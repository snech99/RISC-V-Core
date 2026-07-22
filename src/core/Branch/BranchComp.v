// =============================================================================
// BranchComp — branch comparator (EX stage)
// -----------------------------------------------------------------------------
// Combinational. Compares rs1 and rs2 and reports two flags in Br_erg:
//     Br_erg[0] = equal (rs1 == rs2)
//     Br_erg[1] = less-than; signed when BrUn=0, unsigned when BrUn=1
// The Datapath turns these flags into the actual taken/not-taken decision per
// the branch funct3 (BEQ/BNE/BLT/BGE/BLTU/BGEU).
// =============================================================================
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