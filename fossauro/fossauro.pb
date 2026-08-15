; fossauro - PureBasic MSX Emulator
; Main Entry Point & Graphical User Interface

EnableExplicit

CompilerIf Not Defined(App_Version, #PB_Constant)
  #App_Version = "8.0.1"
CompilerEndIf

; --- Emulation Control Globals ---
Global ThreadExit.l = 0
Global ThreadPaused.l = 0
Global EmulationThread.i = 0
Global Dim PCKeyStates.b(512)

; Include Z80 Emulator, Motherboard, Video, and Audio files
XIncludeFile "Z80_Tables.pbi"
XIncludeFile "Z80.pbi"
XIncludeFile "MSX.pbi"

; Z80 CPU Patch Callback (not used but required by CPU definition)
Procedure MyPatchZ80(*R.Z80)
EndProcedure

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
  PatchZ80 = @MyPatchZ80()
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
    ; Punctuation mappings
    Case 186 : ProcedureReturn 59 ; Semicolon
    Case 187 : ProcedureReturn 43 ; Equal
    Case 188 : ProcedureReturn 44 ; Comma
    Case 189 : ProcedureReturn 45 ; Minus
    Case 190 : ProcedureReturn 46 ; Period
    Case 191 : ProcedureReturn 47 ; Slash
    Case 222 : ProcedureReturn 39 ; Single Quote
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

; Load 16K/32K standard ROM cartridge
Procedure.l LoadCartridge(FileName.s)
  LogGeneral("LoadCartridge called for: " + FileName)
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
  
  If *ROMData(0)
    FreeMemory(*ROMData(0))
  EndIf
  *ROMData(0) = AllocateMemory(Length)
  ReadData(FileNum, *ROMData(0), Length)
  CloseFile(FileNum)
  
  Protected header.s = Chr(PeekA(*ROMData(0))) + Chr(PeekA(*ROMData(0)+1))
  LogGeneral("LoadCartridge: ROM Header Bytes = $" + Hex(PeekA(*ROMData(0))) + " $" + Hex(PeekA(*ROMData(0)+1)) + " ('" + header + "')")
  
  ; Reset slot maps first to empty
  Protected J.l
  For J = 2 To 5
    *MemMap(1, 0, J) = *EmptyRAM
    *MemMap(2, 0, J) = *EmptyRAM
  Next J
  
  ; Map cartridge
  If Length = 32768
    For J = 2 To 5
      *MemMap(1, 0, J) = *ROMData(0) + (J - 2) * $2000
      *MemMap(2, 0, J) = *ROMData(0) + (J - 2) * $2000
    Next J
    LogGeneral("LoadCartridge: Mapped 32KB ROM to Slot 1-0 and Slot 2-0")
  ElseIf Length = 16384
    *MemMap(1, 0, 2) = *ROMData(0) : *MemMap(1, 0, 3) = *ROMData(0) + $2000
    *MemMap(1, 0, 4) = *ROMData(0) : *MemMap(1, 0, 5) = *ROMData(0) + $2000
    *MemMap(2, 0, 2) = *ROMData(0) : *MemMap(2, 0, 3) = *ROMData(0) + $2000
    *MemMap(2, 0, 4) = *ROMData(0) : *MemMap(2, 0, 5) = *ROMData(0) + $2000
    LogGeneral("LoadCartridge: Mapped 16KB ROM (Mirrored) to Slot 1-0 and Slot 2-0")
  Else
    LogGeneral("LoadCartridge WARNING: Unsupported ROM size " + Str(Length))
  EndIf
  
  ; Reset hardware state
  ResetZ80(@CPU)
  ResetVDP()
  ResetPSG()
  
  LogGeneral("LoadCartridge: Cartridge loaded successfully and hardware reset.")
  ProcedureReturn 1
EndProcedure

; Initialize & Run Emulation
Procedure RunEmulator()
  ; fossauro.log is the definitive, persistent log - NOT wiped on every launch anymore.
  ; It accumulates across runs and rolls over on its own once it crosses #LogMaxBytes
  ; (see RotateLog() in MSX.pbi), Linux logrotate style (fossauro.log.1, .2, ...).
  LogGeneral("=== fossauro Start ===")
  
  Protected RomFileToLoad.s = ""
  Protected ParameterCount.l = CountProgramParameters()
  Protected ParamIdx.l = 0
  
  While ParamIdx < ParameterCount
    Protected Param.s = ProgramParameter(ParamIdx)
    If LCase(Param) = "-rom" And ParamIdx + 1 < ParameterCount
      RomFileToLoad = ProgramParameter(ParamIdx + 1)
      ParamIdx + 2
    Else
      ParamIdx + 1
    EndIf
  Wend
  
  LogGeneral("CLI Arguments: RomFileToLoad = '" + RomFileToLoad + "'")

  ; 1. Init tables and system state
  InitZ80Tables()
  InitializeMSXMemory()
  
  ; 2. Route CPU callback pointers
  RealRdZ80 = @MSXRdZ80()
  WrZ80 = @MSXWrZ80()
  InZ80 = @MSXInZ80()
  OutZ80 = @MSXOutZ80()
  LoopZ80 = @MSXLoopZ80()
  PatchZ80 = @MyPatchZ80()

  ; Temporary crash-diagnostic: dump the storage ADDRESS of every Z80 core callback
  ; pointer variable (not its value) so a captured crash-dump's faulting CALL target
  ; address can be matched back to a name.
  LogGeneral("DIAG addr RealRdZ80=$" + Hex(@RealRdZ80) + " WrZ80=$" + Hex(@WrZ80) + " InZ80=$" + Hex(@InZ80) +
         " OutZ80=$" + Hex(@OutZ80) + " LoopZ80=$" + Hex(@LoopZ80) + " PatchZ80=$" + Hex(@PatchZ80) +
         " JumpZ80=$" + Hex(@JumpZ80))
  
  ; 3. Load BIOS
  If Not MSXLoadBIOS("fMSX/MSX.ROM")
    MessageRequester("fossauro Error", "Could not load MSX BIOS ROM 'fMSX/MSX.ROM'.")
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
      MenuItem(1, "Load ROM...")
      MenuBar()
      MenuItem(2, "Exit")
      
      MenuTitle("Emulation")
      MenuItem(3, "Reset")
      MenuItem(4, "Pause")
      MenuItem(5, "Resume")
    EndIf
    
    ; Create Canvas Gadget
    CanvasGadget(0, 0, 0, win_w, win_h, #PB_Canvas_Keyboard)
    SetActiveGadget(0)
    
    ; Load startup cartridge if specified via command line
    If RomFileToLoad <> ""
      LoadCartridge(RomFileToLoad)
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
            Case 1 ; Load ROM
              ThreadPaused = 1
              Protected rom_file.s = OpenFileRequester("Select MSX Cartridge ROM", "", "MSX ROM (*.rom)|*.rom;*.mx1;*.mx2|All files (*.*)|*.*", 0)
              If rom_file <> ""
                LoadCartridge(rom_file)
              EndIf
              ThreadPaused = 0
              SetActiveGadget(0)
              
            Case 2 ; Exit
              exit_window = 1
              
            Case 3 ; Reset
              ThreadPaused = 1
              ResetZ80(@CPU)
              ResetVDP()
              ResetPSG()
              ThreadPaused = 0
              SetActiveGadget(0)
              
            Case 4 ; Pause
              ThreadPaused = 1
              
            Case 5 ; Resume
              ThreadPaused = 0
              SetActiveGadget(0)
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
