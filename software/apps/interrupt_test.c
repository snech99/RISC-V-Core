// =============================================================================
// timer_irq.c  -  First interrupt bring-up on the RV32IM core.
//
// Sets up the AXI Timer for a periodic interrupt, installs a machine-mode trap
// handler in DIRECT mode (mtvec[1:0]=00), and toggles an LED on every tick.
//
// Build (per the repo README):
//   riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 ... timer_irq.c
//
// VERIFY these against your board.h / Address Editor before flashing:
//   - peripheral base addresses (timer, GPIO)
//   - CPU clock frequency (period below assumes 40 MHz, matching clk_wiz_40M)
// =============================================================================

#include <stdint.h>

// ---- Peripheral base addresses (from the repo README address map) ----------
#define GPIO0_BASE   0x40000000u   // LEDs on channel 1
#define TIMER_BASE   0x41C00000u   // AXI Timer

#define REG(addr)    (*(volatile uint32_t *)(addr))

// ---- AXI Timer register offsets (Xilinx LogiCORE axi_timer, PG079) ----------
#define TCSR0   (TIMER_BASE + 0x00)   // Control/Status, timer 0
#define TLR0    (TIMER_BASE + 0x04)   // Load register, timer 0
#define TCR0    (TIMER_BASE + 0x08)   // Counter register, timer 0

// ---- TCSR0 bit masks --------------------------------------------------------
#define T_UDT0  (1u << 1)   // count down
#define T_ARHT0 (1u << 4)   // auto reload / hold
#define T_LOAD0 (1u << 5)   // load TCR0 from TLR0
#define T_ENIT0 (1u << 6)   // enable interrupt
#define T_ENT0  (1u << 7)   // enable timer
#define T_T0INT (1u << 8)   // interrupt occurred (write 1 to clear)

// ---- Period: counts per tick. 40 MHz * 0.5 s = 20,000,000 (~2 Hz blink) -----
#define TIMER_PERIOD  20000000u

// ---- RISC-V CSR access ------------------------------------------------------
#define write_csr(reg, val) asm volatile("csrw " #reg ", %0" :: "rK"(val))
#define set_csr(reg, val)   asm volatile("csrs " #reg ", %0" :: "rK"(val))
#define read_csr(reg) ({ unsigned long __v; \
        asm volatile("csrr %0, " #reg : "=r"(__v)); __v; })

// mstatus.MIE = bit 3 ; mie.MTIE = bit 7
#define MSTATUS_MIE  (1u << 3)
#define MIE_MTIE     (1u << 7)

volatile uint32_t tick_count = 0;

// ---- Trap handler -----------------------------------------------------------
// The "interrupt" attribute makes GCC save/restore caller-saved registers and
// emit MRET. It does NOT touch mepc, so the interrupted instruction re-runs.
void __attribute__((interrupt("machine"))) trap_handler(void)
{
    // 1) CLEAR THE SOURCE FIRST (write-1-to-clear), or we re-enter immediately.
    REG(TCSR0) = REG(TCSR0) | T_T0INT;

    // 2) Do the work: toggle LED0, count ticks.
    tick_count++;
    REG(GPIO0_BASE) = REG(GPIO0_BASE) ^ 0x1u;
}

static void timer_init(uint32_t period)
{
    REG(TLR0)  = period;                 // reload value
    REG(TCSR0) = T_LOAD0;                // load counter from TLR0
    REG(TCSR0) = T_ENT0 | T_ENIT0 | T_ARHT0 | T_UDT0; // run, IRQ, auto-reload, down
}

int main(void)
{
    // Direct mode: all traps enter trap_handler (low 2 bits of the address = 0).
    write_csr(mtvec, (unsigned long)&trap_handler);

    timer_init(TIMER_PERIOD);

    set_csr(mie, MIE_MTIE);       // enable machine timer interrupt
    set_csr(mstatus, MSTATUS_MIE); // global interrupt enable

    // Main work loop; the LED keeps blinking via the interrupt in the background.
    while (1) {
        // ... your foreground code ...
    }
    return 0;
}