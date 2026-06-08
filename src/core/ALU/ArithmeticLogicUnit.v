module ArithmeticLogicUnit (
    input [31:0] op1, op2,
    input [3:0] op_select, 
    output reg [31:0] data_out,
    output zero_flag, sign_out,
    output reg carry_out
);

always@(*) begin

    carry_out = 1'b0;

    case(op_select)
        4'b0000: {carry_out, data_out} = op1 + op2;         //add
        4'b0001: {carry_out, data_out} = op1 - op2;         //sub
        4'b0010: data_out = op1 << op2[4:0];                //sll
        4'b0011: data_out = $signed(op1) < $signed(op2);    //slt
        4'b0100: data_out = op1 < op2;                      //sltu
        4'b0101: data_out = op1^op2;                        //xor
        4'b0110: data_out = op1 >> op2[4:0];                //slr
        4'b0111: data_out = $signed(op1) >>> op2[4:0];      //sra
        4'b1000: data_out = op1 | op2;                      //or
        4'b1001: data_out = op1 & op2;                      //and 
        4'b1111: data_out = op2;                            //LUI
        default data_out = 32'bx;
    endcase 

end

assign sign_out = data_out[31];
assign zero_flag = (data_out == 0) ? 1 : 0;

endmodule