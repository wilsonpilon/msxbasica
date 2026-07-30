# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A native **PureBasic** IDE for MSX BASIC (the "Basic Dignified" dialect — labels instead of line
numbers, includes, macros, proto-functions) and Z80 assembly. It grew from a simple text editor and is
meant to become a self-contained `.exe` (no Python/other runtime dependencies) covering the whole MSX
dev workflow: editing, preprocessing/tokenizing, assembling, disk image management, and running/
debugging in the openMSX emulator.

**`docs/SPEC.md` is the source of truth for architecture and scope decisions** — read it before
proposing structural changes. `README.md` has a running changelog and a quick "what already exists"
summary. `docs/MANUAL.md` is the end-user guide (editor keybindings, disk manager, config screens).

## Commands

Primary development is on **Windows via PowerShell**; a **Linux build script (`build.sh`)** also exists,
meant to be run inside **WSL** against the same checkout, using the Linux `pbcompiler` binary (not
`pbcompiler.exe`) — same spirit as `build.ps1`, own gitignored `build.config.linux.json` for the
compiler path (kept separate from Windows' `build.config.json` on purpose). Its command-line flags are
**not** the same as Windows' `/FLAG` style — Linux `pbcompiler` uses hyphenated flags (`-o`/`--output`,
`-q`/`--quiet`, `-cl`/`--console`, `-co`/`--constant Name=Value`), confirmed 2026-07-29 by running
`pbcompiler -h` for real inside WSL. No `/ICON` embedding either way (PE-only resource, no Linux
equivalent). `editor/BadigEditor.pb` likely still has Windows-only API calls (WinAPI `gdi32`/icon
extraction, etc.) that would need `CompilerIf #PB_Compiler_OS` guards before a Linux build succeeds
fully end-to-end — not yet audited.

**Real cross-platform bugs found while getting `build.sh` to actually compile (2026-07-29)**:
- `XIncludeFile` deduplication by resolved file path (documented in module 2b of `docs/SPEC.md` as an
  established, relied-upon behavior on Windows) is **not guaranteed on the Linux `pbcompiler`** —
  `editor/BadigEditor.pb` includes `PsgSynth.pbi` directly *and* `editor/MmlSynth.pbi` (also pulled in
  by `BadigEditor.pb`) includes `PsgSynth.pbi` again; Windows silently deduped this, Linux raised
  `Structure already declared: PsgStepData`. Fixed at the source with an explicit include-guard idiom in
  `editor/PsgSynth.pbi` (`CompilerIf Not Defined(PSGSYNTH_PBI_INCLUDED, #PB_Constant)` wrapping the whole
  file body) instead of relying on implicit compiler dedup — safe regardless of platform/compiler
  version. If a similar "file A included both directly by `BadigEditor.pb` and indirectly through file
  B" pattern shows up elsewhere, apply the same guard rather than assuming Windows' dedup behavior
  holds.
