/* timing.c -- Demo fuer den AXI Timer.
 *
 * Zeigt drei Dinge:
 *   1) micros()-Messung einer Rechenschleife
 *   2) ZWEI nicht-blockierende "Tasks" parallel, nur ueber millis() getaktet
 *      (LED-Heartbeat 250ms + UART-Statuszeile alle 1000ms) -- kein delay()!
 *   3) eine Stoppuhr ueber die Buttons:
 *        btnU = Start/Stop, btnD = Reset
 *      Laufzeit wird live auf den LEDs (als 1/10s) angezeigt.
 *
 * Pruefung: Heartbeat blinkt 2 Hz, Statuszeile kommt jede Sekunde, die
 * Stoppuhr-Zeit passt zur echten Uhr. Stimmt das Tempo nicht, ist CPU_HZ
 * in board.h != echte clk_out1 (gleiche Falle wie die UART-Baud).
 *
 * Bauen:
 *   riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -Os -ffreestanding \
 *       -nostdlib -nostartfiles -I. -T app.ld -o timing.elf start_app.S timing.c
 *   riscv32-unknown-elf-objcopy -O binary timing.elf timing.bin
 *   python3 send_app.py timing.bin /dev/ttyUSB1 115200
 */
#include "board.h"

/* einfache Flankenerkennung fuer einen Button (entprellt grob ueber millis) */
static int rising_edge(unsigned mask, unsigned *prev_state, unsigned *last_ms){
    unsigned now = millis();
    int pressed = btn_pressed(mask);
    /* mind. 30ms zwischen akzeptierten Flanken -> Prellen ignorieren */
    if (pressed && !*prev_state && (unsigned)(now - *last_ms) > 30u){
        *prev_state = 1;
        *last_ms = now;
        return 1;
    }
    if (!pressed) *prev_state = 0;
    return 0;
}

int main(void){
    timer_init();

    uart_puts("\r\n=== AXI Timer Demo (timing.c) ===\r\n");

    /* --- 1) micros()-Messung --- */
    unsigned t0 = micros();
    volatile unsigned dummy = 0;
    for (unsigned i = 0; i < 100000u; i++) dummy += i;
    unsigned t1 = micros();
    uart_puts("100k-Schleife: "); uart_putu(t1 - t0); uart_puts(" us\r\n");
    uart_puts("Tipp: btnU = Stoppuhr Start/Stop, btnD = Reset\r\n\r\n");

    /* --- nicht-blockierende Task-Zeitstempel --- */
    unsigned hb_last  = millis();   /* Heartbeat-LED (Bit 15) */
    unsigned st_last  = millis();   /* Statuszeile            */
    unsigned hb_state = 0;

    /* --- Stoppuhr-Zustand --- */
    unsigned sw_running   = 0;
    unsigned sw_start_ms  = 0;
    unsigned sw_accum_ms  = 0;      /* aufsummierte Zeit bei Stop */

    /* Button-Flankenerkennung */
    unsigned u_prev = 0, u_last = 0;
    unsigned d_prev = 0, d_last = 0;

    for (;;){
        unsigned now = millis();

        /* Task A: Heartbeat alle 250ms toggeln (LED-Bit 15) */
        if ((unsigned)(now - hb_last) >= 250u){
            hb_last += 250u;
            hb_state ^= 1u;
            if (hb_state) led_set(1u << 15); else led_clr(1u << 15);
        }

        /* Task B: Statuszeile jede Sekunde */
        if ((unsigned)(now - st_last) >= 1000u){
            st_last += 1000u;
            uart_puts("uptime "); uart_putu(now / 1000u); uart_puts("s  ");
            uart_puts(sw_running ? "[STOPPUHR LAUEFT]\r\n" : "[stoppuhr gestoppt]\r\n");
        }

        /* btnU: Stoppuhr Start/Stop */
        if (rising_edge(BTN_U, &u_prev, &u_last)){
            if (sw_running){
                sw_accum_ms += (unsigned)(now - sw_start_ms);
                sw_running = 0;
            } else {
                sw_start_ms = now;
                sw_running = 1;
            }
        }

        /* btnD: Reset */
        if (rising_edge(BTN_D, &d_prev, &d_last)){
            sw_accum_ms = 0;
            sw_start_ms = now;
        }

        /* aktuelle Stoppuhr-Zeit berechnen */
        unsigned elapsed = sw_accum_ms;
        if (sw_running) elapsed += (unsigned)(now - sw_start_ms);

        /* LEDs 0..14 zeigen die Zeit in 1/10-Sekunden (unterste 15 Bit) */
        unsigned tenths = elapsed / 100u;
        led_clr(0x7FFFu);
        led_set(tenths & 0x7FFFu);
    }
    return 0;
}