/* boot.c -- minimaler interaktiver Bootloader fuer den RV32IM Soft-Core
 *
 * Liegt fest bei 0x0000 (per $readmemh im Bitstream).
 * Empfaengt ein App-Binary ueber UART und startet es ab 0x4000.
 *
 * Upload-Protokoll (Host -> Bootloader):
 *     'l'                      Kommando-Byte
 *     length   (4 Byte, LE)    Anzahl App-Bytes
 *     data     (length Byte)   das rohe app.bin
 *     checksum (1 Byte)        XOR aller Daten-Bytes
 */

#define UART_BASE  0x40600000u
#define UART_RX    (*(volatile unsigned int *)(UART_BASE + 0x0))
#define UART_TX    (*(volatile unsigned int *)(UART_BASE + 0x4))
#define UART_STAT  (*(volatile unsigned int *)(UART_BASE + 0x8))
#define RX_VALID   (1u << 0)
#define TX_FULL    (1u << 3)

#define APP_BASE   0x4000u
#define APP_MAX    (32u * 1024u)   /* 32 KB max. App-Image */

static void putc_(char c){ while (UART_STAT & TX_FULL); UART_TX = (unsigned char)c; }
static unsigned getc_(void){ while (!(UART_STAT & RX_VALID)); return UART_RX & 0xFF; }
static void puts_(const char *s){ while (*s) putc_(*s++); }

static void puthex(unsigned v){
    static const char hex[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) putc_(hex[(v >> i) & 0xF]);
}

static int app_loaded = 0;

static void load_app(void){
    unsigned n  =  (unsigned)getc_();
    n |= (unsigned)getc_() << 8;
    n |= (unsigned)getc_() << 16;
    n |= (unsigned)getc_() << 24;

    if (n == 0 || n > APP_MAX){
        puts_("ERR size\r\n");
        return;
    }

    volatile unsigned char *dst = (volatile unsigned char *)APP_BASE;
    unsigned char cks = 0;
    for (unsigned i = 0; i < n; i++){
        unsigned char b = (unsigned char)getc_();
        dst[i] = b;
        cks ^= b;
    }

    if ((unsigned char)getc_() != cks){
        puts_("ERR cksum\r\n");
        return;
    }

    app_loaded = 1;
    puts_("OK loaded 0x"); puthex(n); puts_(" bytes\r\n");
}

static void run_app(void){
    if (!app_loaded){
        puts_("no app loaded\r\n");
        return;
    }
    puts_("running app...\r\n");
    ((void (*)(void))APP_BASE)();
    /* Falls die App per ret zurueckkommt statt nach 0x0000 zu springen: */
    puts_("\r\napp returned\r\n");
}

int main(void){
    puts_("\r\n=== RV32IM Bootloader v1 ===\r\n");
    puts_("commands: [l]oad+run   [r]un again   [p]ing\r\n");
    for (;;){
        puts_("\r\n> ");
        unsigned c = getc_();
        switch (c){
            case 'l': load_app(); if (app_loaded) run_app(); break;
            case 'r': run_app(); break;
            case 'p': puts_("pong\r\n"); break;
            case '\r': case '\n': break;
            default:  puts_("?\r\n"); break;
        }
    }
    return 0;
}
