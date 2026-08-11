;
; ------------------------------------------------------------
;  Executar -> Mamute Assembler...: janela "monitor" inspirada nos antigos
;  montadores de linha de comando dos computadores de 8 bits dos anos 80 -
;  pedido explicito do usuario, referencia direta o MegaAssembler dele (tem
;  o manual original, mas so quer portar um subconjunto pequeno de comandos,
;  aos poucos). Nada de telas com campo/botao pra cada opcao: um prompt
;  "MON>" aceita comandos digitados, um de cada vez - ver Ajuda -> Mamute
;  Assembler... (MamuteHelpData.pbi/MamuteHelpGui.pbi, cresce junto com
;  MamuteGui_Dispatch() abaixo, um comando novo por sessao).
;
;  Primeira leva: BA/QUIT (fecha a janela). Segunda leva: PAGE (mostra/troca
;  qual SLOT fisico esta comutado em cada uma das 4 paginas visiveis pelo
;  Z80 agora mesmo - MamutePageMap(), MamuteSupport.pbi, XIncludeFile'd
;  antes deste arquivo, tambem tem o modelo de memoria 4x4x16KB e a tela
;  "Configurar -> Mamute Assembler..."). Terceira leva: DM (Despejo de
;  Memoria) - abre MamuteDumpGui.pbi (tambem XIncludeFile'd antes deste
;  arquivo), primeiro comando que realmente le/escreve a memoria simulada.
;  Quarta leva (esta sessao): ZAP - "muito parecido com o DM", so que edita
;  SETORES de uma imagem de disco (.dsk) em vez da memoria do MSX - abre
;  MamuteZapGui.pbi. Mais comandos entram aos poucos, sessao a sessao.
;
;  Visual "terminal": fundo preto, texto monoespacado verde, ignorando o
;  tema da IDE de proposito (SetGadgetColor()/SetGadgetFont() explicitos,
;  nao SetWindowColor(..., Color_AppBg) do resto da IDE) - e pra lembrar um
;  terminal de verdade, nao mais um dialogo comum. Unico cuidado real:
;  App_StyleChildCallback (BadigEditor.pb) forca a fonte Segoe UI em TODO
;  controle nativo de QUALQUER janela no primeiro WM_PAINT dela (nao tem
;  como desligar isso por janela) - MamuteGui_ApplyRetroFont() e chamada de
;  novo logo antes do loop de eventos pra garantir que a fonte monoespacada
;  vence essa corrida.
; ------------------------------------------------------------
;

#MamuteGui_EnterShortcut = 9101

Global MamuteGui_Font.i = -1

