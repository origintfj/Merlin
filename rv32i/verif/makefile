# default greylock boot rom
BOOT_ROM_FILE := mem.hex

# optional alternate boot rom
ifdef TESTNAME
	BOOT_ROM_FILE := $(TESTNAME).hex
endif

ifdef DUMP
	DUMP_LXT2 := -lxt2
endif

all:

clean:

rtl:
	iverilog -I../rtl/include -o tb_core.out -g2012 ../rtl/fifo.v ../rtl/pfu.v ../rtl/decoder.v ../rtl/regfile_integer.v ../rtl/id_stage.v ../rtl/alu.v ../rtl/cs_registers.v ../rtl/ex_stage.v ../rtl/hvec.v ../rtl/lsqueue.v ../rtl/merlin32i.v boot_rom.sv ssram.v tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

gates:
	iverilog -o tb_core.out -g2012 osu035_stdcells.v merlin32i.rtlnopwr.v boot_rom.sv ssram.v tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

