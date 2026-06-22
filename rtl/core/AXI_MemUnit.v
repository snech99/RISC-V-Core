`timescale 1ns / 1ps

// =============================================================================
// AXI4-Lite Master (Read & Write) fuer die MEM-Stage
//
// Fix ggü. Original:
//   - VALID-Signale fallen exakt im Handshake-Takt (kein Lag, kein
//     doppeltes Akzeptieren von AW/W/AR).
//   - AW und W werden GLEICHZEITIG präsentiert (AXI-konform, schneller),
//     BREADY wird vorab gehalten.
//   - ARADDR/AWADDR/WDATA/WSTRB kombinatorisch aus der Pipeline. Während
//     der Transaktion ist stall_MEM=1 -> Pipeline eingefroren -> stabil.
// =============================================================================
module AXI_MemUnit (
    input  wire        clk,
    input  wire        resetn,

    input  wire        mem_req,
    input  wire        mem_write,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [1:0]  mem_store_type, // 00=Byte, 01=Half, 10=Word

    input  wire        core_busy,      // = stall_IF: hält DONE, bis der Core übernimmt

    output reg  [31:0] mem_rdata,
    output wire        stall_MEM,

    // Write
    output wire [31:0] M_AXI_AWADDR,
    output wire [2:0]  M_AXI_AWPROT,
    output reg         M_AXI_AWVALID,
    input  wire        M_AXI_AWREADY,
    output wire [31:0] M_AXI_WDATA,
    output wire [3:0]  M_AXI_WSTRB,
    output reg         M_AXI_WVALID,
    input  wire        M_AXI_WREADY,
    input  wire [1:0]  M_AXI_BRESP,
    input  wire        M_AXI_BVALID,
    output reg         M_AXI_BREADY,

    // Read
    output wire [31:0] M_AXI_ARADDR,
    output wire [2:0]  M_AXI_ARPROT,
    output reg         M_AXI_ARVALID,
    input  wire        M_AXI_ARREADY,
    input  wire [31:0] M_AXI_RDATA,
    input  wire [1:0]  M_AXI_RRESP,
    input  wire        M_AXI_RVALID,
    output reg         M_AXI_RREADY
);

    localparam STATE_IDLE  = 2'b00;
    localparam STATE_READ  = 2'b01;
    localparam STATE_WRITE = 2'b10;
    localparam STATE_DONE  = 2'b11;

    reg [1:0] state;

    assign stall_MEM = mem_req && (state != STATE_DONE);

    assign M_AXI_AWPROT = 3'b000;
    assign M_AXI_ARPROT = 3'b000;

    // Adressen/Daten kombinatorisch aus der (eingefrorenen) Pipeline
    assign M_AXI_AWADDR = mem_addr;
    assign M_AXI_ARADDR = mem_addr;
    assign M_AXI_WDATA  = mem_wdata << {mem_addr[1:0], 3'b000};
    
    // Strobe (Byte Enable) fuer SB/SH/SW
    reg [3:0] wstrb_calc;
    always @(*) begin
        case (mem_store_type)
            2'b00: wstrb_calc = 4'b0001 << mem_addr[1:0];        // SB
            2'b01: wstrb_calc = 4'b0011 << {mem_addr[1], 1'b0};  // SH
            2'b10: wstrb_calc = 4'b1111;                         // SW
            default: wstrb_calc = 4'b1111;
        endcase
    end
    assign M_AXI_WSTRB = wstrb_calc;

    always @(posedge clk) begin
        if (!resetn) begin
            state         <= STATE_IDLE;
            M_AXI_ARVALID <= 1'b0;
            M_AXI_RREADY  <= 1'b0;
            M_AXI_AWVALID <= 1'b0;
            M_AXI_WVALID  <= 1'b0;
            M_AXI_BREADY  <= 1'b0;
            mem_rdata     <= 32'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (mem_req && mem_write) begin
                        M_AXI_AWVALID <= 1'b1;
                        M_AXI_WVALID  <= 1'b1;
                        M_AXI_BREADY  <= 1'b1;
                        state         <= STATE_WRITE;
                    end else if (mem_req && !mem_write) begin
                        M_AXI_ARVALID <= 1'b1;
                        M_AXI_RREADY  <= 1'b1;
                        state         <= STATE_READ;
                    end
                end

                STATE_READ: begin
                    if (M_AXI_ARVALID && M_AXI_ARREADY)
                        M_AXI_ARVALID <= 1'b0;
                    if (M_AXI_RVALID && M_AXI_RREADY) begin
                        mem_rdata    <= M_AXI_RDATA;
                        M_AXI_RREADY <= 1'b0;
                        state        <= STATE_DONE;
                    end
                end

                STATE_WRITE: begin
                    if (M_AXI_AWVALID && M_AXI_AWREADY)
                        M_AXI_AWVALID <= 1'b0;
                    if (M_AXI_WVALID && M_AXI_WREADY)
                        M_AXI_WVALID <= 1'b0;
                    if (M_AXI_BVALID && M_AXI_BREADY) begin
                        M_AXI_BREADY <= 1'b0;
                        state        <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    // Daten/Response liegen bereit (stall_MEM=0). Solange der Core
                    // noch durch die IF-FSM stallt (core_busy=stall_IF), HALTEN wir
                    // hier - die gelesenen Daten bleiben gültig - bis der Core
                    // übernimmt. Verhindert Livelock & doppelte Zugriffe.
                    if (!core_busy) state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
