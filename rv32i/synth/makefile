qflow:
	qflow merlin

synth:
	mkdir -p src synth layout
	cp ../rtl/merlin* src/
	cp ../rtl/include/* src/
	./qflow_exec.sh

clean:
	rm -rf src synth layout
	rm -rf *.log *.ys
