module Datapath (
    input wire clk,
    input wire resetn,
    input wire stall_AXI,

    // =========================================================================
    // Interrupt request lines (asynchronous, level-sensitive)
    // =========================================================================
    input  wire        irq_timer_i,     // -> MTIP (e.g. AXI timer)
    input  wire        irq_external_i,  // -> MEIP (e.g. sensor / UART / PLIC)
    input  wire        irq_software_i,  // -> MSIP

    // =========================================================================
    // Interface: Instruction Fetch (IF) -> Geht zur AXI_FetchUnit
    // =========================================================================
    output wire [31:0] pc_IF_out,
    input  wire [31:0] inst_IF_in,

    // =========================================================================
    // Interface: Data Memory (MEM) -> Geht zur AXI_MemUnit
    // =========================================================================
    output wire [31:0] alu_result_MEM_out,
    output wire [31:0] rdata2_MEM_out,
    output wire        MemRW_MEM_out,
    output wire        RegWEn_MEM_out,
    output wire [1:0]  WBSel_MEM_out,
    output wire [1:0]  StoreType_MEM_out,
    output wire [2:0]  LoadType_MEM_out,
    input  wire [31:0] mem_rdata_in,

    // =========================================================================
    // Interne Stalls nach draußen führen (Wichtig für die FetchUnit)
    // =========================================================================
    output wire        stall_out,
    output wire        stall_EX_out
);

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // =========================================================================
    wire [31:0] pc_IF;
    wire [31:0] pc_next_IF = pc_IF + 32'd4;
    wire [31:0] inst_IF = inst_IF_in; // Instruktion kommt jetzt von außen

    // PC an Ausgang leiten
    assign pc_IF_out = pc_IF;

    wire        PCSel_EX;
    wire [31:0] alu_result_EX;
    wire        stall;
    wire        stall_EX;

    // Trap redirect signals (assigned in EX, used here by the PC mux).
    wire        trap_redirect;     // exception/interrupt -> jump to trap vector
    wire        mret_redirect;     // MRET -> jump to mepc
    wire        flush_EX;          // squash younger instructions on any redirect
    wire [31:0] csr_trap_vector;   // from CSRFile
    wire [31:0] csr_mepc;          // from CSRFile

    // Stalls nach außen leiten
    assign stall_out = stall;
    assign stall_EX_out = stall_EX;

    // Select the next PC. Priority: trap > MRET > branch/jump (PCSel) > PC+4.
    wire [31:0] next_pc_in = trap_redirect ? csr_trap_vector :
                             mret_redirect  ? csr_mepc        :
                             PCSel_EX       ? alu_result_EX   :
                                              pc_next_IF;

    ProgramCounter pc_inst (
        .clk(clk),
        .resetn(resetn),
        .write_enable(!stall && !stall_EX && !stall_AXI),
        .data_bus(next_pc_in),
        .data_out(pc_IF)
    );

    // HIER GELÖSCHT: InstructionMemory imem_inst

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 1: IF/ID
    // -------------------------------------------------------------------------
    reg [31:0] pc_ID      = 0;
    reg [31:0] inst_ID    = 0;
    reg [31:0] pc_next_ID = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            pc_ID      <= 32'd0;
            inst_ID    <= 32'h00000013;
            pc_next_ID <= 32'd0;
        end else if (!stall_AXI) begin
            if (flush_EX == 1'b1) begin
                inst_ID    <= 32'h00000013;
                pc_ID      <= 0;
                pc_next_ID <= 0;
            end else if (!stall && !stall_EX) begin
                pc_ID      <= pc_IF;
                inst_ID    <= inst_IF;
                pc_next_ID <= pc_next_IF;
            end
        end
    end


    // =========================================================================
    // STAGE 2: INSTRUCTION DECODE (ID)
    // =========================================================================
    // Extract instruction fields
    wire [4:0] rs1_addr_ID = inst_ID[19:15];
    wire [4:0] rs2_addr_ID = inst_ID[24:20];
    wire [4:0] rd_addr_ID  = inst_ID[11:7];
    wire [2:0] funct3_ID   = inst_ID[14:12];
    wire [11:0] csr_addr_ID = inst_ID[31:20]; // CSR address field

    wire [31:0] rdata1_ID;
    wire [31:0] rdata2_ID;
    wire [31:0] imm_ID;

    // Control signals generated in ID
    wire        RegWEn_ID, ASel_ID, BSel_ID, MemRW_ID, IsJump_ID, IsBranch_ID, BrUn_ID;
    wire [1:0]  WBSel_ID, StoreType_ID;
    wire [2:0]  ImmSel_ID, LoadType_ID;
    wire [4:0]  ALUSel_ID;

    // NEW: System / CSR control signals (Zicsr)
    wire        IsCSR_ID, CSRUseImm_ID, IsMRET_ID, IsECALL_ID, IsEBREAK_ID;
    wire [1:0]  CSRCmd_ID;

    // Writeback signals (coming from STAGE 5)
    wire [31:0] wdata_WB;
    reg  [4:0]  rd_addr_WB = 0;
    reg         RegWEn_WB  = 0;

    ControlUnit controlunit_inst (
        .inst(inst_ID),
        .RegWEn(RegWEn_ID),
        .ASel(ASel_ID),
        .BSel(BSel_ID),
        .ImmSel(ImmSel_ID),
        .ALUSel(ALUSel_ID),
        .WBSel(WBSel_ID),
        .MemRW(MemRW_ID),
        .StoreType(StoreType_ID),
        .LoadType(LoadType_ID),
        .BrUn(BrUn_ID),
        .IsJump(IsJump_ID),
        .IsBranch(IsBranch_ID),
        .IsCSR(IsCSR_ID),
        .CSRCmd(CSRCmd_ID),
        .CSRUseImm(CSRUseImm_ID),
        .IsMRET(IsMRET_ID),
        .IsECALL(IsECALL_ID),
        .IsEBREAK(IsEBREAK_ID)
    );

    RegisterFile rf_inst (
        .clk(clk),
        .rs1(rs1_addr_ID),
        .rs2(rs2_addr_ID),
        .rdata1(rdata1_ID),
        .rdata2(rdata2_ID),
        .RegWEn(RegWEn_WB),
        .rd(rd_addr_WB),
        .wdata(wdata_WB)
    );

    // Internal Forwarding: Resolve Data Hazard if WB is writing to a register ID is currently reading
    wire [31:0] rdata1_fwd_ID = (RegWEn_WB && (rd_addr_WB == rs1_addr_ID) && (rs1_addr_ID != 5'd0)) ? wdata_WB : rdata1_ID;
    wire [31:0] rdata2_fwd_ID = (RegWEn_WB && (rd_addr_WB == rs2_addr_ID) && (rs2_addr_ID != 5'd0)) ? wdata_WB : rdata2_ID;

    ImmGen immgen_inst (
        .inst(inst_ID),
        .ImmSel(ImmSel_ID),
        .imm(imm_ID)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 2: ID/EX
    // -------------------------------------------------------------------------
    reg [31:0] pc_EX = 0, rdata1_EX = 0, rdata2_EX = 0, imm_EX = 0, alu_result_MEM = 0;
    reg [4:0]  rd_addr_EX  = 0;
    reg [31:0] pc_next_EX  = 0;
    reg [4:0]  rs1_addr_EX = 0, rs2_addr_EX = 0;
    reg [2:0]  funct3_EX   = 0;

    reg        RegWEn_EX=0, ASel_EX=0, BSel_EX=0, MemRW_EX=0, IsJump_EX=0, IsBranch_EX=0, BrUn_EX=0;
    reg [1:0]  WBSel_EX=0, StoreType_EX=0;
    reg [2:0]  LoadType_EX=0;
    reg [4:0]  ALUSel_EX=0;

    // NEW: CSR pipeline state carried into EX
    reg        IsCSR_EX=0, CSRUseImm_EX=0;
    reg [1:0]  CSRCmd_EX=0;
    reg [11:0] csr_addr_EX=0;

    // NEW: trap/system pipeline state carried into EX
    reg        IsMRET_EX=0, IsECALL_EX=0, IsEBREAK_EX=0;

    // NEW: marks whether EX currently holds a real instruction (not a bubble).
    // Needed so an interrupt is only taken on a valid victim (correct mepc).
    reg        valid_EX=0;

    // Load-Use Hazard Detection
    assign stall = (WBSel_EX == 2'b00) && (RegWEn_EX == 1'b1) && (rd_addr_EX != 5'd0) &&
                   ((rd_addr_EX == rs1_addr_ID) || (rd_addr_EX == rs2_addr_ID));

    always @(posedge clk) begin
        if (!resetn) begin
            // RESET STATE: Control-Signale deaktivieren
            RegWEn_EX   <= 1'b0;
            MemRW_EX    <= 1'b0;
            IsJump_EX   <= 1'b0;
            IsBranch_EX <= 1'b0;
            ASel_EX     <= 1'b0;
            BSel_EX     <= 1'b0;
            BrUn_EX     <= 1'b0;
            WBSel_EX    <= 2'b00;
            StoreType_EX<= 2'b00;
            LoadType_EX <= 3'b000;
            ALUSel_EX   <= 5'b00000;

            // RESET STATE: Datensignale nullen
            pc_EX       <= 32'd0;
            rdata1_EX   <= 32'd0;
            rdata2_EX   <= 32'd0;
            imm_EX      <= 32'd0;
            rd_addr_EX  <= 5'd0;
            pc_next_EX  <= 32'd0;
            rs1_addr_EX <= 5'd0;
            rs2_addr_EX <= 5'd0;
            funct3_EX   <= 3'd0;

            // NEW: CSR reset
            IsCSR_EX     <= 1'b0;
            CSRUseImm_EX <= 1'b0;
            CSRCmd_EX    <= 2'b00;
            csr_addr_EX  <= 12'd0;

            // NEW: trap/system reset
            IsMRET_EX    <= 1'b0;
            IsECALL_EX   <= 1'b0;
            IsEBREAK_EX  <= 1'b0;
            valid_EX     <= 1'b0;
        end else if (!stall_AXI) begin
            // NORMAL OPERATION & STALL LOGIC
            if (flush_EX == 1'b1 || stall == 1'b1) begin
                RegWEn_EX   <= 1'b0;
                MemRW_EX    <= 1'b0;
                IsJump_EX   <= 1'b0;
                IsBranch_EX <= 1'b0;
                IsCSR_EX    <= 1'b0; // NEW: do not commit a CSR write for a bubble
                IsMRET_EX   <= 1'b0; // NEW: squashed system instr must not redirect
                IsECALL_EX  <= 1'b0;
                IsEBREAK_EX <= 1'b0;
                valid_EX    <= 1'b0; // NEW: bubble -> not a valid victim
            end else if (!stall_EX) begin
                pc_EX       <= pc_ID;
                rdata1_EX   <= rdata1_fwd_ID;
                rdata2_EX   <= rdata2_fwd_ID;
                imm_EX      <= imm_ID;
                rd_addr_EX  <= rd_addr_ID;
                pc_next_EX  <= pc_next_ID;
                rs1_addr_EX <= rs1_addr_ID;
                rs2_addr_EX <= rs2_addr_ID;
                funct3_EX   <= funct3_ID;

                RegWEn_EX   <= RegWEn_ID;
                ASel_EX     <= ASel_ID;
                BSel_EX     <= BSel_ID;
                MemRW_EX    <= MemRW_ID;
                IsJump_EX   <= IsJump_ID;
                IsBranch_EX <= IsBranch_ID;
                BrUn_EX     <= BrUn_ID;
                WBSel_EX    <= WBSel_ID;
                StoreType_EX<= StoreType_ID;
                LoadType_EX <= LoadType_ID;
                ALUSel_EX   <= ALUSel_ID;

                IsCSR_EX     <= IsCSR_ID;
                CSRUseImm_EX <= CSRUseImm_ID;
                CSRCmd_EX    <= CSRCmd_ID;
                csr_addr_EX  <= csr_addr_ID;

                IsMRET_EX    <= IsMRET_ID;
                IsECALL_EX   <= IsECALL_ID;
                IsEBREAK_EX  <= IsEBREAK_ID;
                valid_EX     <= 1'b1; // NEW: a real instruction now occupies EX
            end
        end
    end


    // =========================================================================
    // STAGE 3: EXECUTE (EX)
    // =========================================================================
    wire [1:0]  Br_erg_EX;
    wire [1:0]  ForwardA, ForwardB;
    reg  [4:0]  rd_addr_MEM = 0;
    reg         RegWEn_MEM  = 0;
    reg [1:0]   WBSel_MEM=0;
    // Declared here (before wb_value_MEM uses them); written in the EX/MEM block.
    reg [31:0]  pc_next_MEM = 0;
    reg [31:0]  csr_rdata_MEM = 0; // old CSR value en route to WB

    wire [31:0] mem_MEM = mem_rdata_in; // Daten kommen von Außen (AXI Bus)

    // Determine if branch condition is met
    reg branch_taken;
    always @(*) begin
        branch_taken = 1'b0;
        if (IsBranch_EX) begin
            case (funct3_EX)
                3'b000: branch_taken =  Br_erg_EX[0]; // BEQ
                3'b001: branch_taken = !Br_erg_EX[0]; // BNE
                3'b100: branch_taken =  Br_erg_EX[1]; // BLT
                3'b101: branch_taken = !Br_erg_EX[1]; // BGE
                3'b110: branch_taken =  Br_erg_EX[1]; // BLTU
                3'b111: branch_taken = !Br_erg_EX[1]; // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    assign PCSel_EX = IsJump_EX | branch_taken;

    ForwardingUnit fw_inst (
        .rs1_addr_EX(rs1_addr_EX),
        .rs2_addr_EX(rs2_addr_EX),
        .rd_addr_MEM(rd_addr_MEM),
        .RegWEn_MEM(RegWEn_MEM),
        .rd_addr_WB(rd_addr_WB),
        .RegWEn_WB(RegWEn_WB),
        .ForwardA(ForwardA),
        .ForwardB(ForwardB)
    );

    // Writeback-source mux used for MEM-stage forwarding. It must mirror the WB
    // mux so that JAL/JALR (PC+4) and CSR read values are forwarded correctly,
    // not only load data and ALU results.
    wire [31:0] wb_value_MEM = (WBSel_MEM == 2'b00) ? mem_MEM        :
                               (WBSel_MEM == 2'b01) ? alu_result_MEM :
                               (WBSel_MEM == 2'b10) ? pc_next_MEM    :
                                                      csr_rdata_MEM;

    // Apply forwarding logic
    wire [31:0] forward_a_val = (ForwardA == 2'b10) ? wb_value_MEM :
                                (ForwardA == 2'b01) ? wdata_WB :
                                rdata1_EX;

    wire [31:0] forward_b_val = (ForwardB == 2'b10) ? wb_value_MEM :
                                (ForwardB == 2'b01) ? wdata_WB :
                                rdata2_EX;

    wire [31:0] alu_a_in = ASel_EX ? pc_EX : forward_a_val;
    wire [31:0] alu_b_in = BSel_EX ? imm_EX : forward_b_val;

    wire        div_ready;
    wire [31:0] div_quotient;
    wire [31:0] div_remainder;

    wire is_div_instruction = (ALUSel_EX >= 5'b10100) && (ALUSel_EX <= 5'b10111);
    assign stall_EX = is_div_instruction && !div_ready;

    wire [31:0] divider_result = (ALUSel_EX == 5'b10110 || ALUSel_EX == 5'b10111) ? div_remainder : div_quotient;

    HardwareDivider divi_inst (
        .clk(clk),
        .start(is_div_instruction),
        .dividend(forward_a_val),
        .divisor(forward_b_val),
        .quotient(div_quotient),
        .remainder(div_remainder),
        .ready(div_ready)
    );

    ArithmeticLogicUnit alu_inst (
        .op1(alu_a_in),
        .op2(alu_b_in),
        .op_select(ALUSel_EX),
        .data_out(alu_result_EX),
        .zero_flag(),
        .sign_out(),
        .carry_out()
    );

    wire [31:0] final_ex_result = is_div_instruction ? divider_result : alu_result_EX;

    // -------------------------------------------------------------------------
    // CSR ACCESS (executed in EX): combinational read, registered write.
    // The write commits on the same edge the instruction advances into MEM, so
    // a back-to-back CSR instruction one cycle later observes the new value.
    // -------------------------------------------------------------------------
    wire [31:0] csr_rdata_EX;          // old CSR value -> rd through writeback
    wire [31:0] csr_wdata_EX = CSRUseImm_EX ? {27'd0, rs1_addr_EX} : forward_a_val;

    // CSRRS/CSRRC with rs1 (or uimm) == 0 must not write (read-only access).
    wire        csr_no_write = (CSRCmd_EX == 2'b10 || CSRCmd_EX == 2'b11)
                               && (rs1_addr_EX == 5'd0);

    // Commit only on the cycle the instruction actually leaves EX.
    wire        csr_advance  = !stall_AXI && !stall_EX;

    // CSRFile combinational outputs (csr_trap_vector / csr_mepc are forward-
    // declared near the PC mux).
    wire        csr_int_pending;
    wire [3:0]  csr_int_cause;

    // -------------------------------------------------------------------------
    // TRAP LOGIC
    //   Step 3a: ECALL / EBREAK raise a synchronous exception, MRET returns.
    //   Step 3b: a pending+enabled interrupt is taken on the valid instruction
    //            currently in EX (the "victim"): squash it, save its PC in mepc,
    //            and re-run it after MRET.
    // -------------------------------------------------------------------------
    wire        is_exception_EX = IsECALL_EX | IsEBREAK_EX;
    wire [3:0]  exc_cause       = IsEBREAK_EX ? 4'd3 : 4'd11; // breakpoint=3, ecall-from-M=11

    // Take an interrupt only on a real instruction, not on ECALL/EBREAK/MRET,
    // and only when EX actually advances (so it pulses once).
    wire        int_take = csr_int_pending & valid_EX & !is_exception_EX
                           & !IsMRET_EX & csr_advance;

    // A CSR write must not commit if its instruction becomes an interrupt victim.
    wire [1:0]  csr_cmd_eff  = (IsCSR_EX && !csr_no_write && csr_advance && !int_take)
                               ? CSRCmd_EX : 2'b00;

    assign trap_redirect = is_exception_EX | int_take; // -> PC = trap vector
    assign mret_redirect = IsMRET_EX;                  // -> PC = mepc
    assign flush_EX      = PCSel_EX | trap_redirect | mret_redirect;

    // Cause / kind selection: interrupt wins (exception is gated out of int_take).
    wire        trap_is_int   = int_take;
    wire [3:0]  trap_cause_sel = int_take ? csr_int_cause : exc_cause;

    // Pulse the CSR exactly on the cycle the instruction leaves EX (csr_advance).
    wire        trap_fire = trap_redirect & csr_advance;
    wire        mret_fire = mret_redirect & csr_advance;

    CSRFile csr_inst (
        .clk(clk),
        .resetn(resetn),
        .csr_addr(csr_addr_EX),
        .csr_wdata(csr_wdata_EX),
        .csr_cmd(csr_cmd_eff),
        .csr_rdata(csr_rdata_EX),
        .irq_timer_i(irq_timer_i),
        .irq_external_i(irq_external_i),
        .irq_software_i(irq_software_i),
        .trap_valid(trap_fire),
        .trap_is_interrupt(trap_is_int),
        .trap_cause(trap_cause_sel),
        .trap_pc(pc_EX),           // exception: this instr; interrupt: the victim
        .mret_valid(mret_fire),
        .interrupt_pending(csr_int_pending),
        .interrupt_cause(csr_int_cause),
        .trap_vector(csr_trap_vector),
        .mepc_o(csr_mepc)
    );

    BranchComp branch_inst(
        .rs1(forward_a_val),
        .rs2(forward_b_val),
        .BrUn(BrUn_EX),
        .Br_erg(Br_erg_EX)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 3: EX/MEM
    // -------------------------------------------------------------------------
    reg [31:0] rdata2_MEM  = 0;
    // pc_next_MEM and csr_rdata_MEM are declared earlier (used by wb_value_MEM).

    reg        MemRW_MEM = 0;
    reg [1:0]  StoreType_MEM = 0;
    reg [2:0]  LoadType_MEM = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            // RESET STATE: Schreibsignale deaktivieren
            RegWEn_MEM     <= 1'b0;
            MemRW_MEM      <= 1'b0;
            WBSel_MEM      <= 2'b00;
            StoreType_MEM  <= 2'b00;
            LoadType_MEM   <= 3'b000;

            // RESET STATE: Datensignale nullen
            alu_result_MEM <= 32'd0;
            rdata2_MEM     <= 32'd0;
            rd_addr_MEM    <= 5'd0;
            pc_next_MEM    <= 32'd0;
            csr_rdata_MEM  <= 32'd0;
        end else if (!stall_AXI) begin
            // NORMAL OPERATION & STALL LOGIC
            if (stall_EX) begin
                RegWEn_MEM     <= 1'b0;
                MemRW_MEM      <= 1'b0;
            end else begin
                alu_result_MEM <= final_ex_result;
                rdata2_MEM     <= forward_b_val;
                rd_addr_MEM    <= rd_addr_EX;
                pc_next_MEM    <= pc_next_EX;

                RegWEn_MEM     <= RegWEn_EX;
                MemRW_MEM      <= MemRW_EX;
                WBSel_MEM      <= WBSel_EX;
                StoreType_MEM  <= StoreType_EX;
                LoadType_MEM   <= LoadType_EX;
                csr_rdata_MEM  <= csr_rdata_EX;

                // Interrupt victim: suppress its writeback and memory effects.
                // mepc points at it, so it re-executes after MRET.
                if (int_take) begin
                    RegWEn_MEM <= 1'b0;
                    MemRW_MEM  <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // STAGE 4: MEMORY (MEM)
    // =========================================================================
    // HIER GELÖSCHT: DataMemory dmem_inst

    // Signale nach außen leiten (Zur AXI_MemUnit bzw. Load Formatter)
    assign alu_result_MEM_out = alu_result_MEM;
    assign rdata2_MEM_out     = rdata2_MEM;
    assign MemRW_MEM_out      = MemRW_MEM;
    assign RegWEn_MEM_out     = RegWEn_MEM;
    assign WBSel_MEM_out      = WBSel_MEM;
    assign StoreType_MEM_out  = StoreType_MEM;
    assign LoadType_MEM_out   = LoadType_MEM;


    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 4: MEM/WB
    // -------------------------------------------------------------------------
    reg [31:0] alu_result_WB = 0, mem_WB = 0;
    reg [31:0] pc_next_WB = 0;
    reg [1:0]  WBSel_WB = 0;
    reg [31:0] csr_rdata_WB = 0; // NEW

    always @(posedge clk) begin
        if (!resetn) begin
            // RESET STATE
            RegWEn_WB     <= 1'b0;
            WBSel_WB      <= 2'b00;
            alu_result_WB <= 32'd0;
            mem_WB        <= 32'd0;
            rd_addr_WB    <= 5'd0;
            pc_next_WB    <= 32'd0;
            csr_rdata_WB  <= 32'd0;
        end else if (!stall_AXI) begin
            // NORMAL OPERATION (Keine Hazards mehr in dieser Stufe)
            alu_result_WB <= alu_result_MEM;
            mem_WB        <= mem_MEM;
            rd_addr_WB    <= rd_addr_MEM;
            pc_next_WB    <= pc_next_MEM;

            RegWEn_WB     <= RegWEn_MEM;
            WBSel_WB      <= WBSel_MEM;
            csr_rdata_WB  <= csr_rdata_MEM;
        end
    end


    // =========================================================================
    // STAGE 5: WRITEBACK (WB)
    // =========================================================================

    assign wdata_WB = (WBSel_WB == 2'b00) ? mem_WB        :
                      (WBSel_WB == 2'b01) ? alu_result_WB :
                      (WBSel_WB == 2'b10) ? pc_next_WB    :
                                            csr_rdata_WB;

endmodule