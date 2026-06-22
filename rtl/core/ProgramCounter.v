module ProgramCounter (
    input wire clk,
    input wire resetn,      // <-- NEU
    input wire write_enable,
    input wire [31:0] data_bus,
    output reg [31:0] data_out
);
    always @(posedge clk) begin
        if (!resetn) begin
            data_out <= 32'd0;  // Beim Reset springt der PC auf 0 (Startadresse des RAMs)
        end else if (write_enable) begin
            data_out <= data_bus;
        end
    end
endmodule