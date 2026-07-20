;
; ------------------------------------------------------------
;  Criar -> Alfabeto...: editor de charset MSX (bitmaps 8x8, 256 caracteres)
;  no formato de arquivo .ALF do Graphos III - um binario MSX classico
;  (cabecalho de 7 bytes: byte de tipo &HFE + enderecos inicial/final/
;  execucao, 2 bytes cada, little-endian) contendo 2048 bytes de dados: 256
;  caracteres, 8 bytes cada (um bitmap 8x8, bit 7 = pixel mais a esquerda),
;  carregado originalmente no endereco de VRAM &H9200 (Pattern Generator
;  Table).
;
;  Tabela de 256 caracteres (16 colunas x 16 linhas, indice = linha*16+col -
;  o layout ja corresponde ao codigo hexadecimal: cabecalho de linha = byte
;  alto, cabecalho de coluna = nibble baixo) com miniatura de cada glifo;
;  clicar num caractere carrega o bitmap na grade grande a direita, onde o
;  usuario liga/apaga pixels a mao; o botao "Registrar" e que de fato grava
;  os bytes editados de volta no alfabeto (e atualiza a miniatura na
;  tabela) - editar sem registrar nao muda o alfabeto em memoria.
; ------------------------------------------------------------
;

#CharEd_TableCellPx  = 18
#CharEd_TableHeaderW = 22
#CharEd_TableHeaderH = 18
#CharEd_TableCanvasW = #CharEd_TableHeaderW + 16 * #CharEd_TableCellPx
#CharEd_TableCanvasH = #CharEd_TableHeaderH + 16 * #CharEd_TableCellPx

#CharEd_EditPixelPx    = 30
#CharEd_EditCanvasSize = 8 * #CharEd_EditPixelPx

#CharEd_AlfDataSize    = 2048   ; 256 caracteres x 8 bytes
#CharEd_AlfHeaderSize  = 7      ; ID (1) + inicio/fim/execucao (2 bytes cada, little-endian)
#CharEd_AlfLoadAddress = $9200  ; endereco de VRAM da Pattern Generator Table no Graphos III
#CharEd_AlfID          = $FE    ; byte de tipo dos binarios MSX (CSAVE"...",CSAVE"...",B / BLOAD)

#CharEd_FilePattern = "Alfabeto Graphos III (*.alf)|*.alf|Todos os arquivos (*.*)|*.*"

Global CharEd_LastError.s = ""

Procedure.s CharEd_GetLastError()
  ProcedureReturn CharEd_LastError
EndProcedure

