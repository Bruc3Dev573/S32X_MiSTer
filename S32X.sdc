derive_pll_clocks
derive_clock_uncertainty

set_multicycle_path -to {*Hq2x*} -setup 4
set_multicycle_path -to {*Hq2x*} -hold 3

set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -setup 4
set_multicycle_path -from [get_clocks { *|pll|pll_inst|altera_pll_i|*[1].*|divclk}] -to {ascal|*} -hold 3

set_multicycle_path -from {emu|sdram|*} -to {emu|S32X|s32x_if|*} -start -setup 2
set_multicycle_path -from {emu|sdram|*} -to {emu|S32X|s32x_if|*} -start -hold 1

# Savestate transfers from DDR3 (rtl/ddram.sv): the data stays put from the ack toggle
# until the next request, and clk_sys reads it only after the ack has crossed through a
# two-stage synchronizer.
set_false_path -from {emu|ddram|ss_dout[*]}
set_false_path -from {emu|ddram|ssm_dout[*]}
