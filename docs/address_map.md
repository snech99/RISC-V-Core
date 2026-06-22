# Address Map

AXI4-Lite peripherals are mapped into the `0x4000_0000` region. The base
addresses below must match the Vivado **Address Editor** exactly, and the same
values are mirrored in `software/common/board.h`.

| Peripheral | Base address | Function |
|------------|--------------|----------|
| BRAM (AXI BRAM Controller) | `0x00000000` | code + data, 64 KB |
| GPIO0 (`axi_gpio_0`) | `0x40000000` | ch1 = 16 LEDs (out), ch2 = 16 switches (in) |
| GPIO1 (`axi_gpio_1`) | `0x40010000` | ch1 = 4 buttons (in) |
| AXI Timer (`axi_timer_0`) | `0x________` | free-running counter (**check Address Editor**) |
| UART (`axi_uartlite_0`) | `0x40600000` | USB-serial bridge (B18 = rx, A18 = tx) |

> **Decode-error gotcha:** reading `0xDEC0DEE3` back from a peripheral means the
> address is **not mapped** — an AXI decode error. This was the root cause of the
> buttons not working (`board.h` had GPIO1 at `0x40001000`, but the real address
> is `0x40010000`). Whenever you see this marker, cross-check the base address in
> `board.h` against the Address Editor.

## GPIO (AXI GPIO) registers

Offsets relative to the peripheral base.

| Offset | Register | Notes |
|--------|----------|-------|
| `0x00` | channel 1 data | LEDs (GPIO0), buttons (GPIO1) |
| `0x04` | channel 1 direction | 0 = output, 1 = input (per bit) |
| `0x08` | channel 2 data | switches (GPIO0) |
| `0x0C` | channel 2 direction | |

Resulting data addresses:

- LEDs: `0x40000000`
- Switches: `0x40000008`
- Buttons: `0x40010000`

Button bit assignment (btnC is the reset, so it is not on this channel):

| Bit | Button |
|-----|--------|
| 0 | btnU |
| 1 | btnL |
| 2 | btnR |
| 3 | btnD |

## UART (AXI Uartlite) registers

| Offset | Register | Notes |
|--------|----------|-------|
| `0x00` | RX FIFO | read received byte |
| `0x04` | TX FIFO | write byte to send |
| `0x08` | status | bit 0 = RX_VALID, bit 3 = TX_FULL |
| `0x0C` | control | FIFO reset / interrupt enable |

> The Uartlite IP's **"Frequency of the AXI Clock (Hz)"** parameter must match
> `clk_out1` exactly, or the baud rate will be wrong. This is the same class of
> bug as a mismatched `CPU_HZ` for the timer.

## AXI Timer registers

Timer 0 is used as a free-running up-counter (see `timer_init()` in `board.h`).

| Offset | Register | Notes |
|--------|----------|-------|
| `0x00` | TCSR0 | control / status |
| `0x04` | TLR0 | load value |
| `0x08` | TCR0 | current counter value (read for `millis`/`micros`) |

TCSR0 bits used (and relevant for the upcoming interrupt work):

| Bit | Name | Meaning |
|-----|------|---------|
| 1 | UDT0 | 0 = count up |
| 4 | ARHT0 | auto-reload (free-running) |
| 5 | LOAD0 | load TLR0 into the counter |
| 6 | ENIT0 | enable interrupt |
| 7 | ENT0 | enable timer |
| 8 | T0INT | interrupt flag — **write 1 to clear** (ack in the ISR) |

> `CPU_HZ` in `board.h` must equal the real `clk_out1` frequency, otherwise
> `millis()`, `micros()` and the `delay_*()` helpers are off by the ratio.
