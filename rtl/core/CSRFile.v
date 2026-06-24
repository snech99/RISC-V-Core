`timescale 1ns / 1ps
// =============================================================================
// CSRFile  -  Machine-Mode Control & Status Register File (RV32, Zicsr)
//
// Enthaelt den minimalen M-Mode CSR-Satz fuer Interrupts/Exceptions.
// Drei "Kunden" greifen zu:
//   1) Software ueber CSR-Instruktionen (csr_cmd / csr_addr / csr_wdata)
//   2) Die Trap-Hardware beim Eintritt (trap_valid)  -> schreibt mepc/mcause/mstatus
//   3) MRET (mret_valid)                              -> stellt mstatus wieder her
// Prioritaet bei gleichzeitigem Zugriff: Trap > MRET > Software.
//
// Interrupt-Prioritaet (RISC-V Spec):  MEI(11) > MSI(3) > MTI(7)
// Trap-Vektor:  MODE=1 (vectored) -> base + 4*cause  (nur Interrupts);
//               Exceptions gehen immer auf base.
// =============================================================================
module CSRFile (
    input  wire        clk,
    input  wire        resetn,

    // --- Software-Zugriff (aus einer CSR-Instruktion in der Pipeline) --------
    input  wire [11:0] csr_addr,    // CSR-Adresse = inst[31:20]
    input  wire [31:0] csr_wdata,   // rs1 bzw. zero-extended uimm
    input  wire [1:0]  csr_cmd,     // 00=none, 01=write, 10=set, 11=clear
    output reg  [31:0] csr_rdata,   // alter CSR-Wert (-> rd)

    // --- Interrupt-Quellen (level, asynchron) --------------------------------
    input  wire        irq_timer_i,     // -> MTIP
    input  wire        irq_external_i,  // -> MEIP
    input  wire        irq_software_i,  // -> MSIP

    // --- Trap-Eintritt (vom Core im Commit-Takt gepulst) ---------------------
    input  wire        trap_valid,
    input  wire        trap_is_interrupt, // 1=Interrupt, 0=Exception
    input  wire [3:0]  trap_cause,        // Ursachen-Code (low bits)
    input  wire [31:0] trap_pc,           // PC der zu sichernden Instruktion

    // --- MRET ----------------------------------------------------------------
    input  wire        mret_valid,

    // --- Ausgaenge an die Trap-Logik / den PC-Mux ----------------------------
    output wire        interrupt_pending,   // ein freigegebener IRQ wartet
    output wire [3:0]  interrupt_cause,     // dessen Ursache (prioisiert)
    output wire [31:0] trap_vector,         // Sprungziel beim Trap-Eintritt
    output wire [31:0] mepc_o               // Sprungziel bei MRET
);

    // --- CSR-Adressen --------------------------------------------------------
    localparam CSR_MSTATUS  = 12'h300;
    localparam CSR_MIE      = 12'h304;
    localparam CSR_MTVEC    = 12'h305;
    localparam CSR_MSCRATCH = 12'h340;
    localparam CSR_MEPC     = 12'h341;
    localparam CSR_MCAUSE   = 12'h342;
    localparam CSR_MTVAL    = 12'h343;
    localparam CSR_MIP      = 12'h344;

    // --- Ursachen-Codes ------------------------------------------------------
    localparam [3:0] CAUSE_MSI = 4'd3;   // Machine Software Interrupt
    localparam [3:0] CAUSE_MTI = 4'd7;   // Machine Timer    Interrupt
    localparam [3:0] CAUSE_MEI = 4'd11;  // Machine External Interrupt

    // --- Registerinhalte -----------------------------------------------------
    // mstatus: nur die fuer M-Mode-Interrupts relevanten Felder
    reg        mstatus_MIE;   // bit 3  : global interrupt enable
    reg        mstatus_MPIE;  // bit 7  : previous MIE
    reg [1:0]  mstatus_MPP;   // 12:11  : previous privilege (immer 2'b11 = M)

    // mie / mip: nur MSI/MTI/MEI
    reg        mie_MSIE, mie_MTIE, mie_MEIE;
    reg        mip_MSIP, mip_MTIP, mip_MEIP;

    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtval;
    reg [31:0] mscratch;

    // --- Zusammengesetzte Lesewerte ------------------------------------------
    wire [31:0] mstatus_read = {19'd0, mstatus_MPP, 3'd0, mstatus_MPIE,
                                3'd0, mstatus_MIE, 3'd0};
    //   bit positions:  [12:11]=MPP, [7]=MPIE, [3]=MIE
    wire [31:0] mie_read    = {20'd0, mie_MEIE, 3'd0, mie_MTIE, 3'd0, mie_MSIE, 3'd0};
    wire [31:0] mip_read    = {20'd0, mip_MEIP, 3'd0, mip_MTIP, 3'd0, mip_MSIP, 3'd0};

    // --- Software-Lese-Mux ---------------------------------------------------
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS : csr_rdata = mstatus_read;
            CSR_MIE     : csr_rdata = mie_read;
            CSR_MIP     : csr_rdata = mip_read;
            CSR_MTVEC   : csr_rdata = mtvec;
            CSR_MEPC    : csr_rdata = mepc;
            CSR_MCAUSE  : csr_rdata = mcause;
            CSR_MTVAL   : csr_rdata = mtval;
            CSR_MSCRATCH: csr_rdata = mscratch;
            default     : csr_rdata = 32'd0; // unimplementiert -> liest 0
        endcase
    end

    // --- Schreibwert je nach Operation (read-modify-write) -------------------
    reg [31:0] csr_wval;
    always @(*) begin
        case (csr_cmd)
            2'b01  : csr_wval = csr_wdata;             // CSRRW  : write
            2'b10  : csr_wval = csr_rdata | csr_wdata; // CSRRS  : set
            2'b11  : csr_wval = csr_rdata & ~csr_wdata;// CSRRC  : clear
            default: csr_wval = csr_rdata;
        endcase
    end

    // --- Interrupt-Erkennung (kombinatorisch) --------------------------------
    wire mei = mip_MEIP & mie_MEIE;
    wire msi = mip_MSIP & mie_MSIE;
    wire mti = mip_MTIP & mie_MTIE;

    assign interrupt_pending = mstatus_MIE & (mei | msi | mti);
    assign interrupt_cause   = mei ? CAUSE_MEI :   // Prioritaet MEI > MSI > MTI
                               msi ? CAUSE_MSI :
                               mti ? CAUSE_MTI : 4'd0;

    // --- Trap-Vektor (vectored nur fuer Interrupts) --------------------------
    wire [31:0] mtvec_base  = {mtvec[31:2], 2'b00};
    wire        is_vectored = (mtvec[1:0] == 2'b01);
    assign trap_vector = (is_vectored & trap_is_interrupt)
                         ? (mtvec_base + ({28'd0, trap_cause} << 2))
                         : mtvec_base;

    assign mepc_o = mepc;

    // --- Sequentielle Logik --------------------------------------------------
    always @(posedge clk) begin
        if (!resetn) begin
            mstatus_MIE  <= 1'b0;
            mstatus_MPIE <= 1'b0;
            mstatus_MPP  <= 2'b11;
            mie_MSIE     <= 1'b0; mie_MTIE <= 1'b0; mie_MEIE <= 1'b0;
            mip_MSIP     <= 1'b0; mip_MTIP <= 1'b0; mip_MEIP <= 1'b0;
            mtvec        <= 32'd0;
            mepc         <= 32'd0;
            mcause       <= 32'd0;
            mtval        <= 32'd0;
            mscratch     <= 32'd0;
        end else begin
            // 1) Interrupt-Quellen synchronisieren (level -> mip)
            mip_MTIP <= irq_timer_i;
            mip_MEIP <= irq_external_i;
            mip_MSIP <= irq_software_i;

            // 2) Prioritaet: Trap > MRET > Software-Schreibzugriff
            if (trap_valid) begin
                mepc         <= trap_pc & ~32'd3;                  // IALIGN=32
                mcause       <= {trap_is_interrupt, 27'd0, trap_cause};
                mstatus_MPIE <= mstatus_MIE;
                mstatus_MIE  <= 1'b0;
                mstatus_MPP  <= 2'b11;
                if (!trap_is_interrupt) mtval <= 32'd0;            // hier vereinfacht
            end
            else if (mret_valid) begin
                mstatus_MIE  <= mstatus_MPIE;
                mstatus_MPIE <= 1'b1;
                mstatus_MPP  <= 2'b11;
            end
            else if (csr_cmd != 2'b00) begin
                case (csr_addr)
                    CSR_MSTATUS: begin
                        mstatus_MIE  <= csr_wval[3];
                        mstatus_MPIE <= csr_wval[7];
                        mstatus_MPP  <= csr_wval[12:11];
                    end
                    CSR_MIE: begin
                        mie_MSIE <= csr_wval[3];
                        mie_MTIE <= csr_wval[7];
                        mie_MEIE <= csr_wval[11];
                    end
                    CSR_MTVEC   : mtvec    <= csr_wval;
                    CSR_MEPC    : mepc     <= csr_wval & ~32'd3;
                    CSR_MCAUSE  : mcause   <= csr_wval;
                    CSR_MTVAL   : mtval    <= csr_wval;
                    CSR_MSCRATCH: mscratch <= csr_wval;
                    // CSR_MIP : read-only aus Software -> ignoriert
                    default: ; // unimplementiert -> WARL/ignoriert
                endcase
            end
        end
    end

endmodule