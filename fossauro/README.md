# fossauro - fMSX Ported to PureBasic

**fossauro** is a native PureBasic port of Marat Fayzullin's **fMSX** emulator — Z80 CPU core, MSX
motherboard/slot logic, V9938 VDP, and AY-3-8910 PSG — compiling to a single dependency-free
`fossauro.exe`. Sibling project to Paleobasic within this repository; own license (non-commercial, see
[`LICENSE-fossauro`](../LICENSE-fossauro) at the repo root and the Licença section of the main
`README.md`).

**For full component-by-component status and the prioritized "what's left" list, see [`SPEC.md`](SPEC.md).**
**For architecture notes and debugging methodology when continuing work, see [`OUTLINE.md`](OUTLINE.md).**

---

## Credits

Directly based on the C source code of **fMSX**, designed and written by **Marat Fayzullin**. Full credit
to his exceptional work in MSX emulation — this project would not exist without it.

---

## Project status

- [x] **Z80 CPU core** — complete, verified. See `SPEC.md` for the two real translation bugs found and
  fixed (`EX (SP),HL`/`IX`/`IY`, `JP (HL)`/`(IX)`/`(IY)` null-pointer crash).
- [x] **MSX motherboard & slots** — complete for what's implemented. Primary/secondary slot paging
  verified byte-for-byte against real fMSX's C source. Per-model BIOS loading (MSX1/MSX2/MSX2+),
  cassette BIOS patches, and Real-Time Clock chip all implemented.
- [x] **MSX1 boot** — boots completely to the BASIC prompt ("MSX BASIC version 1.0").
- [x] **MSX2+ boot** — boots completely to the BASIC prompt ("MSX BASIC version 3.0").
- [ ] **MSX2 (non-Plus) boot** — reaches much further than before (screen turns on, `SCREEN 6` reached)
  but still doesn't reach the BASIC prompt — stuck in a VDP status-polling loop with an unidentified
  root cause. See `SPEC.md` §2/§3.
- [x] **V9938 VDP** — text/bitmap rendering for modes 0/1/2/3/4/5/8, sprites, and the full VDP command
  engine (SRCH/LINE/LMMV/LMMM/LMCM/LMMC/HMMV/HMMM/YMMM/HMMC), all audited against real `V9938.c`. Missing:
  SCREEN 6/7 bitmap rendering, VDP command timing (commands complete instantly).
- [x] **AY-3-8910 PSG** — real per-sample audio synthesis (17-bit LFSR noise, verified envelope state
  machine), Win32 `waveOut` streaming.
- [x] **File menu** — Open Cartridge (works), Save/Open Snapshot (real save-state, not a stub), Quit.
- [x] **Hardware → Model menu** — live MSX1/MSX2/MSX2+ switching.
- [ ] **Disk (FDC) emulation** — not implemented. File→Open Disk... accepts a `.dsk` path but does nothing
  with it yet.
- [ ] **Cassette (.CAS) emulation** — not implemented, explicitly deferred.
- [ ] **Cheat (.CHT) support** — not implemented, explicitly deferred (planned: openMSX/BlueMSX-compatible
  format).
- [ ] **MegaROM mappers** — not implemented; cartridges limited to flat 16KB/32KB.
- [ ] Joystick/mouse, printer, serial, Kanji ROM, settings/config UI.

---

## Tooling & automation

Manual conversion of thousands of lines of Z80 opcodes is error-prone, so this project uses a Python
translation pipeline:

- **`translate.py`** — parses fMSX's macro-heavy C instruction tables (`Codes.h`, `CodesCB.h`, etc.) and
  emits PureBasic `Select`/`Case` blocks. Handles ternary branches, C-array-bracket-to-parenthesis
  conversion, register post-increment/decrement (including as call arguments — a real source of past
  bugs, see `OUTLINE.md` §3), and nesting-aware `if` translation. Re-run with `python translate.py` if you
  change the translation rules or the C sources in `fMSX/fMSX/Z80/`.

---

## How to build & run

### Prerequisites
1. **PureBasic Compiler (`pbcompiler`)** on `PATH` or configured via `build.ps1 -C`.
2. **Python 3.x** — only needed if regenerating opcodes via `translate.py`.

### Build and run the emulator
```powershell
.\build.ps1              # compile fossauro.pb -> fossauro.exe
.\build.ps1 -R           # build then run
.\fossauro.exe -msx1               # boots to MSX1 BASIC
.\fossauro.exe -msx2+              # boots to MSX2+ BASIC
.\fossauro.exe -msx2               # loads the right BIOS but currently hangs before BASIC - see SPEC.md
.\fossauro.exe -verbose [rom.rom]  # writes fossauro.log; optionally load a cartridge
```

`fossauro.exe -help` prints the full fMSX-compatible CLI reference (most flags beyond
`-msx1`/`-msx2`/`-msx2+`/`-verbose`/cartridge loading are still accepted-but-inert placeholders — see the
CLI table in `docs/MANUAL.md`'s Fossauro section in the main repo for exactly which).

### Regenerate opcodes (only if touching `translate.py` or the C sources)
```bash
python translate.py
```

### Run the console regression harnesses
```powershell
pbcompiler fossauro_verify.pb /CONSOLE /OUTPUT fossauro_verify.exe
.\fossauro_verify.exe
```
Successful output loads `MSX.ROM`, validates its header, exercises the PPI/keyboard matrix, and reports
`SUCCESS: BIOS Loader & PPI/Keyboard verified successfully!`.
