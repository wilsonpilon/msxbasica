;
; ------------------------------------------------------------
;  Ajuda -> openMSX...: janela navegavel/pesquisavel com os topicos de
;  OpenMsxHelpData.pbi (XIncluded antes deste arquivo) - os 5 manuais
;  originais do openMSX (Setup Guide, User's Manual, Using Diskmanipulator,
;  Controlling openMSX from External Applications, Console Command
;  Reference), convertidos e agrupados por secao.
;
;  Reaproveita a mesma infraestrutura de renderizacao/navegacao ja usada
;  por Ajuda -> Basic Dignified/Nestor Basic (NestorBasicHelpGui.pbi,
;  XIncluded antes deste arquivo): NBHelpGui_SetupStyles/_RenderMarkdown
;  entendem "## " (subtitulo), "**negrito**" e "`codigo`" inline - a mesma
;  marcacao usada em OpenMsxHelpData.pbi. Layout e navegacao (busca/
;  historico/arvore) identicos as outras 3 janelas de Ajuda, por
;  consistencia - "navegar entre as opcoes" aqui e via arvore (agrupada
;  por manual/secao) + busca por titulo/grupo, mesmo mecanismo de sempre
;  (a mini-Markdown nao tem hyperlink clicavel dentro do corpo).
; ------------------------------------------------------------
;

#OMSXHelpGui_ShortcutBack = 4

Global OMSXHelpGui_WinID.i = -1

Structure OMSXHelpRow
  IsGroup.b
  RefIndex.i    ; indice em OMSXHelp_Topics(); -1 para linha de grupo
  Label.s
  SearchKey.s   ; minusculo, vazio para linhas de grupo (nunca batem em busca)
EndStructure

Global NewList OMSXHelpGui_Rows.OMSXHelpRow()
Global OMSXHelpGui_RowsBuilt.b = #False

Procedure OMSXHelpGui_AddRow(IsGroup.b, RefIndex.i, Label.s, SearchKey.s)
  AddElement(OMSXHelpGui_Rows())
  OMSXHelpGui_Rows()\IsGroup = IsGroup
  OMSXHelpGui_Rows()\RefIndex = RefIndex
  OMSXHelpGui_Rows()\Label = Label
  OMSXHelpGui_Rows()\SearchKey = SearchKey
EndProcedure

