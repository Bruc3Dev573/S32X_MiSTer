library STD;
use STD.TEXTIO.ALL;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_TEXTIO.all;

entity SVP is
	port(
		CLK			: in std_logic;
		CE				: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
		BUS_A			: in std_logic_vector(23 downto 1);
		BUS_DO		: out std_logic_vector(15 downto 0);
		BUS_DI		: in std_logic_vector(15 downto 0);
		BUS_SEL		: in std_logic;
		BUS_RNW		: in std_logic;
		BUS_DTACK_N	: out std_logic;
		DMA_ACTIVE	: in std_logic;
		
		ROM_A			: out std_logic_vector(20 downto 1);		
		ROM_DI		: in std_logic_vector(15 downto 0);
		ROM_REQ		: out std_logic;
		ROM_ACK		: in std_logic;
		
		DRAM_A		: out std_logic_vector(16 downto 1);
		DRAM_DI		: in std_logic_vector(15 downto 0);
		DRAM_DO		: out std_logic_vector(15 downto 0);
		DRAM_WE		: out std_logic;

		-- Savestate. 11-bit word map:
		--   0x000-0x2FF  SSP1601 (regs, RAMA, RAMB - decoded inside SSP160x)
		--   0x300-0x31F  PMARS 0..15, two words each (MA, DATA & CD)
		--   0x320-0x326  interface and memory controller registers
		--   0x3FF        DSP clock-enable phase (held in S32X.sv)
		--   0x400-0x7FF  IRAM (1024 x 16)
		-- SS_ACTIVE gives the IRAM/RAM ports to the stream. SS_PARKED is high
		-- when the memory controller is at rest; CE low stops the DSP but not
		-- this controller, so an image is only taken while SS_PARKED is high.
		SS_ADDR		: in std_logic_vector(10 downto 0);
		SS_RD_DATA	: out std_logic_vector(31 downto 0);
		SS_WR_DATA	: in std_logic_vector(31 downto 0);
		SS_WR_EN		: in std_logic;
		SS_ACTIVE	: in std_logic;
		SS_PARKED	: out std_logic
	);
end SVP;

