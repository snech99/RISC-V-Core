`timescale 1ns / 1ps

module custom_bram (
    // --------------------------------------------------
    // PORT A
    // --------------------------------------------------
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK" *)
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_ECC NONE, MEM_WIDTH 32, MEM_SIZE 65536, READ_WRITE_MODE READ_WRITE" *)
    input  wire        clka,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA EN" *)
    input  wire        ena,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA WE" *)
    input  wire [3:0]  wea,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR" *)
    input  wire [15:0] addra,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN" *)
    input  wire [31:0] dina,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT" *)
    output reg  [31:0] douta,

    // --------------------------------------------------
    // PORT B
    // --------------------------------------------------
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_ECC NONE, MEM_WIDTH 32, MEM_SIZE 65536, READ_WRITE_MODE READ_WRITE" *)
    input  wire        clkb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    input  wire        enb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    input  wire [3:0]  web,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    input  wire [15:0] addrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    input  wire [31:0] dinb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    output reg  [31:0] doutb
);

    // 64 KB RAM = 16384 Wörter à 32-Bit
    reg [31:0] ram [0:16383];
    integer i;

    initial begin
        for (i = 0; i < 16384; i = i + 1) begin
            ram[i] = 32'd0;
        end
        $readmemh("test_program_code_hex.mem", ram);    
    end

    // Wort-Adresse aus Byte-Adresse berechnen (durch 4 teilen)
    wire [13:0] word_addra = addra[15:2];
    wire [13:0] word_addrb = addrb[15:2];

    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) ram[word_addra][7:0]   <= dina[7:0];
            if (wea[1]) ram[word_addra][15:8]  <= dina[15:8];
            if (wea[2]) ram[word_addra][23:16] <= dina[23:16];
            if (wea[3]) ram[word_addra][31:24] <= dina[31:24];
            douta <= ram[word_addra];
        end
    end

    always @(posedge clkb) begin
        if (enb) begin
            if (web[0]) ram[word_addrb][7:0]   <= dinb[7:0];
            if (web[1]) ram[word_addrb][15:8]  <= dinb[15:8];
            if (web[2]) ram[word_addrb][23:16] <= dinb[23:16];
            if (web[3]) ram[word_addrb][31:24] <= dinb[31:24];
            doutb <= ram[word_addrb];
        end
    end

endmodule