; Recarrega a fonte a partir de MamuteFontName/Size/Bold (MamuteSupport.pbi,
; "Configurar -> Mamute Assembler...") toda vez que a janela abre - nao
; reaproveita entre aberturas (ao contrario da versao anterior) porque o
; usuario pode ter trocado a configuracao desde a ultima vez; libera a fonte
; anterior antes pra nao vazar um HFONT a cada abertura.
Procedure MamuteGui_EnsureFont()
  If MamuteGui_Font <> -1
    FreeFont(MamuteGui_Font)
  EndIf
  Protected Style.i = 0
  If MamuteFontBold : Style = #PB_Font_Bold : EndIf
  MamuteGui_Font = LoadFont(#PB_Any, MamuteFontName, MamuteFontSize, Style)
EndProcedure

; Acrescenta Text ao log (Accum recebido/devolvido explicitamente, mesmo
; motivo de OMSXGui_AppendLog() em OpenMSXConsoleGui.pbi - nao confiar no
; EditorGadget "lembrar" o proprio conteudo) e rola pro fim.
Procedure.s MamuteGui_AppendLog(G_Log, Accum.s, Text.s)
  If Accum <> ""
    Accum + Chr(13) + Chr(10)
  EndIf
  Accum + Text
  SetGadgetText(G_Log, Accum)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    SendMessage_(GadgetID(G_Log), #EM_LINESCROLL, 0, 999999)
  CompilerEndIf
  ProcedureReturn Accum
EndProcedure

Structure MamuteGui_State
  LogAccum.s
  ShouldQuit.b
EndStructure

; Mostra o mapeamento ATIVO agora (MamutePageMap(), MamuteSupport.pbi) - uma
; linha por pagina, endereco real + slot comutado ali. Usado tanto por
; "PAGE ?" quanto logo apos qualquer "PAGE"/"PAGE X,Y,Z,W" bem-sucedido
; (feedback imediato, mesmo espirito de monitores de verdade ecoarem o
; estado apos um SET).
Procedure.s MamuteGui_ShowPageMap(G_Log, Accum.s)
  Protected Pagina.i
  For Pagina = 0 To 3
    Accum = MamuteGui_AppendLog(G_Log, Accum, "PAGE" + Str(Pagina) + "(" + Mamute_PageRangeText(Pagina) +
                                              ") SLOT " + Str(MamutePageMap(Pagina)))
  Next
  ProcedureReturn Accum
EndProcedure

; Token.s precisa ser 1+ digitos representando um numero de slot valido
; (0-3) - usado pra validar cada um dos 4 argumentos de "PAGE X,Y,Z,W".
Procedure.b MamuteGui_IsValidSlotToken(Token.s)
  If Token = ""
    ProcedureReturn #False
  EndIf
  Protected i
  For i = 1 To Len(Token)
    If Mid(Token, i, 1) < "0" Or Mid(Token, i, 1) > "9"
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn Bool(Val(Token) >= 0 And Val(Token) <= 3)
EndProcedure

; PAGE (Args=""): coloca todas as 4 paginas no slot marcado como RAM.
; PAGE ? (Args="?"): so mostra o mapeamento ativo, sem mexer em nada.
; PAGE X,Y,Z,W (Args="X,Y,Z,W"): troca o mapeamento ativo pros 4 slots
; informados (pagina 0=X, 1=Y, 2=Z, 3=W). Qualquer outra forma = erro.
Procedure MamuteGui_CmdPage(G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    Protected RamSlot.i = Mamute_FindRamSlot()
    If RamSlot = -1
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?NENHUM SLOT DE RAM CONFIGURADO")
      ProcedureReturn
    EndIf
    Protected P.i
    For P = 0 To 3
      MamutePageMap(P) = RamSlot
    Next
    *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
    ProcedureReturn
  EndIf

  If Args = "?"
    *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
    ProcedureReturn
  EndIf

  If CountString(Args, ",") <> 3
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Dim ParsedSlots.i(3)
  Protected Idx.i, Token.s
  For Idx = 0 To 3
    Token = Trim(StringField(Args, Idx + 1, ","))
    If Not MamuteGui_IsValidSlotToken(Token)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    ParsedSlots(Idx) = Val(Token)
  Next

  For Idx = 0 To 3
    MamutePageMap(Idx) = ParsedSlots(Idx)
  Next
  *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
EndProcedure

; DM <endereco>[,<deslocamento>] - abre a janela de despejo/edicao de
; memoria (MamuteDumpGui.pbi, XIncludeFile'd antes deste arquivo) no
; endereco (hexa - "os enderecos em hexa sao o padrao de entrada de todos
; os comandos", pedido explicito do usuario) informado, com o deslocamento
; ASCII opcional (tambem hexa, com sinal, -7Fh a 80h). Vazio = sintaxe
; invalida (endereco e obrigatorio); deslocamento ausente = 0.
Procedure MamuteGui_CmdDm(Win, G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected AddrToken.s, OffsetToken.s
  Protected CommaPos.i = FindString(Args, ",")
  If CommaPos > 0
    AddrToken = Trim(Left(Args, CommaPos - 1))
    OffsetToken = Trim(Mid(Args, CommaPos + 1))
  Else
    AddrToken = Trim(Args)
    OffsetToken = ""
  EndIf

  Protected Addr.i
  If Not Mamute_ParseHexAddr(AddrToken, @Addr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected DmOffset.i = 0
  If OffsetToken <> ""
    If Not Mamute_ParseHexOffset(OffsetToken, @DmOffset)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  MamuteDump_Open(Win, Addr, DmOffset)
EndProcedure

; ZAP <setor inicial>[,<deslocamento>] - "muito parecido com o DM", pedido
; explicito do usuario, so que edita SETORES de uma imagem de disco (.dsk)
; em vez da memoria simulada do MSX - pede o arquivo (MamuteZapGui.pbi,
; XIncludeFile'd antes deste arquivo) antes de abrir a grade. <setor
; inicial> tambem em hexa (mesma regra do DM); <deslocamento> identico ao
; do DM (opcional, hexa com sinal, -7Fh a 80h).
Procedure MamuteGui_CmdZap(Win, G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected SectorToken.s, OffsetToken.s
  Protected CommaPos.i = FindString(Args, ",")
  If CommaPos > 0
    SectorToken = Trim(Left(Args, CommaPos - 1))
    OffsetToken = Trim(Mid(Args, CommaPos + 1))
  Else
    SectorToken = Trim(Args)
    OffsetToken = ""
  EndIf

  Protected Sector.i
  If Not Mamute_ParseHexAddr(SectorToken, @Sector)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected ZapOffset.i = 0
  If OffsetToken <> ""
    If Not Mamute_ParseHexOffset(OffsetToken, @ZapOffset)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  MamuteZap_Open(Win, Sector, ZapOffset)
EndProcedure

; Um comando digitado por chamada - primeiro token (ate o espaco) e o verbo,
; o resto (se houver) sao os argumentos crus, cada comando decide sozinho
; como interpretar os proprios argumentos. Select isolado de proposito -
; cada comando novo (ver Ajuda -> Mamute Assembler...) vira so mais um Case
; aqui, sem mexer no resto da janela.
Procedure MamuteGui_Dispatch(Win, G_Log, *State.MamuteGui_State, Cmd.s)
  Protected Trimmed.s = Trim(Cmd)
  Protected SpacePos.i = FindString(Trimmed, " ")
  Protected Verb.s, Args.s
  If SpacePos > 0
    Verb = UCase(Left(Trimmed, SpacePos - 1))
    Args = Trim(Mid(Trimmed, SpacePos + 1))
  Else
    Verb = UCase(Trimmed)
    Args = ""
  EndIf

  Select Verb
    Case "BA", "QUIT"
      *State\ShouldQuit = #True

    Case "PAGE"
      MamuteGui_CmdPage(G_Log, *State, Args)

    Case "DM"
      MamuteGui_CmdDm(Win, G_Log, *State, Args)

    Case "ZAP"
      MamuteGui_CmdZap(Win, G_Log, *State, Args)

    Default
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?COMANDO INVALIDO")
  EndSelect
EndProcedure

Procedure MamuteAssembler_OpenWindow(ParentWindow)
  MamuteCfg_Load()
  MamuteGui_EnsureFont() ; depende de MamuteFontName/Size/Bold, ja carregados acima
  Mamute_ResetPageMapToDefault() ; "estado de boot" - ver MamuteSupport.pbi

  Protected WinW = 720, WinH = 480
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Mamute Assembler",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered, #True, #False)
  If Not Win
    ProcedureReturn
  EndIf

  Protected ColFront = RGB(60, 220, 90), ColBack = RGB(0, 0, 0)
  SetWindowColor(Win, ColBack)

  Protected G_Log = EditorGadget(#PB_Any, 16, 16, WinW - 32, WinH - 72, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
  SetGadgetColor(G_Log, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Log, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Log, FontID(MamuteGui_Font))

  Protected G_Prompt = TextGadget(#PB_Any, 16, WinH - 46, 64, 24, "MON>")
  SetGadgetColor(G_Prompt, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Prompt, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Prompt, FontID(MamuteGui_Font))

  Protected G_Input = StringGadget(#PB_Any, 80, WinH - 48, WinW - 96, 26, "")
  SetGadgetColor(G_Input, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Input, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Input, FontID(MamuteGui_Font))

  ; Reaplica a fonte - ver nota no topo do arquivo sobre App_StyleChildCallback.
  SetGadgetFont(G_Log, FontID(MamuteGui_Font))
  SetGadgetFont(G_Prompt, FontID(MamuteGui_Font))
  SetGadgetFont(G_Input, FontID(MamuteGui_Font))

  Protected State.MamuteGui_State
  State\LogAccum = MamuteGui_AppendLog(G_Log, "", "MAMUTE ASSEMBLER")
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "Digite BA ou QUIT para encerrar.")
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "")
  State\LogAccum = MamuteGui_ShowPageMap(G_Log, State\LogAccum)
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "")

  SetActiveGadget(G_Input)
  AddKeyboardShortcut(Win, #PB_Shortcut_Return, #MamuteGui_EnterShortcut)

  Protected Event, Quit = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Menu
        If EventMenu() = #MamuteGui_EnterShortcut
          Protected Cmd.s = Trim(GetGadgetText(G_Input))
          If Cmd <> ""
            State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "MON>" + Cmd)
            SetGadgetText(G_Input, "")
            MamuteGui_Dispatch(Win, G_Log, @State, Cmd)
            If State\ShouldQuit
              Quit = #True
            EndIf
          EndIf
        EndIf

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
