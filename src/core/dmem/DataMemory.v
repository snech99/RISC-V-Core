// =============================================================================
// DataMemory (DMEM) — main RAM (MEM stage)
// -----------------------------------------------------------------------------
// Word-addressed RAM with byte/halfword/word granularity for stores (StoreType)
// and sign-/zero-extended byte/halfword/word loads (LoadType). Synchronous
// write, combinational read.
//
// Memory-mapped I/O: a store to address 0x4000 is not written to RAM; instead
// its low byte is emitted to the simulation console via $write, which is how
// the C runtime's print_char() produces output.
// =============================================================================
module DataMemory (
    input [31:0] addr,
    input [31:0] dataW,
    input MemRW,
    input clk,
    input [1:0] StoreType,
    input [2:0] LoadType,
    output reg [31:0] dataR
);

wire [1:0] Offset = addr[1:0];

parameter MEMORY_SIZE = 4096;
reg [31:0] RAM [0:MEMORY_SIZE-1];

integer i;
initial begin
   
    for (i = 0; i < MEMORY_SIZE; i = i + 1) begin
        RAM[i] = 32'd0;
    end

    $readmemh("../test/test_program_code_hex.mem", RAM);
end

always@(posedge clk) begin

    if(MemRW == 1'b1 && addr == 32'h0000_4000) begin
        $write("%c", dataW[7:0]); 
    end

    if(MemRW == 1'b1 && addr < MEMORY_SIZE*4) begin
        case (StoreType) 
            2'b00:  case (Offset)
                        2'b00: RAM[addr[31:2]][7:0] <= dataW[7:0];
                        2'b01: RAM[addr[31:2]][15:8] <= dataW[7:0];
                        2'b10: RAM[addr[31:2]][23:16] <= dataW[7:0];
                        2'b11: RAM[addr[31:2]][31:24] <= dataW[7:0];
                    endcase
            2'b01:  case (Offset)
                        2'b00: RAM[addr[31:2]][15:0] <= dataW[15:0];
                        2'b10: RAM[addr[31:2]][31:16] <= dataW[15:0];
                    endcase
            2'b10: RAM[addr[31:2]] <= dataW;
        endcase
        
    end
end

always@(*) begin
    dataR = 32'd0;
    if(MemRW == 1'b0 && addr < MEMORY_SIZE*4) begin
        case (LoadType) 
            3'b010: dataR = RAM[addr[31:2]];

            3'b000: case (Offset)
                        2'b00: dataR = {{24{RAM[addr[31:2]][7]}},  RAM[addr[31:2]][7:0]};
                        2'b01: dataR = {{24{RAM[addr[31:2]][15]}}, RAM[addr[31:2]][15:8]};
                        2'b10: dataR = {{24{RAM[addr[31:2]][23]}}, RAM[addr[31:2]][23:16]};
                        2'b11: dataR = {{24{RAM[addr[31:2]][31]}}, RAM[addr[31:2]][31:24]};
                    endcase
            
            3'b001: case (Offset)
                        2'b00: dataR = {{16{RAM[addr[31:2]][15]}}, RAM[addr[31:2]][15:0]};
                        2'b10: dataR = {{16{RAM[addr[31:2]][31]}}, RAM[addr[31:2]][31:16]};
                        default: dataR = 32'd0;
                    endcase
            
            3'b011: case (Offset)
                        2'b00: dataR = {24'b0, RAM[addr[31:2]][7:0]};
                        2'b01: dataR = {24'b0, RAM[addr[31:2]][15:8]};
                        2'b10: dataR = {24'b0, RAM[addr[31:2]][23:16]};
                        2'b11: dataR = {24'b0, RAM[addr[31:2]][31:24]};
                    endcase
            
            3'b100: case (Offset)
                        2'b00: dataR = {16'b0, RAM[addr[31:2]][15:0]};
                        2'b10: dataR = {16'b0, RAM[addr[31:2]][31:16]};
                        default: dataR = 32'd0;
                    endcase
            
            default: dataR = 32'd0;
        endcase 
    end
end

endmodule