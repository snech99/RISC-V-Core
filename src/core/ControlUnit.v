// =============================================================================
// ControlUnit — instruction decoder (ID stage)
// -----------------------------------------------------------------------------
// Purely combinational. Decodes opcode/funct3/funct7 of the incoming
// instruction and produces every control signal the later stages need
// (register/memory write enables, ALU op, mux selects, immediate type, ...).
// All outputs are given safe defaults at the top to avoid inferred latches.
// Covers RV32I plus the RV32M set (funct7 == 0000001): MUL family and DIV/REM.
// =============================================================================
module ControlUnit (
    input [31:0] inst,          // new instruction
    output reg RegWEn,          // enable write to the registers
    output reg ASel,            // select for the mux -> A input ALU
    output reg BSel,            // select for the mux -> B input ALU
    output reg [2:0] ImmSel,    // select for the immediate generator 
    output reg [4:0] ALUSel,    // select ALU operation
    output reg MemRW,           // enable write for the RAM
    output reg [1:0] WBSel,     // select which value to write back (mux)
    output reg [1:0] StoreType, // info regarding the S-type STORE inst
    output reg [2:0] LoadType,  // info regarding the S-type LOAD inst
    output reg BrUn,            // set, if branch offset is unsigned
    output reg IsJump,          // set, if there is a jump
    output reg IsBranch         // set, if there is a branch
);

    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];

    always @(*) begin
        // --- DEFAULT VALUES ---
        // Setting defaults prevents latches and reduces redundant code below.
        RegWEn    = 1'b0;
        ASel      = 1'b0;
        BSel      = 1'b0;
        ImmSel    = 3'b000;
        ALUSel    = 5'b00000;  // default: ADD (used for load/store/branch/jump targets)
        MemRW     = 1'b0;
        WBSel     = 2'b01;    // default: write back -> ALU result
        StoreType = 2'bxx;
        LoadType  = 3'bxxx;
        BrUn      = 1'b0;
        IsJump    = 1'b0;
        IsBranch  = 1'b0;
    
        // --- SPECIFIC INSTRUCTION DECODING ---
        case (opcode)

            7'b0110011: begin // R-Type
                RegWEn = 1'b1;    // enable write to the register
                if (funct7 == 7'b0000001) begin 
                    // --- RV32M: Multiplikation & Division ---
                    case (funct3)
                        3'b000: ALUSel = 5'b10000; // MUL
                        3'b001: ALUSel = 5'b10001; // MULH
                        3'b010: ALUSel = 5'b10010; // MULHSU
                        3'b011: ALUSel = 5'b10011; // MULHU
                        3'b100: ALUSel = 5'b10100; // DIV
                        3'b101: ALUSel = 5'b10101; // DIVU
                        3'b110: ALUSel = 5'b10110; // REM
                        3'b111: ALUSel = 5'b10111; // REMU
                    endcase
                end else begin
                    case (funct3)
                        3'b000: ALUSel = (inst[30]) ? 5'b00001 : 5'b00000; // SUB/ADD
                        3'b001: ALUSel = 5'b0010; // SLL
                        3'b010: ALUSel = 5'b0011; // SLT
                        3'b011: ALUSel = 5'b0100; // SLTU
                        3'b100: ALUSel = 5'b0101; // XOR
                        3'b101: ALUSel = (inst[30]) ? 5'b00111 : 5'b00110; // SRA/SRL
                        3'b110: ALUSel = 5'b01000; // OR
                        3'b111: ALUSel = 5'b01001; // AND
                        default:ALUSel = 5'b00000;
                    endcase
                end 
            end

            7'b0010011: begin // I-Type
                RegWEn = 1'b1;    // enable write to the register
                BSel   = 1'b1;    // input B for ALU is imm_gen
                ImmSel = 3'b001;  // imm_gen -> I-type value
                case (funct3)
                    3'b000: ALUSel = 5'b00000; // ADDI
                    3'b001: ALUSel = 5'b00010; // SLLI
                    3'b010: ALUSel = 5'b00011; // SLTI
                    3'b011: ALUSel = 5'b00100; // SLTIU
                    3'b100: ALUSel = 5'b00101; // XORI
                    3'b101: ALUSel = (inst[30]) ? 5'b00111 : 5'b00110; // SRAI/SRLI
                    3'b110: ALUSel = 5'b01000; // ORI
                    3'b111: ALUSel = 5'b01001; // ANDI
                    default:ALUSel = 5'b00000;
                endcase 
            end

            7'b0100011: begin // S-Type SAVE
                BSel      = 1'b1;         // input B for ALU is imm_gen    
                MemRW     = 1'b1;         // enable write to the RAM   
                ImmSel    = 3'b010;       // imm_gen -> S-type value
                case (funct3)
                    3'b000: StoreType = 2'b00; // SB
                    3'b001: StoreType = 2'b01; // SH
                    3'b010: StoreType = 2'b10; // SW
                endcase 
            end

            7'b0000011: begin // S-Type LOAD
                RegWEn   = 1'b1;          // enable write to the register
                BSel     = 1'b1;          // input B for ALU is imm_gen
                ImmSel   = 3'b001;        // imm_gen -> I-type value
                WBSel    = 2'b00;         // write back -> data from dmem
                case (funct3)
                    3'b000: LoadType = 3'b000; // LB
                    3'b001: LoadType = 3'b001; // LH
                    3'b010: LoadType = 3'b010; // LW
                    3'b100: LoadType = 3'b011; // LBU
                    3'b101: LoadType = 3'b100; // LHU
                endcase 
            end

            7'b1100011: begin // B-Type
                ASel     = 1'b1;          // input A for ALU is PC    
                BSel     = 1'b1;          // input B for ALU is imm_gen    
                ImmSel   = 3'b011;        // imm_gen -> B-type value 
                IsBranch = 1'b1;          // set, if there is a branch
                case (funct3)
                    3'b110: BrUn = 1'b1;  // BLTU
                    3'b111: BrUn = 1'b1;  // BGEU
                    default: BrUn = 1'b0;
                endcase 
            end

            7'b1101111: begin // J-Type JAL
                RegWEn = 1'b1;            // enable write to the register
                ASel   = 1'b1;            // input A for ALU is PC
                BSel   = 1'b1;            // input B for ALU is imm_gen    
                WBSel  = 2'b10;           // write back -> PC + 4
                ImmSel = 3'b100;          // imm_gen -> J-type value
                IsJump = 1'b1;            // set, if there is a jump
            end

            7'b1100111: begin // J-Type JALR
                RegWEn = 1'b1;            // enable write to the register
                BSel   = 1'b1;            // input B for ALU is imm_gen
                WBSel  = 2'b10;           // write back -> PC + 4
                ImmSel = 3'b001;          // imm_gen -> I-type value
                IsJump = 1'b1;            // set, if there is a jump
            end

            7'b0110111: begin // U-Type LUI
                RegWEn = 1'b1;            // enable write to the register
                BSel   = 1'b1;            // input B for ALU is imm_gen
                ImmSel = 3'b101;          // imm_gen -> U-type value
                ALUSel = 5'b01111;         // pass B through ALU directly
            end

            7'b0010111: begin // U-Type AUIPC 
                RegWEn = 1'b1;            // enable write to the register 
                ASel   = 1'b1;            // input A for ALU is PC    
                BSel   = 1'b1;            // input B for ALU is imm_gen
                ImmSel = 3'b101;          // imm_gen -> U-type value  
            end

            default: begin 
                // Default block intentionally left blank. 
                // All control signals are safely initialized at the top.
            end         
        endcase
    end
endmodule