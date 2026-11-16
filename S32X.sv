//============================================================================
//  FPGAGen port to MiSTer
//  Copyright (c) 2017-2019 Sorgelig
//
//  YM2612 implementation by Jose Tejada Gomez. Twitter: @topapate
//  Original Genesis code: Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com) 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign BUTTONS   = osd_btn;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = rom_download | sav_pending;

assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

wire [1:0] ar = status[49:48];
wire [7:0] arx,ary;

always_comb begin
	case(res) // {V30, H40}
		2'b00: begin // 256 x 224
			arx = 8'd64;
			ary = 8'd49;
		end

		2'b01: begin // 320 x 224
			arx = status[30] ? 8'd10: 8'd64;
			ary = status[30] ? 8'd7 : 8'd49;
		end

		2'b10: begin // 256 x 240
			arx = 8'd128;
			ary = 8'd105;
		end

		2'b11: begin // 320 x 240
			arx = status[30] ? 8'd4 : 8'd128;
			ary = status[30] ? 8'd3 : 8'd105;
		end
	endcase
end

wire       vcrop_en = status[34];
wire [3:0] vcopt    = status[53:50];
reg        en216p;
reg  [4:0] voff;
always @(posedge CLK_VIDEO) begin
	en216p <= ((HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080) && !forced_scandoubler && !scale);
	voff <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
end

wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? arx : (ar - 1'd1)),
	.ARY((!ar) ? ary : 12'd0),
	.CROP_SIZE((en216p & vcrop_en) ? 10'd216 : 10'd0),
	.CROP_OFF(voff),
	.SCALE(status[55:54])
);

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXX XXXXXXXXXXXXXXXXXXX XXXXXXXXXXXXXXXXXXXXXXXX

`include "build_id.v"
localparam CONF_STR = {
	// Four 8 MB savestate slots in DDR3 from 0x3E000000, declared to Main with
	// SS3E000000:800000 (a Sega Channel image carries 4MB of cartridge memory). The 32X
	// SDRAM uses DDR3 at 0x30000000.
	"S32X;SS3E000000:800000;",
	"FS,32X;",
	"-;",
	"O67,Region,JP,US,EU;",
	"O9,Auto Region,Header,Disabled;",
	"D2ORS,Priority,US>EU>JP,EU>US>JP,US>JP>EU,JP>US>EU;",
	"-;",
	/*
	"C,Cheats;",
	"H1OO,Cheats Enabled,Yes,No;",
	"-;",
	*/
	"D0RG,Load Backup RAM;",
	"D0RH,Save Backup RAM;",
	"D0OD,Autosave,Off,On;",
	"-;",

	"P1,Audio & Video;",
	"P1-;",
	"P1oGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1OU,320x224 Aspect,Original,Corrected;",
	"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"d5P1o2,Vertical Crop,Disabled,216p(5x);",
	"d5P1oIL,Crop Offset,0,2,4,8,10,12,-12,-10,-8,-6,-4,-2;",
	"P1oMN,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P1-;",
	"P1OT,Border,No,Yes;",
	"P1oEF,Composite Blend,Off,On,Adaptive;",
	"P1-;",
	"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"P1OB,FM Chip,YM2612,YM3438;",
	"P1ON,HiFi PCM,No,Yes;",

	"P2,Input;",
	"P2-;",
	"P2O4,Swap Joysticks,No,Yes;",
	"P2O5,6 Buttons Mode,No,Yes;",
	"P2o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"P2-;",
	"P2OIJ,Mouse,None,Port1,Port2;",
	"P2OK,Mouse Flip Y,No,Yes;",
	"P2-;",
	"P2oD,Serial,OFF,SNAC;",
	"P2-;",
	"P2o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	"D4P2oA,Gun Fire,Joy,Mouse;",
	"D4P2oBC,Cross,Small,Medium,Big,None;",

	"P3,Miscellaneous;",
	"P3-;",
	"P3o34,ROM Storage,Auto,SDRAM,DDR3;",
	"P3-;",
	"P3OPQ,CPU Turbo,None,Medium,High;",
	"P3OV,Sprite Limit,Normal,High;",
	"P3-;",

	"- ;",
	"H3o0,Enable FM,Yes,No;",
	"H3o1,Enable PSG,Yes,No;",
	"H3-;",
	// Savestate controls. Load is status[67], Save is status[66] and the slot is status[65:64].
	"-;",
	"R[67],Load State;",
	"R[66],Save State;",
	"O[65:64],Savestate Slot,1,2,3,4;",
	"R0,Reset;",
	// Metadata rows follow the selectable rows because Main skips I rows only when drawing.
	// Savestate overlay indices: help, slots 1-4, then save/load per slot.
	"I,",
	"Slot=DPAD|Save/Load=Mode+DPAD,",
	"Active Slot 1,",
	"Active Slot 2,",
	"Active Slot 3,",
	"Active Slot 4,",
	"Save to state 1,",
	"Restore state 1,",
	"Save to state 2,",
	"Restore state 2,",
	"Save to state 3,",
	"Restore state 3,",
	"Save to state 4,",
	"Restore state 4;",
	"J1,A,B,C,Start,Mode,X,Y,Z,Savestate,Pause;",
	"jn,A,B,R,Start,Select,X,Y,L;", // name map to SNES layout.
	"jp,Y,B,A,Start,Select,L,X,R;", // positional map to SNES layout (3 button friendly) 
	"V,v",`BUILD_DATE
};

// 128 bits because the savestate OSD controls are at status[67:64].
wire [127:0] status;
wire        ss_info_req;   // driven by savestate_ui
wire  [7:0] ss_info;
wire  [1:0] buttons;
wire [13:0] joystick_0;    // bit 12 Savestate, bit 13 Pause
wire [11:0] joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;
wire        ioctl_download;
wire        ioctl_wr;
wire [25:0] ioctl_addr;
wire [15:0] ioctl_data;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

// Savestate signals, used by the instances below. The logic is in the Savestates
// section at the end of this file.
wire        ssui_status_upd;
wire  [1:0] ssui_slot;
wire        ss_busy;
wire        ss_load_done;
wire [31:0] ss_state_dout;
wire        ss_cpu_freeze;
wire        ss_release_now;
reg         ss_release_d = 0;   // ss_release_now one clock later: the release of gen and the SVP
wire        ss_div_ok;
reg         ss_freeze_active = 0;

wire        ss_m68k_frozen;
wire  [7:0] ss_m68k_addr;
wire        ss_m68k_wr_en;
wire [15:0] ss_m68k_rd_data;

wire  [1:0] ss_gen_mem_sel;
wire [15:0] ss_gen_mem_addr;
wire        ss_gen_mem_wr_en;
wire [15:0] ss_gen_mem_rd_data;

wire  [1:0] ss_vdp_sel;
wire  [7:0] ss_vdp_addr;
wire        ss_vdp_wr_en;
wire [31:0] ss_vdp_rd_data;
wire        ss_vdp_quiet;
reg         ss_vdp_resume = 0;
wire        ss_vdp_phase_ok;

wire  [8:0] ss_fm_addr;
wire        ss_fm_wr_en;
wire        ss_fm_rd_en;
wire [31:0] ss_fm_rd_data;
wire        ss_fm_ready;

wire         ss_z80_frozen;
wire [211:0] ss_z80_reg;
reg  [211:0] ss_z80_dir;
reg          ss_z80_dirset = 0;
wire         ss_z80_halt;
reg          ss_z80_halt_dir;
wire [119:0] ss_z80_seq;
wire [119:0] ss_z80_seq_dir;
wire   [8:0] ss_z80_bar;
reg    [8:0] ss_z80_bar_dir;
wire   [1:0] ss_z80_ctrl;
reg    [1:0] ss_z80_ctrl_dir;
reg          ss_z80_ext_set = 0;

wire  [2:0] ss_psg_addr;
wire        ss_psg_wr_en;
wire [31:0] ss_psg_rd_data;

wire  [2:0] ss_sys_addr;
wire        ss_sys_wr_en;
wire [31:0] ss_sys_rd_data;
wire        ss_ba_quiet;

wire        ss_sel_eeprom;
wire  [9:0] ss_cart_addr;
wire        ss_cart_wr_en;
wire [31:0] ss_cart_rd_data;

wire        s32x_aden;

wire        ss_32x_parked;
wire        ss_32x_quiet;
wire        ss_sel_32x;
wire [15:0] ss_32x_addr;
wire [31:0] ss_32x_rd_data;

wire        ss_park_engage;   // the clock the 68000, Z80, 32X and SVP all park on
wire        s32x_can_park;

reg         ss_ssm_req = 0;
reg         ss_ssm_we;
reg         ss_ssm_cache = 0;
reg  [17:2] ss_ssm_addr;
reg  [31:0] ss_ssm_din;
wire [31:0] ss_ssm_dout;
wire        ss_ssm_ack;
wire [15:0] ss_fb_addr;
wire        ss_fb_we;

wire        ss_sel_svp;
wire [10:0] ss_svp_addr;
wire [31:0] ss_svp_rd;
wire        ss_svp_parked;
wire        svp_can_park;

reg         ss_ddr_req = 0;
reg         ss_ddr_we;
reg  [28:0] ss_ddr_addr;
reg  [63:0] ss_ddr_din;
wire [63:0] ss_ddr_dout;
wire        ss_ddr_ack;

reg         ss_sdr_own = 0;
wire [14:0] ss_sram_addr;
wire        ss_sel_crom;
wire [19:0] ss_crom_addr;
reg         ss_sdr_hi = 0;
reg         ss_sdr_rd = 0, ss_sdr_wr = 0;
reg  [25:1] ss_sdr_a;
reg  [15:0] ss_sdr_d;

wire  [9:0] ss_rfs_cur;
reg   [9:0] ss_rfs_park = 0;

hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_4(joystick_4),
	.joystick_l_analog_0({joy0_y, joy0_x}),
	.joystick_l_analog_1({joy1_y, joy1_x}),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[127:66],ssui_slot,status[63:8],(region_set ? region_req : status[7:6]),status[5:0]}),
	.status_set(region_set | ssui_status_upd),
	.status_menumask({en216p,!gun_mode,1'b1,status[9],~gg_available,~bk_ena}),

	// On-screen "Save 1" / "Load 1" text, driven by savestate_ui.
	.info_req(ss_info_req),
	.info(ss_info),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.sd_lba('{sd_lba}),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din('{sd_buff_din}),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.gamma_bus(gamma_bus),
	.sdram_sz(sdram_sz),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse)
);

wire [1:0] gun_mode = status[41:40];
wire       gun_btn_mode = status[42];

wire code_index = &ioctl_index;
wire rom_download = ioctl_download & ~code_index;
wire code_download = ioctl_download & code_index;

reg osd_btn = 0;
always @(posedge clk_sys) begin
	integer timeout = 0;
	reg     has_bootrom = 0;
	reg     last_rst = 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (rom_download & ioctl_wr & status[0]) has_bootrom <= 1;

	if(last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= ~has_bootrom;
		end
	end
end
///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_ram),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll),
	.locked(locked)
);

wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;
wire        cfg_waitrequest;
reg         cfg_write;
reg   [5:0] cfg_address;
reg  [31:0] cfg_data;

pll_cfg pll_cfg
(
	.mgmt_clk(CLK_50M),
	.mgmt_reset(0),
	.mgmt_waitrequest(cfg_waitrequest),
	.mgmt_read(0),
	.mgmt_readdata(),
	.mgmt_write(cfg_write),
	.mgmt_address(cfg_address),
	.mgmt_writedata(cfg_data),
	.reconfig_to_pll(reconfig_to_pll),
	.reconfig_from_pll(reconfig_from_pll)
);

always @(posedge CLK_50M) begin
	reg pald = 0, pald2 = 0;
	reg [2:0] state = 0;
	reg pal_r;

	pald <= PAL;
	pald2 <= pald;

	cfg_write <= 0;
	if(pald2 == pald && pald2 != pal_r) begin
		state <= 1;
		pal_r <= pald2;
	end

	if(!cfg_waitrequest) begin
		if(state) state<=state+1'd1;
		case(state)
			1: begin
					cfg_address <= 0;
					cfg_data <= 0;
					cfg_write <= 1;
				end
			5: begin
					cfg_address <= 7;
					cfg_data <= pal_r ? 2201376125 : 2537930535;
					cfg_write <= 1;
				end
			7: begin
					cfg_address <= 2;
					cfg_data <= 0;
					cfg_write <= 1;
				end
		endcase
	end
end

wire reset = RESET | status[0] | buttons[1] | region_set;

///////////////////////////////////////////////////
// Code loading for WIDE IO (16 bit)
reg [128:0] gg_code;
wire        gg_available;

// Code layout:
// {clock bit, code flags,     32'b address, 32'b compare, 32'b replace}
//  128        127:96          95:64         63:32         31:0
// Integer values are in BIG endian byte order, so it up to the loader
// or generator of the code to re-arrange them correctly.

