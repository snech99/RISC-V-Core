// =============================================================================
// ProgramCounter (PC) — instruction address register (IF stage)
// -----------------------------------------------------------------------------
// A simple synchronous 32-bit register holding the address of the instruction
// being fetched. write_enable is deasserted to freeze the PC during a stall
// (load-use or divider), so the same instruction is re-fetched next cycle.
// =============================================================================
module ProgramCounter (
    input [31:0] data_bus,
    input write_enable,
    input  clk, 
    output reg [31:0] data_out
);

initial begin
    data_out <= 32'b0;
end

always@(posedge clk) begin
    if(write_enable) begin
        data_out <= data_bus;
    end 
end

endmodule