- `editor/Screen2EditorGui.pbi` had one isolated `GetKeyState_(#VK_CONTROL)` (WinAPI, Windows-only) used
  during Screen2 TEXTO tool mouse-move to detect Ctrl-held-for-pixel-snap — replaced with
  `ExamineKeyboard()`/`KeyboardPushed(#PB_Key_LeftControl) Or KeyboardPushed(#PB_Key_RightControl)`
  (PureBasic's own cross-platform Keyboard library). Compiles clean on Windows; not yet confirmed on
  Linux.
- `editor/WordStarKeys.pbi` (WordStar/JOE keybindings) is **structurally** Windows-only in its
  interception mechanism: it subclasses each `ScintillaGadget`'s raw HWND (`SetWindowLongPtr_`/
  `CallWindowProc_`/`#WM_KEYDOWN`/`#WM_CHAR`/`#VK_*`) to catch keys *before* Scintilla consumes them —
  the only way to implement multi-key chords (`^K` then a letter) and swallow/redirect arbitrary keys,
  since Scintilla's own `SCI_ASSIGNCMDKEY` only remaps single keys to Scintilla's *own* built-in
  commands, not arbitrary host actions. The command logic itself (mark block, search, cursor movement,
  paragraph reformat, etc.) is **already portable** — it only talks to Scintilla via
  `ScintillaSendMessage`, same library on every OS. Fixed for the immediate Linux build error by
  guarding just the OS-specific subclass/WndProc procedures with
  `CompilerIf #PB_Compiler_OS = #PB_OS_Windows` (`WS_AttachSubclass` gets a no-op stub on other OSes,
  since `BadigEditor.pb` calls it unconditionally; `WS_ShowHelp()` shows an explanatory message instead
  of opening a help screen it couldn't close, since closing it also depended on the same subclass).
  **Still open**: a real non-Windows equivalent needs low-level per-backend widget hooking (GTK
  `key-press-event`/`g_signal_connect` on Linux, presumably Cocoa on Mac) — this is real systems
  programming that cannot be written and validated from here without a live Linux+GTK+PureBasic
  environment to compile/run against; treat any attempt at it as a draft requiring the user's live
  WSL testing loop, not a one-shot fix.

```powershell
# Compile editor\BadigEditor.pb -> editor\BadigEditor.exe (finds pbcompiler.exe automatically,
# or pass -C once and it's remembered in build.config.json, gitignored/machine-local)
.\build.ps1
.\build.ps1 -C "C:\Basic\Compilers\pbcompiler.exe"   # first time on a new machine
.\build.ps1 -R                                        # build then run
.\build.ps1 -Version "5.4.0" -R                       # stamp a version + run
.\build.ps1 -H                                        # list all flags
```

```bash
# Linux counterpart, run from inside WSL (or any Linux shell) against the same repo checkout
./build.sh
./build.sh -C "/home/user/pb/compilers/pbcompiler"   # first time on a new machine
./build.sh -R                                         # build then run
./build.sh -H                                         # list all flags
```

**First-time WSL/Linux setup**: the PureBasic Linux compiler links against GTK3 (its GUI backend) plus
several libraries unconditionally (OpenGL/X11/OpenSSL) regardless of whether this codebase actually uses
them — a fresh WSL/Ubuntu install is missing all of these dev packages at link time. Found across two
rounds of real linker failures (2026-07-29): first `fontconfig`/`cairo`/`gtk+-3.0` not found via
pkg-config + `-lgmodule-2.0` not found; after installing those, a second round surfaced `-lGLU`/
`-lXxf86vm`/`-lssl`/`-lcrypto` also not found. Install once per machine (both rounds together, to save a
second round-trip next time):
```bash
sudo apt install libgtk-3-dev libcairo2-dev libfontconfig1-dev libglib2.0-dev \
                  libglu1-mesa-dev libxxf86vm-dev libssl-dev
```
Possibly not exhaustive — if another `-l<name>` shows up at link time, it's the same pattern (system dev
package missing, not a source bug); map the library name to its Ubuntu `-dev` package and add it here.

There is no automated test runner — verification happens through small standalone console harnesses in
`editor/tools/` (each is its own `.pb`, compiled separately with `/CONSOLE`, exercising one subsystem
without opening the GUI):

```powershell
# Compile a harness (same pbcompiler.exe as above)
& "C:\Basic\Compilers\pbcompiler.exe" editor\tools\DigTestCli.pb /EXE editor\tools\DigTestCli.exe /CONSOLE

editor\tools\DigTestCli.exe sample\teste.dmx <out_prefix> tok   # Dignified -> ASCII (-> tokenized if "tok")
editor\tools\MSXDiskTestCli.exe <scratch_dir>                    # round-trips MSXDisk.pbi (create/add/list/extract/delete)
editor\tools\RunBasicTestCli.exe <entrada.dmx> <scratch_dir>     # reproduces the "Executar -> BASIC" disk-build pipeline
```

`sample/teste.dmx` (~900 lines, real production code — "Change Graph Kit" by Fred Rique, not a
synthetic fixture) is the regression suite for the preprocessor/tokenizer: **run `DigTestCli` against it
after any change to `DignifiedPreprocessor.pbi` or `MsxTokenizer.pbi`** and diff the byte size / spot-check
output against the previous known-good result.

The disk tooling can also be exercised headlessly through the shipped `.exe` itself, which is often the
fastest way to validate `MSXDisk.pbi` changes:

```powershell
editor\BadigEditor.exe --diskmanipulator create|list|add|extract|delete disco.dsk ...
```

## Architecture

**Single compilation unit.** `editor/BadigEditor.pb` is the only file passed to `pbcompiler.exe`; every
`.pbi` file is pulled in via `XIncludeFile` (textual inclusion, not a real module boundary) and compiles
into one `.exe`. `MSXDisk.pbi` is the one file using a real `DeclareModule`/`Module` (`MSXDisk::`), so
its calls are qualified.

