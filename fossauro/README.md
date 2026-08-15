# fossauro - fMSX Ported to PureBasic

**fossauro** is a native port of Marat Fayzullin's famous **fMSX** emulator (specifically its Z80 CPU emulation core and peripheral structures) written in **PureBasic**. 

---

## Credits

This project is directly based on the C source code of **fMSX**, designed and written by **Marat Fayzullin**. We acknowledge and give full credit to his exceptional work in MSX emulation. 

---

## Project Status

- [x] **Z80 CPU Translation**: Completed and compiling cleanly in PureBasic.
- [x] **MSX Memory & Slot Management**: Completed. Handles primary/secondary slot paging via `PSlot` and `SSlot` structures.
- [x] **Intel 8255 PPI & Keyboard Matrix**: Completed. Emulates parallel port interface and translates keyboard reads through active matrix scans.
- [x] **MSX BIOS Loader**: Completed. Allocates ROM memory buffers and loads/maps `MSX.ROM` file from disk.
- [x] **Verification Routine**: Completed. The double-verification routine in `fossauro_verify.pb` successfully loads `MSX.ROM`, validates the header (`$F3`), configures the PPI ports, triggers matrix row selection, writes keyboard press states, and verifies matching output.
- [ ] **V9938 VDP Video Display Processor**: Planned (Basic skeleton port routing completed).
- [ ] **AY-3-8910 PSG Audio Synthesizer**: Planned (Basic skeleton port routing completed).
- [ ] **UI & Tape/Disk Loading**: Planned.

---

## Tooling & Automation

Because manual conversion of thousands of lines of opcodes is prone to human error, this project utilizes a custom Python translation pipeline:

- **`translate.py`**: A parsing and translation script that processes Marat's macro-heavy C instruction lists (`Codes.h`, `CodesCB.h`, etc.) and outputs pure PureBasic selection blocks. It handles:
  - Complex ternary operator branches.
  - Bracket-to-parenthesis array references.
  - Post-increments/decrements on registers inside function arguments vs standalone lines.
  - Nesting-aware parenthesis parser to accurately translate C `if` conditions to PureBasic `If` blocks.
  - Constant conversions (e.g. `C_FLAG` to `#C_FLAG`).

---

## How to Build & Run

### Prerequisites
1. **Python 3.x**: To run the automation script.
2. **PureBasic Compiler (`pbcompiler`)**: Added to your environment variables / PATH.

### 1. Regenerate Opcodes
If you modify the translation rules in `translate.py` or the C header sources in `fMSX/Z80/`, run:
```bash
python translate.py
```
This will rebuild `Z80_Tables.pbi` and all the translated opcode files (`Z80_Codes*.pbi`).

### 2. Compile the Project
To compile the console-based validation program:
```bash
pbcompiler fossauro_verify.pb /CONSOLE /OUTPUT fossauro_verify.exe
```

### 3. Run Verification
Execute the generated binary to run the Z80 execution test:
```bash
.\fossauro_verify.exe
```
Successful output looks like:
```
Initializing Z80 Lookup Tables...
Initializing MSX Memory Mapper...
Loading MSX BIOS ROM...
SUCCESS: BIOS ROM loaded successfully (32KB)
BIOS ROM Header Byte: $F3
SUCCESS: BIOS header matched ($F3)!
Setting up Z80 verification program...
Resetting CPU...
Running CPU...
Emulation stopped. Verifying results...
PC : $A
A  : $BF (Key matrix row read)
F  : $0

---------------------------------------------
 SUCCESS: BIOS Loader & PPI/Keyboard verified successfully!
---------------------------------------------
```
