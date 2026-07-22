// =============================================================================
// RegisterFile — 32 x 32-bit general-purpose registers
// -----------------------------------------------------------------------------
// Two asynchronous (combinational) read ports for the ID stage and one
// synchronous write port for the WB stage. Register x0 is hardwired to zero:
// reads of x0 return 0 and writes to x0 are ignored.
// =============================================================================
module RegisterFile (
    input [31:0] wdata,
    input [4:0] rs1, 
    input [4:0] rs2,
    input [4:0] rd,
    input RegWEn, 
    input clk,
    output [31:0] rdata1,
    output [31:0] rdata2
);

reg [31:0] register [0:31];

integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        register[i] = 32'd0;
    end
end

assign rdata1 = (rs1 == 5'd0) ? 32'd0 : register[rs1];
assign rdata2 = (rs2 == 5'd0) ? 32'd0 : register[rs2];

always@(posedge clk) begin
    if(RegWEn == 1'b1 && rd != 5'd0) begin
        register[rd] <= wdata;
    end
end


endmodule