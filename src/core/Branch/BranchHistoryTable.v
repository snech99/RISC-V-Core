// =============================================================================
// BranchHistoryTable (BHT)
// -----------------------------------------------------------------------------
// Direction predictor. One 2-bit saturating counter per entry, indexed by
// PC[7:2] (64 entries). Read combinationally in IF, updated in EX when a
// conditional branch (or JAL) resolves.
//
// 2-bit FSM exactly as in the lecture (slide 23). MSB of the state is the
// prediction (1 = predict taken):
//     11 = strongly taken      10 = weakly taken
//     01 = weakly not-taken     00 = strongly not-taken
// =============================================================================
module BranchHistoryTable #(
    parameter INDEX_BITS = 6,                  // 64 entries -> PC[7:2]
    parameter ENTRIES    = (1 << INDEX_BITS)
)(
    input  clk,

    // --- Read port (IF stage) ---
    input  [INDEX_BITS-1:0] read_index,        // = pc_IF[7:2]
    output                  predict_taken,     // 1 = predict taken

    // --- Update port (EX stage) ---
    input                   update_en,         // assert when a branch/JAL resolves
    input  [INDEX_BITS-1:0] update_index,      // = pc_EX[7:2]
    input                   actual_taken       // real outcome (1 = taken)
);

    reg [1:0] table_mem [0:ENTRIES-1];

    integer i;
    initial begin
        for (i = 0; i < ENTRIES; i = i + 1)
            table_mem[i] = 2'b01;              // start: weakly not-taken
    end

    // Combinational read: prediction is the MSB of the indexed counter.
    assign predict_taken = table_mem[read_index][1];

    // State transition per the lecture's 2-bit FSM (slide 23):
    //   11: T->11  NT->10
    //   10: T->11  NT->00
    //   01: T->11  NT->00
    //   00: T->01  NT->00
    function [1:0] next_state;
        input [1:0] state;
        input       taken;
        begin
            case (state)
                2'b11:   next_state = taken ? 2'b11 : 2'b10;
                2'b10:   next_state = taken ? 2'b11 : 2'b00;
                2'b01:   next_state = taken ? 2'b11 : 2'b00;
                2'b00:   next_state = taken ? 2'b01 : 2'b00;
                default: next_state = 2'b01;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (update_en)
            table_mem[update_index] <= next_state(table_mem[update_index], actual_taken);
    end

endmodule