```
editor/BadigEditor.pb          main window, menus, tab/document management, event loop, all XIncludeFile wiring
editor/DignifiedPreprocessor.pbi   Dignified source -> classic ASCII pipeline (see below)
editor/MsxTokenizer.pbi            classic ASCII -> tokenized MSX-BASIC binary (.bmx)
editor/MSXDisk.pbi                 FAT12 .dsk image read/write (DeclareModule MSXDisk)
editor/DiskManagerGui.pbi          "Criar -> Disco..." dual-pane disk manager window
editor/BadigSettings.pbi           "Configurar -> Basic Dignified..." settings + JSON persistence
editor/EditorSettings.pbi          "Configurar -> Editor..." settings (font/theme/tabs) + JSON persistence
editor/WordStarKeys.pbi            WordStar/JOE-style keybindings for the Scintilla editor
editor/FontDownloader.pbi          Nerd Fonts download picker
editor/tools/*Cli.pb               standalone console test harnesses, see Commands above
```

**The Dignified pipeline** (the core value of the project) is a from-scratch PureBasic **port** of a
reference Python implementation that lives in `badig/` (gitignored/submodule, downloadable from inside
the app via `Configurar -> Basic Dignified... -> Baixar...`). Treat `badig/` as a **behavior spec to
port, never a runtime dependency to call** — the `.exe` does not shell out to Python anywhere anymore
(that path existed early on and was fully removed once native parity was reached). When in doubt about
what some preprocessor step should do, the ground truth is `badig/`'s Python source and the
already-extracted notes in `docs/reference/*.md` (one file per original module: core engine, MSX
vocabulary, dignifier, emulator/tokenizer interfaces), not guesswork.

Pipeline stages, in order: **Dignified source (`.dmx`)** → `DignifiedPreprocessor.pbi` (labels, loop
labels, `EXIT`, recursive `DEFINE`, `DECLARE` name-shortening, `FUNC`/`RET` proto-functions, `INCLUDE`
with per-file label/variable namespacing, remtags) → **classic ASCII (`.amx`)** → `MsxTokenizer.pbi` →
**tokenized binary (`.bmx`)**, the format MSX-BASIC actually loads. `RunOnOpenMSX()` (in
`BadigEditor.pb`) then wraps the result plus a synthesized `AUTOEXEC.BAS` into a `.dsk` via `MSXDisk.pbi`
and launches openMSX with the configured machine/extension.

**MSXDisk.pbi** originated as a vendored copy of the user's separate `msxDiskUtil` project. As of
2026-07-28, `msxDiskUtil/` was removed from the repo — a runtime/build audit confirmed
`editor/MSXDisk.pbi` is fully self-contained (no `XIncludeFile` reaching outside `editor/`) and the app
has zero dependency on the external directory; a Unicode `MatchesFAT11` bugfix that had only been
applied to the vendored copy was ported back into `msxDiskUtil/MSXDisk.pbi` before deletion, so the two
were in sync at removal time. `editor/MSXDisk.pbi` is now the sole source of truth for disk format
logic. It's exposed three ways: internally by
`RunOnOpenMSX()`, as a headless CLI (`BadigEditor.exe --diskmanipulator ...`, detected at the very start
of the "Programa principal" section before any window opens), and as the graphical
`DiskMgr_OpenWindow()` (`DiskManagerGui.pbi`). The GUI tool stages all edits on a temp copy
(`GetTemporaryDirectory()`) and only writes the user's chosen `.dsk` on Salvar/Salvar como/Duplicar —
Cancelar discards the temp copy untouched. Left-panel/right-panel transfers in that tool are always
copies, never moves (deliberate: never delete the user's source file as a side effect).

**Settings screens** (`BadigSettings.pbi`, `EditorSettings.pbi`) persist to JSON next to the `.exe`
(`badig_settings.json`, `editor_settings.json`, both gitignored — machine-local) via PureBasic's native
`CreateJSON`/`LoadJSON`/`SaveJSON`, not by editing the reference `.ini` files under `badig/` (those stay
read-only reference material), with one exception: `emulator_path` gets patched back into
`emulator_interface.ini` because the original Python tool has no CLI flag for it.

**Verification approach**: this is a GUI-heavy PureBasic app with no unit test framework, so prefer the
`editor/tools/*Cli.pb` console harnesses (or the `--diskmanipulator` CLI) to validate logic changes —
they're fast, deterministic, and don't require driving the actual window. When live GUI verification is
unavoidable, prefer message-based automation targeted at a specific window handle (`WM_COMMAND` to a
menu ID, `BM_CLICK` to a button) over real cursor/keyboard input simulation or cross-process pointer
messages (`LVM_SETITEMSTATE`, `SCI_SETTEXT`) — the latter can hang or crash the target process, and real
input simulation acts on whatever is actually on screen for whoever is using the machine.
