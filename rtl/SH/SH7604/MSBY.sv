module SH7604_MSBY (
	input             CLK,
	input             RST_N,
	input             CE_R,
	input             CE_F,
	input             EN,
	
	input             RES_N,
	
	input      [31:0] IBUS_A,
	input      [31:0] IBUS_DI,
	output     [31:0] IBUS_DO,
	input       [3:0] IBUS_BA,
	input             IBUS_WE,
	input             IBUS_REQ,
	output            IBUS_BUSY,
	output            IBUS_ACT,
	
	input             SLEEP,
	input             WDT_OVF,
	output reg        SBY,
	
	input             SS_SHIFT,
	input      [31:0] SS_SI,
	output     [31:0] SS_SO
);

	import SH7604_PKG::*;
	
	SBYCR_t     SBYCR;
	bit          SLEEP_OLD;
	
	// Savestate chain. The register readback is not wired to the bus, so only SBYCR.SBY
	// is live.
	wire [ 2+31:0] ss_sb = {SBY, SLEEP_OLD, SS_SI};
	wire [ 1+31:0] ss_cr = {SBYCR.SBY, ss_sb[2+31:2]};
	assign SS_SO = ss_cr[1+31:1];
	
	wire REG_SEL = (IBUS_A == 32'hFFFFFE91);
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SBYCR <= SBYCR_INIT;
			// synopsys translate_off
			// synopsys translate_on
		end
		else if (SS_SHIFT) begin
			SBYCR.SBY <= ss_cr[0];
		end
		else if (EN && CE_R) begin
			if (REG_SEL && IBUS_WE && IBUS_REQ) begin
				SBYCR <= IBUS_DI[23:16] & SBYCR_WMASK;
			end
		end
	end
	
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			SBY <= 0;
		end
		else if (SS_SHIFT) begin
			{SBY, SLEEP_OLD} <= ss_sb[1:0];
		end
		else if (EN && CE_R) begin
			SLEEP_OLD <= SLEEP;
			if (SLEEP && !SLEEP_OLD && SBYCR.SBY) begin
				SBY <= 1;
			end
			if (WDT_OVF && SBY) begin
				SBY <= 0;
			end
		end
	end
//	assign SBY = SBYCR.SBY;
	
	bit [31:0] REG_DO;
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			REG_DO <= '0;
		end
		else if (CE_F) begin
			if (REG_SEL && !IBUS_WE && IBUS_REQ) begin
				REG_DO <= {4{SBYCR & SBYCR_RMASK}};
			end
		end
	end
	
	assign IBUS_DO = REG_SEL ? REG_DO : 8'h00;
	assign IBUS_BUSY = 0;
	assign IBUS_ACT = REG_SEL;
	
endmodule
