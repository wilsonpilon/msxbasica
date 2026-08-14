; Z80 CPU Emulation Core for PureBasic
; Portable Z80 Emulator
; Translated from C source by Marat Fayzullin

; Flag Bits in AF Register
#S_FLAG = $80       ; 1: Result negative
#Z_FLAG = $40       ; 1: Result is zero
#H_FLAG = $10       ; 1: Halfcarry/Halfborrow
#P_FLAG = $04       ; 1: Result is even / Overflow occurred
#V_FLAG = $04       ; 1: Overflow occurred
#N_FLAG = $02       ; 1: Subtraction occurred
#C_FLAG = $01       ; 1: Carry/Borrow occurred

; LoopZ80() returns / Interrupt Vectors
#INT_RST00 = $00C7  ; RST 00h
#INT_RST08 = $00CF  ; RST 08h
#INT_RST10 = $00D7  ; RST 10h
#INT_RST18 = $00DF  ; RST 18h
#INT_RST20 = $00E7  ; RST 20h
#INT_RST28 = $00EF  ; RST 28h
#INT_RST30 = $00F7  ; RST 30h
#INT_RST38 = $00FF  ; RST 38h
#INT_IRQ   = #INT_RST38
#INT_NMI   = $FFFD  ; Non-maskable interrupt
#INT_NONE  = $FFFF  ; No interrupt required
#INT_QUIT  = $FFFE  ; Exit the emulation

; Bits in IFF flip-flops
#IFF_1    = $01     ; IFF1 flip-flop
#IFF_IM1  = $02     ; 1: IM1 mode
#IFF_IM2  = $04     ; 1: IM2 mode
#IFF_2    = $08     ; IFF2 flip-flop
#IFF_EI   = $20     ; 1: EI pending
#IFF_HALT = $80     ; 1: CPU HALTed

; Structure representing low/high bytes of a 16-bit register
Structure RegBytes
  l.a
  h.a
EndStructure

; Union for 16-bit registers with individual byte access (LSB first)
Structure RegisterPair
  StructureUnion
    W.u
    B.RegBytes
  EndStructureUnion
EndStructure

; Main Z80 CPU context structure
Structure Z80
  AF.RegisterPair
  BC.RegisterPair
  DE.RegisterPair
  HL.RegisterPair
  IX.RegisterPair
  IY.RegisterPair
  XX.RegisterPair
  PC.RegisterPair
  SP.RegisterPair
  
  AF1.RegisterPair ; Shadow registers
  BC1.RegisterPair
  DE1.RegisterPair
  HL1.RegisterPair
  
  IFF.a ; Interrupt status/IFF flip-flops
  I.a   ; Interrupt vector register
  R.a   ; Refresh register
  
  IPeriod.l   ; Cycles between LoopZ80() calls
  ICount.l    ; Cycles remaining
  IBackup.l   ; Backup cycle count (used during EI)
  IRequest.u  ; Vector of pending interrupt
  IAutoReset.a ; Auto-reset of IRequest flag
  TrapBadOps.a ; Set to 1 to debug bad/illegal opcodes
  Trap.u      ; Trace trap address
  Trace.a     ; Tracing on/off
  User.i      ; Arbitrary user pointer/integer (RAM index, ID, etc)
EndStructure

; --- Memory & I/O Callback Prototypes ---
Prototype.a RdZ80_Callback(Addr.u)
Prototype WrZ80_Callback(Addr.u, Value.a)
Prototype.a InZ80_Callback(Port.u)
Prototype OutZ80_Callback(Port.u, Value.a)
Prototype PatchZ80_Callback(*R.Z80)
Prototype.u LoopZ80_Callback(*R.Z80)
Prototype JumpZ80_Callback(PC.u)

; Global Callback pointers (to be set by the main emulator code)
Global RdZ80.RdZ80_Callback
Global WrZ80.WrZ80_Callback
Global InZ80.InZ80_Callback
Global OutZ80.OutZ80_Callback
Global PatchZ80.PatchZ80_Callback
Global LoopZ80.LoopZ80_Callback
Global JumpZ80.JumpZ80_Callback

; --- Internal Emulation Procedures/Macros ---

; Sign extend an 8-bit value to a 32-bit signed integer
Macro SignExtend8(Val)
  ( (Val) | ($FFFFFF00 * ((Val) >> 7)) )
EndMacro

; Basic CPU helpers
Macro S(Fl)
  *R\AF\B\l | (Fl)
EndMacro

Macro R(Fl)
  *R\AF\B\l & (~(Fl))
EndMacro

Macro FLAGS(Rg, Fl)
  *R\AF\B\l = (Fl) | PZSTable(Rg)
