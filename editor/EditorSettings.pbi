;
; ------------------------------------------------------------
;  Configuracoes do Editor (fonte, tema, caminhos)
;  Cobre: fonte monoespacada (com pasta opcional de fontes customizadas,
;  carregadas em memoria via AddFontResourceEx - privado ao processo, sem
;  instalar nada no sistema operacional), caminho de "instalacao" do editor
;  (base usada para calcular o diretorio padrao do Basic Dignified Suite,
;  ver BadigSettings.pbi - util para manter 2 versoes do editor, ex.:
;  estavel + beta), tema claro/escuro e estilo de abas moderno/classico.
;  Persistidas em JSON proprio (editor_settings.json, ao lado do .exe).
; ------------------------------------------------------------
;

; Structure EditorSettings/Global EditorCfg/Global CustomFontResources() foram
; movidos pro topo de BadigEditor.pb (antes do primeiro XIncludeFile) porque
; ThemedButtons.pbi (incluido logo depois de EditorSettings.pbi na cadeia) ja
; precisa ler EditorCfg\FontName/IconFontName - com EnableExplicit, a
; declaracao precisa aparecer antes textualmente. Mesmo motivo dos varios
; Declare no topo de BadigEditor.pb para dependencia circular de procedures.

;- ------------------------------------------------------------
;- Valores padrao
;- ------------------------------------------------------------

Procedure.s EditorCfg_DefaultFontName()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ProcedureReturn "Consolas"
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn "DejaVu Sans Mono"
  CompilerElse
    ProcedureReturn "Menlo"
  CompilerEndIf
EndProcedure

Procedure.s EditorCfg_NormalizeDir(Path.s)
  If Path = ""
    ProcedureReturn Path
  EndIf
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If Right(Path, 1) <> "\"
      Path + "\"
    EndIf
  CompilerElse
    If Right(Path, 1) <> "/"
      Path + "/"
    EndIf
  CompilerEndIf
  ProcedureReturn Path
EndProcedure

Procedure EditorCfg_SetDefaults()
  EditorCfg\FontName = EditorCfg_DefaultFontName()
  EditorCfg\FontSize = 11
  EditorCfg\FontFolder = ""
  EditorCfg\EditorPath = EditorCfg_NormalizeDir(GetPathPart(ProgramFilename()))
  EditorCfg\Theme = "Graphite"
  EditorCfg\Style = "Modern"
  EditorCfg\IconFontName = ""
EndProcedure

;- ------------------------------------------------------------
;- Temas: ID persistido em JSON <-> indice do ComboBoxGadget/rotulo em PT-BR
;- ------------------------------------------------------------

; Ordem = ordem do combo na tela de Configurar -> Editor... e dos mockups
; originais (ver docs/RELEASE_NOTES.md) - Graphite/Snow sao as revisoes do
; escuro/claro que ja existiam; os outros 5 sao as cores novas pedidas.
Procedure.s EditorCfg_ThemeIdByIndex(Index)
  Select Index
    Case 1 : ProcedureReturn "Snow"
    Case 2 : ProcedureReturn "Navy"
    Case 3 : ProcedureReturn "Rose"
    Case 4 : ProcedureReturn "Crimson"
    Case 5 : ProcedureReturn "Forest"
    Case 6 : ProcedureReturn "Paper"
    Default : ProcedureReturn "Graphite" ; indice 0 e qualquer coisa fora da faixa
  EndSelect
EndProcedure

; Contraparte de EditorCfg_ThemeIdByIndex() - tambem absorve os dois IDs
; antigos ("Dark"/"Light", unicos valores que este campo teve antes dos 7
; temas) para nao resetar o tema de quem ja tinha um editor_settings.json.
Procedure.i EditorCfg_ThemeIndexById(Id.s)
  Select Id
    Case "Snow", "Light" : ProcedureReturn 1
    Case "Navy"          : ProcedureReturn 2
    Case "Rose"          : ProcedureReturn 3
    Case "Crimson"       : ProcedureReturn 4
    Case "Forest"        : ProcedureReturn 5
    Case "Paper"         : ProcedureReturn 6
    Default              : ProcedureReturn 0 ; "Graphite"/"Dark"/desconhecido
  EndSelect