architecture rtl of SVP is

	signal EN				: std_logic;
	
	--SSP ports
	signal SSP_PA 			: std_logic_vector(15 downto 0);
	signal SSP_PDI 		: std_logic_vector(15 downto 0);
	signal SSP_SS 			: std_logic;
	signal SSP_EA 			: std_logic_vector(2 downto 0);
	signal SSP_EXTI 		: std_logic_vector(15 downto 0);
	signal SSP_EXTO 		: std_logic_vector(15 downto 0);
	signal SSP_ESB 		: std_logic;
	signal SSP_R_NW 		: std_logic;
	signal SSP_USR01 		: std_logic_vector(1 downto 0);
	signal SSP_ST56 		: std_logic_vector(1 downto 0);
	signal SSP_BL_WR 		: std_logic;
	signal SSP_BL_RD 		: std_logic;
	
	--PMARs
	type PMAR_r is record
		MA		: std_logic_vector(31 downto 0);		--Mode/Address
		DATA	: std_logic_vector(15 downto 0);		--Read/Write data
		CD		: std_logic_vector(15 downto 0);		--Custom displacement
	end record;
	type PMARs_t is array (0 to 15) of PMAR_r;
	signal PMARS 			: PMARs_t;
	signal PMAR_SET 		: std_logic;
	signal PMAR_NUM 		: unsigned(3 downto 0);
	signal PMC 				: std_logic_vector(31 downto 0);
	signal PMC_SEL 		: std_logic;
	
	--I/O
	signal DTACK_N 		: std_logic;
	signal XCM 				: std_logic_vector(15 downto 0);
	signal XST 				: std_logic_vector(15 downto 0);
	signal CA 				: std_logic;
	signal SA 				: std_logic;
	signal HALT 			: std_logic;
	
	--Memory controller
	type MemAccessState_t is (
		MAS_IDLE,
		MAS_PROM_RD,
		MAS_ROM_RD,
		MAS_DRAM_RD,
		MAS_DRAM_WR,
		MAS_IRAM_RD,
		MAS_IRAM_WR
	);
	signal MAS 				: MemAccessState_t;
	signal MEM_ADDR 		: std_logic_vector(20 downto 0);
	signal ROM_ADDR 		: std_logic_vector(19 downto 0);
	signal ROM_DATA 		: std_logic_vector(15 downto 0);
	signal DRAM_ADDR 		: std_logic_vector(15 downto 0);
	signal SSP_WAIT 		: std_logic;
	signal SSP_ACTIVE 	: std_logic;
	signal PMAR_ACTIVE	: std_logic; 
	signal IRAM_SEL 		: std_logic;
	signal MA_ROM_REQ 	: std_logic;
	signal MEM_WAIT 		: std_logic; 
	signal DRAM_GEN_REQ 	: std_logic; 
	signal DRAM_GEN_ADDR : std_logic_vector(15 downto 0);
	signal DRAM_GEN_DAT 	: std_logic_vector(15 downto 0);
	signal DRAM_GEN_WAIT : std_logic; 
	signal DRAM_GEN_WE 	: std_logic; 
	
	--IRAM
	signal IRAM_ADDR 		: std_logic_vector(9 downto 0);
	signal IRAM_D 			: std_logic_vector(15 downto 0);
	signal IRAM_WE 		: std_logic;
	signal IRAM_Q 			: std_logic_vector(15 downto 0);

	--Savestate
	signal SS_SEL_IRAM	: std_logic;
	signal SS_SEL_TOP		: std_logic;
	signal SS_SEL_SSP		: std_logic;
	signal SS_SSP_WR		: std_logic;
	signal SS_TOP_WR		: std_logic;
	signal SS_SSP_RD		: std_logic_vector(31 downto 0);
	-- BUS_DO is a registered output; routed through this signal so the sweep
	-- can read it back (an out port is not readable in VHDL-93).
	signal BUS_DO_R		: std_logic_vector(15 downto 0);
	
	impure function GetNextMA(pmar: PMAR_r) return std_logic_vector is
		variable displ: std_logic_vector(15 downto 0); 
		variable temp: std_logic_vector(19 downto 0); 
		variable res: std_logic_vector(31 downto 0); 
	begin
		case pmar.MA(29 downto 27) is
			when "001" => 	displ := x"0001";
			when "010" => 	displ := x"0002";
			when "011" => 	displ := x"0004";
			when "100" => 	displ := x"0008";
			when "101" => 	displ := x"0010";
			when "110" => 	displ := x"0020";
			when "111" => 	displ := pmar.CD;
			when others => displ := x"0000";
		end case;
		if pmar.MA(30) = '0' then
			if pmar.MA(31) = '0' then
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + unsigned(displ));
			else
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) - unsigned(displ));
			end if;
		else
			if pmar.MA(0) = '0' then
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + 1);
			else
				temp := std_logic_vector(unsigned(pmar.MA(19 downto 0)) + 31);
			end if;
		end if;
		
		res := pmar.MA(31 downto 20) & temp;
		return res;
	end function;
	
	impure function OverWrite(pmar: PMAR_r; old: std_logic_vector(15 downto 0)) return std_logic_vector is
		variable res: std_logic_vector(15 downto 0); 
	begin
		res := old;
		if pmar.DATA(3 downto 0) /= x"0" or pmar.MA(26) = '0' then
			res(3 downto 0) := pmar.DATA(3 downto 0);
		end if;
		if pmar.DATA(7 downto 4) /= x"0" or pmar.MA(26) = '0' then
			res(7 downto 4) := pmar.DATA(7 downto 4);
		end if;
		if pmar.DATA(11 downto 8) /= x"0" or pmar.MA(26) = '0' then
			res(11 downto 8) := pmar.DATA(11 downto 8);
		end if;
		if pmar.DATA(15 downto 12) /= x"0" or pmar.MA(26) = '0' then
			res(15 downto 12) := pmar.DATA(15 downto 12);
		end if;

		return res;
	end function;

