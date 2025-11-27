# Auto-generated project tcl file


create_project microwatt_0 -force

set_property part xc7a200tsbg484-1 [current_project]

#Default since Vivado 2016.1
set_param project.enableVHDL2008 1

set_property generic {memory_size=0 cpus=2 clk_frequency=9000000 use_litedram=true use_liteeth=true use_litesdcard=false disable_flatten_core=false no_bram=true spi_flash_offset=10485760 log_length=2048 uart_is_16550=true has_fpu=true has_btc=true } [get_filesets sources_1]

read_verilog {src/microwatt_uart16550_1.5.5-r1/raminfr.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_receiver.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_regs.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_rfifo.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_sync_flops.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_tfifo.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_top.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_transmitter.v}
read_verilog {src/microwatt_uart16550_1.5.5-r1/uart_wb.v}
read_vhdl -vhdl2008 {src/microwatt_0/decode_types.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/wishbone_types.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/common.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/fetch1.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/predecode.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/decode1.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/helpers.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/decode2.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/register_file.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/cr_file.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/crhelpers.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/ppc_fx_insns.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/sim_console.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/logical.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/countbits.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/bitsort.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/control.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/execute1.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/fpu.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/loadstore1.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/mmu.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/dcache.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/divider.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/rotator.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/pmu.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/writeback.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/insn_helpers.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/core.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/icache.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/plrufn.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/cache_ram.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/core_debug.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/utils.vhdl}
read_xdc {src/microwatt_0/fpga/nexys-video.xdc}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/clk_gen_plle2.vhd}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/top-nexys-video.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/wishbone_arbiter.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/wishbone_debug_master.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/wishbone_bram_wrapper.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/soc.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/xics.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/gpio.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/syscon.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/sync_fifo.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/spi_rxtx.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/spi_flash_ctrl.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/git.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/main_bram.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/soc_reset.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/pp_fifo.vhd}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/pp_soc_uart.vhd}
read_vhdl -vhdl2008 {src/microwatt_0/fpga/pp_utilities.vhd}
read_vhdl -vhdl2008 {src/microwatt_0/nonrandom.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/dmi_dtm_xilinx.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/xilinx-mult.vhdl}
read_vhdl -vhdl2008 {src/microwatt_0/xilinx-mult-32s.vhdl}
read_verilog {/home/pe1576su/Desktop/slice/microwatt/litedram/extras/../generated/nexys-video/litedram_core.v}
read_vhdl -vhdl2008 {/home/pe1576su/Desktop/slice/microwatt/litedram/extras/../generated/nexys-video/litedram-initmem.vhdl}
read_vhdl -vhdl2008 {/home/pe1576su/Desktop/slice/microwatt/litedram/extras/../extras/litedram-wrapper-l2.vhdl}
read_verilog {/home/pe1576su/Desktop/slice/microwatt/liteeth/generated/nexys-video/liteeth_core.v}
read_verilog {/home/pe1576su/Desktop/slice/microwatt/litesdcard/generated/xilinx.100e6/litesdcard_core.v}

set_property include_dirs [list src/microwatt_uart16550_1.5.5-r1 .] [get_filesets sources_1]
set_property top toplevel [current_fileset]
set_property source_mgmt_mode None [current_project]


