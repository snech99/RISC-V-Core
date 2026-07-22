// =============================================================================
// Datapath — top-level structural integration of the RV32IM core
// -----------------------------------------------------------------------------
// Wires together all functional units into a classic in-order 5-stage pipeline
// (IF, ID, EX, MEM, WB) and owns every pipeline register. It also implements:
//   * internal WB->ID forwarding and the MEM/WB forwarding via ForwardingUnit
//   * load-use hazard detection (stall) and the multi-cycle divider stall (stall_EX)
//   * branch prediction (BHT + BTB) with resolution/recovery in EX
// This module contains no algorithmic logic of its own; it is the map that
// connects the leaf modules and steers data between stages.
// =============================================================================
module Datapath (
    input clk
);

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF)
    // =========================================================================
    wire [31:0] pc_IF;
    wire [31:0] pc_next_IF = pc_IF + 32'd4;
    wire [31:0] inst_IF;

    wire        PCSel_EX;        // NOW: "misprediction detected in EX" (drives flush)
    wire [31:0] recover_pc_EX;   // correct PC to resume from after a misprediction
    wire [31:0] alu_result_EX;
    wire        stall;
    wire        stall_EX;

    // --- Branch prediction lookups (driven by the BHT/BTB instances below) ---
    wire        predict_taken_bht_IF;  // BHT direction prediction for pc_IF
    wire        btb_hit_IF;            // BTB has a (taken) entry for pc_IF
    wire [31:0] btb_target_IF;         // BTB predicted target for pc_IF

    // Predict taken only if the BTB knows the target AND the BHT votes taken.
    wire        predict_taken_IF = btb_hit_IF & predict_taken_bht_IF;

    // Next-PC priority: EX recovery (misprediction) > IF prediction > PC + 4
    wire [31:0] next_pc_in = PCSel_EX        ? recover_pc_EX  :
                             predict_taken_IF ? btb_target_IF :
                             pc_next_IF;

    ProgramCounter pc_inst (
        .clk(clk),
        .write_enable(!stall && !stall_EX),      // freeze PC if a stall is detected
        .data_bus(next_pc_in),
        .data_out(pc_IF)
    );

    InstructionMemory imem_inst (
        .addr(pc_IF),
        .inst(inst_IF)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 1: IF/ID
    // -------------------------------------------------------------------------
    reg [31:0] pc_ID      = 0;
    reg [31:0] inst_ID    = 0;
    reg [31:0] pc_next_ID = 0;

    // Prediction metadata travelling with the instruction.
    reg        predicted_taken_ID  = 0;
    reg [31:0] predicted_target_ID = 0;

    always @(posedge clk) begin
        if (PCSel_EX == 1'b1) begin
            // Misprediction recovery: insert NOP (addi x0, x0, 0) and drop any prediction.
            inst_ID             <= 32'h00000013;
            pc_ID               <= 0;
            pc_next_ID          <= 0;
            predicted_taken_ID  <= 1'b0;
            predicted_target_ID <= 32'b0;
        end else if (!stall && !stall_EX) begin
            // Normal operation: pass values (and the prediction made in IF) onward.
            pc_ID               <= pc_IF;
            inst_ID             <= inst_IF;
            pc_next_ID          <= pc_next_IF;
            predicted_taken_ID  <= predict_taken_IF;
            predicted_target_ID <= btb_target_IF;
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

    wire [31:0] rdata1_ID;
    wire [31:0] rdata2_ID;
    wire [31:0] imm_ID;

    // Control signals generated in ID
    wire        RegWEn_ID, ASel_ID, BSel_ID, MemRW_ID, IsJump_ID, IsBranch_ID, BrUn_ID;
    wire [1:0]  WBSel_ID, StoreType_ID;
    wire [2:0]  ImmSel_ID, LoadType_ID;
    wire [4:0]  ALUSel_ID;

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
        .IsBranch(IsBranch_ID)
    );

    RegisterFile rf_inst (
        .clk(clk),
        // read ports -> ID Stage
        .rs1(rs1_addr_ID),
        .rs2(rs2_addr_ID),
        .rdata1(rdata1_ID),
        .rdata2(rdata2_ID),
        // write port -> WB Stage
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

    // Prediction metadata for the instruction now entering EX.
    reg        predicted_taken_EX  = 0;
    reg [31:0] predicted_target_EX = 0;

    // Load-Use Hazard Detection: Stall if EX stage is executing a Load and the destination matches ID sources
    assign stall = (WBSel_EX == 2'b00) && (RegWEn_EX == 1'b1) && (rd_addr_EX != 5'd0) &&
                   ((rd_addr_EX == rs1_addr_ID) || (rd_addr_EX == rs2_addr_ID));

    always @(posedge clk) begin
        if (PCSel_EX == 1'b1 || stall == 1'b1) begin
            // Flush control signals to prevent executing incorrect instructions.
            RegWEn_EX          <= 0;
            MemRW_EX           <= 0;
            IsJump_EX          <= 0;
            IsBranch_EX        <= 0;
            predicted_taken_EX <= 0;   // a bubble carries no prediction
        end else if (!stall_EX) begin
            // Pass data to EX
            pc_EX       <= pc_ID;
            rdata1_EX   <= rdata1_fwd_ID;
            rdata2_EX   <= rdata2_fwd_ID;
            imm_EX      <= imm_ID;
            rd_addr_EX  <= rd_addr_ID;
            pc_next_EX  <= pc_next_ID;
            rs1_addr_EX <= rs1_addr_ID;
            rs2_addr_EX <= rs2_addr_ID;
            funct3_EX   <= funct3_ID;

            // Pass control signals to EX
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

            // Pass prediction metadata to EX
            predicted_taken_EX  <= predicted_taken_ID;
            predicted_target_EX <= predicted_target_ID;
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
    wire [31:0] mem_MEM;

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

    // -------------------------------------------------------------------------
    // BRANCH PREDICTION: verification + recovery (resolution happens here in EX)
    // -------------------------------------------------------------------------
    // Ground truth produced in EX:
    wire        actual_taken_EX = IsJump_EX | branch_taken;   // taken jump or taken branch
    wire        is_jalr_EX      = IsJump_EX & ~ASel_EX;       // JALR = jump with rs1-based target
                                                              // (JAL/branch use ASel=PC=1)

    // Misprediction = wrong direction, OR right (taken) direction but wrong target.
    wire        target_wrong_EX = actual_taken_EX & predicted_taken_EX &
                                  (alu_result_EX != predicted_target_EX);
    wire        mispredict_EX   = (actual_taken_EX ^ predicted_taken_EX) | target_wrong_EX;

    // Drive the (existing) flush signal and the recovery target.
    assign PCSel_EX      = mispredict_EX;
    assign recover_pc_EX = actual_taken_EX ? alu_result_EX : pc_next_EX;

    // --- Table update enables (EX -> BHT/BTB) ---
    // BHT: learn direction for conditional branches; treat JAL as "always taken"
    //      so an unconditional jump becomes predicted-taken after one execution.
    wire bht_update_en    = (IsBranch_EX | (IsJump_EX & ~is_jalr_EX)) & ~stall_EX;
    wire bht_actual_taken = IsBranch_EX ? branch_taken : 1'b1;
    // BTB: allocate/refresh on any taken branch or JAL, but never for JALR.
    wire btb_write_en     = actual_taken_EX & ~is_jalr_EX & ~stall_EX;

    BranchHistoryTable bht_inst (
        .clk(clk),
        .read_index(pc_IF[7:2]),
        .predict_taken(predict_taken_bht_IF),
        .update_en(bht_update_en),
        .update_index(pc_EX[7:2]),
        .actual_taken(bht_actual_taken)
    );

    BranchTargetBuffer btb_inst (
        .clk(clk),
        .read_pc(pc_IF),
        .hit(btb_hit_IF),
        .target(btb_target_IF),
        .write_en(btb_write_en),
        .write_pc(pc_EX),
        .write_target(alu_result_EX)
    );

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


    wire [31:0] mem_or_alu_MEM = (WBSel_MEM == 2'b00) ? mem_MEM : alu_result_MEM;

    // Apply forwarding logic for ALU inputs based on ForwardingUnit
    wire [31:0] forward_a_val = (ForwardA == 2'b10) ? mem_or_alu_MEM :
                                (ForwardA == 2'b01) ? wdata_WB :
                                rdata1_EX;

    wire [31:0] forward_b_val = (ForwardB == 2'b10) ? mem_or_alu_MEM :
                                (ForwardB == 2'b01) ? wdata_WB :
                                rdata2_EX;

    // Select final ALU inputs (PC/Reg vs Imm/Reg)
    wire [31:0] alu_a_in = ASel_EX ? pc_EX : forward_a_val;
    wire [31:0] alu_b_in = BSel_EX ? imm_EX : forward_b_val;

    wire        div_ready;
    wire [31:0] div_quotient;
    wire [31:0] div_remainder;

    wire is_div_instruction = (ALUSel_EX >= 5'b10100) && (ALUSel_EX <= 5'b10111);
    // DIV=10100 / REM=10110 sind signed, DIVU=10101 / REMU=10111 unsigned -> LSB unterscheidet.
    wire div_is_signed = is_div_instruction && (ALUSel_EX[0] == 1'b0);
    assign stall_EX = is_div_instruction && !div_ready;
    wire [31:0] divider_result = (ALUSel_EX == 5'b10110 || ALUSel_EX == 5'b10111) ? div_remainder : div_quotient;

    HardwareDivider divi_inst (
        .clk(clk),
        .start(is_div_instruction),
        .is_signed(div_is_signed),
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
    reg [31:0] pc_next_MEM = 0;

    // Only signals needed for MEM and WB stages travel further
    reg        MemRW_MEM = 0;
    reg [1:0]  StoreType_MEM = 0;
    reg [2:0]  LoadType_MEM = 0;

    always @(posedge clk) begin
        if (stall_EX) begin
            RegWEn_MEM     <= 0;
            MemRW_MEM      <= 0;
        end else begin
            alu_result_MEM <= final_ex_result;
            rdata2_MEM     <= forward_b_val;
            rd_addr_MEM    <= rd_addr_EX;
            pc_next_MEM    <= pc_next_EX;

            // Pass control signals to MEM
            RegWEn_MEM     <= RegWEn_EX;
            MemRW_MEM      <= MemRW_EX;
            WBSel_MEM      <= WBSel_EX;
            StoreType_MEM  <= StoreType_EX;
            LoadType_MEM   <= LoadType_EX;
        end
    end

    // =========================================================================
    // STAGE 4: MEMORY (MEM)
    // =========================================================================

    DataMemory dmem_inst(
        .clk(clk),
        .addr(alu_result_MEM),
        .dataW(rdata2_MEM),
        .MemRW(MemRW_MEM),
        .dataR(mem_MEM),
        .StoreType(StoreType_MEM),
        .LoadType(LoadType_MEM)
    );

    // -------------------------------------------------------------------------
    // PIPELINE REGISTER 4: MEM/WB
    // -------------------------------------------------------------------------
    reg [31:0] alu_result_WB = 0, mem_WB = 0;
    reg [31:0] pc_next_WB = 0;

    reg [1:0]  WBSel_WB = 0;

    always @(posedge clk) begin
        // Pass data to WB
        alu_result_WB <= alu_result_MEM;
        mem_WB        <= mem_MEM;
        rd_addr_WB    <= rd_addr_MEM;
        pc_next_WB    <= pc_next_MEM;

        // Pass control signals to WB
        RegWEn_WB     <= RegWEn_MEM;
        WBSel_WB      <= WBSel_MEM;
    end


    // =========================================================================
    // STAGE 5: WRITEBACK (WB)
    // =========================================================================

    // Select the final data to write back into the Register File
    assign wdata_WB = (WBSel_WB == 2'b00) ? mem_WB :
                      (WBSel_WB == 2'b01) ? alu_result_WB :
                      pc_next_WB;

endmodule