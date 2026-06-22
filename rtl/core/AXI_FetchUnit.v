`timescale 1ns / 1ps

// =============================================================================
// AXI4-Lite Master (Read-Only) fuer Instruction Fetch
//
// Fix ggü. Original:
//   - VALID/READY werden in EINEM getakteten Block zusammen mit der
//     State-Logik geführt -> kein Lag mehr, ARVALID fällt exakt im Takt
//     nach dem Handshake.
//   - ARADDR kombinatorisch = pc_in. Während Fetch ist stall_IF=1 -> der
//     PC ist eingefroren, die Adresse also über den ganzen Handshake stabil.
//     Nur in STATE_DONE läuft der PC weiter, da findet aber kein AR-Handshake
//     statt -> immer die richtige Adresse, ohne Stale-Address-Risiko.
// =============================================================================
module AXI_FetchUnit (
    input  wire        clk,
    input  wire        resetn,

    input  wire [31:0] pc_in,
    output reg  [31:0] inst_out,
    output wire        stall_IF,
    input  wire        core_stall,

    // AXI4-Lite Master Interface (Read-Only)
    output wire [31:0] M_AXI_ARADDR,
    output wire [2:0]  M_AXI_ARPROT,
    output reg         M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,

    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RVALID,
    output reg         M_AXI_RREADY
);

    localparam STATE_IDLE = 2'b00;
    localparam STATE_ADDR = 2'b01;
    localparam STATE_DATA = 2'b10;
    localparam STATE_DONE = 2'b11;

    reg [1:0] state;

    assign M_AXI_ARPROT = 3'b000;
    assign M_AXI_ARADDR = pc_in;            // PC ist während des Fetch eingefroren
    assign stall_IF     = (state != STATE_DONE);

    always @(posedge clk) begin
        if (!resetn) begin
            state         <= STATE_IDLE;
            M_AXI_ARVALID <= 1'b0;
            M_AXI_RREADY  <= 1'b0;
            inst_out      <= 32'h00000013; // NOP (addi x0,x0,0)
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (!core_stall) begin
                        M_AXI_ARVALID <= 1'b1;
                        state         <= STATE_ADDR;
                    end
                end

                STATE_ADDR: begin
                    // Adresse akzeptiert -> ARVALID SOFORT fallen lassen,
                    // direkt RREADY hochziehen (vor RVALID erlaubt).
                    if (M_AXI_ARVALID && M_AXI_ARREADY) begin
                        M_AXI_ARVALID <= 1'b0;
                        M_AXI_RREADY  <= 1'b1;
                        state         <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        inst_out     <= M_AXI_RDATA;
                        M_AXI_RREADY <= 1'b0;
                        state        <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    // stall_IF=0: der Core übernimmt inst_out, sobald er bereit ist.
                    // Solange der Core noch stallt (z.B. laufender MEM-Zugriff über
                    // core_stall), HALTEN wir hier - die Instruktion bleibt gültig -
                    // statt nach IDLE zurückzufallen. Das verhindert den Livelock
                    // zwischen IF- und MEM-FSM: wer zuerst fertig ist, wartet auf den
                    // anderen, bis stall_AXI in einem gemeinsamen Takt 0 wird.
                    if (!core_stall) begin
                        M_AXI_ARVALID <= 1'b1; // ARADDR=pc_in liefert dann den NEUEN PC
                        state         <= STATE_ADDR;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
