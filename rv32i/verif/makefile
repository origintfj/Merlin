# default greylock boot rom
BOOT_ROM_FILE := programs/test.c

# optional alternate boot rom
ifdef TESTNAME
	BOOT_ROM_FILE := programs/$(TESTNAME).c
endif

ifdef DUMP
	DUMP_LXT2 := -lxt2
endif

all:

clean:
	rm *.out
	rm *.hex
	rm *.lxt

build_mem: # -ffreestanding -fPIC -fno-builtin
	riscv32-unknown-elf-gcc -nostdinc -nostdlib -fPIC -e main -T link.ld $(CARGS) $(BOOT_ROM_FILE) -o test.out -O0
	riscv32-unknown-elf-objcopy -O verilog test.out mem.hex

rtl: build_mem
	iverilog -I../rtl/include -o tb_core.out -g2012 ../rtl/fifo.v ../rtl/pfu.v ../rtl/decoder.v ../rtl/regfile_integer.v ../rtl/id_stage.v ../rtl/alu.v ../rtl/cs_registers.v ../rtl/ex_stage.v ../rtl/hvec.v ../rtl/lsqueue.v ../rtl/merlin32i.v tb/boot_rom.v tb/ssram.v tb/tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

gates: build_mem
	cp ../synth/synthesis/merlin32i.rtlnopwr.v merlin32i.rtlnopwr.v
	iverilog -o tb_core.out -g2012 osu035_stdcells.v merlin32i.rtlnopwr.v tb/boot_rom.v tb/ssram.v tb/tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