begin

	EN <= ENABLE and CE;
	
	IRAM_SEL <= '1' when SSP_PA(15 downto 10) = "000000" else '0';
	
	SSP_WAIT <= '1' when MAS /= MAS_IDLE else '0';
	
	SSP_PDI <= IRAM_Q when IRAM_SEL = '1' else ROM_DATA;
	SSP_SS <= EN and not SSP_WAIT and not HALT;
	SSP_USR01 <= "00";
	
	-- SS decode: 0x400+ is IRAM, 0x300-0x3FF is this level, everything below
	-- belongs to the DSP core.
	SS_SEL_IRAM <= SS_ADDR(10);
	SS_SEL_TOP  <= '1' when SS_ADDR(10) = '0' and SS_ADDR(9 downto 8) = "11" else '0';
	SS_SEL_SSP  <= '1' when SS_ADDR(10) = '0' and SS_ADDR(9 downto 8) /= "11" else '0';
	SS_TOP_WR   <= SS_WR_EN and SS_SEL_TOP;
	SS_SSP_WR   <= SS_WR_EN and SS_SEL_SSP;
	BUS_DO      <= BUS_DO_R;

	-- The FSM's canonical rest point (see the port comment).
	SS_PARKED <= '1' when MAS = MAS_IDLE and SSP_ACTIVE = '0' and PMAR_ACTIVE = '0'
	                  and MEM_WAIT = '0' and DRAM_GEN_REQ = '0' else '0';

	SSP160x : entity work.SSP160x
	port map(
		CLK		=> CLK,
		RST_N		=> RST_N,
		ENABLE	=> ENABLE,
		SS			=> SSP_SS,

		SS_ADDR		=> SS_ADDR(9 downto 0),
		SS_RD_DATA	=> SS_SSP_RD,
		SS_WR_DATA	=> SS_WR_DATA,
		SS_WR_EN		=> SS_SSP_WR,
		SS_ACTIVE	=> SS_ACTIVE,
		
		PA			=> SSP_PA,		
		PDI		=> SSP_PDI,
		
		EA			=> SSP_EA,
		EXTI		=> SSP_EXTI,
		EXTO		=> SSP_EXTO,
		ESB		=> SSP_ESB,
		R_NW		=> SSP_R_NW,
		
		USR01		=> SSP_USR01,
		ST56		=> SSP_ST56,
		
		BLIND_RD	=> SSP_BL_RD,
		BLIND_WR	=> SSP_BL_WR
	);
	
	--I/O
	process(CLK, RST_N)
	variable ADDR_TEMP : std_logic_vector(16 downto 1);
	begin
		if RST_N = '0' then
			PMC_SEL <= '0';
			XST <= (others => '0');
			SA <= '0';
			CA <= '0';
			DTACK_N <= '1';
			BUS_DO_R <= (others => '0');
			HALT <= '0';
			DRAM_GEN_REQ <= '0';
		elsif rising_edge(CLK) then
			-- SS restore for the signals this process drives. One driver per
			-- signal is a VHDL rule, so the injection has to live here rather
			-- than in a savestate process of its own.
			if SS_TOP_WR = '1' then
				case SS_ADDR(7 downto 0) is
					when x"21" =>
						XST <= SS_WR_DATA(31 downto 16);
						DRAM_GEN_ADDR <= SS_WR_DATA(15 downto 0);
					when x"22" =>
						DRAM_GEN_DAT <= SS_WR_DATA(31 downto 16);
						BUS_DO_R <= SS_WR_DATA(15 downto 0);
					when x"23" =>
						-- Handshake bits with the 68k (CA/SA/XST) carry real
						-- protocol state and are restored. The in-flight
						-- 68k-side DRAM access is not: like the DSP's own FSM
						-- above, resuming half of a bus transaction leaves
						-- both sides waiting. DTACK_N goes to its idle level
						-- so the next 68k access starts clean.
						PMC_SEL      <= SS_WR_DATA(12);
						CA           <= SS_WR_DATA(10);
						SA           <= SS_WR_DATA(9);
						HALT         <= SS_WR_DATA(8);
						DTACK_N      <= '1';
						DRAM_GEN_REQ <= '0';
						DRAM_GEN_WAIT<= '0';
						DRAM_GEN_WE  <= '0';
					when others => null;
				end case;
			end if;
			if ENABLE = '1' then
				if SSP_ESB = '1' and EN = '1' then
					if SSP_R_NW = '0' then
						case SSP_EA is
							when "011" => 
								if SSP_ST56(1) = '0' then
									XST <= SSP_EXTO;
									SA <= '1';
								end if;
							when "110" => 
								PMC_SEL <= not PMC_SEL;
							when others => null;
						end case; 
					else
						case SSP_EA is
							when "000" =>
								if SSP_ST56(0) = '0' then
									CA <= '0';
								end if;
							when "110" => 
								PMC_SEL <= not PMC_SEL;
							when "111" => 
								if SSP_BL_RD = '1' then
									PMC_SEL <= '0';
								end if;
							when others =>null;
						end case; 
					end if;
				end if;
			
				if BUS_SEL = '0' then
					DTACK_N <= '1';
				elsif BUS_SEL = '1' and DTACK_N = '1' then
					if BUS_A(23 downto 4) = x"A1500" then
						if BUS_RNW = '0' then
							case BUS_A(3 downto 1) is
								when "000" | "001" =>
									XST <= BUS_DI;
									if BUS_DI /= x"0000" then
										CA <= '1';
									end if;
								when "011" => 
									if BUS_DI(3 downto 0) = x"A" then
										HALT <= '1';
									else
										HALT <= '0';
									end if;
								when others =>
							end case; 
						else
							case BUS_A(3 downto 1) is
								when "000" | "001" =>
									BUS_DO_R <= XST;
								when "010" =>
									BUS_DO_R <= "00000000000000" & CA & SA;
									SA <= '0';
								when others =>
									BUS_DO_R <= (others => '0');
							end case; 
						end if;
						DTACK_N <= '0';
					elsif BUS_A(23 downto 19) = "00110" or 	--300000-37FFFF SVP DRAM (+mirrors)
							BUS_A(23 downto 16) = x"39" or 		--390000-39FFFF SVP DRAM cell arrange 1
							BUS_A(23 downto 16) = x"3A" then 	--3A0000-3AFFFF SVP DRAM cell arrange 2
						if DRAM_GEN_REQ = '0' and MAS /= MAS_DRAM_RD and MAS /= MAS_DRAM_WR then
							DRAM_GEN_REQ <= '1';
							if DMA_ACTIVE = '0' then
								ADDR_TEMP := BUS_A(16 downto 1);
							else
								ADDR_TEMP := std_logic_vector( unsigned(BUS_A(16 downto 1)) - 1 );
							end if;
							if BUS_A(23 downto 16) = x"39" then
								DRAM_GEN_ADDR <= "0" & ADDR_TEMP(15 downto 13) & ADDR_TEMP(6 downto 2) & ADDR_TEMP(12 downto 7) & ADDR_TEMP(1);
							elsif BUS_A(23 downto 16) = x"3A" then
								DRAM_GEN_ADDR <= "0" & ADDR_TEMP(15 downto 12) & ADDR_TEMP(5 downto 2) & ADDR_TEMP(11 downto 6) & ADDR_TEMP(1);
							else
								DRAM_GEN_ADDR <= ADDR_TEMP;
							end if;
							DRAM_GEN_WE <= not BUS_RNW;
							DRAM_GEN_DAT <= BUS_DI;
							DRAM_GEN_WAIT <= '1';
						elsif DRAM_GEN_REQ = '1' then
							DRAM_GEN_WAIT <= '0';
							if DRAM_GEN_WAIT = '0' then
								if BUS_RNW = '1' then
									BUS_DO_R <= DRAM_DI;
								end if;
								DTACK_N <= '0';
								DRAM_GEN_REQ <= '0';
							end if;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;
	
	BUS_DTACK_N <= DTACK_N;
	
	process(SSP_EA, SSP_ST56, PMARS, PMC_SEL, PMC, XST, CA, SA)
	begin
		case SSP_EA is
			when "000" =>
				if SSP_ST56(0) = '0' then
					SSP_EXTI <= "00000000000000" & CA & SA;
				else
					SSP_EXTI <= PMARS(0+8).DATA;
				end if;
			when "001" =>
				if SSP_ST56(0) = '0' then
					SSP_EXTI <= (others => '0');
				else
					SSP_EXTI <= PMARS(1+8).DATA;
				end if;
			when "010" =>
				if SSP_ST56(1) = '0' then
					SSP_EXTI <= (others => '0');
				else
					SSP_EXTI <= PMARS(2+8).DATA;
				end if;
			when "011" => 
				if SSP_ST56(1) = '0' then
					SSP_EXTI <= XST;
				else
					SSP_EXTI <= PMARS(3+8).DATA;
				end if;
			when "100" =>
				SSP_EXTI <= PMARS(4+8).DATA;
			when "101" =>
				SSP_EXTI <= (others => '0');
			when "110" => 
				if PMC_SEL = '0' then
					SSP_EXTI <= PMC(15 downto 0);
				else
					SSP_EXTI <= PMC(11 downto 8) & PMC(15 downto 12) & PMC(3 downto 0) & PMC(7 downto 4);
				end if;
			when others =>
				SSP_EXTI <= (others => '0');
		end case; 
	end process;
	
	
	--PMARs
	process(CLK, RST_N)
	variable NEW_MA : std_logic_vector(31 downto 0); 
	begin
		if RST_N = '0' then
			PMC <= (others => '0');
			PMARS <= (others => ((others => '0'),(others => '0'),(others => '0')));
			PMAR_SET <= '0';
			MAS <= MAS_IDLE;
			PMAR_NUM <= (others => '0');
			MA_ROM_REQ <= '0';
			ROM_DATA <= (others => '0');
			SSP_ACTIVE <= '1';
			PMAR_ACTIVE <= '0';
			MEM_WAIT <= '0';
		elsif rising_edge(CLK) then
			-- SS restore for this process's signals (PMAR file + the memory
			-- controller). Note MAS is rebuilt from its enumeration position,
			-- never from raw encoding bits.
			if SS_TOP_WR = '1' then
				if SS_ADDR(7 downto 5) = "000" then
					if SS_ADDR(0) = '0' then
						PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).MA <= SS_WR_DATA;
					else
						PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).DATA <= SS_WR_DATA(31 downto 16);
						PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).CD   <= SS_WR_DATA(15 downto 0);
					end if;
				else
					case SS_ADDR(7 downto 0) is
						when x"20" => PMC <= SS_WR_DATA;
						when x"23" =>
							-- An image is only taken with the SVP parked (SS_PARKED:
							-- memory FSM idle, no PMAR access pending, nothing in
							-- flight), so the FSM goes back to that rest point and the
							-- req/ack handshake to rest. SSP_ACTIVE is the recorded one:
							-- at the park the instruction at PC has been fetched into
							-- ROM_DATA (word 26), and forcing a refetch would delay the
							-- DSP against the 68000 it races with.
							MAS         <= MAS_IDLE;
							MEM_WAIT    <= '0';
							PMAR_ACTIVE <= '0';
							SSP_ACTIVE  <= SS_WR_DATA(6);
							MA_ROM_REQ  <= ROM_ACK;   -- req/ack handshake at rest
							PMAR_NUM    <= unsigned(SS_WR_DATA(16 downto 13));
							PMAR_SET    <= SS_WR_DATA(11);
						when x"24" => MEM_ADDR <= SS_WR_DATA(20 downto 0);
						when x"25" => ROM_ADDR <= SS_WR_DATA(19 downto 0);
						when x"26" =>
							ROM_DATA  <= SS_WR_DATA(31 downto 16);
							DRAM_ADDR <= SS_WR_DATA(15 downto 0);
						when others => null;
					end case;
				end if;
			end if;
			if EN = '1' then
				SSP_ACTIVE <= '1';
				if SSP_ESB = '1' then
					if (SSP_ST56(0) = '1' and SSP_EA(2 downto 1) = "00") or 
						(SSP_ST56(1) = '1' and SSP_EA(2 downto 1) = "01") or 
						SSP_EA = "100" then			--set PMAR
						if ((SSP_BL_WR = '1' and SSP_R_NW = '0') or (SSP_BL_RD = '1' and SSP_R_NW = '1')) and PMAR_SET = '0' then
							PMARS(to_integer(unsigned(SSP_R_NW & SSP_EA))).MA <= PMC;
							if SSP_R_NW = '1' then
								PMAR_ACTIVE <= '1';
							end if;
							MEM_ADDR <= PMC(20 downto 0);
							PMAR_NUM <= unsigned(SSP_R_NW & SSP_EA);
							PMAR_SET <= '1';
						else
							NEW_MA := GetNextMA(PMARS(to_integer(unsigned(SSP_R_NW & SSP_EA))));
							if SSP_R_NW = '1' then
								MEM_ADDR <= NEW_MA(20 downto 0);
							else
								PMARS(to_integer(unsigned(SSP_R_NW & SSP_EA))).DATA <= SSP_EXTO;
								MEM_ADDR <= PMARS(to_integer(unsigned(SSP_R_NW & SSP_EA))).MA(20 downto 0);
							end if;
							PMARS(to_integer(unsigned(SSP_R_NW & SSP_EA))).MA <= NEW_MA;
							PMC <= NEW_MA;
							
							PMAR_NUM <= unsigned(SSP_R_NW & SSP_EA);
							PMAR_ACTIVE <= '1';
						end if;
					elsif SSP_EA = "110" then		--set PMC
						if SSP_R_NW = '0' then
							if PMC_SEL = '0' then
								PMC(15 downto 0) <= SSP_EXTO;
							else
								PMC(31 downto 16) <= SSP_EXTO;
							end if;
							PMAR_SET <= '0';
						end if;
					elsif SSP_EA = "111" then		--set custom displacement
						if SSP_R_NW = '1' and SSP_BL_RD = '1' then
							PMARS(to_integer(PMAR_NUM)).CD <= PMC(15 downto 0);
						end if;
					end if;
				end if;
			end if;
			
			case MAS is
				when MAS_IDLE =>
					if PMAR_ACTIVE = '1' then
						if MEM_ADDR(20) = '0' then								--ROM 000000-1FFFFF (000000-0FFFFF)
							if PMAR_NUM(3) = '1' then
								MA_ROM_REQ <= not ROM_ACK;
								ROM_ADDR <= MEM_ADDR(19 downto 0);
								MAS <= MAS_ROM_RD;
							end if;
							PMAR_ACTIVE <= '0';
						elsif MEM_ADDR(20 downto 16) = "11000" then		--DRAM 300000-37FFFF (180000-1BFFFF)
							DRAM_ADDR <= MEM_ADDR(15 downto 0);
							if PMAR_NUM(3) = '1' then
								MAS <= MAS_DRAM_RD;
							else
								MAS <= MAS_DRAM_WR;
							end if;
							MEM_WAIT <= '1';
						elsif MEM_ADDR(20 downto 15) = "111001" then		--IRAM 390000-3907FF (1C8000-1C83FF)
							if PMAR_NUM(3) = '1' then
								MAS <= MAS_IRAM_RD;
								MEM_WAIT <= '1';
							else
								MAS <= MAS_IRAM_WR;
							end if;
						end if;
						PMAR_ACTIVE <= '0';
					end if;
					
				when MAS_PROM_RD =>
					if MA_ROM_REQ = ROM_ACK then
						ROM_DATA <= ROM_DI;
						MAS <= MAS_IDLE;
						SSP_ACTIVE <= '0';
					end if;
					
				when MAS_ROM_RD =>
					if MA_ROM_REQ = ROM_ACK then
						PMARS(to_integer(PMAR_NUM)).DATA <= ROM_DI;
						MAS <= MAS_IDLE;
					end if;
				
				when MAS_DRAM_RD =>
					if DRAM_GEN_REQ = '0' then
						MEM_WAIT <= '0';
						if MEM_WAIT = '0' then
							PMARS(to_integer(PMAR_NUM)).DATA <= DRAM_DI;
							MAS <= MAS_IDLE;
						end if;
					end if;
										
				when MAS_DRAM_WR =>
					if DRAM_GEN_REQ = '0' then
						MEM_WAIT <= '0';
						if MEM_WAIT = '0' then
							MAS <= MAS_IDLE;
						end if;
					end if;
					
				when MAS_IRAM_RD =>
					MEM_WAIT <= '0';
					if MEM_WAIT = '0' then
						PMARS(to_integer(PMAR_NUM)).DATA <= IRAM_Q;
						MAS <= MAS_IDLE;
					end if;	
					
				when MAS_IRAM_WR =>
					MEM_WAIT <= '0';