EndMacro

Macro INCR(N)
  *R\R = ((*R\R + (N)) & $7F) | (*R\R & $80)
EndMacro

Macro OpZ80(Addr)
  RdZ80(Addr)
EndMacro

Procedure.a ReadOp(*R.Z80)
  Protected val.a = RdZ80(*R\PC\W)
  *R\PC\W + 1
  ProcedureReturn val
EndProcedure

Procedure.a ReadPop(*R.Z80)
  Protected val.a = RdZ80(*R\SP\W)
  *R\SP\W + 1
  ProcedureReturn val
EndProcedure

; --- Translation Macros for Z80 Instructions ---

Macro M_RLC(Rg)
  *R\AF\B\l = (Rg) >> 7
  Rg = ((Rg) << 1) | *R\AF\B\l
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_RRC(Rg)
  *R\AF\B\l = (Rg) & $01
  Rg = ((Rg) >> 1) | (*R\AF\B\l << 7)
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_RL(Rg)
  If (Rg) & $80
    Rg = ((Rg) << 1) | (*R\AF\B\l & #C_FLAG)
    *R\AF\B\l = PZSTable(Rg) | #C_FLAG
  Else
    Rg = ((Rg) << 1) | (*R\AF\B\l & #C_FLAG)
    *R\AF\B\l = PZSTable(Rg)
  EndIf
EndMacro

Macro M_RR(Rg)
  If (Rg) & $01
    Rg = ((Rg) >> 1) | (*R\AF\B\l << 7)
    *R\AF\B\l = PZSTable(Rg) | #C_FLAG
  Else
    Rg = ((Rg) >> 1) | (*R\AF\B\l << 7)
    *R\AF\B\l = PZSTable(Rg)
  EndIf
EndMacro

Macro M_SLA(Rg)
  *R\AF\B\l = (Rg) >> 7
  Rg = (Rg) << 1
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_SRA(Rg)
  *R\AF\B\l = (Rg) & #C_FLAG
  Rg = ((Rg) >> 1) | ((Rg) & $80)
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_SLL(Rg)
  *R\AF\B\l = (Rg) >> 7
  Rg = ((Rg) << 1) | $01
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_SRL(Rg)
  *R\AF\B\l = (Rg) & $01
  Rg = (Rg) >> 1
  *R\AF\B\l | PZSTable(Rg)
EndMacro

Macro M_BIT(Bit, Rg)
  *R\AF\B\l = (*R\AF\B\l & #C_FLAG) | #H_FLAG | PZSTable((Rg) & (1 << (Bit)))
EndMacro

Macro M_SET(Bit, Rg)
  Rg = (Rg) | (1 << (Bit))
EndMacro

Macro M_RES(Bit, Rg)
  Rg = (Rg) & (~(1 << (Bit)))
EndMacro

Macro M_POP(Rg)
  *R\Rg#\B\l = ReadPop(*R)
  *R\Rg#\B\h = ReadPop(*R)
EndMacro

Macro M_PUSH(Rg)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\Rg#\B\h)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\Rg#\B\l)
EndMacro

Macro M_CALL
  J\B\l = ReadOp(*R)
  J\B\h = ReadOp(*R)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\PC\B\h)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\PC\B\l)
  *R\PC\W = J\W
  If JumpZ80 : JumpZ80(J\W) : EndIf
EndMacro

Macro M_JP
  J\B\l = ReadOp(*R)
  J\B\h = RdZ80(*R\PC\W)
  *R\PC\W = J\W
  If JumpZ80 : JumpZ80(J\W) : EndIf
EndMacro

Macro M_JR
  *R\PC\W + SignExtend8(RdZ80(*R\PC\W)) + 1
  If JumpZ80 : JumpZ80(*R\PC\W) : EndIf
EndMacro

Macro M_RET
  *R\PC\B\l = ReadPop(*R)
  *R\PC\B\h = ReadPop(*R)
  If JumpZ80 : JumpZ80(*R\PC\W) : EndIf
EndMacro

Macro M_RST(Ad)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\PC\B\h)
  *R\SP\W - 1 : WrZ80(*R\SP\W, *R\PC\B\l)
  *R\PC\W = Ad
  If JumpZ80 : JumpZ80(Ad) : EndIf
EndMacro

Macro M_LDWORD(Rg)
  *R\Rg#\B\l = ReadOp(*R)
  *R\Rg#\B\h = ReadOp(*R)
EndMacro

