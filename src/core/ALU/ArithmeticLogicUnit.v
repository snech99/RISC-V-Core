// =============================================================================
// ArithmeticLogicUnit (ALU) — combinational execute-stage compute
// -----------------------------------------------------------------------------
// Selects one operation via op_select (see the ControlUnit ALUSel encoding).
// Implements the RV32I arithmetic/logic/shift ops, LUI pass-through, and the
// single-cycle RV32M multiply variants (MUL, MULH, MULHSU, MULHU).
// The RV32M DIV/REM ops are NOT handled here; they are multi-cycle and live in
// the separate HardwareDivider. op_select values 10100..10111 leave data_out
// as 'x' here on purpose — the Datapath muxes in the divider result instead.
// =============================================================================
module ArithmeticLogicUnit (
    input [31:0] op1, op2,
    input [4:0] op_select, 
    output reg [31:0] data_out,
    output zero_flag, sign_out,
    output reg carry_out
);

reg signed [63:0] temp_mulh;
reg signed [63:0] temp_mulhsu;
reg [63:0] temp_mulhu;

always@(*) begin

    carry_out = 1'b0;

    case(op_select)
        5'b00000: {carry_out, data_out} = op1 + op2;         //add
        5'b00001: {carry_out, data_out} = op1 - op2;         //sub
        5'b00010: data_out = op1 << op2[4:0];                //sll
        5'b00011: data_out = $signed(op1) < $signed(op2);    //slt
        5'b00100: data_out = op1 < op2;                      //sltu
        5'b00101: data_out = op1^op2;                        //xor
        5'b00110: data_out = op1 >> op2[4:0];                //slr
        5'b00111: data_out = $signed(op1) >>> op2[4:0];      //sra
        5'b01000: data_out = op1 | op2;                      //or
        5'b01001: data_out = op1 & op2;                      //and 
        5'b01111: data_out = op2;                            //LUI      
        5'b10000: data_out = op1 * op2;                      //MUL
        5'b10001: begin                                      //MULH
                    temp_mulh = $signed(op1) * $signed(op2);
                    data_out  = temp_mulh[63:32];
                end
        5'b10010: begin                                      //MULHSU
                    temp_mulhsu = $signed(op1) * $signed({1'b0, op2});
                    data_out    = temp_mulhsu[63:32];
                end
        5'b10011: begin                                      //MULHU
                    temp_mulhu = {32'd0, op1} * {32'd0, op2};
                    data_out   = temp_mulhu[63:32];
                end
        default data_out = 32'bx;
    endcase 

end

assign sign_out = data_out[31];
assign zero_flag = (data_out == 0) ? 1 : 0;

endmodule