EndProcedure

; #True para os 5 temas de fundo escuro (Graphite/Navy/Rose/Crimson/Forest,
; ver Color_AppBg de cada Case em ApplyTheme(), BadigEditor.pb), #False para
; os 2 de fundo claro (Snow/Paper) - usado pra decidir quando acionar as
; APIs nativas de "modo escuro" do Windows (DWMWA_USE_IMMERSIVE_DARK_MODE,
; SetWindowTheme_ "DarkMode_Explorer", WM_CTLCOLOREDIT/LISTBOX) em vez do
; antigo "EditorCfg\Theme = 'Dark'" literal, que era um resquicio do sistema
; binario Dark/Light anterior aos 7 temas - EditorCfg_Load() ja migra
; qualquer "Dark"/"Light" legado pra "Graphite"/"Snow" assim que carrega
; (ver comentario la), entao aquela comparacao nunca mais podia dar certo:
; o modo escuro nativo ficava sempre desligado, em qualquer tema, inclusive
; nos 5 escuros.
Procedure.b EditorCfg_ThemeIsDark(ThemeId.s)
  Select ThemeId
    Case "Snow", "Paper"
      ProcedureReturn #False
    Default
      ProcedureReturn #True ; Graphite/Navy/Rose/Crimson/Forest + desconhecido
  EndSelect
EndProcedure

;- ------------------------------------------------------------
;- Enumeracao de fontes monoespacadas instaladas (WinAPI)
;- ------------------------------------------------------------

