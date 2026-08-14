;
; ------------------------------------------------------------
;  Debugger visual Z80 (comando G do Mamute Assembler) - modulo 32 do
;  docs/SPEC.md, Fase 1: simulador Z80 puro (sem VDP/PSG/FDC/BIOS - chamadas
;  de sistema real nao sao simuladas). Layout inspirado no Konpass
;  (images/msxbasica-20.png, referencia pedida pelo usuario): disassembly a
;  esquerda, registradores/flags em cima a direita, minimonitor de memoria no
;  meio, pilha na coluna direita, PAGE/SLOT/TIPO abaixo do minimonitor
;  (sem linha MAPPER - MamutePageMap nao modela sub-slot/segmento de mapper).
;
;  Visual "terminal" preto/verde igual ao resto do Mamute (DM/ZAP/monitor) -
;  ignora Color_*/ThemedButton() de proposito, mesma decisao ja tomada em
;  MamuteAssemblerGui.pbi. Motor de execucao real fica em MamuteZ80Cpu.pbi
;  (Mz80_StepInto/StepOver/StepOut/Run/ResetToStart), incluido antes deste
;  arquivo.
;
;  Edicao: registradores/flags/breakpoints usam StringGadget/CheckBoxGadget
;  nativos + botao "Aplicar" (mais simples e robusto que replicar a edicao
;  por cursor do DM pra uma dezena de campos pequenos - simplificacao
;  consciente desta primeira leva). O minimonitor reaproveita a MESMA tecnica
;  de grade do DM (MamuteDumpGui.pbi) - clique numa celula abre um
;  InputRequester de 2 digitos hexa. A pilha (coluna direita) usa o mesmo
;  idioma - clique numa linha abre um InputRequester de 4 digitos (word de
;  16 bits, little-endian, igual PUSH/POP gravam).
;
;  Disassembly: por padrao acompanha o PC (checkbox "Seguir PC"); desmarcando
;  (ou clicando ^/v) rola independente em blocos de ~1 pagina de instrucoes -
;  ^ usa um deslocamento fixo de bytes (heuristica, pode desalinhar 1-2 linhas
;  ate resincronizar, mesma limitacao de qualquer scroll reverso sem
;  disassembly reverso de verdade), v usa o proximo endereco real calculado
;  pelo disassembler (sempre alinhado).
; ------------------------------------------------------------
;

#MamuteDebugger_Shortcut_StepInto = 9301
#MamuteDebugger_Shortcut_StepOver = 9302
#MamuteDebugger_Shortcut_StepOut  = 9303
#MamuteDebugger_Shortcut_Run      = 9304
#MamuteDebugger_Shortcut_Reset    = 9305
#MamuteDebugger_Shortcut_Escape   = 9306

Structure MamuteDebuggerState
  *CpuState.MamuteGui_State ; ponteiro pro MamuteGui_State da janela MON> que abriu o debugger
  MiniBase.i                ; endereco (0-65535) do minimonitor - independente do PC
  DisasmBase.i               ; endereco (0-65535) do topo do painel de disassembly
  FollowPC.b                 ; #True (padrao) = DisasmBase acompanha o PC a cada repaint
  StatusText.s
EndStructure

Procedure.s Mdbg_FlagChar(F.a, Mask.a, OnChar.s, OffChar.s)
  If F & Mask
    ProcedureReturn OnChar
  EndIf
  ProcedureReturn OffChar
EndProcedure

Procedure.s Mdbg_PageTypeName(Tipo.b)
  Select Tipo
    Case #MamuteMem_RAM   : ProcedureReturn "RAM"
    Case #MamuteMem_ROM   : ProcedureReturn "ROM"
    Case #MamuteMem_Basic : ProcedureReturn "BASIC"
    Default               : ProcedureReturn "VAZIO"
  EndSelect
EndProcedure

