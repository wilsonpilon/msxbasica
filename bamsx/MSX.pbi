; MSX Board Emulation & Slot Memory Mapper for bamsx
; Derived from fMSX source by Marat Fayzullin

; System hardware constants
#MSX_MODEL  = $03
#MSX_MSX1   = $00
#MSX_MSX2   = $01
#MSX_MSX2P  = $02

#MSX_VIDEO  = $04
#MSX_NTSC   = $00
#MSX_PAL    = $04

; CPU Cycles per scanline phase
#CPU_HPERIOD = 228                ; 1368 VDP cycles / 6
#CPU_H240    = 160                ; 960 VDP cycles / 6
#CPU_H256    = 170                ; 1024 VDP cycles / 6

; Interrupt request bitmasks in IRQPending
#INT_IE0     = $01                ; VBlank Interrupt flag (IE0)
#INT_IE1     = $02                ; Line Coincidence Interrupt flag (IE1)

Global CPU.Z80                    ; Global Z80 CPU state
Global IRQPending.a = 0           ; Bitmask of currently pending interrupts

; Global memory mapping arrays
Global Dim *RAM(7)              ; Active Z80 address space (8 x 8KB pages)
Global Dim *MemMap(3, 3, 7)     ; Slot memory layout mapping [PrimarySlot][SecondarySlot][8KBPage]
Global Dim EnWrite.a(3)           ; 1 if write-enabled for each of the 4 16KB pages
Global Dim PSL.a(3)               ; Primary slot selection list for the 4 pages
Global Dim SSL.a(3)               ; Secondary slot selection list for the 4 pages

; Intel 8255 PPI Structure
Structure I8255
  R.a[4]         ; Registers
  Rout.a[3]      ; Output ports
  Rin.a[3]       ; Input ports
EndStructure

Global PPI.I8255                  ; Main Intel 8255 PPI instance

; Slot Registers
Global PSLReg.a                   ; Primary slot register state (PPI port $A8)
Global Dim SSLReg.a(3)            ; Secondary slot registers state (each slot has one at $FFFF)

; Key Matrix state (16 rows)
Global Dim KeyMatrix.a(15)        ; MSX keyboard row state matrix
Global Dim KeysRow.a(129)         ; Keyboard matrix row for each code
Global Dim KeysMask.a(129)        ; Keyboard matrix mask for each code

; Emulator control variables
Global Verbose.a = 1
Global Mode.l = #MSX_MSX2 | #MSX_NTSC  ; Default MSX2 NTSC
Global RAMPages.l = 4             ; 4 x 16KB = 64KB RAM
Global VRAMPages.l = 8            ; 8 x 16KB = 128KB VRAM
Global UPeriod.a = 75             ; % of frames to draw (defaults to 75)

; Include V9938 VDP Graphics Processor Emulation
XIncludeFile "V9938.pbi"

; PSG (AY-3-8910 Sound chip) state
Global PSGLatch.a = 0             ; Selected PSG register index latch
Global Dim PSGRegs.a(15)          ; PSG Registers

; Memory blocks
Global *EmptyRAM                  ; Pointer to dummy 8KB block initialized to $FF
Global *RAMData                   ; Main RAM buffer
Global *BIOSData                  ; Main MSX BIOS ROM buffer (32KB)
Global Dim *ROMData(5)            ; Cartridge/System ROM data pointers

; Intel 8255 PPI Helper Procedures
Procedure Reset8255(*D.I8255)
  *D\R[0] = 0 : *D\Rout[0] = 0 : *D\Rin[0] = 0
  *D\R[1] = 0 : *D\Rout[1] = 0 : *D\Rin[1] = 0
  *D\R[2] = 0 : *D\Rout[2] = 0 : *D\Rin[2] = 0
  *D\R[3] = $9B
EndProcedure

Procedure.a Write8255(*D.I8255, A.a, V.a)
  Select A
    Case 0, 1, 2
      *D\R[A] = V
    Case 3
      If V & $80
        *D\R[3] = V
      Else
        Protected bit.a = 1 << ((V & $0E) >> 1)
        If V & $01
          *D\R[2] | bit
        Else
          *D\R[2] & ~bit
        EndIf
      EndIf
    Default
      ProcedureReturn 0
  EndSelect
  
  Protected ctrl.a = *D\R[3]
  If ctrl & $10 : *D\Rout[0] = $00 : Else : *D\Rout[0] = *D\R[0] : EndIf
  If ctrl & $02 : *D\Rout[1] = $00 : Else : *D\Rout[1] = *D\R[1] : EndIf
  
  Protected rout2.a = 0
  If (ctrl & $01) = 0 : rout2 | (*D\R[2] & $0F) : EndIf
  If (ctrl & $08) = 0 : rout2 | (*D\R[2] & $F0) : EndIf
  *D\Rout[2] = rout2
  
  ProcedureReturn 1
