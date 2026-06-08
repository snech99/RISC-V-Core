SRC_ROOT = $(wildcard *.v)
SRC_SUBDIRS = $(wildcard */*.v)

SRC_ALL = $(SRC_ROOT) $(SRC_SUBDIRS)

SRC = $(SRC_ALL)

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