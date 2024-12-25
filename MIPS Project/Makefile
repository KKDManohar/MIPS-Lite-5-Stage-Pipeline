all:	clear compile run	
clear:
	rm -rf work
	rm -rf transcript

compile:
	vlib work
	vlog files.svh

run:
	vsim -c -voptargs=+acc top_tb -do "run -all; exit"