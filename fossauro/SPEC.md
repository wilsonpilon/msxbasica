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

**Fixed 2026-08-18**: plain `-msx2` (not `-msx2+`) used to hang forever short of the BASIC prompt, stuck
re-entering `MSX2EXT.ROM $2980-$299F` (the "wait for VDP command to finish" routine) once per frame. Root
cause: the boot logo/icon draw issues a real **LMMC** VDP command (CPU→VRAM, 16×8=128 pixels) and feeds it
byte-by-byte through port `$9B`, but only ever sends **127** bytes — confirmed via a real instruction-level
trace (`docs/SPEC.md` module 32j), not guesswork. `VDPDraw()` (`V9938.pbi`) required a full `NX*NY` CPU
writes to clear the CE (Command Executing) status bit, so it never cleared and every later "wait for VDP
ready" poll (there are many, before/after nearly every draw op) hung forever. Real fMSX's own
`VDPDraw()`/`V9938.c` explained why 127 is correct: it calls the command engine **once immediately** at
command start (`if(VdpEngine&&(VdpOpsCnt>0)) VdpEngine();`), consuming one pixel from whatever was already
latched in VDP register 44/S#7 *before* the CPU sends anything — so real hardware (and the real,
hardware-validated MSX2 BIOS) only ever needs `NX*NY-1` more bytes. Fix: `VDPDraw()`'s `Case $0B, $0F`
(LMMC/HMMC) now calls `VDPWrite(VDP(44))` once right after `MMC\Active`/CE/TR are set, mirroring real
fMSX's immediate first engine tick. Verified: MSX2 now boots to "MSX BASIC version 2.1" end-to-end
(screenshot-confirmed), MSX1 and MSX2+ unaffected (screenshot-confirmed, no regression). `LMCM` ($0A,
VRAM→CPU direction) was deliberately **not** touched by this fix — real fMSX's generic immediate-tick
applies there too in principle, but no failing repro exists for it yet, so changing it now would be
unverified guesswork; revisit only if a real LMCM-related hang shows up. See `docs/SPEC.md` module 32j for
the full investigation (the instruction-level trace methodology, and why two earlier sessions' hypotheses
— a `JP (IX)` hook trampoline, and "CE reads as expected" from a too-small sample — both missed it).

**RAM mapper / configurable RAM size** (2026-08-18) — ports `$FC`-`$FF` (`RAMMapper()`/`RAMMask`/
`ReallocateRAM()`/`ClampRAMPages()`, `MSX.pbi`), ported to match real fMSX exactly (`MSX.c`:
`RAMMapper[]`/`RAMMask`/`ResetMSX()`'s round-to-power-of-2 + per-model clamp). Real fMSX does **not**
model MSX1 RAM expansion as separate cartridges plugged into extra slots (the common real-hardware
approach) — it uses this same bank-switched mapper, hardwired to Primary Slot 3/Secondary Slot 2, for
every model alike; only the minimum valid page count differs (MSX1 4 pages/64KB, MSX2/2+ 8 pages/128KB;
max 256 pages/4096KB either way). Requesting a size below the model's minimum (or above the max) silently
snaps to that minimum, not down to the max - a real fMSX quirk, kept for parity. Reset-time default
mapping is `RAMMapper[]=3:2:1:0` (segment `3-J` at CPU page `J`), matching real MSX2-mapper hardware
convention - only the first 4 segments (64KB) are reachable without software touching the mapper ports
itself, exactly like real hardware. Exposed via **Hardware → RAM Size** (64/128/256/512/1024KB, live,
full reset - not a hot-swap, same as a real `-ram` change or model switch) and `-ram <pages>` (now wired,
previously an accepted-but-inert placeholder). Save-state format bumped to v2 to include `RAMPages`/
`RAMMapper()` alongside the (now variably-sized) RAM contents. Verified via `WM_COMMAND`-driven live size
changes at 128KB/512KB/1024KB on both MSX1 and MSX2, screenshot-confirmed booting cleanly at each (MSX1's
"Bytes free" stays the classic 28815 regardless of extra RAM - matches real hardware/fMSX: MSX1 BIOS never
auto-probes the mapper for extra memory the way MSX2's BIOS does).

**Configurable VRAM size** (2026-08-18) — `ClampVRAMPages()`/`ReallocateVRAM()` (`V9938.pbi`), same
round-to-power-of-2 + per-model reset-to-default pattern as the RAM mapper above, ported from
`ResetMSX()`'s `NewVRAMPages` clamp. Real fMSX has no bank-switch mapper for VRAM (it's a flat buffer,
page-selected via VDP register 14 for modes 4+) but its clamp is *more* rigid than RAM's: MSX2/MSX2+
accept **only** exactly 8 pages (128KB) — any other value resets to 128KB, not just below-minimum ones.
Real fMSX has no 192KB/V9958-addon concept at all - that menu option always snaps back to 128KB (MSX2/2+)
or 16KB (MSX1, see below). `SafePeekVRAM()`'s existing bounds check (already present for a different
reason - defending `ChrTab`/`ColTab`/`ChrGen`/`SprTab` table-pointer reads) now also protects against a
genuinely *smaller* buffer (MSX1 at 16/32/64KB instead of the old fixed 128KB) - real fMSX has no
equivalent guard there, it simply never shrinks VRAM enough to need one. Exposed via **Hardware → VRAM
Size** (16/32/64/128/192KB, live, full reset) and `-vram <pages>` (now wired). Save-state bumped to v3
(VRAM size variable too). Verified via `WM_COMMAND`: MSX2 with any non-128KB selection correctly snaps
back and reboots cleanly; MSX1 with a genuinely different size (64KB) boots with full, uncorrupted text -
confirms `SafePeekVRAM()` protects the smaller buffer correctly.

