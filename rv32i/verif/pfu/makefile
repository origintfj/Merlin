all:
	iverilog -I../../rtl/include -o test.out -g2012 ../../rtl/fifo.v ../../rtl/pfu.v tb_pfu.v
	vvp test.out -lxt2

