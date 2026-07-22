# RISC-V 5-Stage Pipelined Processor Core

This repository contains the Verilog RTL implementation of a 32-bit RISC-V processor core implementing the **RV32IM** instruction set (base integer + the M extension for multiply/divide). The design features a classic 5-stage pipeline (Instruction Fetch, Decode, Execute, Memory Access, and Writeback) and includes robust mechanisms for hazard detection, pipeline stalling, and data forwarding.

Beyond the base pipeline it adds two notable features:
* **Dynamic branch prediction** — a Branch History Table (BHT, 2-bit saturating counters) and a Branch Target Buffer (BTB) predict direction and target in the IF stage; mispredictions are detected and recovered in EX.
* **RV32M multiply/divide** — single-cycle multiplies in the ALU (`MUL`/`MULH`/`MULHSU`/`MULHU`) and a multi-cycle sequential `HardwareDivider` for `DIV`/`DIVU`/`REM`/`REMU` (fully signed-aware) that stalls the pipeline while it computes.

## 📑 Table of Contents
- [Architecture & Module Interconnection](#architecture--module-interconnection)
  - [1. Central Integration & Top-Level](#1-central-integration--top-level)
  - [2. Instruction Fetch (IF)](#2-instruction-fetch-if)
  - [3. Instruction Decode (ID)](#3-instruction-decode-id)
  - [4. Execute (EX)](#4-execute-ex)
  - [5. Branch Prediction (IF + EX)](#5-branch-prediction-if--ex)
  - [6. RV32M Multiply / Divide](#6-rv32m-multiply--divide)
  - [7. Memory & Writeback (MEM/WB)](#7-memory--writeback-memwb)
- [Deep Dive: The Datapath (`Datapath.v`)](#deep-dive-the-datapath-datapathv)
   - [Key Responsibilities of the Datapath:](#key-responsibilities-of-the-datapath)
   - [Pipeline Hazards & Resolution](#pipeline-hazards--resolution)
   - [RISC-V Datapath Signals Overview](#risc-v-datapath-signals-overview)
- [Software Compilation (C to .mem)](#software-compilation-c-to-mem)
  - [Example Test Program (`main.c`)](#example-test-program-mainc)
  - [Standard Output & Memory-Mapped I/O](#standard-output--memory-mapped-io)
  - [Compiling the Code](#compiling-the-code)
- [Automated Hardware Simulation (Makefile)](#automated-hardware-simulation-makefile)
  - [Installation of Required Tools](#installation-of-required-tools)
  - [Available Make Commands](#available-make-commands)

## Architecture & Module Interconnection

The core is highly modular. The components are grouped logically by the pipeline stage they belong to, and everything is wired together by the central Datapath.

### 1. Central Integration & Top-Level
* **`Datapath.v`**: The central backbone of the processor (see detailed explanation below).
* **`Processor_tb.v`**: The main testbench. It instantiates the `Datapath`, generates the clock (`clk`), and dumps the simulation data into a `RISCV.vcd` file for waveform analysis (e.g., using GTKWave).

### 2. Instruction Fetch (IF)
* **`ProgramCounter.v` (PC)**: A synchronous register that holds the memory address of the current instruction. It can be frozen by a stall signal.
* **`InstructionMemory.v` (IMEM)**: A read-only memory module that fetches the 32-bit instruction based on the PC. It is initialized via a `.mem` file.

### 3. Instruction Decode (ID)
* **`ControlUnit.v` (CU)**: The brain of the decode stage. It reads the `opcode` and `funct3` fields of the instruction and generates all necessary control signals (e.g., `MemRW`, `ALUSel`, `RegWEn`) for the subsequent pipeline stages.
* **`RegisterFile.v` (RF)**: The 32x32-bit general-purpose register file. It provides two asynchronous read ports for the ID stage and one synchronous write port for the WB stage. Register `x0` is hardwired to zero.
* **`ImmGen.v`**: Extracts and sign-extends the immediate values from the instruction based on the instruction type (I, S, B, J, U).

### 4. Execute (EX)
* **`ArithmeticLogicUnit.v` (ALU)**: Performs all arithmetic (ADD, SUB), logical (AND, OR, XOR), shift and comparison (SLT/SLTU) operations, plus the single-cycle RV32M multiplies (`MUL`/`MULH`/`MULHSU`/`MULHU`).
* **`BranchComp.v`**: Compares two register values (`rs1` and `rs2`) to evaluate branch conditions (equal, less than). It handles both signed and unsigned comparisons.
* **`ForwardingUnit.v`**: Detects Data Hazards. If an instruction in the EX stage needs a register value that is currently being computed in the MEM or WB stage, this unit overrides the ALU inputs with the newest data to prevent reading stale values.

### 5. Branch Prediction (IF + EX)
The core predicts branches and jumps dynamically so that correctly-predicted control-flow changes cost **zero** bubbles. A prediction is made in IF and *verified* in EX; only a misprediction pays a penalty (a 2-cycle flush).
* **`BranchHistoryTable.v` (BHT)**: A direction predictor of 64 two-bit saturating counters, indexed by `PC[7:2]`. The MSB of the indexed counter is the taken/not-taken prediction. It is read combinationally in IF and updated in EX when a conditional branch (or `JAL`, treated as always-taken) resolves.
* **`BranchTargetBuffer.v` (BTB)**: A direct-mapped, 64-entry target cache, indexed by `PC[7:2]` with a full `PC[31:8]` tag (so there is no aliasing). A hit means "a taken branch/JAL was seen at exactly this PC before" and supplies the predicted target address. Allocated/refreshed in EX; `JALR` is intentionally never cached.
* **Prediction & recovery (in `Datapath.v`)**: The IF stage predicts *taken* only when the BTB hits **and** the BHT votes taken, and redirects the fetch to the BTB target. In EX the real outcome and target are computed; a wrong direction **or** a wrong target asserts `PCSel_EX`, which flushes the two mis-fetched instructions and resumes from the correct PC.

### 6. RV32M Multiply / Divide
* **Multiply (in `ArithmeticLogicUnit.v`)**: `MUL`, `MULH`, `MULHSU`, and `MULHU` are computed combinationally in a single cycle.
* **`HardwareDivider.v`**: A sequential restoring divider for `DIV`, `DIVU`, `REM`, and `REMU`. Because it needs ~34 cycles, it drives the `stall_EX` signal to freeze the pipeline until its `ready` output is asserted, at which point the quotient/remainder is latched. It is fully signed-aware (normalises operands to their magnitudes and restores the result signs per the RISC-V "round toward zero" rule) and handles the divide-by-zero and signed-overflow special cases per spec.

### 7. Memory & Writeback (MEM/WB)
* **`DataMemory.v` (DMEM)**: The main RAM. It handles reading and writing data (Bytes, Halfwords, Words) based on the control signals. Initialized via a `.mem` file.
* **Writeback (Internal to Datapath)**: A multiplexer selection (`WBSel`) at the end of the Datapath decides whether the ALU result, Memory data, or PC+4 is written back into the Register File.

---

## Deep Dive: The Datapath (`Datapath.v`)

The `Datapath.v` module is the most critical file in this repository. It is not a functional block itself, but rather the structural map that connects all the modules listed above and manages the flow of data across the pipeline.

### Key Responsibilities of the Datapath:

* **Pipeline Registers:** Between every stage, the Datapath defines physical registers (e.g., `pc_ID`, `inst_ID`, `alu_result_MEM`). These registers capture the data and control signals at the positive edge of the clock and pass them to the next stage, enabling true parallel execution of multiple instructions.
* **Internal Forwarding (ID Stage):** The Datapath implements a small forwarding network directly at the output of the Register File. If the Writeback (WB) stage is writing to a register at the exact same time the Decode (ID) stage is reading from it, the Datapath routes the `wdata_WB` directly to the ID outputs (`rdata1_fwd_ID`), ensuring the instruction reads the most up-to-date value.
* **Load-Use Hazard Detection & Stalling:** If a `LOAD` instruction is in the EX stage, its data won't be available until the MEM stage. If the immediately following instruction (in ID) needs that data, the Datapath triggers a `stall`. It freezes the PC and IF/ID registers and inserts a NOP (bubble) into the ID/EX register.
* **Multi-cycle Divider Stall:** While a `DIV`/`REM` occupies the EX stage, the `HardwareDivider` needs many cycles to finish. The Datapath asserts `stall_EX` for the whole computation, freezing the PC, IF/ID and ID/EX registers so the divider's operands stay stable, and only lets the result advance once `ready` is high.
* **Branch Prediction & Misprediction Flushing:** Control-flow changes are predicted in IF using the BHT/BTB and *verified* in EX. A correct prediction costs nothing. On a misprediction the Datapath asserts `PCSel_EX`, overwrites the PC with the correct address (the computed target if actually taken, otherwise `PC+4`), and "flushes" the two mis-fetched instructions in IF/ID and ID/EX by replacing them with `NOPs` (`addi x0, x0, 0`).

### Pipeline Hazards & Resolution

This core is designed to handle all classic pipeline hazards for a scalar, in-order 5-stage architecture:

* **Data Hazards:** Handled via a robust **Forwarding Unit** that routes newly calculated data from the MEM and WB stages directly back to the EX stage. For Load-Use hazards, the datapath automatically triggers a **Stall** (freezing the PC and inserting a pipeline bubble) to wait for the memory data.
* **Control Hazards:** Handled via **dynamic branch prediction** (BHT + BTB) resolved in EX. A correctly predicted branch or jump proceeds with no bubbles; only a misprediction triggers **Pipeline Flushing**, where the datapath overwrites the PC with the correct address and flushes the two mis-fetched instructions in the IF and ID stages by replacing them with NOPs.
* **Structural Hazards:** Prevented structurally by utilizing a **Harvard Architecture** (physically separate Instruction and Data memories) and a Register File with independent, isolated read and write ports.

### RISC-V Datapath Signals Overview

| Signal Name | Width | Description |
| :--- | :--- | :--- |
| <td colspan="3">**Global & Control Flow**</td> |
| `clk` | 1 bit | The central clock signal synchronizing all sequential logic (registers, PC, memory). |
| `stall` | 1 bit | Freezes the PC and IF/ID registers while inserting a NOP bubble (used to resolve Load-Use hazards). |
| `stall_EX` | 1 bit | Asserted while the multi-cycle `HardwareDivider` is busy. Freezes the PC, IF/ID and ID/EX registers until the division result is `ready`. |
| `PCSel_EX` | 1 bit | Program Counter Select / misprediction flag. Set to `1` in EX when a branch/jump was mispredicted. Overwrites the PC with `recover_pc_EX` and triggers a pipeline flush. |
| `recover_pc_EX` | 32 bit | The correct PC to resume from after a misprediction (computed target if actually taken, else `PC+4`). |
| `pc` | 32 bit | The Program Counter holding the address of the current instruction. |
| `pc_next` | 32 bit | The default sequential next address (`pc + 4`). |
| `next_pc_in`| 32 bit | The final selected address written to the PC at the next clock edge. |
| <td colspan="3">**Instruction & Decoding**</td> |
| `inst` | 32 bit | The 32-bit raw instruction word fetched from the Instruction Memory. |
| `rs1_addr`, `rs2_addr` | 5 bit | The extracted source register addresses (Source 1 and Source 2). |
| `rd_addr` | 5 bit | The extracted destination register address. |
| `imm` | 32 bit | The sign-extended immediate value generated from the instruction by the `ImmGen` module. |
| `rdata1`, `rdata2` | 32 bit | The raw 32-bit data values read directly from the Register File. |
| `rdata1_fwd`, `rdata2_fwd`| 32 bit | Register read data with internal forwarding applied. Resolves ID-stage data hazards. |
| <td colspan="3">**Execution & Forwarding**</td> |
| `ForwardA`, `ForwardB` | 2 bit | Selectors from the `ForwardingUnit`. Route default or forwarded data to ALU inputs. |
| `alu_a_in`, `alu_b_in` | 32 bit | The final, fully resolved 32-bit operands fed into the Arithmetic Logic Unit (ALU). |
| `Br_erg` | 2 bit | Output from the `BranchComp` unit containing comparison flags (Less Than, Equal). |
| `branch_taken` | 1 bit | A boolean flag indicating whether the evaluated branch condition is true. |
| `alu_result` | 32 bit | The computed 32-bit output from the ALU. |
| <td colspan="3">**Branch Prediction**</td> |
| `predict_taken_IF` | 1 bit | IF-stage prediction: taken only when the BTB hits **and** the BHT votes taken. Redirects the fetch to `btb_target_IF`. |
| `btb_hit_IF`, `btb_target_IF` | 1 / 32 bit | BTB lookup result for `pc_IF`: whether a taken branch/JAL is known here, and its predicted target. |
| `predicted_taken_EX`, `predicted_target_EX` | 1 / 32 bit | The prediction that travelled with the instruction, carried into EX to be checked against the real outcome. |
| `mispredict_EX` | 1 bit | Set when the predicted direction or target was wrong; drives `PCSel_EX`. |
| <td colspan="3">**RV32M Divider**</td> |
| `is_div_instruction` | 1 bit | High when the EX instruction is `DIV`/`DIVU`/`REM`/`REMU`, routing the result from the `HardwareDivider` instead of the ALU. |
| `div_ready` | 1 bit | Asserted by the `HardwareDivider` when the quotient/remainder is valid; deasserts `stall_EX`. |
| <td colspan="3">**Memory & Writeback**</td> |
| `mem` | 32 bit | The 32-bit data read from the Data Memory during a `LOAD` instruction. |
| `wdata` | 32 bit | The final 32-bit data written back into the Register File during the Writeback stage. |
| <td colspan="3">**Pipelined Control Signals**</td> |
| *(Generated in ID)* | div. | **Control signals** generated by the `ControlUnit` that travel through the pipeline registers: <br>• `RegWEn`: Enables writing to the Register File.<br>• `MemRW`: Enables writing to the Data Memory.<br>• `ALUSel`: Determines the specific ALU operation.<br>• `WBSel`: Selects the Writeback data source.<br>• `ASel`, `BSel`: Base selectors for the ALU input multiplexers.<br>• `IsJump`, `IsBranch`, `BrUn`, `StoreType`, `LoadType`: Specific execution flags. |
## Software Compilation (C to .mem)

Before simulating the processor, you need a machine code file to load into the Instruction and Data Memory. This repository includes a setup to compile standard C code into a RISC-V compatible `.mem` file using a standard RISC-V toolchain.

### Example Test Program (`main.c`)
The provided `main.c` is a self-checking exercise for the whole RV32IM feature set, chosen to stress both the M extension and the branch predictor. Because this core runs "bare-metal" without an operating system, the code cannot use standard C libraries like `<stdio.h>`; it relies entirely on custom hardware-specific functions (`print_number`, `print_char`). It prints:

* **factorials** 1!..10! — exercises `MUL` inside a tight, perfectly-predicted loop;
* **`1000 / n`, `1000 % n`** — exercises unsigned-safe `DIV`/`REM`;
* **primes < 60** (trial division) — nested loops with genuinely data-dependent branches (`x % d == 0`, early `break`) that actually challenge the predictor;
* **sum 1..200** — a long, cleanly-predicted accumulation loop;
* **signed division** with negative operands — verifies the signed `DIV`/`REM` result and sign rules.

The expected console output is:
```
factorials: 1 2 6 24 120 720 5040 40320 362880 3628800
1000 divmod n: 1000r0 500r0 333r1 250r0 200r0 166r4 142r6 125r0 111r1 100r0 90r10 83r4 76r12 71r6 66r10 62r8
primes<60: 2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59
sum 1..200: 20100
signed div: -6r-2 -6r2 6r-2 -3r-1
done
```

### Standard Output & Memory-Mapped I/O
The custom I/O functions provided in `riscv_gh.h` and `riscv_gh.c` rely on **Memory-Mapped I/O**. Writing a character to the specific memory address `0x4000` (`#define PRINTER (*(volatile unsigned char*) 0x4000)`) will not store the data in RAM. Instead, it triggers a special `$write` command in the Verilog `DataMemory` module, which intercepts the data and prints the character directly to the simulation console.

### Compiling the Code
A `Makefile` is provided in the software directory to automate this process. It requires a RISC-V toolchain (e.g., `riscv64-elf-gcc`). 

To compile your C program (`main.c`) and generate the memory file, run:
```bash
make
``` 

This process links the C code with a boot code (start.S), strips it down to a raw binary, and uses hexdump to format it into `test_program_code_hex.mem`. The code is compiled for **`-march=rv32im`** so that multiply/divide are emitted as native hardware instructions (exercising the ALU multiplier and the `HardwareDivider`) rather than being expanded into software routines by the compiler.


## Automated Hardware Simulation (Makefile)

To simplify the hardware simulation process, a `Makefile` is provided in the root directory. It automatically locates all Verilog (`.v`) files in the current directory and its subdirectories, handling compilation, execution, and waveform viewing.

### Prerequisites
Make sure you have **Icarus Verilog** (`iverilog`, `vvp`) and **GTKWave** installed on your system.
### Installation of Required Tools

To compile the Verilog code and view the simulation waveforms, you will need **Icarus Verilog** (`iverilog`) and **GTKWave**. You also need `make` to use the provided Makefile.

**For Ubuntu / Debian-based systems:**
```bash
sudo apt update
sudo apt install iverilog gtkwave make
```

**For Arch Linux systems:**
```bash
sudo pacman -S iverilog gtkwave make
```



### Available Make Commands

* **`make`** or **`make compile`**: 
  Finds all `.v` files and compiles them into a single executable named `compiled.vvp`.
* **`make run`**: 
  Compiles the design and runs the simulation using `vvp`. This executes the testbench and generates the `RISCV.vcd` waveform file.
* **`make show`**: 
  The most convenient command. It compiles the code, runs the simulation, and immediately opens the resulting `.vcd` file in GTKWave for visual analysis.
* **`make clean`**: 
  Deletes the generated `compiled.vvp` and any `*.vcd` files to keep your workspace clean.

**Quickstart:** Once your `test_program_code_hex.mem` is ready, simply open your terminal in the `/src/core` directory and type:
`make show`

This will automatically compile, simulate, print the test program's output (`main.c`) to your console, and launch the waveform viewer in one step!