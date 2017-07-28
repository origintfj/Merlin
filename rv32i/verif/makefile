# default greylock boot rom
BOOT_ROM_FILE := programs/hello_world.c

CARGS := -O0

FILE_LIST := -I../rtl/include ../rtl/fifo.v ../rtl/pfu.v ../rtl/decoder.v ../rtl/regfile_integer.v ../rtl/id_stage.v ../rtl/alu.v ../rtl/cs_registers.v ../rtl/ex_stage.v ../rtl/hvec.v ../rtl/lsqueue.v ../rtl/merlin32i.v

# optional alternate boot rom
ifdef TESTNAME
	BOOT_ROM_FILE := programs/$(TESTNAME).c
endif

ifdef TIMEOUT
	SARGS := -Ptb_core.C_TIMEOUT=$(TIMEOUT)
else
	SARGS :=
endif

ifdef DUMP
	DUMP_LXT2 := -lxt2
endif

ifdef GATES
	FILE_LIST := osu035_stdcells.v merlin32i.rtlnopwr.v
endif

test:
	TSEED=$$(date +%s | sha256sum | head -c 8)
	echo $(TSEED)

usage:
	@echo "make clean run [options...]"
	@echo ""
	@echo "OPTIONS:"
	@echo "    Timeout after x us                 : TIMEOUT=x"
	@echo "    Run program ./programs/some_test.c : TESTNAME=some_test"
	@echo "    Dump waveform                      : DUMP=1"
	@echo "    Use gate-level netlist             : GATES=1"

all:

clean:
	rm -f *.out
	rm -f *.hex
	rm -f *.lxt

build_mem: # -ffreestanding -fPIC -fno-builtin
	riscv32-unknown-elf-gcc -nostdinc -nostdlib -fPIC -e _entry -T link.ld $(CARGS) $(BOOT_ROM_FILE) -o test.out
	riscv32-unknown-elf-objcopy -O verilog test.out mem.hex
	#cat mem.hex
	riscv32-unknown-elf-objdump -D test.out

run: build_mem run_only

run_only:
	iverilog $(SARGS) -o tb_core.out -g2012 $(FILE_LIST) tb/boot_rom.v tb/ssram.v tb/tb_core.v
	vvp tb_core.out $(DUMP_LXT2)

synth:
	../synth/qflow_exec.sh
	cp /usr/share/qflow/tech/osu035/osu035_stdcells.v osu035_stdcells.v
	cp ../synth/synthesis/merlin32i.rtlnopwr.v merlin32i.rtlnopwr.v

