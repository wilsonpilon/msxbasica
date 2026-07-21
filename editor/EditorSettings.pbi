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

Structure EditorSettings
  FontName.s
  FontSize.i
  FontFolder.s    ; pasta com .ttf/.otf/.ttc customizados (opcional)
  EditorPath.s    ; "onde o editor reside" (sempre termina com separador) - nao move o .exe, so serve de base para outros defaults
  Theme.s         ; "Dark" ou "Light"
  Style.s         ; "Modern" ou "Classic" (formato das abas)
EndStructure

Global EditorCfg.EditorSettings
Global NewList CustomFontResources.s()   ; caminhos registrados via AddFontResourceEx, para poder remover ao trocar de pasta

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
  EditorCfg\Theme = "Dark"
  EditorCfg\Style = "Modern"
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

  SaveJSON(Json, EditorCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Janela de configuracao (Configurar -> Editor...)
;- ------------------------------------------------------------

Procedure.b EditorCfg_OpenSettingsWindow(ParentWindow)
  Protected WinW = 560, WinH = 300
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Configuracoes do Editor",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn #False
  EndIf
  App_ApplyWindowIcon(Win)

  DisableWindow(ParentWindow, #True)

  TextGadget(#PB_Any, 15, 15, 150, 20, "Fonte (monoespacada)")
  Protected G_Font = ComboBoxGadget(#PB_Any, 170, 12, 260, 22)

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

  TextGadget(#PB_Any, 440, 15, 40, 20, "Tam.")
  Protected G_FontSize = StringGadget(#PB_Any, 480, 12, 50, 22, Str(EditorCfg\FontSize))

  TextGadget(#PB_Any, 15, 55, 400, 20, "Pasta de fontes customizadas (opcional)")
  Protected G_FontFolder = StringGadget(#PB_Any, 15, 75, 460, 22, EditorCfg\FontFolder)
  Protected G_FontFolderBrowse = ButtonGadget(#PB_Any, 485, 75, 45, 22, "...")
  Protected G_FontDownload = ButtonGadget(#PB_Any, 15, 100, 250, 22, "Baixar fontes (Nerd Fonts)...")

  TextGadget(#PB_Any, 15, 155, 400, 20, "Caminho de instalacao do editor")
  Protected G_EditorPath = StringGadget(#PB_Any, 15, 175, 460, 22, EditorCfg\EditorPath)
  Protected G_EditorPathBrowse = ButtonGadget(#PB_Any, 485, 175, 45, 22, "...")
  TextGadget(#PB_Any, 15, 200, 515, 32,
    "Usado como base do diretorio padrao do Basic Dignified Suite - util para manter" + Chr(10) +
    "instalacoes separadas do editor (ex.: estavel e beta).")

  TextGadget(#PB_Any, 15, 245, 100, 20, "Tema")
  Protected G_Theme = ComboBoxGadget(#PB_Any, 90, 242, 130, 22)
  AddGadgetItem(G_Theme, -1, "Escuro")
  AddGadgetItem(G_Theme, -1, "Claro")
  SetGadgetState(G_Theme, Bool(EditorCfg\Theme = "Light"))

  TextGadget(#PB_Any, 300, 245, 100, 20, "Estilo de abas")
  Protected G_Style = ComboBoxGadget(#PB_Any, 400, 242, 130, 22)
  AddGadgetItem(G_Style, -1, "Moderno")
  AddGadgetItem(G_Style, -1, "Classico")
  SetGadgetState(G_Style, Bool(EditorCfg\Style = "Classic"))

  Protected G_Save = ButtonGadget(#PB_Any, WinW - 220, WinH - 40, 100, 28, "Salvar")
  Protected G_Cancel = ButtonGadget(#PB_Any, WinW - 110, WinH - 40, 100, 28, "Cancelar")

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

    If GetGadgetState(G_Theme) = 1
      EditorCfg\Theme = "Light"
    Else
      EditorCfg\Theme = "Dark"
    EndIf

    If GetGadgetState(G_Style) = 1
      EditorCfg\Style = "Classic"
    Else
      EditorCfg\Style = "Modern"
    EndIf

    EditorCfg_Save()

    If FontFolderChanged
      EditorCfg_LoadCustomFonts()
    EndIf
  EndIf

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)

  ProcedureReturn Saved
EndProcedure
