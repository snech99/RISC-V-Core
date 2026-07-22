// =============================================================================
// InstructionMemory (IMEM) — read-only instruction ROM (IF stage)
// -----------------------------------------------------------------------------
// Word-addressed, combinational read. Initialised from the assembled program
// image (test_program_code_hex.mem). Uses addr[31:2] as the word index, so the
// byte-address PC is converted to a word address here. Harvard-style: separate
// from the DataMemory to avoid a structural hazard.
// =============================================================================
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