// =============================================================================
// HardwareDivider — multi-cycle divider for RV32M DIV/DIVU/REM/REMU
// -----------------------------------------------------------------------------
// Sequential restoring divider: one shift/compare/subtract step per clock, so a
// division takes ~34 cycles. The Datapath asserts `start` while a DIV/REM sits
// in EX and stalls the pipeline (stall_EX) until `ready` goes high, then latches
// quotient/remainder.
//
// Signed support: for DIV/REM (is_signed=1) the operands are normalised to their
// magnitudes, divided unsigned, and the result signs are restored per the
// RISC-V rule (round toward zero):
//     quotient  is negative  <=>  operand signs differ
//     remainder takes the sign of the dividend
// Special cases follow the spec:
//     divide-by-zero      -> quotient = -1 (0xFFFFFFFF), remainder = dividend
//     signed overflow      -> -2^31 / -1 = -2^31, remainder 0 (handled naturally,
//                             since |-2^31| = 0x80000000 is representable unsigned)
// =============================================================================
module HardwareDivider (
    input wire clk,
    input wire start,
    input wire is_signed,          // 1 = DIV/REM (signed), 0 = DIVU/REMU (unsigned)
    input wire [31:0] dividend,
    input wire [31:0] divisor,

    output reg [31:0] quotient = 0,
    output reg [31:0] remainder = 0,
    output reg ready = 0
);

    reg [31:0] M = 0;              // divisor magnitude
    reg [63:0] AQ = 0;             // {remainder, quotient} working register
    reg [5:0]  counter = 0;        // remaining iterations
    reg        busy = 0;

    // Result signs, latched at init so they survive the whole computation.
    reg        quotient_neg = 0;
    reg        remainder_neg = 0;

    wire [63:0] shifted_AQ = {AQ[62:0], 1'b0};

    // Operand magnitudes (only negated when signed and negative).
    wire        dividend_neg = is_signed & dividend[31];
    wire        divisor_neg  = is_signed & divisor[31];
    wire [31:0] abs_dividend = dividend_neg ? (~dividend + 1'b1) : dividend;
    wire [31:0] abs_divisor  = divisor_neg  ? (~divisor  + 1'b1) : divisor;

    always @(posedge clk) begin
        if (start && !busy && !ready) begin
            if (divisor == 32'd0) begin
                // Divide-by-zero: quotient all ones (-1), remainder = dividend.
                // Same bit pattern for the signed and unsigned cases.
                quotient  <= 32'hFFFFFFFF;
                remainder <= dividend;
                ready     <= 1'b1;
            end else begin
                // --- Init (cycle 0): load magnitudes, latch result signs ---
                M       <= abs_divisor;
                AQ      <= {32'd0, abs_dividend};
                counter <= 6'd32;
                busy    <= 1'b1;
                ready   <= 1'b0;
                quotient_neg  <= dividend_neg ^ divisor_neg;
                remainder_neg <= dividend_neg;
            end
        end
        else if (busy) begin
            // --- Compute step: unsigned restoring division on the magnitudes ---
            if (counter > 0) begin
                // Shift first (shifted_AQ), THEN compare against the divisor.
                if (shifted_AQ[63:32] >= M) begin
                    // Fits: subtract and set the quotient LSB to 1.
                    AQ <= { (shifted_AQ[63:32] - M), shifted_AQ[31:1], 1'b1 };
                end else begin
                    // Does not fit: keep the shifted value (quotient LSB = 0).
                    AQ <= shifted_AQ;
                end
                counter <= counter - 1;
            end
            else begin
                // --- Done: apply the result signs to the unsigned result ---
                quotient  <= quotient_neg  ? (~AQ[31:0]  + 1'b1) : AQ[31:0];
                remainder <= remainder_neg ? (~AQ[63:32] + 1'b1) : AQ[63:32];
                busy      <= 1'b0;
                ready     <= 1'b1; // releases the pipeline stall
            end
        end
        else begin
            ready <= 1'b0;
        end
    end
endmodule
