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