; Monta a lista achatada uma unica vez por sessao: um cabecalho de grupo
; toda vez que o campo Grupo muda, seguido dos topicos daquele grupo.
Procedure OMSXHelpGui_BuildRows()
  If OMSXHelpGui_RowsBuilt
    ProcedureReturn
  EndIf
  OMSXHelpGui_RowsBuilt = #True

  OMSXHelp_BuildData()

  Protected Idx.i = -1, CurrentGrupo.s = ""
  ForEach OMSXHelp_Topics()
    Idx + 1
    If OMSXHelp_Topics()\Grupo <> CurrentGrupo
      CurrentGrupo = OMSXHelp_Topics()\Grupo
      OMSXHelpGui_AddRow(#True, -1, CurrentGrupo, "")
    EndIf
    OMSXHelpGui_AddRow(#False, Idx, OMSXHelp_Topics()\Titulo,
                        LCase(OMSXHelp_Topics()\Titulo + " " + OMSXHelp_Topics()\Grupo))
  Next
EndProcedure

Procedure OMSXHelpGui_PopulateTree(Tree)
  ClearGadgetItems(Tree)
  Protected RowIdx = -1
  ForEach OMSXHelpGui_Rows()
    RowIdx + 1
    AddGadgetItem(Tree, -1, OMSXHelpGui_Rows()\Label, 0, Bool(Not OMSXHelpGui_Rows()\IsGroup))
    SetGadgetItemData(Tree, CountGadgetItems(Tree) - 1, RowIdx)
  Next
EndProcedure

Procedure OMSXHelpGui_FilterTree(Tree, SearchText.s)
  Protected Needle.s = LCase(Trim(SearchText))
  If Needle = ""
    OMSXHelpGui_PopulateTree(Tree)
    ProcedureReturn
  EndIf

  ClearGadgetItems(Tree)
  Protected RowIdx = -1
  ForEach OMSXHelpGui_Rows()
    RowIdx + 1
    If Not OMSXHelpGui_Rows()\IsGroup And FindString(OMSXHelpGui_Rows()\SearchKey, Needle) > 0
      AddGadgetItem(Tree, -1, OMSXHelpGui_Rows()\Label, 0, 0)
      SetGadgetItemData(Tree, CountGadgetItems(Tree) - 1, RowIdx)
    EndIf
  Next
EndProcedure

Procedure OMSXHelpGui_ShowRow(Sci, RowIdx.i)
  If Not SelectElement(OMSXHelpGui_Rows(), RowIdx)
    ProcedureReturn
  EndIf
  If OMSXHelpGui_Rows()\IsGroup
    NBHelpGui_RenderMarkdown(Sci, "## " + OMSXHelpGui_Rows()\Label + #CRLF$ + #CRLF$ +
                                   "Selecione um topico na lista ao lado.")
  Else
    NBHelpGui_RenderMarkdown(Sci, OMSXHelp_FullBody(OMSXHelpGui_Rows()\RefIndex))
  EndIf
EndProcedure

Procedure OpenMsxHelp_OpenWindow(ParentWindow)
  If OMSXHelpGui_WinID <> -1 And IsWindow(OMSXHelpGui_WinID)
    SetActiveWindow(OMSXHelpGui_WinID)
    ProcedureReturn
  EndIf

  OMSXHelpGui_BuildRows()

  Protected WinW = 900, WinH = 600
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Ajuda - openMSX",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf
  App_ApplyWindowIcon(Win)
  OMSXHelpGui_WinID = Win

  Protected TopY = 15
  TextGadget(#PB_Any, 15, TopY + 4, 55, 20, "Buscar:")
  Protected G_Search = StringGadget(#PB_Any, 75, TopY, 300, 24, "")
  GadgetToolTip(G_Search, "Filtra por titulo ou grupo (manual/secao)")
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

  OMSXHelpGui_PopulateTree(G_Tree)
  AddKeyboardShortcut(Win, #PB_Shortcut_Alt | #PB_Shortcut_Left, #OMSXHelpGui_ShortcutBack)

  NewList History.i()
  Protected CurrentRow.i = -1
  Protected BackIdx.i, TreeScanIdx.i

  ; Macro (nao Procedure) de proposito, mesma razao dos outros tres Ajuda
  ; -> ...: precisa enxergar direto as variaveis locais desta janela
  ; (G_Tree, G_Content, History(), CurrentRow).
  Macro OMSXHelpGui_DoGoBack
    If ListSize(History()) > 0
      LastElement(History())
      BackIdx = History()
      DeleteElement(History())
      If BackIdx >= 0
        OMSXHelpGui_ShowRow(G_Content, BackIdx)
        CurrentRow = BackIdx
        For TreeScanIdx = 0 To CountGadgetItems(G_Tree) - 1
          If GetGadgetItemData(G_Tree, TreeScanIdx) = BackIdx
            SetGadgetState(G_Tree, TreeScanIdx)
            Break
          EndIf
        Next
      EndIf
    EndIf
  EndMacro

  ; Linha 0 e sempre um cabecalho de grupo; a primeira linha de conteudo de
  ; verdade fica na linha 1.
  If CountGadgetItems(G_Tree) > 1
    OMSXHelpGui_ShowRow(G_Content, 1)
    CurrentRow = 1
    SetGadgetState(G_Tree, 1)
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
                Protected RowIdx = GetGadgetItemData(G_Tree, Sel)
                If RowIdx <> CurrentRow
                  AddElement(History()) : History() = CurrentRow
                  OMSXHelpGui_ShowRow(G_Content, RowIdx)
                  CurrentRow = RowIdx
                EndIf
              EndIf
            EndIf

          Case G_Search
            If EventType() = #PB_EventType_Change
              OMSXHelpGui_FilterTree(G_Tree, GetGadgetText(G_Search))
              If Trim(GetGadgetText(G_Search)) <> ""
                SetGadgetText(G_Status, Str(CountGadgetItems(G_Tree)) + " resultado(s)")
              Else
                SetGadgetText(G_Status, "")
              EndIf
            EndIf

          Case G_ClearSearch
            SetGadgetText(G_Search, "")
            OMSXHelpGui_FilterTree(G_Tree, "")
            SetGadgetText(G_Status, "")

          Case G_Back
            OMSXHelpGui_DoGoBack

          Case G_Close
            Quit = #True

        EndSelect

      Case #PB_Event_Menu
        If EventMenu() = #OMSXHelpGui_ShortcutBack
          OMSXHelpGui_DoGoBack
        EndIf

      Case #PB_Event_CloseWindow
        Quit = #True

    EndSelect
  Until Quit

  OMSXHelpGui_WinID = -1
  CloseWindow(Win)
EndProcedure
