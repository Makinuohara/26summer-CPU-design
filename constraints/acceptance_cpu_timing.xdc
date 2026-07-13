# The board build still divides the CPU clock by 2^18 for observation.
# This generated-clock constraint intentionally evaluates the CPU clock domain
# against a conservative 100 MHz target so that its datapaths are not omitted
# from timing analysis.  It does not change the implemented divider hardware.
create_generated_clock -name cpu_clk_eval \
    -source [get_ports CLK100MHZ] \
    -divide_by 1 \
    [get_pins u_soc/u_clk_div/counter_reg[17]/Q]
