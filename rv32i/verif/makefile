# default greylock boot rom
BOOT_ROM_FILE := programs/test.c

CARGS := -O0

FILE_LIST := -I../rtl/include ../rtl/fifo.v ../rtl/pfu.v ../rtl/decoder.v ../rtl/regfile_integer.v ../rtl/id_stage.v ../rtl/alu.v ../rtl/cs_registers.v ../rtl/ex_stage.v ../rtl/hvec.v ../rtl/lsqueue.v ../rtl/merlin32i.v

# optional alternate boot rom
ifdef TESTNAME
	BOOT_ROM_FILE := programs/$(TESTNAME).c
endif

ifdef DUMP
	DUMP_LXT2 := -lxt2
endif

ifdef GATES
	FILE_LIST := osu035_stdcells.v merlin32i.rtlnopwr.v
endif

all:

clean:
	rm *.out
	rm *.hex
	rm *.lxt

build_mem: # -ffreestanding -fPIC -fno-builtin
	riscv32-unknown-elf-gcc -nostdinc -nostdlib -fPIC -e _entry -T link.ld $(CARGS) $(BOOT_ROM_FILE) -o test.out
	riscv32-unknown-elf-objcopy -O verilog test.out mem.hex
	riscv32-unknown-elf-objdump -D test.out
	cat mem.hex

run: build_mem
	iverilog -o tb_core.out -g2012 $(FILE_LIST) tb/boot_rom.v tb/ssram.v tb/tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

synth:
	../synth/qflow_exec.sh
	cp /usr/share/qflow/tech/osu035/osu035_stdcells.v osu035_stdcells.v
	cp ../synth/synthesis/merlin32i.rtlnopwr.v merlin32i.rtlnopwr.v