CompilerIf #PB_Compiler_OS = #PB_OS_Windows

  ; Nomes proprios (nao "LOGFONT"/"TEXTMETRIC") para nao colidir com estruturas
  ; que o compilador/SDK do PureBasic ja possa definir internamente.
  Structure EdLogFontW
    lfHeight.l
    lfWidth.l
    lfEscapement.l
    lfOrientation.l
    lfWeight.l
    lfItalic.a
    lfUnderline.a
    lfStrikeOut.a
    lfCharSet.a
    lfOutPrecision.a
    lfClipPrecision.a
    lfQuality.a
    lfPitchAndFamily.a
    lfFaceName.u[32]
  EndStructure

  #EdFont_DEFAULT_CHARSET = 1
  #EdFont_FIXED_PITCH     = 1
  #EdFont_FR_PRIVATE      = $10

  ; AddFontResourceEx/RemoveFontResourceEx (variante "Ex", que permite carregar
  ; a fonte so em memoria/privada ao processo, sem instalar no sistema) nao
  ; estao na .lib de importacao do gdi32 que o PureBasic traz embutida -
  ; resolvidas dinamicamente via OpenLibrary/GetFunction (Prototype tipado).
  Prototype.i EdAddFontResourceExProto(FileName.p-unicode, fl.l, pdv.i)
  Prototype.i EdRemoveFontResourceExProto(FileName.p-unicode, fl.l, pdv.i)

  Global EdGdi32Lib.i = 0
  Global EdAddFontResourceExFn.EdAddFontResourceExProto
  Global EdRemoveFontResourceExFn.EdRemoveFontResourceExProto

  Procedure EditorCfg_InitFontApi()
    If Not EdGdi32Lib
      EdGdi32Lib = OpenLibrary(#PB_Any, "gdi32.dll")
      If EdGdi32Lib
        EdAddFontResourceExFn = GetFunction(EdGdi32Lib, "AddFontResourceExW")
        EdRemoveFontResourceExFn = GetFunction(EdGdi32Lib, "RemoveFontResourceExW")
      EndIf
    EndIf
  EndProcedure

  Procedure.i EdAddFontResourceEx(FileName.s, fl.l, pdv.i)
    EditorCfg_InitFontApi()
    If Not EdAddFontResourceExFn
      ProcedureReturn 0
    EndIf
    ProcedureReturn EdAddFontResourceExFn(FileName, fl, pdv)
  EndProcedure

  Procedure.i EdRemoveFontResourceEx(FileName.s, fl.l, pdv.i)
    EditorCfg_InitFontApi()
    If Not EdRemoveFontResourceExFn
      ProcedureReturn 0
    EndIf
    ProcedureReturn EdRemoveFontResourceExFn(FileName, fl, pdv)
  EndProcedure

  UseZipPacker() ; usado mais abaixo (BadigCfg_ExtractZip, em BadigSettings.pbi) - declarado aqui por ser diretiva de compilador, nao runtime

  Global NewList EdFontEnumResult.s()

  Procedure.l EdFontEnumProc(*lf.EdLogFontW, *tm, FontType.l, lParam.i)
    Protected Pitch.l = *lf\lfPitchAndFamily & 3
    If Pitch = #EdFont_FIXED_PITCH
      Protected Name.s = PeekS(@*lf\lfFaceName[0], -1, #PB_Unicode)
      If Name <> "" And Left(Name, 1) <> "@"
        Protected Found.b = #False
        ForEach EdFontEnumResult()
          If EdFontEnumResult() = Name
            Found = #True
            Break
          EndIf
        Next
        If Not Found
          AddElement(EdFontEnumResult())
          EdFontEnumResult() = Name
        EndIf
      EndIf
    EndIf
    ProcedureReturn 1
  EndProcedure

CompilerEndIf

; Preenche Result() com os nomes (unicos, ordenados) de todas as fontes
; monoespacadas visiveis para o processo - inclui fontes do sistema e as
; carregadas via EditorCfg_LoadCustomFonts() (AddFontResourceEx torna essas
; visiveis para a mesma enumeracao). Sem suporte fora do Windows por ora.
Procedure EditorCfg_EnumMonospaceFonts(List Result.s())
  ClearList(Result())

  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ClearList(EdFontEnumResult())

    Protected hDC = GetDC_(0)
    If hDC
      Protected lf.EdLogFontW
      lf\lfCharSet = #EdFont_DEFAULT_CHARSET
      EnumFontFamiliesEx_(hDC, @lf, @EdFontEnumProc(), 0, 0)
      ReleaseDC_(0, hDC)
    EndIf

    SortList(EdFontEnumResult(), #PB_Sort_Ascending | #PB_Sort_NoCase)
    ForEach EdFontEnumResult()
      AddElement(Result())
      Result() = EdFontEnumResult()
    Next
  CompilerEndIf

  If ListSize(Result()) = 0
    AddElement(Result())
    Result() = EditorCfg_DefaultFontName()
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Fontes customizadas (carregadas em memoria, privadas ao processo)
;- ------------------------------------------------------------

Procedure EditorCfg_UnloadCustomFonts()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ForEach CustomFontResources()
      EdRemoveFontResourceEx(CustomFontResources(), #EdFont_FR_PRIVATE, 0)
    Next
  CompilerEndIf
  ClearList(CustomFontResources())
EndProcedure

Procedure EditorCfg_LoadCustomFonts()
  EditorCfg_UnloadCustomFonts()

  If EditorCfg\FontFolder = "" Or FileSize(EditorCfg\FontFolder) <> -2
    ProcedureReturn
  EndIf

  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    Protected Folder.s = EditorCfg_NormalizeDir(EditorCfg\FontFolder)
    Protected Dir = ExamineDirectory(#PB_Any, Folder, "*.*")
    If Dir
      Protected Ext.s, FontPath.s
      While NextDirectoryEntry(Dir)
        If DirectoryEntryType(Dir) = #PB_DirectoryEntry_File
          Ext = LCase(GetExtensionPart(DirectoryEntryName(Dir)))
          If Ext = "ttf" Or Ext = "otf" Or Ext = "ttc"
            FontPath = Folder + DirectoryEntryName(Dir)
            If EdAddFontResourceEx(FontPath, #EdFont_FR_PRIVATE, 0)
              AddElement(CustomFontResources())
              CustomFontResources() = FontPath
            EndIf
          EndIf
        EndIf
      Wend
      FinishDirectory(Dir)
    EndIf
  CompilerEndIf
EndProcedure

;- ------------------------------------------------------------
;- Persistencia em JSON
;- ------------------------------------------------------------

Procedure.s EditorCfg_FilePath()
  ProcedureReturn GetPathPart(ProgramFilename()) + "editor_settings.json"
EndProcedure

Procedure EditorCfg_Load()
  EditorCfg_SetDefaults()

  Protected FilePath.s = EditorCfg_FilePath()
  If FileSize(FilePath) <= 0
    ProcedureReturn #False
  EndIf

  Protected Json = LoadJSON(#PB_Any, FilePath)
  If Not Json
    ProcedureReturn #False
  EndIf

  Protected Root = JSONValue(Json)
  Protected M

  M = GetJSONMember(Root, "FontName")   : If M : EditorCfg\FontName = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "FontSize")   : If M : EditorCfg\FontSize = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "FontFolder") : If M : EditorCfg\FontFolder = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "EditorPath") : If M : EditorCfg\EditorPath = EditorCfg_NormalizeDir(GetJSONString(M)) : EndIf
  M = GetJSONMember(Root, "Theme")      : If M : EditorCfg\Theme = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "Style")      : If M : EditorCfg\Style = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "IconFontName") : If M : EditorCfg\IconFontName = GetJSONString(M) : EndIf

  ; settings.json de antes dos 7 temas so tinha "Dark"/"Light" - migra pros
  ; equivalentes mais proximos (Graphite/Snow) assim que carrega, pra
  ; ApplyTheme() (BadigEditor.pb) so precisar conhecer os 7 IDs atuais.
  If EditorCfg\Theme = "Dark"
    EditorCfg\Theme = "Graphite"
  ElseIf EditorCfg\Theme = "Light"
    EditorCfg\Theme = "Snow"
  EndIf

  FreeJSON(Json)
  ProcedureReturn #True
EndProcedure

Procedure EditorCfg_Save()
  Protected Json = CreateJSON(#PB_Any)
  Protected Root = SetJSONObject(JSONValue(Json))

  SetJSONString(AddJSONMember(Root, "FontName"), EditorCfg\FontName)
  SetJSONInteger(AddJSONMember(Root, "FontSize"), EditorCfg\FontSize)
  SetJSONString(AddJSONMember(Root, "FontFolder"), EditorCfg\FontFolder)
  SetJSONString(AddJSONMember(Root, "EditorPath"), EditorCfg\EditorPath)
  SetJSONString(AddJSONMember(Root, "Theme"), EditorCfg\Theme)
  SetJSONString(AddJSONMember(Root, "Style"), EditorCfg\Style)
  SetJSONString(AddJSONMember(Root, "IconFontName"), EditorCfg\IconFontName)

  SaveJSON(Json, EditorCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Janela de configuracao (Configurar -> Editor...)
;- ------------------------------------------------------------

Procedure.b EditorCfg_OpenSettingsWindow(ParentWindow)
  ; Grade de layout com margens/espacamentos generosos (24px nas bordas,
  ; ~26-30px entre grupos, 8px entre um rotulo e o campo logo abaixo dele) -
  ; ao inves dos ~15px colados uns nos outros que a janela tinha antes
  ; (pedido explicito do usuario pra tirar a cara "Windows 95" compacta dos
  ; dialogos). Todo campo/combo/botao usa a mesma altura (24px, 32px so nos
  ; botoes principais Salvar/Cancelar) para o alinhamento ficar consistente.
  Protected WinW = 620, WinH = 470
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Configuracoes do Editor",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn #False
  EndIf

  TextGadget(#PB_Any, 24, 24, 180, 20, "Fonte (monoespacada)")
  Protected G_Font = ComboBoxGadget(#PB_Any, 214, 21, 270, 24)

  Protected NewList Fonts.s()
  EditorCfg_EnumMonospaceFonts(Fonts())
  Protected FontIndex = -1, Idx = 0
  ForEach Fonts()
    AddGadgetItem(G_Font, -1, Fonts())
    If Fonts() = EditorCfg\FontName
      FontIndex = Idx
    EndIf
    Idx + 1
  Next
  If FontIndex < 0
    AddGadgetItem(G_Font, -1, EditorCfg\FontName)
    FontIndex = CountGadgetItems(G_Font) - 1
  EndIf
  SetGadgetState(G_Font, FontIndex)

  TextGadget(#PB_Any, 500, 24, 40, 20, "Tam.")
  Protected G_FontSize = StringGadget(#PB_Any, 548, 21, 48, 24, Str(EditorCfg\FontSize))

  TextGadget(#PB_Any, 24, 72, 400, 20, "Pasta de fontes customizadas (opcional)")
  Protected G_FontFolder = StringGadget(#PB_Any, 24, 100, 512, 24, EditorCfg\FontFolder)
  Protected G_FontFolderBrowse = ThemedButton(546, 100, 50, 24, "...", "")
  Protected G_FontDownload = ThemedButton(24, 140, 300, 24, "Baixar fontes (Nerd Fonts)...", "")

  TextGadget(#PB_Any, 24, 190, 400, 20, "Caminho de instalacao do editor")
  Protected G_EditorPath = StringGadget(#PB_Any, 24, 218, 512, 24, EditorCfg\EditorPath)
  Protected G_EditorPathBrowse = ThemedButton(546, 218, 50, 24, "...", "")
  TextGadget(#PB_Any, 24, 254, 572, 36,
    "Usado como base do diretorio padrao do Basic Dignified Suite - util para manter" + Chr(10) +
    "instalacoes separadas do editor (ex.: estavel e beta).")

  TextGadget(#PB_Any, 24, 314, 70, 20, "Tema")
  Protected G_Theme = ComboBoxGadget(#PB_Any, 108, 311, 190, 24)
  AddGadgetItem(G_Theme, -1, "Grafite (escuro)")
  AddGadgetItem(G_Theme, -1, "Neve (claro)")
  AddGadgetItem(G_Theme, -1, "Azul Profundo")
  AddGadgetItem(G_Theme, -1, "Rose")
  AddGadgetItem(G_Theme, -1, "Carmesim")
  AddGadgetItem(G_Theme, -1, "Floresta")
  AddGadgetItem(G_Theme, -1, "Bege (claro)")
  SetGadgetState(G_Theme, EditorCfg_ThemeIndexById(EditorCfg\Theme))

  TextGadget(#PB_Any, 320, 314, 110, 20, "Estilo de abas")
  Protected G_Style = ComboBoxGadget(#PB_Any, 444, 311, 152, 24)
  AddGadgetItem(G_Style, -1, "Moderno")
  AddGadgetItem(G_Style, -1, "Classico")
  SetGadgetState(G_Style, Bool(EditorCfg\Style = "Classic"))

  ; Fonte separada da de codigo (acima) porque precisa ser especificamente uma
  ; Nerd Font (glifos de icone vivem em codepoints da Private Use Area - uma
  ; fonte comum nao tem esses desenhos, so mostra quadradinho vazio). "" =
  ; usa texto nos botoes tematizados (ver HexEd_CreateButtonImage,
  ; HexEditorGui.pbi) - unica janela que ja usa isso por enquanto.
  TextGadget(#PB_Any, 24, 360, 220, 20, "Fonte de icones (Nerd Font, opcional)")
  Protected G_IconFont = ComboBoxGadget(#PB_Any, 260, 357, 270, 24)
  AddGadgetItem(G_IconFont, -1, "(Nenhuma - usa texto)")

  Protected IconFontIndex = 0, IconIdx = 1
  ForEach Fonts()
    AddGadgetItem(G_IconFont, -1, Fonts())
    If Fonts() = EditorCfg\IconFontName
      IconFontIndex = IconIdx
    EndIf
    IconIdx + 1
  Next
  If IconFontIndex = 0 And EditorCfg\IconFontName <> ""
    AddGadgetItem(G_IconFont, -1, EditorCfg\IconFontName)
    IconFontIndex = CountGadgetItems(G_IconFont) - 1
  EndIf
  SetGadgetState(G_IconFont, IconFontIndex)
  GadgetToolTip(G_IconFont, "Baixe uma Nerd Font acima (ou coloque na pasta de fontes customizadas) e escolha aqui pra trocar o texto dos botoes por icones")

  Protected G_Save = ThemedButton(WinW - 256, WinH - 56, 110, 32, "Salvar", Chr(#Icon_Save))
  GadgetToolTip(G_Save, "Salvar")
  Protected G_Cancel = ThemedButton(WinW - 134, WinH - 56, 110, 32, "Cancelar", "")

  Protected Event, Quit = #False, Saved = #False, Pick.s

  Repeat
    Event = WaitWindowEvent()

    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_FontFolderBrowse
            Pick = PathRequester("Selecione a pasta de fontes customizadas", GetGadgetText(G_FontFolder))
            If Pick <> ""
              SetGadgetText(G_FontFolder, Pick)
            EndIf

          Case G_EditorPathBrowse
            Pick = PathRequester("Selecione o caminho de instalacao do editor", GetGadgetText(G_EditorPath))
            If Pick <> ""
              SetGadgetText(G_EditorPath, Pick)
            EndIf

          Case G_FontDownload
            Pick = FontDownloader_OpenWindow(Win, GetGadgetText(G_FontFolder))
            If Pick <> ""
              SetGadgetText(G_FontFolder, Pick)
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
    EditorCfg\FontName = GetGadgetText(G_Font)

    EditorCfg\FontSize = Val(GetGadgetText(G_FontSize))
    If EditorCfg\FontSize < 6 : EditorCfg\FontSize = 6 : EndIf
    If EditorCfg\FontSize > 72 : EditorCfg\FontSize = 72 : EndIf

    Protected NewFontFolder.s = GetGadgetText(G_FontFolder)
    Protected FontFolderChanged.b = Bool(NewFontFolder <> EditorCfg\FontFolder)
    EditorCfg\FontFolder = NewFontFolder

    Protected NewEditorPath.s = GetGadgetText(G_EditorPath)
    If NewEditorPath = ""
      NewEditorPath = GetPathPart(ProgramFilename())
    EndIf
    EditorCfg\EditorPath = EditorCfg_NormalizeDir(NewEditorPath)

    EditorCfg\Theme = EditorCfg_ThemeIdByIndex(GetGadgetState(G_Theme))

    If GetGadgetState(G_Style) = 1
      EditorCfg\Style = "Classic"
    Else
      EditorCfg\Style = "Modern"
    EndIf

    If GetGadgetState(G_IconFont) = 0
      EditorCfg\IconFontName = ""
    Else
      EditorCfg\IconFontName = GetGadgetText(G_IconFont)
    EndIf

    EditorCfg_Save()

    If FontFolderChanged
      EditorCfg_LoadCustomFonts()
    EndIf
  EndIf

  CloseModelessChildWindow(ParentWindow, Win)

  ProcedureReturn Saved
EndProcedure
