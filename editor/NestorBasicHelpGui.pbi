;
; ------------------------------------------------------------
;  Ajuda -> Nestor Basic...: janela navegavel/pesquisavel com as 87 funcoes
;  do NestorBASIC + introducao, montada sobre a base de dados de
;  NestorBasicHelpData.pbi (XIncludeFile'd antes deste arquivo).
;
;  Layout: caixa de busca no topo (filtra por nome, numero de funcao ou
;  grupo - CountGadgetItems() apos filtrar mostra quantos bateram);
;  TreeGadget a esquerda (grupos = secoes do manual original, funcoes como
;  filhos, numeradas); ScintillaGadget de conteudo a direita, so leitura,
;  com um "mini-renderizador" Markdown propio (NBHelpGui_RenderMarkdown) -
;  entende so "## " (subtitulo), "**negrito**" e "`codigo`" inline, que e
;  exatamente (e so) a marcacao usada em NestorBasicHelpData.pbi.
;
;  Navegacao: clicar/setas na arvore troca de topico e empilha o anterior
;  num historico; Alt+Seta-esquerda (ou o botao "Voltar") desempilha e volta
;  um topico. "Voltar uma secao" fica de graca no proprio TreeGadget nativo
;  (seta esquerda sobre uma funcao move a selecao pro grupo-pai, exatamente
;  como qualquer TreeView do Windows) - por isso NAO usamos Backspace como
;  atalho de historico: essa tecla precisa continuar apagando texto
;  normalmente dentro da caixa de busca.
;
;  Esta janela e nao-modal de proposito (ao contrario de Sprite/Alfabeto/
;  Disco): e uma janela de referencia, o usuario deve poder deixar aberta e
;  continuar editando codigo ao lado.
; ------------------------------------------------------------
;

#NBHelpGui_Style_Default = 0
#NBHelpGui_Style_H2      = 1
#NBHelpGui_Style_Bold    = 2
#NBHelpGui_Style_Code    = 3

#NBHelpGui_ShortcutBack = 1

Global NBHelpGui_WinID.i = -1

Procedure NBHelpGui_SetupStyles(Sci)
  Protected *FontName = UTF8(EditorCfg\FontName)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #STYLE_DEFAULT, RGB(30, 30, 30))
  ScintillaSendMessage(Sci, #SCI_STYLESETBACK, #STYLE_DEFAULT, RGB(255, 255, 255))
  ScintillaSendMessage(Sci, #SCI_STYLESETFONT, #STYLE_DEFAULT, *FontName)
  ScintillaSendMessage(Sci, #SCI_STYLESETSIZE, #STYLE_DEFAULT, EditorCfg\FontSize)
  ScintillaSendMessage(Sci, #SCI_STYLECLEARALL)
  FreeMemory(*FontName)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #NBHelpGui_Style_H2, RGB(20, 60, 120))
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #NBHelpGui_Style_H2, 1)
  ScintillaSendMessage(Sci, #SCI_STYLESETSIZE, #NBHelpGui_Style_H2, EditorCfg\FontSize + 2)

  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #NBHelpGui_Style_Bold, 1)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #NBHelpGui_Style_Code, RGB(140, 40, 120))
  Protected *MonoFont = UTF8("Consolas")
  ScintillaSendMessage(Sci, #SCI_STYLESETFONT, #NBHelpGui_Style_Code, *MonoFont)
  FreeMemory(*MonoFont)

  ScintillaSendMessage(Sci, #SCI_SETCARETFORE, RGB(255, 255, 255)) ; esconde o caret (so leitura)
  ScintillaSendMessage(Sci, #SCI_SETWRAPMODE, #SC_WRAP_WORD)
EndProcedure

; Aplica um estilo a proxima faixa de bytes (mesma ideia de EmitRun() em
; BadigEditor.pb, reimplementada aqui pra nao depender de ordem de
; resolucao entre arquivos XIncluded).
Procedure NBHelpGui_EmitRun(Sci, Text.s, Style)
  Protected ByteLen = StringByteLength(Text, #PB_UTF8)
  If ByteLen > 0
    ScintillaSendMessage(Sci, #SCI_SETSTYLING, ByteLen, Style)
  EndIf
EndProcedure

; "Mini Markdown": entende so linhas "## " (vira #NBHelpGui_Style_H2, sem o
; prefixo), "**texto**" (negrito inline) e `texto` (codigo inline) - nada
; alem disso, de proposito (ver nota no topo do arquivo). Monta o texto puro
; (sem os marcadores) e a lista de faixas de estilo juntos, na mesma
; passada, pra nao precisar recalcular deslocamento de bytes depois.
Procedure NBHelpGui_RenderMarkdown(Sci, Markdown.s)
  Protected PlainText.s = ""
  NewList RunStyle.i()
  NewList RunText.s()

  Protected TotalLines = CountString(Markdown, #CRLF$) + 1
  Protected LineIdx, Line.s, FirstLine.b = #True

  For LineIdx = 1 To TotalLines
    Line = StringField(Markdown, LineIdx, #CRLF$)
    If Not FirstLine
      AddElement(RunStyle()) : RunStyle() = #NBHelpGui_Style_Default
      AddElement(RunText())  : RunText()  = #CRLF$
      PlainText + #CRLF$
    EndIf
    FirstLine = #False

    Protected IsHeading.b = #False
    Protected Body.s = Line
    If Left(Line, 3) = "## "
      IsHeading = #True
      Body = Mid(Line, 4)
    EndIf

    Protected Pos = 1, BodyLen = Len(Body)
    Protected CurStyle = #NBHelpGui_Style_Default
    If IsHeading : CurStyle = #NBHelpGui_Style_H2 : EndIf
    Protected Buf.s = "", InBold.b = #False, InCode.b = #False

    While Pos <= BodyLen
      If Not IsHeading And Mid(Body, Pos, 2) = "**"
        If Buf <> ""
          AddElement(RunStyle()) : RunStyle() = CurStyle
          AddElement(RunText())  : RunText()  = Buf
          PlainText + Buf
          Buf = ""
        EndIf
        If InBold : InBold = #False : Else : InBold = #True : EndIf
        If InBold : CurStyle = #NBHelpGui_Style_Bold : Else : CurStyle = #NBHelpGui_Style_Default : EndIf
        Pos + 2
      ElseIf Not IsHeading And Mid(Body, Pos, 1) = "`"
        If Buf <> ""
          AddElement(RunStyle()) : RunStyle() = CurStyle
          AddElement(RunText())  : RunText()  = Buf
          PlainText + Buf
          Buf = ""
        EndIf
        If InCode : InCode = #False : Else : InCode = #True : EndIf
        If InCode : CurStyle = #NBHelpGui_Style_Code : Else : CurStyle = #NBHelpGui_Style_Default : EndIf
        Pos + 1
      Else
        Buf + Mid(Body, Pos, 1)
        Pos + 1
      EndIf
    Wend

    If Buf <> ""
      AddElement(RunStyle()) : RunStyle() = CurStyle
      AddElement(RunText())  : RunText()  = Buf
      PlainText + Buf
    EndIf
  Next

  Protected *Buffer = UTF8(PlainText)
  ScintillaSendMessage(Sci, #SCI_SETREADONLY, 0)
  ScintillaSendMessage(Sci, #SCI_SETTEXT, 0, *Buffer)
  FreeMemory(*Buffer)

  ScintillaSendMessage(Sci, #SCI_STARTSTYLING, 0, 0)
  ResetList(RunStyle()) : ResetList(RunText())
  While NextElement(RunStyle()) And NextElement(RunText())
    NBHelpGui_EmitRun(Sci, RunText(), RunStyle())
  Wend

  ScintillaSendMessage(Sci, #SCI_SETREADONLY, 1)
  ScintillaSendMessage(Sci, #SCI_EMPTYUNDOBUFFER)
  ScintillaSendMessage(Sci, #SCI_GOTOPOS, 0)
EndProcedure

; Arvore completa: grupos (identificados por um topico Numero=-1 cujo
; Titulo == Grupo) como nos de nivel 0, funcoes (e topicos avulsos, como a
; Introducao, antes do 1o grupo) como nivel 1 ou 0 conforme o caso. O indice
; do topico em NBHelp_Topics() fica guardado em cada item via
; SetGadgetItemData(), pra achar de volta com SelectElement() ao clicar.
Procedure NBHelpGui_PopulateTree(Tree)
  ClearGadgetItems(Tree)
  Protected Idx = -1
  Protected InsideGroup.b = #False

  ForEach NBHelp_Topics()
    Idx + 1
    If NBHelp_Topics()\Numero = -1 And NBHelp_Topics()\Titulo = NBHelp_Topics()\Grupo
      AddGadgetItem(Tree, -1, NBHelp_Topics()\Titulo, 0, 0)
      SetGadgetItemData(Tree, CountGadgetItems(Tree) - 1, Idx)
      InsideGroup = #True
    Else
      Protected Label.s = NBHelp_Topics()\Titulo
      If NBHelp_Topics()\Numero >= 0
        Label = Str(NBHelp_Topics()\Numero) + " - " + Label
      EndIf
      Protected SubLevel = 0
      If InsideGroup : SubLevel = 1 : EndIf
      AddGadgetItem(Tree, -1, Label, 0, SubLevel)
      SetGadgetItemData(Tree, CountGadgetItems(Tree) - 1, Idx)
    EndIf
  Next
EndProcedure

; Lista filtrada (sem hierarquia - so uma lista plana dos topicos que
; batem, com o grupo entre parenteses pra dar contexto). SearchText vazio
; volta pra arvore completa agrupada.
Procedure NBHelpGui_FilterTree(Tree, SearchText.s)
  Protected Needle.s = LCase(Trim(SearchText))
  If Needle = ""
    NBHelpGui_PopulateTree(Tree)
    ProcedureReturn
  EndIf

  ClearGadgetItems(Tree)
  Protected Idx = -1
  ForEach NBHelp_Topics()
    Idx + 1
    If FindString(NBHelp_SearchKey(@NBHelp_Topics()), Needle) > 0
      Protected Label.s = NBHelp_Topics()\Titulo
      If NBHelp_Topics()\Numero >= 0
        Label = Str(NBHelp_Topics()\Numero) + " - " + Label + " (" + NBHelp_Topics()\Grupo + ")"
      EndIf
      AddGadgetItem(Tree, -1, Label, 0, 0)
      SetGadgetItemData(Tree, CountGadgetItems(Tree) - 1, Idx)
    EndIf
  Next
EndProcedure

Procedure NestorBasicHelp_OpenWindow(ParentWindow)
  If NBHelpGui_WinID <> -1 And IsWindow(NBHelpGui_WinID)
    SetActiveWindow(NBHelpGui_WinID)
    ProcedureReturn
  EndIf

  NBHelp_BuildData()

  Protected WinW = 900, WinH = 600
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Ajuda - NestorBASIC",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf
  App_ApplyWindowIcon(Win)
  NBHelpGui_WinID = Win

  Protected TopY = 15
  TextGadget(#PB_Any, 15, TopY + 4, 55, 20, "Buscar:")
  Protected G_Search = StringGadget(#PB_Any, 75, TopY, 300, 24, "")
  GadgetToolTip(G_Search, "Filtra por nome, numero de funcao ou grupo")
  Protected G_ClearSearch = ButtonGadget(#PB_Any, 380, TopY, 80, 24, "Limpar")
  Protected G_Status = TextGadget(#PB_Any, 470, TopY + 4, WinW - 490, 20, "")

  Protected BottomBarH = 40
  Protected TreeY = TopY + 34
  Protected TreeH = WinH - TreeY - BottomBarH - 15
  Protected TreeW = 280
  Protected G_Tree = TreeGadget(#PB_Any, 15, TreeY, TreeW, TreeH)
  Protected G_Content = ScintillaGadget(#PB_Any, 15 + TreeW + 15, TreeY, WinW - TreeW - 45, TreeH, 0)
  NBHelpGui_SetupStyles(G_Content)

  Protected G_Back = ButtonGadget(#PB_Any, 15, WinH - BottomBarH, 160, 28, "<- Voltar (Alt+Esquerda)")
  Protected G_Close = ButtonGadget(#PB_Any, WinW - 115, WinH - BottomBarH, 100, 28, "Fechar")

  NBHelpGui_PopulateTree(G_Tree)
  AddKeyboardShortcut(Win, #PB_Shortcut_Alt | #PB_Shortcut_Left, #NBHelpGui_ShortcutBack)

  NewList History.i()
  Protected CurrentTopic.i = -1
  Protected BackIdx.i, TreeScanIdx.i

  ; Macro (nao Procedure) de proposito: precisa acessar direto as variaveis
  ; locais desta janela (G_Tree, G_Content, History(), CurrentTopic) sem ter
  ; que passar tudo isso por parametro/ponteiro pra frente e pra tras.
  Macro NBHelpGui_DoGoBack
    If ListSize(History()) > 0
      LastElement(History())
      BackIdx = History()
      DeleteElement(History())
      If BackIdx >= 0 And SelectElement(NBHelp_Topics(), BackIdx)
        NBHelpGui_RenderMarkdown(G_Content, NBHelp_FullBody(@NBHelp_Topics()))
        CurrentTopic = BackIdx
        For TreeScanIdx = 0 To CountGadgetItems(G_Tree) - 1
          If GetGadgetItemData(G_Tree, TreeScanIdx) = BackIdx
            SetGadgetState(G_Tree, TreeScanIdx)
            Break
          EndIf
        Next
      EndIf
    EndIf
  EndMacro

  If SelectElement(NBHelp_Topics(), 0)
    NBHelpGui_RenderMarkdown(G_Content, NBHelp_FullBody(@NBHelp_Topics()))
    CurrentTopic = 0
    SetGadgetState(G_Tree, 0)
  EndIf

  Protected Event, Quit = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event

      Case #PB_Event_Gadget
        Select EventGadget()

          Case G_Tree
            If EventType() = #PB_EventType_Change
              Protected Sel = GetGadgetState(G_Tree)
              If Sel >= 0
                Protected TopicIdx = GetGadgetItemData(G_Tree, Sel)
                If TopicIdx <> CurrentTopic
                  AddElement(History()) : History() = CurrentTopic
                  If SelectElement(NBHelp_Topics(), TopicIdx)
                    NBHelpGui_RenderMarkdown(G_Content, NBHelp_FullBody(@NBHelp_Topics()))
                    CurrentTopic = TopicIdx
                  EndIf
                EndIf
              EndIf
            EndIf

          Case G_Search
            If EventType() = #PB_EventType_Change
              NBHelpGui_FilterTree(G_Tree, GetGadgetText(G_Search))
              If Trim(GetGadgetText(G_Search)) <> ""
                SetGadgetText(G_Status, Str(CountGadgetItems(G_Tree)) + " resultado(s)")
              Else
                SetGadgetText(G_Status, "")
              EndIf
            EndIf

          Case G_ClearSearch
            SetGadgetText(G_Search, "")
            NBHelpGui_FilterTree(G_Tree, "")
            SetGadgetText(G_Status, "")

          Case G_Back
            NBHelpGui_DoGoBack

          Case G_Close
            Quit = #True

        EndSelect

      Case #PB_Event_Menu
        If EventMenu() = #NBHelpGui_ShortcutBack
          NBHelpGui_DoGoBack
        EndIf

      Case #PB_Event_CloseWindow
        Quit = #True

    EndSelect
  Until Quit

  NBHelpGui_WinID = -1
  CloseWindow(Win)
EndProcedure
