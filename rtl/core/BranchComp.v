module BranchComp (
    input  [31:0] rs1,
    input  [31:0] rs2,
    input         BrUn,
    output [1:0]  Br_erg   
);

    wire eq = (rs1 == rs2);
    reg lt;
    
    always @(*) begin
        if (BrUn == 1'b1) begin
            lt = (rs1 < rs2);
        end else begin
            lt = ($signed(rs1) < $signed(rs2));
        end
    end
    
    assign Br_erg = {lt, eq};

endmodule