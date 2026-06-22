## ---- Systemtakt (100 MHz) ----
set_property -dict { PACKAGE_PIN W5  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ---- Reset: btnC, aktiv-high ----
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { reset }];

## ---- 16 LEDs (gpio0 ch1, Output) ----
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[0]  }];
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[1]  }];
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[2]  }];
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[3]  }];
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[4]  }];
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[5]  }];
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[6]  }];
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[7]  }];
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[8]  }];
set_property -dict { PACKAGE_PIN V3  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[9]  }];
set_property -dict { PACKAGE_PIN W3  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[10] }];
set_property -dict { PACKAGE_PIN U3  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[11] }];
set_property -dict { PACKAGE_PIN P3  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[12] }];
set_property -dict { PACKAGE_PIN N3  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[13] }];
set_property -dict { PACKAGE_PIN P1  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[14] }];
set_property -dict { PACKAGE_PIN L1  IOSTANDARD LVCMOS33 } [get_ports { gpio_rtl_0_tri_o[15] }];

## ---- 16 Switches SW0..SW15 (gpio0 ch2, Input) ----
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[0]  }];
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[1]  }];
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[2]  }];
set_property -dict { PACKAGE_PIN W17 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[3]  }];
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[4]  }];
set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[5]  }];
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[6]  }];
set_property -dict { PACKAGE_PIN W13 IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[7]  }];
set_property -dict { PACKAGE_PIN V2  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[8]  }];
set_property -dict { PACKAGE_PIN T3  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[9]  }];
set_property -dict { PACKAGE_PIN T2  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[10] }];
set_property -dict { PACKAGE_PIN R3  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[11] }];
set_property -dict { PACKAGE_PIN W2  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[12] }];
set_property -dict { PACKAGE_PIN U1  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[13] }];
set_property -dict { PACKAGE_PIN T1  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[14] }];
set_property -dict { PACKAGE_PIN R2  IOSTANDARD LVCMOS33 } [get_ports { sw_tri_i[15] }];

## ---- 4 Buttons U/L/R/D (gpio1 ch1, Input) ----
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { btn_tri_i[0] }];  ## btnU
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { btn_tri_i[1] }];  ## btnL
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports { btn_tri_i[2] }];  ## btnR
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { btn_tri_i[3] }];  ## btnD

## ---- UART (USB-RS232 Bridge) ----
set_property -dict { PACKAGE_PIN B18 IOSTANDARD LVCMOS33 } [get_ports { rx_0 }];
set_property -dict { PACKAGE_PIN A18 IOSTANDARD LVCMOS33 } [get_ports { tx_0 }];

## ---- QSPI Flash Config ----
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