always_ff @(posedge clk_sys) begin
	gg_code[128] <= 1'b0;

	if (code_download & ioctl_wr) begin
		case (ioctl_addr[3:0])
			0:  gg_code[111:96]  <= ioctl_data; // Flags Bottom Word
			2:  gg_code[127:112] <= ioctl_data; // Flags Top Word
			4:  gg_code[79:64]   <= ioctl_data; // Address Bottom Word
			6:  gg_code[95:80]   <= ioctl_data; // Address Top Word
			8:  gg_code[47:32]   <= ioctl_data; // Compare Bottom Word
			10: gg_code[63:48]   <= ioctl_data; // Compare top Word
			12: gg_code[15:0]    <= ioctl_data; // Replace Bottom Word
			14: begin
				gg_code[31:16]   <= ioctl_data; // Replace Top Word
				gg_code[128]     <=  1'b1;      // Clock it in
			end
		endcase
	end
end



// Every cartridge, 32X or Mega Drive, runs through the 32X adapter.
wire s32x_rom = 1'b1;

//Genesis
wire [23:1] GEN_VA;
wire [15:0] GEN_VDI, GEN_VDO;
wire        GEN_RNW, GEN_LDS_N, GEN_UDS_N;
wire        GEN_AS_N, GEN_DTACK_N, GEN_ASEL_N;
wire        GEN_RAS2_N, GEN_CAS2_N;
wire        EXT_ROM_N;
wire        EXT_FDC_N;
wire        GEN_VCLK_CE;
wire        GEN_CE0_N;
wire        GEN_LWR_N, GEN_UWR_N, GEN_CAS0_N;
wire        GEN_ROM_CE_N;
wire        GEN_RAM_CE_N;
wire        GEN_TIME_N;
wire        GEN_DOT_CE;
wire        GEN_HBLANK;

//wire [15:0] GEN_MEM_DO;
wire        GEN_MEM_BUSY;
wire        GEN_VBUS_DMA;

wire [7:0] color_lut[16] = '{
	8'd0,   8'd27,  8'd49,  8'd71,
	8'd87,  8'd103, 8'd119, 8'd130,
	8'd146, 8'd157, 8'd174, 8'd190,
	8'd206, 8'd228, 8'd255, 8'd255
};

wire [3:0] GEN_R, GEN_G, GEN_B;
wire YS_N;
wire EDCLK;
wire vs,hs;
wire ce_pix;
wire hblank, vblank;
wire interlace;
wire [1:0] resolution;

