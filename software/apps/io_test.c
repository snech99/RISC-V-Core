/* io_test.c -- I/O-Test-App fuer den RV32IM Soft-Core (Basys 3)
 *
 * - LEDs spiegeln standardmaessig die Switch-Stellung
 * - btnU: Lauflicht ueber die 16 LEDs
 * - btnL: alle LEDs an
 * - btnR: alle LEDs aus
 * - btnD: aktuellen Status (Switches + Buttons) ueber UART ausgeben
 * - jede Switch-Aenderung wird ueber UART gemeldet
 *
 * Bauen (App-Build mit Bootloader-Layout):
 *   riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -Os -ffreestanding \
 *       -nostdlib -nostartfiles -I. -T app.ld -o io_test.elf start_app.S io_test.c
 *   riscv32-unknown-elf-objcopy -O binary io_test.elf io_test.bin
 *   python3 send_app.py io_test.bin /dev/ttyUSB1 115200
 *
 * Mit btnC (Reset) zurueck zum Bootloader.
 */
#include "board.h"

static void delay(volatile unsigned n){ while (n--) ; }

int main(void){
    uart_puts("\r\n=== Basys3 I/O-Test ===\r\n");
    uart_puts("LEDs spiegeln die Switches.\r\n");
    uart_puts("btnU=Lauflicht  btnL=alle an  btnR=alle aus  btnD=Status\r\n\r\n");

    unsigned last_sw = 0xFFFFFFFFu;

    for (;;){
        unsigned sw  = sw_read();
        unsigned btn = btn_read();

        /* LED-Verhalten je nach Button */
        if      (btn & BTN_U){ for (int i = 0; i < 16; i++){ led_write(1u << i); delay(120000); } }
        else if (btn & BTN_L)  led_write(0xFFFF);
        else if (btn & BTN_R)  led_write(0x0000);
        else                   led_write(sw);          /* Standard: Switches spiegeln */

        /* Status auf Knopfdruck */
        if (btn & BTN_D){
            uart_puts("SW="); uart_puthex(sw);
            uart_puts(" ("); uart_putu(sw); uart_puts(")  BTN=");
            uart_putc((btn & BTN_U) ? 'U' : '-');
            uart_putc((btn & BTN_L) ? 'L' : '-');
            uart_putc((btn & BTN_R) ? 'R' : '-');
            uart_putc((btn & BTN_D) ? 'D' : '-');
            uart_puts("\r\n");
            delay(300000);                              /* simple Entprellung */
        }

        /* Switch-Aenderung melden */
        if (sw != last_sw){
            uart_puts("Switches: "); uart_puthex(sw); uart_puts("\r\n");
            last_sw = sw;
        }

        delay(2000);
    }
    return 0;
}