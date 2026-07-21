;
; ------------------------------------------------------------
;  Download de fontes Nerd Fonts (https://www.nerdfonts.com/font-downloads)
;  A pagina e estatica (server-side), entao a lista de fontes disponiveis e
;  obtida em tempo real via uma requisicao HTTP simples (ReceiveHTTPMemory) +
;  expressao regular sobre o HTML - sem precisar embutir/manter uma lista fixa
;  de nomes ou a versao do release do GitHub (ex.: v3.4.0) no codigo.
;  Cada .zip baixado e descompactado direto na pasta de destino (reaproveita
;  BadigCfg_ExtractZip(), definida em BadigSettings.pbi) e depois apagado -
;  os arquivos das fontes (.ttf/.otf) ficam prontos para uso em "Pasta de
;  fontes customizadas" (ver EditorSettings.pbi).
; ------------------------------------------------------------
;

#NerdFonts_PageUrl = "https://www.nerdfonts.com/font-downloads"

Structure NerdFontEntry
  Name.s
  Url.s
EndStructure

Global NewList NerdFontEntries.NerdFontEntry()

;- ------------------------------------------------------------
;- Lista de fontes disponiveis (obtida da pagina da Nerd Fonts)
;- ------------------------------------------------------------

Procedure.s FontDownloader_FetchPage(Url.s)
  Protected *Buffer = ReceiveHTTPMemory(Url)
  If Not *Buffer
    ProcedureReturn ""
  EndIf
  Protected Result.s = PeekS(*Buffer, MemorySize(*Buffer), #PB_UTF8 | #PB_ByteLength)
  FreeMemory(*Buffer)
  ProcedureReturn Result
EndProcedure

; Preenche NerdFontEntries() com nomes unicos (ordenados) e a URL do .zip de
; cada fonte, lendo direto da pagina de downloads (sem versao fixa embutida).
Procedure.b FontDownloader_FetchList()
  ClearList(NerdFontEntries())

  Protected Html.s = FontDownloader_FetchPage(#NerdFonts_PageUrl)
  If Html = ""
    ProcedureReturn #False
  EndIf

  Protected Regex = CreateRegularExpression(#PB_Any, "https://github\.com/ryanoasis/nerd-fonts/releases/download/[A-Za-z0-9_.\-/]+\.zip")
  If Not Regex
    ProcedureReturn #False
  EndIf

  Dim Matches.s(0)
  Protected Count = ExtractRegularExpression(Regex, Html, Matches())
  FreeRegularExpression(Regex)

  Protected i, Url.s, Name.s, Found.b
  For i = 0 To Count - 1
    Url = Matches(i)
    Name = GetFilePart(Url)
    If Right(Name, 4) = ".zip"
      Name = Left(Name, Len(Name) - 4)
    EndIf
    If Name = ""
      Continue
    EndIf

    Found = #False
    ForEach NerdFontEntries()
      If NerdFontEntries()\Name = Name
        Found = #True
        Break
      EndIf
    Next
    If Not Found
      AddElement(NerdFontEntries())
      NerdFontEntries()\Name = Name
      NerdFontEntries()\Url = Url
    EndIf
  Next

  SortStructuredList(NerdFontEntries(), #PB_Sort_Ascending, OffsetOf(NerdFontEntry\Name), #PB_String)

  ProcedureReturn Bool(ListSize(NerdFontEntries()) > 0)
EndProcedure

;- ------------------------------------------------------------
;- Download + extracao de uma fonte
;- ------------------------------------------------------------

; Baixa Url para um .zip temporario, descompacta em TargetDir (via
; BadigCfg_ExtractZip, ja usada para o Basic Dignified Suite) e apaga o .zip.
Procedure.b FontDownloader_DownloadOne(Url.s, TargetDir.s)
  Protected TmpZip.s = GetTemporaryDirectory() + "nerdfont-" + Str(Random(999999999)) + ".zip"

  If Not ReceiveHTTPFile(Url, TmpZip)
    ProcedureReturn #False
  EndIf

  Protected Ok.b = BadigCfg_ExtractZip(TmpZip, TargetDir)
  DeleteFile(TmpZip)
  ProcedureReturn Ok
EndProcedure

;- ------------------------------------------------------------
;- Janela de download
;- ------------------------------------------------------------

Procedure FontDownloader_PopulateListGadget(ListGadget)
  ClearGadgetItems(ListGadget)
  ForEach NerdFontEntries()
    AddGadgetItem(ListGadget, -1, NerdFontEntries()\Name)
  Next
EndProcedure

; Esvazia a fila de eventos pendente (sem bloquear) para o texto de status
; ser repintado antes de uma chamada de rede bloqueante (ReceiveHTTPFile /
; ReceiveHTTPMemory nao cedem tempo para a interface).
Procedure FontDownloader_FlushEvents()
  Repeat
  Until WindowEvent() = 0
EndProcedure

Procedure FontDownloader_SetBusy(StatusGadget, ListGadget, Btn1, Btn2, Btn3, Btn4, Btn5, Btn6, Btn7, Busy.b)
  DisableGadget(ListGadget, Busy)
  DisableGadget(Btn1, Busy)
  DisableGadget(Btn2, Busy)
  DisableGadget(Btn3, Busy)
  DisableGadget(Btn4, Busy)
  DisableGadget(Btn5, Busy)
  DisableGadget(Btn6, Busy)
  DisableGadget(Btn7, Busy)
  If Busy
    SetGadgetText(StatusGadget, "Preparando...")
  Else
    SetGadgetText(StatusGadget, "")
  EndIf
  FontDownloader_FlushEvents()
EndProcedure

; Baixa as fontes da lista de indices (posicoes em NerdFontEntries(), na mesma
; ordem em que foram inseridas no ListGadget) para TargetDir. Retorna a
; quantidade baixada com sucesso.
Procedure.i FontDownloader_RunDownloads(Win, StatusGadget, List Indexes.i(), TargetDir.s)
  Protected Total = ListSize(Indexes())
  If Total = 0
    ProcedureReturn 0
  EndIf

  If FileSize(TargetDir) <> -2
    CreateDirectory(TargetDir)
  EndIf

  Protected Idx, Done = 0, Ok = 0, Fail = 0
  Protected FailNames.s = ""

  ForEach Indexes()
    Idx = Indexes()
    Done + 1
    If SelectElement(NerdFontEntries(), Idx)
      SetGadgetText(StatusGadget, "Baixando " + Str(Done) + "/" + Str(Total) + ": " + NerdFontEntries()\Name + "...")
      FontDownloader_FlushEvents()

      If FontDownloader_DownloadOne(NerdFontEntries()\Url, TargetDir)
        Ok + 1
      Else
        Fail + 1
        FailNames + Chr(10) + " - " + NerdFontEntries()\Name
      EndIf
    EndIf
  Next

  SetGadgetText(StatusGadget, "")

  If Fail = 0
    MessageRequester("Baixar fontes", Str(Ok) + " fonte(s) baixada(s) e extraida(s) em:" + Chr(10) + TargetDir,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  Else
    MessageRequester("Baixar fontes", Str(Ok) + " fonte(s) baixada(s) com sucesso." + Chr(10) +
                     Str(Fail) + " falha(s) (verifique sua conexao):" + FailNames,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Warning)
  EndIf

  ProcedureReturn Ok
EndProcedure

; Abre a janela de download de fontes. Retorna a pasta de destino usada se ao
; menos uma fonte foi baixada com sucesso (para o chamador poder preencher o
; campo "Pasta de fontes customizadas"), ou "" caso contrario/cancelado.
Procedure.s FontDownloader_OpenWindow(ParentWindow, InitialFolder.s)
  Protected DefaultDir.s = InitialFolder
  If DefaultDir = ""
    Protected EditorDir.s = GetPathPart(ProgramFilename())
    DefaultDir = GetPathPart(Left(EditorDir, Len(EditorDir) - 1)) + "fonts"
  EndIf
  If Right(DefaultDir, 1) = "\" Or Right(DefaultDir, 1) = "/"
    DefaultDir = Left(DefaultDir, Len(DefaultDir) - 1)
  EndIf

  Protected WinW = 540, WinH = 470
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Baixar Fontes (Nerd Fonts)",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn ""
  EndIf
  App_ApplyWindowIcon(Win)

  DisableWindow(ParentWindow, #True)

  TextGadget(#PB_Any, 15, 15, 510, 48,
    "Baixa fontes da colecao Nerd Fonts (nerdfonts.com), extraindo automaticamente" + Chr(10) +
    "os arquivos .ttf/.otf na pasta abaixo. Selecione as fontes desejadas ou use" + Chr(10) +
    "'Baixar todas' para a colecao inteira (atencao: dezenas de arquivos grandes).")

  TextGadget(#PB_Any, 15, 68, 300, 20, "Pasta de destino")
  Protected G_TargetDir = StringGadget(#PB_Any, 15, 88, 430, 22, DefaultDir)
  Protected G_TargetDirBrowse = ButtonGadget(#PB_Any, 450, 88, 75, 22, "...")

  Protected G_List = ListIconGadget(#PB_Any, 15, 118, 510, 250, "Fonte", 490,
                                     #PB_ListIcon_CheckBoxes | #PB_ListIcon_GridLines | #PB_ListIcon_FullRowSelect)

  Protected G_Status = TextGadget(#PB_Any, 15, 374, 510, 20, "Carregando lista de fontes...")

  Protected G_SelectAll = ButtonGadget(#PB_Any, 15, 398, 120, 24, "Selecionar todas")
  Protected G_SelectNone = ButtonGadget(#PB_Any, 140, 398, 120, 24, "Limpar selecao")
  Protected G_Reload = ButtonGadget(#PB_Any, 265, 398, 100, 24, "Recarregar lista")

  Protected G_DownloadSelected = ButtonGadget(#PB_Any, 15, 432, 160, 28, "Baixar selecionadas")
  Protected G_DownloadAll = ButtonGadget(#PB_Any, 180, 432, 120, 28, "Baixar todas")
  Protected G_Close = ButtonGadget(#PB_Any, WinW - 110, 432, 95, 28, "Fechar")

  FontDownloader_FlushEvents()
  If FontDownloader_FetchList()
    FontDownloader_PopulateListGadget(G_List)
    SetGadgetText(G_Status, Str(ListSize(NerdFontEntries())) + " fonte(s) disponivel(is).")
  Else
    SetGadgetText(G_Status, "Falha ao carregar a lista (verifique sua conexao) - tente 'Recarregar lista'.")
  EndIf

  Protected Event, Quit = #False, DownloadedDir.s = "", TotalOk = 0
  Protected NewList Indexes.i()
  Protected i

  Repeat
    Event = WaitWindowEvent()

    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_TargetDirBrowse
            Protected Pick.s = PathRequester("Selecione a pasta de destino das fontes", GetGadgetText(G_TargetDir))
            If Pick <> ""
              SetGadgetText(G_TargetDir, Pick)
            EndIf

          Case G_SelectAll
            For i = 0 To CountGadgetItems(G_List) - 1
              SetGadgetItemState(G_List, i, #PB_ListIcon_Checked)
            Next

          Case G_SelectNone
            For i = 0 To CountGadgetItems(G_List) - 1
              SetGadgetItemState(G_List, i, 0)
            Next

          Case G_Reload
            SetGadgetText(G_Status, "Recarregando lista de fontes...")
            FontDownloader_FlushEvents()
            If FontDownloader_FetchList()
              FontDownloader_PopulateListGadget(G_List)
              SetGadgetText(G_Status, Str(ListSize(NerdFontEntries())) + " fonte(s) disponivel(is).")
            Else
              SetGadgetText(G_Status, "Falha ao carregar a lista (verifique sua conexao).")
            EndIf

          Case G_DownloadSelected
            ClearList(Indexes())
            For i = 0 To CountGadgetItems(G_List) - 1
              If GetGadgetItemState(G_List, i) & #PB_ListIcon_Checked
                AddElement(Indexes()) : Indexes() = i
              EndIf
            Next
            If ListSize(Indexes()) = 0
              MessageRequester("Baixar fontes", "Selecione ao menos uma fonte na lista.", #PB_MessageRequester_Ok)
            ElseIf Trim(GetGadgetText(G_TargetDir)) = ""
              MessageRequester("Baixar fontes", "Informe a pasta de destino.", #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
            Else
              FontDownloader_SetBusy(G_Status, G_List, G_TargetDirBrowse, G_SelectAll, G_SelectNone, G_Reload, G_DownloadSelected, G_DownloadAll, G_Close, #True)
              TotalOk = FontDownloader_RunDownloads(Win, G_Status, Indexes(), GetGadgetText(G_TargetDir))
              FontDownloader_SetBusy(G_Status, G_List, G_TargetDirBrowse, G_SelectAll, G_SelectNone, G_Reload, G_DownloadSelected, G_DownloadAll, G_Close, #False)
              SetGadgetText(G_Status, Str(ListSize(NerdFontEntries())) + " fonte(s) disponivel(is).")
              If TotalOk > 0
                DownloadedDir = GetGadgetText(G_TargetDir)
              EndIf
            EndIf

          Case G_DownloadAll
            If ListSize(NerdFontEntries()) = 0
              MessageRequester("Baixar fontes", "A lista de fontes ainda nao foi carregada.", #PB_MessageRequester_Ok)
            ElseIf Trim(GetGadgetText(G_TargetDir)) = ""
              MessageRequester("Baixar fontes", "Informe a pasta de destino.", #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
            Else
              Protected Confirm = MessageRequester("Baixar fontes",
                "Isso ira baixar as " + Str(ListSize(NerdFontEntries())) + " fontes da Nerd Fonts (varios GB, alguns" + Chr(10) +
                "arquivos com centenas de MB) para:" + Chr(10) + GetGadgetText(G_TargetDir) + Chr(10) + Chr(10) +
                "A janela ficara sem responder durante os downloads. Continuar?",
                #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning)
              If Confirm = #PB_MessageRequester_Yes
                ClearList(Indexes())
                For i = 0 To CountGadgetItems(G_List) - 1
                  AddElement(Indexes()) : Indexes() = i
                Next
                FontDownloader_SetBusy(G_Status, G_List, G_TargetDirBrowse, G_SelectAll, G_SelectNone, G_Reload, G_DownloadSelected, G_DownloadAll, G_Close, #True)
                TotalOk = FontDownloader_RunDownloads(Win, G_Status, Indexes(), GetGadgetText(G_TargetDir))
                FontDownloader_SetBusy(G_Status, G_List, G_TargetDirBrowse, G_SelectAll, G_SelectNone, G_Reload, G_DownloadSelected, G_DownloadAll, G_Close, #False)
                SetGadgetText(G_Status, Str(ListSize(NerdFontEntries())) + " fonte(s) disponivel(is).")
                If TotalOk > 0
                  DownloadedDir = GetGadgetText(G_TargetDir)
                EndIf
              EndIf
            EndIf

          Case G_Close
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)

  ProcedureReturn DownloadedDir
EndProcedure
