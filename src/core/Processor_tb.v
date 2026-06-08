// main test bench for the Core
`timescale 1ns / 1ps

module Prozessor_tb;

    reg clk;
    Datapath datapath_inst (
        .clk(clk)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;

        // output for GTKWave
        $dumpfile("RISCV.vcd");
        $dumpvars(0, Prozessor_tb);

        #1000000        
        $finish;
    end

endmodule