EndProcedure

Procedure.a Read8255(*D.I8255, A.a)
  Select A
    Case 0
      If *D\R[3] & $10 : ProcedureReturn *D\Rin[0] : Else : ProcedureReturn *D\R[0] : EndIf
    Case 1
      If *D\R[3] & $02 : ProcedureReturn *D\Rin[1] : Else : ProcedureReturn *D\R[1] : EndIf
    Case 2
      Protected val2.a = 0
      If *D\R[3] & $01 : val2 | (*D\Rin[2] & $0F) : Else : val2 | (*D\R[2] & $0F) : EndIf
      If *D\R[3] & $08 : val2 | (*D\Rin[2] & $F0) : Else : val2 | (*D\R[2] & $F0) : EndIf
      ProcedureReturn val2
    Case 3
      ProcedureReturn *D\R[3]
  EndSelect
  ProcedureReturn $00
EndProcedure

; Initialize Z80-mapped slot memories and hardware registers
Procedure InitializeMSXMemory()
  Protected I.l, J.l, K.l
  
  ; Allocate empty RAM region (filled with $FF)
  *EmptyRAM = AllocateMemory($2000)
  FillMemory(*EmptyRAM, $2000, $FF)
  
  ; Allocate main BIOS ROM memory (32KB default)
  *BIOSData = AllocateMemory($8000)
  FillMemory(*BIOSData, $8000, $FF)
  
  ; Initialize all Slot memory mappings to EmptyRAM
  For I = 0 To 3
    For J = 0 To 3
      For K = 0 To 7
        *MemMap(I, J, K) = *EmptyRAM
      Next K
    Next J
  Next I
  
  ; Allocate main system RAM (64KB default)
  *RAMData = AllocateMemory($10000)
  FillMemory(*RAMData, $10000, $00)
  
  ; Map main RAM to Slot 3-2 (Primary 3, Secondary 2)
  For J = 0 To 3
    *MemMap(3, 2, J * 2)     = *RAMData + (3 - J) * $4000
    *MemMap(3, 2, J * 2 + 1) = *MemMap(3, 2, J * 2) + $2000
  Next J
  
  ; Set initial primary and secondary slots
  PSLReg = $00
  For J = 0 To 3
    PSL(J) = 0
    SSL(J) = 0
    SSLReg(J) = $00
    
    ; Map slot 0-0 initially
    *RAM(J * 2)     = *MemMap(0, 0, J * 2)
    *RAM(J * 2 + 1) = *MemMap(0, 0, J * 2 + 1)
    
    ; Enable writes only if slot maps to RAM
    EnWrite(J) = 0
  Next J
  
  ; Load Keyboard matrix configuration from DataSection
  Restore KeyboardData
  For I = 0 To 129
    Read.b KeysRow(I)
    Read.b KeysMask(I)
  Next I
  
  ; Clear Keyboard Matrix (all keys released, active low)
  For I = 0 To 15
    KeyMatrix(I) = $FF
  Next I
  
  ; Reset PPI chip state
  Reset8255(@PPI)
  
  ; Initialize VDP chip state
  InitializeVDP()
EndProcedure