**MSX1 minimum VRAM relaxed to 16KB, and new startup defaults** (2026-08-18, same day) — real fMSX's MSX1
minimum is actually 2 pages/32KB (see above); the project owner explicitly asked for a 16KB MSX1 default
("faz sentido, era o tamanho comum de VRAM em hardware MSX1 real"), so `ClampVRAMPages()`'s MSX1
`MinPages` was deliberately changed from 2 to 1 - the **one** place fossauro intentionally diverges from
real fMSX's own clamp behavior (flagged clearly in the code comment so it isn't mistaken for a bug later).
Startup defaults changed to match: `Mode` now defaults to `#MSX_MSX1` (was `#MSX_MSX2`), `VRAMPages`
defaults to 1/16KB (was 8/128KB) - `RAMPages`'s existing default of 4/64KB already matched what was asked
for, no change needed there. Verified: launching with no CLI arguments now boots straight to "MSX BASIC
version 1.0 ... 28815 Bytes free ... Ok", screenshot-confirmed.

**MegaROM bank-switch mappers** (2026-08-18) — `MapROM()`/`GuessROMType()`/`ApplyMegaROMPage()`
(`MSX.pbi`), ported from real fMSX's `MapROM()`/`GuessROM()`/`SetMegaROM()` (`MSX.c`) for all 8 mapper
types (`#MAP_GEN8`/`GEN16`/`KONAMI5`/`KONAMI4`/`ASCII8`/`ASCII16`/`GMASTER2`/`FMPAC`), keyed off which
cartridge slot (`ROMMask()`/`ROMType()`/`ROMMapper()`, indices 0=Cart A/Primary Slot 1, 1=Cart B/Primary
Slot 2) is currently paged into the CPU address that got written. SCC (Konami5) and OPLL/FM (FMPAC) sound
registers are trapped (so writes don't fall through as "bad write") but not emulated - ROM/SRAM banking
works identically without them, per the real source. SRAM (ASCII8/ASCII16/GameMaster2/FMPAC) is
session-only, allocated on first use, never persisted to a `.sav` file. `LoadCartridge()` (`fossauro.pb`)
rewritten: ROMs ≤32KB still load flat/mirrored exactly as before; larger ones round up to the next
power-of-2 8KB-page count and get real bank-switching. **Fixed a real bug in the process**: the old
`LoadCartridge()` mirrored Cart A into *both* Primary Slot 1 and 2 ("legacy single-cartridge behavior"),
which meant loading Cart A after Cart B silently stole Cart B's slot - each slot is now fully independent,
matching real fMSX's `CartMap[][]` (Cart A always Primary Slot 1, Cart B always Primary Slot 2). Exposed
via **Hardware → Cartridge Slot A/Slot B** (Load.../Eject + a Mapper Type submenu, checkmark shows the
active selection, changing it live-reloads an already-inserted cartridge). `-rom <type>` CLI flag is
**still** just accepted-and-logged, not wired to this - real fMSX's two-slots-in-one-flag CLI convention
needs more parsing-order work than fit in this pass; use the menu for now.

Verified with real MegaROM test files already in the repo (`editor/tools/msxbas2rom/demo/`/`games/`,
128KB ASCII8 and Konami5/SCC cartridges): `GuessROMType()` correctly identified the ASCII8 one (confirmed
via log), loaded without error, no regression on the plain no-cartridge boot path. **Note**: loading
either test MegaROM (and, confirmed separately, the pre-existing plain 16KB `Kingsvalley.rom` too - not a
MegaROM, doesn't touch any of this session's new code at all) hits the **already-documented, pre-existing**
H.TIMI-hook stack-overflow bug (`docs/MANUAL.md`'s Fossauro section, "Achado separado, ainda em aberto" -
SP grows unbounded and wraps, found in an earlier session, root cause not yet isolated) - confirmed this
is unrelated to MegaROM support, not a regression from this session's changes, by reproducing the identical
symptom (`PC=$0038` stuck, SP climbing every frame) with the non-Mega cartridge that has no code path
through any of today's new logic.

**Not implemented at all**:
- Floppy disk controller (FDC/WD2793-style) — `MSXRdZ80`/`MSXWrZ80` have `; TODO: Floppy disk controller`
  markers and nothing else. `-diska`/`-diskb`/File→Open Disk... all accept a file path but do nothing
  with it.
- Cassette (.CAS) tape I/O — explicitly deferred by the project owner; File→Load .CAS... opens a file
  picker but does not load anything.
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

1. **SCREEN 6/7 rendering** in `RefreshLine()` (`V9938.pbi`) — needed for MSX2 BASIC users doing bitmap
   graphics in those modes, including the now-fixed MSX2 boot sequence's own logo/icon draw (invisible
   today, drawn correctly into VRAM but never rendered to screen). Modes 5/8 already implement the exact
   pixel-packing/palette math needed; 6/7 just need their own `Case` in the same `Select` block
   (2bpp/4-colors-per-byte for mode 6, matching `VDPPixelsPerByte()`'s existing table).
2. **Disk (FDC) emulation** — the largest remaining gap. Real fMSX's `EMULib/WD1793.c` (controller command
   state machine) + `EMULib/FDIDisk.c` (raw-sector .DSK image container, no FAT12 awareness needed at that
   layer) is the reference; needs a real `DISK.ROM` loaded into Slot 3-1 pages 2-3 (file already present at
   `fMSX/DISK.ROM`) to have any driver code to issue commands, memory-mapped register dispatch at
   `$7FF8-$7FFF` gated on `PSL=3/SSL=1` (matching real fMSX's default WD1793-hardware-emulation mode, not
   the simpler-but-less-general `-simbdos` BDOS-trap alternative). The main Paleobasic project's own
   `editor/MSXDisk.pbi` (FAT12-aware) is NOT a substitute for this - it operates one layer up (parsing the
   filesystem inside an already-readable disk image) and doesn't overlap with what the FDC/WD1793 layer
   itself needs to do (raw sector I/O only).
