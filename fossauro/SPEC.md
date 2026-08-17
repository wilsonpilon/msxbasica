# SPEC.md - fossauro Emulator Specification & Status

This document tracks the port of Marat Fayzullin's **fMSX** emulator (C) to PureBasic (project name
**fossauro**). It reflects the **actual, verified state** of the port, not an aspirational plan — every
"done" claim below has been confirmed either against real fMSX's C source (`fMSX/fMSX/*.c`,
`fMSX/EMULib/*.c`) or by booting the compiled `fossauro.exe` and comparing screenshots against the real
`fMSX.exe` binary that already ships in this directory (`fMSX/fMSX.exe`, MSX2/2+ configuration).

**For the detailed, dated history of every bug found and fixed** (with exact line numbers, root causes,
and the methodology that found them), see `docs/SPEC.md` in the main Paleobasic repo root, modules **32**
through **32i**. This file is the consolidated, current-state summary; that one is the full incident log.

**Last updated**: 2026-08-17, work paused here to continue on a different machine.

---

## 1. Architecture

```
+--------------------------------------------------------------+
|                        fossauro.pb                           |
|   Window/Canvas/Menu UI, Audio output, Keyboard input,       |
|   CLI parsing, cartridge loading, save-state serialization   |
+--------------------------------------------------------------+
                               |
+------------------------------+-------------------------------+
|                              |                               |
V                              V                               V
+---------------+     +-----------------+             +----------------+
|    MSX.pbi    |     |    V9938.pbi    |             |   AY8910.pbi   |
| (Board Logic, |     | (VDP Graphics,  |             |  (PSG Sound,   |
|  Slots, RAM,  |     |  VRAM, Command  |             |  real per-     |
|  PPI, RTC)    |     |  Engine)        |             |  sample synth) |
+---------------+     +-----------------+             +----------------+
       |
       V
+---------------+
|    Z80.pbi    |
| (CPU Emulator)|
+---------------+
```

