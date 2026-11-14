package S32X_PKG;

	parameter bit [31:0] S32X_ID = 32'h4D415253;
	
	typedef struct packed		//R/W,A15100
	{
		bit         FM;			//R/W
		bit [ 6: 0] UNSIGNED;
		bit         REN;			//R/W
		bit [ 4: 0] UNSIGNED2;
		bit         RES;			//R/W
		bit         ADEN;			//R/W
	} ADCR_t;
	parameter bit [15:0] ADCR_MASK = 16'h8083;
	parameter bit [15:0] ADCR_INIT = 16'h0000;

	typedef struct packed		//R/W,A15102
	{
		bit [13: 0] UNSIGNED;
		bit         INTS;			//R/W
		bit         INTM;			//R/W
	} ICR_t;
	parameter bit [15:0] ICR_MASK = 16'h0003;
	parameter bit [15:0] ICR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A15104
	{
		bit [13: 0] UNSIGNED;
		bit [ 1: 0] BK;			//R/W
	} BSR_t;
	parameter bit [15:0] BSR_MASK = 16'h0003;
	parameter bit [15:0] BSR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A15106
	{
		bit [ 7: 0] UNSIGNED;
		bit         FULL;			//RO
		bit [ 3: 0] UNSIGNED2;
		bit         M68S;			//R/W
		bit         DMA;			//R/W
		bit         RV;			//R/W
	} DCR_t;
	parameter bit [15:0] DCR_MASK = 16'h0007;
	parameter bit [15:0] DCR_INIT = 16'h0000;
	
	typedef bit [23:0] DSAR_t;	//R/W,A15108,A1510A; R,20004008,2000400A
	parameter bit [23:0] DSAR_MASK = 24'hFFFFFE;
	parameter bit [23:0] DSAR_INIT = 24'h000000;
	
	typedef bit [23:0] DDAR_t;	//R/W,A1510C,A1510E; R,2000400C,2000400E
	parameter bit [23:0] DDAR_MASK = 24'hFFFFFF;
	parameter bit [23:0] DDAR_INIT = 24'h000000;
	
	typedef bit [15:0] DLR_t;	//R/W,A15110; R,20004010
	parameter bit [15:0] DLR_MASK = 16'hFFFC;
	parameter bit [15:0] DLR_INIT = 16'h0000;
	
	typedef bit [15:0] FFDR_t;	//W,A15112; R,20004012
	parameter bit [15:0] FFDR_MASK = 16'hFFFF;
	parameter bit [15:0] FFDR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A1511A
	{
		bit [14: 0] UNSIGNED;
		bit         CM;			//R/W
	} STVR_t;
	parameter bit [15:0] STVR_MASK = 16'h0001;
	parameter bit [15:0] STVR_INIT = 16'h0000;
	
	typedef bit [15:0] CPxR_t;	//R/W,A15120-A1512F,20004020-2000402F
	parameter bit [15:0] CPxR_MASK = 16'hFFFF;
	parameter bit [15:0] CPxR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A15130; R/W,20004030
	{
		bit [ 3: 0] UNSIGNED;
		bit [ 3: 0] TM;			//R by 68k, R/W by SH2
		bit         RTP;			//R by 68k, R/W by SH2
		bit [ 1: 0] UNSIGNED2;
		bit         MONO;			//R/W
		bit [ 1: 0] RMD;			//R/W
		bit [ 1: 0] LMD;			//R/W
	} PWMCR_t;
	parameter bit [15:0] PWMCR_MASK = 16'h0F9F;
	parameter bit [15:0] PWMCR_INIT = 16'h0000;
	
	typedef bit [11:0] CYCR_t;	//R/W,A15132; R/W,20004032
	parameter bit [11:0] CYCR_MASK = 12'hFFF;
	parameter bit [11:0] CYCR_INIT = 12'h000;
	
	typedef struct packed		//R/W,A15134,A15136,A15138; R/W,20004034,20004036,20004038
	{
		bit         FULL;			//R
		bit         EMPTY;		//R
		bit [ 1: 0] UNSIGNED;
		bit [11: 0] PW;			//W
	} PWR_t;
	parameter bit [15:0] PWR_MASK = 16'hCFFF;
	parameter bit [15:0] PWR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,20004000
	{
		bit         FM;			//RW
		bit [ 4: 0] UNSIGNED;
		bit         ADEN;			//RO
		bit         CART;			//RO
		bit         HEN;			//R/W
		bit [ 2: 0] UNSIGNED2;
		bit         V;				//R/W
		bit         H;				//R/W
		bit         CMD;			//R/W
		bit         PWM;			//R/W
	} IMR_t;
	parameter bit [15:0] IMR_MASK = 16'h008F;
	parameter bit [15:0] IMR_INIT = 16'h0000;
	
	typedef bit [15:0] STBR_t;//W,20004002
	parameter bit [15:0] STBR_MASK = 16'h0000;
	parameter bit [15:0] STBR_INIT = 16'h0000;
	
	typedef bit [7:0] HCNTR_t;	//R/W,20004004
	parameter bit [7:0] HCNTR_MASK = 8'hFF;
	parameter bit [7:0] HCNTR_INIT = 8'h00;
	
	typedef bit [15:0] ICLR_t;//W,20004014,20004016,20004018,2000401A,2000401C
	parameter bit [15:0] ICLR_MASK = 16'h0000;
	parameter bit [15:0] ICLR_INIT = 16'h0000;
	
	//VDP registers
	typedef struct packed		//R/W,A15180,20004100
	{
		bit         PAL;			//RO
		bit [ 6: 0] UNSIGNED;
		bit         PRI;			//R/W
		bit         M240;			//R/W
		bit [ 3: 0] UNSIGNED2;
		bit [ 1: 0] M;				//R/W
	} BMMR_t;
	parameter bit [15:0] BMMR_MASK = 16'h80C3;
	parameter bit [15:0] BMMR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A15182,20004102
	{
		bit [14: 0] UNSIGNED;
		bit         SFT;			//R/W
	} PPCR_t;
	parameter bit [15:0] PPCR_MASK = 16'h0001;
	parameter bit [15:0] PPCR_INIT = 16'h0000;
	
	typedef bit [7:0] AFLR_t;	//R/W,A15184,20004104
	parameter bit [7:0] AFLR_MASK = 8'hFF;
	parameter bit [7:0] AFLR_INIT = 8'h00;
	
	typedef bit [15:0] AFAR_t;	//R/W,A15186,20004106
	parameter bit [15:0] AFAR_MASK = 16'hFFFF;
	parameter bit [15:0] AFAR_INIT = 16'h0000;
	
	typedef bit [15:0] AFDR_t;	//R/W,A15188,20004108
	parameter bit [15:0] AFDR_MASK = 16'hFFFF;
	parameter bit [15:0] AFDR_INIT = 16'h0000;
	
	typedef struct packed		//R/W,A1518A,2000410A
	{
		bit         VBLK;			//RO
		bit         HBLK;			//RO
		bit         PEN;			//RO
		bit [10: 0] UNSIGNED;
		bit         FEN;			//RO
		bit         FS;			//R/W
	} FBCR_t;
	parameter bit [15:0] FBCR_MASK = 16'h0001;
	parameter bit [15:0] FBCR_INIT = 16'h0000;

	// Savestate image of the 32X module, in 32-bit words:
	// [master SH-2][slave SH-2][adapter registers][VDP registers][palette][MD BIOS RAM words].
	// The framebuffers and the 32X SDRAM are not in it (the top level saves them).
	// Regions start on power-of-2 boundaries so a word index is the low address bits;
	// the words in the gaps are reserved (read 0, writes ignored).
	// Any change of this layout must bump the image version at the top level.
	localparam int SS_SH_SIZE     = SH7604_PKG::SS_IMAGE_SIZE;
	localparam int SS_SH_SLOT     = 1 << $clog2(SS_SH_SIZE);
	localparam int SS_IF_SIZE     = 19;
	localparam int SS_VDP_SIZE    = 3;
	localparam int SS_PAL_SIZE    = 256;	// one palette entry per word, bits 15:0
	localparam int SS_MDROM_SIZE  = 2;	// MD BIOS RAM bytes 70h-73h (68000 level 4 vector), bits 15:0
	localparam int SS_RUN_SIZE    = 1;	// VCLKs the 32X ran after the 68000 parked, bits 15:0
	localparam int SS_RC_SIZE     = 5;	// DDR3 read cache state (ddram.sv), answered by the top level

	localparam int SS_OFF_MSH     = 0;
	localparam int SS_OFF_SSH     = SS_SH_SLOT;
	// Adapter block of 1024 words: adapter +000h, VDP +020h, SDRAM read cache +040h,
	// palette +100h, MD BIOS +200h, park delay +202h. Word 0 of the read cache block has
	// bit 31 set.
	localparam int SS_OFF_IF      = 2*SS_SH_SLOT > 1024 ? 2*SS_SH_SLOT : 1024;
	localparam int SS_OFF_VDP     = SS_OFF_IF + 'h020;
	localparam int SS_OFF_RC      = SS_OFF_IF + 'h040;
	localparam int SS_OFF_PAL     = SS_OFF_IF + 'h100;
	localparam int SS_OFF_MDROM   = SS_OFF_IF + 'h200;
	localparam int SS_OFF_RUN     = SS_OFF_IF + 'h202;
	localparam int SS_32X_SIZE    = SS_OFF_RUN + SS_RUN_SIZE;

endpackage