3. **VDP command engine timing** — matters for games/demos that poll VDP busy status for timing, not for
   BASIC. Real fMSX's `VdpOpsCnt`/scanline-sliced `LoopVDP()` model (`fMSX/fMSX/V9938.c`) is the reference
   if this becomes a priority.
4. **Cassette (.CAS) emulation** — explicitly deferred, no immediate plan.
5. **Cheat (.CHT) support**, openMSX/BlueMSX-compatible format — explicitly deferred, no immediate plan.
6. **`NX`/`NY` register = 0 meaning "1024"** VDP quirk — rare edge case, low priority.
7. **LMCM ($0A, VRAM→CPU) may have the same "immediate first engine tick" gap as LMMC/HMMC did** (see
   module 32j's fix) — real fMSX's generic immediate-tick applies to all VDP commands uniformly, but LMCM
   wasn't touched since no failing repro exists for it. Only worth revisiting if a real hang shows up.
8. **`-rom <type>` CLI flag** — still accepted-and-logged only, not wired to the new MegaROM mapper
   support (module 32k/2026-08-18 has the real mapper logic; only the CLI plumbing for the "two `-rom`
   options, one per cartridge slot" convention is missing). Use Hardware→Cartridge Slot A/B's Mapper Type
   submenu in the meantime.
9. **MegaROM SRAM persistence** (`.sav`-equivalent file) — SRAM (ASCII8/ASCII16/GameMaster2/FMPAC) works
   in-session but is never saved/loaded, so battery-backed game saves don't survive a restart. No immediate
   plan.
10. Joystick/mouse, printer, serial, Kanji ROM, config/settings UI — no immediate plan, listed for
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
