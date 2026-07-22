// =============================================================================
// ImmGen — immediate generator (ID stage)
// -----------------------------------------------------------------------------
// Combinational. Extracts and sign-extends the immediate encoded in the
// instruction according to the format selected by ImmSel (I, S, B, J, U).
// B- and J-type immediates are reassembled from their scattered bit fields and
// carry an implicit low zero bit (targets are 2-byte aligned).
// =============================================================================
module ImmGen (
    input [31:0] inst,
    input [2:0] ImmSel,
    output reg [31:0] imm
);

always@(*) begin
    case (ImmSel)
        // I-Type
        3'b001: imm = {{20{inst[31]}}, inst[31:20]};
        
        // S-Type
        3'b010: imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
        
        // B-Type
        3'b011: imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};

        // J-Type
        3'b100: imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

        // U-Type
        3'b101: imm = {inst[31:12], 12'd0};
        
        default: imm = 32'd0;
    endcase
end

endmodule