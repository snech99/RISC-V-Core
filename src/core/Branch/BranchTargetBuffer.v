// =============================================================================
// BranchTargetBuffer (BTB) — the "Jump Table"
// -----------------------------------------------------------------------------
// Target predictor. Direct-mapped, 64 entries, indexed by PC[7:2].
// Each entry: valid bit, tag (PC[31:8]), and the predicted target PC.
//
// Because index (6 bit) + tag (24 bit) = PC[31:2] = the full word address,
// there is NO aliasing: a hit means exactly "a taken branch/JAL was seen at
// this PC before", and the stored target belongs to that very instruction.
//
// Looked up combinationally in IF; allocated/refreshed in EX when a taken
// branch or JAL (never JALR) resolves.
// =============================================================================
module BranchTargetBuffer #(
    parameter INDEX_BITS = 6,                  // 64 entries -> PC[7:2]
    parameter TAG_BITS   = 24,                 // PC[31:8]
    parameter ENTRIES    = (1 << INDEX_BITS)
)(
    input  clk,

    // --- Lookup port (IF stage) ---
    input  [31:0] read_pc,                     // = pc_IF
    output        hit,                         // 1 = known taken branch/jump here
    output [31:0] target,                      // predicted target PC

    // --- Allocate/refresh port (EX stage) ---
    input         write_en,                    // taken branch/JAL resolved (not JALR)
    input  [31:0] write_pc,                    // = pc_EX
    input  [31:0] write_target                 // = alu_result_EX (PC + imm)
);

    localparam IDX_LO = 2;
    localparam IDX_HI = INDEX_BITS + 1;        // = 7  for a 6-bit index
    localparam TAG_LO = INDEX_BITS + 2;        // = 8

    reg                valid_mem  [0:ENTRIES-1];
    reg [TAG_BITS-1:0] tag_mem    [0:ENTRIES-1];
    reg [31:0]         target_mem [0:ENTRIES-1];

    integer i;
    initial begin
        for (i = 0; i < ENTRIES; i = i + 1) begin
            valid_mem[i]  = 1'b0;
            tag_mem[i]    = {TAG_BITS{1'b0}};
            target_mem[i] = 32'b0;
        end
    end

    wire [INDEX_BITS-1:0] read_index  = read_pc [IDX_HI:IDX_LO];
    wire [TAG_BITS-1:0]   read_tag    = read_pc [31:TAG_LO];

    wire [INDEX_BITS-1:0] write_index = write_pc[IDX_HI:IDX_LO];
    wire [TAG_BITS-1:0]   write_tag   = write_pc[31:TAG_LO];

    // Combinational lookup.
    assign hit    = valid_mem[read_index] && (tag_mem[read_index] == read_tag);
    assign target = target_mem[read_index];

    // Allocate / refresh entry (idempotent if it already exists).
    always @(posedge clk) begin
        if (write_en) begin
            valid_mem [write_index] <= 1'b1;
            tag_mem   [write_index] <= write_tag;
            target_mem[write_index] <= write_target;
        end
    end

endmodule