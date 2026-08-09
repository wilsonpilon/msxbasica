;
; ------------------------------------------------------------
;  Suporte ao MSXBAS2ROM (github.com/amaurycarvalho/msxbas2rom): template de
;  arquivo novo (.bas classico, formato que o compilador espera - MSX-BASIC
;  tradicional numerado, sem Dignified), tela "Configurar -> MSXBas2Rom..."
;  que baixa o binario mais recente (Windows/Linux conforme o SO) e gera o
;  conteudo de "Ajuda -> MSXBas2Rom..." a partir de "-h" e das paginas reais
;  da wiki do projeto.
;
;  Nota: "msxbas2rom -D"/"--doc" NAO despeja documentacao - so imprime um
;  ponteiro pra wiki (confirmado rodando o binario). A wiki de verdade e bem
;  mais rica e e buscavel direto via raw.githubusercontent.com/wiki/<owner>/
;  <repo>/<Pagina>.md - e dai que vem o conteudo de Ajuda, nao do "-doc".
; ------------------------------------------------------------
;

;- ------------------------------------------------------------
;- Template do arquivo novo (Arquivo -> Novo MSXBas2Rom...)
;- ------------------------------------------------------------

Procedure.s MsxBas2RomTemplateText()
  Protected Text.s = ""
  Text + "10 REM ------------------------------------------------------------" + #CRLF$
  Text + "20 REM  Projeto MSXBAS2ROM" + #CRLF$
  Text + "30 REM  Compile com: msxbas2rom NOMEDOARQUIVO.BAS" + #CRLF$
  Text + "40 REM  https://github.com/amaurycarvalho/msxbas2rom" + #CRLF$
  Text + "50 REM ------------------------------------------------------------" + #CRLF$
  Text + "60 SCREEN 0" + #CRLF$
  Text + "70 PRINT " + Chr(34) + "HELLO, MSX!" + Chr(34) + #CRLF$
  Text + "80 END" + #CRLF$
  ProcedureReturn Text
EndProcedure

;- ------------------------------------------------------------
;- Configuracoes / persistencia (mesmo padrao de EditorCfg_FilePath() em
;- EditorSettings.pbi - JSON simples ao lado do .exe)
;- ------------------------------------------------------------

Structure MsxBas2RomSettings
  ExePath.s
  Version.s
EndStructure
Global MsxBas2RomCfg.MsxBas2RomSettings

Procedure.s MsxBas2Rom_ToolDir()
  ProcedureReturn GetPathPart(ProgramFilename()) + "tools\msxbas2rom\"
EndProcedure

Procedure.s MsxBas2Rom_HelpDir()
  ProcedureReturn MsxBas2Rom_ToolDir() + "help\"
EndProcedure

Procedure.s MsxBas2RomCfg_FilePath()
  ProcedureReturn GetPathPart(ProgramFilename()) + "msxbas2rom_settings.json"
EndProcedure

Procedure MsxBas2RomCfg_Load()
  MsxBas2RomCfg\ExePath = ""
  MsxBas2RomCfg\Version = ""

  Protected FilePath.s = MsxBas2RomCfg_FilePath()
  If FileSize(FilePath) <= 0
    ProcedureReturn
  EndIf

  Protected Json = LoadJSON(#PB_Any, FilePath)
  If Not Json
    ProcedureReturn
  EndIf

  Protected Root = JSONValue(Json)
  Protected M
  M = GetJSONMember(Root, "ExePath") : If M : MsxBas2RomCfg\ExePath = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "Version") : If M : MsxBas2RomCfg\Version = GetJSONString(M) : EndIf
  FreeJSON(Json)
EndProcedure

