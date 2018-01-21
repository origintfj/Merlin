> WARNING: cpu clock gating on sleep has had almost no testing - recomend assigning an always-on clock to both 'clk_i' and 'fclk_i' for now.

# RISC-V - Open Source RV32I[C] CPU

This is an open source implementation of a 32-bit base integer (with optional 'C' extension) RISC-V CPU.  It has been written in a version of Verilog which is compatible with a wide variety of open source tools including the open-source ASIC design flow "Qflow".
>Although it appears to be in a functional state it has not yet been fully verified.

## My Vision
Anyone, whether a hobbyist interested in experimenting with RISC-V on an FPGA, someone developing an ASIC using the open source ASIC design flow Qflow, or a company wishing to integrate the core into existing IP, should be able to download build, and use this IP through the use of open source tools alone.

It therefore follows that a fundamental requirement for anyone wishing to contribute to this project is that all changes made maintain compatibility with the open source tools.  As the tools evolve, so too can the verilog source.  I have provided a makefile which allows contributors to test their changes maintain compatibility with the tools I’ve used.  These are:
* iverilog (For simulation)
* verilator (For linting)
* qflow (For ASIC synthesis)
Contributors should use the “lint”, “run”, and “synth” targets in the makefile to verify compatibility is maintained before patching the repository.

>Examples of language constructs which are not yet supported include; enums, structs, and localparams.  For this reason the code uses, for example, \`defines (with an “RV_” prefix to minimise the chances of name collisions) for many global constants used throughout the design, and parameters where localparams would be more suitable.
---

### TODO
* Implement the debug interface.
* Implement the performance counters.

### Optional TODOs
