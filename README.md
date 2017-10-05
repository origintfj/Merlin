# RISC-V - Open Source RV32I[C] CPU

This is an open source implementation or a 32-bit base integer (with optional 'C' extension) RISC-V CPU.  It has been written in a version of Verilog which is compatible with wide variety of open source tools including the open-source ASIC design flow "Qflow".
>Although it appears to be in a functional state it has not yet been fully verified.

## My Vision
Anyone, whether a hobbyist interested in experimenting with RISC-V on an FPGA, someone developing an ASIC using the open source ASIC design flow Qflow, or a company wishing to integrate the core into existing IP, should be able to download build, and use this IP through the use of open source tools alone.

It therefore follows that a fundamental requirement for anyone wishing to contribute to this project is that all changes made maintain compatibility with the with open source tools.  I have provided a makefile which allows contributors to test their changes maintain compatibility with the tools I’ve used.  These are:
* iverilog (For simulation)
* verilator (For linting)
* qflow (For ASIC synthesis)
Contributors should use the “lint”, “run”, and “synth” targets in the makefile to verify compatibility is maintained before patching the repository.
---
![alt text](https://github.com/origintfj/riscv/img/output_screenshot.png "Simulation Output Screenshot")
 

### TODO
* Implement the debug interface.
* Implement the performance counters.

### Optional TODOs



