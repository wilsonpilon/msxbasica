; fossauro - PureBasic MSX Emulator
; Main Entry Point & Graphical User Interface

EnableExplicit

CompilerIf Not Defined(App_Version, #PB_Constant)
  #App_Version = "8.0.1"
CompilerEndIf

; Windows constant + import for AttachConsole()/FreeConsole() - not part of PureBasic's
; automatic "_"-suffixed WinAPI passthrough, needs an explicit Import. Used by -help so its
; output can reach a real terminal instead of going nowhere - see RunEmulator() below.
#ATTACH_PARENT_PROCESS = -1
CompilerIf #PB_Compiler_OS = #PB_OS_Windows
  Import "Kernel32.lib"
    AttachConsole(dwProcessId.l)
    FreeConsole()
  EndImport
CompilerEndIf

; --- Emulation Control Globals ---
Global ThreadExit.l = 0
Global ThreadPaused.l = 0
Global EmulationThread.i = 0
Global Dim PCKeyStates.b(512)

; Paths of the currently-loaded cartridges (if any), kept up to date by LoadCartridge() -
; needed so File->Save Snapshot... knows what to reference on restore (snapshots don't embed
; cartridge ROM data, just the path - see SaveSnapshot()/LoadSnapshot() below).
Global CurCartAPath.s = ""
Global CurCartBPath.s = ""

; Include Z80 Emulator, Motherboard, Video, and Audio files
XIncludeFile "Z80_Tables.pbi"
XIncludeFile "Z80.pbi"
XIncludeFile "MSX.pbi"

; Emulation Background Thread
Procedure EmulationThreadProc(*Param)
  ; Re-assert the Z80 core callback pointers HERE, on the thread that actually calls
  ; RunZ80/uses them, instead of trusting the assignment done earlier on the main
  ; thread in RunEmulator() to be visible. Confirmed via crash dump analysis
  ; (0xC0000005, RIP=0x0) that RdZ80 was null at the exact moment the CPU reached the
  ; cartridge's entry point ($406C) - the call-site target address matched RdZ80's
  ; storage address exactly. Cheap and harmless if it was already set correctly.
  RealRdZ80 = @MSXRdZ80()
  WrZ80 = @MSXWrZ80()
  InZ80 = @MSXInZ80()
  OutZ80 = @MSXOutZ80()
  LoopZ80 = @MSXLoopZ80()
  PatchZ80 = @MSXPatchZ80()
  LogGeneral("EmulationThreadProc: callback pointers re-asserted on emu thread. RealRdZ80=$" + Hex(RealRdZ80))

  CPU\IPeriod = 228 ; Cycles per scanline phase
  RunZ80(@CPU)
EndProcedure

; Map PC Key Codes to MSX Keyboard Matrix Codes
Procedure.l MapCanvasKey(PBKey.l)
  Select PBKey
    Case #PB_Shortcut_Up : ProcedureReturn 2
    Case #PB_Shortcut_Down : ProcedureReturn 4
    Case #PB_Shortcut_Left : ProcedureReturn 1
    Case #PB_Shortcut_Right : ProcedureReturn 3
    Case #PB_Shortcut_Space : ProcedureReturn 32
    Case #PB_Shortcut_Return : ProcedureReturn 13
    Case 16 : ProcedureReturn 5   ; Shift
    Case 17 : ProcedureReturn 6   ; Control
    Case 18 : ProcedureReturn 7   ; Graph (Alt)
    Case #PB_Shortcut_Escape : ProcedureReturn 27
    Case #PB_Shortcut_Back : ProcedureReturn 8
    Case #PB_Shortcut_Tab : ProcedureReturn 9
    Case 20 : ProcedureReturn 10  ; CapsLock
    ; MSX specific special keys
    Case #PB_Shortcut_End : ProcedureReturn 11      ; SELECT
    Case #PB_Shortcut_Home : ProcedureReturn 12     ; HOME
    Case #PB_Shortcut_Insert : ProcedureReturn 15   ; INSERT
    Case #PB_Shortcut_Delete : ProcedureReturn 14   ; DELETE
    Case #PB_Shortcut_PageUp : ProcedureReturn 17   ; STOP
    Case #PB_Shortcut_PageDown : ProcedureReturn 16 ; COUNTRY
    ; Function keys
    Case #PB_Shortcut_F1 : ProcedureReturn 18
    Case #PB_Shortcut_F2 : ProcedureReturn 19
    Case #PB_Shortcut_F3 : ProcedureReturn 20
    Case #PB_Shortcut_F4 : ProcedureReturn 21
    Case #PB_Shortcut_F5 : ProcedureReturn 22
    ; Punctuation mappings (Windows OEM virtual-key codes -> ASCII-indexed slot in the
    ; KeyboardData table, MSX.pbi - see the table comments there for the full 0-129 layout).
    ; Shifted variants (? " { } | ~) aren't mapped separately - the MSX matrix combines the
    ; physical key with SHIFT (case 16, above) the same way real MSX keyboard hardware does.
    Case 186 : ProcedureReturn 59 ; VK_OEM_1     ; :
    Case 187 : ProcedureReturn 43 ; VK_OEM_PLUS  = +
    Case 188 : ProcedureReturn 44 ; VK_OEM_COMMA , <
    Case 189 : ProcedureReturn 45 ; VK_OEM_MINUS - _
    Case 190 : ProcedureReturn 46 ; VK_OEM_PERIOD . >
    Case 191 : ProcedureReturn 47 ; VK_OEM_2     / ?
    Case 192 : ProcedureReturn 96 ; VK_OEM_3     ` ~
    Case 219 : ProcedureReturn 91 ; VK_OEM_4     [ {
    Case 220 : ProcedureReturn 92 ; VK_OEM_5     \ |
    Case 221 : ProcedureReturn 93 ; VK_OEM_6     ] }
    Case 222 : ProcedureReturn 39 ; VK_OEM_7     ' "
    Case 226 : ProcedureReturn 92 ; VK_OEM_102 (extra ISO key on some layouts, usually \ |)
    Default
      ; Map numbers
      If PBKey >= '0' And PBKey <= '9'
        ProcedureReturn PBKey
      EndIf
      ; Map letters (canvas returns uppercase/lowercase)
      If PBKey >= 'A' And PBKey <= 'Z'
        ProcedureReturn PBKey
      ElseIf PBKey >= 'a' And PBKey <= 'z'
        ProcedureReturn PBKey - 32
      EndIf
  EndSelect
  ProcedureReturn 0
EndProcedure

; Load 16K/32K standard ROM cartridge. Slot=1 (default, backward-compatible) mirrors the
; ROM into BOTH primary slots 1 and 2 (fossauro's original single-cartridge convenience
; behavior - File menu, legacy -rom <file> shorthand). Slot=2 maps ONLY into primary slot 2
; (using a second ROM buffer, *ROMData(1)) and leaves slot 1 alone, for real fMSX-style dual
; cartridge use (positional [filename1] [filename2] - see RunEmulator's CLI parsing).
Procedure.l LoadCartridge(FileName.s, Slot.l = 1)
  LogGeneral("LoadCartridge called for: " + FileName + " (slot " + Str(Slot) + ")")
  Protected FileNum.i = ReadFile(#PB_Any, FileName)
  If FileNum = 0
    LogGeneral("LoadCartridge ERROR: Could not open file " + FileName)
    ProcedureReturn 0
  EndIf

  Protected Length.q = Lof(FileNum)
  LogGeneral("LoadCartridge: File size = " + Str(Length) + " bytes")
  If Length > 32768
    Length = 32768
    LogGeneral("LoadCartridge WARNING: Truncating ROM mapping to 32KB")
  EndIf

  Protected BufIdx.l = Slot - 1 ; Slot 1 -> ROMData(0), Slot 2 -> ROMData(1)
  If *ROMData(BufIdx)
    FreeMemory(*ROMData(BufIdx))
  EndIf
  *ROMData(BufIdx) = AllocateMemory(Length)
  ReadData(FileNum, *ROMData(BufIdx), Length)
  CloseFile(FileNum)

  Protected header.s = Chr(PeekA(*ROMData(BufIdx))) + Chr(PeekA(*ROMData(BufIdx)+1))
  LogGeneral("LoadCartridge: ROM Header Bytes = $" + Hex(PeekA(*ROMData(BufIdx))) + " $" + Hex(PeekA(*ROMData(BufIdx)+1)) + " ('" + header + "')")

  Protected J.l
  If Slot = 1
    ; Reset slot maps first to empty
    For J = 2 To 5
      *MemMap(1, 0, J) = *EmptyRAM
      *MemMap(2, 0, J) = *EmptyRAM
    Next J

    ; Map cartridge (mirrored into both slots - legacy single-cartridge behavior)
    If Length = 32768
      For J = 2 To 5
        *MemMap(1, 0, J) = *ROMData(BufIdx) + (J - 2) * $2000
        *MemMap(2, 0, J) = *ROMData(BufIdx) + (J - 2) * $2000
      Next J
      LogGeneral("LoadCartridge: Mapped 32KB ROM to Slot 1-0 and Slot 2-0")
    ElseIf Length = 16384
      *MemMap(1, 0, 2) = *ROMData(BufIdx) : *MemMap(1, 0, 3) = *ROMData(BufIdx) + $2000
      *MemMap(1, 0, 4) = *ROMData(BufIdx) : *MemMap(1, 0, 5) = *ROMData(BufIdx) + $2000
      *MemMap(2, 0, 2) = *ROMData(BufIdx) : *MemMap(2, 0, 3) = *ROMData(BufIdx) + $2000
      *MemMap(2, 0, 4) = *ROMData(BufIdx) : *MemMap(2, 0, 5) = *ROMData(BufIdx) + $2000
      LogGeneral("LoadCartridge: Mapped 16KB ROM (Mirrored) to Slot 1-0 and Slot 2-0")
    Else
      LogGeneral("LoadCartridge WARNING: Unsupported ROM size " + Str(Length))
    EndIf
  Else
    ; Cartridge B: slot 2 only, slot 1 untouched
    For J = 2 To 5
      *MemMap(2, 0, J) = *EmptyRAM
    Next J
    If Length = 32768
      For J = 2 To 5
        *MemMap(2, 0, J) = *ROMData(BufIdx) + (J - 2) * $2000
      Next J
      LogGeneral("LoadCartridge: Mapped 32KB ROM to Slot 2-0")
    ElseIf Length = 16384
      *MemMap(2, 0, 2) = *ROMData(BufIdx) : *MemMap(2, 0, 3) = *ROMData(BufIdx) + $2000
      *MemMap(2, 0, 4) = *ROMData(BufIdx) : *MemMap(2, 0, 5) = *ROMData(BufIdx) + $2000
      LogGeneral("LoadCartridge: Mapped 16KB ROM (Mirrored) to Slot 2-0")
    Else
      LogGeneral("LoadCartridge WARNING: Unsupported ROM size " + Str(Length))
    EndIf
  EndIf

  If Slot = 1
    CurCartAPath = FileName
  Else
    CurCartBPath = FileName
  EndIf

  ; Reset hardware state
  ResetZ80(@CPU)
  ResetVDP()
  ResetPSG()

  LogGeneral("LoadCartridge: Cartridge loaded successfully and hardware reset.")
  ProcedureReturn 1
EndProcedure

; --- Snapshot save/load ---
; Custom binary format, not cross-version/cross-build stable (structs are dumped raw via
; WriteData/ReadData - fine since a snapshot is only ever meant to be reloaded by the same
; fossauro.exe build that wrote it, same spirit as most simple emulator save-states). Does NOT
; embed cartridge ROM data - only the file path - so the original ROM file must still exist at
; that path when restoring; BIOS/extended BIOS are never saved either, since MSXLoadBIOSForModel()
; deterministically reloads the right ones from Mode alone. RAM/VRAM/CPU/VDP/PSG/PPI/RTC/slot
; state are all included, which is everything MemMap() pointers themselves are NOT (raw addresses
; only valid for this process run) - the slot mapping is rebuilt on load by forcing PSlot() to
; recompute from the restored SSLReg()/PSLReg values, the same derivation the emulator itself
; uses on every real slot-select write.
#SnapshotMagic = "FSNP"
#SnapshotVersion = 1

Procedure.l SaveSnapshot(FileName.s)
  Protected FileNum.i = CreateFile(#PB_Any, FileName)
  If FileNum = 0
    LogGeneral("SaveSnapshot ERROR: Could not create " + FileName)
    ProcedureReturn 0
  EndIf

  WriteString(FileNum, #SnapshotMagic, #PB_Ascii)
  WriteLong(FileNum, #SnapshotVersion)
  WriteLong(FileNum, Mode)
  WriteStringN(FileNum, CurCartAPath, #PB_UTF8)
  WriteStringN(FileNum, CurCartBPath, #PB_UTF8)

  WriteData(FileNum, *RAMData, $10000)
  WriteData(FileNum, *VRAM, $20000)
  WriteData(FileNum, @CPU, SizeOf(Z80))

  Protected I.l
  For I = 0 To 63 : WriteByte(FileNum, VDP(I)) : Next I
  For I = 0 To 15 : WriteByte(FileNum, VDPStatus(I)) : Next I
  WriteByte(FileNum, VDPKey)
  WriteByte(FileNum, VDPALatch)
  WriteWord(FileNum, VDPAddr)
  WriteByte(FileNum, VDPData)

  WriteData(FileNum, @MMC, SizeOf(VDPCommandState))
  WriteData(FileNum, @PSG, SizeOf(PSGState))
  WriteData(FileNum, @PPI, SizeOf(I8255))

  WriteByte(FileNum, RTCReg)
  WriteByte(FileNum, RTCMode)
  Protected bank.l, reg.l
  For bank = 0 To 3
    For reg = 0 To 12
      WriteByte(FileNum, RTC(bank, reg))
    Next reg
  Next bank

  WriteByte(FileNum, PSLReg)
  For I = 0 To 3 : WriteByte(FileNum, SSLReg(I)) : Next I

  CloseFile(FileNum)
  LogGeneral("SaveSnapshot: wrote " + FileName)
  ProcedureReturn 1
EndProcedure

Procedure.l LoadSnapshot(FileName.s)
  Protected FileNum.i = ReadFile(#PB_Any, FileName)
  If FileNum = 0
    LogGeneral("LoadSnapshot ERROR: Could not open " + FileName)
    ProcedureReturn 0
  EndIf

  Protected magic.s = ReadString(FileNum, #PB_Ascii, 4)
  If magic <> #SnapshotMagic
    LogGeneral("LoadSnapshot ERROR: bad magic in " + FileName)
    CloseFile(FileNum)
    ProcedureReturn 0
  EndIf
  Protected version.l = ReadLong(FileNum)
  If version <> #SnapshotVersion
    LogGeneral("LoadSnapshot ERROR: unsupported snapshot version " + Str(version))
    CloseFile(FileNum)
    ProcedureReturn 0
  EndIf

  Protected loadedMode.l = ReadLong(FileNum)
  Protected loadedCartA.s = ReadString(FileNum, #PB_UTF8)
  Protected loadedCartB.s = ReadString(FileNum, #PB_UTF8)

  Mode = loadedMode
  If Not MSXLoadBIOSForModel()
    LogGeneral("LoadSnapshot ERROR: could not load BIOS for restored model")
    CloseFile(FileNum)
    ProcedureReturn 0
  EndIf
  If loadedCartA <> "" : LoadCartridge(loadedCartA, 1) : EndIf
  If loadedCartB <> "" : LoadCartridge(loadedCartB, 2) : EndIf

  ReadData(FileNum, *RAMData, $10000)
  ReadData(FileNum, *VRAM, $20000)
  ReadData(FileNum, @CPU, SizeOf(Z80))

  Protected I.l
  For I = 0 To 63 : VDP(I) = ReadByte(FileNum) : Next I
  For I = 0 To 15 : VDPStatus(I) = ReadByte(FileNum) : Next I
  VDPKey = ReadByte(FileNum)
  VDPALatch = ReadByte(FileNum)
  VDPAddr = ReadWord(FileNum)
  VDPData = ReadByte(FileNum)

  ReadData(FileNum, @MMC, SizeOf(VDPCommandState))
  ReadData(FileNum, @PSG, SizeOf(PSGState))
  ReadData(FileNum, @PPI, SizeOf(I8255))

  RTCReg = ReadByte(FileNum)
  RTCMode = ReadByte(FileNum)
  Protected bank.l, reg.l
  For bank = 0 To 3
    For reg = 0 To 12
      RTC(bank, reg) = ReadByte(FileNum)
    Next reg
  Next bank

  Protected loadedPSLReg.a = ReadByte(FileNum)
  For I = 0 To 3 : SSLReg(I) = ReadByte(FileNum) : Next I

  CloseFile(FileNum)

  ; Force PSlot() to recompute PSL()/SSL()/*RAM()/EnWrite() for all 4 pages from the just-
  ; restored SSLReg() array, instead of assigning PSLReg directly (which would skip that
  ; derivation - see PSlot()'s "If PSLReg <> V" change-detection guard in MSX.pbi).
  PSLReg = loadedPSLReg ! $FF
  PSlot(loadedPSLReg)
  SetScreen()

  LogGeneral("LoadSnapshot: restored " + FileName)
  ProcedureReturn 1
EndProcedure

; True if S is a plain (optionally signed) decimal integer - used to tell "-rom <type>"
; (a small number, real fMSX MegaROM mapper selector) apart from fossauro's own legacy
; "-rom <file>" shorthand, and to peek at "-sound [<quality>]"'s optional argument.
Procedure.b LooksNumeric(S.s)
  If S = "" : ProcedureReturn #False : EndIf
  Protected I.l, Start.l = 1
  If Mid(S, 1, 1) = "-" Or Mid(S, 1, 1) = "+" : Start = 2 : EndIf
  If Start > Len(S) : ProcedureReturn #False : EndIf
  For I = Start To Len(S)
    If Mid(S, I, 1) < "0" Or Mid(S, I, 1) > "9"
      ProcedureReturn #False
    EndIf
  Next I
  ProcedureReturn #True
EndProcedure

; fMSX-compatible command-line reference (see fossauro/fossauro.md for the full original
; text this is adapted from). Returned by -help as one block of text; also the ground truth
; for which flags RunEmulator()'s parser below recognizes. Not every flag has real effect
; yet - each line says so where that's the case, instead of silently pretending it works.
; Built as one string (not printed line-by-line) so the same text can go either to a
; console (PrintN) or a MessageRequester dialog, depending on how fossauro was launched -
; see the "-help" case in RunEmulator() below for why both paths exist.
Procedure.s GetFmsxHelpText()
  Protected T.s
  T = "fossauro " + #App_Version + " - PureBasic MSX Emulator" + #CRLF$
  T + "Usage: fossauro [-option1 [-option2...]] [filename1] [filename2]" + #CRLF$ + #CRLF$
  T + "  [filename1] = cartridge ROM to load in slot A" + #CRLF$
  T + "  [filename2] = cartridge ROM to load in slot B" + #CRLF$ + #CRLF$
  T + "  -help               - Print this help page and exit" + #CRLF$
  T + "  -verbose [<mask>]   - Turn on the log file (fossauro.log), off by default." + #CRLF$
  T + "                        <mask> is fossauro's own category bitmask (1=general," + #CRLF$
  T + "                        2=memory, 4=VDP, 8=PSG, 16=CPU) - NOT the same bit" + #CRLF$
  T + "                        meanings as real fMSX's -verbose. Omit <mask> for all." + #CRLF$
  T + "  -msx1/-msx2/-msx2+  - Select MSX model [-msx2]. Loads the matching BIOS" + #CRLF$
  T + "                        (MSX.ROM / MSX2.ROM+MSX2EXT.ROM / MSX2P.ROM+MSX2PEXT.ROM)" + #CRLF$
  T + "                        and applies the same cassette BIOS patches real fMSX" + #CRLF$
  T + "                        does." + #CRLF$
  T + "  -pal/-ntsc          - Set PAL/NTSC HBlank/VBlank periods [NTSC]" + #CRLF$
  T + "  -rom <type>         - Select MegaROM mapper type [8,8] (0-7, see fMSX docs)." + #CRLF$
  T + "                        Accepted and stored, mapper switching isn't" + #CRLF$
  T + "                        implemented yet, so it has no effect on emulation." + #CRLF$
  T + "                        A non-numeric argument here is treated as a legacy" + #CRLF$
  T + "                        fossauro cartridge-file shorthand instead." + #CRLF$
  T + "  -home <dirname>     - Accepted, not yet implemented (system ROM directory)." + #CRLF$
  T + "  -printer <filename> - Accepted, not yet implemented." + #CRLF$
  T + "  -serial <filename>  - Accepted, not yet implemented." + #CRLF$
  T + "  -diska <filename>   - Accepted, not yet implemented (disk drive A:)." + #CRLF$
  T + "  -diskb <filename>   - Accepted, not yet implemented (disk drive B:)." + #CRLF$
  T + "  -tape <filename>    - Accepted, not yet implemented." + #CRLF$
  T + "  -font <filename>    - Accepted, not yet implemented." + #CRLF$
  T + "  -logsnd <filename>  - Accepted, not yet implemented (no PSG audio yet)." + #CRLF$
  T + "  -state <filename>   - Accepted, not yet implemented (no save-state yet)." + #CRLF$
  T + "  -auto/-noauto       - Accepted, not yet implemented (autofire on SPACE)." + #CRLF$
  T + "  -ram <pages>        - Accepted, not yet wired to the RAM allocator (fixed" + #CRLF$
  T + "                        64KB today)." + #CRLF$
  T + "  -vram <pages>       - Accepted, not yet wired to the VRAM allocator (fixed" + #CRLF$
  T + "                        128KB today)." + #CRLF$
  T + "  -joy <type>         - Accepted, not yet implemented (no joystick input yet)." + #CRLF$
  T + "  -simbdos/-wd1793    - Accepted, not yet implemented (no disk controller yet)." + #CRLF$
  T + "  -sound [<quality>]  - Accepted, not yet implemented (no PSG audio yet)." + #CRLF$
  T + "  -nosound            - Accepted (no-op - there's no sound to disable yet)." + #CRLF$
  T + "  -skip <percent>     - Accepted, not yet implemented (frame skip)." + #CRLF$
  T + "  -sync <frequency>   - Accepted, not yet implemented (screen update sync)." + #CRLF$
  T + "  -nosync             - Accepted, not yet implemented." + #CRLF$
  T + "  -static/-nostatic   - Accepted, not yet implemented (palette mode)." + #CRLF$
  T + "  -tv/-lcd/-raster    - Accepted, not yet implemented (scanline/raster fx)." + #CRLF$
  T + "  -linear             - Accepted, not yet implemented (display scaling)." + #CRLF$
  T + "  -soft/-eagle        - Accepted, not yet implemented (display scaling)." + #CRLF$
  T + "  -epx/-scale2x       - Accepted, not yet implemented (display scaling)." + #CRLF$
  T + "  -cmy/-rgb           - Accepted, not yet implemented (pixel raster fx)." + #CRLF$
  T + "  -mono/-sepia        - Accepted, not yet implemented (CRT color fx)." + #CRLF$
  T + "  -green/-amber       - Accepted, not yet implemented (CRT color fx)." + #CRLF$
  T + "  -4x3                - Accepted, not yet implemented (screen ratio)." + #CRLF$
  T + "  -trap <address>     - Accepted, not yet implemented (debugger trap)." + #CRLF$
  T + "  -scale <factor>     - Accepted, not yet implemented (window scale)." + #CRLF$ + #CRLF$
  T + "Full original fMSX option reference: fossauro/fossauro.md"
  ProcedureReturn T
EndProcedure

; Reflect the current Mode's model as a checkmark on Hardware->Model's three radio-style items.
Procedure UpdateModelMenuCheck()
  SetMenuItemState(0, 11, Bool((Mode & #MSX_MODEL) = #MSX_MSX1))
  SetMenuItemState(0, 12, Bool((Mode & #MSX_MODEL) = #MSX_MSX2))
  SetMenuItemState(0, 13, Bool((Mode & #MSX_MODEL) = #MSX_MSX2P))
EndProcedure

; Switch the running machine to a different MSX model: reloads the model-appropriate BIOS and
; does a full hardware reset, same as picking a fresh -msx1/-msx2/-msx2+ at startup would - RAM/
; VRAM content and any loaded cartridge are NOT preserved (a model switch is a cold boot in real
; hardware terms, not a hot-swap).
Procedure SwitchModel(NewModel.l)
  ThreadPaused = 1
  Mode = (Mode & ~#MSX_MODEL) | NewModel
  If Not MSXLoadBIOSForModel()
    MessageRequester("fossauro Error", "Could not load MSX BIOS ROM for the selected model.")
  EndIf
  If CurCartAPath <> "" : LoadCartridge(CurCartAPath, 1) : EndIf
  If CurCartBPath <> "" : LoadCartridge(CurCartBPath, 2) : EndIf
  ResetZ80(@CPU)
  ResetVDP()
  ResetPSG()
  UpdateModelMenuCheck()
  ThreadPaused = 0
  SetActiveGadget(0)
EndProcedure

; Initialize & Run Emulation
Procedure RunEmulator()
  ; fossauro.log is the definitive, persistent log - NOT wiped on every launch anymore.
  ; It accumulates across runs and rolls over on its own once it crosses #LogMaxBytes
  ; (see RotateLog() in MSX.pbi), Linux logrotate style (fossauro.log.1, .2, ...).
  LogGeneral("=== fossauro Start ===")
  
  ; fMSX-compatible CLI parsing (see GetFmsxHelpText() above and fossauro/fossauro.md for the
  ; full reference this is adapted from). Positional (non "-") arguments are cartridge A/B,
  ; matching real fMSX - "-rom <file>" (fossauro's own earlier shorthand) still works too,
  ; distinguished from real fMSX's "-rom <type>" by whether the argument is numeric.
  Protected CartA.s = "", CartB.s = ""
  Protected ParameterCount.l = CountProgramParameters()
  Protected ParamIdx.l = 0

  While ParamIdx < ParameterCount
    Protected Param.s = ProgramParameter(ParamIdx)
    Protected LParam.s = LCase(Param)
    Protected NextArg.s = ""
    Protected HasNextArg.b = Bool(ParamIdx + 1 < ParameterCount)
    If HasNextArg : NextArg = ProgramParameter(ParamIdx + 1) : EndIf

    Select LParam
      Case "-help", "-h", "-?", "/?"
        ; fossauro.exe is a GUI-subsystem app: plain OpenConsole() doesn't reliably attach
        ; to the caller's existing terminal (confirmed - it went nowhere the user could see,
        ; even run directly from a real PowerShell/cmd window, not just redirected).
        ; AttachConsole_(ATTACH_PARENT_PROCESS) is the actual WinAPI call for "reuse the
        ; console of whoever launched me" - if that succeeds, print there. If it fails
        ; (double-clicked, no parent console at all), fall back to a dialog box so the text
        ; is guaranteed visible somewhere either way.
        Protected HelpText.s = GetFmsxHelpText()
        Protected AttachedConsole.b = #False
        CompilerIf #PB_Compiler_OS = #PB_OS_Windows
          If AttachConsole(#ATTACH_PARENT_PROCESS)
            AttachedConsole = #True
          EndIf
        CompilerEndIf
        If AttachedConsole
          OpenConsole()
          PrintN("")
          PrintN(HelpText)
          CloseConsole()
          CompilerIf #PB_Compiler_OS = #PB_OS_Windows
            FreeConsole()
          CompilerEndIf
        Else
          MessageRequester("fossauro " + #App_Version + " - Ajuda / Help", HelpText)
        EndIf
        End

      Case "-verbose"
        If HasNextArg And LooksNumeric(NextArg)
          LogCategories = Val(NextArg)
          ParamIdx + 2
        Else
          LogCategories = #LogCat_All
          ParamIdx + 1
        EndIf
        Verbose = Bool(LogCategories <> 0)

      Case "-rom"
        If HasNextArg
          If LooksNumeric(NextArg) And Val(NextArg) >= 0 And Val(NextArg) <= 7
            LogGeneral("CLI: -rom " + NextArg + " (MegaROM mapper type - accepted, not yet implemented)")
          Else
            CartA = NextArg
          EndIf
          ParamIdx + 2
        Else
          ParamIdx + 1
        EndIf

      Case "-msx1"
        Mode = (Mode & ~#MSX_MODEL) | #MSX_MSX1 : ParamIdx + 1
      Case "-msx2"
        Mode = (Mode & ~#MSX_MODEL) | #MSX_MSX2 : ParamIdx + 1
      Case "-msx2+"
        Mode = (Mode & ~#MSX_MODEL) | #MSX_MSX2P : ParamIdx + 1
      Case "-pal"
        Mode = Mode | #MSX_PAL : ParamIdx + 1
      Case "-ntsc"
        Mode = Mode & ~#MSX_PAL : ParamIdx + 1

      ; Flags that take a filename/value argument - accepted and logged, not yet wired to
      ; actual behavior (see GetFmsxHelpText() for what each one is supposed to do).
      Case "-home", "-printer", "-serial", "-diska", "-diskb", "-tape", "-font", "-logsnd",
           "-state", "-ram", "-vram", "-joy", "-skip", "-sync", "-scale", "-trap"
        If HasNextArg
          LogGeneral("CLI: " + LParam + " " + NextArg + " (accepted, not yet implemented)")
          ParamIdx + 2
        Else
          ParamIdx + 1
        EndIf

      ; -sound takes an OPTIONAL numeric argument
      Case "-sound"
        If HasNextArg And LooksNumeric(NextArg)
          LogGeneral("CLI: -sound " + NextArg + " (accepted, not yet implemented)")
          ParamIdx + 2
        Else
          LogGeneral("CLI: -sound (accepted, not yet implemented)")
          ParamIdx + 1
        EndIf

      ; Boolean-only flags - accepted and logged, not yet wired to actual behavior.
      Case "-auto", "-noauto", "-simbdos", "-wd1793", "-nosound", "-nosync", "-static",
           "-nostatic", "-tv", "-lcd", "-raster", "-linear", "-soft", "-eagle", "-epx",
           "-scale2x", "-cmy", "-rgb", "-mono", "-sepia", "-green", "-amber", "-4x3",
           "-shm", "-noshm", "-saver", "-nosaver", "-vsync", "-480", "-200"
        LogGeneral("CLI: " + LParam + " (accepted, not yet implemented)")
        ParamIdx + 1

      Default
        If Left(Param, 1) <> "-"
          ; Positional argument: cartridge A, then cartridge B (real fMSX convention)
          If CartA = ""
            CartA = Param
          ElseIf CartB = ""
            CartB = Param
          EndIf
        Else
          LogGeneral("CLI: unrecognized option '" + Param + "' (ignored)")
        EndIf
        ParamIdx + 1
    EndSelect
  Wend

  LogGeneral("CLI Arguments: CartA = '" + CartA + "' CartB = '" + CartB + "'")

  ; 1. Init tables and system state
  InitZ80Tables()
  InitializeMSXMemory()
  
  ; 2. Route CPU callback pointers
  RealRdZ80 = @MSXRdZ80()
  WrZ80 = @MSXWrZ80()
  InZ80 = @MSXInZ80()
  OutZ80 = @MSXOutZ80()
  LoopZ80 = @MSXLoopZ80()
  PatchZ80 = @MSXPatchZ80()

  ; Temporary crash-diagnostic: dump the storage ADDRESS of every Z80 core callback
  ; pointer variable (not its value) so a captured crash-dump's faulting CALL target
  ; address can be matched back to a name.
  LogGeneral("DIAG addr RealRdZ80=$" + Hex(@RealRdZ80) + " WrZ80=$" + Hex(@WrZ80) + " InZ80=$" + Hex(@InZ80) +
         " OutZ80=$" + Hex(@OutZ80) + " LoopZ80=$" + Hex(@LoopZ80) + " PatchZ80=$" + Hex(@PatchZ80) +
         " JumpZ80=$" + Hex(@JumpZ80))
  
  ; 3. Load BIOS (model-aware: MSX.ROM / MSX2.ROM+MSX2EXT.ROM / MSX2P.ROM+MSX2PEXT.ROM,
  ; picked from Mode - set above by -msx1/-msx2/-msx2+ - matching real fMSX's own BIOS
  ; selection in StartMSX(); also applies the cassette BIOS patches, see MSX.pbi)
  If Not MSXLoadBIOSForModel()
    MessageRequester("fossauro Error", "Could not load MSX BIOS ROM for the selected model.")
    End
  EndIf

  ; 4. Create Emulation Frame Buffer Image (512x212)
  If Not CreateImage(0, 512, 212, 32)
    MessageRequester("fossauro Error", "Failed to create back buffer image.")
    End
  EndIf
  
  ; 5. Open Graphical Window
  Protected win_w.l = 512
  Protected win_h.l = 384
  If OpenWindow(0, 100, 100, win_w, win_h, "fossauro v" + #App_Version + " - PureBasic MSX Emulator", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
    ; Create Menus
    If CreateMenu(0, WindowID(0))
      MenuTitle("File")
      MenuItem(1, "Open Cartridge...")
      MenuItem(2, "Open Disk...")
      MenuBar()
      MenuItem(3, "Save Snapshot...")
      MenuItem(4, "Open Snapshot...")
      MenuBar()
      MenuItem(5, "Load .CAS...")
      MenuItem(6, "Load .CHT...")
      MenuBar()
      MenuItem(7, "Quit")

      MenuTitle("Emulation")
      MenuItem(8, "Reset")
      MenuItem(9, "Pause")
      MenuItem(10, "Resume")

      MenuTitle("Hardware")
      OpenSubMenu("Model")
        MenuItem(11, "MSX1")
        MenuItem(12, "MSX2")
        MenuItem(13, "MSX2+")
      CloseSubMenu()
    EndIf
    UpdateModelMenuCheck()
    
    ; Create Canvas Gadget
    CanvasGadget(0, 0, 0, win_w, win_h, #PB_Canvas_Keyboard)
    SetActiveGadget(0)
    
    ; Load startup cartridge(s) if specified via command line
    If CartA <> ""
      LoadCartridge(CartA, 1)
    EndIf
    If CartB <> ""
      LoadCartridge(CartB, 2)
    EndIf

    ; 6. Start audio and emulation threads
    StartAudio()
    ResetZ80(@CPU)
    ResetVDP()
    
    ThreadExit = 0
    ThreadPaused = 0
    EmulationThread = CreateThread(@EmulationThreadProc(), 0)
    
    ; 7. Main Window Event Loop
    Protected event.l, exit_window.l = 0
    Repeat
      event = WaitWindowEvent()
      
      Select event
        Case #PB_Event_Menu
          Select EventMenu()
            Case 1 ; Open Cartridge...
              ThreadPaused = 1
              Protected rom_file.s = OpenFileRequester("Select MSX Cartridge ROM", "", "MSX ROM (*.rom)|*.rom;*.mx1;*.mx2|All files (*.*)|*.*", 0)
              If rom_file <> ""
                LoadCartridge(rom_file)
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 2 ; Open Disk...
              ThreadPaused = 1
              Protected disk_file.s = OpenFileRequester("Select MSX Disk Image", "", "MSX Disk (*.dsk)|*.dsk|All files (*.*)|*.*", 0)
              If disk_file <> ""
                ; No floppy disk controller emulation yet (see docs/SPEC.md module 32c) - the
                ; path is accepted and logged so the picker isn't a dead end, but nothing reads
                ; from it until FDC support exists.
                LogGeneral("Open Disk: " + disk_file + " (accepted, floppy disk controller not yet implemented)")
                MessageRequester("fossauro", "Disk image selected, but floppy disk controller emulation isn't implemented yet." + #CRLF$ + "The file was not loaded.")
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 3 ; Save Snapshot...
              ThreadPaused = 1
              Protected save_file.s = SaveFileRequester("Save Snapshot", "", "fossauro Snapshot (*.fss)|*.fss", 0)
              If save_file <> ""
                If LCase(Right(save_file, 4)) <> ".fss" : save_file + ".fss" : EndIf
                If Not SaveSnapshot(save_file)
                  MessageRequester("fossauro Error", "Could not save snapshot to " + save_file)
                EndIf
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 4 ; Open Snapshot...
              ThreadPaused = 1
              Protected load_snap_file.s = OpenFileRequester("Open Snapshot", "", "fossauro Snapshot (*.fss)|*.fss|All files (*.*)|*.*", 0)
              If load_snap_file <> ""
                If Not LoadSnapshot(load_snap_file)
                  MessageRequester("fossauro Error", "Could not load snapshot from " + load_snap_file)
                EndIf
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 5 ; Load .CAS...
              ThreadPaused = 1
              Protected cas_file.s = OpenFileRequester("Select Cassette Tape Image", "", "Cassette Tape (*.cas)|*.cas|All files (*.*)|*.*", 0)
              If cas_file <> ""
                ; Cassette emulation not implemented yet (explicit scope decision - see
                ; docs/SPEC.md) - the picker exists so the menu structure is complete, but
                ; nothing is done with the file yet.
                LogGeneral("Load .CAS: " + cas_file + " (accepted, cassette emulation not yet implemented)")
                MessageRequester("fossauro", "Cassette tape emulation isn't implemented yet." + #CRLF$ + "The file was not loaded.")
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 6 ; Load .CHT...
              ThreadPaused = 1
              Protected cht_file.s = OpenFileRequester("Select Cheat File", "", "Cheat File (*.cht)|*.cht|All files (*.*)|*.*", 0)
              If cht_file <> ""
                ; Cheat support (openMSX/BlueMSX .cht-compatible format) is planned but not
                ; implemented yet - see docs/SPEC.md.
                LogGeneral("Load .CHT: " + cht_file + " (accepted, cheat support not yet implemented)")
                MessageRequester("fossauro", "Cheat file support isn't implemented yet." + #CRLF$ + "The file was not loaded.")
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 7 ; Quit
              exit_window = 1

            Case 8 ; Reset
              ThreadPaused = 1
              ResetZ80(@CPU)
              ResetVDP()
              ResetPSG()
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 9 ; Pause
              ThreadPaused = 1

            Case 10 ; Resume
              ThreadPaused = 0
              SetActiveGadget(0)

            Case 11 ; Hardware -> Model -> MSX1
              SwitchModel(#MSX_MSX1)

            Case 12 ; Hardware -> Model -> MSX2
              SwitchModel(#MSX_MSX2)

            Case 13 ; Hardware -> Model -> MSX2+
              SwitchModel(#MSX_MSX2P)
          EndSelect
          
        Case #PB_Event_Gadget
          If EventGadget() = 0
            Protected canvas_type.l = EventType()
            Select canvas_type
              Case #PB_EventType_LeftButtonDown
                SetActiveGadget(0)
              Case #PB_EventType_LostFocus
                ResetKeyboard()
                Dim PCKeyStates.b(512)
              Case #PB_EventType_KeyDown
                Protected key_down.l = GetGadgetAttribute(0, #PB_Canvas_Key)
                If key_down >= 0 And key_down < 512
                  If PCKeyStates(key_down) = 0
                    PCKeyStates(key_down) = 1
                    Protected msx_key_down.l = MapCanvasKey(key_down)
                    If msx_key_down > 0
                      MSXKeyPress(msx_key_down)
                    EndIf
                  EndIf
                EndIf
                
              Case #PB_EventType_KeyUp
                Protected key_up.l = GetGadgetAttribute(0, #PB_Canvas_Key)
                If key_up >= 0 And key_up < 512
                  PCKeyStates(key_up) = 0
                  Protected msx_key_up.l = MapCanvasKey(key_up)
                  If msx_key_up > 0
                    MSXKeyRelease(msx_key_up)
                  EndIf
                EndIf
            EndSelect
          EndIf
          
        Case #PB_Event_FirstCustomValue + 1
          ; Frame Ready - Render to Canvas
          FramePending = 0
          If StartDrawing(ImageOutput(0))
            Protected *Buf = DrawingBuffer()
            Protected pitch.l = DrawingBufferPitch()
            Protected y.l
            For y = 0 To 211
              CopyMemory(@FrameBuffer(y * 512), *Buf + (211 - y) * pitch, 512 * 4)
            Next y
            StopDrawing()
          EndIf
          If StartDrawing(CanvasOutput(0))
            DrawImage(ImageID(0), 0, 0, win_w, win_h)
            StopDrawing()
          EndIf
          
        Case #PB_Event_CloseWindow
          exit_window = 1
      EndSelect
    Until exit_window = 1
    
    ; 8. Shutdown & cleanup
    ThreadExit = 1
    If EmulationThread
      WaitThread(EmulationThread, 2000)
      EmulationThread = 0
    EndIf
    StopAudio()
    CloseLogFile()
  EndIf
EndProcedure

RunEmulator()
