#ifndef BOARD_H
#define BOARD_H

/* ---------- Basisadressen ---------- */
#define UART_BASE   0x40600000u
#define GPIO0_BASE  0x40000000u
#define GPIO1_BASE  0x40010000u   /* korrigiert: gpio1 liegt real bei 0x40010000 */

/* ---------- AXI GPIO Registeroffsets ---------- */
#define GPIO_CH1_DATA  0x00
#define GPIO_CH1_TRI   0x04
#define GPIO_CH2_DATA  0x08
#define GPIO_CH2_TRI   0x0C

/* ---------- UART ---------- */
#define UART_RX    (*(volatile unsigned int *)(UART_BASE + 0x0))
#define UART_TX    (*(volatile unsigned int *)(UART_BASE + 0x4))
#define UART_STAT  (*(volatile unsigned int *)(UART_BASE + 0x8))
#define UART_RXVALID (1u << 0)
#define UART_TXFULL  (1u << 3)

/* ---------- LEDs / Switches / Buttons ---------- */
#define LEDS      (*(volatile unsigned int *)(GPIO0_BASE + GPIO_CH1_DATA))  /* 16 out */
#define SWITCHES  (*(volatile unsigned int *)(GPIO0_BASE + GPIO_CH2_DATA))  /* 16 in  */
#define BUTTONS   (*(volatile unsigned int *)(GPIO1_BASE + GPIO_CH1_DATA))  /*  5 in  */

/* Button-Bits (btnC ist Reset; nutzbar: U/L/R/D) */
#define BTN_U  (1u << 0)
#define BTN_L  (1u << 1)
#define BTN_R  (1u << 2)
#define BTN_D  (1u << 3)

/* ---------- bequeme Helfer ---------- */
static inline void     uart_putc(char c){ while (UART_STAT & UART_TXFULL); UART_TX = (unsigned char)c; }
static inline int      uart_getc(void){ while (!(UART_STAT & UART_RXVALID)); return UART_RX & 0xFF; }
static inline void     uart_puts(const char *s){ while (*s) uart_putc(*s++); }

static inline void     led_write(unsigned v){ LEDS = v; }
static inline void     led_set(unsigned mask){ LEDS = LEDS | mask; }
static inline void     led_clr(unsigned mask){ LEDS = LEDS & ~mask; }
static inline unsigned sw_read(void){ return SWITCHES & 0xFFFFu; }
static inline unsigned btn_read(void){ return BUTTONS & 0x0Fu; }
static inline int      btn_pressed(unsigned mask){ return (BUTTONS & mask) != 0; }

/* ganze Zahl als Dezimal / Hex ausgeben (kleines printf-Ersatz) */
static inline void uart_putu(unsigned v){
    char buf[10]; int i = 0;
    if (v == 0) { uart_putc('0'); return; }
    while (v) { buf[i++] = '0' + (v % 10); v /= 10; }
    while (i) uart_putc(buf[--i]);
}
static inline void uart_puthex(unsigned v){
    static const char h[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) uart_putc(h[(v >> i) & 0xF]);
}


/* ===================================================================== */
/* AXI Timer  (axi_timer)                                                */
/* ===================================================================== */
#define TIMER_BASE  0x41C00000u       
#define CPU_HZ      40000000u          
#define TMR_TCSR0   (*(volatile unsigned int *)(TIMER_BASE + 0x00))
#define TMR_TLR0    (*(volatile unsigned int *)(TIMER_BASE + 0x04))
#define TMR_TCR0    (*(volatile unsigned int *)(TIMER_BASE + 0x08))

/* TCSR0-Bits */
#define TMR_MDT   (1u << 0)   /* 0 = generate mode                 */
#define TMR_UDT   (1u << 1)   /* 0 = hochzaehlen                   */
#define TMR_ARHT  (1u << 4)   /* Auto-Reload (free-running)        */
#define TMR_LOAD  (1u << 5)   /* TLR in Zaehler laden              */
#define TMR_ENT   (1u << 7)   /* Timer aktivieren                  */

/* Timer 0 als frei laufenden Hochzaehler starten (zaehlt Taktzyklen) */
static inline void timer_init(void){
    TMR_TLR0  = 0;                       /* Ladewert 0                      */
    TMR_TCSR0 = TMR_LOAD;                /* 0 in den Zaehler laden          */
    TMR_TCSR0 = TMR_ENT | TMR_ARHT;      /* hoch, auto-reload, aktiv        */
}

static inline unsigned timer_ticks(void){ return TMR_TCR0; }                 /* rohe Taktzyklen */
static inline unsigned micros(void){ return TMR_TCR0 / (CPU_HZ / 1000000u); }
static inline unsigned millis(void){ return TMR_TCR0 / (CPU_HZ / 1000u); }

/* wrap-sichere Verzoegerung (unsigned-Subtraktion ueberlaeuft korrekt) */
static inline void delay_us(unsigned us){
    unsigned start = TMR_TCR0;
    unsigned ticks = us * (CPU_HZ / 1000000u);
    while ((unsigned)(TMR_TCR0 - start) < ticks) ;
}
static inline void delay_ms(unsigned ms){ while (ms--) delay_us(1000); }

#endif /* BOARD_H */