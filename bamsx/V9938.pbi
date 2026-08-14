; V9938 VDP Graphics Processor Emulation for bamsx
; Derived from fMSX V9938.c by Marat Fayzullin

; Globals representing the VDP state
Global *VRAM                      ; Video RAM buffer (128KB)
Global *VPAGE                     ; Active 16KB VRAM page pointer
Global VDPKey.a = 1               ; Write phase indicator (TMS9918 double-write address/register select)
Global VDPALatch.a = 0            ; Address latch register
Global VDPAddr.u = 0              ; VRAM access address (14-bit)
Global VDPData.a = 0              ; VRAM read-ahead buffer

Global Dim VDP.a(63)              ; VDP Control Registers (VDP[0] to VDP[63])
Global Dim VDPStatus.a(15)        ; VDP Status Registers (VDPStatus[0] to VDPStatus[15])

Global ScrMode.a = 0              ; Screen Mode index
Global ScanLine.l = 0             ; Current rendering scanline
Global FGColor.a = 15             ; Foreground color
Global BGColor.a = 1              ; Background color

; Forward Declarations
Declare SetScreen()
Declare InitializeVDP()
Declare ResetVDP()
Declare VDPOut(R.a, V.a)
Declare MSXWriteVDP(Port.u, V.a)
Declare.a MSXReadVDP(Port.u)
Declare.u SetIRQ(IRQ.a)

; Dummy SetScreen procedure (will be expanded for UI screen rendering)
Procedure SetScreen()
  ; Screen mode index calculation from VDP registers
  Protected modeBits.a = ((VDP(0) & $0E) >> 1) | (VDP(1) & $18)
  Select modeBits
    Case $10 : ScrMode = 0
    Case $00 : ScrMode = 1
    Case $01 : ScrMode = 2
    Case $08 : ScrMode = 3
    Case $02 : ScrMode = 4
    Case $03 : ScrMode = 5
    Case $04 : ScrMode = 6
    Case $05 : ScrMode = 7
    Case $07 : ScrMode = 8
    Default  : ScrMode = 0
  EndSelect
EndProcedure

; Initialize Video memory and structures
Procedure InitializeVDP()
  ; Allocate 128KB Video RAM
  *VRAM = AllocateMemory($20000)
  FillMemory(*VRAM, $20000, $00)
  
  *VPAGE = *VRAM
  
  ResetVDP()
EndProcedure

; Reset Video Processor registers
Procedure ResetVDP()
  Protected I.l
  
  ; Clear control and status registers
  For I = 0 To 63
    VDP(I) = 0
  Next I
  For I = 0 To 15
    VDPStatus(I) = 0
  Next I
  
  VDPKey = 1
  VDPALatch = 0
  VDPAddr = 0
  VDPData = 0
  *VPAGE = *VRAM
  ScrMode = 0
EndProcedure

; Write value into VDP control register
Procedure VDPOut(R.a, V.a)
  Select R
    Case 0
      ; Reset HBlank interrupt if disabled
      If (VDPStatus(1) & $01) And (V & $10) = 0
        VDPStatus(1) = VDPStatus(1) & $FE
        SetIRQ(~#INT_IE1)
      EndIf
      If VDP(0) <> V
        VDP(0) = V
        SetScreen()
      EndIf
      
    Case 1
      ; Set/Reset VBlank interrupt if enabled/disabled
      If VDPStatus(0) & $80
        If V & $20
          SetIRQ(#INT_IE0)
        Else
          SetIRQ(~#INT_IE0)
        EndIf
      EndIf
      If VDP(1) <> V
        VDP(1) = V
        SetScreen()
      EndIf
      
    Case 14
      ; Select active 16KB VRAM page
      Protected pageIndex.a = V & (VRAMPages - 1)
      *VPAGE = *VRAM + (pageIndex << 14)
      
    Case 15
      ; Select status register to read on port $99
      VDP(15) = V & $0F
      
    Case 16
      ; Color palette register select
      VDP(16) = V & $0F
      
    Case 25
      ; Screen mode control register 25
      VDP(25) = V
      SetScreen()
      
    ; Other registers are just stored; graphics routines query them directly
  EndSelect
  
  VDP(R) = V
EndProcedure

; Handle port writes ($98-$99) from MSXOutZ80
Procedure MSXWriteVDP(Port.u, V.a)
  Port & $FF
  Select Port
    Case $98
      ; VRAM Write
      PokeA(*VPAGE + VDPAddr, V)
      VDPData = V
      VDPAddr = (VDPAddr + 1) & $3FFF
      
    Case $99
      ; Control port address latch write
      If VDPKey = 1
        VDPALatch = V
        VDPKey = 0
      Else
        VDPKey = 1
        Select V & $C0
          Case $80
            ; Control register write
            VDPOut(V & $3F, VDPALatch)
          Case $00, $40
            ; Setup VRAM access address
            VDPAddr = ((V & $3F) << 8) | VDPALatch
            ; When configured for reading, pre-read the first byte
            If (V & $40) = 0
              VDPData = PeekA(*VPAGE + VDPAddr)
              VDPAddr = (VDPAddr + 1) & $3FFF
            EndIf
        EndSelect
      EndIf
  EndSelect
EndProcedure

; Handle port reads ($98-$99) from MSXInZ80
Procedure.a MSXReadVDP(Port.u)
  Port & $FF
  Select Port
    Case $98
      ; VRAM Read (auto-increments address within selected 16KB page)
      Protected res.a = VDPData
      VDPData = PeekA(*VPAGE + VDPAddr)
      VDPAddr = (VDPAddr + 1) & $3FFF
      ProcedureReturn res
      
    Case $99
      ; Status Register read
      Protected statusReg.a = VDP(15)
      Protected statusVal.a = VDPStatus(statusReg)
      
      ; Reading status register 0 clears VBlank flag
      If statusReg = 0
        VDPStatus(0) = VDPStatus(0) & $7F
      EndIf
      
      ProcedureReturn statusVal
  EndSelect
  
  ProcedureReturn $FF
EndProcedure