Macro M_ADD(Rg)
  J\W = *R\AF\B\h + (Rg)
  *R\AF\B\l = ZSTable(J\B\l) | J\B\h | ((*R\AF\B\h ! (Rg) ! J\B\l) & #H_FLAG)
  If (~(*R\AF\B\h ! (Rg)) & ((Rg) ! J\B\l) & $80)
    *R\AF\B\l | #V_FLAG
  EndIf
  *R\AF\B\h = J\B\l
EndMacro

Macro M_SUB(Rg)
  J\W = *R\AF\B\h - (Rg)
  *R\AF\B\l = ZSTable(J\B\l) | #N_FLAG | (J\B\h & #C_FLAG) | ((*R\AF\B\h ! (Rg) ! J\B\l) & #H_FLAG)
  If (((*R\AF\B\h ! (Rg)) & (*R\AF\B\h ! J\B\l) & $80))
    *R\AF\B\l | #V_FLAG
  EndIf
  *R\AF\B\h = J\B\l
EndMacro

Macro M_ADC(Rg)
  J\W = *R\AF\B\h + (Rg) + (*R\AF\B\l & #C_FLAG)
  *R\AF\B\l = ZSTable(J\B\l) | J\B\h | ((*R\AF\B\h ! (Rg) ! J\B\l) & #H_FLAG)
  If (~(*R\AF\B\h ! (Rg)) & ((Rg) ! J\B\l) & $80)
    *R\AF\B\l | #V_FLAG
  EndIf
  *R\AF\B\h = J\B\l
EndMacro

Macro M_SBC(Rg)
  J\W = *R\AF\B\h - (Rg) - (*R\AF\B\l & #C_FLAG)
  *R\AF\B\l = ZSTable(J\B\l) | #N_FLAG | (J\B\h & #C_FLAG) | ((*R\AF\B\h ! (Rg) ! J\B\l) & #H_FLAG)
  If (((*R\AF\B\h ! (Rg)) & (*R\AF\B\h ! J\B\l) & $80))
    *R\AF\B\l | #V_FLAG
  EndIf
  *R\AF\B\h = J\B\l
EndMacro

Macro M_CP(Rg)
  J\W = *R\AF\B\h - (Rg)
  *R\AF\B\l = ZSTable(J\B\l) | #N_FLAG | (J\B\h & #C_FLAG) | ((*R\AF\B\h ! (Rg) ! J\B\l) & #H_FLAG)
  If (((*R\AF\B\h ! (Rg)) & (*R\AF\B\h ! J\B\l) & $80))
    *R\AF\B\l | #V_FLAG
  EndIf
EndMacro

Macro M_AND(Rg)
  *R\AF\B\h & (Rg)
  *R\AF\B\l = #H_FLAG | PZSTable(*R\AF\B\h)
EndMacro

Macro M_OR(Rg)
  *R\AF\B\h | (Rg)
  *R\AF\B\l = PZSTable(*R\AF\B\h)
EndMacro

Macro M_XOR(Rg)
  *R\AF\B\h ! (Rg)
  *R\AF\B\l = PZSTable(*R\AF\B\h)
EndMacro

Macro M_IN(Rg)
  Rg = InZ80(*R\BC\W)
  *R\AF\B\l = PZSTable(Rg) | (*R\AF\B\l & #C_FLAG)
EndMacro

Macro M_INC(Rg)
  Rg + 1
  *R\AF\B\l = (*R\AF\B\l & #C_FLAG) | ZSTable(Rg)
  If Rg = $80
    *R\AF\B\l | #V_FLAG
  EndIf
  If (Rg & $0F) = 0
    *R\AF\B\l | #H_FLAG
  EndIf
EndMacro

Macro M_DEC(Rg)
  Rg - 1
  *R\AF\B\l = #N_FLAG | (*R\AF\B\l & #C_FLAG) | ZSTable(Rg)
  If Rg = $7F
    *R\AF\B\l | #V_FLAG
  EndIf
  If (Rg & $0F) = $0F
    *R\AF\B\l | #H_FLAG
  EndIf
EndMacro

Macro M_ADDW(Rg1, Rg2)
  J\W = (*R\Rg1#\W + *R\Rg2#\W) & $FFFF
  *R\AF\B\l & ~(#H_FLAG | #N_FLAG | #C_FLAG)
  If ((*R\Rg1#\W ! *R\Rg2#\W ! J\W) & $1000)
    *R\AF\B\l | #H_FLAG
  EndIf
  If (*R\Rg1#\W + *R\Rg2#\W) > $FFFF
    *R\AF\B\l | #C_FLAG
  EndIf
  *R\Rg1#\W = J\W
EndMacro

Macro M_ADCW(Rg)
  I = *R\AF\B\l & #C_FLAG
  J\W = (*R\HL\W + *R\Rg#\W + I) & $FFFF
  *R\AF\B\l = 0
  If (*R\HL\W + *R\Rg#\W + I) > $FFFF
    *R\AF\B\l | #C_FLAG
  EndIf
  If (~(*R\HL\W ! *R\Rg#\W) & (*R\Rg#\W ! J\W) & $8000)
    *R\AF\B\l | #V_FLAG
  EndIf
  If ((*R\HL\W ! *R\Rg#\W ! J\W) & $1000)
    *R\AF\B\l | #H_FLAG
  EndIf
  If J\W = 0
    *R\AF\B\l | #Z_FLAG
  EndIf
  *R\AF\B\l | (J\B\h & #S_FLAG)
  *R\HL\W = J\W
EndMacro

Macro M_SBCW(Rg)
  I = *R\AF\B\l & #C_FLAG
  J\W = (*R\HL\W - *R\Rg#\W - I) & $FFFF
  *R\AF\B\l = #N_FLAG
  If (*R\HL\W - *R\Rg#\W - I) < 0
    *R\AF\B\l | #C_FLAG
  EndIf
  If ((*R\HL\W ! *R\Rg#\W) & (*R\HL\W ! J\W) & $8000)
    *R\AF\B\l | #V_FLAG
  EndIf
  If ((*R\HL\W ! *R\Rg#\W ! J\W) & $1000)
    *R\AF\B\l | #H_FLAG
  EndIf
  If J\W = 0
    *R\AF\B\l | #Z_FLAG
  EndIf
  *R\AF\B\l | (J\B\h & #S_FLAG)
  *R\HL\W = J\W
EndMacro

; --- Prefix Opcode Decoders ---

Procedure CodesCB(*R.Z80)
  Protected I.a
  I = ReadOp(*R)
  *R\ICount - CyclesCB(I)
  INCR(1)
  Select I
    IncludeFile "Z80_CodesCB.pbi"
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: CB " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
EndProcedure

Procedure CodesDDCB(*R.Z80)
  Protected J.RegisterPair
  Protected I.a
  J\W = *R\IX\W + SignExtend8(ReadOp(*R))
  I = ReadOp(*R)
  *R\ICount - CyclesXXCB(I)
  Select I
    IncludeFile "Z80_CodesXCB.pbi"
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: DD CB " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
EndProcedure

Procedure CodesFDCB(*R.Z80)
  Protected J.RegisterPair
  Protected I.a
  J\W = *R\IY\W + SignExtend8(ReadOp(*R))
  I = ReadOp(*R)
  *R\ICount - CyclesXXCB(I)
  Select I
    IncludeFile "Z80_CodesXCB.pbi"
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: FD CB " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
EndProcedure

Procedure CodesED(*R.Z80)
  Protected I.a
  Protected J.RegisterPair
  I = ReadOp(*R)
  *R\ICount - CyclesED(I)
  INCR(1)
  Select I
    IncludeFile "Z80_CodesED.pbi"
    Case $ED : *R\PC\W - 1
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: ED " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
EndProcedure

Procedure CodesDD(*R.Z80)
  Protected I.a
  Protected J.RegisterPair
  *R\XX\W = *R\IX\W
  I = ReadOp(*R)
  *R\ICount - CyclesXX(I)
  INCR(1)
  Select I
    IncludeFile "Z80_CodesXX.pbi"
    Case $FD, $DD : *R\PC\W - 1
    Case $CB : CodesDDCB(*R)
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: DD " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
  *R\IX\W = *R\XX\W
EndProcedure

Procedure CodesFD(*R.Z80)
  Protected I.a
  Protected J.RegisterPair
  *R\XX\W = *R\IY\W
  I = ReadOp(*R)
  *R\ICount - CyclesXX(I)
  INCR(1)
  Select I
    IncludeFile "Z80_CodesXX.pbi"
    Case $FD, $DD : *R\PC\W - 1
    Case $CB : CodesFDCB(*R)
    Default:
      If *R\TrapBadOps
        Debug "Unrecognized instruction: FD " + Hex(I) + " at PC=" + Hex(*R\PC\W)
      EndIf
  EndSelect
  *R\IY\W = *R\XX\W
EndProcedure

; --- Public CPU API Functions ---

; Reset the CPU state
Procedure ResetZ80(*R.Z80)
  *R\PC\W     = $0000
  *R\SP\W     = $F000
  *R\AF\W     = $0000
  *R\BC\W     = $0000
  *R\DE\W     = $0000
  *R\HL\W     = $0000
  *R\AF1\W    = $0000
  *R\BC1\W    = $0000
  *R\DE1\W    = $0000
  *R\HL1\W    = $0000
  *R\IX\W     = $0000
  *R\IY\W     = $0000
  *R\I        = $00
  *R\R        = $00
  *R\IFF      = $00
  *R\ICount   = *R\IPeriod
  *R\IRequest = #INT_NONE
  *R\IBackup  = 0
  
  If JumpZ80 : JumpZ80(*R\PC\W) : EndIf
EndProcedure

; Trigger an Interrupt
Procedure IntZ80(*R.Z80, Vector.u)
  If *R\IFF & #IFF_HALT
    *R\PC\W + 1
    *R\IFF & ~#IFF_HALT
  EndIf
  
  If (*R\IFF & #IFF_1) Or (Vector = #INT_NMI)
    Protected J.RegisterPair
    J\W = *R\PC\W
    *R\SP\W - 1 : WrZ80(*R\SP\W, J\B\h)
    *R\SP\W - 1 : WrZ80(*R\SP\W, J\B\l)
    
    If *R\IAutoReset And (Vector = *R\IRequest)
      *R\IRequest = #INT_NONE
    EndIf
    
    If Vector = #INT_NMI
      *R\IFF & ~(#IFF_1 | #IFF_EI)
      *R\PC\W = $0066
      If JumpZ80 : JumpZ80($0066) : EndIf
      ProcedureReturn
    EndIf
    
    *R\IFF & ~(#IFF_1 | #IFF_2 | #IFF_EI)
    
    If *R\IFF & #IFF_IM2
      Vector = (Vector & $FF) | (*R\I << 8)
      *R\PC\B\l = RdZ80(Vector) : Vector + 1
      *R\PC\B\h = RdZ80(Vector)
      If JumpZ80 : JumpZ80(*R\PC\W) : EndIf
      ProcedureReturn
    EndIf
    
    If *R\IFF & #IFF_IM1
      *R\PC\W = $0038
      If JumpZ80 : JumpZ80($0038) : EndIf
      ProcedureReturn
    EndIf
    
    Select Vector
      Case #INT_RST00 : *R\PC\W = $0000 : If JumpZ80 : JumpZ80($0000) : EndIf
      Case #INT_RST08 : *R\PC\W = $0008 : If JumpZ80 : JumpZ80($0008) : EndIf
      Case #INT_RST10 : *R\PC\W = $0010 : If JumpZ80 : JumpZ80($0010) : EndIf
      Case #INT_RST18 : *R\PC\W = $0018 : If JumpZ80 : JumpZ80($0018) : EndIf
      Case #INT_RST20 : *R\PC\W = $0020 : If JumpZ80 : JumpZ80($0020) : EndIf
      Case #INT_RST28 : *R\PC\W = $0028 : If JumpZ80 : JumpZ80($0028) : EndIf
      Case #INT_RST30 : *R\PC\W = $0030 : If JumpZ80 : JumpZ80($0030) : EndIf
      Case #INT_RST38 : *R\PC\W = $0038 : If JumpZ80 : JumpZ80($0038) : EndIf
    EndSelect
  EndIf
EndProcedure

; Run the CPU emulation loop
Procedure.u RunZ80(*R.Z80)
  Protected I.a
  Protected J.RegisterPair
  
  Repeat
    I = ReadOp(*R)
    *R\ICount - Cycles(I)
    INCR(1)
    
    Select I
      Case $CB : CodesCB(*R)
      Case $ED : CodesED(*R)
      Case $DD : CodesDD(*R)
      Case $FD : CodesFD(*R)
      IncludeFile "Z80_Codes.pbi"
    EndSelect
    
    If *R\ICount <= 0
      If *R\IFF & #IFF_EI
        *R\IFF = (*R\IFF & ~#IFF_EI) | #IFF_1
        *R\ICount + *R\IBackup - 1
        
        If *R\ICount > 0
          J\W = *R\IRequest
        Else
          J\W = LoopZ80(*R)
          *R\ICount + *R\IPeriod
          If J\W = #INT_NONE
            J\W = *R\IRequest
          EndIf
        EndIf
      Else
        J\W = LoopZ80(*R)
        *R\ICount + *R\IPeriod
        If J\W = #INT_NONE
          J\W = *R\IRequest
        EndIf
      EndIf
      
      If J\W = #INT_QUIT
        ProcedureReturn *R\PC\W
      EndIf
      If J\W <> #INT_NONE
        IntZ80(*R, J\W)
      EndIf
    EndIf
  ForEver
  
  ProcedureReturn *R\PC\W
EndProcedure