Procedure MsxBas2RomCfg_Save()
  Protected Json = CreateJSON(#PB_Any)
  Protected Root = SetJSONObject(JSONValue(Json))
  SetJSONString(AddJSONMember(Root, "ExePath"), MsxBas2RomCfg\ExePath)
  SetJSONString(AddJSONMember(Root, "Version"), MsxBas2RomCfg\Version)
  SaveJSON(Json, MsxBas2RomCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Download (Configurar -> MSXBas2Rom -> Baixar versao mais recente)
;- ------------------------------------------------------------

; Acha o asset .zip da release mais recente pro SO atual via GET
; releases/latest (um unico release, sem precisar varrer historico - ao
; contrario do N80/LK80/LB80, ver N80Support.pbi). *OutVersion recebe o
; "tag_name" da release (ex.: "v1.2.1.0").
Procedure.s MsxBas2Rom_ResolveAssetUrl(*OutVersion.String)
  *OutVersion\s = ""
  Protected JsonText.s = ExtTool_HttpGetText("https://api.github.com/repos/amaurycarvalho/msxbas2rom/releases/latest")
  If JsonText = ""
    ProcedureReturn ""
  EndIf

  Protected JsonHandle = ParseJSON(#PB_Any, JsonText)
  If Not JsonHandle
    ProcedureReturn ""
  EndIf

  Protected Root = JSONValue(JsonHandle)
  Protected M = GetJSONMember(Root, "tag_name")
  If M : *OutVersion\s = GetJSONString(M) : EndIf

  Protected OsTag.s
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    OsTag = "-windows-x64-bin.zip"
  CompilerElse
    OsTag = "-linux-x64-bin.zip"
  CompilerEndIf

  Protected Result.s = ""
  Protected AssetsElem = GetJSONMember(Root, "assets")
  If AssetsElem
    Protected N = JSONArraySize(AssetsElem)
    Protected Idx, Item, NameM, UrlM
    For Idx = 0 To N - 1
      Item = GetJSONElement(AssetsElem, Idx)
      If Item
        NameM = GetJSONMember(Item, "name")
        If NameM And FindString(GetJSONString(NameM), OsTag) > 0
          UrlM = GetJSONMember(Item, "browser_download_url")
          If UrlM
            Result = GetJSONString(UrlM)
            Break
          EndIf
        EndIf
      EndIf
    Next
  EndIf

  FreeJSON(JsonHandle)
  ProcedureReturn Result
EndProcedure

Procedure.s MsxBas2Rom_FindExe()
  Protected Dir.s = MsxBas2Rom_ToolDir()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    If FileSize(Dir + "msxbas2rom.exe") > 0 : ProcedureReturn Dir + "msxbas2rom.exe" : EndIf
  CompilerElse
    If FileSize(Dir + "msxbas2rom") > 0 : ProcedureReturn Dir + "msxbas2rom" : EndIf
  CompilerEndIf
  ProcedureReturn ""
EndProcedure

; Paginas da wiki oficial confirmadas existentes (raw.githubusercontent.com/
; wiki/.../<Pagina>.md) e de tamanho razoavel pra virar Ajuda - cobre visao
; geral, uso/opcoes de linha de comando e a secao de referencia principal.
DataSection
  MsxBas2Rom_WikiPages:
  Data.s "Home",              "Visao geral"
  Data.s "Install",           "Instalacao"
  Data.s "Gettingstarted",    "Primeiros passos"
  Data.s "Usage",             "Uso e opcoes de linha de comando"
  Data.s "Documentation",     "Indice da documentacao"
  Data.s "Compiling-Code",    "Limitacoes e diferencas ao compilar"
  Data.s "Resource-Directives", "Diretivas de recursos (assets)"
  Data.s "Extended-Commands", "Comandos estendidos"
  Data.s "Extended-Functions", "Funcoes estendidas"
  Data.s "Getting-Help",      "Como obter ajuda"
  Data.s "@@END@@", ""
EndDataSection

; Baixa binario + wiki, monta a pasta de Ajuda e salva as configuracoes.
; StatusGadget (pode ser 0) recebe feedback textual a cada passo, ja que
; tudo aqui e bloqueante (ExtTool_SetStatus cuida de bombear a fila de
; eventos pra o texto aparecer antes do proximo passo travar a UI de novo).
Procedure.b MsxBas2Rom_Download(StatusGadget)
  ExtTool_SetStatus(StatusGadget, "Consultando release mais recente no GitHub...")
  Protected Version.String
  Protected AssetUrl.s = MsxBas2Rom_ResolveAssetUrl(@Version)
  If AssetUrl = ""
    ExtTool_SetStatus(StatusGadget, "Falha ao consultar o GitHub (verifique sua conexao).")
    ProcedureReturn #False
  EndIf

  Protected ToolDir.s = MsxBas2Rom_ToolDir()
  ExtTool_SetStatus(StatusGadget, "Baixando " + Version\s + "...")
  If Not ExtTool_DownloadAndExtractZip(AssetUrl, ToolDir)
    ExtTool_SetStatus(StatusGadget, "Falha ao baixar/descompactar o pacote.")
    ProcedureReturn #False
  EndIf

  Protected ExePath.s = MsxBas2Rom_FindExe()
  If ExePath = ""
    ExtTool_SetStatus(StatusGadget, "Pacote baixado, mas o executavel nao foi encontrado.")
    ProcedureReturn #False
  EndIf

  Protected HelpDir.s = MsxBas2Rom_HelpDir()
  CreateDirectory(HelpDir)
  NewList Topics.GenMdHelp_TopicItem()

  ExtTool_SetStatus(StatusGadget, "Gerando referencia de linha de comando (-h)...")
  Protected HelpOutput.s = ExtTool_RunCaptureOutput(ExePath, "-h")
  Protected CliFile = CreateFile(#PB_Any, HelpDir + "cli-help.md")
  If CliFile
    WriteStringN(CliFile, "# MSXBAS2ROM - referencia de linha de comando (-h)")
    WriteStringN(CliFile, "")
    WriteStringN(CliFile, "```")
    WriteString(CliFile, HelpOutput)
    WriteStringN(CliFile, "```")
    CloseFile(CliFile)
    AddElement(Topics())
    Topics()\File  = "cli-help.md"
    Topics()\Title = "Linha de comando (-h)"
    Topics()\Group = "MSXBAS2ROM"
  EndIf

  Restore MsxBas2Rom_WikiPages
  Protected PageName.s, PageTitle.s
  Repeat
    Read.s PageName
    Read.s PageTitle
    If PageName = "@@END@@"
      Break
    EndIf

    ExtTool_SetStatus(StatusGadget, "Baixando wiki: " + PageName + "...")
    Protected PageMd.s = ExtTool_HttpGetText("https://raw.githubusercontent.com/wiki/amaurycarvalho/msxbas2rom/" + PageName + ".md")
    If PageMd <> ""
      Protected PageFile.s = LCase(PageName) + ".md"
      Protected FNum = CreateFile(#PB_Any, HelpDir + PageFile)
      If FNum
        WriteString(FNum, PageMd)
        CloseFile(FNum)
        AddElement(Topics())
        Topics()\File  = PageFile
        Topics()\Title = PageTitle
        Topics()\Group = "MSXBAS2ROM"
      EndIf
    EndIf
  ForEver

  GenMdHelp_SaveIndex(HelpDir, Topics())

  MsxBas2RomCfg\ExePath = ExePath
  MsxBas2RomCfg\Version = Version\s
  MsxBas2RomCfg_Save()

  ExtTool_SetStatus(StatusGadget, "Concluido: " + Version\s + " instalado em " + ToolDir)
  ProcedureReturn #True
EndProcedure

;- ------------------------------------------------------------
;- Tela "Configurar -> MSXBas2Rom..."
;- ------------------------------------------------------------

Procedure MsxBas2RomSettings_OpenWindow(ParentWindow)
  MsxBas2RomCfg_Load()

  Protected WinW = 580, WinH = 304
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Configurar - MSXBas2Rom",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf

  TextGadget(#PB_Any, 24, 24, WinW - 48, 40,
            "MSXBAS2ROM compila programas MSX-BASIC classicos (.bas) direto em ROM." + Chr(10) +
            "github.com/amaurycarvalho/msxbas2rom")

  Protected G_Installed = TextGadget(#PB_Any, 24, 80, WinW - 48, 20, "")
  If MsxBas2RomCfg\ExePath <> "" And FileSize(MsxBas2RomCfg\ExePath) > 0
    SetGadgetText(G_Installed, "Instalado: " + MsxBas2RomCfg\Version + " (" + MsxBas2RomCfg\ExePath + ")")
  Else
    SetGadgetText(G_Installed, "Nao instalado ainda.")
  EndIf

  Protected G_Download = ThemedButton(24, 120, 280, 28, "Baixar versao mais recente", "")
  Protected G_Status = TextGadget(#PB_Any, 24, 176, WinW - 48, 40, "")

  Protected G_Close = ThemedButton(WinW - 24 - 110, WinH - 56, 110, 32, "Fechar", Chr(#Icon_Close))
  GadgetToolTip(G_Close, "Fechar")

  Protected Event, Quit = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_Download
            DisableGadget(G_Download, #True)
            DisableGadget(G_Close, #True)
            If MsxBas2Rom_Download(G_Status)
              MsxBas2RomCfg_Load()
              SetGadgetText(G_Installed, "Instalado: " + MsxBas2RomCfg\Version + " (" + MsxBas2RomCfg\ExePath + ")")
            EndIf
            DisableGadget(G_Download, #False)
            DisableGadget(G_Close, #False)

          Case G_Close
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
