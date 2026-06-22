module HardwareDivider (
    input wire clk,
    input wire start,
    input wire [31:0] dividend,
    input wire [31:0] divisor,
    
    output reg [31:0] quotient = 0,
    output reg [31:0] remainder = 0,
    output reg ready = 0
);

    reg [31:0] M = 0;
    reg [63:0] AQ = 0;
    reg [5:0]  counter = 0;
    reg        busy = 0;

    wire [63:0] shifted_AQ = {AQ[62:0], 1'b0};

    always @(posedge clk) begin
        if (start && !busy && !ready) begin
            if (divisor == 32'd0) begin
                quotient <= 32'hFFFFFFFF; // -1
                remainder <= dividend;
                ready <= 1'b1;
            end else begin
                // --- Initialisierung (Takt 0) ---
                M <= divisor;
                AQ <= {32'd0, dividend};
                counter <= 6'd32;
                busy <= 1'b1;
                ready <= 1'b0;
            end
        end 
        else if (busy) begin
            // --- Rechenzyklus ---
            if (counter > 0) begin
                // 1. Erst schieben (shifted_AQ), DANN vergleichen!
                if (shifted_AQ[63:32] >= M) begin
                    // Wenn groß genug: Subtrahieren und LSB auf 1 setzen
                    AQ <= { (shifted_AQ[63:32] - M), shifted_AQ[31:1], 1'b1 };
                end else begin
                    // Sonst: Nur geschobenen Wert übernehmen (LSB = 0)
                    AQ <= shifted_AQ;
                end
                counter <= counter - 1;
            end 
            else begin
                // --- Fertig ---
                quotient <= AQ[31:0];
                remainder <= AQ[63:32];
                busy <= 1'b0;
                ready <= 1'b1; // Stall aufheben!
            end
        end 
        else begin
            ready <= 1'b0;
        end
    end
endmodule