;
; ------------------------------------------------------------
;  Suporte ao Mamute Assembler (MamuteAssemblerGui.pbi): simulacao do
;  sistema de slots do MSX - 4 slots (0-3), 4 paginas de 16KB por slot
;  (Pagina 0: 0000-3FFF, Pagina 1: 4000-7FFF, Pagina 2: 8000-BFFF, Pagina 3:
;  C000-FFFF, exatamente como o hardware real do MSX endereca memoria via
;  paginacao). MamuteMem() e um bloco 4x4 de 16KB cada (256KB no total) -
;  toda em branco por enquanto (Dim zera sozinho), preenchida por arquivo
;  real (BIOS/BASIC/cartucho) numa sessao futura.
;
;  "Configurar -> Mamute Assembler..." (MamuteSettings_OpenWindow abaixo)
;  configura o que existe FISICAMENTE em cada uma das 16 celulas Slot x
;  Pagina (Vazio/RAM/ROM/BASIC + arquivo, pra ROM/BASIC) - configuracao
;  fixa, nao muda em tempo de execucao. Ao escolher um arquivo de 32KB pra
;  uma celula ROM na Pagina 0 (BIOS), a tela pergunta se e BIOS+BASIC
;  combinados (comum em MSX real) - se sim, aponta a Pagina 0 e a Pagina 1
;  do MESMO slot pro MESMO arquivo, cada uma com o FileOffset certo (0 pros
;  primeiros 16KB/BIOS, #Mamute_PageSize pros ultimos 16KB/BASIC).
;  O comando PAGE (MamuteAssemblerGui.pbi)
;  mexe num conceito DIFERENTE: MamutePageMap() e o mapeamento ATIVO agora
;  mesmo - pra cada uma das 4 paginas visiveis pelo Z80 (0-3), qual dos 4
;  slots fisicos esta "comutado" ali - exatamente como o registrador de slot
;  primario (porta A8h) de um MSX de verdade. E esse mapeamento ativo (nao a
;  configuracao fisica) que vai decidir, em sessoes futuras, de qual bloco
;  de 16KB um comando que mostra/edita memoria realmente le/escreve.
; ------------------------------------------------------------
;

#MamuteMem_Empty = 0
#MamuteMem_RAM   = 1
#MamuteMem_ROM   = 2
#MamuteMem_Basic = 3

#Mamute_PageSize = 16384 ; 16KB - tamanho de cada bloco/pagina
#Mamute_CombinedBiosBasicSize = 32768 ; 32KB - BIOS+BASIC combinados num arquivo so (comum em MSX real)

; Bloco de memoria simulada: [Slot][Pagina][Offset 0..16383] - 4x4x16KB =
; 256KB. Global Dim zera sozinho (PureBasic) - "toda a memoria em branco"
; sem precisar de nenhum laco de inicializacao.
Global Dim MamuteMem.a(3, 3, 16383)

; FileOffset: deslocamento (em bytes) dentro de FilePath de onde comecam os
; 16KB desta celula - normalmente 0 (arquivo do tamanho exato da pagina),
; mas #Mamute_PageSize (16384) quando esta celula e a metade FINAL de um
; arquivo BIOS+BASIC combinado de 32KB (ver MamuteSettings_HandleFilePick())
; - assim os dois pontos (BIOS na Pagina 0, BASIC na Pagina 1 do mesmo slot)
; apontam pro MESMO arquivo, cada um lendo a metade certa.
Structure MamuteMemCell
  Tipo.b     ; #MamuteMem_Empty/RAM/ROM/Basic
  FilePath.s ; so usado quando Tipo = ROM ou Basic
  FileOffset.i
EndStructure
Global Dim MamuteCfgCell.MamuteMemCell(3, 3) ; [Slot][Pagina]

; Mapeamento ATIVO agora mesmo - MamutePageMap(Pagina) = Slot comutado
; naquela pagina. Recalculado pro "estado de boot" (Mamute_ResetPageMapToDefault)
; toda vez que a janela do Mamute Assembler abre - ver comentario no topo.
Global Dim MamutePageMap.i(3)

; Fonte do terminal (MamuteAssemblerGui.pbi) - configuravel em "Configurar ->
; Mamute Assembler..." (pedido explicito do usuario, fonte padrao ficou
; pequena demais). Monoespacada de proposito (EditorCfg_EnumMonospaceFonts(),
; EditorSettings.pbi, mesma enumeracao ja usada pela fonte do editor de
; codigo) - uma fonte proporcional quebraria o alinhamento em grade do
; terminal.
Global MamuteFontName.s = "Consolas"
Global MamuteFontSize.i = 14
Global MamuteFontBold.b = #True