; Le um .alf no formato binario do Graphos III (ver cabecalho do arquivo).
; Valida o byte de tipo (&HFE) e o tamanho minimo antes de aceitar os dados -
; um cabecalho invalido provavelmente significa que o arquivo nao e um
; alfabeto de verdade, entao preferimos falhar a carregar lixo silenciosamente.
Procedure.b CharEd_LoadAlf(Path.s, Array CharsetBytes.a(2))
  Protected FileNum = ReadFile(#PB_Any, Path)
  If Not FileNum
    CharEd_LastError = "Nao foi possivel abrir o arquivo: " + Path
    ProcedureReturn #False
  EndIf

  Protected TotalSize = #CharEd_AlfHeaderSize + #CharEd_AlfDataSize
  Protected FileLen = Lof(FileNum)
  If FileLen < TotalSize
    CloseFile(FileNum)
    CharEd_LastError = "Arquivo pequeno demais pra ser um alfabeto Graphos III valido (" +
                        Str(FileLen) + " bytes, esperado pelo menos " + Str(TotalSize) + ")."
    ProcedureReturn #False
  EndIf

  Protected *Buffer = AllocateMemory(TotalSize)
  ReadData(FileNum, *Buffer, TotalSize)
  CloseFile(FileNum)

  Protected ID.a = PeekA(*Buffer)
  If ID <> #CharEd_AlfID
    FreeMemory(*Buffer)
    CharEd_LastError = "Tipo de arquivo invalido: byte inicial e &H" + RSet(Hex(ID), 2, "0") +
                        " (esperado &H" + RSet(Hex(#CharEd_AlfID), 2, "0") + ", binario MSX)."
    ProcedureReturn #False
  EndIf

  Protected Row, Col
  For Row = 0 To 255
    For Col = 0 To 7
      CharsetBytes(Row, Col) = PeekA(*Buffer + #CharEd_AlfHeaderSize + Row * 8 + Col)
    Next
  Next
  FreeMemory(*Buffer)
  CharEd_LastError = ""
  ProcedureReturn #True
EndProcedure

; Grava um .alf no formato binario do Graphos III: ID &HFE, endereco inicial
; &H9200, endereco final = inicio + tamanho - 1 (endereco do ULTIMO byte,
; inclusive - convencao padrao dos binarios MSX, confirmada contra o
; cabecalho de um .alf real do Graphos III), execucao = inicio, seguido dos
; 2048 bytes de dados (256 caracteres x 8 bytes).
Procedure.b CharEd_SaveAlf(Path.s, Array CharsetBytes.a(2))
  Protected FileNum = CreateFile(#PB_Any, Path)
  If Not FileNum
    CharEd_LastError = "Nao foi possivel criar o arquivo: " + Path
    ProcedureReturn #False
  EndIf

  Protected TotalSize = #CharEd_AlfHeaderSize + #CharEd_AlfDataSize
  Protected *Buffer = AllocateMemory(TotalSize)

  Protected StartAddr.u = #CharEd_AlfLoadAddress
  Protected EndAddr.u   = #CharEd_AlfLoadAddress + #CharEd_AlfDataSize - 1
  Protected ExecAddr.u  = #CharEd_AlfLoadAddress

  PokeA(*Buffer + 0, #CharEd_AlfID)
  PokeA(*Buffer + 1, StartAddr & $FF) : PokeA(*Buffer + 2, (StartAddr >> 8) & $FF)
  PokeA(*Buffer + 3, EndAddr & $FF)   : PokeA(*Buffer + 4, (EndAddr >> 8) & $FF)
  PokeA(*Buffer + 5, ExecAddr & $FF)  : PokeA(*Buffer + 6, (ExecAddr >> 8) & $FF)

  Protected Row, Col
  For Row = 0 To 255
    For Col = 0 To 7
      PokeA(*Buffer + #CharEd_AlfHeaderSize + Row * 8 + Col, CharsetBytes(Row, Col))
    Next
  Next

  WriteData(FileNum, *Buffer, TotalSize)
  CloseFile(FileNum)
  FreeMemory(*Buffer)
  CharEd_LastError = ""
  ProcedureReturn #True
EndProcedure

; Desempacota os 8 bytes do caractere CharIndex em EditGrid (8x8, 0/1) - bit
; 7 de cada byte e a coluna 0 (pixel mais a esquerda), igual ao layout real
; do bitmap MSX.
Procedure CharEd_UnpackChar(Array CharsetBytes.a(2), CharIndex.i, Array EditGrid.a(2))
  Protected Row, Col, ByteVal.a
  For Row = 0 To 7
    ByteVal = CharsetBytes(CharIndex, Row)
    For Col = 0 To 7
      If ByteVal & (1 << (7 - Col))
        EditGrid(Row, Col) = 1
      Else
        EditGrid(Row, Col) = 0
      EndIf
    Next
  Next
EndProcedure

; Empacota EditGrid (8x8, 0/1) de volta nos 8 bytes do caractere CharIndex -
; chamado pelo botao "Registrar", nunca automaticamente ao editar.
Procedure CharEd_PackChar(Array EditGrid.a(2), Array CharsetBytes.a(2), CharIndex.i)
  Protected Row, Col, ByteVal.a
  For Row = 0 To 7
    ByteVal = 0
    For Col = 0 To 7
      If EditGrid(Row, Col)
        ByteVal = ByteVal | (1 << (7 - Col))
      EndIf
    Next
    CharsetBytes(CharIndex, Row) = ByteVal
  Next
EndProcedure

Procedure CharEd_ClearEditGrid(Array EditGrid.a(2))
  Protected Row, Col
  For Row = 0 To 7
    For Col = 0 To 7
      EditGrid(Row, Col) = 0
    Next
  Next
EndProcedure

Procedure CharEd_InvertEditGrid(Array EditGrid.a(2))
  Protected Row, Col
  For Row = 0 To 7
    For Col = 0 To 7
      EditGrid(Row, Col) = 1 - EditGrid(Row, Col)
    Next
  Next
EndProcedure

; "Caractere: 65 ($41) 'A'" - so mostra o caractere impresso pra faixa ASCII
; imprimivel (32-126); fora dela o charset MSX diverge do Unicode/Windows-1252
; e Chr() poderia desenhar qualquer coisa.
Procedure.s CharEd_CharStatusText(CharIndex.i)
  Protected Label.s = "Caractere: " + Str(CharIndex) + " ($" + RSet(Hex(CharIndex), 2, "0") + ")"
  If CharIndex >= 32 And CharIndex <= 126
    Label = Label + " '" + Chr(CharIndex) + "'"
  EndIf
  ProcedureReturn Label
EndProcedure

; Os 8 bytes hex do caractere sendo editado agora (recalculado a cada
; pixel alterado, antes de "Registrar") - leitura rapida pro usuario
; conferir/copiar os bytes, estilo editor de charset classico.
Procedure.s CharEd_HexBytesText(Array EditGrid.a(2))
  Protected Result.s = "", Row, Col, ByteVal.a
  For Row = 0 To 7
    ByteVal = 0
    For Col = 0 To 7
      If EditGrid(Row, Col)
        ByteVal = ByteVal | (1 << (7 - Col))
      EndIf
    Next
    Result = Result + "&H" + RSet(Hex(ByteVal), 2, "0")
    If Row < 7
      Result = Result + ","
    EndIf
  Next
  ProcedureReturn Result
EndProcedure

Procedure CharEd_UpdateFileLabel(G_FileLabel, CurrentPath.s)
  If CurrentPath = ""
    SetGadgetText(G_FileLabel, "Arquivo: (novo, sem nome)")
  Else
    SetGadgetText(G_FileLabel, "Arquivo: " + CurrentPath)
  EndIf
EndProcedure

; Tabela inteira (16x16 = 256 caracteres) com cabecalho hex de linha/coluna
; (linha = byte alto, coluna = nibble baixo - a posicao na grade ja e o
; codigo do caractere) e uma miniatura 8x8 (zoom 2x) de cada glifo, tal como
; esta em CharsetBytes agora. O caractere selecionado ganha um contorno
; vermelho.
Procedure CharEd_RedrawTable(Canvas, Array CharsetBytes.a(2), Selected.i)
  Protected HexDigits.s = "0123456789ABCDEF"
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf

  Box(0, 0, #CharEd_TableCanvasW, #CharEd_TableCanvasH, RGB(255, 255, 255))

  DrawingMode(#PB_2DDrawing_Transparent)
  FrontColor(RGB(90, 90, 90))
  Protected i
  For i = 0 To 15
    DrawText(#CharEd_TableHeaderW + i * #CharEd_TableCellPx + 5, 2, Mid(HexDigits, i + 1, 1))
    DrawText(2, #CharEd_TableHeaderH + i * #CharEd_TableCellPx + 3, RSet(Hex(i * 16), 2, "0"))
  Next

  DrawingMode(#PB_2DDrawing_Default)
  Protected CharIdx, TableRow, TableCol, CellX, CellY, PxRow, PxCol, ByteVal.a
  Protected Zoom = 2
  For CharIdx = 0 To 255
    TableRow = CharIdx / 16
    TableCol = CharIdx % 16
    CellX = #CharEd_TableHeaderW + TableCol * #CharEd_TableCellPx + 1
    CellY = #CharEd_TableHeaderH + TableRow * #CharEd_TableCellPx + 1

    For PxRow = 0 To 7
      ByteVal = CharsetBytes(CharIdx, PxRow)
      For PxCol = 0 To 7
        If ByteVal & (1 << (7 - PxCol))
          Box(CellX + PxCol * Zoom, CellY + PxRow * Zoom, Zoom, Zoom, RGB(0, 0, 0))
        EndIf
      Next
    Next

    If CharIdx = Selected
      DrawingMode(#PB_2DDrawing_Outlined)
      Box(CellX - 1, CellY - 1, 8 * Zoom + 2, 8 * Zoom + 2, RGB(205, 40, 40))
      DrawingMode(#PB_2DDrawing_Default)
    EndIf
  Next

  StopDrawing()
EndProcedure

; Grade grande editavel (8x8, um quadrado grosso por pixel) com linhas de
; grade finas e uma cruz central mais forte de referencia (igual a maioria
; dos editores de charset classicos).
Procedure CharEd_RedrawEditCanvas(Canvas, Array EditGrid.a(2))
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf

  Box(0, 0, #CharEd_EditCanvasSize, #CharEd_EditCanvasSize, RGB(255, 255, 255))

  Protected Row, Col, X, Y
  For Row = 0 To 7
    For Col = 0 To 7
      If EditGrid(Row, Col)
        X = Col * #CharEd_EditPixelPx
        Y = Row * #CharEd_EditPixelPx
        Box(X + 1, Y + 1, #CharEd_EditPixelPx - 1, #CharEd_EditPixelPx - 1, RGB(0, 0, 0))
      EndIf
    Next
  Next

  Protected i
  For i = 0 To 8
    Line(i * #CharEd_EditPixelPx, 0, 0, #CharEd_EditCanvasSize, RGB(180, 180, 180))
    Line(0, i * #CharEd_EditPixelPx, #CharEd_EditCanvasSize, 0, RGB(180, 180, 180))
  Next
  Line(4 * #CharEd_EditPixelPx, 0, 0, #CharEd_EditCanvasSize, RGB(120, 120, 200))
  Line(0, 4 * #CharEd_EditPixelPx, #CharEd_EditCanvasSize, 0, RGB(120, 120, 200))

  StopDrawing()
EndProcedure

Procedure.b CharEd_ConfirmDiscardChar()
  ProcedureReturn Bool(MessageRequester("Caractere nao registrado",
                        "As alteracoes deste caractere ainda nao foram registradas no alfabeto." + Chr(10) +
                        "Descartar mesmo assim?",
                        #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning) = #PB_MessageRequester_Yes)
EndProcedure

Procedure.b CharEd_ConfirmDiscardAlphabet()
  ProcedureReturn Bool(MessageRequester("Alfabeto nao registrado",
                        "As alteracoes deste alfabeto (ou do caractere em edicao) ainda nao foram" + Chr(10) +
                        "registradas no projeto. Descartar mesmo assim?",
                        #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning) = #PB_MessageRequester_Yes)
EndProcedure

; Busca o alfabeto TargetNumber no projeto e atualiza a UI inteira (numero,
; tag, tabela, grade grande, status do caractere selecionado, bytes hex) -
; sempre reseta a selecao de caractere para 0. Nao mexe em AlphaNumber/
; AlphaTag do chamador; quem chama deve ler ProjectDB::LastAlphabetTag() em
; seguida pra manter as proprias variaveis em dia (mesmo padrao de
; SpriteEd_LoadSprite em SpriteEditorGui.pbi).
Procedure.b CharEd_LoadAlphabetUI(TargetNumber.i, G_AlphaNumberText, G_Tag, G_Table, G_EditCanvas, G_CharStatus, G_HexBytes, Array CharsetBytes.a(2), Array EditGrid.a(2))
  If Not ProjectDB::FetchAlphabet(TargetNumber, CharsetBytes())
    ProcedureReturn #False
  EndIf
  SetGadgetText(G_AlphaNumberText, "#" + Str(TargetNumber))
  SetGadgetText(G_Tag, ProjectDB::LastAlphabetTag())
  CharEd_UnpackChar(CharsetBytes(), 0, EditGrid())
  CharEd_RedrawTable(G_Table, CharsetBytes(), 0)
  CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
  SetGadgetText(G_CharStatus, CharEd_CharStatusText(0))
  SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
  ProcedureReturn #True
EndProcedure

Procedure CharsetEditor_OpenWindow(ParentWindow)
  Protected LeftX = 15
  Protected ProjBarY = 15
  Protected FileBarY = ProjBarY + 34
  Protected TableY = FileBarY + 34

  Protected RightX = LeftX + #CharEd_TableCanvasW + 20
  Protected RightW = #CharEd_EditCanvasSize

  Protected LeftBottom = TableY + #CharEd_TableCanvasH
  Protected CloseY = LeftBottom + 15

  Protected EditY = TableY + 24
  Protected HexBytesY = EditY + #CharEd_EditCanvasSize + 6
  Protected BtnY = HexBytesY + 26
  Protected RightBottom = BtnY + 28

  Protected WinW = RightX + RightW + 15
  Protected WinH
  If RightBottom > CloseY + 30
    WinH = RightBottom + 15
  Else
    WinH = CloseY + 30 + 15
  EndIf

  ; Barra de projeto (numero/navegacao/tag/Novo/Registrar alfabeto) pode
  ; precisar de mais largura que a tabela+grade - WinW cresce se preciso.
  Protected Cx = LeftX + 60 + 4 + 40 + 10 + 30 + 30 + 30 + 44 + 36 + 126 + 106 + 130 + 15
  If Cx > WinW
    WinW = Cx
  EndIf

  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Criar alfabeto MSX (Graphos III)",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf
  DisableWindow(ParentWindow, #True)

  ; Barra de projeto: numero do alfabeto atual, navegacao entre os alfabetos
  ; ja registrados no projeto, tag (nome curto) e os botoes Novo/Registrar -
  ; mesmo padrao da barra de projeto do editor de sprites.
  Cx = LeftX
  TextGadget(#PB_Any, Cx, ProjBarY + 5, 60, 20, "Alfabeto:")
  Cx + 60 + 4
  Protected G_AlphaNumberText = TextGadget(#PB_Any, Cx, ProjBarY + 5, 40, 20, "#1")
  Cx + 40 + 10

  Protected G_First = ButtonGadget(#PB_Any, Cx, ProjBarY, 28, 26, Chr(9198))
  GadgetToolTip(G_First, "Primeiro alfabeto")
  Cx + 28 + 2
  Protected G_Prev = ButtonGadget(#PB_Any, Cx, ProjBarY, 28, 26, Chr(9664))
  GadgetToolTip(G_Prev, "Alfabeto anterior")
  Cx + 28 + 2
  Protected G_Next = ButtonGadget(#PB_Any, Cx, ProjBarY, 28, 26, Chr(9654))
  GadgetToolTip(G_Next, "Proximo alfabeto")
  Cx + 28 + 2
  Protected G_Last = ButtonGadget(#PB_Any, Cx, ProjBarY, 28, 26, Chr(9197))
  GadgetToolTip(G_Last, "Ultimo alfabeto")
  Cx + 28 + 16

  TextGadget(#PB_Any, Cx, ProjBarY + 5, 32, 20, "Tag:")
  Cx + 32 + 4
  Protected G_Tag = StringGadget(#PB_Any, Cx, ProjBarY + 3, 110, 22, "")
  GadgetToolTip(G_Tag, "Nome curto pra identificar o alfabeto (ate 16 caracteres)")
  Cx + 110 + 16

  Protected G_AlphaNew = ButtonGadget(#PB_Any, Cx, ProjBarY, 100, 26, "Novo alfabeto")
  GadgetToolTip(G_AlphaNew, "Novo alfabeto (numera automaticamente, sempre parte do msx.alf padrao)")
  Cx + 100 + 6
  Protected G_AlphaRegister = ButtonGadget(#PB_Any, Cx, ProjBarY, 130, 26, "Registrar alfabeto")
  GadgetToolTip(G_AlphaRegister, "Registrar: grava este alfabeto inteiro no projeto")

  Protected G_FileLabel = TextGadget(#PB_Any, LeftX, FileBarY + 5, 330, 20, "")
  Protected G_Open      = ButtonGadget(#PB_Any, LeftX + 340, FileBarY, 90, 26, "Abrir...")
  Protected G_SaveAs    = ButtonGadget(#PB_Any, LeftX + 340 + 96, FileBarY, 110, 26, "Salvar como...")

  Protected G_Table = CanvasGadget(#PB_Any, LeftX, TableY, #CharEd_TableCanvasW, #CharEd_TableCanvasH)
  Protected G_Close = ButtonGadget(#PB_Any, LeftX, CloseY, 100, 30, "Fechar")

  Protected G_CharStatus = TextGadget(#PB_Any, RightX, TableY, RightW, 20, "")
  Protected G_EditCanvas = CanvasGadget(#PB_Any, RightX, EditY, #CharEd_EditCanvasSize, #CharEd_EditCanvasSize)
  Protected G_HexBytes   = TextGadget(#PB_Any, RightX, HexBytesY, RightW, 20, "")

  Protected G_Register = ButtonGadget(#PB_Any, RightX, BtnY, 74, 28, "Registrar")
  GadgetToolTip(G_Register, "Registrar: grava os pixels editados neste caractere (nao registra o alfabeto)")
  Protected G_Clear    = ButtonGadget(#PB_Any, RightX + 78, BtnY, 74, 28, "Limpar")
  Protected G_Invert   = ButtonGadget(#PB_Any, RightX + 156, BtnY, 74, 28, "Inverter")

  Dim CharsetBytes.a(255, 7)
  Dim EditGrid.a(7, 7)
  Protected Selected.i = 0
  Protected EditDirty.b = #False
  Protected CurrentPath.s = ""

  Protected AlphaNumber.i = 1
  Protected AlphaTag.s = ""
  Protected AlphaDirty.b = #False

  ; Abre (ou reaproveita) o projeto atual e carrega o primeiro alfabeto ja
  ; registrado nele, se houver; senao comeca com o alfabeto #1 (ainda nao
  ; registrado) usando o msx.alf padrao (alfabeto 0 do "projeto 0" de
  ; defaults, sempre em memoria - ver ProjectDB::FetchDefaultAlphabet()).
  ProjectDB::EnsureOpen()
  NewList ExistingAlphabets.i()
  ProjectDB::ListAlphabetNumbers(ExistingAlphabets())
  If ListSize(ExistingAlphabets()) > 0
    FirstElement(ExistingAlphabets())
    AlphaNumber = ExistingAlphabets()
    ProjectDB::FetchAlphabet(AlphaNumber, CharsetBytes())
    AlphaTag = ProjectDB::LastAlphabetTag()
  Else
    ProjectDB::FetchDefaultAlphabet(0, CharsetBytes())
  EndIf
  CharEd_UnpackChar(CharsetBytes(), Selected, EditGrid())

  SetGadgetText(G_AlphaNumberText, "#" + Str(AlphaNumber))
  SetGadgetText(G_Tag, AlphaTag)
  CharEd_UpdateFileLabel(G_FileLabel, CurrentPath)
  CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)
  CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
  SetGadgetText(G_CharStatus, CharEd_CharStatusText(Selected))
  SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))

  Protected Event, Quit = #False
  Protected MouseX, MouseY, TableRow, TableCol, NewSelected, PxRow, PxCol
  Protected DragValue.i, LastEditRow.i = -1, LastEditCol.i = -1
  Protected NavTarget.i
  NewList Nav.i()

  Repeat
    Event = WaitWindowEvent()
    Select Event

      Case #PB_Event_Gadget
        Select EventGadget()

          Case G_Open
            Protected OpenPath.s = OpenFileRequester("Abrir alfabeto MSX (Graphos III)", CurrentPath, #CharEd_FilePattern, 0)
            If OpenPath <> ""
              If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
                ; CharEd_LoadAlf() so grava em CharsetBytes() depois de validar
                ; tipo/tamanho do arquivo inteiro - em caso de erro a chamada
                ; abaixo nao toca no array, entao o alfabeto atual em memoria
                ; fica intacto (nao ha necessidade de limpar antes).
                If CharEd_LoadAlf(OpenPath, CharsetBytes())
                  CurrentPath = OpenPath
                  Selected = 0
                  EditDirty = #False
                  AlphaDirty = #True
                  CharEd_UnpackChar(CharsetBytes(), Selected, EditGrid())
                  CharEd_UpdateFileLabel(G_FileLabel, CurrentPath)
                  CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)
                  CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
                  SetGadgetText(G_CharStatus, CharEd_CharStatusText(Selected))
                  SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
                Else
                  MessageRequester("Erro ao abrir alfabeto",
                                    "Nao foi possivel abrir:" + Chr(10) + OpenPath + Chr(10) + CharEd_GetLastError(),
                                    #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
                EndIf
              EndIf
            EndIf

          Case G_SaveAs
            Protected SavePath.s = SaveFileRequester("Salvar alfabeto MSX (Graphos III)", CurrentPath, #CharEd_FilePattern, 0)
            If SavePath <> ""
              SavePath = EnsureExtension(SavePath, "alf")
              If CharEd_SaveAlf(SavePath, CharsetBytes())
                CurrentPath = SavePath
                CharEd_UpdateFileLabel(G_FileLabel, CurrentPath)
              Else
                MessageRequester("Erro ao salvar alfabeto",
                                  "Nao foi possivel salvar em:" + Chr(10) + SavePath + Chr(10) + CharEd_GetLastError(),
                                  #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
              EndIf
            EndIf

          Case G_Register
            CharEd_PackChar(EditGrid(), CharsetBytes(), Selected)
            EditDirty = #False
            AlphaDirty = #True
            CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)

          Case G_First
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              ProjectDB::ListAlphabetNumbers(Nav())
              NavTarget = SpriteEd_FindNavTarget(Nav(), 0, AlphaNumber)
              If NavTarget >= 0
                If CharEd_LoadAlphabetUI(NavTarget, G_AlphaNumberText, G_Tag, G_Table, G_EditCanvas, G_CharStatus, G_HexBytes, CharsetBytes(), EditGrid())
                  AlphaNumber = NavTarget
                  AlphaTag = ProjectDB::LastAlphabetTag()
                  Selected = 0
                  EditDirty = #False
                  AlphaDirty = #False
                EndIf
              EndIf
            EndIf

          Case G_Prev
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              ProjectDB::ListAlphabetNumbers(Nav())
              NavTarget = SpriteEd_FindNavTarget(Nav(), 1, AlphaNumber)
              If NavTarget >= 0
                If CharEd_LoadAlphabetUI(NavTarget, G_AlphaNumberText, G_Tag, G_Table, G_EditCanvas, G_CharStatus, G_HexBytes, CharsetBytes(), EditGrid())
                  AlphaNumber = NavTarget
                  AlphaTag = ProjectDB::LastAlphabetTag()
                  Selected = 0
                  EditDirty = #False
                  AlphaDirty = #False
                EndIf
              EndIf
            EndIf

          Case G_Next
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              ProjectDB::ListAlphabetNumbers(Nav())
              NavTarget = SpriteEd_FindNavTarget(Nav(), 2, AlphaNumber)
              If NavTarget >= 0
                If CharEd_LoadAlphabetUI(NavTarget, G_AlphaNumberText, G_Tag, G_Table, G_EditCanvas, G_CharStatus, G_HexBytes, CharsetBytes(), EditGrid())
                  AlphaNumber = NavTarget
                  AlphaTag = ProjectDB::LastAlphabetTag()
                  Selected = 0
                  EditDirty = #False
                  AlphaDirty = #False
                EndIf
              EndIf
            EndIf

          Case G_Last
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              ProjectDB::ListAlphabetNumbers(Nav())
              NavTarget = SpriteEd_FindNavTarget(Nav(), 3, AlphaNumber)
              If NavTarget >= 0
                If CharEd_LoadAlphabetUI(NavTarget, G_AlphaNumberText, G_Tag, G_Table, G_EditCanvas, G_CharStatus, G_HexBytes, CharsetBytes(), EditGrid())
                  AlphaNumber = NavTarget
                  AlphaTag = ProjectDB::LastAlphabetTag()
                  Selected = 0
                  EditDirty = #False
                  AlphaDirty = #False
                EndIf
              EndIf
            EndIf

          Case G_AlphaNew
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              ProjectDB::ListAlphabetNumbers(Nav())
              Protected NextAlphaNum.i = 1
              If ListSize(Nav()) > 0
                LastElement(Nav())
                NextAlphaNum = Nav() + 1
              EndIf
              AlphaNumber = NextAlphaNum
              AlphaTag = ""
              Selected = 0
              EditDirty = #False
              AlphaDirty = #False
              ; "Novo alfabeto" sempre parte do msx.alf padrao (alfabeto 0
              ; do projeto de defaults), nunca em branco - pedido explicito,
              ; diferente do "Novo sprite" (que comeca em branco).
              ProjectDB::FetchDefaultAlphabet(0, CharsetBytes())
              CharEd_UnpackChar(CharsetBytes(), Selected, EditGrid())
              SetGadgetText(G_AlphaNumberText, "#" + Str(AlphaNumber))
              SetGadgetText(G_Tag, AlphaTag)
              CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)
              CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
              SetGadgetText(G_CharStatus, CharEd_CharStatusText(Selected))
              SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
            EndIf

          Case G_AlphaRegister
            ; Registrar o alfabeto tambem aplica qualquer edicao pendente do
            ; caractere atual primeiro (senao esses pixels ficariam de fora
            ; do que e gravado no projeto, sem o usuario perceber).
            If EditDirty
              CharEd_PackChar(EditGrid(), CharsetBytes(), Selected)
              EditDirty = #False
              CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)
            EndIf
            AlphaTag = Left(GetGadgetText(G_Tag), 16)
            SetGadgetText(G_Tag, AlphaTag)
            If ProjectDB::StoreAlphabet(AlphaNumber, AlphaTag, CharsetBytes())
              AlphaDirty = #False
            Else
              MessageRequester("Erro ao registrar",
                                "Nao foi possivel gravar o alfabeto:" + Chr(10) + ProjectDB::GetLastError(),
                                #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
            EndIf

          Case G_Tag
            If EventType() = #PB_EventType_Change
              If Len(GetGadgetText(G_Tag)) > 16
                SetGadgetText(G_Tag, Left(GetGadgetText(G_Tag), 16))
              EndIf
            EndIf

          Case G_Clear
            CharEd_ClearEditGrid(EditGrid())
            EditDirty = #True
            CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
            SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))

          Case G_Invert
            CharEd_InvertEditGrid(EditGrid())
            EditDirty = #True
            CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
            SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))

          Case G_Table
            If EventType() = #PB_EventType_LeftButtonDown
              MouseX = GetGadgetAttribute(G_Table, #PB_Canvas_MouseX) - #CharEd_TableHeaderW
              MouseY = GetGadgetAttribute(G_Table, #PB_Canvas_MouseY) - #CharEd_TableHeaderH
              If MouseX >= 0 And MouseY >= 0
                TableCol = MouseX / #CharEd_TableCellPx
                TableRow = MouseY / #CharEd_TableCellPx
                If TableCol >= 0 And TableCol < 16 And TableRow >= 0 And TableRow < 16
                  NewSelected = TableRow * 16 + TableCol
                  If NewSelected <> Selected
                    If Not EditDirty Or CharEd_ConfirmDiscardChar()
                      Selected = NewSelected
                      EditDirty = #False
                      CharEd_UnpackChar(CharsetBytes(), Selected, EditGrid())
                      CharEd_RedrawTable(G_Table, CharsetBytes(), Selected)
                      CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
                      SetGadgetText(G_CharStatus, CharEd_CharStatusText(Selected))
                      SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
                    EndIf
                  EndIf
                EndIf
              EndIf
            EndIf

          Case G_EditCanvas
            Select EventType()

              Case #PB_EventType_LeftButtonDown
                MouseX = GetGadgetAttribute(G_EditCanvas, #PB_Canvas_MouseX)
                MouseY = GetGadgetAttribute(G_EditCanvas, #PB_Canvas_MouseY)
                PxCol = MouseX / #CharEd_EditPixelPx
                PxRow = MouseY / #CharEd_EditPixelPx
                If PxRow >= 0 And PxRow < 8 And PxCol >= 0 And PxCol < 8
                  If EditGrid(PxRow, PxCol)
                    DragValue = 0
                  Else
                    DragValue = 1
                  EndIf
                  EditGrid(PxRow, PxCol) = DragValue
                  EditDirty = #True
                  LastEditRow = PxRow : LastEditCol = PxCol
                  CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
                  SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
                EndIf

              ; Arrastar com o botao esquerdo pressionado pinta uma sequencia
              ; de pixels com o mesmo valor do primeiro clique (nao fica
              ; alternando a cada pixel passado por cima) - mesmo padrao do
              ; lapis/borracha do editor de sprites.
              Case #PB_EventType_MouseMove
                If GetGadgetAttribute(G_EditCanvas, #PB_Canvas_Buttons) & #PB_Canvas_LeftButton
                  MouseX = GetGadgetAttribute(G_EditCanvas, #PB_Canvas_MouseX)
                  MouseY = GetGadgetAttribute(G_EditCanvas, #PB_Canvas_MouseY)
                  PxCol = MouseX / #CharEd_EditPixelPx
                  PxRow = MouseY / #CharEd_EditPixelPx
                  If PxRow >= 0 And PxRow < 8 And PxCol >= 0 And PxCol < 8 And (PxRow <> LastEditRow Or PxCol <> LastEditCol)
                    EditGrid(PxRow, PxCol) = DragValue
                    EditDirty = #True
                    LastEditRow = PxRow : LastEditCol = PxCol
                    CharEd_RedrawEditCanvas(G_EditCanvas, EditGrid())
                    SetGadgetText(G_HexBytes, CharEd_HexBytesText(EditGrid()))
                  EndIf
                EndIf

            EndSelect

          Case G_Close
            If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
              Quit = #True
            EndIf

        EndSelect

      Case #PB_Event_CloseWindow
        If Not (EditDirty Or AlphaDirty) Or CharEd_ConfirmDiscardAlphabet()
          Quit = #True
        EndIf

    EndSelect
  Until Quit

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
EndProcedure
