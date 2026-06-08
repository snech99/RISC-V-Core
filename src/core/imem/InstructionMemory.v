module InstructionMemory (
    input [31:0] addr,
    output [31:0] inst
);

parameter MEMORY_SIZE = 4096;
reg [31:0] ROM [0:MEMORY_SIZE-1];

initial begin
    $readmemh("../test/test_program_code_hex.mem", ROM);
end

assign inst = ROM[addr[31:2]]; 

endmodule