--					if MEM_WAIT = '0' then
						MAS <= MAS_IDLE;
--					end if;
					
				when others => null;
			end case; 
			
			if (MAS = MAS_IDLE) or 
				(MAS = MAS_ROM_RD and MA_ROM_REQ = ROM_ACK) or
				(MAS = MAS_DRAM_RD and MEM_WAIT = '0' and DRAM_GEN_REQ = '0') or
				(MAS = MAS_DRAM_WR and MEM_WAIT = '0' and DRAM_GEN_REQ = '0') or
				(MAS = MAS_IRAM_RD and MEM_WAIT = '0') or 
				(MAS = MAS_IRAM_WR) then-- and MEM_WAIT = '0'
				if PMAR_ACTIVE = '0' and SSP_ACTIVE = '1' then
					if IRAM_SEL = '0' then
						MA_ROM_REQ <= not ROM_ACK;
						ROM_ADDR <= "0000" & SSP_PA;
						MAS <= MAS_PROM_RD;
					else
						SSP_ACTIVE <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;
	
	ROM_A <= ROM_ADDR;
	ROM_REQ <= MA_ROM_REQ;
	
	
	--IRAM
	-- SS: single-port BRAM, so the stream takes the port while frozen. Read is
	-- registered by the block RAM, so the caller must present an address one
	-- cycle before sampling.
	IRAM_ADDR <= SS_ADDR(9 downto 0) when SS_ACTIVE = '1' else
	             MEM_ADDR(9 downto 0) when MAS = MAS_IRAM_RD or MAS = MAS_IRAM_WR else SSP_PA(9 downto 0);
	IRAM_D <= SS_WR_DATA(15 downto 0) when SS_ACTIVE = '1' else PMARS(to_integer(PMAR_NUM)).DATA;
	IRAM_WE <= (SS_WR_EN and SS_SEL_IRAM) when SS_ACTIVE = '1' else
	           '1' when MAS = MAS_IRAM_WR else '0';
	IRAM : entity work.spram generic map(10, 16)
	port map(
		clock		=> CLK,
		address	=> IRAM_ADDR,
		data		=> IRAM_D,
		wren		=> IRAM_WE,
		q			=> IRAM_Q
	);
	
	-- SS read mux. PMARS pairs: even word = MA, odd = DATA & CD.
	SS_RD_DATA <=
		x"0000" & IRAM_Q                                  when SS_SEL_IRAM = '1' else
		SS_SSP_RD                                         when SS_SEL_SSP = '1' else
		PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).MA
			when SS_ADDR(7 downto 5) = "000" and SS_ADDR(0) = '0' else
		PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).DATA &
		PMARS(to_integer(unsigned(SS_ADDR(4 downto 1)))).CD
			when SS_ADDR(7 downto 5) = "000" else
		PMC                                               when SS_ADDR(7 downto 0) = x"20" else
		XST & DRAM_GEN_ADDR                               when SS_ADDR(7 downto 0) = x"21" else
		DRAM_GEN_DAT & BUS_DO_R                           when SS_ADDR(7 downto 0) = x"22" else
		-- 31:20 pad | 19:17 MAS | 16:13 PMAR_NUM | 12 PMC_SEL | 11 PMAR_SET |
		-- 10 CA | 9 SA | 8 HALT | 7 DTACK_N | 6 SSP_ACTIVE | 5 PMAR_ACTIVE |
		-- 4 MA_ROM_REQ | 3 MEM_WAIT | 2 DRAM_GEN_REQ | 1 DRAM_GEN_WAIT | 0 WE.
		-- MAS is an enumeration: Quartus is free to one-hot it, so it travels
		-- as an explicit binary position, never as raw bits.
		"000000000000" & std_logic_vector(to_unsigned(MemAccessState_t'pos(MAS), 3)) &
		  std_logic_vector(PMAR_NUM) & PMC_SEL & PMAR_SET & CA & SA & HALT & DTACK_N &
		  SSP_ACTIVE & PMAR_ACTIVE & MA_ROM_REQ & MEM_WAIT & DRAM_GEN_REQ &
		  DRAM_GEN_WAIT & DRAM_GEN_WE                     when SS_ADDR(7 downto 0) = x"23" else
		std_logic_vector(resize(unsigned(MEM_ADDR), 32))  when SS_ADDR(7 downto 0) = x"24" else
		std_logic_vector(resize(unsigned(ROM_ADDR), 32))  when SS_ADDR(7 downto 0) = x"25" else
		ROM_DATA & DRAM_ADDR                              when SS_ADDR(7 downto 0) = x"26" else
		(others => '0');

	--DRAM
	DRAM_A <= DRAM_GEN_ADDR when DRAM_GEN_REQ = '1' else DRAM_ADDR;
	DRAM_DO <= DRAM_GEN_DAT when DRAM_GEN_REQ = '1' else OverWrite(PMARS(to_integer(PMAR_NUM)), DRAM_DI);
	DRAM_WE <= '1' when DRAM_GEN_REQ = '0' and MAS = MAS_DRAM_WR and MEM_WAIT = '0' else
				  '1' when DRAM_GEN_REQ = '1' and DRAM_GEN_WAIT = '0' and DRAM_GEN_WE = '1' else 
				  '0';
	
end rtl;
