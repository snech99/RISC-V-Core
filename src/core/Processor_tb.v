// =============================================================================
// Processor_tb — top-level testbench
// -----------------------------------------------------------------------------
// Instantiates the Datapath, drives a 100 MHz clock (10 ns period), and dumps
// all signals to RISCV.vcd for waveform inspection. There is no explicit
// end-of-program detection: the simulation simply runs for a fixed amount of
// time and then $finish-es, which must be long enough for the loaded program
// (the hardware divider makes each DIV/REM take ~34 cycles).
// =============================================================================
`timescale 1ns / 1ps

module Prozessor_tb;

    reg clk;
    Datapath datapath_inst (
        .clk(clk)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;

        $dumpfile("RISCV.vcd");
        $dumpvars(0, Prozessor_tb);

        #5000000
        $finish;
    end

endmodule