Single compilation unit (`fossauro.pb` is the only file passed to `pbcompiler.exe`; everything else is
`XIncludeFile`'d) — same pattern as the main Paleobasic editor. `Z80_Codes*.pbi` are auto-generated from
fMSX's C opcode tables by `translate.py`; everything else is hand-ported.

---

## 2. Component status

### Z80 CPU core — **COMPLETE**

`Z80.pbi` + `Z80_Tables.pbi` + `Z80_Codes.pbi`/`Z80_CodesCB.pbi`/`Z80_CodesED.pbi`/`Z80_CodesXX.pbi`/
`Z80_CodesXCB.pbi`. Compiles clean, verified via `fossauro_verify.pb`/`basic_verify.pb`.

Real bugs found and fixed during this port:
- `EX (SP),HL`/`EX (SP),IX`/`EX (SP),IY` (opcode `$E3`) had wrong read/write addresses — `translate.py`
  mishandled C's `SP.W++`/`SP.W--` used as a function-call argument. This was the root cause of an early
  "boot never draws anything" symptom.
- `JP (HL)`/`JP (IX)`/`JP (IY)` (opcode `$E9`) crashed with a real access violation — `JumpZ80` callback
  was never assigned in the real app (only in the separate test harness), called unconditionally. Fixed
  with a null-guard; diagnosed via Windows' own `%LOCALAPPDATA%\CrashDumps\` minidumps parsed by hand
  (no WinDbg/cdb available) — 7 reproduced crashes, all `ExceptionAddress=0x0`, all at the same call site.
- `translate.py`'s C-postfix-`++`/`--`-as-call-argument pattern audited exhaustively across all four
  opcode files afterward — clean everywhere else. **If a future Z80 bug looks like a stale/duplicated
  register value after a `(HL)`/`(IX+d)`/`(IY+d)`-style access, check this pattern first.**

### MSX board / memory slots / peripherals — **COMPLETE for what's implemented**

`MSX.pbi`. `PSlot()`/`SSlot()` verified **byte-for-byte** against real fMSX's `PSlot()`/`SSlot()`
(`fMSX/fMSX/MSX.c`) — including the "cartridge slots have no subslots" and "MSX1 slot 0 has no subslots"
special cases, and the `EnWrite` computation. 8255 PPI + keyboard matrix scan implemented and verified.

**Per-model BIOS loading** (`MSXLoadBIOSForModel()`) — MSX1 loads `fMSX/MSX.ROM`; MSX2 loads
`fMSX/MSX2.ROM` + `fMSX/MSX2EXT.ROM` (Slot 3-1); MSX2+ loads `fMSX/MSX2P.ROM` + `fMSX/MSX2PEXT.ROM`.
Cassette BIOS patches (`ED FE C9` traps at the 7 real fMSX offsets, `ApplyBIOSPatches()`) match real
fMSX's `BIOSPatches[]`/`PatchZ80()` exactly — TAPION/TAPIN/TAPOON/TAPOUT fail (no tape mounted), TAPIOF/
TAPOOF/STMOTR succeed as no-ops, same as real fMSX with `CasStream == NULL`.

**Real-Time Clock (RTC)** — implemented (`RTCIn()`, ports `$B4`/`$B5`, RP-5C01-style, 13 registers × 4
banks, bank 0 mirrors the live system clock via PureBasic's `Date()`/`Second()`/etc.). **This was missing
entirely until 2026-08-17 and was the root cause of the MSX2/MSX2+ boot freeze** — the extended BIOS
polls this chip during boot with no timeout; an unimplemented port returning the default `$FF` never
satisfied the check, hanging forever. Fixing this got **MSX2+ to boot completely to the BASIC prompt**.

**Live model switching** (`SwitchModel()`, Hardware→Model menu) — reloads BIOS for the new model, reloads
any currently-loaded cartridge, full reset. Verified in both directions (MSX1↔MSX2+) via `WM_COMMAND`
sent to the window. Fixed a bug where switching *to* MSX1 left a stale MSX2/2+ extended BIOS mapped in
Slot 3-1 (`MSXLoadBIOSForModel()`'s MSX1 branch now explicitly clears it back to `*EmptyRAM`).

**Known open bug**: plain `-msx2` (not `-msx2+`) still does not reach the BASIC prompt. It progresses far
past the old freeze point (VDP screen-enable bit gets set, `SCREEN 6` is reached, thousands of frames run
without truly halting) but stays stuck in a periodic loop at `MSX2EXT.ROM $2980-$299F` — a routine that
reads VDP status register S#2 via the standard 2-byte port `$99` protocol. Root cause **not found**
despite deep tracing (see `docs/SPEC.md` modules 32g/32h/32i for the full trace log and the two
hypotheses already ruled out: a `JP (IX)` hook-dispatch trampoline that turned out to resolve fine, and a
stuck CE/command-executing flag that read as expected in the samples captured). Since MSX2+ already boots
end-to-end, this has not been a priority to keep chasing — see "What's left" below for how to resume.

**Not implemented at all**:
- Floppy disk controller (FDC/WD2793-style) — `MSXRdZ80`/`MSXWrZ80` have `; TODO: Floppy disk controller`
  markers and nothing else. `-diska`/`-diskb`/File→Open Disk... all accept a file path but do nothing
  with it.
- Cassette (.CAS) tape I/O — explicitly deferred by the project owner; File→Load .CAS... opens a file
  picker but does not load anything.
- MegaROM bank-switching mappers (Konami/Konami4/ASCII8/ASCII16/GameMaster2/FMPAC) — `LoadCartridge()`
  only supports flat 16KB/32KB cartridges, mirrored into the mapped slot(s). A cartridge larger than 32KB
  will silently fail to map correctly (logged as "Unsupported ROM size").
- Joystick/mouse input, printer port, serial port, Kanji ROM.

### V9938/V9958 VDP — **mostly complete, audited against real V9938.c**

`V9938.pbi`. Confirmed by real MSX1 boot rendering the actual "MSX BASIC version 1.0" banner (not a
skeleton), and MSX2+ boot rendering "MSX BASIC version 3.0".

**Rendering** (`RefreshLine()`) — modes 0 (Text 40×24), 1 (Graphic 1), 2/4 (Graphic 2), 3 (Multicolor), 5
(Graphic 3, 16-color bitmap), 8 (Graphic 7, 256-color bitmap): **done**. Sprites (8×8/16×16, magnified,
`RenderSprites()`): **done**.

**Missing**: **SCREEN 6/7 (and MSX2+'s 10-12) bitmap rendering is not implemented** — `RefreshLine()`'s
mode `Select` has no `Case 6`/`Case 7`, so those modes fall through to `Default` (flat background-color
fill only, no pixel content drawn at all). This is directly relevant to the plain-MSX2 boot bug above:
even if that freeze gets fixed, the screen would still render blank during the part of boot that briefly
uses SCREEN 6, until this gap is closed.

**VDP command engine** (`VDPDraw()`) — ABRT/POINT/PSET/SRCH/LINE/LMMV/LMMM/LMCM/LMMC/HMMV/HMMM/YMMM/HMMC
all implemented, and audited line-by-line against real `V9938.c`'s `SrchEngine`/`LineEngine`/
`LmmvEngine`/`LmmmEngine`/`LmcmEngine`/`LmmcEngine`/`HmmvEngine`/`HmmmEngine`/`YmmmEngine`/`HmmcEngine`.
Three real bugs found and fixed (2026-08-17):
- `SRCH` used a hardcoded 512-pixel screen-width wrap for every mode; modes 5/8 are actually 256px wide.
- `HMMV`/`HMMM` ("high-speed" commands) went through the per-pixel nibble-masked write path instead of
  real hardware's raw whole-byte store stepped by pixels-per-byte (2/4/2/1 for modes 5/6/7/8) — only
  produced correct results when the fill/copy byte happened to have identical sub-pixel fields already.
- `YMMM` used an independent source-X register and bounded its scan by `NX`; real V9938 hardware always
  copies within the *same* X column (only the row changes) across the full screen width, ignoring `NX`
  entirely. This is the command games use for vertical scroll, so the old behavior would have corrupted
  any scroll effect.

Commands complete **instantly** (single call, no real VDP cycle timing/`VdpOpsCnt`-style throttling like
real fMSX's `LoopVDP()`). The `NX`/`NY` register value `0` meaning "1024" (a documented V9938 hardware
quirk) is **not implemented** — `VDPDraw()`'s `For ix = 0 To NX-1` loops simply do zero iterations when
`NX=0` instead of ~1024. Both are known, low-priority gaps (rare in practice; matters for game timing/
effects more than for BASIC or debugger correctness, which is this project's current priority).

### AY-3-8910 PSG — **COMPLETE** (architecturally different from real fMSX, verified independently)

`AY8910.pbi`. Real fMSX's `AY8910.c` does **not** synthesize waveforms itself — it computes frequency/
volume per channel and delegates to a generic `Sound()` abstraction elsewhere in EMULib, without emulating
the chip's 17-bit noise LFSR cycle-accurately. fossauro's `PSG_Render()` does genuine per-sample
synthesis instead (real 17-bit LFSR noise generator, envelope state machine as an actual state machine) —
a *more* accurate, lower-level approach, not a direct translation of `AY8910.c`.

Verified correct against known real AY-3-8910 hardware behavior: the noise LFSR feedback (`bit0 XOR
bit3`) matches the documented algorithm; the envelope state machine was checked against real fMSX's own
`Envelopes[16][32]` reference table (used differently by fMSX, but still valid as a behavior reference) —
**all 16 shapes match exactly**, including a real hardware artifact (a repeated value at the turn-around
point of alternating/triangle shapes) that falls out "for free" from the same overflow/direction-flip
logic without having copied the table.

One real (minor) bug found and fixed: register writes on port `$A1` didn't mask unused bits the way real
`Write8910()` does, which only affected register-*readback* fidelity via port `$A2` (a program that wrote
`$FF` to a 5-bit register and read it back would see `$FF` instead of `$1F`) — never affected audio output
since the read side already masked correctly at point of use.

### GUI / Menu / Save-state — **File/Hardware/Emulation menus real, more UI still to come**

`fossauro.pb`. Window + `CanvasGadget` + native Win32 menu, non-blocking emulation on its own thread.

- **File → Open Cartridge...**: works (`LoadCartridge()`, flat 16KB/32KB ROMs only, see MegaROM gap
  above).
- **File → Open Disk...**: opens a `.dsk` picker, but does nothing with the file yet (no FDC — see above).
- **File → Save Snapshot... / Open Snapshot...**: **real, working save-state**, not a stub. Custom binary
  format (`.fss`, magic `FSNP`, versioned — not stable across different builds of `fossauro.exe`, only
  meant to be reloaded by the same build that wrote it). Saves: `Mode`, cartridge file paths (not ROM
  data — re-read from disk on load), full RAM (64KB), full VRAM (128KB), the entire `Z80` CPU struct, VDP
  registers/status/VRAM-access-cursor state, the VDP command-engine (`MMC`) struct, the entire PSG struct,
  the entire PPI struct, RTC state, and primary/secondary slot registers. On load, slot mapping
  (`PSL()`/`SSL()`/`*RAM()`/`EnWrite()`) is *not* saved directly (those are raw pointers, only valid for
  one process run) — it's rebuilt by forcing `PSlot()` to recompute from the restored `SSLReg()`/`PSLReg`
  values, the same derivation the emulator already does on every real slot-select write. Verified via a
  temporary headless round-trip test (save → corrupt state → load → confirm exact match) before being
  removed from the shipped code.
- **File → Load .CAS... / Load .CHT...**: file pickers only, explicitly deferred (see peripherals above;
  `.CHT` is planned to be openMSX/BlueMSX cheat-format-compatible once implemented).
- **File → Quit**, **Emulation → Reset/Pause/Resume**: work.
- **Hardware → Model → MSX1/MSX2/MSX2+**: live model switching, see above.

No settings/config screens yet (font, theme, key remapping, controller config, video filters, etc. — all
still just accepted-but-inert CLI flags, see the CLI table in `docs/MANUAL.md`'s Fossauro section).

---

## 3. What's left to do, in priority order

This is the practical "what would make fossauro emulate MSX more completely" list, ordered by what's
likely most valuable for the project's stated current priority (debugger + BASIC correctness first, then
games):

1. **Plain MSX2 boot freeze** (see "Known open bug" above). Low urgency since MSX2+ already covers the
   "one working MSX2-family model" requirement, but leaves a gap for anyone who specifically needs
   non-Plus MSX2 behavior. Next concrete step: keep applying the "read the return address off the stack
   at an exact PC, one call level at a time" technique that cracked the RTC bug, starting from `$2980` in
   `MSX2EXT.ROM` and working outward to find who re-invokes that status-check block periodically.
2. **SCREEN 6/7 rendering** in `RefreshLine()` (`V9938.pbi`) — needed both for MSX2 BASIC users doing
   bitmap graphics in those modes and for the plain-MSX2 boot sequence to ever show anything visual even
   after freeze #1 is fixed. Modes 5/8 already implement the exact pixel-packing/palette math needed;
   6/7 just need their own `Case` in the same `Select` block (2bpp/4-colors-per-byte for mode 6, matching
   `VDPPixelsPerByte()`'s existing table).
3. **MegaROM mapper support** (Konami/Konami4/ASCII8/ASCII16/GameMaster2/FMPAC) — required for the large
   majority of real MSX cartridges, which exceed the current flat 32KB limit. Real fMSX's mapper logic is
   in `fMSX/fMSX/MSX.c` (`ROMMapper[]`/port `$4000`-ish writes) — worth porting the mapper *tables*
   faithfully rather than reinventing bank-switch semantics from scratch.
4. **VDP command engine timing** — matters for games/demos that poll VDP busy status for timing, not for
   BASIC. Real fMSX's `VdpOpsCnt`/scanline-sliced `LoopVDP()` model (`fMSX/fMSX/V9938.c`) is the reference
   if this becomes a priority.
5. **Disk (FDC) emulation** — a substantial feature (WD2793-style controller + the disk-image handling
   the main Paleobasic project already has in `editor/MSXDisk.pbi`, which could potentially be reused/
   adapted rather than rewritten, since it already handles FAT12 `.dsk` images).
6. **Cassette (.CAS) emulation** — explicitly deferred, no immediate plan.
7. **Cheat (.CHT) support**, openMSX/BlueMSX-compatible format — explicitly deferred, no immediate plan.
8. **`NX`/`NY` register = 0 meaning "1024"** VDP quirk — rare edge case, low priority.
9. Joystick/mouse, printer, serial, Kanji ROM, config/settings UI — no immediate plan, listed for
   completeness.

---

## 4. Verification tools available

- `fossauro_verify.pb` / `basic_verify.pb` — console-based Z80/BIOS/PPI regression harnesses, compile
  with `pbcompiler ... /CONSOLE`.
- `fMSX/fMSX.exe` — the **real** fMSX 6.0 Windows binary, already in the repo, configured with the same
  ROM set fossauro uses (`fMSX/*.ROM`). Invaluable as a ground-truth reference for "does real fMSX even do
  this" questions — several apparent fossauro bugs during this project turned out to be real fMSX
  behavior too (e.g. the "boot logo" that doesn't actually exist beyond a sub-second border-color flash).
  Screenshot via `PrintWindow` (P/Invoke from PowerShell) is the reliable way to inspect it, same as
  fossauro's own window — see any of the screenshot-taking PowerShell snippets in this session's history
  for the exact pattern (`GetWindowRect`/`PrintWindow`/`Bitmap`).
- `WM_COMMAND` sent directly to the window's `HWND` (via `SendMessage`, P/Invoke) — the reliable way to
  trigger menu items programmatically without fragile GUI automation; native Win32 menus respond to this
  the same as a real click. Works well for anything that doesn't open a modal file dialog; for those
  (Open Cartridge, Save/Open Snapshot, etc.) a temporary headless CLI-triggered test path is more
  reliable than trying to automate the dialog itself (Windows' modern file dialogs are COM-based, not
  simple child-window controls).
