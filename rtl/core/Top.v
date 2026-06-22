`timescale 1ns / 1ps

module rv32im_axi_top (
    input wire clk,
    input wire resetn,

    // =========================================================================
    // AXI4-Lite Master: Instruction Fetch (Read-Only)
    // =========================================================================
    output wire [31:0] M_AXI_IF_ARADDR,
    output wire [2:0]  M_AXI_IF_ARPROT,
    output wire        M_AXI_IF_ARVALID,
    input  wire        M_AXI_IF_ARREADY,
    input  wire [31:0] M_AXI_IF_RDATA,
    input  wire [1:0]  M_AXI_IF_RRESP,
    input  wire        M_AXI_IF_RVALID,
    output wire        M_AXI_IF_RREADY,
    // Dummy Write-Channels für Vivados AXI-Erkennung (bleiben ungenutzt)
    output wire [31:0] M_AXI_IF_AWADDR,
    output wire [2:0]  M_AXI_IF_AWPROT,
    output wire        M_AXI_IF_AWVALID,
    input  wire        M_AXI_IF_AWREADY,
    output wire [31:0] M_AXI_IF_WDATA,
    output wire [3:0]  M_AXI_IF_WSTRB,
    output wire        M_AXI_IF_WVALID,
    input  wire        M_AXI_IF_WREADY,
    input  wire [1:0]  M_AXI_IF_BRESP,
    input  wire        M_AXI_IF_BVALID,
    output wire        M_AXI_IF_BREADY,

    // =========================================================================
    // AXI4-Lite Master: Data Memory (Read & Write)
    // =========================================================================
    output wire [31:0] M_AXI_DP_AWADDR,
    output wire [2:0]  M_AXI_DP_AWPROT,
    output wire        M_AXI_DP_AWVALID,
    input  wire        M_AXI_DP_AWREADY,
    output wire [31:0] M_AXI_DP_WDATA,
    output wire [3:0]  M_AXI_DP_WSTRB,
    output wire        M_AXI_DP_WVALID,
    input  wire        M_AXI_DP_WREADY,
    input  wire [1:0]  M_AXI_DP_BRESP,
    input  wire        M_AXI_DP_BVALID,
    output wire        M_AXI_DP_BREADY,
    output wire [31:0] M_AXI_DP_ARADDR,
    output wire [2:0]  M_AXI_DP_ARPROT,
    output wire        M_AXI_DP_ARVALID,
    input  wire        M_AXI_DP_ARREADY,
    input  wire [31:0] M_AXI_DP_RDATA,
    input  wire [1:0]  M_AXI_DP_RRESP,
    input  wire        M_AXI_DP_RVALID,
    output wire        M_AXI_DP_RREADY
);

    // =========================================================================
    // Interne Signale
    // =========================================================================

    // Core Stalls
    wire stall_core_internal; // Load-Use Hazard Stall vom Datapath
    wire stall_div_internal;  // Divider Stall vom Datapath
    wire stall_IF;            // Fetch Unit Stall
    wire stall_MEM;           // Memory Unit Stall

    // Kombiniertes AXI-Stall Signal für den Core
    wire stall_AXI = stall_IF | stall_MEM;

    // Kombiniertes Core-Stall Signal für die Fetch Unit
    wire core_stall_combined = stall_core_internal | stall_div_internal | stall_MEM;

    // IF Verbindungen
    wire [31:0] pc_IF_out;
    wire [31:0] inst_IF_in;

    // MEM Verbindungen
    wire [31:0] alu_result_MEM_out;
    wire [31:0] rdata2_MEM_out;
    wire        MemRW_MEM_out;
    wire        RegWEn_MEM_out;
    wire [1:0]  WBSel_MEM_out;
    wire [1:0]  StoreType_MEM_out;
    wire [2:0]  LoadType_MEM_out;

    wire        mem_req   = ((WBSel_MEM_out == 2'b00) && RegWEn_MEM_out) | MemRW_MEM_out; // echter Load oder Store
    wire        mem_write = MemRW_MEM_out;

    wire [31:0] raw_mem_rdata;
    reg  [31:0] formatted_mem_rdata;

    // =========================================================================
    // RISC-V Load-Formatter (Alignment & Sign-Extension für LB, LH, LW)
    // =========================================================================
    // Verschiebe die rohen 32-Bit Daten basierend auf den untersten 2 Adressbits.
    // Wenn die Adresse z.B. 0x01 ist, rückt das gesuchte Byte an die Position [7:0].
    wire [31:0] shifted_rdata = raw_mem_rdata >> {alu_result_MEM_out[1:0], 3'b000};

    always @(*) begin
        // Annahme: Standard RISC-V funct3 Encoding für Loads
        case (LoadType_MEM_out)
            3'b000:  formatted_mem_rdata = {{24{shifted_rdata[7]}}, shifted_rdata[7:0]};   // LB
            3'b001:  formatted_mem_rdata = {{16{shifted_rdata[15]}}, shifted_rdata[15:0]}; // LH
            3'b010:  formatted_mem_rdata = shifted_rdata;                                  // LW
            3'b011:  formatted_mem_rdata = {24'b0, shifted_rdata[7:0]};                    // LBU
            3'b100:  formatted_mem_rdata = {16'b0, shifted_rdata[15:0]};                   // LHU
            default: formatted_mem_rdata = shifted_rdata;
        endcase
    end

    // =========================================================================
    // Instanziierung: Datapath
    // =========================================================================
    Datapath datapath_inst (
        .clk(clk),
        .resetn(resetn),
        .stall_AXI(stall_AXI),

        // IF Stage
        .pc_IF_out(pc_IF_out),
        .inst_IF_in(inst_IF_in),

        // MEM Stage
        .alu_result_MEM_out(alu_result_MEM_out),
        .rdata2_MEM_out(rdata2_MEM_out),
        .MemRW_MEM_out(MemRW_MEM_out),
        .RegWEn_MEM_out(RegWEn_MEM_out),
        .WBSel_MEM_out(WBSel_MEM_out),
        .StoreType_MEM_out(StoreType_MEM_out),
        .LoadType_MEM_out(LoadType_MEM_out),
        .mem_rdata_in(formatted_mem_rdata), // Hier gehen die formatierten Daten rein!

        // Interne Stalls nach draußen führen
        .stall_out(stall_core_internal),
        .stall_EX_out(stall_div_internal)
    );

    // =========================================================================
    // Instanziierung: AXI Fetch Unit
    // =========================================================================
    AXI_FetchUnit fetch_unit_inst (
        .clk(clk),
        .resetn(resetn),
        .pc_in(pc_IF_out),
        .inst_out(inst_IF_in),
        .stall_IF(stall_IF),
        .core_stall(core_stall_combined),

        .M_AXI_ARADDR(M_AXI_IF_ARADDR),
        .M_AXI_ARPROT(M_AXI_IF_ARPROT),
        .M_AXI_ARVALID(M_AXI_IF_ARVALID),
        .M_AXI_ARREADY(M_AXI_IF_ARREADY),
        .M_AXI_RDATA(M_AXI_IF_RDATA),
        .M_AXI_RRESP(M_AXI_IF_RRESP),
        .M_AXI_RVALID(M_AXI_IF_RVALID),
        .M_AXI_RREADY(M_AXI_IF_RREADY)
    );

    // =========================================================================
    // Instanziierung: AXI Mem Unit
    // =========================================================================
    AXI_MemUnit mem_unit_inst (
        .clk(clk),
        .resetn(resetn),

        .mem_req(mem_req),
        .mem_write(mem_write),
        .mem_addr(alu_result_MEM_out),
        .mem_wdata(rdata2_MEM_out),
        .mem_store_type(StoreType_MEM_out[1:0]),
        .core_busy(stall_IF),

        .mem_rdata(raw_mem_rdata), // Rohe 32-Bit Daten vom Bus
        .stall_MEM(stall_MEM),

        .M_AXI_AWADDR(M_AXI_DP_AWADDR),
        .M_AXI_AWPROT(M_AXI_DP_AWPROT),
        .M_AXI_AWVALID(M_AXI_DP_AWVALID),
        .M_AXI_AWREADY(M_AXI_DP_AWREADY),
        .M_AXI_WDATA(M_AXI_DP_WDATA),
        .M_AXI_WSTRB(M_AXI_DP_WSTRB),
        .M_AXI_WVALID(M_AXI_DP_WVALID),
        .M_AXI_WREADY(M_AXI_DP_WREADY),
        .M_AXI_BRESP(M_AXI_DP_BRESP),
        .M_AXI_BVALID(M_AXI_DP_BVALID),
        .M_AXI_BREADY(M_AXI_DP_BREADY),
        .M_AXI_ARADDR(M_AXI_DP_ARADDR),
        .M_AXI_ARPROT(M_AXI_DP_ARPROT),
        .M_AXI_ARVALID(M_AXI_DP_ARVALID),
        .M_AXI_ARREADY(M_AXI_DP_ARREADY),
        .M_AXI_RDATA(M_AXI_DP_RDATA),
        .M_AXI_RRESP(M_AXI_DP_RRESP),
        .M_AXI_RVALID(M_AXI_DP_RVALID),
        .M_AXI_RREADY(M_AXI_DP_RREADY)
    );

    assign M_AXI_IF_AWADDR  = 32'd0;
    assign M_AXI_IF_AWPROT  = 3'b000;
    assign M_AXI_IF_AWVALID = 1'b0;
    assign M_AXI_IF_WDATA   = 32'd0;
    assign M_AXI_IF_WSTRB   = 4'b0000;
    assign M_AXI_IF_WVALID  = 1'b0;
    assign M_AXI_IF_BREADY  = 1'b1; // Immer bereit, falls der Slave sinnlos antwortet

endmodule
