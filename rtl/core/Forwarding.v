module ForwardingUnit (
    input [4:0] rs1_addr_EX,
    input [4:0] rs2_addr_EX, 
    input [4:0] rd_addr_MEM,
    input       RegWEn_MEM,
    input [4:0] rd_addr_WB,
    input       RegWEn_WB,
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);

    always @(*) begin
        ForwardA = 2'b00;
        ForwardB = 2'b00;

        // ==========================================
        // Forwarding für Operand A (rs1)
        // ==========================================
        
        if (RegWEn_MEM && (rd_addr_MEM != 5'd0) && (rd_addr_MEM == rs1_addr_EX)) begin
            ForwardA = 2'b10;
        end
        else if (RegWEn_WB && (rd_addr_WB != 5'd0) && (rd_addr_WB == rs1_addr_EX)) begin
            ForwardA = 2'b01;
        end

        // ==========================================
        // Forwarding für Operand B (rs2)
        // ==========================================
        
        if (RegWEn_MEM && (rd_addr_MEM != 5'd0) && (rd_addr_MEM == rs2_addr_EX)) begin
            ForwardB = 2'b10;
        end
        else if (RegWEn_WB && (rd_addr_WB != 5'd0) && (rd_addr_WB == rs2_addr_EX)) begin
            ForwardB = 2'b01;
        end
    end

endmodule