; Load BIOS file from disk and map it to Slot 0-0
Procedure.l MSXLoadBIOS(FileName.s)
  Protected FileNum.i = ReadFile(#PB_Any, FileName)
  If FileNum = 0
    ProcedureReturn 0 ; failed to open
  EndIf
  
  Protected Length.q = Lof(FileNum)
  If Length > $8000
    Length = $8000
  EndIf
  
  ReadData(FileNum, *BIOSData, Length)
  CloseFile(FileNum)
  
  ; Map BIOS to Slot 0-0 pages 0, 1, 2, 3 (each is 8KB, total 32KB)
  Protected I.l
  For I = 0 To 3
    *MemMap(0, 0, I) = *BIOSData + I * $2000
  Next I
  
  ; Update active memory pages if Slot 0-0 is mapped
  For I = 0 To 3
    If PSL(I) = 0 And SSL(I) = 0
      *RAM(I * 2)     = *MemMap(0, 0, I * 2)
      *RAM(I * 2 + 1) = *MemMap(0, 0, I * 2 + 1)
    EndIf
  Next I
  
  ProcedureReturn 1 ; success
EndProcedure

; Switch primary memory slots (Port $A8 write)
Procedure PSlot(V.a)
  Protected J.a, I.a
  
  If PSLReg <> V
    PSLReg = V
    For J = 0 To 3
      I = J << 1
      PSL(J) = V & 3
      SSL(J) = (SSLReg(PSL(J)) >> I) & 3
      *RAM(I)   = *MemMap(PSL(J), SSL(J), I)
      *RAM(I+1) = *MemMap(PSL(J), SSL(J), I+1)
      
      If PSL(J) = 3 And SSL(J) = 2 And *MemMap(3, 2, I) <> *EmptyRAM
        EnWrite(J) = 1
      Else
        EnWrite(J) = 0
      EndIf
      
      V >> 2
    Next J
  EndIf
EndProcedure

; Switch secondary memory slots (Memory address $FFFF write)
Procedure SSlot(V.a)
  Protected J.a, I.a
  
  ; Cartridge slots do not have subslots, fix them at 0:0:0:0
  If PSL(3) = 1 Or PSL(3) = 2
    V = $00
  EndIf
  
  ; In MSX1, slot 0 does not have subslots
  If PSL(3) = 0 And (Mode & #MSX_MODEL) = #MSX_MSX1
    V = $00
  EndIf
  
  If SSLReg(PSL(3)) <> V
    SSLReg(PSL(3)) = V
    For J = 0 To 3
      If PSL(J) = PSL(3)
        I = J << 1
        SSL(J) = V & 3
        *RAM(I)   = *MemMap(PSL(J), SSL(J), I)
        *RAM(I+1) = *MemMap(PSL(J), SSL(J), I+1)
        
        If PSL(J) = 3 And SSL(J) = 2 And *MemMap(3, 2, I) <> *EmptyRAM
          EnWrite(J) = 1
        Else
          EnWrite(J) = 0
        EndIf
      EndIf
      V >> 2
    Next J
  EndIf
EndProcedure

; Memory reading callback
Procedure.a MSXRdZ80(A.u)
  ; Filter out everything but [xx11 1111 1xxx 1xxx] for FDC/special registers
  If (A & $3F88) <> $3F88
    ProcedureReturn PeekA(*RAM(A >> 13) + (A & $1FFF))
  EndIf

  ; Secondary slot selector at $FFFF
  If A = $FFFF
    ProcedureReturn ~SSLReg(PSL(3))
  EndIf

  ; TODO: Floppy disk controller check (PSL=3, SSL=1)

  ProcedureReturn PeekA(*RAM(A >> 13) + (A & $1FFF))
EndProcedure

; Memory writing callback
Procedure MSXWrZ80(A.u, V.a)
  ; Secondary slot selector at $FFFF
  If A = $FFFF
    SSlot(V)
    ProcedureReturn
  EndIf

  ; TODO: Floppy disk controller write check (PSL=3, SSL=1)

  ; Write to RAM if enabled
  If EnWrite(A >> 14)
    PokeA(*RAM(A >> 13) + (A & $1FFF), V)
    ProcedureReturn
  EndIf

  ; TODO: Switch MegaROM pages (MapROM)
EndProcedure

; Input port reading callback
Procedure.a MSXInZ80(Port.u)
  Port & $FF
  Select Port
    Case $98, $99
      ProcedureReturn MSXReadVDP(Port)
      
    Case $A0, $A1, $A2
      ; PSG registers read
      If Port = $A2
        ProcedureReturn PSGRegs(PSGLatch)
      Else
        ProcedureReturn $FF
      EndIf
      
    Case $A8, $A9, $AA, $AB
      ; Before reading PPI, update register C input (KeyMatrix row selected by Port C output lower nibble)
      Protected row.a = PPI\Rout[2] & $0F
      PPI\Rin[1] = KeyMatrix(row)
      ProcedureReturn Read8255(@PPI, Port - $A8)
    Default:
      ProcedureReturn $FF
  EndSelect
EndProcedure

; Output port writing callback
Procedure MSXOutZ80(Port.u, V.a)
  Port & $FF
  Select Port
    Case $98, $99
      MSXWriteVDP(Port, V)
      
    Case $A0
      ; PSG latch register select
      PSGLatch = V & $0F
    Case $A1
      ; PSG write register data
      PSGRegs(PSGLatch) = V
      
    Case $A8, $A9, $AA, $AB
      Protected oldRout0.a = PPI\Rout[0]
      Protected oldRout2.a = PPI\Rout[2]
      
      Write8255(@PPI, Port - $A8, V)
      
      ; If primary slot state has changed...
      If PPI\Rout[0] <> oldRout0
        PSlot(PPI\Rout[0])
      EndIf
      
      ; If I/O control register has changed...
      If PPI\Rout[2] <> oldRout2
        ; Drum/sound click placeholder
      EndIf
  EndSelect
EndProcedure

; Set key pressed (active low)
Procedure MSXKeyPress(K.a)
  If K <= 129
    KeyMatrix(KeysRow(K)) = KeyMatrix(KeysRow(K)) & ~KeysMask(K)
  EndIf
EndProcedure

; Set key released (active low)
Procedure MSXKeyRelease(K.a)
  If K <= 129
    KeyMatrix(KeysRow(K)) = KeyMatrix(KeysRow(K)) | KeysMask(K)
  EndIf
EndProcedure

DataSection
  KeyboardData:
  ; Row, Mask pairs for Keys[130][2]
  Data.b 0,$00, 8,$10, 8,$20, 8,$80 ; None,LEFT,UP,RIGHT
  Data.b 8,$40, 6,$01, 6,$02, 6,$04 ; DOWN,SHIFT,CONTROL,GRAPH
  Data.b 7,$20, 7,$08, 6,$08, 7,$40 ; BS,TAB,CAPSLOCK,SELECT
  Data.b 8,$02, 7,$80, 8,$08, 8,$04 ; HOME,ENTER,DELETE,INSERT
  Data.b 6,$10, 7,$10, 6,$20, 6,$40 ; COUNTRY,STOP,F1,F2
  Data.b 6,$80, 7,$01, 7,$02, 9,$08 ; F3,F4,F5,PAD0
  Data.b 9,$10, 9,$20, 9,$40, 7,$04 ; PAD1,PAD2,PAD3,ESCAPE
  Data.b 9,$80, 10,$01, 10,$02, 10,$04 ; PAD4,PAD5,PAD6,PAD7
  Data.b 8,$01, 0,$02, 2,$01, 0,$08 ; SPACE,[!],["],[#]
  Data.b 0,$10, 0,$20, 0,$80, 2,$01 ; [$],[%],[&],[']
  Data.b 1,$02, 0,$01, 1,$01, 1,$08 ; [(],[)],[*],[=]
  Data.b 2,$04, 1,$04, 2,$08, 2,$10 ; [,],[-],[.],[/]
  Data.b 0,$01, 0,$02, 0,$04, 0,$08 ; 0,1,2,3
  Data.b 0,$10, 0,$20, 0,$40, 0,$80 ; 4,5,6,7
  Data.b 1,$01, 1,$02, 1,$80, 1,$80 ; 8,9,[:],[;]
  Data.b 2,$04, 1,$08, 2,$08, 2,$10 ; [<],[=],[>],[?]
  Data.b 0,$04, 2,$40, 2,$80, 3,$01 ; [@],A,B,C
  Data.b 3,$02, 3,$04, 3,$08, 3,$10 ; D,E,F,G
  Data.b 3,$20, 3,$40, 3,$80, 4,$01 ; H,I,J,K
  Data.b 4,$02, 4,$04, 4,$08, 4,$10 ; L,M,N,O
  Data.b 4,$20, 4,$40, 4,$80, 5,$01 ; P,Q,R,S
  Data.b 5,$02, 5,$04, 5,$08, 5,$10 ; T,U,V,W
  Data.b 5,$20, 5,$40, 5,$80, 1,$20 ; X,Y,Z,[[]
  Data.b 1,$10, 1,$40, 0,$40, 1,$04 ; [\],[]],[^],[_]
  Data.b 2,$02, 2,$40, 2,$80, 3,$01 ; [`],a,b,c
  Data.b 3,$02, 3,$04, 3,$08, 3,$10 ; d,e,f,g
  Data.b 3,$20, 3,$40, 3,$80, 4,$01 ; h,i,j,k
  Data.b 4,$02, 4,$04, 4,$08, 4,$10 ; l,m,n,o
  Data.b 4,$20, 4,$40, 4,$80, 5,$01 ; p,q,r,s
  Data.b 5,$02, 5,$04, 5,$08, 5,$10 ; t,u,v,w
  Data.b 5,$20, 5,$40, 5,$80, 1,$20 ; x,y,z,[{]
  Data.b 1,$10, 1,$40, 2,$02, 8,$08 ; [|],[}],[~],DEL
  Data.b 10,$08, 10,$10             ; PAD8,PAD9
EndDataSection

; Set or reset an interrupt request
Procedure.u SetIRQ(IRQ.a)
  If IRQ & $80
    IRQPending & IRQ
  Else
    IRQPending | IRQ
  EndIf
  
  If IRQPending
    CPU\IRequest = #INT_IRQ
  Else
    CPU\IRequest = #INT_NONE
  EndIf
  ProcedureReturn CPU\IRequest
EndProcedure

; MSX main execution timer loop callback (called at each interrupt cycle)
Procedure.u MSXLoopZ80(*R.Z80)
  Static BFlag.a = 0
  Static BCount.a = 0
  Static UCount.l = 0
  Static ACount.a = 0
  Static Drawing.a = 0
  Protected J.l
  
  ; Flip HRefresh status bit (VDPStatus[2] bit 5)
  VDPStatus(2) = VDPStatus(2) ! $20
  
  ; Active drawing phase of scanline
  If (VDPStatus(2) & $20) = 0
    If ScrMode = 0
      *R\IPeriod = #CPU_H240
    Else
      *R\IPeriod = #CPU_H256
    EndIf
    
    Protected palVideo.a = 0
    If (Mode & #MSX_PAL) : palVideo = 1 : EndIf
    
    Protected maxLine.l = 261
    If palVideo : maxLine = 312 : EndIf
    
    If ScanLine < maxLine
      ScanLine + 1
    Else
      ScanLine = 0
    EndIf
    
    If ScanLine = 0
      Drawing = 1
      VDPStatus(2) = VDPStatus(2) & $BF ; Clear VRefresh status bit
      UCount + UPeriod
    EndIf
    
    Protected coinLine.l = 235
    If palVideo
      coinLine = 256
    ElseIf VDP(9) & $80
      coinLine = 245
    EndIf
    
    If ScanLine = coinLine
      VDPStatus(1) = VDPStatus(1) & $FE ; Clear line coincidence flag
      SetIRQ(~#INT_IE1)
    EndIf
    
    If ScanLine < coinLine
      ; Line coincidence check (using register 19)
      J = (((ScanLine + VDP(23)) & $FF) - VDP(19)) & $FF
      If J = 2
        VDPStatus(1) = VDPStatus(1) | $01 ; Set coincidence flag
        If VDP(0) & $10
          SetIRQ(#INT_IE1)
        EndIf
      Else
        If (VDP(0) & $10) = 0
          VDPStatus(1) = VDPStatus(1) & $FE
        EndIf
      EndIf
    EndIf
    
    *R\IRequest = SetIRQ($FF)
    ProcedureReturn *R\IRequest
  EndIf
  
  ; HBlank Phase of scanline
  Protected activePeriod.l
  If ScrMode = 0
    activePeriod = #CPU_H240
  Else
    activePeriod = #CPU_H256
  EndIf
  *R\IPeriod = #CPU_HPERIOD - activePeriod
  
  Protected displayEndLine.l = 192
  If VDP(9) & $80
    displayEndLine = 212
  EndIf
  If ScanLine = displayEndLine
    Drawing = 0
  EndIf
  
  Protected vblankStartLine.l = 192 + 28
  If VDP(9) & $80
    If (Mode & #MSX_PAL)
      vblankStartLine = 212 + 42
    Else
      vblankStartLine = 212 + 18
    EndIf
  Else
    If (Mode & #MSX_PAL)
      vblankStartLine = 192 + 52
    EndIf
  EndIf
  
  If Drawing = 0 And ScanLine = vblankStartLine
    VDPStatus(0) = VDPStatus(0) | $80 ; Set VBlank status bit
    VDPStatus(2) = VDPStatus(2) | $40 ; Set VRefresh status bit
    
    If VDP(1) & $20
      SetIRQ(#INT_IE0)
    EndIf
  EndIf
  
  *R\IRequest = SetIRQ($FF)
  ProcedureReturn *R\IRequest
EndProcedure
