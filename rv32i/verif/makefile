# default greylock boot rom
BOOT_ROM_FILE := programs/hello_world.c

CARGS := -O0

DESIGN_HOME := ../

RTL_DIR     := $(DESIGN_HOME)/rtl
TB_SRC_DIR  := $(DESIGN_HOME)/verif/tb

RTL_INC_DIR := $(RTL_DIR)/include

RTL_FILE_LIST :=                                 \
	$(RTL_DIR)/merlin_fifo.v                     \
	$(RTL_DIR)/merlin_pfu.v                      \
	$(RTL_DIR)/merlin_pfu32ic.v                  \
	$(RTL_DIR)/merlin_rv32ic_expander.v          \
	$(RTL_DIR)/merlin_rv32i_decoder.v            \
	$(RTL_DIR)/merlin_int_regs.v                 \
	$(RTL_DIR)/merlin_id_stage.v                 \
	$(RTL_DIR)/merlin_alu.v                      \
	$(RTL_DIR)/merlin_cs_regs.v                  \
	$(RTL_DIR)/merlin_rv32ic_trace_logger.v      \
	$(RTL_DIR)/merlin_ex_stage.v                 \
	$(RTL_DIR)/merlin_lsqueue.v                  \
	$(RTL_DIR)/merlin.v

TB_FILE_LIST :=                                  \
	$(TB_SRC_DIR)/boot_rom.v                     \
	$(TB_SRC_DIR)/ssram.v                        \
	$(TB_SRC_DIR)/tb_core.v

# optional alternate boot rom
ifdef TESTNAME
	BOOT_ROM_FILE := programs/$(TESTNAME).c
endif

IV_ARGS := -DRV_ASSERTS_ON -DRV_TRACER_ON
ifdef TIMEOUT
	IV_ARGS += -Ptb_core.C_TIMEOUT=$(TIMEOUT)
endif
IV_ARGS += $(USER_IV_ARGS)

ifdef DUMP
	DUMP_LXT2 := -lxt2
endif

ifdef GATES
	RTL_FILE_LIST := osu035_stdcells.v merlin32i.rtlnopwr.v
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
	rm -f *.dis

build_mem: # -ffreestanding -fPIC -fno-builtin
	$(CC_DIR)/bin/riscv32-unknown-elf-gcc -nostdinc -nostdlib -fPIC -e _entry -T link.ld $(CARGS) $(BOOT_ROM_FILE) -o test.out
	$(CC_DIR)/bin/riscv32-unknown-elf-objcopy -O verilog test.out mem.hex
	#cat mem.hex
	$(CC_DIR)/bin/riscv32-unknown-elf-objdump -D test.out > test.dis

run: build_mem run_only

run_only:
	iverilog $(IV_ARGS) -o tb_core.out -g2012 -I$(RTL_INC_DIR) $(RTL_FILE_LIST) $(TB_FILE_LIST)
	vvp tb_core.out $(DUMP_LXT2)

synth:
	../synth/qflow_exec.sh
	cp /usr/share/qflow/tech/osu035/osu035_stdcells.v osu035_stdcells.v
	cp ../synth/synthesis/merlin32i.rtlnopwr.v merlin32i.rtlnopwr.v

