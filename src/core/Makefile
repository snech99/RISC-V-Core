# =============================================================================
# Makefile (hardware) — compile and simulate the core with Icarus Verilog
# -----------------------------------------------------------------------------
# Auto-collects every .v file in this directory and its subdirectories, treats
# *_tb.v as the testbench, and builds/runs the simulation. Targets:
#   make / make compile  -> build compiled.vvp
#   make run             -> run the simulation (prints program output)
#   make show            -> run and open the waveform in GTKWave
#   make clean           -> remove build artifacts
# =============================================================================
SRC_ROOT = $(wildcard *.v)
SRC_SUBDIRS = $(wildcard */*.v)

SRC_ALL = $(SRC_ROOT) $(SRC_SUBDIRS)
SRC_MODULES = $(filter-out %_tb.v, $(SRC_ALL))
MAIN_TB = Processor_tb.v

SRC = $(MAIN_TB) $(SRC_MODULES)

OUT = compiled.vvp

VCD = *.vcd

all: compile

compile:
	iverilog -o $(OUT) $(SRC)

run: compile
	vvp $(OUT)

show: run
	gtkwave $(VCD)

clean:
	rm -f $(OUT) $(VCD)