Procedure Mdbg_DrawButton(Canvas, Label.s, Font)
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf
  Protected W = GadgetWidth(Canvas), H = GadgetHeight(Canvas)
  Box(0, 0, W, H, RGB(0, 45, 18))
  DrawingMode(#PB_2DDrawing_Outlined)
  Box(0, 0, W, H, RGB(60, 220, 90))
  DrawingMode(#PB_2DDrawing_Transparent)
  DrawingFont(FontID(Font))
  Protected TW = TextWidth(Label), TH = TextHeight(Label)
  DrawText((W - TW) / 2, (H - TH) / 2, Label, RGB(60, 220, 90))
  StopDrawing()
EndProcedure

; Encadeia Mamute_DisasmBuildLines (10 instrucoes por chamada) ate ter pelo
; menos MinLines linhas ou dar 4 voltas (protecao contra loop, nao deveria
; acontecer) - devolve o proximo endereco livre em *OutNext.
Procedure Mdbg_BuildDisasmLines(List OutLines.s(), StartAddr.i, MinLines.i, *OutNext.Integer)
  ClearList(OutLines())
  Protected Cur.i = StartAddr & $FFFF
  Protected Rounds.i = 0
  Protected NewList Chunk.s()
  Protected NextA.i
  While ListSize(OutLines()) < MinLines And Rounds < 4
    ClearList(Chunk())
    Mamute_DisasmBuildLines(Chunk(), Cur, #False, 0, @NextA)
    ForEach Chunk()
      AddElement(OutLines())
      OutLines() = Chunk()
    Next
    Cur = NextA
    Rounds + 1
  Wend
  *OutNext\i = Cur
EndProcedure

Procedure Mdbg_RepaintDisasm(Canvas, *State.MamuteDebuggerState, Font.i)
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf
  Protected ColBack = RGB(0, 0, 0), ColFront = RGB(60, 220, 90), ColCur = RGB(0, 0, 0)
  Protected ColCurBack = RGB(60, 220, 90)
  DrawingFont(FontID(Font))
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColBack)

  Protected RowH = TextHeight("0") + 4
  Protected VisibleRows.i = GadgetHeight(Canvas) / RowH

  Protected NewList Lines.s()
  Protected NextAddr.i
  Mdbg_BuildDisasmLines(Lines(), *State\DisasmBase, VisibleRows + 2, @NextAddr)

  Protected Row.i = 0
  Protected CurPC.u = *State\CpuState\RegPC
  ForEach Lines()
    If Row >= VisibleRows
      Break
    EndIf
    Protected LineAddr.i = Val("$" + Left(Lines(), 4))
    If LineAddr = CurPC
      Box(0, Row * RowH, GadgetWidth(Canvas), RowH, ColCurBack)
      DrawText(2, Row * RowH, Lines(), ColCur, ColCurBack)
    Else
      DrawText(2, Row * RowH, Lines(), ColFront, ColBack)
    EndIf
    Row + 1
  Next

  DrawingMode(#PB_2DDrawing_Outlined)
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColFront)
  StopDrawing()
EndProcedure

Procedure Mdbg_RepaintMiniGrid(Canvas, *State.MamuteDebuggerState, Font.i)
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf
  Protected ColBack = RGB(0, 0, 0), ColFront = RGB(60, 220, 90), ColDim = RGB(25, 110, 50)
  DrawingFont(FontID(Font))
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColBack)

  Protected CharW = TextWidth("00"), CharH = TextHeight("0") + 4
  Protected AddrW = TextWidth("0000: ")
  Protected HalfCharW = CharW / 2
  Protected AsciiX = AddrW + 8 * HalfCharW * 3 + 12

  Protected r.i, c.i, RowAddr.i, ByteAddr.i, RawByte.a, bx.i, ax.i, RowY.i
  For r = 0 To 7
    RowY = r * CharH
    RowAddr = (*State\MiniBase + r * 8) & $FFFF
    DrawText(0, RowY, Mamute_Hex4(RowAddr) + ":", ColDim, ColBack)
    For c = 0 To 7
      ByteAddr = (*State\MiniBase + r * 8 + c) & $FFFF
      RawByte = Mamute_ReadByte(ByteAddr)
      bx = AddrW + c * HalfCharW * 3
      DrawText(bx, RowY, Mamute_Hex2(RawByte), ColFront, ColBack)
    Next
    For c = 0 To 7
      ByteAddr = (*State\MiniBase + r * 8 + c) & $FFFF
      RawByte = Mamute_ReadByte(ByteAddr)
      ax = AsciiX + c * HalfCharW
      Protected DispChar.s = "."
      If RawByte >= 32 And RawByte <= 126 : DispChar = Chr(RawByte) : EndIf
      DrawText(ax, RowY, DispChar, ColFront, ColBack)
    Next
  Next

  DrawingMode(#PB_2DDrawing_Outlined)
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColFront)
  StopDrawing()
EndProcedure

Procedure.b Mdbg_MiniHitTest(MouseX.i, MouseY.i, Font.i, *OutRow.Integer, *OutCol.Integer)
  Protected Img = CreateImage(#PB_Any, 10, 10)
  Protected CharW, CharH
  If Img And StartDrawing(ImageOutput(Img))
    DrawingFont(FontID(Font))
    CharW = TextWidth("00")
    CharH = TextHeight("0") + 4
    StopDrawing()
  EndIf
  If Img : FreeImage(Img) : EndIf
  If CharW <= 0 : CharW = 18 : EndIf
  If CharH <= 0 : CharH = 20 : EndIf
  Protected HalfCharW = CharW / 2
  Protected AddrW = CharW * 3 + HalfCharW ; aprox. de "0000: " no mesmo font

  Protected Row.i = MouseY / CharH
  If Row < 0 Or Row > 7
    ProcedureReturn #False
  EndIf
  Protected c.i, bx.i
  For c = 0 To 7
    bx = AddrW + c * HalfCharW * 3
    If MouseX >= bx - 2 And MouseX < bx + CharW
      *OutRow\i = Row : *OutCol\i = c
      ProcedureReturn #True
    EndIf
  Next
  ProcedureReturn #False
EndProcedure

Procedure Mdbg_RepaintStack(Canvas, *State.MamuteDebuggerState, Font.i)
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf
  Protected ColBack = RGB(0, 0, 0), ColFront = RGB(60, 220, 90)
  Protected ColCur = RGB(0, 0, 0), ColCurBack = RGB(60, 220, 90)
  DrawingFont(FontID(Font))
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColBack)

  Protected RowH = TextHeight("0") + 4
  Protected SP.u = *State\CpuState\RegSP
  Protected i.i, Addr.u, Lo.a, Hi.a, Row.i = 0
  For i = -8 To 16
    Addr = (SP + i * 2) & $FFFF
    Lo = Mamute_ReadByte(Addr)
    Hi = Mamute_ReadByte((Addr + 1) & $FFFF)
    Protected Line.s = Mamute_Hex4(Addr) + ": " + Mamute_Hex4((Hi << 8) | Lo)
    If Addr = SP
      Box(0, Row * RowH, GadgetWidth(Canvas), RowH, ColCurBack)
      DrawText(2, Row * RowH, Line + " <SP", ColCur, ColCurBack)
    Else
      DrawText(2, Row * RowH, Line, ColFront, ColBack)
    EndIf
    Row + 1
  Next

  DrawingMode(#PB_2DDrawing_Outlined)
  Box(0, 0, GadgetWidth(Canvas), GadgetHeight(Canvas), ColFront)
  StopDrawing()
EndProcedure

Procedure Mdbg_UpdateRegFields(*S.MamuteGui_State, G_AF, G_BC, G_DE, G_HL, G_AF2, G_BC2, G_DE2, G_HL2,
                               G_IX, G_IY, G_SP, G_PC, G_I, G_R, G_IM, G_IFF1, G_IFF2, G_Halted,
                               G_FlagS, G_FlagZ, G_FlagY, G_FlagH, G_FlagX, G_FlagPV, G_FlagN, G_FlagC)
  SetGadgetText(G_AF,  Mamute_Hex4(Mz80_GetAF(*S)))
  SetGadgetText(G_BC,  Mamute_Hex4(Mz80_GetBC(*S)))
  SetGadgetText(G_DE,  Mamute_Hex4(Mz80_GetDE(*S)))
  SetGadgetText(G_HL,  Mamute_Hex4(Mz80_GetHL(*S)))
  SetGadgetText(G_AF2, Mamute_Hex4((*S\RegA2 << 8) | *S\RegF2))
  SetGadgetText(G_BC2, Mamute_Hex4((*S\RegB2 << 8) | *S\RegC2))
  SetGadgetText(G_DE2, Mamute_Hex4((*S\RegD2 << 8) | *S\RegE2))
  SetGadgetText(G_HL2, Mamute_Hex4((*S\RegH2 << 8) | *S\RegL2))
  SetGadgetText(G_IX,  Mamute_Hex4(*S\RegIX))
  SetGadgetText(G_IY,  Mamute_Hex4(*S\RegIY))
  SetGadgetText(G_SP,  Mamute_Hex4(*S\RegSP))
  SetGadgetText(G_PC,  Mamute_Hex4(*S\RegPC))
  SetGadgetText(G_I,   Mamute_Hex2(*S\RegI))
  SetGadgetText(G_R,   Mamute_Hex2(*S\RegR))
  SetGadgetText(G_IM,  Str(*S\IM))
  SetGadgetState(G_IFF1, *S\IFF1)
  SetGadgetState(G_IFF2, *S\IFF2)
  If *S\Halted
    SetGadgetText(G_Halted, "HALT")
  Else
    SetGadgetText(G_Halted, "")
  EndIf
  SetGadgetState(G_FlagS,  Bool(*S\RegF & #Mz80_FS))
  SetGadgetState(G_FlagZ,  Bool(*S\RegF & #Mz80_FZ))
  SetGadgetState(G_FlagY,  Bool(*S\RegF & #Mz80_FY))
  SetGadgetState(G_FlagH,  Bool(*S\RegF & #Mz80_FH))
  SetGadgetState(G_FlagX,  Bool(*S\RegF & #Mz80_FX))
  SetGadgetState(G_FlagPV, Bool(*S\RegF & #Mz80_FPV))
  SetGadgetState(G_FlagN,  Bool(*S\RegF & #Mz80_FN))
  SetGadgetState(G_FlagC,  Bool(*S\RegF & #Mz80_FC))
EndProcedure

Procedure MamuteDebugger_Open(ParentWindow, *CpuState.MamuteGui_State, StartAddr.u)
  Protected DbgState.MamuteDebuggerState
  DbgState\CpuState = *CpuState
  DbgState\MiniBase = StartAddr & $FFFF
  DbgState\StatusText = "PRONTO"

  Mz80_ResetToStart(*CpuState, StartAddr & $FFFF)

  Protected DbgStyle.i = 0
  If MamuteFontBold : DbgStyle = #PB_Font_Bold : EndIf
  Protected DbgFont = LoadFont(#PB_Any, MamuteFontName, MamuteFontSize - 2, DbgStyle)
  If Not DbgFont
    DbgFont = LoadFont(#PB_Any, "Consolas", 13, #PB_Font_Bold)
  EndIf
  Protected UiFont = LoadFont(#PB_Any, MamuteFontName, 12, DbgStyle)
  If Not UiFont
    UiFont = LoadFont(#PB_Any, "Consolas", 12, #PB_Font_Bold)
  EndIf

  Protected WinW = 1180, WinH = 820
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Mamute Assembler - Debugger (G)",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered, #True, #False)
  If Not Win
    ProcedureReturn
  EndIf
  SetWindowColor(Win, RGB(0, 0, 0))

  Protected ColFront = RGB(60, 220, 90), ColBack = RGB(0, 0, 0)
  Protected LblW = 26, FldW = 44, FldH = 20, RowGap = 26
  Protected CurX, CurY = 8

  ; --- Registradores (linhas 1-3: AF/BC/DE/HL, AF'/BC'/DE'/HL', IX/IY/SP/PC) ---
  Protected RegNames.s = "AF|BC|DE|HL|AF'|BC'|DE'|HL'|IX|IY|SP|PC"
  Protected G_AF, G_BC, G_DE, G_HL, G_AF2, G_BC2, G_DE2, G_HL2, G_IX, G_IY, G_SP, G_PC
  Protected Dim RegHandles.i(11)
  Protected RegIdx.i
  For RegIdx = 0 To 11
    If RegIdx % 4 = 0
      CurX = 8
      If RegIdx > 0 : CurY + RowGap : EndIf
    EndIf
    Protected RName.s = StringField(RegNames, RegIdx + 1, "|")
    Protected G_Lbl = TextGadget(#PB_Any, CurX, CurY + 2, LblW + 8, FldH, RName)
    SetGadgetColor(G_Lbl, #PB_Gadget_FrontColor, ColFront)
    SetGadgetColor(G_Lbl, #PB_Gadget_BackColor, ColBack)
    SetGadgetFont(G_Lbl, FontID(UiFont))
    CurX + LblW + 8
    RegHandles(RegIdx) = StringGadget(#PB_Any, CurX, CurY, FldW, FldH, "0000", #PB_String_UpperCase)
    SetGadgetColor(RegHandles(RegIdx), #PB_Gadget_FrontColor, ColFront)
    SetGadgetColor(RegHandles(RegIdx), #PB_Gadget_BackColor, ColBack)
    SetGadgetFont(RegHandles(RegIdx), FontID(UiFont))
    CurX + FldW + 10
  Next
  G_AF = RegHandles(0) : G_BC = RegHandles(1) : G_DE = RegHandles(2) : G_HL = RegHandles(3)
  G_AF2 = RegHandles(4) : G_BC2 = RegHandles(5) : G_DE2 = RegHandles(6) : G_HL2 = RegHandles(7)
  G_IX = RegHandles(8) : G_IY = RegHandles(9) : G_SP = RegHandles(10) : G_PC = RegHandles(11)
  CurY + RowGap + 4

  ; --- I / R / IM / IFF1 / IFF2 / HALT ---
  CurX = 8
  Protected G_LblI = TextGadget(#PB_Any, CurX, CurY + 2, 20, FldH, "I")
  SetGadgetColor(G_LblI, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_LblI, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_LblI, FontID(UiFont))
  CurX + 22
  Protected G_I = StringGadget(#PB_Any, CurX, CurY, 34, FldH, "00", #PB_String_UpperCase)
  SetGadgetColor(G_I, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_I, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_I, FontID(UiFont))
  CurX + 44
  Protected G_LblR = TextGadget(#PB_Any, CurX, CurY + 2, 20, FldH, "R")
  SetGadgetColor(G_LblR, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_LblR, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_LblR, FontID(UiFont))
  CurX + 22
  Protected G_R = StringGadget(#PB_Any, CurX, CurY, 34, FldH, "00", #PB_String_UpperCase)
  SetGadgetColor(G_R, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_R, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_R, FontID(UiFont))
  CurX + 44
  Protected G_LblIM = TextGadget(#PB_Any, CurX, CurY + 2, 26, FldH, "IM")
  SetGadgetColor(G_LblIM, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_LblIM, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_LblIM, FontID(UiFont))
  CurX + 28
  Protected G_IM = StringGadget(#PB_Any, CurX, CurY, 26, FldH, "0")
  SetGadgetColor(G_IM, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_IM, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_IM, FontID(UiFont))
  CurX + 36
  Protected G_IFF1 = CheckBoxGadget(#PB_Any, CurX, CurY + 2, 60, FldH, "IFF1")
  SetGadgetFont(G_IFF1, FontID(UiFont))
  CurX + 64
  Protected G_IFF2 = CheckBoxGadget(#PB_Any, CurX, CurY + 2, 60, FldH, "IFF2")
  SetGadgetFont(G_IFF2, FontID(UiFont))
  CurX + 64
  Protected G_Halted = TextGadget(#PB_Any, CurX, CurY + 2, 60, FldH, "")
  SetGadgetColor(G_Halted, #PB_Gadget_FrontColor, RGB(255, 90, 90)) : SetGadgetColor(G_Halted, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Halted, FontID(UiFont))
  CurY + RowGap

  ; --- Flags ---
  CurX = 8
  Protected FlagNames.s = "S|Z|F5|H|F3|PV|N|C"
  Protected Dim FlagHandles.i(7)
  Protected FlagIdx.i
  For FlagIdx = 0 To 7
    FlagHandles(FlagIdx) = CheckBoxGadget(#PB_Any, CurX, CurY + 2, 50, FldH, StringField(FlagNames, FlagIdx + 1, "|"))
    SetGadgetFont(FlagHandles(FlagIdx), FontID(UiFont))
    CurX + 54
  Next
  Protected G_FlagS = FlagHandles(0) : Protected G_FlagZ = FlagHandles(1)
  Protected G_FlagY = FlagHandles(2) : Protected G_FlagH = FlagHandles(3)
  Protected G_FlagX = FlagHandles(4) : Protected G_FlagPV = FlagHandles(5)
  Protected G_FlagN = FlagHandles(6) : Protected G_FlagC = FlagHandles(7)
  CurY + RowGap

  ; --- Breakpoints ---
  CurX = 8
  Protected G_LblBP1 = TextGadget(#PB_Any, CurX, CurY + 2, 30, FldH, "BP1")
  SetGadgetColor(G_LblBP1, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_LblBP1, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_LblBP1, FontID(UiFont))
  CurX + 34
  Protected G_BP1 = StringGadget(#PB_Any, CurX, CurY, FldW, FldH, Mamute_Hex4(*CpuState\Break1Addr), #PB_String_UpperCase)
  SetGadgetColor(G_BP1, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_BP1, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_BP1, FontID(UiFont))
  CurX + FldW + 6
  Protected G_BP1On = CheckBoxGadget(#PB_Any, CurX, CurY + 2, 60, FldH, "ativo")
  SetGadgetFont(G_BP1On, FontID(UiFont))
  SetGadgetState(G_BP1On, *CpuState\HasBreak1)
  CurX + 70
  Protected G_LblBP2 = TextGadget(#PB_Any, CurX, CurY + 2, 30, FldH, "BP2")
  SetGadgetColor(G_LblBP2, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_LblBP2, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_LblBP2, FontID(UiFont))
  CurX + 34
  Protected G_BP2 = StringGadget(#PB_Any, CurX, CurY, FldW, FldH, Mamute_Hex4(*CpuState\Break2Addr), #PB_String_UpperCase)
  SetGadgetColor(G_BP2, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_BP2, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_BP2, FontID(UiFont))
  CurX + FldW + 6
  Protected G_BP2On = CheckBoxGadget(#PB_Any, CurX, CurY + 2, 60, FldH, "ativo")
  SetGadgetFont(G_BP2On, FontID(UiFont))
  SetGadgetState(G_BP2On, *CpuState\HasBreak2)
  CurX + 90
  Protected G_Apply = ButtonGadget(#PB_Any, CurX, CurY, 190, FldH + 4, "Aplicar regs/flags/BP")
  CurY + RowGap + 6

  Protected TopBlockY = CurY

  ; --- Coluna esquerda: disassembly ---
  Protected G_DisasmLbl = TextGadget(#PB_Any, 8, TopBlockY, 130, 18, "Disassembly")
  SetGadgetColor(G_DisasmLbl, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_DisasmLbl, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_DisasmLbl, FontID(UiFont))
  Protected G_FollowPC = CheckBoxGadget(#PB_Any, 140, TopBlockY - 2, 90, 18, "Seguir PC")
  SetGadgetFont(G_FollowPC, FontID(UiFont))
  SetGadgetState(G_FollowPC, #True)
  Protected G_DisasmUp = ButtonGadget(#PB_Any, 232, TopBlockY - 2, 30, 20, "^")
  Protected G_DisasmDown = ButtonGadget(#PB_Any, 264, TopBlockY - 2, 30, 20, "v")
  Protected G_Disasm = CanvasGadget(#PB_Any, 8, TopBlockY + 20, 370, 420)

  ; --- Coluna do meio: minimonitor + PAGE/SLOT/TIPO ---
  Protected MidX = 388
  Protected G_MiniLbl = TextGadget(#PB_Any, MidX, TopBlockY, 60, 18, "Endereco:")
  SetGadgetColor(G_MiniLbl, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_MiniLbl, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_MiniLbl, FontID(UiFont))
  Protected G_MiniAddr = StringGadget(#PB_Any, MidX + 64, TopBlockY - 2, 60, FldH, Mamute_Hex4(DbgState\MiniBase), #PB_String_UpperCase)
  SetGadgetColor(G_MiniAddr, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_MiniAddr, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_MiniAddr, FontID(UiFont))
  Protected G_MiniGo = ButtonGadget(#PB_Any, MidX + 128, TopBlockY - 2, 40, FldH, "Ir")
  Protected G_MiniPrev = ButtonGadget(#PB_Any, MidX + 172, TopBlockY - 2, 30, FldH, "<<")
  Protected G_MiniNext = ButtonGadget(#PB_Any, MidX + 204, TopBlockY - 2, 30, FldH, ">>")
  Protected G_MiniGrid = CanvasGadget(#PB_Any, MidX, TopBlockY + 24, 280, 170)

  Protected PsY = TopBlockY + 204
  Protected G_PsLbl = TextGadget(#PB_Any, MidX, PsY, 260, 18, "PAGE -> SLOT (TIPO)")
  SetGadgetColor(G_PsLbl, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_PsLbl, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_PsLbl, FontID(UiFont))
  Protected Dim G_PageSlot.i(3)
  Protected pIdx.i
  For pIdx = 0 To 3
    G_PageSlot(pIdx) = TextGadget(#PB_Any, MidX, PsY + 20 + pIdx * 20, 260, 18, "")
    SetGadgetColor(G_PageSlot(pIdx), #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_PageSlot(pIdx), #PB_Gadget_BackColor, ColBack)
    SetGadgetFont(G_PageSlot(pIdx), FontID(UiFont))
  Next

  ; --- Coluna direita: pilha ---
  Protected RightX = 760
  Protected G_StackLbl = TextGadget(#PB_Any, RightX, TopBlockY, 100, 18, "Stack (SP)")
  SetGadgetColor(G_StackLbl, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_StackLbl, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_StackLbl, FontID(UiFont))
  Protected G_Stack = CanvasGadget(#PB_Any, RightX, TopBlockY + 20, WinW - RightX - 8, 420)

  ; --- Botoes de execucao ---
  Protected BtnY = TopBlockY + 452
  Protected BtnW = 165, BtnH = 38, BtnGap = 12
  CurX = 8
  Protected G_StepInto = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH) : CurX + BtnW + BtnGap
  Protected G_StepOver = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH) : CurX + BtnW + BtnGap
  Protected G_StepOut  = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH) : CurX + BtnW + BtnGap
  Protected G_Run      = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH) : CurX + BtnW + BtnGap
  Protected G_Reset    = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH) : CurX + BtnW + BtnGap
  Protected G_Close    = CanvasGadget(#PB_Any, CurX, BtnY, BtnW, BtnH)

  Mdbg_DrawButton(G_StepInto, "Step Into (F7)", UiFont)
  Mdbg_DrawButton(G_StepOver, "Step Over (F8)", UiFont)
  Mdbg_DrawButton(G_StepOut,  "Step Out (F9)", UiFont)
  Mdbg_DrawButton(G_Run,      "Run (F5)", UiFont)
  Mdbg_DrawButton(G_Reset,    "Reset", UiFont)
  Mdbg_DrawButton(G_Close,    "Fechar (Esc)", UiFont)

  Protected StatusY = BtnY + BtnH + 8
  Protected G_Status = TextGadget(#PB_Any, 8, StatusY, WinW - 16, 20, DbgState\StatusText)
  SetGadgetColor(G_Status, #PB_Gadget_FrontColor, ColFront) : SetGadgetColor(G_Status, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Status, FontID(UiFont))

  AddKeyboardShortcut(Win, #PB_Shortcut_F7, #MamuteDebugger_Shortcut_StepInto)
  AddKeyboardShortcut(Win, #PB_Shortcut_F8, #MamuteDebugger_Shortcut_StepOver)
  AddKeyboardShortcut(Win, #PB_Shortcut_F9, #MamuteDebugger_Shortcut_StepOut)
  AddKeyboardShortcut(Win, #PB_Shortcut_F5, #MamuteDebugger_Shortcut_Run)
  AddKeyboardShortcut(Win, #PB_Shortcut_Escape, #MamuteDebugger_Shortcut_Escape)

  Protected FullRepaint
  FullRepaint = 1

  Repeat
    If FullRepaint
      Mdbg_UpdateRegFields(*CpuState, G_AF, G_BC, G_DE, G_HL, G_AF2, G_BC2, G_DE2, G_HL2,
                           G_IX, G_IY, G_SP, G_PC, G_I, G_R, G_IM, G_IFF1, G_IFF2, G_Halted,
                           G_FlagS, G_FlagZ, G_FlagY, G_FlagH, G_FlagX, G_FlagPV, G_FlagN, G_FlagC)
      DbgState\FollowPC = GetGadgetState(G_FollowPC)
      If DbgState\FollowPC
        DbgState\DisasmBase = *CpuState\RegPC
      EndIf
      Mdbg_RepaintDisasm(G_Disasm, @DbgState, DbgFont)
      Mdbg_RepaintMiniGrid(G_MiniGrid, @DbgState, DbgFont)
      Mdbg_RepaintStack(G_Stack, @DbgState, DbgFont)
      Protected pgIdx.i
      For pgIdx = 0 To 3
        Protected SlotHere.i = MamutePageMap(pgIdx)
        SetGadgetText(G_PageSlot(pgIdx), "PAGINA " + Str(pgIdx) + ": SLOT " + Str(SlotHere) +
          " (" + Mdbg_PageTypeName(MamuteCfgCell(SlotHere, pgIdx)\Tipo) + ")")
      Next
      SetGadgetText(G_Status, DbgState\StatusText)
      FullRepaint = 0
    EndIf

    Protected Ev = WaitWindowEvent()
    Select Ev
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_Apply
            Protected VAF.i, VBC.i, VDE.i, VHL.i, VAF2.i, VBC2.i, VDE2.i, VHL2.i
            Protected VIX.i, VIY.i, VSP.i, VPC.i, VI.i, VR.i, VIM.i, VBP1.i, VBP2.i
            If Mamute_ParseHexAddr(GetGadgetText(G_AF), @VAF)  : Mz80_SetAF(*CpuState, VAF)  : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_BC), @VBC)  : Mz80_SetBC(*CpuState, VBC)  : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_DE), @VDE)  : Mz80_SetDE(*CpuState, VDE)  : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_HL), @VHL)  : Mz80_SetHL(*CpuState, VHL)  : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_AF2), @VAF2)
              *CpuState\RegA2 = (VAF2 >> 8) & $FF : *CpuState\RegF2 = VAF2 & $FF
            EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_BC2), @VBC2)
              *CpuState\RegB2 = (VBC2 >> 8) & $FF : *CpuState\RegC2 = VBC2 & $FF
            EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_DE2), @VDE2)
              *CpuState\RegD2 = (VDE2 >> 8) & $FF : *CpuState\RegE2 = VDE2 & $FF
            EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_HL2), @VHL2)
              *CpuState\RegH2 = (VHL2 >> 8) & $FF : *CpuState\RegL2 = VHL2 & $FF
            EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_IX), @VIX) : *CpuState\RegIX = VIX : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_IY), @VIY) : *CpuState\RegIY = VIY : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_SP), @VSP) : *CpuState\RegSP = VSP : EndIf
            If Mamute_ParseHexAddr(GetGadgetText(G_PC), @VPC) : *CpuState\RegPC = VPC : EndIf
            If Mamute_IsHexString(GetGadgetText(G_I), 2) : *CpuState\RegI = Val("$" + GetGadgetText(G_I)) : EndIf
            If Mamute_IsHexString(GetGadgetText(G_R), 2) : *CpuState\RegR = Val("$" + GetGadgetText(G_R)) : EndIf
            VIM = Val(GetGadgetText(G_IM))
            If VIM >= 0 And VIM <= 2 : *CpuState\IM = VIM : EndIf
            *CpuState\IFF1 = GetGadgetState(G_IFF1)
            *CpuState\IFF2 = GetGadgetState(G_IFF2)

            Protected NewF.a = 0
            If GetGadgetState(G_FlagS)  : NewF = NewF | #Mz80_FS  : EndIf
            If GetGadgetState(G_FlagZ)  : NewF = NewF | #Mz80_FZ  : EndIf
            If GetGadgetState(G_FlagY)  : NewF = NewF | #Mz80_FY  : EndIf
            If GetGadgetState(G_FlagH)  : NewF = NewF | #Mz80_FH  : EndIf
            If GetGadgetState(G_FlagX)  : NewF = NewF | #Mz80_FX  : EndIf
            If GetGadgetState(G_FlagPV) : NewF = NewF | #Mz80_FPV : EndIf
            If GetGadgetState(G_FlagN)  : NewF = NewF | #Mz80_FN  : EndIf
            If GetGadgetState(G_FlagC)  : NewF = NewF | #Mz80_FC  : EndIf
            *CpuState\RegF = NewF

            *CpuState\HasBreak1 = GetGadgetState(G_BP1On)
            If Mamute_ParseHexAddr(GetGadgetText(G_BP1), @VBP1) : *CpuState\Break1Addr = VBP1 : EndIf
            *CpuState\HasBreak2 = GetGadgetState(G_BP2On)
            If Mamute_ParseHexAddr(GetGadgetText(G_BP2), @VBP2) : *CpuState\Break2Addr = VBP2 : EndIf

            DbgState\StatusText = "REGISTRADORES/FLAGS/BREAKPOINTS APLICADOS"
            FullRepaint = 1

          Case G_FollowPC
            FullRepaint = 1

          Case G_DisasmUp
            SetGadgetState(G_FollowPC, #False)
            DbgState\DisasmBase = (DbgState\DisasmBase - 32) & $FFFF
            FullRepaint = 1

          Case G_DisasmDown
            SetGadgetState(G_FollowPC, #False)
            Protected NewList DisasmPageLines.s()
            Protected DisasmNextAddr.i
            Mdbg_BuildDisasmLines(DisasmPageLines(), DbgState\DisasmBase, 20, @DisasmNextAddr)
            DbgState\DisasmBase = DisasmNextAddr
            FullRepaint = 1

          Case G_MiniGo
            Protected VMini.i
            If Mamute_ParseHexAddr(GetGadgetText(G_MiniAddr), @VMini)
              DbgState\MiniBase = VMini
              FullRepaint = 1
            EndIf

          Case G_MiniPrev
            DbgState\MiniBase = (DbgState\MiniBase - 64) & $FFFF
            SetGadgetText(G_MiniAddr, Mamute_Hex4(DbgState\MiniBase))
            FullRepaint = 1

          Case G_MiniNext
            DbgState\MiniBase = (DbgState\MiniBase + 64) & $FFFF
            SetGadgetText(G_MiniAddr, Mamute_Hex4(DbgState\MiniBase))
            FullRepaint = 1

          Case G_MiniGrid
            If EventType() = #PB_EventType_LeftButtonDown
              Protected HitRow.i, HitCol.i
              If Mdbg_MiniHitTest(GetGadgetAttribute(G_MiniGrid, #PB_Canvas_MouseX), GetGadgetAttribute(G_MiniGrid, #PB_Canvas_MouseY),
                                  DbgFont, @HitRow, @HitCol)
                Protected HitAddr.i = (DbgState\MiniBase + HitRow * 8 + HitCol) & $FFFF
                Protected CurVal.s = Mamute_Hex2(Mamute_ReadByte(HitAddr))
                Protected NewVal.s = InputRequester("Editar byte " + Mamute_Hex4(HitAddr), "Novo valor (hexa, 2 digitos):", CurVal)
                If NewVal <> "" And Mamute_IsHexString(NewVal, 2)
                  Mamute_WriteByte(HitAddr, Val("$" + NewVal))
                  FullRepaint = 1
                EndIf
              EndIf
            EndIf

          Case G_Stack
            If EventType() = #PB_EventType_LeftButtonDown
              Protected StackImg.i = CreateImage(#PB_Any, 10, 10)
              Protected StackRowH.i = 20
              If StackImg And StartDrawing(ImageOutput(StackImg))
                DrawingFont(FontID(DbgFont))
                StackRowH = TextHeight("0") + 4
                StopDrawing()
              EndIf
              If StackImg : FreeImage(StackImg) : EndIf
              Protected StackMouseY.i = GetGadgetAttribute(G_Stack, #PB_Canvas_MouseY)
              Protected StackRow.i = StackMouseY / StackRowH
              If StackRow >= 0 And StackRow <= 24
                Protected StackAddr.u = (*CpuState\RegSP + (StackRow - 8) * 2) & $FFFF
                Protected CurWord.s = Mamute_Hex4(Mamute_ReadByte(StackAddr) | (Mamute_ReadByte((StackAddr + 1) & $FFFF) << 8))
                Protected NewWord.s = InputRequester("Editar pilha " + Mamute_Hex4(StackAddr), "Novo valor (hexa, 4 digitos):", CurWord)
                If NewWord <> "" And Mamute_IsHexString(NewWord, 4)
                  Protected WordVal.i = Val("$" + NewWord)
                  Mamute_WriteByte(StackAddr, WordVal & $FF)
                  Mamute_WriteByte((StackAddr + 1) & $FFFF, (WordVal >> 8) & $FF)
                  FullRepaint = 1
                EndIf
              EndIf
            EndIf

          Case G_StepInto
            If EventType() = #PB_EventType_LeftButtonDown
              Protected TxtSI.s = Mz80_StepInto(*CpuState)
              DbgState\StatusText = "EXECUTADO: " + TxtSI
              DbgState\MiniBase = *CpuState\RegPC
              SetGadgetText(G_MiniAddr, Mamute_Hex4(DbgState\MiniBase))
              FullRepaint = 1
            EndIf

          Case G_StepOver
            If EventType() = #PB_EventType_LeftButtonDown
              If Mz80_StepOver(*CpuState)
                DbgState\StatusText = "STEP OVER CONCLUIDO - PC=" + Mamute_Hex4(*CpuState\RegPC)
              Else
                DbgState\StatusText = "STEP OVER INTERROMPIDO - LIMITE DE INSTRUCOES ATINGIDO"
              EndIf
              FullRepaint = 1
            EndIf

          Case G_StepOut
            If EventType() = #PB_EventType_LeftButtonDown
              If Mz80_StepOut(*CpuState)
                DbgState\StatusText = "STEP OUT CONCLUIDO - PC=" + Mamute_Hex4(*CpuState\RegPC)
              Else
                DbgState\StatusText = "STEP OUT INTERROMPIDO - LIMITE DE INSTRUCOES ATINGIDO"
              EndIf
              FullRepaint = 1
            EndIf

          Case G_Run
            If EventType() = #PB_EventType_LeftButtonDown
              DbgState\StatusText = Mz80_Run(*CpuState)
              FullRepaint = 1
            EndIf

          Case G_Reset
            If EventType() = #PB_EventType_LeftButtonDown
              Mz80_ResetToStart(*CpuState, StartAddr & $FFFF)
              DbgState\StatusText = "REINICIADO EM " + Mamute_Hex4(StartAddr & $FFFF)
              FullRepaint = 1
            EndIf

          Case G_Close
            If EventType() = #PB_EventType_LeftButtonDown
              Break
            EndIf
        EndSelect

      Case #PB_Event_Menu
        Select EventMenu()
          Case #MamuteDebugger_Shortcut_StepInto
            Protected TxtSI2.s = Mz80_StepInto(*CpuState)
            DbgState\StatusText = "EXECUTADO: " + TxtSI2
            DbgState\MiniBase = *CpuState\RegPC
            SetGadgetText(G_MiniAddr, Mamute_Hex4(DbgState\MiniBase))
            FullRepaint = 1

          Case #MamuteDebugger_Shortcut_StepOver
            If Mz80_StepOver(*CpuState)
              DbgState\StatusText = "STEP OVER CONCLUIDO - PC=" + Mamute_Hex4(*CpuState\RegPC)
            Else
              DbgState\StatusText = "STEP OVER INTERROMPIDO - LIMITE DE INSTRUCOES ATINGIDO"
            EndIf
            FullRepaint = 1

          Case #MamuteDebugger_Shortcut_StepOut
            If Mz80_StepOut(*CpuState)
              DbgState\StatusText = "STEP OUT CONCLUIDO - PC=" + Mamute_Hex4(*CpuState\RegPC)
            Else
              DbgState\StatusText = "STEP OUT INTERROMPIDO - LIMITE DE INSTRUCOES ATINGIDO"
            EndIf
            FullRepaint = 1

          Case #MamuteDebugger_Shortcut_Run
            DbgState\StatusText = Mz80_Run(*CpuState)
            FullRepaint = 1

          Case #MamuteDebugger_Shortcut_Escape
            Break
        EndSelect

      Case #PB_Event_CloseWindow
        Break
    EndSelect
  ForEver

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