Procedure.s Mamute_PageRangeText(Pagina.i)
  Select Pagina
    Case 0 : ProcedureReturn "0000-3FFF"
    Case 1 : ProcedureReturn "4000-7FFF"
    Case 2 : ProcedureReturn "8000-BFFF"
    Case 3 : ProcedureReturn "C000-FFFF"
  EndSelect
  ProcedureReturn "????-????"
EndProcedure

Procedure.s Mamute_TipoText(Tipo.b)
  Select Tipo
    Case #MamuteMem_RAM   : ProcedureReturn "RAM"
    Case #MamuteMem_ROM   : ProcedureReturn "ROM"
    Case #MamuteMem_Basic : ProcedureReturn "BASIC"
  EndSelect
  ProcedureReturn "Vazio"
EndProcedure

; Primeiro slot (0..3, varrendo em ordem) com RAM configurada em QUALQUER
; pagina - usado por "PAGE" sem parametros ("coloca todas as paginas no
; slot marcado como RAM"). -1 se nenhum slot tem RAM configurada ainda.
Procedure Mamute_FindRamSlot()
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      If MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_RAM
        ProcedureReturn Slot
      EndIf
    Next
  Next
  ProcedureReturn -1
EndProcedure

; Recalcula MamutePageMap() a partir da configuracao fisica (MamuteCfgCell) -
; "estado de boot": pra cada pagina, usa o slot configurado ali (ROM/BASIC
; ganham de RAM se as duas existirem na mesma pagina - RAM so vence quando
; e a UNICA coisa configurada); pagina sem nada configurado cai no slot 0
; por padrao (comportamento deterministico, sem "barramento flutuante").
Procedure Mamute_ResetPageMapToDefault()
  Protected Pagina, Slot, Chosen.i, ChosenIsRam.b, Found.b, Tipo.b
  For Pagina = 0 To 3
    Chosen = 0 : ChosenIsRam = #True : Found = #False
    For Slot = 0 To 3
      Tipo = MamuteCfgCell(Slot, Pagina)\Tipo
      If Tipo <> #MamuteMem_Empty
        If Not Found
          Chosen = Slot
          ChosenIsRam = Bool(Tipo = #MamuteMem_RAM)
          Found = #True
        ElseIf ChosenIsRam And Tipo <> #MamuteMem_RAM
          Chosen = Slot
          ChosenIsRam = #False
        EndIf
      EndIf
    Next
    MamutePageMap(Pagina) = Chosen
  Next
EndProcedure

;- ------------------------------------------------------------
;- Acesso a memoria por endereco de CPU (0000-FFFF) - usa MamutePageMap()
;- pra achar o slot ativo, exatamente como o comando PAGE deixou configurado.
;- Base de qualquer comando futuro que mostra/edita memoria (DM e o
;- primeiro) - ver comentario no topo do arquivo.
;- ------------------------------------------------------------

; Resolve um endereco de CPU (0-65535, sem checar faixa - chamador garante)
; pro Slot/Pagina/Offset fisicos correspondentes, considerando o mapeamento
; ATIVO agora (MamutePageMap()), nao a configuracao fisica crua.
Procedure Mamute_ResolveAddress(Addr.i, *OutSlot.Integer, *OutPagina.Integer, *OutOffset.Integer)
  Protected Pagina.i = (Addr >> 14) & 3
  *OutPagina\i = Pagina
  *OutSlot\i = MamutePageMap(Pagina)
  *OutOffset\i = Addr & (#Mamute_PageSize - 1)
EndProcedure

; #True so quando a celula fisica mapeada em Addr agora e RAM - ROM/BASIC/
; Vazio sao somente-leitura (fisicamente nao ha o que escrever ali, igual
; hardware real: ROM nao aceita escrita, e sem nada configurado nao ha chip
; nenhum pra responder).
Procedure.b Mamute_CanWriteAt(Addr.i)
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  ProcedureReturn Bool(MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_RAM)
EndProcedure

Procedure.a Mamute_ReadByte(Addr.i)
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  ProcedureReturn MamuteMem(Slot, Pagina, Offset)
EndProcedure

; #True se escreveu de verdade (Mamute_CanWriteAt); #False sem tocar em nada
; se a celula mapeada agora nao for RAM.
Procedure.b Mamute_WriteByte(Addr.i, Value.a)
  If Not Mamute_CanWriteAt(Addr)
    ProcedureReturn #False
  EndIf
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  MamuteMem(Slot, Pagina, Offset) = Value
  ProcedureReturn #True
EndProcedure

;- ------------------------------------------------------------
;- Formatacao/parse hexadecimal - "enderecos em hexa sao o padrao de
;- entrada de todos os comandos" (pedido explicito do usuario).
;- ------------------------------------------------------------

Procedure.s Mamute_Hex2(v.i)
  ProcedureReturn RSet(Hex(v & $FF), 2, "0")
EndProcedure

Procedure.s Mamute_Hex4(v.i)
  ProcedureReturn RSet(Hex(v & $FFFF), 4, "0")
EndProcedure

; Valida que Token so tem digitos hex (0-9A-Fa-f), 1 a MaxLen deles.
Procedure.b Mamute_IsHexString(Token.s, MaxLen.i)
  If Len(Token) < 1 Or Len(Token) > MaxLen
    ProcedureReturn #False
  EndIf
  Protected i
  For i = 1 To Len(Token)
    If FindString("0123456789ABCDEFabcdef", Mid(Token, i, 1)) = 0
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

; Endereco de 16 bits sem sinal, 1-4 digitos hex (ex.: "4000", "8000").
Procedure.b Mamute_ParseHexAddr(Token.s, *OutValue.Integer)
  If Not Mamute_IsHexString(Token, 4)
    ProcedureReturn #False
  EndIf
  *OutValue\i = Val("$" + Token)
  ProcedureReturn #True
EndProcedure

; Deslocamento com sinal opcional ("+"/"-" na frente, 1-2 digitos hex depois)
; - faixa -7Fh (-127) a 80h (128), pedido explicito do usuario. "80" sem
; sinal e tratado como positivo (+80h), igual "+80".
Procedure.b Mamute_ParseHexOffset(Token.s, *OutValue.Integer)
  If Token = ""
    ProcedureReturn #False
  EndIf
  Protected Sign.i = 1
  Protected Digits.s = Token
  If Left(Token, 1) = "+"
    Digits = Mid(Token, 2)
  ElseIf Left(Token, 1) = "-"
    Sign = -1
    Digits = Mid(Token, 2)
  EndIf
  If Not Mamute_IsHexString(Digits, 2)
    ProcedureReturn #False
  EndIf
  Protected Value.i = Sign * Val("$" + Digits)
  If Value < -$7F Or Value > $80
    ProcedureReturn #False
  EndIf
  *OutValue\i = Value
  ProcedureReturn #True
EndProcedure

;- ------------------------------------------------------------
;- Configuracoes / persistencia
;- ------------------------------------------------------------

Procedure.s MamuteCfg_FilePath()
  ProcedureReturn GetPathPart(ProgramFilename()) + "mamute_settings.json"
EndProcedure

Procedure MamuteCfg_Load()
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_Empty
      MamuteCfgCell(Slot, Pagina)\FilePath = ""
      MamuteCfgCell(Slot, Pagina)\FileOffset = 0
    Next
  Next
  MamuteFontName = "Consolas"
  MamuteFontSize = 14
  MamuteFontBold = #True

  Protected FilePath.s = MamuteCfg_FilePath()
  If FileSize(FilePath) <= 0
    ProcedureReturn
  EndIf

  Protected Json = LoadJSON(#PB_Any, FilePath)
  If Not Json
    ProcedureReturn
  EndIf

  Protected Root = JSONValue(Json)
  Protected M
  M = GetJSONMember(Root, "FontName") : If M : MamuteFontName = GetJSONString(M)  : EndIf
  M = GetJSONMember(Root, "FontSize") : If M : MamuteFontSize = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "FontBold") : If M : MamuteFontBold = GetJSONBoolean(M) : EndIf

  Protected CellsElem = GetJSONMember(Root, "Cells")
  If CellsElem
    Protected N = JSONArraySize(CellsElem)
    Protected Idx, Item, S, P
    For Idx = 0 To N - 1
      Item = GetJSONElement(CellsElem, Idx)
      If Item
        S = -1 : P = -1
        M = GetJSONMember(Item, "Slot")  : If M : S = GetJSONInteger(M) : EndIf
        M = GetJSONMember(Item, "Pagina") : If M : P = GetJSONInteger(M) : EndIf
        If S >= 0 And S <= 3 And P >= 0 And P <= 3
          M = GetJSONMember(Item, "Tipo") : If M : MamuteCfgCell(S, P)\Tipo = GetJSONInteger(M) : EndIf
          M = GetJSONMember(Item, "Arquivo") : If M : MamuteCfgCell(S, P)\FilePath = GetJSONString(M) : EndIf
          M = GetJSONMember(Item, "Offset") : If M : MamuteCfgCell(S, P)\FileOffset = GetJSONInteger(M) : EndIf
        EndIf
      EndIf
    Next
  EndIf
  FreeJSON(Json)
EndProcedure

Procedure MamuteCfg_Save()
  Protected Json = CreateJSON(#PB_Any)
  Protected Root = SetJSONObject(JSONValue(Json))
  SetJSONString(AddJSONMember(Root, "FontName"), MamuteFontName)
  SetJSONInteger(AddJSONMember(Root, "FontSize"), MamuteFontSize)
  SetJSONBoolean(AddJSONMember(Root, "FontBold"), MamuteFontBold)
  Protected CellsElem = SetJSONArray(AddJSONMember(Root, "Cells"))

  Protected Slot, Pagina, Elem
  For Slot = 0 To 3
    For Pagina = 0 To 3
      Elem = AddJSONElement(CellsElem)
      SetJSONObject(Elem)
      SetJSONInteger(AddJSONMember(Elem, "Slot"), Slot)
      SetJSONInteger(AddJSONMember(Elem, "Pagina"), Pagina)
      SetJSONInteger(AddJSONMember(Elem, "Tipo"), MamuteCfgCell(Slot, Pagina)\Tipo)
      SetJSONString(AddJSONMember(Elem, "Arquivo"), MamuteCfgCell(Slot, Pagina)\FilePath)
      SetJSONInteger(AddJSONMember(Elem, "Offset"), MamuteCfgCell(Slot, Pagina)\FileOffset)
    Next
  Next

  SaveJSON(Json, MamuteCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Tela "Configurar -> Mamute Assembler..."
;- ------------------------------------------------------------

; Atualiza o texto exibido na linha ItemIdx da lista a partir de
; WorkCells(Slot,Pagina) - usado tanto ao popular a lista inteira quanto ao
; refletir uma edicao pontual (Tipo/Arquivo do celula selecionada).
Procedure MamuteSettings_RefreshRow(List, ItemIdx.i, Slot.i, Pagina.i, Array WorkCells.MamuteMemCell(2))
  SetGadgetItemText(List, ItemIdx, Str(Slot), 0)
  SetGadgetItemText(List, ItemIdx, Str(Pagina), 1)
  SetGadgetItemText(List, ItemIdx, Mamute_PageRangeText(Pagina), 2)
  SetGadgetItemText(List, ItemIdx, Mamute_TipoText(WorkCells(Slot, Pagina)\Tipo), 3)
  Protected ArquivoText.s = WorkCells(Slot, Pagina)\FilePath
  If ArquivoText <> "" And WorkCells(Slot, Pagina)\FileOffset > 0
    ArquivoText + " (ultimos 16KB)"
  EndIf
  SetGadgetItemText(List, ItemIdx, ArquivoText, 4)
EndProcedure

Procedure.b MamuteSettings_TipoUsesFile(Tipo.b)
  ProcedureReturn Bool(Tipo = #MamuteMem_ROM Or Tipo = #MamuteMem_Basic)
EndProcedure

Procedure MamuteSettings_OpenWindow(ParentWindow)
  MamuteCfg_Load()

  ; Copia de trabalho - Salvar/Cancelar decide se isso vira o MamuteCfgCell()
  ; global de verdade, mesmo espirito das outras telas de Configurar desta
  ; IDE (nunca aplica edicao direto no global antes de "Salvar").
  Protected Dim WorkCells.MamuteMemCell(3, 3)
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      WorkCells(Slot, Pagina) = MamuteCfgCell(Slot, Pagina)
    Next
  Next

  Protected WinW = 820, WinH = 620
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Configurar - Mamute Assembler",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf

  TextGadget(#PB_Any, 24, 24, WinW - 48, 40,
            "Configuracao fisica dos 16 blocos de memoria (4 slots x 4 paginas de 16KB) simulados pelo" + Chr(10) +
            "Mamute Assembler. Selecione uma linha pra ajustar o tipo/arquivo abaixo.")

  Protected G_List = ListIconGadget(#PB_Any, 24, 76, WinW - 48, 300, "Slot", 60, #PB_ListIcon_FullRowSelect)
  AddGadgetColumn(G_List, 1, "Pagina", 70)
  AddGadgetColumn(G_List, 2, "Endereco", 110)
  AddGadgetColumn(G_List, 3, "Tipo", 90)
  AddGadgetColumn(G_List, 4, "Arquivo", WinW - 48 - 60 - 70 - 110 - 90)

  For Slot = 0 To 3
    For Pagina = 0 To 3
      AddGadgetItem(G_List, -1, "" + Chr(10) + "" + Chr(10) + "" + Chr(10) + "" + Chr(10) + "")
      MamuteSettings_RefreshRow(G_List, Slot * 4 + Pagina, Slot, Pagina, WorkCells())
    Next
  Next

  Protected EditY = 76 + 300 + 24
  TextGadget(#PB_Any, 24, EditY + 4, 50, 20, "Tipo:")
  Protected G_Tipo = ComboBoxGadget(#PB_Any, 80, EditY, 160, 24)
  AddGadgetItem(G_Tipo, #MamuteMem_Empty, "Vazio")
  AddGadgetItem(G_Tipo, #MamuteMem_RAM, "RAM")
  AddGadgetItem(G_Tipo, #MamuteMem_ROM, "ROM")
  AddGadgetItem(G_Tipo, #MamuteMem_Basic, "BASIC")
  DisableGadget(G_Tipo, #True)

  TextGadget(#PB_Any, 260, EditY + 4, 60, 20, "Arquivo:")
  Protected G_File = StringGadget(#PB_Any, 324, EditY, WinW - 324 - 24 - 64 - 8, 24, "")
  Protected G_FileBrowse = ThemedButton(WinW - 24 - 64, EditY, 64, 24, "...", "")
  DisableGadget(G_File, #True)
  DisableGadget(G_FileBrowse, #True)

  ; Fonte do terminal (MamuteAssemblerGui.pbi) - monoespacada de proposito,
  ; mesma enumeracao ja usada pela fonte do editor de codigo
  ; (EditorCfg_EnumMonospaceFonts(), EditorSettings.pbi).
  Protected FontY = EditY + 48
  TextGadget(#PB_Any, 24, FontY + 4, 140, 20, "Fonte do terminal:")
  Protected G_TermFont = ComboBoxGadget(#PB_Any, 170, FontY, 220, 24)

  Protected NewList TermFonts.s()
  EditorCfg_EnumMonospaceFonts(TermFonts())
  Protected TermFontIndex = -1, TermFontIdx = 0
  ForEach TermFonts()
    AddGadgetItem(G_TermFont, -1, TermFonts())
    If TermFonts() = MamuteFontName
      TermFontIndex = TermFontIdx
    EndIf
    TermFontIdx + 1
  Next
  If TermFontIndex < 0
    AddGadgetItem(G_TermFont, -1, MamuteFontName)
    TermFontIndex = CountGadgetItems(G_TermFont) - 1
  EndIf
  SetGadgetState(G_TermFont, TermFontIndex)

  TextGadget(#PB_Any, 400, FontY + 4, 40, 20, "Tam.")
  Protected G_TermFontSize = StringGadget(#PB_Any, 444, FontY, 50, 24, Str(MamuteFontSize))

  Protected G_TermFontBold = CheckBoxGadget(#PB_Any, 510, FontY + 3, 140, 22, "Negrito")
  SetGadgetState(G_TermFontBold, MamuteFontBold)

  Protected G_Save = ThemedButton(WinW - 256, WinH - 56, 110, 32, "Salvar", Chr(#Icon_Save))
  GadgetToolTip(G_Save, "Salvar")
  Protected G_Cancel = ThemedButton(WinW - 134, WinH - 56, 110, 32, "Cancelar", "")

  Protected SelectedSlot.i = -1, SelectedPagina.i = -1

  Protected Event, Quit = #False, Saved = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_List
            If EventType() = #PB_EventType_Change
              Protected Sel = GetGadgetState(G_List)
              If Sel >= 0
                SelectedSlot = Sel / 4
                SelectedPagina = Sel % 4
                DisableGadget(G_Tipo, #False)
                SetGadgetState(G_Tipo, WorkCells(SelectedSlot, SelectedPagina)\Tipo)
                SetGadgetText(G_File, WorkCells(SelectedSlot, SelectedPagina)\FilePath)
                Protected UsesFile.b = MamuteSettings_TipoUsesFile(WorkCells(SelectedSlot, SelectedPagina)\Tipo)
                DisableGadget(G_File, Bool(Not UsesFile))
                DisableGadget(G_FileBrowse, Bool(Not UsesFile))
              EndIf
            EndIf

          Case G_Tipo
            If SelectedSlot >= 0
              Protected NewTipo.b = GetGadgetState(G_Tipo)
              WorkCells(SelectedSlot, SelectedPagina)\Tipo = NewTipo
              Protected UsesFile2.b = MamuteSettings_TipoUsesFile(NewTipo)
              DisableGadget(G_File, Bool(Not UsesFile2))
              DisableGadget(G_FileBrowse, Bool(Not UsesFile2))
              If Not UsesFile2
                WorkCells(SelectedSlot, SelectedPagina)\FilePath = ""
                SetGadgetText(G_File, "")
              EndIf
              MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
              SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
            EndIf

          Case G_File
            If SelectedSlot >= 0 And EventType() = #PB_EventType_Change
              WorkCells(SelectedSlot, SelectedPagina)\FilePath = GetGadgetText(G_File)
              WorkCells(SelectedSlot, SelectedPagina)\FileOffset = 0 ; digitado a mao - abandona o offset de uma divisao BIOS+BASIC anterior
              MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
              SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
            EndIf

          Case G_FileBrowse
            If SelectedSlot >= 0
              Protected PickPath.s = OpenFileRequester("Selecione o arquivo (ROM/BASIC)", GetGadgetText(G_File),
                                                       "Todos os arquivos (*.*)|*.*", 0)
              If PickPath <> ""
                ; Arquivo de 32KB escolhido pra uma celula ROM na Pagina 0 (BIOS) -
                ; muito comum a BIOS e o BASIC virem combinados num unico arquivo
                ; assim num MSX real. Pergunta antes de assumir - "Nao" trata como
                ; um arquivo qualquer (usa so os primeiros 16KB aqui, nao mexe na
                ; Pagina 1). O usuario continua livre pra trocar o arquivo da
                ; Pagina 1 manualmente depois, mesmo apos o "Sim" auto-preencher.
                Protected HandledAsCombined.b = #False
                If SelectedPagina = 0 And WorkCells(SelectedSlot, 0)\Tipo = #MamuteMem_ROM And FileSize(PickPath) = #Mamute_CombinedBiosBasicSize
                  Protected CombinedAnswer = MessageRequester("BIOS + BASIC combinados?",
                    "Este arquivo tem 32KB - e comum a BIOS e o BASIC virem combinados num unico" + Chr(10) +
                    "arquivo assim num MSX real." + Chr(10) + Chr(10) +
                    "Usar os primeiros 16KB aqui (BIOS, Pagina 0) e os ultimos 16KB na Pagina 1" + Chr(10) +
                    "(BASIC) deste mesmo slot?",
                    #PB_MessageRequester_YesNo | #PB_MessageRequester_Info)
                  If CombinedAnswer = #PB_MessageRequester_Yes
                    WorkCells(SelectedSlot, 0)\FilePath = PickPath
                    WorkCells(SelectedSlot, 0)\FileOffset = 0
                    WorkCells(SelectedSlot, 1)\Tipo = #MamuteMem_Basic
                    WorkCells(SelectedSlot, 1)\FilePath = PickPath
                    WorkCells(SelectedSlot, 1)\FileOffset = #Mamute_PageSize
                    MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + 0, SelectedSlot, 0, WorkCells())
                    MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + 1, SelectedSlot, 1, WorkCells())
                    HandledAsCombined = #True
                  EndIf
                EndIf

                If Not HandledAsCombined
                  WorkCells(SelectedSlot, SelectedPagina)\FilePath = PickPath
                  WorkCells(SelectedSlot, SelectedPagina)\FileOffset = 0
                  MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
                EndIf

                SetGadgetText(G_File, PickPath)
                SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
              EndIf
            EndIf

          Case G_Save
            Saved = #True
            Quit = #True

          Case G_Cancel
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  If Saved
    For Slot = 0 To 3
      For Pagina = 0 To 3
        MamuteCfgCell(Slot, Pagina) = WorkCells(Slot, Pagina)
      Next
    Next
    MamuteFontName = GetGadgetText(G_TermFont)
    Protected TypedSize.i = Val(GetGadgetText(G_TermFontSize))
    If TypedSize < 6 : TypedSize = 6 : EndIf
    If TypedSize > 72 : TypedSize = 72 : EndIf
    MamuteFontSize = TypedSize
    MamuteFontBold = GetGadgetState(G_TermFontBold)
    MamuteCfg_Save()
  EndIf

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
