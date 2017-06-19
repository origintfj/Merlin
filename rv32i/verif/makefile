all:
	iverilog -I../rtl/include -o tb_core.out -g2012 ../rtl/fifo.sv ../rtl/pfu.sv ../rtl/decoder.v ../rtl/regfile_integer.v ../rtl/id_stage.v ../rtl/alu.v ../rtl/cs_registers.v ../rtl/ex_stage.v ../rtl/merlin32i.v boot_rom.sv tb_core.v
	vvp tb_core.out -lxt2