gen gen
(
	.RESET_N(~reset),
	.MCLK(clk_sys),
	
	.VA(GEN_VA),
	.VDI(GEN_VDI),
	.VDO(GEN_VDO),
	.RNW(GEN_RNW),
	.LDS_N(GEN_LDS_N),
	.UDS_N(GEN_UDS_N),
	.AS_N(GEN_AS_N),
	.DTACK_N(GEN_DTACK_N),
	.ASEL_N(GEN_ASEL_N),
	.VCLK_CE(GEN_VCLK_CE),
	.CE0_N(GEN_CE0_N),
	.RAS2_N(GEN_RAS2_N),
	.CAS2_N(GEN_CAS2_N),
	.ROM_N(EXT_ROM_N),
	.FDC_N(EXT_FDC_N),
	.CART_N(0),
	.DISK_N(1),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CAS0_N(GEN_CAS0_N),
	.TIME_N(GEN_TIME_N),

	.LOADING(rom_download),
	.EXPORT(|status[7:6]),
	.PAL(PAL),

	.RED(GEN_R),
	.GREEN(GEN_G),
	.BLUE(GEN_B),
	.YS_N(YS_N),
	.EDCLK(EDCLK),
	.VS(vs),
	.HS(hs),
	.HBL(GEN_HBLANK),
	.VBL(vblank),
	.BORDER(status[29]),
	.DOT_CE(GEN_DOT_CE),
	.FIELD(VGA_F1),
	.INTERLACE(interlace),
	.RESOLUTION(resolution),

	.J3BUT(~status[5]),
	.JOY_1(status[4] ? joystick_1 : joystick_0[11:0]),
	.JOY_2(status[4] ? joystick_0[11:0] : joystick_1),
	.JOY_3(joystick_2),
	.JOY_4(joystick_3),
	.JOY_5(joystick_4),
	.MULTITAP(status[22:21]),

	.MOUSE(ps2_mouse),
	.MOUSE_OPT(status[20:18]),

	.GUN_OPT(|gun_mode),
	.GUN_TYPE(gun_type),
	.GUN_SENSOR(lg_sensor),
	.GUN_A(lg_a),
	.GUN_B(lg_b),
	.GUN_C(lg_c),
	.GUN_START(lg_start),

	.SERJOYSTICK_IN(SERJOYSTICK_IN),
	.SERJOYSTICK_OUT(SERJOYSTICK_OUT),
	.SER_OPT(SER_OPT),

	.EN_GEN_FM(EN_GEN_FM),
	.EN_GEN_PSG(EN_GEN_PSG),
	.EN_32X_PWM(EN_32X_PWM),
	.EN_HIFI_PCM(status[23]), // Option "N"
	.LADDER(~status[8]),
	.LPF_MODE(status[15:14]),
	.FMBUSY_QUIRK(fmbusy_quirk),

	.EXT_SL(S32X_SL),
	.EXT_SR(S32X_SR),

	.DAC_LDATA(AUDIO_L),
	.DAC_RDATA(AUDIO_R),

	.OBJ_LIMIT_HIGH(status[31]),

	.MEM_RDY(~GEN_MEM_BUSY),
	.VBUS_DMA(GEN_VBUS_DMA),
	.ROM_DMA_DEC(svp_quirk),
	.GG_RESET(code_download && ioctl_wr && !ioctl_addr),
	.GG_EN(status[24]),
	.GG_CODE({~gg_code[95] & gg_code[128], gg_code[127:0]}),
	.GG_AVAILABLE(gg_available),
	
	.PAUSE_EN(1'b0),          // the Pause key now holds the whole core, see pausekey
	.BGA_EN(VDP_BGA_EN),
	.BGB_EN(VDP_BGB_EN),
	.SPR_EN(VDP_SPR_EN),
	.BG_GRID_EN(VDP_BG_GRID_EN),
	.SPR_GRID_EN(VDP_SPR_GRID_EN),

	.SS_FREEZE(ss_cpu_freeze),
	.SS_RELEASE(ss_release_d),
	.SS_EXT_CAN(svp_can_park & s32x_can_park),
	.SS_ENGAGE(ss_park_engage),
	.SS_DIV_OK(ss_div_ok),
	.SS_M68K_FROZEN(ss_m68k_frozen),
	.SS_M68K_ADDR(ss_m68k_addr),
	.SS_M68K_WR_DATA(ss_state_dout[15:0]),
	.SS_M68K_WR_EN(ss_m68k_wr_en),
	.SS_M68K_RD_DATA(ss_m68k_rd_data),

	.SS_ACTIVE(ss_freeze_active),
	.SS_MEM_SEL(ss_gen_mem_sel),
	.SS_MEM_ADDR(ss_gen_mem_addr),
	.SS_MEM_WR_DATA(ss_state_dout[15:0]),
	.SS_MEM_WR_EN(ss_gen_mem_wr_en),
	.SS_MEM_RD_DATA(ss_gen_mem_rd_data),

	.SS_VDP_SEL(ss_vdp_sel),
	.SS_VDP_ADDR(ss_vdp_addr),
	.SS_VDP_WR_DATA(ss_state_dout),
	.SS_VDP_WR_EN(ss_vdp_wr_en),
	.SS_VDP_RD_DATA(ss_vdp_rd_data),
	.SS_VDP_QUIET(ss_vdp_quiet),
	// The VDP latches its park position on the park clock P (ss_park_engage).
	.SS_VDP_PARK(ss_m68k_frozen | ss_park_engage | ss_freeze_active),
	.SS_VDP_RESUME(ss_vdp_resume),
	.SS_VDP_PHASE_OK(ss_vdp_phase_ok),

	.SS_FM_ADDR(ss_fm_addr),
	.SS_FM_WR_DATA(ss_state_dout),
	.SS_FM_WR_EN(ss_fm_wr_en),
	.SS_FM_RD_EN(ss_fm_rd_en),
	.SS_FM_RD_DATA(ss_fm_rd_data),
	.SS_FM_READY(ss_fm_ready),
	.SS_FM_REPLAY(ss_load_done),
	.SS_FM_REPLAYING(),

	.SS_Z80_FROZEN(ss_z80_frozen),
	.SS_Z80_REG(ss_z80_reg),
	.SS_Z80_DIR(ss_z80_dir),
	.SS_Z80_DIRSET(ss_z80_dirset),
	.SS_Z80_HALT(ss_z80_halt),
	.SS_Z80_HALT_DIR(ss_z80_halt_dir),
	.SS_Z80_SEQ(ss_z80_seq),
	.SS_Z80_SEQ_DIR(ss_z80_seq_dir),
	.SS_Z80_BAR(ss_z80_bar),
	.SS_Z80_BAR_DIR(ss_z80_bar_dir),
	.SS_Z80_CTRL(ss_z80_ctrl),
	.SS_Z80_CTRL_DIR(ss_z80_ctrl_dir),
	.SS_Z80_EXT_SET(ss_z80_ext_set),

	.SS_PSG_ADDR(ss_psg_addr),
	.SS_PSG_WR_DATA(ss_state_dout),
	.SS_PSG_WR_EN(ss_psg_wr_en),
	.SS_PSG_RD_DATA(ss_psg_rd_data),

	.SS_SYS_ADDR(ss_sys_addr),
	.SS_SYS_WR_DATA(ss_state_dout),
	.SS_SYS_WR_EN(ss_sys_wr_en),
	.SS_SYS_RD_DATA(ss_sys_rd_data),
	.SS_BA_QUIET(ss_ba_quiet)
);

// The SVP DRAM sits in the RAS2 area, which otherwise answers at once: its accesses wait
// for the SVP's DTACK.
assign GEN_MEM_BUSY = svp_dram_area               ? 1'b1 :
                      !GEN_RAS2_N                  ? 1'b0 : 
                      CART_SRAM_RD || CART_SRAM_WR ? sdr_busy[2] : 
							                                sdr_busy[1];

assign GEN_VDI = (svp_reg_area | svp_dram_area) ? SVP_BUS_DO : s32x_rom ? S32X_VDO : CART_VDO;
assign GEN_DTACK_N = S32X_DTACK_N & CART_DTACK_N & SVP_DTACK_N;

// 32X
wire [23:1] S32X_CA;
wire [15:0] S32X_CDO;
wire [15:0] S32X_CDI;
wire        S32X_CASEL_N;
wire        S32X_CLWR_N;
wire        S32X_CUWR_N;
wire        S32X_CCE0_N;
wire        S32X_CCAS0_N;
wire        S32X_CCAS2_N;

wire [15:0] S32X_VDO;
wire        S32X_DTACK_N;

wire [17:1] S32X_SDR_A;
wire [15:0] S32X_SDR_DO;
reg  [15:0] S32X_SDR_DI;
wire        S32X_SDR_CS;
wire  [1:0] S32X_SDR_WE;
wire        S32X_SDR_RD;
wire        S32X_SDR_WAIT;

wire [15:0] S32X_MEM_DO;
wire        S32X_ROM_WAIT;

wire [15:0] S32X_FB0_A;
wire [15:0] S32X_FB0_DI;
wire [15:0] S32X_FB0_DO;
wire  [1:0] S32X_FB0_WE;
wire        S32X_FB0_RD;
wire [15:0] S32X_FB1_A;
wire [15:0] S32X_FB1_DI;
wire [15:0] S32X_FB1_DO;
wire  [1:0] S32X_FB1_WE;
wire        S32X_FB1_RD;
	
wire        S32X_DOT_CE;
wire  [4:0] S32X_R;
wire  [4:0] S32X_G;
wire  [4:0] S32X_B;
wire        S32X_YSO_N;
wire        S32X_HBLANK;

wire [15:0] S32X_SL;
wire [15:0] S32X_SR;

S32X #(
	.USE_ROM_WAIT(1),
	.USE_ASYNC_FB(0)
) S32X
(
	.RST_N(~(reset | rom_download)),
	.CLK(clk_sys),

	.VCLK(GEN_VCLK_CE),
	.VA(GEN_VA),
	.VDI(GEN_VDO),
	.VDO(S32X_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(S32X_DTACK_N),
	.LWR_N(GEN_LWR_N),
	.UWR_N(GEN_UWR_N),
	.CE0_N(GEN_CE0_N),
	.CAS0_N(GEN_CAS0_N),
	.CAS2_N(GEN_CAS2_N),
	.ASEL_N(GEN_ASEL_N),
	.VRES_N(1'b1),
	.MRES_N(1'b1),
	.CART_N(1'b0),
	
	.VSYNC_N(vs),
	.HSYNC_N(hs),
	.EDCLK(EDCLK),
	.YS_N(YS_N),
	.PAL(PAL),
	
	.CA(S32X_CA),
	.CDI(S32X_CDI),
	.CDO(S32X_CDO),
	.CASEL_N(S32X_CASEL_N),
	.CLWR_N(S32X_CLWR_N),
	.CUWR_N(S32X_CUWR_N),
	.CCE0_N(S32X_CCE0_N),
	.CCAS0_N(S32X_CCAS0_N),
	.CCAS2_N(S32X_CCAS2_N),
	.ROM_WAIT(S32X_ROM_WAIT),
	
	.SDR_A(S32X_SDR_A),
	.SDR_DI(S32X_SDR_DI),
	.SDR_DO(S32X_SDR_DO),
	.SDR_CS(S32X_SDR_CS),
	.SDR_WE(S32X_SDR_WE),
	.SDR_RD(S32X_SDR_RD),
	.SDR_WAIT(S32X_SDR_WAIT),
	
	.FB0_A(S32X_FB0_A),
	.FB0_DI(S32X_FB0_DI),
	.FB0_DO(S32X_FB0_DO),
	.FB0_WE(S32X_FB0_WE),
	.FB0_RD(S32X_FB0_RD),
	.FB1_A(S32X_FB1_A),
	.FB1_DI(S32X_FB1_DI),
	.FB1_DO(S32X_FB1_DO),
	.FB1_WE(S32X_FB1_WE),
	.FB1_RD(S32X_FB1_RD),
	
	.DOT_CE(S32X_DOT_CE),
	.R(S32X_R),
	.G(S32X_G),
	.B(S32X_B),
	.YSO_N(S32X_YSO_N),
	.HBL(S32X_HBLANK),

	.PWM_L(S32X_SL),
	.PWM_R(S32X_SR),

	.ADEN(s32x_aden),

	// The 32X parks on the clock the 68000 does (see the savestate section). It is held
	// from P (where it skips its burst) and runs again on the release clock, a VCLK at
	// the phase of P, while gen resumes one clock later.
	.SS_PHASE_HOLD(ss_park_engage | (ss_m68k_frozen & ~ss_release_now & ~ss_release_d)),
	.SS_PARK_REQ(ss_m68k_frozen),
	.SS_PARK_ENGAGE(ss_park_engage),
	.SS_CAN_PARK(s32x_can_park),
	.SS_RELEASE(ss_release_now),
	.SS_PARKED(ss_32x_parked),
	.SS_QUIET(ss_32x_quiet),
	.SS_ACTIVE(ss_freeze_active),
	.SS_SEL(ss_freeze_active & ss_sel_32x),
	.SS_ADDR(ss_32x_addr),
	.SS_WR_EN(ss_state_we & ss_sel_32x),
	.SS_WR_DATA(ss_state_dout),
	.SS_RD_DATA(ss_32x_rd_data)
);
assign S32X_CDI = CART_VDO;
assign S32X_ROM_WAIT = CART_SRAM_RD || CART_SRAM_WR ? sdr_busy[2] : sdr_busy[1];


//Cart
wire [15:0] CART_VDO;
wire        CART_DTACK_N;

wire [24:1] CART_ROM_A;
wire [15:0] CART_ROM_DI;
wire [15:0] CART_ROM_DO;
wire        CART_ROM_WRL;
wire        CART_ROM_WRH;
wire        CART_ROM_RD;

wire [15:1] CART_SRAM_A;
wire  [7:0] CART_SRAM_DI;
wire  [7:0] CART_SRAM_DO;
wire        CART_SRAM_WR;
wire        CART_SRAM_RD;
wire        CART_EP_RD, CART_EP_WR;
wire        CART_ROM_BANK_HI;
CART cart
(
	.CLK(clk_sys),
	.RST_N(~(reset || rom_download)),
	
	.VCLK(GEN_VCLK_CE),
	.VA(!s32x_rom ? GEN_VA : S32X_CA),
	.VDI(!s32x_rom ? GEN_VDO : S32X_CDO),
	.VDO(CART_VDO),
	.AS_N(GEN_AS_N),
	.DTACK_N(CART_DTACK_N),
	.LWR_N(!s32x_rom ? GEN_LWR_N : S32X_CLWR_N),
	.UWR_N(!s32x_rom ? GEN_UWR_N : S32X_CUWR_N),
	.CE0_N(!s32x_rom ? GEN_CE0_N : S32X_CCE0_N),
	.CAS0_N(!s32x_rom ? GEN_CAS0_N : S32X_CCAS0_N),
	.CAS2_N(!s32x_rom ? GEN_CAS2_N : S32X_CCAS2_N),
	.ASEL_N(!s32x_rom ? GEN_ASEL_N : S32X_CASEL_N),
	.TIME_N(GEN_TIME_N),
	
	.ROM_A(CART_ROM_A),
	.ROM_DI(CART_ROM_DI),
	.ROM_DO(CART_ROM_DO),
	.ROM_RD(CART_ROM_RD),
	.ROM_WRL(CART_ROM_WRL),
	.ROM_WRH(CART_ROM_WRH),
	
	.SRAM_A(CART_SRAM_A),
	.SRAM_DI(CART_SRAM_DI),
	.SRAM_DO(CART_SRAM_DO),
	.SRAM_RD(CART_SRAM_RD),
	.SRAM_WR(CART_SRAM_WR),
	.EP_RD(CART_EP_RD),
	.EP_WR(CART_EP_WR),
	
	.rom_sz(rom_sz),
	.s32x(s32x_rom),
	.eeprom_map(eeprom_map),
	.noram_quirk(noram_quirk | svp_quirk), // the SVP DRAM is where SRAM would be
	.pier_quirk(pier_quirk),
	.realtec_map(realtec_map),
	.sf_map(sf_map),
	.ROM_BANK_HI(CART_ROM_BANK_HI),

	.SS_ACTIVE(ss_freeze_active),
	.SS_SEL(ss_sel_eeprom),
	.SS_ADDR(ss_cart_addr),
	.SS_WR_DATA(ss_state_dout),
	.SS_WR_EN(ss_cart_wr_en),
	.SS_RD_DATA(ss_cart_rd_data)
);
assign CART_ROM_DI = sdr_do[1];
assign CART_SRAM_DI = sdr_do[2][7:0];

// SVP (Virtua Racing). The SSP1601 and its interface answer on the Mega Drive bus:
// registers at A15000-A1500F, DRAM at 300000-37FFFF and its two cell-arranged views at
// 390000 and 3A0000. With a Mega Drive cartridge the 32X passes that bus through
// unchanged, so the SVP takes it straight from gen, off the SH-2 paths. Its 128KB DRAM is
// framebuffer 1, which a Mega Drive cartridge leaves to no one, so the framebuffer region
// of the savestate carries it. Its program reads take SDRAM channel 0, which the 32X
// SDRAM (in DDR3) leaves free.
wire svp_reg_area  = svp_quirk && GEN_VA[23:4] == 20'hA1500;
wire svp_dram_area = svp_quirk && (GEN_VA[23:19] == 5'b00110 || GEN_VA[23:16] == 8'h39 || GEN_VA[23:16] == 8'h3A);

wire [15:0] SVP_BUS_DO;
wire        SVP_DTACK_N;
wire [20:1] SVP_ROM_A;
wire        SVP_ROM_REQ;
wire [15:0] SVP_DRAM_A;
wire [15:0] SVP_DRAM_DO;
wire        SVP_DRAM_WE;

// The DSP stops with the 68000 at its park and runs again with it (ss_release_d). Its
// memory controller is not under the clock enable, so the park waits for a clock where
// it has nothing in flight (SS_PARKED, program read handshake and SDRAM channel at rest)
// and the DSP takes no enable: then nothing in the SVP moves while it is held, and it
// resumes exactly where the 68000 does. The enable phase is kept across the stop and in
// the savestate (word 3FF of the SVP block).
// The enable is low while the SVP is in reset, so the first clock after it never enables
// the DSP (as SVP_CLKEN in the Genesis core). On that clock the program fetch of 400h
// starts; an enable there would execute the empty instruction register and advance PC,
// leaving the fetches one word behind PC: the boot code then misses its wait for the
// 68000 and Virtua Racing stops at "Communication Error" with a black screen.
wire svp_hold = ss_m68k_frozen & ~ss_release_d;
reg  svp_ce_ph = 0;
always @(posedge clk_sys) begin
	if(!svp_quirk || reset || rom_download) svp_ce_ph <= 0;
	else if(!svp_hold) svp_ce_ph <= ~svp_ce_ph;
	if(ss_state_we && ss_sel_svp && ss_svp_addr == 11'h3FF) svp_ce_ph <= ss_state_dout[0];
end

SVP svp
(
	.CLK(clk_sys),
	.CE(svp_ce_ph & ~svp_hold),
	.RST_N(~(reset | rom_download) & svp_quirk),
	.ENABLE(1'b1),

	.BUS_A(GEN_VA),
	.BUS_DO(SVP_BUS_DO),
	.BUS_DI(GEN_VDO),
	.BUS_SEL(svp_quirk & (~GEN_CAS0_N | ~GEN_LWR_N | ~GEN_UWR_N)),
	.BUS_RNW(GEN_LWR_N & GEN_UWR_N),
	.BUS_DTACK_N(SVP_DTACK_N),
	.DMA_ACTIVE(GEN_VBUS_DMA),

	.ROM_A(SVP_ROM_A),
	.ROM_DI(svp_rom_q),
	.ROM_REQ(SVP_ROM_REQ),
	.ROM_ACK(svp_rom_ack),

	.DRAM_A(SVP_DRAM_A),
	.DRAM_DI(S32X_FB1_DI),
	.DRAM_DO(SVP_DRAM_DO),
	.DRAM_WE(SVP_DRAM_WE),

	.SS_ADDR(ss_svp_addr),
	.SS_RD_DATA(ss_svp_rd),
	.SS_WR_DATA(ss_state_dout),
	.SS_WR_EN(ss_state_we & ss_sel_svp),
	.SS_ACTIVE(ss_freeze_active),
	.SS_PARKED(ss_svp_parked)
);

// Program reads: one SDRAM read per toggle of ROM_REQ; ROM_ACK toggles back with the data.
reg  [20:1] svp_rom_a_l;
reg  [15:0] svp_rom_q;
reg         svp_rom_ack = 0;
reg         svp_rom_rd = 0;
reg   [1:0] svp_rom_st = 0;
always @(posedge clk_sys) begin
	if(!svp_quirk || reset) begin
		svp_rom_st <= 0; svp_rom_rd <= 0; svp_rom_ack <= SVP_ROM_REQ;
	end else case(svp_rom_st)
		2'd0: if(SVP_ROM_REQ != svp_rom_ack) begin
			svp_rom_a_l <= SVP_ROM_A;
			svp_rom_rd  <= 1;
			svp_rom_st  <= 2'd1;
		end
		// The controller took the request (busy rises): drop the strobe.
		2'd1: if(sdr_busy[0]) begin
			svp_rom_rd <= 0;
			svp_rom_st <= 2'd2;
		end
		// dout is valid as busy falls.
		2'd2: if(!sdr_busy[0]) begin
			svp_rom_q   <= sdr_do[0];
			svp_rom_ack <= ~svp_rom_ack;
			svp_rom_st  <= 2'd0;
		end
		default: svp_rom_st <= 2'd0;
	endcase
end

// See svp_hold: the 68000 parks only on a clock where the SVP can stop with nothing in
// flight.
assign svp_can_park = ~svp_quirk | (ss_svp_parked & ~svp_ce_ph & ~svp_rom_rd & ~sdr_busy[0] &
                                    svp_rom_st == 2'd0 & SVP_ROM_REQ == svp_rom_ack);

always @(posedge clk_sys) begin
	reg old_busy;
	
	old_busy <= sdr_busy[3];
	if(rom_download & ioctl_wr) ioctl_wait <= 1;
	if(old_busy & ~sdr_busy[3]) ioctl_wait <= 0;
end

wire ddr_busy;
wire [15:0] ddr_do;
ddram ddram
(
	.*,

	.clk(clk_ram),
	.rst(reset),

	.ramh_addr(S32X_SDR_A),
	.ramh_dout(ddr_do),
	.ramh_din(S32X_SDR_DO),
	.ramh_rd(S32X_SDR_CS & S32X_SDR_RD),
	.ramh_wr({2{S32X_SDR_CS}} & S32X_SDR_WE),
	.ramh_busy(ddr_busy),

	.ss_req(ss_ddr_req),
	.ss_we(ss_ddr_we),
	.ss_addr(ss_ddr_addr),
	.ss_din(ss_ddr_din),
	.ss_dout(ss_ddr_dout),
	.ss_ack(ss_ddr_ack),

	// 32X SDRAM region of the savestate, straight to DDR3 (keeps the SH-2 port as is).
	.ssm_req(ss_ssm_req),
	.ssm_we(ss_ssm_we),
	.ssm_cache(ss_ssm_cache),
	.ssm_addr(ss_ssm_addr),
	.ssm_din(ss_ssm_din),
	.ssm_dout(ss_ssm_dout),
	.ssm_ack(ss_ssm_ack)
);
assign S32X_SDR_DI   = ddr_do;
assign S32X_SDR_WAIT = ddr_busy;

wire sdr_busy[4];
wire [15:0] sdr_do[4];
sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_ram),

	//SVP program reads (the 32X SDRAM is in DDR3)
	.addr0({5'b00000,svp_rom_a_l}),
	.din0(16'd0),
	.dout0(sdr_do[0]),
	.rd0(svp_rom_rd),
	.wr0(2'b00),
	.busy0(sdr_busy[0]),

	//CART ROM
	.addr1({1'b0,CART_ROM_A[24:1]}),
	.din1(CART_ROM_DO),
	.dout1(sdr_do[1]),
	.rd1(CART_ROM_RD | CART_ROM_WRL | CART_ROM_WRH),
	.wr1({CART_ROM_WRH,CART_ROM_WRL} & {2{schan_quirk}}),
	.busy1(sdr_busy[1]),

	//CART SRAM
	.addr2({10'b1100000000,CART_SRAM_A[15:1]}),	//CART RAM 3000000-300FFFF
	.din2({8'hFF,CART_SRAM_DO}),
	.dout2(sdr_do[2]),
	.rd2(CART_SRAM_RD | CART_EP_RD),
	.wr2({2{CART_SRAM_WR | CART_EP_WR}}),
	.busy2(sdr_busy[2]),
	
	//ROM/BRAM Load/Save. The savestate streams the cart SRAM, or the writable cart ROM of
	//a Sega Channel cartridge, two halfwords per state word.
	.addr3(ss_sdr_own ? ss_sdr_a : rom_download ? {1'b0,ioctl_addr[24:1]} : {10'b1100000000,sd_lba[6:0],tmpram_addr}),
	.din3(ss_sdr_own ? ss_sdr_d : rom_download ? {ioctl_data[7:0],ioctl_data[15:8]} : {tmpram_dout[7:0],tmpram_dout[15:8]}),
	.dout3(sdr_do[3]),
	.rd3(ss_sdr_own ? ss_sdr_rd : rom_download ? 1'b0 : (tmpram_req & ~bk_loading)),
	.wr3(ss_sdr_own ? {2{ss_sdr_wr}} : rom_download ? {2{ioctl_wait}} : {2{tmpram_req & bk_loading}}),
	.busy3(sdr_busy[3]),

	.ss_rfs_cur(ss_rfs_cur),
	.ss_rfs_set(ss_release_d),
	.ss_rfs_val(ss_rfs_park ? ss_rfs_park - 1'd1 : 10'd0)
);

// The SDRAM refresh timer one clock after the park clock P, kept with the raster and
// divider phases (SYS word 6, bits 13-4). The release of gen, one clock after the
// release clock, loads it back, one count on for the clk_ram edge that latched it, so a
// resumed CPU meets the same refresh stalls.
reg        ss_m68k_frozen_d = 0;
always @(posedge clk_sys) begin
	ss_m68k_frozen_d <= ss_m68k_frozen;
	if(ss_m68k_frozen & ~ss_m68k_frozen_d) ss_rfs_park <= ss_rfs_cur;
	if(ss_sys_wr_en && ss_sys_addr == 3'd6) ss_rfs_park <= ss_state_dout[13:4];
end

// The framebuffers are one savestate region: word N is {FB1[N], FB0[N]}. Port B of each
// framebuffer belongs to the stream, so scanout keeps reading port A: a save leaves the
// picture as it is, and a load shows the restored picture as it is written. With an SVP
// cartridge FB1 is the SVP DRAM.
wire [15:0] fb1_a  = svp_quirk ? SVP_DRAM_A : S32X_FB1_A;
wire [15:0] fb1_d  = svp_quirk ? SVP_DRAM_DO : S32X_FB1_DO;
wire  [1:0] fb1_we = svp_quirk ? {2{SVP_DRAM_WE}} : S32X_FB1_WE;
wire [15:0] ss_fb0_q, ss_fb1_q;

`ifdef MISTER_DUAL_SDRAM
wire sdr2_busy;
wire [15:0] sdr2_do;
sdram2 sdram2
(
	.SDRAM_CLK(SDRAM2_CLK),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nCAS(SDRAM2_nCAS),
	
	.init(~locked),
	.clk(clk_ram),

	//
	.addr0({8'b00000000,S32X_FB0_A}), // 0000000-001FFFF
	.din0(S32X_FB0_DO),
	.dout0(S32X_FB0_DI),
	.rd0(S32X_FB0_RD),
	.wrl0(S32X_FB0_WE[0]),
	.wrh0(S32X_FB0_WE[1]),
	.busy0(sdr2_busy),

	//
	.addr1('0),
	.din1('0),
	.dout1(),
	.rd1(0),
	.wrl1(0),
	.wrh1(0),
	.busy1(),

	//
	.addr2('0),
	.din2('0),
	.dout2(),
	.rd2(0),
	.wrl2(0),
	.wrh2(0),
	.busy2()
);
// FB0 sits in the second SDRAM here, outside the savestate ports.
assign ss_fb0_q = S32X_FB0_DI;

`else

dpram #(16,8) vdp_fb0_l
(
	.clock(clk_sys),
	.address_a(S32X_FB0_A),
	.data_a(S32X_FB0_DO[7:0]),
	.wren_a(S32X_FB0_WE[0]),
	.q_a(S32X_FB0_DI[7:0]),
	.address_b(ss_fb_addr),
	.data_b(ss_state_dout[7:0]),
	.wren_b(ss_fb_we),
	.q_b(ss_fb0_q[7:0])
);

dpram #(16,8) vdp_fb0_u
(
	.clock(clk_sys),
	.address_a(S32X_FB0_A),
	.data_a(S32X_FB0_DO[15:8]),
	.wren_a(S32X_FB0_WE[1]),
	.q_a(S32X_FB0_DI[15:8]),
	.address_b(ss_fb_addr),
	.data_b(ss_state_dout[15:8]),
	.wren_b(ss_fb_we),
	.q_b(ss_fb0_q[15:8])
);

`endif

dpram #(16,8) vdp_fb1_l
(
	.clock(clk_sys),
	.address_a(fb1_a),
	.data_a(fb1_d[7:0]),
	.wren_a(fb1_we[0]),
	.q_a(S32X_FB1_DI[7:0]),
	.address_b(ss_fb_addr),
	.data_b(ss_state_dout[23:16]),
	.wren_b(ss_fb_we),
	.q_b(ss_fb1_q[7:0])
);

dpram #(16,8) vdp_fb1_u
(
	.clock(clk_sys),
	.address_a(fb1_a),
	.data_a(fb1_d[15:8]),
	.wren_a(fb1_we[1]),
	.q_a(S32X_FB1_DI[15:8]),
	.address_b(ss_fb_addr),
	.data_b(ss_state_dout[31:24]),
	.wren_b(ss_fb_we),
	.q_b(ss_fb1_q[15:8])
);



wire [7:0] r, g, b;
always_comb begin
	if ((VDP_MD_EN && !VDP_32X_EN) || !s32x_rom) begin
		r = color_lut[GEN_R];
		g = color_lut[GEN_G];
		b = color_lut[GEN_B];
	end else if (!VDP_MD_EN && VDP_32X_EN) begin
		r = {S32X_R,S32X_R[4:2]};
		g = {S32X_G,S32X_G[4:2]};
		b = {S32X_B,S32X_B[4:2]};
	end else begin
		r = !S32X_YSO_N ? {S32X_R,S32X_R[4:2]} : color_lut[GEN_R];
		g = !S32X_YSO_N ? {S32X_G,S32X_G[4:2]} : color_lut[GEN_G];
		b = !S32X_YSO_N ? {S32X_B,S32X_B[4:2]} : color_lut[GEN_B];
	end
end

assign hblank = s32x_rom ? S32X_HBLANK : GEN_HBLANK;
assign ce_pix = s32x_rom ? S32X_DOT_CE : GEN_DOT_CE;

/////////////////////////////////////////////////////////////
reg TRANSP_DETECT = 0;
wire cofi_enable = status[46] || (status[47] && TRANSP_DETECT);

wire PAL = status[7];

reg new_vmode;
always @(posedge clk_sys) begin
	reg old_pal;
	int to;
	
	if(~(reset | rom_download)) begin
		old_pal <= PAL;
		if(old_pal != PAL) to <= 5000000;
	end
	else to <= 5000000;
	
	if(to) begin
		to <= to - 1;
		if(to == 1) new_vmode <= ~new_vmode;
	end
end


//lock resolution for the whole frame.
reg [1:0] res;
always @(posedge clk_sys) begin
	reg old_vbl;
	
	old_vbl <= vblank;
	if(old_vbl & ~vblank) res <= resolution;
end

wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_ram;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

reg old_ce_pix;
always @(posedge CLK_VIDEO) old_ce_pix <= ce_pix;

wire [7:0] red, green, blue;

cofi coffee (
	.clk(clk_sys),
	.pix_ce(ce_pix),
	.enable(cofi_enable),

	.hblank(hblank),
	.vblank(vblank),
	.hs(hs),
	.vs(vs),
	.red(r),
	.green(g),
	.blue(b),

	.hblank_out(hblank_c),
	.vblank_out(vblank_c),
	.hs_out(hs_c),
	.vs_out(vs_c),
	.red_out(red),
	.green_out(green),
	.blue_out(blue)
);

wire hs_c,vs_c,hblank_c,vblank_c;

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,
	.ce_pix(~old_ce_pix & ce_pix),
	.scandoubler(~interlace && (scale || forced_scandoubler)),
	.hq2x(scale==1),
	.freeze_sync(),
	// HDMI shows the scaler's last frame while paused (HDMI_FREEZE). The direct analog
	// output keeps the live picture, so the mixer's own freeze (black + sync) stays off.
	.HDMI_FREEZE(1'b0),

	.VGA_DE(vga_de),
	.R((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[0]}} : red),
	.G((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[1]}} : green),
	.B((lg_target && gun_mode && (~&status[44:43])) ? {8{lg_target[2]}} : blue),

	// Positive pulses.
	.HSync(hs_c),
	.VSync(vs_c),
	.HBlank(hblank_c),
	.VBlank(vblank_c)
);

wire [2:0] lg_target;
wire       lg_sensor;
wire       lg_a;
wire       lg_b;
wire       lg_c;
wire       lg_start;

lightgun lightgun
(
	.CLK(clk_sys),
	.RESET(reset),

	.MOUSE(ps2_mouse),
	.MOUSE_XY(&gun_mode),

	.JOY_X(gun_mode[0] ? joy0_x : joy1_x),
	.JOY_Y(gun_mode[0] ? joy0_y : joy1_y),
	.JOY(gun_mode[0] ? joystick_0[11:0] : joystick_1),

	.RELOAD(gun_type),

	.HDE(~hblank_c),
	.VDE(~vblank_c),
	.CE_PIX(ce_pix),
	.H40(res[0]),

	.BTN_MODE(gun_btn_mode),
	.SIZE(status[44:43]),
	.SENSOR_DELAY(gun_sensor_delay),

	.TARGET(lg_target),
	.SENSOR(lg_sensor),
	.BTN_A(lg_a),
	.BTN_B(lg_b),
	.BTN_C(lg_c),
	.BTN_START(lg_start)
);


//////////////////////////////////////////////////////////////////
wire [3:0] hrgn = ioctl_data[3:0] - 4'd7;

reg cart_hdr_ready = 0;
reg hdr_j = 0, hdr_u = 0, hdr_e = 0;
reg  [1:0] region_req;
reg        region_set = 0;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
// F1 to F4 are savestate keys (savestate_ui). The region is set in the OSD or taken
// from the ROM header.
always @(posedge clk_sys) begin
	reg old_ready = 0;

	old_ready <= cart_hdr_ready;
	if(~status[9] & ~old_ready & cart_hdr_ready) begin
		//if(status[8]) begin
			region_set <= 1;
			case(status[28:27])
				0: if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else if(hdr_j) region_req <= 0;
					else region_req <= 1;
				
				1: if(hdr_e) region_req <= 2;
					else if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else region_req <= 2;
				
				2: if(hdr_u) region_req <= 1;
					else if(hdr_j) region_req <= 0;
					else if(hdr_e) region_req <= 2;
					else region_req <= 1;

				3: if(hdr_j) region_req <= 0;
					else if(hdr_u) region_req <= 1;
					else if(hdr_e) region_req <= 2;
					else region_req <= 0;
			endcase
		/*
		end
		else begin
			region_set <= |ioctl_index;
			region_req <= ioctl_index[7:6];
		end
		*/
	end

	if(old_ready & ~cart_hdr_ready) region_set <= 0;
end

reg [25:0] rom_sz;
always @(posedge clk_sys) begin
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) begin
		{hdr_j,hdr_u,hdr_e} <= 0;
	end
	
	if(old_download && ~rom_download) begin
		cart_hdr_ready <= 0;
		rom_sz <= ioctl_addr[25:0];
	end

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
			else if(ioctl_data[7:0] >= "0" && ioctl_data[7:0] <= "9") {hdr_e, hdr_u, hdr_j} <= {ioctl_data[3], ioctl_data[2], ioctl_data[0]};
			else if(ioctl_data[7:0] >= "A" && ioctl_data[7:0] <= "F") {hdr_e, hdr_u, hdr_j} <= {      hrgn[3],       hrgn[2],       hrgn[0]};
		end
		if(ioctl_addr == 'h1F2) begin
			if(ioctl_data[7:0] == "J") hdr_j <= 1;
			else if(ioctl_data[7:0] == "U") hdr_u <= 1;
			else if(ioctl_data[7:0] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h1F0) begin
			if(ioctl_data[15:8] == "J") hdr_j <= 1;
			else if(ioctl_data[15:8] == "U") hdr_u <= 1;
			else if(ioctl_data[15:8] == "E") hdr_e <= 1;
		end
		if(ioctl_addr == 'h200) cart_hdr_ready <= 1;
	end
end

reg [3:0] eeprom_map = '0;
reg realtec_map = 0;
//reg fifo_quirk = 0;
reg noram_quirk = 0;
reg pier_quirk = 0;
reg svp_quirk = 0;
reg fmbusy_quirk = 0;
reg schan_quirk = 0;
reg [2:0] sf_map = '0;
reg gun_type = 0;
reg [7:0] gun_sensor_delay = 8'd44;
always @(posedge clk_sys) begin
	reg [87:0] cart_id;
	reg [15:0] crc = '0;
	reg [31:0] realtec_id = '0;
	reg old_download;
	old_download <= rom_download;

	if(~old_download && rom_download) {/*fifo_quirk,*/eeprom_map,realtec_map,noram_quirk,pier_quirk,svp_quirk,fmbusy_quirk,schan_quirk,sf_map} <= 0;

	if(ioctl_wr & rom_download) begin
		if(ioctl_addr == 'h180) cart_id[87:72] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h182) cart_id[71:56] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h184) cart_id[55:40] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h186) cart_id[39:24] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h188) cart_id[23:08] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h18A) cart_id[07:00] <= ioctl_data[7:0];
		if(ioctl_addr == 'h18E) crc <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h190) begin
			if     (cart_id[63:0] == "T-50446 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93
			else if(cart_id[63:0] == "T-50516 ") eeprom_map        <= 4'b0001; 	// John Madden Football 93 Championship Edition
			else if(cart_id[63:0] == "T-50396 ") eeprom_map        <= 4'b0001; 	// NHLPA Hockey 93
			else if(cart_id[63:0] == "T-50176 ") eeprom_map        <= 4'b0001; 	// Rings of Power
			else if(cart_id[63:0] == "T-50606 ") eeprom_map        <= 4'b0001; 	// Bill Walsh College Football
			else if(cart_id[63:0] == "MK-1215 ") eeprom_map        <= 4'b0010; 	// Evander Real Deal Holyfield's Boxing
			else if(cart_id[63:0] == "G-4060  ") eeprom_map        <= 4'b0010; 	// Wonder Boy
			else if(cart_id[63:0] == "00001211") eeprom_map        <= 4'b0010; 	// Sports Talk Baseball
			else if(cart_id[63:0] == "MK-1228 ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights
			else if(cart_id[63:0] == "G-5538  ") eeprom_map        <= 4'b0010; 	// Greatest Heavyweights JP
			else if(cart_id[63:0] == "00004076") eeprom_map        <= 4'b0010; 	// Honoo no Toukyuuji Dodge Danpei
			else if(cart_id[63:0] == "T-12046 ") eeprom_map        <= 4'b0010; 	// Mega Man - The Wily Wars 
			else if(cart_id[63:0] == "T-12053 ") eeprom_map        <= 4'b0010; 	// Rockman Mega World 
			else if(cart_id[63:0] == "G-4524  ") eeprom_map        <= 4'b0010; 	// Ninja Burai Densetsu
			else if(cart_id[63:0] == "00054503") eeprom_map        <= 4'b0010; 	// Game Toshokan
			else if(cart_id[63:0] == "T-81033 ") eeprom_map        <= 4'b0011; 	// NBA Jam (J)
			else if(cart_id[63:0] == "T-081326") eeprom_map        <= 4'b0011; 	// NBA Jam (U)(E)
			else if(cart_id[63:0] == "T-081276") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club
			else if(cart_id[63:0] == "T-81406 ") eeprom_map        <= 4'b1011; 	// NBA Jam TE
			else if(cart_id[63:0] == "T-081586") eeprom_map        <= 4'b1100; 	// NFL Quarterback Club '96
			else if(cart_id[63:0] == "T-81576 ") eeprom_map        <= 4'b1101; 	// College Slam
			else if(cart_id[63:0] == "T-81476 ") eeprom_map        <= 4'b1101; 	// Frank Thomas Big Hurt Baseball
			else if(cart_id[63:0] == "T-8104B ") eeprom_map        <= 4'b1011; 	// NBA Jam TE (32X)
			else if(cart_id[63:0] == "T-8102B ") eeprom_map        <= 4'b1011; 	// NFL Quarterback Club (32X)
			else if(cart_id[63:0] == "T-113016") noram_quirk       <= 1; 			// Puggsy fake ram check
//			else if(cart_id[63:0] == "T-89016 ") fifo_quirk        <= 1; 			// Clue
			else if(cart_id[63:0] == "T-574023") pier_quirk        <= 1; 			// Pier Solar Reprint
			else if(cart_id[63:0] == "T-574013") pier_quirk        <= 1; 			// Pier Solar 1st Edition
			else if(cart_id[63:0] == "MK-1229 ") svp_quirk         <= 1; 			// Virtua Racing EU/US
			else if(cart_id[63:0] == "G-7001  ") svp_quirk         <= 1; 			// Virtua Racing JP
			else if(cart_id[63:0] == "T-35036 ") fmbusy_quirk      <= 1; 			// Hellfire US
			else if(cart_id[63:0] == "T-25073 ") fmbusy_quirk      <= 1; 			// Hellfire JP
			else if(cart_id[63:0] == "MK-1137-") fmbusy_quirk      <= 1; 			// Hellfire EU
			else if(cart_id[63:0] == "T-68???-") schan_quirk       <= 1; 			// Game no Kanzume Otokuyou
			else if(cart_id[87:40] == "SF-001")  sf_map            <= {crc == 16'h3E08,2'b01}; // Beggar Prince (Unl), Beggar Prince rev 1 (Unl)
			else if(cart_id[87:40] == "SF-002")  sf_map            <= {1'b1,2'b10}; // Legend of Wukong (Unl)
			else if(cart_id[87:40] == "SF-004")  sf_map            <= {1'b1,2'b11}; // Star Odyssey (Unl)
			
			// Lightgun device and timing offsets
			if(cart_id[63:0] == "MK-1533 ") begin						  // Body Count
				gun_type  <= 0;
				gun_sensor_delay <= 8'd100;
			end
			else if(cart_id[63:0] == "T-95096-") begin				  // Lethal Enforcers
				gun_type  <= 1;
				gun_sensor_delay <= 8'd52;
			end
			else if(cart_id[63:0] == "T-95136-") begin				  // Lethal Enforcers II
				gun_type  <= 1;
				gun_sensor_delay <= 8'd30;
			end
			else if(cart_id[63:0] == "MK-1658 ") begin				  // Menacer 6-in-1
				gun_type  <= 0;
				gun_sensor_delay <= 8'd120;
			end
			else if(cart_id[63:0] == "T-081156") begin				  // T2: The Arcade Game
				gun_type  <= 0;
				gun_sensor_delay <= 8'd126;
			end
			else begin
				gun_type  <= 0;
				gun_sensor_delay <= 8'd44;
			end
		end
		
		if(ioctl_addr == 'h7E100) realtec_id[31:16] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h7E102) realtec_id[15: 0] <= {ioctl_data[7:0],ioctl_data[15:8]};
		if(ioctl_addr == 'h7E104) begin
			if (realtec_id == "SEGA") realtec_map <= 1; // Earth Defend, Funny World & Balloon Boy, Whac-a-Critter
		end
	end
end


/////////////////////////  BRAM SAVE/LOAD  /////////////////////////////
wire downloading = rom_download;
wire bk_change  = CART_SRAM_WR | CART_EP_WR;
wire autosave   = status[13];
wire bk_load    = status[16];
wire bk_save    = status[17];

reg bk_ena = 0;
reg sav_pending = 0;
always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_change = 0;

	old_downloading <= downloading;
	if(~old_downloading & downloading) bk_ena <= 0;

	//Save file always mounted in the end of downloading state.
	if(downloading && img_mounted && !img_readonly) bk_ena <= 1;

	old_change <= bk_change;
	if (~old_change & bk_change) sav_pending <= 1;
	else if (bk_state) sav_pending <= 0;
end

wire bk_save_a  = autosave & OSD_STATUS;
reg  bk_loading = 0;
reg  bk_state   = 0;
//reg  bk_reload  = 0;

always @(posedge clk_sys) begin
	reg old_downloading = 0;
	reg old_load = 0, old_save = 0, old_save_a = 0, old_ack;
	reg [1:0] state;

	old_downloading <= downloading;

	old_load   <= bk_load;
	old_save   <= bk_save;
	old_save_a <= bk_save_a;
	old_ack    <= sd_ack;

	if(~old_ack & sd_ack) {sd_rd, sd_wr} <= 0;

	if (!bk_state) begin
		tmpram_tx_start <= 0;
		state <= 0;
		sd_lba <= 0;
//		bk_reload <= 0;
		bk_loading <= 0;
		if (bk_ena & ~ss_busy & ((~old_load & bk_load) | (~old_save & bk_save) | (~old_save_a & bk_save_a & sav_pending))) begin
			bk_state <= 1;
			bk_loading <= bk_load;
//			bk_reload <= bk_load;
			sd_rd <=  bk_load;
			sd_wr <= 0;
		end
		if (old_downloading & ~rom_download & bk_ena) begin
			bk_state <= 1;
			bk_loading <= 1;
			sd_rd <= 1;
			sd_wr <= 0;
		end
	end
	else begin
		if (bk_loading) begin
			case(state)
				0: begin
						sd_rd <= 1;
						state <= 1;
					end
				1: if(old_ack & ~sd_ack) begin
						tmpram_tx_start <= 1;
						state <= 2;
					end
				2: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
		else begin
			case(state)
				0: begin
						tmpram_tx_start <= 1;
						state <= 1;
					end
				1: if(tmpram_tx_finish) begin
						tmpram_tx_start <= 0;
						sd_wr <= 1;
						state <= 2;
					end
				2: if(old_ack & ~sd_ack) begin
						state <= 0;
						sd_lba <= sd_lba + 1'd1;
						if(sd_lba[6:0] == 7'h7F) bk_state <= 0;
					end
			endcase
		end
	end
end

wire [15:0] tmpram_dout;
wire [15:0] tmpram_din = {sdr_do[3][7:0],sdr_do[3][15:8]};
wire        tmpram_busy = sdr_busy[3];

wire [15:0] tmpram_sd_buff_q;
dpram_dif #(8,16,8,16) tmpram
(
	.clock(clk_sys),

	.address_a(tmpram_addr),
	.wren_a(~bk_loading & tmpram_busy_d & ~tmpram_busy),
	.data_a(tmpram_din),
	.q_a(tmpram_dout),

	.address_b(sd_buff_addr),
	.wren_b(sd_buff_wr & sd_ack /*& |sd_lba[10:4]*/),
	.data_b(sd_buff_dout),
	.q_b(tmpram_sd_buff_q)
);

//reg [10:0] tmpram_lba;
reg  [8:1] tmpram_addr;
reg tmpram_tx_start;
reg tmpram_tx_finish;
reg tmpram_req;
reg tmpram_busy_d;
always @(posedge clk_sys) begin
	reg state;

//	tmpram_lba <= sd_lba[10:0] - 11'h10;
	
	tmpram_busy_d <= tmpram_busy;
	if (~tmpram_busy_d & tmpram_busy) tmpram_req <= 0;

	if (~tmpram_tx_start) {tmpram_addr, state, tmpram_tx_finish} <= '0;
	else if(~tmpram_tx_finish) begin
		if(!state) begin
			tmpram_req <= 1;
			state <= 1;
		end
		else if(tmpram_busy_d & ~tmpram_busy) begin
			state <= 0;
			if(~&tmpram_addr) tmpram_addr <= tmpram_addr + 1'd1;
			else tmpram_tx_finish <= 1;
		end
	end
end

assign sd_buff_din = tmpram_sd_buff_q;


wire [7:0] SERJOYSTICK_IN;
wire [7:0] SERJOYSTICK_OUT;
wire [1:0] SER_OPT;

always @(posedge clk_sys) begin
	if (status[45]) begin
		SERJOYSTICK_IN[0] <= USER_IN[1];//up
		SERJOYSTICK_IN[1] <= USER_IN[0];//down	
		SERJOYSTICK_IN[2] <= USER_IN[5];//left	
		SERJOYSTICK_IN[3] <= USER_IN[3];//right
		SERJOYSTICK_IN[4] <= USER_IN[2];//b TL		
		SERJOYSTICK_IN[5] <= USER_IN[6];//c TR GPIO7			
		SERJOYSTICK_IN[6] <= USER_IN[4];//  TH
		SERJOYSTICK_IN[7] <= 0;
		SER_OPT[0] <= status[4];
		SER_OPT[1] <= ~status[4];
		USER_OUT[1] <= SERJOYSTICK_OUT[0];
		USER_OUT[0] <= SERJOYSTICK_OUT[1];
		USER_OUT[5] <= SERJOYSTICK_OUT[2];
		USER_OUT[3] <= SERJOYSTICK_OUT[3];
		USER_OUT[2] <= SERJOYSTICK_OUT[4];
		USER_OUT[6] <= SERJOYSTICK_OUT[5];
		USER_OUT[4] <= SERJOYSTICK_OUT[6];
	end else begin
		SER_OPT  <= 0;
		USER_OUT <= '1;
	end
end

//debug
reg       VDP_MD_EN = 1;
reg       VDP_32X_EN = 1;
reg       VDP_BGA_EN = 1;
reg       VDP_BGB_EN = 1;
reg       VDP_SPR_EN = 1;
reg [1:0] VDP_BG_GRID_EN = '0;
reg       VDP_SPR_GRID_EN = 0;
reg       DBG_PAUSE_EN = 0;   // driven by pausekey
reg       dbg_pause_key = 0;
reg       EN_GEN_FM = 1;
reg       EN_GEN_PSG = 1;
reg       EN_32X_PWM = 1;

always @(posedge clk_sys) begin
	reg old_state = 0;

	old_state <= ps2_key[10];
	dbg_pause_key <= 0;

	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			// F4 is a savestate key.
			'h003: begin VDP_MD_EN <= ~VDP_MD_EN; end 	// F5
			'h00B: begin VDP_BGA_EN <= ~VDP_BGA_EN; end 	// F6
			'h083: begin VDP_BGB_EN <= ~VDP_BGB_EN; end 	// F7
			'h00A: begin VDP_SPR_EN <= ~VDP_SPR_EN; end 	// F8
			'h001: begin VDP_BG_GRID_EN[0] <= ~VDP_BG_GRID_EN[0]; end 	// F9
			'h009: begin VDP_BG_GRID_EN[1] <= ~VDP_BG_GRID_EN[1]; end 	// F10
			'h078: begin VDP_SPR_GRID_EN <= ~VDP_SPR_GRID_EN; end 	// F11
			'h177: begin dbg_pause_key <= 1; end 	// Pause
			'h016: begin EN_GEN_FM <= ~EN_GEN_FM; end 	// 1
			'h01E: begin EN_GEN_PSG <= ~EN_GEN_PSG; end 	// 1
			'h026: begin EN_32X_PWM <= ~EN_32X_PWM; end 	// 2
			'h025: begin  end 	// 3
		endcase
	end
end

//////////////////////////////  Savestates  ////////////////////////////////////
// The Mega Drive side and the 32X side (two SH-2, adapter, 32X VDP, palette, 32X SDRAM
// and framebuffers). Mega Drive games carry the idle 32X side too.
// Changing a region offset or size requires an SS_VERSION bump.

localparam [31:0] SS_MAGIC   = 32'h33325353;  // "32SS"
localparam [31:0] SS_VERSION = 32'h00000005;

// Region sizes are in 32-bit words: one native byte or 16-bit value per word.
localparam [31:0] SS_HEADER_SIZE    = 32'd2;
localparam [31:0] SS_WORK_RAM_SIZE  = 32'd32768;  // 64KB work RAM as 32K x 16-bit
localparam [31:0] SS_VRAM_SIZE      = 32'd65536;  // 64KB VRAM, 1 byte/word
localparam [31:0] SS_ZRAM_SIZE      = 32'd8192;   // 8KB Z80 RAM, 1 byte/word
localparam [31:0] SS_SRAM_SIZE      = 32'd32768;  // cart SRAM window, one SDRAM word/word
localparam [31:0] SS_EEPROM_SIZE    = 32'd1024;   // cart EEPROM, 1 byte/word
localparam [31:0] SS_CRAM_SIZE      = 32'd64;     // VDP SS_SEL 0
localparam [31:0] SS_VSRAM_SIZE     = 32'd64;     // VDP SS_SEL 1
localparam [31:0] SS_OBJ_SIZE       = 32'd128;    // VDP SS_SEL 2, sprite attribute cache (7-bit index)
localparam [31:0] SS_VDP_REGS_SIZE  = 32'd32;     // VDP SS_SEL 3, see the layout in vdp.sv
localparam [31:0] SS_M68K_REGS_SIZE = 32'd128;    // fx68k
localparam [31:0] SS_Z80_REGS_SIZE  = 32'd32;
localparam [31:0] SS_FM_SHADOW_SIZE = 32'd512;    // YM2612 shadow and chip state
localparam [31:0] SS_PSG_REGS_SIZE  = 32'd16;
localparam [31:0] SS_SYS_REGS_SIZE  = 32'd8;      // I/O registers, bus arbiter
localparam [31:0] SS_CART_REGS_SIZE = 32'd8;      // mapper registers, EEPROM interface
localparam [31:0] SS_MISC_SIZE      = 32'd32;
localparam [31:0] SS_32X_SIZE       = S32X_PKG::SS_32X_SIZE; // SH-2s, adapter, 32X VDP, palette
localparam [31:0] SS_SDR32_SIZE     = 32'd65536;  // 256KB 32X SDRAM, two 16-bit words/word
localparam [31:0] SS_FB_SIZE        = 32'd65536;  // framebuffers, {FB1, FB0} per word; FB1 is the SVP DRAM
localparam [31:0] SS_SVP_SIZE       = 32'd2048;   // SVP: DSP, RAMA/RAMB, interface, IRAM (rtl/SVP/SVP.vhd)
// Sega Channel only: the 4MB the cartridge can write (cart ROM below 4MB, two halfwords
// per word). The image of any other cartridge ends before it.
localparam [31:0] SS_CROM_SIZE      = 32'd1048576;

localparam [31:0] SS_OFF_WORK_RAM  = SS_HEADER_SIZE;
localparam [31:0] SS_OFF_VRAM      = SS_OFF_WORK_RAM  + SS_WORK_RAM_SIZE;
localparam [31:0] SS_OFF_ZRAM      = SS_OFF_VRAM      + SS_VRAM_SIZE;
localparam [31:0] SS_OFF_SRAM      = SS_OFF_ZRAM      + SS_ZRAM_SIZE;
localparam [31:0] SS_OFF_EEPROM    = SS_OFF_SRAM      + SS_SRAM_SIZE;
localparam [31:0] SS_OFF_CRAM      = SS_OFF_EEPROM    + SS_EEPROM_SIZE;
localparam [31:0] SS_OFF_VSRAM     = SS_OFF_CRAM      + SS_CRAM_SIZE;
localparam [31:0] SS_OFF_OBJ       = SS_OFF_VSRAM     + SS_VSRAM_SIZE;
localparam [31:0] SS_OFF_VDP_REGS  = SS_OFF_OBJ       + SS_OBJ_SIZE;
localparam [31:0] SS_OFF_M68K_REGS = SS_OFF_VDP_REGS  + SS_VDP_REGS_SIZE;
localparam [31:0] SS_OFF_Z80_REGS  = SS_OFF_M68K_REGS + SS_M68K_REGS_SIZE;
localparam [31:0] SS_OFF_FM_SHADOW = SS_OFF_Z80_REGS  + SS_Z80_REGS_SIZE;
localparam [31:0] SS_OFF_PSG_REGS  = SS_OFF_FM_SHADOW + SS_FM_SHADOW_SIZE;
localparam [31:0] SS_OFF_SYS_REGS  = SS_OFF_PSG_REGS  + SS_PSG_REGS_SIZE;
localparam [31:0] SS_OFF_CART_REGS = SS_OFF_SYS_REGS  + SS_SYS_REGS_SIZE;
localparam [31:0] SS_OFF_MISC      = SS_OFF_CART_REGS + SS_CART_REGS_SIZE;
localparam [31:0] SS_OFF_32X       = SS_OFF_MISC      + SS_MISC_SIZE;
localparam [31:0] SS_OFF_SDR32     = SS_OFF_32X       + SS_32X_SIZE;
localparam [31:0] SS_OFF_FB        = SS_OFF_SDR32     + SS_SDR32_SIZE;
localparam [31:0] SS_OFF_SVP       = SS_OFF_FB        + SS_FB_SIZE;
localparam [31:0] SS_OFF_CROM      = SS_OFF_SVP       + SS_SVP_SIZE;

localparam [31:0] SS_FULL_SIZE     = SS_OFF_CROM;
localparam [31:0] SS_CROM_FULL     = SS_OFF_CROM      + SS_CROM_SIZE;
wire       [31:0] ss_state_size    = schan_quirk ? SS_CROM_FULL : SS_FULL_SIZE;

wire        ss_save_done;
wire        ss_eng_freeze_req;
wire        ss_freeze_req = ss_eng_freeze_req | DBG_PAUSE_EN;
wire [31:0] ss_state_addr;
wire        ss_state_wr, ss_state_rd, ss_state_we;

// savestate_ui. F1 to F4 load slots 1 to 4 and Alt with F1 to F4 saves.
// On a gamepad, hold the Savestate button, J1 bit 12, which is unmapped by default.
// With it held, Left and Right select the slot, Mode+Down saves and Mode+Up loads.
// A Sega Channel cartridge whose bank registers have mapped a page at 4MB or above can have
// written memory the image does not hold: its savestates stay off until the next reset.
wire ssui_save, ssui_load;
wire ssui_allow = ~rom_download & ~ss_busy & ~bk_state & ~(schan_quirk & CART_ROM_BANK_HI);

savestate_ui #(.INFO_TIMEOUT_BITS(25)) savestate_ui
(
	.clk          (clk_sys),
	.ps2_key      (ps2_key),
	.allow_ss     (ssui_allow),
	.joySS        (joystick_0[12]),
	.joyRight     (joystick_0[0]),
	.joyLeft      (joystick_0[1]),
	.joyDown      (joystick_0[2]),
	.joyUp        (joystick_0[3]),
	.joyStart     (joystick_0[8]),   // Mode, because Start pauses most games.
	.status_slot  (status[65:64]),
	.OSD_saveload ({status[67], status[66]}),  // Bit 1 loads, bit 0 saves.
	.ss_save      (ssui_save),
	.ss_load      (ssui_load),
	.ss_info_req  (ss_info_req),
	.ss_info      (ss_info),
	.statusUpdate (ssui_status_upd),
	.selected_slot(ssui_slot)
);

// savestate_ui emits 1-cycle pulses and the engine samples through a 2-FF
// synchronizer, so stretch them.
reg [7:0] ss_save_cnt = 0;
reg [7:0] ss_load_cnt = 0;
reg [1:0] ss_slot_reg = 0;
always @(posedge clk_sys) begin
	if(ssui_save) begin ss_save_cnt <= 8'd100; ss_slot_reg <= ssui_slot; end
	else if(ss_save_cnt) ss_save_cnt <= ss_save_cnt - 1'd1;

	if(ssui_load) begin ss_load_cnt <= 8'd100; ss_slot_reg <= ssui_slot; end
	else if(ss_load_cnt) ss_load_cnt <= ss_load_cnt - 1'd1;
end
wire ss_save_req = |ss_save_cnt;
wire ss_load_req = |ss_load_cnt;

// Grant capture only after a VBlank, with parked CPUs and an idle bus.
reg ss_vbl_parked = 0;
always @(posedge clk_sys) begin
	if(!ss_freeze_req) ss_vbl_parked <= 0;
	else if(vblank)    ss_vbl_parked <= 1;
end

// Cart ROM and SRAM requests finish once the 68000 and the SH-2s have parked with the
// bus idle (the SH-2s read the cartridge through the same SDRAM channel), and the SVP
// program reads once the SVP has parked.
wire ss_sdr_quiet = ~sdr_busy[0] & ~sdr_busy[1] & ~sdr_busy[2];

// The 32X parks on the clock the 68000 does (ss_park_engage, rtl/GEN/gen.sv): a VCLK
// where both SH-2 are between bus cycles at the end of a clock burst; it skips that
// burst and takes no VCLK until the release (rtl/32X/32X.sv). Its SDRAM requests (DDR3)
// have finished once ddr_busy is low. The SVP stops on the same clock and is parked
// once its memory controller has drained (SS_PARKED).
wire ss_freeze_ack = ss_vbl_parked & ss_m68k_frozen & ss_z80_frozen &
                     ss_vdp_quiet & ss_ba_quiet & ss_sdr_quiet &
                     ss_32x_parked & ss_32x_quiet & ~ddr_busy &
                     (~svp_quirk | ss_svp_parked);

// An image is only taken, or written back, with everything parked. If the CPUs never
// meet a common safe point, the engine times out after about three seconds and the
// request is dropped; the CPUs keep running until they park.
// Latch the grant so the port muxes do not switch during the stream.
always @(posedge clk_sys) begin
	if (!ss_freeze_req)      ss_freeze_active <= 0;
	else if (ss_freeze_ack)  ss_freeze_active <= 1;
end

// The raster keeps running. Hold the CPUs until the live raster and the 68000 clock
// divider are both back at their phase of the park clock P. On that clock (release
// clock) the 32X starts the SH-2 burst it skipped at P; gen and the SVP had already run
// P, so they resume one clock later (ss_release_d) on the same pulses they would have
// had. The VDP then restores its pending interrupts and HINT countdown (SS_RESUME_LAG
// = 1). The divider repeats every 7 clocks and a frame is not a multiple of it, so this
// can take up to 7 frames. A mode change that makes the phase unreachable is bounded by
// 2^24 clocks (~310 ms).
reg        ss_resume_hold = 0;
reg [23:0] ss_resume_to   = 0;
assign ss_release_now = ss_resume_hold & ss_vdp_phase_ok & ss_div_ok;
wire ss_rel_cond = ss_release_now | (&ss_resume_to);
always @(posedge clk_sys) begin
	ss_release_d  <= ss_release_now;
	ss_vdp_resume <= 0;
	if (ss_freeze_active & ~ss_freeze_req) begin
		ss_resume_hold <= 1;
		ss_resume_to   <= 0;
	end
	else if (ss_freeze_req) begin
		ss_resume_hold <= 0;
	end
	else if (ss_resume_hold) begin
		ss_resume_to <= ss_resume_to + 1'd1;
		if (ss_rel_cond) begin
			ss_resume_hold <= 0;
			ss_vdp_resume  <= 1;
		end
	end
end
// (freeze_active & ~freeze_req) covers the one clock between the request
// dropping and the hold being registered, so the CPUs never see a gap.
wire ss_hold_any  = (ss_freeze_active & ~ss_freeze_req) | ss_resume_hold;
assign ss_cpu_freeze = ss_freeze_req | ss_hold_any;

// Pause: the Pause key or J1 bit 13. It holds the core through the savestate freeze,
// so the pause starts at the next VBlank with the 68000, Z80, both SH-2 and the SVP
// parked and the sound stopped, and it ends at the phase where it started. A save
// keeps the pause. A load ends it once the engine holds the freeze, and reset ends it.
reg pause_load = 0;
always @(posedge clk_sys) begin : pausekey
	reg old_state;
	old_state <= joystick_0[13];
	if (reset | rom_download) begin
		DBG_PAUSE_EN <= 0;
		pause_load   <= 0;
	end
	else if (pause_load) begin
		if (ss_eng_freeze_req) begin DBG_PAUSE_EN <= 0; pause_load <= 0; end
		else if (~ss_busy & ~ss_load_req) pause_load <= 0;   // the load did not start
	end
	else if (DBG_PAUSE_EN & ss_load_req) pause_load <= 1;
	else if ((~old_state & joystick_0[13]) | dbg_pause_key) DBG_PAUSE_EN <= ~DBG_PAUSE_EN;
end

// The raster runs on while paused without the CPUs, so HDMI keeps the last complete
// frame until the first VBlank after the core runs again.
reg pause_vid = 0;
always @(posedge clk_sys) begin : pausevid
	reg old_vbl;
	old_vbl <= vblank;
	if (DBG_PAUSE_EN) pause_vid <= 1;
	else if (~ss_cpu_freeze & vblank & ~old_vbl) pause_vid <= 0;
end
assign HDMI_FREEZE = pause_vid;


// Region decode.
`define SS_IN(off, size) ((ss_state_addr >= (off)) && (ss_state_addr < (off) + (size)))

wire ss_sel_work_ram = `SS_IN(SS_OFF_WORK_RAM,  SS_WORK_RAM_SIZE);
wire ss_sel_vram     = `SS_IN(SS_OFF_VRAM,      SS_VRAM_SIZE);
wire ss_sel_zram     = `SS_IN(SS_OFF_ZRAM,      SS_ZRAM_SIZE);
wire ss_sel_sram     = `SS_IN(SS_OFF_SRAM,      SS_SRAM_SIZE);
assign ss_sel_eeprom = `SS_IN(SS_OFF_EEPROM,    SS_EEPROM_SIZE);
wire ss_sel_cram     = `SS_IN(SS_OFF_CRAM,      SS_CRAM_SIZE);
wire ss_sel_vsram    = `SS_IN(SS_OFF_VSRAM,     SS_VSRAM_SIZE);
wire ss_sel_obj      = `SS_IN(SS_OFF_OBJ,       SS_OBJ_SIZE);
wire ss_sel_vdp_regs = `SS_IN(SS_OFF_VDP_REGS,  SS_VDP_REGS_SIZE);
wire ss_sel_m68k     = `SS_IN(SS_OFF_M68K_REGS, SS_M68K_REGS_SIZE);
wire ss_sel_z80      = `SS_IN(SS_OFF_Z80_REGS,  SS_Z80_REGS_SIZE);
wire ss_sel_fm       = `SS_IN(SS_OFF_FM_SHADOW, SS_FM_SHADOW_SIZE);
wire ss_sel_psg      = `SS_IN(SS_OFF_PSG_REGS,  SS_PSG_REGS_SIZE);
wire ss_sel_sys      = `SS_IN(SS_OFF_SYS_REGS,  SS_SYS_REGS_SIZE);
wire ss_sel_cart     = `SS_IN(SS_OFF_CART_REGS, SS_CART_REGS_SIZE);
assign ss_sel_32x     = `SS_IN(SS_OFF_32X,       SS_32X_SIZE);
wire ss_sel_sdr32    = `SS_IN(SS_OFF_SDR32,     SS_SDR32_SIZE);
wire ss_sel_fb       = `SS_IN(SS_OFF_FB,        SS_FB_SIZE);
assign ss_sel_svp    = `SS_IN(SS_OFF_SVP,       SS_SVP_SIZE);
assign ss_sel_crom   = schan_quirk && `SS_IN(SS_OFF_CROM, SS_CROM_SIZE);
assign ss_svp_addr   = 11'(ss_state_addr - SS_OFF_SVP);

// 32X internals (rtl/32X/32X.sv). The framebuffers take their block RAM ports, written
// twice with the same word during the two-clock state_we.
assign ss_32x_addr = 16'(ss_state_addr - SS_OFF_32X);
// The read cache words of the adapter block belong to ddram.sv (SDRAM channel below).
wire ss_sel_rc     = ss_sel_32x && ss_32x_addr >= 16'(S32X_PKG::SS_OFF_RC) &&
                     ss_32x_addr < 16'(S32X_PKG::SS_OFF_RC + S32X_PKG::SS_RC_SIZE);
assign ss_fb_addr  = 16'(ss_state_addr - SS_OFF_FB);
assign ss_fb_we    = ss_freeze_active & ss_state_we & ss_sel_fb;

// Work RAM, VRAM and Z80 RAM share one port into gen.
wire ss_sel_gen_mem = ss_sel_work_ram | ss_sel_vram | ss_sel_zram;
assign ss_gen_mem_sel   = ss_sel_vram ? 2'd1 : ss_sel_zram ? 2'd2 : 2'd0;
assign ss_gen_mem_addr  = ss_sel_vram ? 16'(ss_state_addr - SS_OFF_VRAM) :
                          ss_sel_zram ? 16'(ss_state_addr - SS_OFF_ZRAM) :
                                        16'(ss_state_addr - SS_OFF_WORK_RAM);
assign ss_gen_mem_wr_en = ss_state_we & ss_sel_gen_mem;

// VDP internals.
wire ss_sel_vdp = ss_sel_cram | ss_sel_vsram | ss_sel_obj | ss_sel_vdp_regs;
assign ss_vdp_sel   = ss_sel_cram  ? 2'd0 :
                      ss_sel_vsram ? 2'd1 :
                      ss_sel_obj   ? 2'd2 : 2'd3;
assign ss_vdp_addr  = ss_sel_cram  ? 8'(ss_state_addr - SS_OFF_CRAM)  :
                      ss_sel_vsram ? 8'(ss_state_addr - SS_OFF_VSRAM) :
                      ss_sel_obj   ? 8'(ss_state_addr - SS_OFF_OBJ)   :
                                     8'(ss_state_addr - SS_OFF_VDP_REGS);
assign ss_vdp_wr_en = ss_state_we & ss_sel_vdp;

// 68000. One 16-bit fx68k word per 32-bit word. fx68k reads 0 above its used range
// and ignores writes there. ss_wr_en may only pulse while the CPU is frozen: state_we
// requires freeze_ack, and freeze_ack includes the frozen report.
assign ss_m68k_addr  = 8'(ss_state_addr - SS_OFF_M68K_REGS);
assign ss_m68k_wr_en = ss_state_we & ss_sel_m68k;

// FM: one YM2612 register of the shadow per word, 512 of them, and in bits 31-8 the
// state of the chip (fm_savestate.sv). A word of chip state takes 24 clocks.
assign ss_fm_addr  = 9'(ss_state_addr - SS_OFF_FM_SHADOW);
assign ss_fm_wr_en = ss_state_we & ss_sel_fm;
assign ss_fm_rd_en = ss_state_wr & ss_sel_fm;

// jt89 decodes 3 address bits, so the reserved tail of the region must not alias.
assign ss_psg_addr  = 3'(ss_state_addr - SS_OFF_PSG_REGS);
assign ss_psg_wr_en = ss_state_we & ss_sel_psg & (ss_state_addr < SS_OFF_PSG_REGS + 32'd8);

// Words 0-3 are the I/O registers, 4-5 the bus arbiter, 6 the park timing (gen.sv);
// 7 is spare.
assign ss_sys_addr  = 3'(ss_state_addr - SS_OFF_SYS_REGS);
assign ss_sys_wr_en = ss_state_we & ss_sel_sys & (ss_sys_addr != 3'd7);

// Cart: mapper registers, or the EEPROM data while ss_sel_eeprom.
assign ss_cart_addr  = ss_sel_eeprom ? 10'(ss_state_addr - SS_OFF_EEPROM) : 10'(ss_state_addr - SS_OFF_CART_REGS);
assign ss_cart_wr_en = ss_state_we & (ss_sel_cart | ss_sel_eeprom);

// Z80 state. Words 0-6 hold the 212 bits of T80 REG. Word 7:
//   bits 8-0: bank register (A23-A15)
//   bit 9:    BUSRQ_N, bit 10: RESET_N (A11100 and A11200)
//   bit 11:   HALT
//   bit 12:   words 8-11 hold T80 SEQ (bits 119-0), the rest of an instruction the bus
//             request stopped (BUSAK low, SEQ bit 0)
// Words 12-31 are spare. Word 7 restores the bank and the bus lines at once (EXT_SET).
// The registers are restored by one DIRSet pulse, two clocks after word 11: T80 latches
// the whole register file at once, and a Z80 taken out of reset by word 7 must be out of
// it by then.
wire [4:0] ss_z80_word = 5'(ss_state_addr - SS_OFF_Z80_REGS);
reg  [119:0] ss_z80_seq_dir_r;
reg          ss_z80_seq_ok;
reg          ss_z80_dirset_d;
always @(posedge clk_sys) begin
	ss_z80_dirset_d <= 0;
	ss_z80_dirset   <= ss_z80_dirset_d;
	ss_z80_ext_set  <= 0;
	if(ss_state_we & ss_sel_z80) begin
		case(ss_z80_word)
			5'd0: ss_z80_dir[ 31:  0] <= ss_state_dout;
			5'd1: ss_z80_dir[ 63: 32] <= ss_state_dout;
			5'd2: ss_z80_dir[ 95: 64] <= ss_state_dout;
			5'd3: ss_z80_dir[127: 96] <= ss_state_dout;
			5'd4: ss_z80_dir[159:128] <= ss_state_dout;
			5'd5: ss_z80_dir[191:160] <= ss_state_dout;
			5'd6: ss_z80_dir[211:192] <= ss_state_dout[19:0];
			5'd7: begin
				ss_z80_halt_dir <= ss_state_dout[11];
				ss_z80_bar_dir  <= ss_state_dout[8:0];
				ss_z80_ctrl_dir <= ss_state_dout[10:9];
				ss_z80_ext_set  <= 1;
				ss_z80_seq_ok   <= ss_state_dout[12];
			end
			5'd8:  ss_z80_seq_dir_r[ 31: 0] <= ss_state_dout;
			5'd9:  ss_z80_seq_dir_r[ 63:32] <= ss_state_dout;
			5'd10: ss_z80_seq_dir_r[ 95:64] <= ss_state_dout;
			5'd11: begin
				ss_z80_seq_dir_r[119:96] <= ss_state_dout[23:0];
				ss_z80_dirset_d <= 1;   // Last word, latch all registers.
			end
			default: ;
		endcase
	end
end
assign ss_z80_seq_dir = ss_z80_seq_ok ? ss_z80_seq_dir_r : 120'd0;


//////////////////  SDRAM-backed regions: cart SRAM, Sega Channel cart ROM  //////////////////
// The only regions not in block RAM or flops. SDRAM port 3 serves ROM loading and the
// backup RAM transfers, neither of which runs during a savestate, so the stream takes
// it. The SDRAM latency varies, so the engine waits on state_ready. Port select, address
// and data are registered with the strobes, which keeps the region decode of the state
// address out of the clk_ram paths.
assign ss_sram_addr = 15'(ss_state_addr - SS_OFF_SRAM);
assign ss_crom_addr = 20'(ss_state_addr - SS_OFF_CROM);

// One SDRAM word per state word for the SRAM, two (low halfword first) for the cart ROM.
reg  [1:0] ss_sdr_st = 0;
reg [31:0] ss_sdr_data;
reg        ss_sdr_ready = 0;
reg [31:0] ss_sdr_addr_d;
reg        ss_sdr_load;
always @(posedge clk_sys) begin
	ss_sdr_addr_d <= ss_state_addr;
	ss_sdr_own    <= ss_freeze_active & (ss_sel_sram | ss_sel_crom);

	if(!ss_freeze_active) begin
		ss_sdr_st <= 0; ss_sdr_rd <= 0; ss_sdr_wr <= 0; ss_sdr_ready <= 0; ss_sdr_hi <= 0;
	end else case(ss_sdr_st)
		// Idle. state_wr reads from the core for a save, state_we writes for a load.
		2'd0: begin
			ss_sdr_ready <= 0;
			ss_sdr_hi    <= 0;
			if((ss_sel_sram | ss_sel_crom) && (ss_state_wr | ss_state_we)) begin
				ss_sdr_rd   <= ~ss_state_we;
				ss_sdr_wr   <=  ss_state_we;
				ss_sdr_load <=  ss_state_we;
				ss_sdr_a    <= ss_sel_crom ? {4'b0000, ss_crom_addr, 1'b0} : {10'b1100000000, ss_sram_addr};
				ss_sdr_d    <= ss_state_dout[15:0];
				ss_sdr_st <= 2'd1;
			end
		end
		// Wait for the controller to take the request (busy rises).
		2'd1: if(sdr_busy[3]) ss_sdr_st <= 2'd2;
		// Drop the strobes and wait for completion. dout is valid as busy falls.
		2'd2: begin
			ss_sdr_rd <= 0;
			ss_sdr_wr <= 0;
			if(!sdr_busy[3]) begin
				if(ss_sdr_hi) ss_sdr_data[31:16] <= sdr_do[3];
				else          ss_sdr_data <= {16'd0, sdr_do[3]};
				if(ss_sel_crom && !ss_sdr_hi) begin
					ss_sdr_hi   <= 1;
					ss_sdr_rd   <= ~ss_sdr_load;
					ss_sdr_wr   <=  ss_sdr_load;
					ss_sdr_a[1] <= 1;
					ss_sdr_d    <= ss_state_dout[31:16];
					ss_sdr_st   <= 2'd1;
				end else begin
					ss_sdr_ready <= 1;
					ss_sdr_st    <= 2'd3;
				end
			end
		end
		// Hold ready until the engine moves on, then arm for the next word.
		2'd3: if(ss_state_addr != ss_sdr_addr_d) begin
			ss_sdr_ready <= 0;
			ss_sdr_st    <= 2'd0;
		end
	endcase
end

//////////////////  DDR3-backed region: 32X SDRAM  //////////////////
// The SH-2 SDRAM lives in DDR3 (ddram.sv, 0x30000000), with a block RAM copy of its low
// 32KB and a small read cache in front. The stream reads and writes the DDR3 words
// through ddram's ssm channel, two SDRAM words per savestate word, after any posted
// SH-2 write; a load also rewrites the low copy. The read cache state (SS_OFF_RC words
// of the 32X block) goes through the same channel: a load puts it back after the last
// SDRAM word and refetches its lines, so the SH-2 hits and misses as before the save.
// The SH-2 port itself is left untouched, so its timing does not change.
reg   [1:0] ss_ssm_ack_s = 0;
reg   [1:0] ss_ssm_st = 0;
reg  [31:0] ss_ssm_data;
reg         ss_ssm_ready = 0;
always @(posedge clk_sys) begin
	ss_ssm_ack_s <= {ss_ssm_ack_s[0], ss_ssm_ack};

	if(!ss_freeze_active) begin
		ss_ssm_st <= 0; ss_ssm_ready <= 0;
	end else case(ss_ssm_st)
		2'd0: begin
			ss_ssm_ready <= 0;
			if((ss_sel_sdr32 | ss_sel_rc) && (ss_state_wr | ss_state_we)) begin
				ss_ssm_addr  <= ss_sel_rc ? 16'(ss_32x_addr - 16'(S32X_PKG::SS_OFF_RC)) : 16'(ss_state_addr - SS_OFF_SDR32);
				ss_ssm_cache <= ss_sel_rc;
				ss_ssm_we    <= ss_state_we;
				ss_ssm_din   <= ss_state_dout;
				ss_ssm_req   <= ~ss_ssm_req;
				ss_ssm_st   <= 2'd1;
			end
		end
		2'd1: if(ss_ssm_ack_s[1] == ss_ssm_req) begin
			ss_ssm_data  <= ss_ssm_dout;
			ss_ssm_ready <= 1;
			ss_ssm_st    <= 2'd2;
		end
		// Hold ready until the engine moves on, then arm for the next word.
		2'd2: if(ss_state_addr != ss_sdr_addr_d) begin
			ss_ssm_ready <= 0;
			ss_ssm_st    <= 2'd0;
		end
	endcase
end

// Regions that answer in the engine's fixed 4-cycle window never stall it.
wire ss_state_ready = (ss_sel_sram | ss_sel_crom) ? ss_sdr_ready :
                      ss_sel_sdr32 ? ss_ssm_ready  :
                      ss_sel_rc    ? ss_ssm_ready  :
                      ss_sel_fm    ? ss_fm_ready   : 1'b1;


// Read chain. Words 0 and 1 are the header checked on load. Reserved tails read 0.
reg [31:0] ss_state_din;
always @(posedge clk_sys) begin
	if(ss_sel_gen_mem)
		ss_state_din <= {16'd0, ss_gen_mem_rd_data};
	else if(ss_sel_sram | ss_sel_crom)
		ss_state_din <= ss_sdr_data;
	else if(ss_sel_eeprom | ss_sel_cart)
		ss_state_din <= ss_cart_rd_data;
	else if(ss_sel_vdp)
		ss_state_din <= ss_vdp_rd_data;
	else if(ss_sel_m68k)
		ss_state_din <= {16'd0, ss_m68k_rd_data};
	else if(ss_sel_fm)
		ss_state_din <= ss_fm_rd_data;
	else if(ss_sel_psg)
		ss_state_din <= ss_psg_rd_data;
	else if(ss_sel_rc)
		ss_state_din <= ss_ssm_data;
	else if(ss_sel_32x)
		ss_state_din <= ss_32x_rd_data;
	else if(ss_sel_sdr32)
		ss_state_din <= ss_ssm_data;
	else if(ss_sel_fb)
		ss_state_din <= {ss_fb1_q, ss_fb0_q};
	else if(ss_sel_svp)
		ss_state_din <= (ss_svp_addr == 11'h3FF) ? {31'd0, svp_ce_ph} : ss_svp_rd;
	else if(ss_sel_sys)
		ss_state_din <= (ss_sys_addr == 3'd6) ? {18'd0, ss_rfs_park, ss_sys_rd_data[3:0]} :
		                (ss_sys_addr != 3'd7) ? ss_sys_rd_data : 32'd0;
	else if(ss_sel_z80)
		ss_state_din <= (ss_z80_word == 5'd0) ? ss_z80_reg[ 31:  0] :
		                (ss_z80_word == 5'd1) ? ss_z80_reg[ 63: 32] :
		                (ss_z80_word == 5'd2) ? ss_z80_reg[ 95: 64] :
		                (ss_z80_word == 5'd3) ? ss_z80_reg[127: 96] :
		                (ss_z80_word == 5'd4) ? ss_z80_reg[159:128] :
		                (ss_z80_word == 5'd5) ? ss_z80_reg[191:160] :
		                (ss_z80_word == 5'd6) ? {12'd0, ss_z80_reg[211:192]} :
		                (ss_z80_word == 5'd7) ? {19'd0, 1'b1, ss_z80_halt, ss_z80_ctrl, ss_z80_bar} :
		                (ss_z80_word == 5'd8) ? ss_z80_seq[ 31: 0] :
		                (ss_z80_word == 5'd9) ? ss_z80_seq[ 63:32] :
		                (ss_z80_word == 5'd10) ? ss_z80_seq[ 95:64] :
		                (ss_z80_word == 5'd11) ? {8'd0, ss_z80_seq[119:96]} : 32'd0;
	else case(ss_state_addr)
		0: ss_state_din <= SS_MAGIC;
		1: ss_state_din <= {SS_VERSION[7:0], ss_state_size[23:0]};
		default: ss_state_din <= 32'd0;
	endcase
end


//////////////////  DDR3 bridge  //////////////////
// The engine runs on clk_sys. ddram.sv owns the DDR3 port on clk_ram and serves one
// savestate word per toggle request, after any 32X SDRAM traffic.
wire        ss_e_ddr_rd, ss_e_ddr_we;
wire [28:0] ss_e_ddr_addr;
wire [63:0] ss_e_ddr_din;
reg         ss_ddr_pend = 0;
reg         ss_ddr_rdy = 0;
reg   [1:0] ss_ddr_ack_s = 0;
always @(posedge clk_sys) begin
	ss_ddr_ack_s <= {ss_ddr_ack_s[0], ss_ddr_ack};
	ss_ddr_rdy   <= 0;
	if(ss_e_ddr_rd | ss_e_ddr_we) begin
		ss_ddr_addr <= ss_e_ddr_addr;
		ss_ddr_din  <= ss_e_ddr_din;
		ss_ddr_we   <= ss_e_ddr_we;
		ss_ddr_req  <= ~ss_ddr_req;
		ss_ddr_pend <= 1;
	end
	else if(ss_ddr_pend && ss_ddr_ack_s[1] == ss_ddr_req) begin
		ss_ddr_pend <= 0;
		ss_ddr_rdy  <= ~ss_ddr_we;
	end
end

savestate savestate_inst
(
	.clk(clk_sys),
	.reset(reset),

	.DDRAM_BUSY(ss_ddr_pend),
	.DDRAM_BURSTCNT(),
	.DDRAM_ADDR(ss_e_ddr_addr),
	.DDRAM_DOUT(ss_ddr_dout),
	.DDRAM_DOUT_READY(ss_ddr_rdy),
	.DDRAM_RD(ss_e_ddr_rd),
	.DDRAM_DIN(ss_e_ddr_din),
	.DDRAM_BE(),
	.DDRAM_WE(ss_e_ddr_we),

	.ss_slot(ss_slot_reg),
	.ss_save(ss_save_req),
	.ss_load(ss_load_req),
	.state_size(ss_state_size),
	.ss_busy(ss_busy),
	.ss_save_done(ss_save_done),
	.ss_load_done(ss_load_done),
	.load_hold(1'b0),

	.freeze_req(ss_eng_freeze_req),
	.freeze_ack(ss_freeze_ack & ss_eng_freeze_req),   // the engine sees its own freeze end while paused

	.state_addr(ss_state_addr),
	.state_wr(ss_state_wr),
	.state_rd(ss_state_rd),
	.state_din(ss_state_din),
	.state_dout(ss_state_dout),
	.state_we(ss_state_we),
	.state_ready(ss_state_ready),

	.hdr_magic(SS_MAGIC),
	.hdr_version(SS_VERSION),
	.hdr_size(ss_state_size)
);

endmodule
