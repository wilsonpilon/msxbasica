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

Everything is built and run on **Windows via PowerShell**; there is no Linux build script yet despite
the eventual cross-platform goal.

```powershell
# Compile editor\BadigEditor.pb -> editor\BadigEditor.exe (finds pbcompiler.exe automatically,
# or pass -C once and it's remembered in build.config.json, gitignored/machine-local)
.\build.ps1
.\build.ps1 -C "C:\Basic\Compilers\pbcompiler.exe"   # first time on a new machine
.\build.ps1 -R                                        # build then run
.\build.ps1 -Version "5.4.0" -R                       # stamp a version + run
.\build.ps1 -H                                        # list all flags
```

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

**MSXDisk.pbi** is a verbatim vendored copy of the user's separate `msxDiskUtil` project (also present
in this repo, tracked, under `msxDiskUtil/`) — resync manually if that project evolves; don't edit the
disk format logic without checking upstream first. It's exposed three ways: internally by
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
