module SH7604 
#(parameter bit UBC_DISABLE=0, bit SCI_DISABLE=0, bit WDT_DISABLE=0, bit [3:0] BUS_AREA_TIMIMG=0, bit BUS_SIZE_BYTE_DISABLE=0, bit BUS_SIZE_WORD_DISABLE=0)
(
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	input             NMI_N,
	
	input       [3:0] IRL_N,
	
	output     [26:0] A,
	input      [31:0] DI,
	output     [31:0] DO,
	output            BS_N,
	output            CS0_N,
	output            CS1_N,
	output            CS2_N,
	output            CS3_N,
	output            RD_WR_N,	//WE_N
	output            CE_N,		//RAS_N
	output            OE_N,		//CAS_N
	output      [3:0] WE_N,		//CASxx_N/DQMxx
	output            RD_N,
	output            IVECF_N,
	output            RFS,
	
	input      [26:0] EA,
	output     [31:0] EDI,
	input      [31:0] EDO,
	input             EBS_N,
	input             ECS0_N,
	input             ECS1_N,
	input             ECS2_N,
	input             ECS3_N,
	input             ERD_WR_N,	//WE_N
	input             ECE_N,		//RAS_N
	input             EOE_N,		//CAS_N
	input       [3:0] EWE_N,		//CASxx_N/DQMxx
	input             ERD_N,
	input             EIVECF_N,
	
	input             WAIT_N,
	input             BRLS_N,	//BACK_N
	output            BGR_N,	//BREQ_N
	
	input             DREQ0,
	output            DACK0,
	input             DREQ1,
	output            DACK1,
	
	output            FTOA,
	output            FTOB,
	input             FTCI,
	input             FTI,
	
	input             RXD,
	output            TXD,
	output            SCKO,
	input             SCKI,
	
	output            WDTOVF_N,
	
	input       [5:0] MD,
	
	input             FAST,
	
	// Savestate. SS_HOLD: this CPU is parked (VCLK blocked, no CE_R/CE_F); the access ports
	// below are ignored while it is low. SS_BUS_IDLE: safe to park at the coming VCLK (bus
	// controller at T0, divider idle). Image layout: see the savestate section below.
	input             SS_HOLD,
	output            SS_BUS_IDLE,
	input             SS_SEL,
	input      [11:0] SS_ADDR,
	input             SS_WR_EN,
	input      [31:0] SS_WR_DATA,
	output     [31:0] SS_RD_DATA
	
`ifdef DEBUG
	                  ,
	input       [4:0] DBG_REGN,
	output     [31:0] DBG_REGQ,
	input             DBG_RUN,
	output            DBG_BREAK
`endif
);

	import SH7604_PKG::*;
	
	//**********************************************************
	// Savestate
	//**********************************************************
	// Image (32-bit words at SS_ADDR, SS_IMAGE_SIZE = 'h600), written only while parked:
	//   000-048  flop chain, 2331 bits, MSB of word 000 first: reset sync and clock divider
	//            (27 bits), 5 pad bits, then core, MULT, DIVU, DMAC, INTC, FRT, WDT, SCI,
	//            UBC, MSBY, BSC, cache (the order of the SS_SI/SS_SO links below)
	//   049-0DF  reserved (read 0)
	//   0E0-0EF  R0-R15, 0F0 PR, 0F1-0FF reserved
	//   100-1FF  cache address array, 100 + index*4 + way: [19:1] tag, [0] valid,
	//            [20] line purge pending, [26:21] LRU of the index, [27] LRU purge pending
	//   200-5FF  cache data array, 200 + way*256 + longword (the 0xC0000000 offset / 4)
	// The chain shifts one word when SS_ADDR leaves a chain word during a save (after the
	// last word it is back in its original state) and on the first clock of SS_WR_EN
	// during a load. SS_RD_DATA is valid 1 clock after SS_ADDR changes.
	// Flops that are dead or constant at the park are left out: bus read latches (REG_DO)
	// consumed by the CE_R after they load, MULT operands and the DIVU datapath, the
	// regfile write-B latch, one-clock pulses, and what the 32X ties off or leaves
	// unconnected (see each module).
	// chain bits: top 27, core 760, MULT 100, DIVU 186, DMAC 378, INTC 119, FRT 78, WDT 30,
	// SCI 100, UBC 217, MSBY 3, BSC 211 (+9 with byte areas), cache 122
	localparam SS_BITS  = 27 + 760 + 100 + 186 + 378 + 119 + 78 + 30 + 100 + 217 + 3 +
	                      211 + (BUS_SIZE_BYTE_DISABLE ? 0 : 9) + 122;
	localparam SS_WORDS = (SS_BITS + 32) / 32;
	localparam SS_PAD   = SS_WORDS*32 - SS_BITS;
	
	wire        ss_on   = SS_SEL & SS_HOLD;
	wire        ss_chain = ss_on & (SS_ADDR < SS_WORDS);
	wire        ss_regs  = ss_on & (SS_ADDR[11:5] == 7'h07) & (~SS_ADDR[4] | ~|SS_ADDR[3:0]);
	wire        ss_tag   = ss_on & (SS_ADDR[11:8] == 4'h1);
	wire        ss_data  = ss_on & ((SS_ADDR[11:9] == 3'd1) | (SS_ADDR[11:9] == 3'd2));
	wire  [9:0] ss_cache_a = {SS_ADDR[9] ^ ss_data, SS_ADDR[8:0]};
	
	bit         ss_chain_d, ss_a0_d, ss_wrote;
	bit   [6:0] ss_cnt;
	wire        ss_chg   = ~ss_chain_d | (SS_ADDR[0] ^ ss_a0_d);
	wire        ss_leave = ss_chain_d & (~ss_chain | ss_chg);
	wire        ss_done  = ss_wrote & ~ss_chg;
	wire        ss_load  = ss_chain & SS_WR_EN & ~ss_done;
	wire        SS_SHIFT = ss_load | (ss_leave & ~ss_wrote);
	// The chain holds a mix of words between the first and the last shift. Only then must
	// the logic that is not CE-gated (resets, cache purge) and the pins ignore it.
	wire        ss_rot   = |ss_cnt;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			ss_chain_d <= 0;
			ss_a0_d <= 0;
			ss_wrote <= 0;
			ss_cnt <= '0;
		end
		else begin
			ss_chain_d <= ss_chain;
			ss_a0_d <= SS_ADDR[0];
			ss_wrote <= ss_chain & (ss_load | ss_done);
			if (SS_SHIFT) ss_cnt <= ss_cnt == SS_WORDS-1 ? 7'd0 : ss_cnt + 7'd1;
		end
	end
	
	wire [31:0] ss_chain_in;
	wire [31:0] ss_core_so, ss_mult_so, ss_divu_so, ss_dmac_so, ss_intc_so, ss_frt_so, ss_wdt_so;
	wire [31:0] ss_sci_so, ss_ubc_so, ss_msby_so, ss_bsc_so, ss_cache_so;
	wire [31:0] ss_regs_q, ss_cache_q;
	wire        ss_bsc_idle, ss_divu_idle;
	wire [       1+31:0] ss_res;
	wire [      26+31:0] ss_div;
	wire [SS_PAD+31:0] ss_padc;
	bit  [SS_PAD-1:0] ss_pad;
	always @(posedge CLK) if (SS_SHIFT) ss_pad <= ss_padc[SS_PAD-1:0];
	
	assign SS_BUS_IDLE = ss_bsc_idle & ss_divu_idle;
	assign SS_RD_DATA  = ss_chain ? ss_res[1+31:1] :
	                     ss_regs  ? ss_regs_q :
	                     ss_tag | ss_data ? ss_cache_q : '0;
	assign ss_chain_in = ss_load ? SS_WR_DATA : ss_res[1+31:1];
	
	bit [31:0] CBUS_A;
	bit [31:0] CBUS_DO;
	bit [31:0] CBUS_DI;
	bit        CBUS_WR;
	bit  [3:0] CBUS_BA;
	bit        CBUS_REQ;
	bit        CBUS_ID;
	bit        CBUS_TAS;
	
	bit [31:0] IBUS_A;
	bit [31:0] IBUS_DO;
	bit [31:0] IBUS_DI;
	bit  [3:0] IBUS_BA;
	bit        IBUS_WE;
	bit        IBUS_REQ;
	bit        IBUS_PREREQ;
	bit        IBUS_WAIT;
	bit        IBUS_BURST;
	bit        IBUS_LOCK;
	
	bit  [3:0] INT_LVL;
	bit  [7:0] INT_VEC;
	bit        INT_REQ;
	bit  [3:0] INT_MASK;
	bit        INT_ACK;
	bit        INT_ACP;
	bit        VECT_REQ;
	bit        VECT_WAIT;
	
	bit        SLEEP;
	
	
	//CACHE
	bit [31:0] CACHE_DI;
	bit [31:0] CACHE_DO;
	bit        CACHE_BUSY;
	bit        CACHE_ACT;
	
	//BSC
	bit [31:0] BSC_IBUS_DO;
	bit [31:0] BSC_DBUS_DO;
	bit        BSC_IBUS_BUSY;
	bit        BSC_DBUS_BUSY;
	bit        BSC_VBUS_BUSY;
	bit        BSC_ACK;
	
	//DMAC
	bit [31:0] DMAC_DO;
	bit        DMAC_ACT;
	bit        DMAC0_IRQ;
	bit  [7:0] DMAC0_VEC;
	bit        DMAC1_IRQ;
	bit  [7:0] DMAC1_VEC;
	
	//INTC
	bit [31:0] INTC_DO;
	bit        INTC_ACT;
	bit        INTC_BUSY;
	bit  [3:0] VBUS_A;
	bit  [7:0] VBUS_DO;
	bit        VBUS_REQ;
	bit        INTC_NMI_REQ;
	
	//MULT
	bit  [1:0] MAC_SEL;
	bit  [3:0] MAC_OP;
	bit        MAC_S;
	bit        MAC_WE;
	bit [31:0] MULT_DO;
	bit        MULT_BUSY;
	
	//SCI
	bit [31:0] SCI_DO;
	bit        SCI_ACT;
	bit        TEI_IRQ;
	bit        TXI_IRQ;
	bit        RXI_IRQ;
	bit        ERI_IRQ;
	
	//FRT
	bit [31:0] FRT_DO;
	bit        FRT_ACT;
	bit        ICI_IRQ;
	bit        OCIA_IRQ;
	bit        OCIB_IRQ;
	bit        OVI_IRQ;
	
	//WDT
	bit [31:0] WDT_DO;
	bit        WDT_ACT;
	bit        WDT_BUSY;
	bit        ITI_IRQ;
	bit        WDT_OVF;
	bit        WDT_PRES;
	bit        WDT_MRES;

	//DIVU
	bit [31:0] DIVU_DO;
	bit        DIVU_BUSY;
	bit        DIVU_ACT;
	bit        DIVU_IRQ;
	bit  [7:0] DIVU_VEC;
	
	//UBC
	bit [31:0] UBC_DO;
	bit        UBC_ACT;
	bit        UBC_IRQ;
	
	//MSBY
	bit [31:0] MSBY_DO;
	bit        MSBY_ACT;
	bit        MSBY_SBY;
	
	//Internal clocks
	bit        CLK2_CE;
	bit        CLK4_CE;
	bit        CLK8_CE;
	bit        CLK16_CE;
	bit        CLK32_CE;
	bit        CLK64_CE;
	bit        CLK128_CE;
	bit        CLK256_CE;
	bit        CLK512_CE;
	bit        CLK1024_CE;
	bit        CLK2048_CE;
	bit        CLK4096_CE;
	bit        CLK8192_CE;
	
	bit        RES_SYNC_N;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			RES_SYNC_N <= 0;
		end
		else if (SS_SHIFT) begin
			RES_SYNC_N <= ss_res[0];
		end
		else begin	
			if (CE_R) begin
				RES_SYNC_N <= RES_N;
			end
		end
	end
	
	// The reset branches of the blocks below are not CE-gated; they are held off while the
	// chain is partly shifted.
	wire       RES_INT_N = RES_SYNC_N | ss_rot;
	
	SH_core core
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE(CE_R),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		.NMI_N(NMI_N),
		
		.BUS_A(CBUS_A),
		.BUS_DI(CBUS_DI),
		.BUS_DO(CBUS_DO),
		.BUS_WR(CBUS_WR),
		.BUS_BA(CBUS_BA),
		.BUS_REQ(CBUS_REQ),
		.BUS_ID(CBUS_ID),
		.BUS_TAS(CBUS_TAS),
		.BUS_WAIT(CACHE_BUSY | (MULT_BUSY & ~FAST)),
		
		.MAC_SEL(MAC_SEL),
		.MAC_OP(MAC_OP),
		.MAC_S(MAC_S),
		.MAC_WE(MAC_WE),
		
		.INT_LVL(INT_LVL),
		.INT_VEC(INT_VEC),
		.INT_REQ(INT_REQ & ~MSBY_SBY),
		.INT_MASK(INT_MASK),
		.INT_ACK(INT_ACK),
		.INT_ACP(INT_ACP),
		.VECT_REQ(VECT_REQ),
		.VECT_WAIT(VECT_WAIT),
		
		.SLEEP(SLEEP),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_mult_so),
		.SS_SO(ss_core_so),
		.SS_REG_SEL(ss_regs),
		.SS_REG_N(SS_ADDR[4:0]),
		.SS_REG_WE(ss_regs & SS_WR_EN),
		.SS_REG_D(SS_WR_DATA),
		.SS_REG_Q(ss_regs_q)
`ifdef DEBUG
		,
		.DBG_REGN(DBG_REGN),
		.DBG_REGQ(DBG_REGQ),
		.DBG_RUN(DBG_RUN),
		.DBG_BREAK(DBG_BREAK)
`endif
	);
	
	assign CBUS_DI = |MAC_SEL && MAC_OP == 4'b1100 && !MAC_WE ? MULT_DO : CACHE_DO;
	
	wire [31:0] MULT_DI = |MAC_SEL && MAC_OP[3:2] == 2'b10 ? CACHE_DO : CBUS_DO;
	SH7604_MULT mult
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.CBUS_A(CBUS_A),
		.CBUS_DI(MULT_DI),
		.CBUS_DO(MULT_DO),
		.CBUS_WR(CBUS_WR),
		.CBUS_BA(CBUS_BA),
		.CBUS_REQ(CBUS_REQ),
		.CBUS_BUSY(MULT_BUSY),
		
		.MAC_SEL(MAC_SEL),
		.MAC_OP(MAC_OP),
		.MAC_S(MAC_S),
		.MAC_WE(MAC_WE),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_divu_so),
		.SS_SO(ss_mult_so)
	);
	

	assign CACHE_DI = |MAC_SEL && MAC_OP == 4'b1110 && !MAC_WE ? MULT_DO : CBUS_DO;
	SH7604_CACHE cache
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.CBUS_A(CBUS_A),
		.CBUS_DI(CACHE_DI),
		.CBUS_DO(CACHE_DO),
		.CBUS_WR(CBUS_WR),
		.CBUS_BA(CBUS_BA),
		.CBUS_REQ(CBUS_REQ),
		.CBUS_ID(CBUS_ID),
		.CBUS_TAS(CBUS_TAS),
		.CBUS_BUSY(CACHE_BUSY),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DI),
		.IBUS_DO(IBUS_DO),
		.IBUS_WE(IBUS_WE),
		.IBUS_BA(IBUS_BA),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_PREREQ(IBUS_PREREQ),
		.IBUS_BURST(IBUS_BURST),
		.IBUS_LOCK(IBUS_LOCK),
		.IBUS_WAIT(IBUS_WAIT),
		
		.SS_ROT(ss_rot),
		.SS_TAG(ss_tag),
		.SS_DATA(ss_data),
		.SS_A(ss_cache_a),
		.SS_WE(SS_WR_EN),
		.SS_D(SS_WR_DATA),
		.SS_Q(ss_cache_q),
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_chain_in),
		.SS_SO(ss_cache_so)
	);
	
	assign IBUS_DI = INTC_ACT ? INTC_DO : 
						  DIVU_ACT ? DIVU_DO : 
						  DMAC_ACT ? DMAC_DO : 
						  FRT_ACT  ? FRT_DO : 
						  WDT_ACT  ? WDT_DO : 
						  SCI_ACT  ? SCI_DO : 
						  UBC_ACT  ? UBC_DO : 
						             BSC_IBUS_DO;
	assign IBUS_WAIT = INTC_ACT ? INTC_BUSY :
	                   DIVU_ACT ? DIVU_BUSY :
						    DMAC_ACT ? 1'b0 : 
						    UBC_ACT  ? 1'b0 :  
						    FRT_ACT  ? 1'b0 : 
						    WDT_ACT  ? WDT_BUSY : 
						    SCI_ACT  ? 1'b0 : 
	                              BSC_IBUS_BUSY;

	
	SH7604_UBC #(UBC_DISABLE) UBC
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(UBC_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(),
		.IBUS_ACT(UBC_ACT),
		
		.IRQ(UBC_IRQ),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_msby_so),
		.SS_SO(ss_ubc_so)
	);
	
	
	//Clock divider
	bit [12:0] DIV_CNT;
	always @(posedge CLK or negedge RST_N) begin
		
		if (!RST_N) begin
			CLK2_CE <= 0;
			CLK4_CE <= 0;
			CLK8_CE <= 0;
			CLK16_CE <= 0;
			CLK32_CE <= 0;
			CLK64_CE <= 0;
			CLK128_CE <= 0;
			CLK256_CE <= 0;
			CLK512_CE <= 0;
			CLK1024_CE <= 0;
			CLK2048_CE <= 0;
			CLK4096_CE <= 0;
			CLK8192_CE <= 0;
			DIV_CNT <= '0;
		end
		else if (SS_SHIFT) begin
			{DIV_CNT, CLK2_CE, CLK4_CE, CLK8_CE, CLK16_CE, CLK32_CE, CLK64_CE, CLK128_CE, CLK256_CE,
			 CLK512_CE, CLK1024_CE, CLK2048_CE, CLK4096_CE, CLK8192_CE} <= ss_div[25:0];
		end
		else if (!RES_INT_N) begin
			CLK2_CE <= 0;
			CLK4_CE <= 0;
			CLK8_CE <= 0;
			CLK16_CE <= 0;
			CLK32_CE <= 0;
			CLK64_CE <= 0;
			CLK128_CE <= 0;
			CLK256_CE <= 0;
			CLK512_CE <= 0;
			CLK1024_CE <= 0;
			CLK2048_CE <= 0;
			CLK4096_CE <= 0;
			CLK8192_CE <= 0;
			DIV_CNT <= '0;
		end
		else if (CE_R) begin	
			DIV_CNT <= DIV_CNT + 13'd1;
			
			CLK2_CE    <= (DIV_CNT ==? 13'b????????????1);
			CLK4_CE    <= (DIV_CNT ==? 13'b???????????11);
			CLK8_CE    <= (DIV_CNT ==? 13'b??????????111);
			CLK16_CE   <= (DIV_CNT ==? 13'b?????????1111);
			CLK32_CE   <= (DIV_CNT ==? 13'b????????11111);
			CLK64_CE   <= (DIV_CNT ==? 13'b???????111111);
			CLK128_CE  <= (DIV_CNT ==? 13'b??????1111111);
			CLK256_CE  <= (DIV_CNT ==? 13'b?????11111111);
			CLK512_CE  <= (DIV_CNT ==? 13'b????111111111);
			CLK1024_CE <= (DIV_CNT ==? 13'b???1111111111);
			CLK2048_CE <= (DIV_CNT ==? 13'b??11111111111);
			CLK4096_CE <= (DIV_CNT ==? 13'b?111111111111);
			CLK8192_CE <= (DIV_CNT ==? 13'b1111111111111);
		end
	end
	
	bit  [31:0] DBUS_A;
	bit  [31:0] DBUS_DO;
	bit   [3:0] DBUS_BA;
	bit         DBUS_WE;
	bit         DBUS_REQ;
	bit         DBUS_BURST;
	bit         DBUS_LOCK;
	SH7604_DMAC dmac
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		.NMI_N(NMI_N),
		
		.DREQ0(DREQ0),
		.DACK0(DACK0),
		.DREQ1(DREQ1),
		.DACK1(DACK1),
		
		.RXI_IRQ(1'b0),
		.TXI_IRQ(1'b0),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(DMAC_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_ACT(DMAC_ACT),
		
		.DBUS_A(DBUS_A),
		.DBUS_DI(BSC_DBUS_DO),
		.DBUS_DO(DBUS_DO),
		.DBUS_BA(DBUS_BA),
		.DBUS_WE(DBUS_WE),
		.DBUS_REQ(DBUS_REQ),
		.DBUS_BURST(DBUS_BURST),
		.DBUS_LOCK(DBUS_LOCK),
		.DBUS_WAIT(BSC_DBUS_BUSY),
		
		.BSC_ACK(BSC_ACK),
		
		.DMAC0_IRQ(DMAC0_IRQ),
		.DMAC0_VEC(DMAC0_VEC),
		.DMAC1_IRQ(DMAC1_IRQ),
		.DMAC1_VEC(DMAC1_VEC),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_intc_so),
		.SS_SO(ss_dmac_so)
	);
	
	bit  [26:0] IA;
	bit  [31:0] IDI;
	bit  [31:0] IDO;
	bit         IBS_N;
	bit         ICS0_N;
	bit         ICS1_N;
	bit         ICS2_N;
	bit         ICS3_N;
	bit         IRD_WR_N;
	bit         ICE_N;
	bit         IOE_N;
	bit   [3:0] IWE_N;
	bit         IRD_N;
	bit         IIVECF_N;
	bit         BUS_RLS;
	SH7604_BSC #(.AREA_TIMIMG(BUS_AREA_TIMIMG), .SIZE_BYTE_DISABLE(BUS_SIZE_BYTE_DISABLE), .SIZE_WORD_DISABLE(BUS_SIZE_WORD_DISABLE)) bsc
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.CLK4_CE(CLK4_CE),
		.CLK16_CE(CLK16_CE),
		.CLK64_CE(CLK64_CE),
		.CLK256_CE(CLK256_CE),
		.CLK1024_CE(CLK1024_CE),
		.CLK2048_CE(CLK2048_CE),
		.CLK4096_CE(CLK4096_CE),
		
		.A(IA),
		.DI(IDI),
		.DO(IDO),
		.BS_N(IBS_N),
		.CS0_N(ICS0_N),
		.CS1_N(ICS1_N),
		.CS2_N(ICS2_N),
		.CS3_N(ICS3_N),
		.RD_WR_N(IRD_WR_N),
		.CE_N(ICE_N),
		.OE_N(IOE_N),
		.WE_N(IWE_N),
		.RD_N(IRD_N),
		.IVECF_N(IIVECF_N),
		.WAIT_N(WAIT_N),
		.BRLS_N(BRLS_N),
		.BGR_N(BGR_N),
		.RFS(RFS),
		.MD(MD),
		
		.CBUS_A(IBUS_A),
		.CBUS_DI(IBUS_DO),
		.CBUS_DO(BSC_IBUS_DO),
		.CBUS_BA(IBUS_BA),
		.CBUS_WE(IBUS_WE),
		.CBUS_REQ(IBUS_REQ),
		.CBUS_PREREQ(IBUS_PREREQ),
		.CBUS_BURST(IBUS_BURST),
		.CBUS_LOCK(IBUS_LOCK),
		.CBUS_BUSY(BSC_IBUS_BUSY),
		.CBUS_ACT(),
		
		.DBUS_A(DBUS_A),
		.DBUS_DI(DBUS_DO),
		.DBUS_DO(BSC_DBUS_DO),
		.DBUS_BA(DBUS_BA),
		.DBUS_WE(DBUS_WE),
		.DBUS_REQ(DBUS_REQ),
		.DBUS_BURST(DBUS_BURST),
		.DBUS_LOCK(DBUS_LOCK),
		.DBUS_BUSY(BSC_DBUS_BUSY),
		
		.VBUS_A(VBUS_A),
		.VBUS_DO(VBUS_DO),
		.VBUS_REQ(VBUS_REQ),
		.VBUS_BUSY(BSC_VBUS_BUSY),
		
		.IRQ(),
		
		.CACK(BSC_ACK),
		.BUS_RLS(BUS_RLS),
		
		.FAST(FAST),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_cache_so),
		.SS_SO(ss_bsc_so),
		.SS_IDLE(ss_bsc_idle)
	);
	
	assign {A,DO}                                 = !BUS_RLS ? {IA,IDO}                                     : {EA,EDO};
	assign IDI                                    = !BUS_RLS ? DI                                           : EDO;
	// While the savestate chain shifts through their flops, the select and read/write
	// strobes are held inactive, as they are at the T0 park point. BS_N may be low at T0
	// after an SDRAM burst; the 32X only samples it with CE_F, so it is left alone.
	assign BS_N                                   = !BUS_RLS ? IBS_N                                        : EBS_N;
	assign {CS0_N,CS1_N,CS2_N,CS3_N}              = (!BUS_RLS ? {ICS0_N,ICS1_N,ICS2_N,ICS3_N}               : {ECS0_N,ECS1_N,ECS2_N,ECS3_N}) | {4{ss_rot}};
	assign {RD_WR_N,CE_N,OE_N,WE_N,RD_N,IVECF_N}  = (!BUS_RLS ? {IRD_WR_N,ICE_N,IOE_N,IWE_N,IRD_N,IIVECF_N}  : {ERD_WR_N,ECE_N,EOE_N,EWE_N,ERD_N,EIVECF_N}) | {9{ss_rot}};
	assign EDI = DI;
	
	
	SH7604_INTC intc
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		.NMI_N(NMI_N),
		.IRL_N(IRL_N),
		
		.INT_MASK(INT_MASK),
		.INT_ACK(INT_ACK),
		.INT_ACP(INT_ACP),
		.INT_LVL(INT_LVL),
		.INT_VEC(INT_VEC),
		.INT_REQ(INT_REQ),
		.VECT_REQ(VECT_REQ),
		.VECT_WAIT(VECT_WAIT),
		
		.NMI_REQ(INTC_NMI_REQ),
		
		.UBC_IRQ(UBC_IRQ),
		.DIVU_IRQ(DIVU_IRQ),
		.DIVU_VEC(DIVU_VEC),
		.DMAC0_IRQ(DMAC0_IRQ),
		.DMAC0_VEC(DMAC0_VEC),
		.DMAC1_IRQ(DMAC1_IRQ),
		.DMAC1_VEC(DMAC1_VEC),
		.WDT_IRQ(ITI_IRQ),
		.BSC_IRQ(1'b0),
		.SCI_ERI_IRQ(ERI_IRQ),
		.SCI_RXI_IRQ(RXI_IRQ),
		.SCI_TXI_IRQ(TXI_IRQ),
		.SCI_TEI_IRQ(TEI_IRQ),
		.FRT_ICI_IRQ(ICI_IRQ),
		.FRT_OCI_IRQ(OCIA_IRQ | OCIB_IRQ),
		.FRT_OVI_IRQ(OVI_IRQ),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(INTC_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(INTC_BUSY),
		.IBUS_ACT(INTC_ACT),
		
		.VBUS_A(VBUS_A),
		.VBUS_DI(VBUS_DO),
		.VBUS_REQ(VBUS_REQ),
		.VBUS_WAIT(BSC_VBUS_BUSY),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_frt_so),
		.SS_SO(ss_intc_so)
	);
	
	SH7604_DIVU divu
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(DIVU_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(DIVU_BUSY),
		.IBUS_ACT(DIVU_ACT),
		
		.IRQ(DIVU_IRQ),
		.VEC(DIVU_VEC),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_dmac_so),
		.SS_SO(ss_divu_so),
		.SS_IDLE(ss_divu_idle)
	);

	SH7604_SCI #(SCI_DISABLE) sci
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.RXD(RXD),
		.TXD(TXD),
		.SCKO(SCKO),
		.SCKI(SCKI),
		
		.CLK4_CE(CLK4_CE),
		.CLK16_CE(CLK16_CE),
		.CLK64_CE(CLK64_CE),
		.CLK256_CE(CLK256_CE),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(SCI_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(),
		.IBUS_ACT(SCI_ACT),
		
		.TEI_IRQ(TEI_IRQ),
		.TXI_IRQ(TXI_IRQ),
		.RXI_IRQ(RXI_IRQ),
		.ERI_IRQ(ERI_IRQ),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_ubc_so),
		.SS_SO(ss_sci_so)
	);
	
	SH7604_FRT frt
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		.SBY(MSBY_SBY),
		
		.FTOA(FTOA),
		.FTOB(FTOB),
		.FTCI(FTCI),
		.FTI(FTI),
		
		.CLK4_CE(CLK4_CE),
		.CLK8_CE(CLK8_CE),
		.CLK32_CE(CLK32_CE),
		.CLK128_CE(CLK128_CE),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(FRT_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(),
		.IBUS_ACT(FRT_ACT),
		
		.ICI_IRQ(ICI_IRQ),
		.OCIA_IRQ(OCIA_IRQ),
		.OCIB_IRQ(OCIB_IRQ),
		.OVI_IRQ(OVI_IRQ),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_wdt_so),
		.SS_SO(ss_frt_so)
	);
	
	SH7604_WDT #(WDT_DISABLE) wdt
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		.SBY(MSBY_SBY),
		.NMI(INTC_NMI_REQ),
		
		.WDTOVF_N(WDTOVF_N),
		
		.CLK2_CE(CLK2_CE),
		.CLK64_CE(CLK64_CE),
		.CLK128_CE(CLK128_CE),
		.CLK256_CE(CLK256_CE),
		.CLK512_CE(CLK512_CE),
		.CLK1024_CE(CLK1024_CE),
		.CLK4096_CE(CLK4096_CE),
		.CLK8192_CE(CLK8192_CE),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(WDT_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(WDT_BUSY),
		.IBUS_ACT(WDT_ACT),
		
		.ITI_IRQ(ITI_IRQ),
		.OVF(WDT_OVF),
		.PRES(WDT_PRES),
		.MRES(WDT_MRES),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_sci_so),
		.SS_SO(ss_wdt_so)
	);
	
	SH7604_MSBY msby
	(
		.CLK(CLK),
		.RST_N(RST_N),
		.CE_R(CE_R),
		.CE_F(CE_F),
		.EN(EN),
		
		.RES_N(RES_INT_N),
		
		.IBUS_A(IBUS_A),
		.IBUS_DI(IBUS_DO),
		.IBUS_DO(MSBY_DO),
		.IBUS_BA(IBUS_BA),
		.IBUS_WE(IBUS_WE),
		.IBUS_REQ(IBUS_REQ),
		.IBUS_BUSY(),
		.IBUS_ACT(MSBY_ACT),
		
		.SLEEP(SLEEP),
		.WDT_OVF(WDT_OVF),
		.SBY(MSBY_SBY),
		
		.SS_SHIFT(SS_SHIFT),
		.SS_SI(ss_bsc_so),
		.SS_SO(ss_msby_so)
	);
	
	assign ss_res  = {RES_SYNC_N, ss_div[26+31:26]};
	assign ss_div  = {DIV_CNT, CLK2_CE, CLK4_CE, CLK8_CE, CLK16_CE, CLK32_CE, CLK64_CE, CLK128_CE, CLK256_CE,
	                  CLK512_CE, CLK1024_CE, CLK2048_CE, CLK4096_CE, CLK8192_CE, ss_padc[SS_PAD+31:SS_PAD]};
	assign ss_padc = {ss_pad, ss_core_so};
	
endmodule
