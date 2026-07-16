;
; ------------------------------------------------------------
;  Configuracoes do Basic Dignified Suite
;  Cobre os tres .ini do toolchain Python de referencia (badig/):
;    - support/badig.ini            -> pagina "Basic Dignified"
;    - msx/badig_msx.ini + msx/msxbatoken/msxbatoken.ini -> pagina "MSX"
;    - msx/emulator_interface.ini   -> pagina "Emulador"
;  Persistidas em JSON proprio do editor (nao nos .ini do Python, que
;  continuam existindo so como referencia de comportamento). O caminho do
;  executavel do openMSX e o unico valor que so existe no .ini real (nao ha
;  flag de linha de comando equivalente no badig.py), entao ao salvar tambem
;  gravamos esse valor de volta no emulator_interface.ini.
; ------------------------------------------------------------
;

Structure BadigSettings
  ; -- Pagina 1: Basic Dignified (geral, badig.ini) --
  InstallDir.s       ; pasta onde o toolchain Python (badig/) esta instalado - ver BadigCfg_DefaultInstallDir()
  SystemId.s
  LineStart.i
  LineStep.i
  RemHeader.b
  StripSpaces.b
  CapitalizeAll.b
  Translate.b
  PrintReport.b
  LabelReport.b
  LineReport.b
  VarReport.b
  LexerReport.b
  ParserReport.b
  TabLenght.i
  VerboseLevel.i

  ; -- Pagina 2: MSX (badig_msx.ini + msxbatoken.ini) --
  ConvertPrint.s     ; "" = nao converter, "?" ou "P"
  StripThenGoto.s     ; "" = nao remover, "T" ou "G"
  TkList.b
  TkListWidth.i
  TkDelAscii.b
  TkVerbose.i         ; -1 = nao definido (usa padrao do badig.py)

  ; -- Pagina 3: Emulador (emulator_interface.ini) --
  EmRun.b
  EmSetting.s
  EmMachine.s
  EmExtension.s
  EmNoThrottle.b
  EmMonitor.b
  EmVerbose.i         ; -1 = nao definido
  EmulatorPath.s
EndStructure

Global BadigCfg.BadigSettings

;- ------------------------------------------------------------
;- Valores padrao
;- ------------------------------------------------------------

; Se a instalacao "classica" (irmao da pasta editor/, ..\badig - onde o
; submodulo do toolchain Python vive hoje) ja existir, usa ela como default
; (evita quebrar quem ja tem o projeto configurado). Senao, usa o novo default
; pedido: pasta "badig" dentro do caminho de instalacao do editor
; (EditorCfg\EditorPath, ver EditorSettings.pbi - editavel em Configurar ->
; Editor..., util para manter 2 instalacoes separadas do editor).
Procedure.s BadigCfg_DefaultInstallDir()
  Protected Legacy.s = GetPathPart(ProgramFilename()) + "..\badig"
  If FileSize(Legacy) = -2
    ProcedureReturn Legacy
  EndIf
  ProcedureReturn EditorCfg\EditorPath + "badig"
EndProcedure

Procedure BadigCfg_SetDefaults()
  BadigCfg\InstallDir = BadigCfg_DefaultInstallDir()
  BadigCfg\SystemId = "msx"
  BadigCfg\LineStart = 10
  BadigCfg\LineStep = 10
  BadigCfg\RemHeader = #True
  BadigCfg\StripSpaces = #False
  BadigCfg\CapitalizeAll = #False
  ; Traduzir por padrao: sem isso o arquivo fonte (UTF-8) e lido incorretamente
  ; quando ha caracteres especiais (box-drawing, acentos, letras gregas) em
  ; strings literais, corrompendo o .bmx gerado a partir dali.
  BadigCfg\Translate = #True
  BadigCfg\PrintReport = #False
  BadigCfg\LabelReport = #False
  BadigCfg\LineReport = #False
  BadigCfg\VarReport = #False
  BadigCfg\LexerReport = #False
  BadigCfg\ParserReport = #False
  BadigCfg\TabLenght = 4
  BadigCfg\VerboseLevel = 3

  BadigCfg\ConvertPrint = ""
  BadigCfg\StripThenGoto = ""
  BadigCfg\TkList = #False
  BadigCfg\TkListWidth = 16
  BadigCfg\TkDelAscii = #False
  BadigCfg\TkVerbose = -1

  BadigCfg\EmRun = #False
  BadigCfg\EmSetting = ""
  BadigCfg\EmMachine = ""
  BadigCfg\EmExtension = ""
  BadigCfg\EmNoThrottle = #False
  BadigCfg\EmMonitor = #True
  BadigCfg\EmVerbose = -1
  BadigCfg\EmulatorPath = ""
EndProcedure

;- ------------------------------------------------------------
;- Persistencia em JSON
;- ------------------------------------------------------------

Procedure.s BadigCfg_FilePath()
  ProcedureReturn GetPathPart(ProgramFilename()) + "badig_settings.json"
EndProcedure

Procedure BadigCfg_Load()
  BadigCfg_SetDefaults()

  Protected FilePath.s = BadigCfg_FilePath()
  If FileSize(FilePath) <= 0
    ProcedureReturn #False
  EndIf

  Protected Json = LoadJSON(#PB_Any, FilePath)
  If Not Json
    ProcedureReturn #False
  EndIf

  Protected Root = JSONValue(Json)
  Protected M

  M = GetJSONMember(Root, "InstallDir")     : If M : BadigCfg\InstallDir = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "SystemId")       : If M : BadigCfg\SystemId = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "LineStart")      : If M : BadigCfg\LineStart = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "LineStep")       : If M : BadigCfg\LineStep = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "RemHeader")      : If M : BadigCfg\RemHeader = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "StripSpaces")    : If M : BadigCfg\StripSpaces = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "CapitalizeAll")  : If M : BadigCfg\CapitalizeAll = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "Translate")      : If M : BadigCfg\Translate = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "PrintReport")    : If M : BadigCfg\PrintReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "LabelReport")    : If M : BadigCfg\LabelReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "LineReport")     : If M : BadigCfg\LineReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "VarReport")      : If M : BadigCfg\VarReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "LexerReport")    : If M : BadigCfg\LexerReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "ParserReport")   : If M : BadigCfg\ParserReport = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "TabLenght")      : If M : BadigCfg\TabLenght = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "VerboseLevel")   : If M : BadigCfg\VerboseLevel = GetJSONInteger(M) : EndIf

  M = GetJSONMember(Root, "ConvertPrint")   : If M : BadigCfg\ConvertPrint = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "StripThenGoto")  : If M : BadigCfg\StripThenGoto = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "TkList")         : If M : BadigCfg\TkList = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "TkListWidth")    : If M : BadigCfg\TkListWidth = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "TkDelAscii")     : If M : BadigCfg\TkDelAscii = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "TkVerbose")      : If M : BadigCfg\TkVerbose = GetJSONInteger(M) : EndIf

  M = GetJSONMember(Root, "EmRun")          : If M : BadigCfg\EmRun = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "EmSetting")      : If M : BadigCfg\EmSetting = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "EmMachine")      : If M : BadigCfg\EmMachine = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "EmExtension")    : If M : BadigCfg\EmExtension = GetJSONString(M) : EndIf
  M = GetJSONMember(Root, "EmNoThrottle")   : If M : BadigCfg\EmNoThrottle = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "EmMonitor")      : If M : BadigCfg\EmMonitor = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "EmVerbose")      : If M : BadigCfg\EmVerbose = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "EmulatorPath")   : If M : BadigCfg\EmulatorPath = GetJSONString(M) : EndIf

  FreeJSON(Json)
  ProcedureReturn #True
EndProcedure

Procedure BadigCfg_Save()
  Protected Json = CreateJSON(#PB_Any)
  Protected Root = SetJSONObject(JSONValue(Json))

  SetJSONString(AddJSONMember(Root, "InstallDir"), BadigCfg\InstallDir)
  SetJSONString(AddJSONMember(Root, "SystemId"), BadigCfg\SystemId)
  SetJSONInteger(AddJSONMember(Root, "LineStart"), BadigCfg\LineStart)
  SetJSONInteger(AddJSONMember(Root, "LineStep"), BadigCfg\LineStep)
  SetJSONBoolean(AddJSONMember(Root, "RemHeader"), BadigCfg\RemHeader)
  SetJSONBoolean(AddJSONMember(Root, "StripSpaces"), BadigCfg\StripSpaces)
  SetJSONBoolean(AddJSONMember(Root, "CapitalizeAll"), BadigCfg\CapitalizeAll)
  SetJSONBoolean(AddJSONMember(Root, "Translate"), BadigCfg\Translate)
  SetJSONBoolean(AddJSONMember(Root, "PrintReport"), BadigCfg\PrintReport)
  SetJSONBoolean(AddJSONMember(Root, "LabelReport"), BadigCfg\LabelReport)
  SetJSONBoolean(AddJSONMember(Root, "LineReport"), BadigCfg\LineReport)
  SetJSONBoolean(AddJSONMember(Root, "VarReport"), BadigCfg\VarReport)
  SetJSONBoolean(AddJSONMember(Root, "LexerReport"), BadigCfg\LexerReport)
  SetJSONBoolean(AddJSONMember(Root, "ParserReport"), BadigCfg\ParserReport)
  SetJSONInteger(AddJSONMember(Root, "TabLenght"), BadigCfg\TabLenght)
  SetJSONInteger(AddJSONMember(Root, "VerboseLevel"), BadigCfg\VerboseLevel)

  SetJSONString(AddJSONMember(Root, "ConvertPrint"), BadigCfg\ConvertPrint)
  SetJSONString(AddJSONMember(Root, "StripThenGoto"), BadigCfg\StripThenGoto)
  SetJSONBoolean(AddJSONMember(Root, "TkList"), BadigCfg\TkList)
  SetJSONInteger(AddJSONMember(Root, "TkListWidth"), BadigCfg\TkListWidth)
  SetJSONBoolean(AddJSONMember(Root, "TkDelAscii"), BadigCfg\TkDelAscii)
  SetJSONInteger(AddJSONMember(Root, "TkVerbose"), BadigCfg\TkVerbose)

  SetJSONBoolean(AddJSONMember(Root, "EmRun"), BadigCfg\EmRun)
  SetJSONString(AddJSONMember(Root, "EmSetting"), BadigCfg\EmSetting)
  SetJSONString(AddJSONMember(Root, "EmMachine"), BadigCfg\EmMachine)
  SetJSONString(AddJSONMember(Root, "EmExtension"), BadigCfg\EmExtension)
  SetJSONBoolean(AddJSONMember(Root, "EmNoThrottle"), BadigCfg\EmNoThrottle)
  SetJSONBoolean(AddJSONMember(Root, "EmMonitor"), BadigCfg\EmMonitor)
  SetJSONInteger(AddJSONMember(Root, "EmVerbose"), BadigCfg\EmVerbose)
  SetJSONString(AddJSONMember(Root, "EmulatorPath"), BadigCfg\EmulatorPath)

  SaveJSON(Json, BadigCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Sincroniza o caminho do emulador com o .ini real do badig/
;- (unico valor sem flag de linha de comando equivalente)
;- ------------------------------------------------------------

Procedure.s BadigCfg_OSSectionName()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ProcedureReturn "WINDOWS"
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn "LINUX"
  CompilerElse
    ProcedureReturn "DARWIN"
  CompilerEndIf
EndProcedure

Procedure BadigCfg_SyncEmulatorIni()
  If BadigCfg\EmulatorPath = ""
    ProcedureReturn
  EndIf

  Protected IniPath.s = BadigCfg\InstallDir + "\msx\emulator_interface.ini"
  If FileSize(IniPath) <= 0
    ProcedureReturn
  EndIf

  Protected TargetSection.s = BadigCfg_OSSectionName()
  Protected InFile = ReadFile(#PB_Any, IniPath)
  If Not InFile
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Protected CurrentSection.s = ""
  Protected Line.s

  While Not Eof(InFile)
    Line = ReadString(InFile, #PB_UTF8)
    Protected Trimmed.s = Trim(Line)

    If Left(Trimmed, 1) = "[" And Right(Trimmed, 1) = "]"
      CurrentSection = UCase(Mid(Trimmed, 2, Len(Trimmed) - 2))
    ElseIf CurrentSection = TargetSection And LCase(Left(Trimmed, 13)) = "emulator_path"
      Line = "emulator_path = " + BadigCfg\EmulatorPath
    EndIf

    AddElement(Lines())
    Lines() = Line
  Wend
  CloseFile(InFile)

  Protected OutFile = CreateFile(#PB_Any, IniPath)
  If OutFile
    ForEach Lines()
      WriteStringN(OutFile, Lines(), #PB_UTF8)
    Next
    CloseFile(OutFile)
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Download do Basic Dignified Suite (clone via Git ou .zip do GitHub)
;- UseZipPacker() ja foi declarado em EditorSettings.pbi (incluido antes
;- deste arquivo - ver XIncludeFile em BadigEditor.pb).
;- ------------------------------------------------------------

#BadigSuite_GitUrl = "https://github.com/farique1/basic-dignified.git"
#BadigSuite_ZipUrl  = "https://github.com/farique1/basic-dignified/archive/refs/heads/main.zip"

UseNetworkTLS() ; necessario para ReceiveHTTPFile() conseguir falar https:// (GitHub)

; Descompacta ZipPath em TargetDir, removendo o prefixo de pasta unico que o
; GitHub inclui em arquivos de archive (ex.: "basic-dignified-main/") para que
; o conteudo do repositorio fique direto dentro de TargetDir, sem subpasta extra.
Procedure.b BadigCfg_ExtractZip(ZipPath.s, TargetDir.s)
  Protected Pack = OpenPack(#PB_Any, ZipPath, #PB_PackerPlugin_Zip)
  If Not Pack
    ProcedureReturn #False
  EndIf

  If Not ExaminePack(Pack)
    ClosePack(Pack)
    ProcedureReturn #False
  EndIf

  Protected Prefix.s = ""
  If NextPackEntry(Pack) > 0
    Protected FirstName.s = PackEntryName(Pack)
    Protected SlashPos = FindString(FirstName, "/")
    If SlashPos > 0
      Prefix = Left(FirstName, SlashPos)
    EndIf
  EndIf

  CreateDirectory(TargetDir)

  Protected EntryName.s, RelName.s, OutPath.s
  ExaminePack(Pack)
  While NextPackEntry(Pack) > 0
    EntryName = PackEntryName(Pack)
    RelName = EntryName
    If Prefix <> "" And Left(EntryName, Len(Prefix)) = Prefix
      RelName = Mid(EntryName, Len(Prefix) + 1)
    EndIf
    If RelName = ""
      Continue
    EndIf

    OutPath = TargetDir + "\" + RelName

    If Right(EntryName, 1) = "/"
      CreateDirectory(OutPath)
    Else
      CreateDirectory(GetPathPart(OutPath))
      UncompressPackFile(Pack, OutPath)
    EndIf
  Wend

  ClosePack(Pack)
  ProcedureReturn #True
EndProcedure

Procedure BadigCfg_DownloadViaGit(TargetDir.s)
  Protected Params.s = "clone --depth 1 " + #BadigSuite_GitUrl + " " + Chr(34) + TargetDir + Chr(34)
  Protected Prog = RunProgram("git", Params, GetPathPart(ProgramFilename()), #PB_Program_Wait | #PB_Program_Hide)
  If Not Prog
    MessageRequester("Erro", "Git nao encontrado. Instale o Git (https://git-scm.com/) ou use a opcao de download via ZIP.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected ExitCode = ProgramExitCode(Prog)
  CloseProgram(Prog)

  If ExitCode = 0
    MessageRequester("Basic Dignified Suite", "Clonado com sucesso em:" + Chr(10) + TargetDir,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  Else
    MessageRequester("Erro", "O comando 'git clone' falhou (codigo " + Str(ExitCode) + ")." + Chr(10) +
                     "Verifique se a pasta ja existe e nao esta vazia, ou tente a opcao de download via ZIP.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
  EndIf
EndProcedure

Procedure BadigCfg_DownloadViaZip(TargetDir.s)
  Protected TmpZip.s = GetTemporaryDirectory() + "basic-dignified-" + Str(Random(999999)) + ".zip"

  If Not ReceiveHTTPFile(#BadigSuite_ZipUrl, TmpZip)
    MessageRequester("Erro", "Falha ao baixar o arquivo ZIP do GitHub." + Chr(10) + "Verifique sua conexao com a internet.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  If Not BadigCfg_ExtractZip(TmpZip, TargetDir)
    MessageRequester("Erro", "Falha ao descompactar o arquivo ZIP baixado.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    DeleteFile(TmpZip)
    ProcedureReturn
  EndIf

  DeleteFile(TmpZip)
  MessageRequester("Basic Dignified Suite", "Baixado e descompactado com sucesso em:" + Chr(10) + TargetDir,
                   #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
EndProcedure

Procedure BadigCfg_DownloadSuite(ParentWindow, TargetDir.s)
  If Trim(TargetDir) = ""
    MessageRequester("Erro", "Informe o diretorio de instalacao antes de baixar.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  If FileSize(TargetDir) = -2
    Protected Confirm = MessageRequester("Basic Dignified Suite",
      "A pasta" + Chr(10) + TargetDir + Chr(10) + "ja existe. Continuar pode sobrescrever arquivos nela." + Chr(10) + Chr(10) + "Continuar?",
      #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning)
    If Confirm <> #PB_MessageRequester_Yes
      ProcedureReturn
    EndIf
  EndIf

  Protected Method = MessageRequester("Basic Dignified Suite",
    "Como deseja baixar?" + Chr(10) + Chr(10) +
    "SIM = clonar com Git (recomendado, permite atualizar depois)" + Chr(10) +
    "NAO = baixar o .zip da branch main e descompactar" + Chr(10) + Chr(10) +
    "Pasta de destino:" + Chr(10) + TargetDir,
    #PB_MessageRequester_YesNoCancel | #PB_MessageRequester_Info)

  Select Method
    Case #PB_MessageRequester_Yes
      BadigCfg_DownloadViaGit(TargetDir)
    Case #PB_MessageRequester_No
      BadigCfg_DownloadViaZip(TargetDir)
  EndSelect
EndProcedure

;- ------------------------------------------------------------
;- Selecao de maquina/extensao do openMSX (lista os arquivos .xml de
;- share/machines ou share/extensions, a partir do diretorio do executavel
;- configurado no campo acima) - pedido pelo usuario para nao precisar
;- digitar o nome exato da maquina/extensao de cabeca.
;- ------------------------------------------------------------

; Lista os nomes (sem a extensao .xml) dos arquivos .xml em Dir, ordenados
; alfabeticamente (case-insensitive). Devolve #False se o diretorio nao existir.
Procedure.b BadigCfg_ListXmlNames(Dir.s, List Names.s())
  ClearList(Names())
  If FileSize(Dir) <> -2 ; -2 = diretorio existe
    ProcedureReturn #False
  EndIf

  Protected Handle = ExamineDirectory(#PB_Any, Dir, "*.xml")
  If Not Handle
    ProcedureReturn #False
  EndIf

  While NextDirectoryEntry(Handle)
    If DirectoryEntryType(Handle) = #PB_DirectoryEntry_File
      Protected Name.s = DirectoryEntryName(Handle)
      AddElement(Names())
      Names() = Left(Name, Len(Name) - 4) ; remove ".xml"
    EndIf
  Wend
  FinishDirectory(Handle)

  SortList(Names(), #PB_Sort_Ascending | #PB_Sort_NoCase)
  ProcedureReturn #True
EndProcedure

; Abre uma janela modal simples com uma lista dos itens encontrados em Dir
; para o usuario escolher um (duplo-clique ou "OK"). Devolve o nome escolhido
; (sem .xml) ou "" se cancelado, se o diretorio nao existir ou vier vazio
; (mostra um aviso claro nesses dois ultimos casos, apontando para o campo
; do executavel do openMSX que define a base da busca).
Procedure.s BadigCfg_PickXmlName(ParentWindow, Title.s, Dir.s, CurrentValue.s)
  Protected NewList Names.s()

  If Not BadigCfg_ListXmlNames(Dir, Names())
    MessageRequester("Diretorio nao encontrado",
                     "Nao foi possivel encontrar:" + Chr(10) + Dir + Chr(10) + Chr(10) +
                     "Confira o caminho do executavel do openMSX configurado acima.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn ""
  EndIf

  If ListSize(Names()) = 0
    MessageRequester("Nada encontrado",
                     "Nenhum arquivo .xml encontrado em:" + Chr(10) + Dir,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn ""
  EndIf

  Protected WinW = 380, WinH = 420
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, Title,
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn ""
  EndIf
  DisableWindow(ParentWindow, #True)

  Protected G_List = ListViewGadget(#PB_Any, 15, 15, WinW - 30, WinH - 70)
  Protected SelectIndex = -1, i.i = 0
  ForEach Names()
    AddGadgetItem(G_List, -1, Names())
    If Names() = CurrentValue
      SelectIndex = i
    EndIf
    i + 1
  Next
  If SelectIndex >= 0
    SetGadgetState(G_List, SelectIndex)
  EndIf

  Protected G_Ok = ButtonGadget(#PB_Any, WinW - 220, WinH - 40, 100, 28, "OK")
  Protected G_Cancel = ButtonGadget(#PB_Any, WinW - 110, WinH - 40, 100, 28, "Cancelar")

  Protected Event, Quit = #False, Result.s = "", Sel.i

  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_List
            If EventType() = #PB_EventType_LeftDoubleClick
              Sel = GetGadgetState(G_List)
              If Sel >= 0
                Result = GetGadgetItemText(G_List, Sel)
              EndIf
              Quit = #True
            EndIf

          Case G_Ok
            Sel = GetGadgetState(G_List)
            If Sel >= 0
              Result = GetGadgetItemText(G_List, Sel)
            EndIf
            Quit = #True

          Case G_Cancel
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
  ProcedureReturn Result
EndProcedure

; Diretorio "share\<SubFolder>\" a partir do caminho do executavel do openMSX
; (respeitando o separador nativo do SO devolvido por GetPathPart).
Procedure.s BadigCfg_OpenMsxShareDir(ExePath.s, SubFolder.s)
  Protected Base.s = GetPathPart(ExePath)
  Protected Sep.s = Right(Base, 1)
  ProcedureReturn Base + "share" + Sep + SubFolder + Sep
EndProcedure

;- ------------------------------------------------------------
;- Janela de configuracao (Configurar -> Basic Dignified...)
;- ------------------------------------------------------------

Procedure BadigCfg_OpenSettingsWindow(ParentWindow)
  Protected WinW = 640, WinH = 600
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Configuracoes do Basic Dignified",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf

  DisableWindow(ParentWindow, #True)

  Protected Panel = PanelGadget(#PB_Any, 10, 10, WinW - 20, WinH - 60)

  ;- Pagina 1: Basic Dignified ------------------------------------------------
  AddGadgetItem(Panel, -1, "Basic Dignified")

  TextGadget(#PB_Any, 15, 15, 130, 20, "Linha inicial")
  Protected G_LineStart = StringGadget(#PB_Any, 150, 12, 60, 22, Str(BadigCfg\LineStart))

  TextGadget(#PB_Any, 230, 15, 110, 20, "Passo de linha")
  Protected G_LineStep = StringGadget(#PB_Any, 345, 12, 60, 22, Str(BadigCfg\LineStep))

  TextGadget(#PB_Any, 425, 15, 110, 20, "Tamanho do TAB")
  Protected G_TabLenght = StringGadget(#PB_Any, 540, 12, 50, 22, Str(BadigCfg\TabLenght))

  TextGadget(#PB_Any, 15, 47, 150, 20, "Verbosidade (0-4)")
  Protected G_VerboseLevel = StringGadget(#PB_Any, 170, 44, 50, 22, Str(BadigCfg\VerboseLevel))

  TextGadget(#PB_Any, 15, 85, 300, 20, "Opcoes gerais")
  Protected G_RemHeader = CheckBoxGadget(#PB_Any, 15, 110, 290, 22, "Incluir cabecalho REM")
  Protected G_StripSpaces = CheckBoxGadget(#PB_Any, 320, 110, 290, 22, "Remover todos os espacos")
  Protected G_CapitalizeAll = CheckBoxGadget(#PB_Any, 15, 138, 290, 22, "Converter tudo para maiusculas")
  Protected G_Translate = CheckBoxGadget(#PB_Any, 320, 138, 290, 40, "Traduzir caracteres Unicode especiais para nativos MSX")

  TextGadget(#PB_Any, 15, 190, 300, 20, "Relatorios (salvar/exibir)")
  Protected G_PrintReport = CheckBoxGadget(#PB_Any, 15, 215, 290, 22, "Exibir relatorios em vez de salvar")
  Protected G_LabelReport = CheckBoxGadget(#PB_Any, 320, 215, 290, 22, "Rotulos como REM no codigo convertido")
  Protected G_LineReport = CheckBoxGadget(#PB_Any, 15, 243, 290, 22, "Correspondencia de linhas")
  Protected G_VarReport = CheckBoxGadget(#PB_Any, 320, 243, 290, 22, "Substituicao de variaveis")
  Protected G_LexerReport = CheckBoxGadget(#PB_Any, 15, 271, 290, 22, "Saida do lexer (tokens)")
  Protected G_ParserReport = CheckBoxGadget(#PB_Any, 320, 271, 290, 22, "Saida do parser (tokens)")

  TextGadget(#PB_Any, 15, 313, 400, 20, "Diretorio de instalacao do Basic Dignified Suite")
  Protected G_InstallDir = StringGadget(#PB_Any, 15, 333, 460, 22, BadigCfg\InstallDir)
  Protected G_InstallDirBrowse = ButtonGadget(#PB_Any, 485, 333, 45, 22, "...")

  Protected G_DownloadSuite = ButtonGadget(#PB_Any, 15, 365, 260, 26, "Baixar Basic Dignified Suite...")
  TextGadget(#PB_Any, 285, 368, 260, 40, "Clona com Git ou baixa um .zip do GitHub e descompacta no diretorio acima.")

  ;- Pagina 2: MSX -------------------------------------------------------------
  AddGadgetItem(Panel, -1, "MSX")

  TextGadget(#PB_Any, 15, 15, 160, 20, "Converter ? / PRINT")
  Protected G_ConvertPrint = ComboBoxGadget(#PB_Any, 180, 12, 220, 22)
  AddGadgetItem(G_ConvertPrint, -1, "Nao converter")
  AddGadgetItem(G_ConvertPrint, -1, "? -> PRINT")
  AddGadgetItem(G_ConvertPrint, -1, "PRINT -> ?")

  TextGadget(#PB_Any, 15, 50, 200, 20, "Remover THEN/ELSE ou GOTO")
  Protected G_StripThenGoto = ComboBoxGadget(#PB_Any, 220, 47, 260, 22)
  AddGadgetItem(G_StripThenGoto, -1, "Nao remover")
  AddGadgetItem(G_StripThenGoto, -1, "THEN/ELSE (apos IF)")
  AddGadgetItem(G_StripThenGoto, -1, "GOTO (apos THEN/ELSE)")

  TextGadget(#PB_Any, 15, 95, 300, 20, "Tokenizador (msxbatoken)")
  Protected G_TkList = CheckBoxGadget(#PB_Any, 15, 120, 220, 22, "Gerar arquivo de listagem")
  TextGadget(#PB_Any, 250, 120, 110, 20, "Colunas (1-32)")
  Protected G_TkListWidth = StringGadget(#PB_Any, 365, 118, 50, 22, Str(BadigCfg\TkListWidth))

  Protected G_TkDelAscii = CheckBoxGadget(#PB_Any, 15, 155, 320, 22, "Apagar o ASCII apos tokenizar")

  TextGadget(#PB_Any, 15, 195, 380, 20, "Verbosidade do tokenizador (0-5, vazio = padrao)")
  Protected G_TkVerbose = StringGadget(#PB_Any, 15, 215, 60, 22, "")
  If BadigCfg\TkVerbose >= 0 : SetGadgetText(G_TkVerbose, Str(BadigCfg\TkVerbose)) : EndIf

  ;- Pagina 3: Emulador --------------------------------------------------------
  AddGadgetItem(Panel, -1, "Emulador")

  Protected G_EmRun = CheckBoxGadget(#PB_Any, 15, 15, 420, 22, "Abrir o openMSX e rodar o codigo apos gerar")
  Protected G_EmMonitor = CheckBoxGadget(#PB_Any, 15, 43, 420, 22, "Monitorar execucao (detectar erros em runtime)")
  Protected G_EmNoThrottle = CheckBoxGadget(#PB_Any, 15, 71, 420, 22, "Rodar sem limitador de velocidade (nothrottle)")

  TextGadget(#PB_Any, 15, 108, 300, 20, "Arquivo de configuracao (setting)")
  Protected G_EmSetting = StringGadget(#PB_Any, 15, 128, 480, 22, BadigCfg\EmSetting)
  Protected G_EmSettingBrowse = ButtonGadget(#PB_Any, 505, 128, 40, 22, "...")

  TextGadget(#PB_Any, 15, 160, 300, 20, "Maquina (machine)")
  Protected G_EmMachine = StringGadget(#PB_Any, 15, 180, 480, 22, BadigCfg\EmMachine)
  Protected G_EmMachineBrowse = ButtonGadget(#PB_Any, 505, 180, 40, 22, "...")

  TextGadget(#PB_Any, 15, 212, 400, 20, "Extensao de disco (extension), formato Nome:slot")
  Protected G_EmExtension = StringGadget(#PB_Any, 15, 232, 480, 22, BadigCfg\EmExtension)
  Protected G_EmExtensionBrowse = ButtonGadget(#PB_Any, 505, 232, 40, 22, "...")

  TextGadget(#PB_Any, 15, 264, 380, 20, "Verbosidade do emulador (0-4, vazio = padrao)")
  Protected G_EmVerbose = StringGadget(#PB_Any, 15, 284, 60, 22, "")
  If BadigCfg\EmVerbose >= 0 : SetGadgetText(G_EmVerbose, Str(BadigCfg\EmVerbose)) : EndIf

  TextGadget(#PB_Any, 15, 316, 500, 20, "Caminho do executavel do openMSX (grava no emulator_interface.ini)")
  Protected G_EmulatorPath = StringGadget(#PB_Any, 15, 336, 480, 22, BadigCfg\EmulatorPath)
  Protected G_EmulatorPathBrowse = ButtonGadget(#PB_Any, 505, 336, 40, 22, "...")

  CloseGadgetList()

  ;- Preenche os valores atuais -------------------------------------------------
  SetGadgetState(G_RemHeader, BadigCfg\RemHeader)
  SetGadgetState(G_StripSpaces, BadigCfg\StripSpaces)
  SetGadgetState(G_CapitalizeAll, BadigCfg\CapitalizeAll)
  SetGadgetState(G_Translate, BadigCfg\Translate)
  SetGadgetState(G_PrintReport, BadigCfg\PrintReport)
  SetGadgetState(G_LabelReport, BadigCfg\LabelReport)
  SetGadgetState(G_LineReport, BadigCfg\LineReport)
  SetGadgetState(G_VarReport, BadigCfg\VarReport)
  SetGadgetState(G_LexerReport, BadigCfg\LexerReport)
  SetGadgetState(G_ParserReport, BadigCfg\ParserReport)

  ; ConvertPrint guarda a forma FINAL desejada ("?" ou "P"), nao qual token
  ; esta sendo substituido - por isso o mapeamento e invertido em relacao ao
  ; rotulo do combo (item 1 "? -> PRINT" produz forma final "P", e vice-versa).
  Select BadigCfg\ConvertPrint
    Case "?" : SetGadgetState(G_ConvertPrint, 2)
    Case "P" : SetGadgetState(G_ConvertPrint, 1)
    Default  : SetGadgetState(G_ConvertPrint, 0)
  EndSelect

  Select BadigCfg\StripThenGoto
    Case "T" : SetGadgetState(G_StripThenGoto, 1)
    Case "G" : SetGadgetState(G_StripThenGoto, 2)
    Default  : SetGadgetState(G_StripThenGoto, 0)
  EndSelect

  SetGadgetState(G_TkList, BadigCfg\TkList)
  SetGadgetState(G_TkDelAscii, BadigCfg\TkDelAscii)

  SetGadgetState(G_EmRun, BadigCfg\EmRun)
  SetGadgetState(G_EmMonitor, BadigCfg\EmMonitor)
  SetGadgetState(G_EmNoThrottle, BadigCfg\EmNoThrottle)

  Protected G_Save = ButtonGadget(#PB_Any, WinW - 220, WinH - 40, 100, 28, "Salvar")
  Protected G_Cancel = ButtonGadget(#PB_Any, WinW - 110, WinH - 40, 100, 28, "Cancelar")

  Protected Event, Quit = #False, Saved = #False

  Repeat
    Event = WaitWindowEvent()

    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_InstallDirBrowse
            Protected PickInstallDir.s = PathRequester("Selecione o diretorio de instalacao do Basic Dignified Suite",
                                                        GetGadgetText(G_InstallDir))
            If PickInstallDir <> ""
              SetGadgetText(G_InstallDir, PickInstallDir)
            EndIf

          Case G_DownloadSuite
            BadigCfg_DownloadSuite(Win, GetGadgetText(G_InstallDir))

          Case G_EmSettingBrowse
            Protected PickSetting.s = OpenFileRequester("Selecione o arquivo de configuracao do openMSX",
                                                        GetGadgetText(G_EmSetting), "Todos os arquivos (*.*)|*.*", 0)
            If PickSetting <> ""
              SetGadgetText(G_EmSetting, PickSetting)
            EndIf

          Case G_EmulatorPathBrowse
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              Protected ExeFilter.s = "Executavel (*.exe)|*.exe|Todos os arquivos (*.*)|*.*"
            CompilerElse
              Protected ExeFilter.s = "Todos os arquivos (*.*)|*.*"
            CompilerEndIf
            Protected PickPath.s = OpenFileRequester("Selecione o executavel do openMSX",
                                                     GetGadgetText(G_EmulatorPath), ExeFilter, 0)
            If PickPath <> ""
              SetGadgetText(G_EmulatorPath, PickPath)
            EndIf

          Case G_EmMachineBrowse
            If Trim(GetGadgetText(G_EmulatorPath)) = ""
              MessageRequester("Maquina", "Informe o caminho do executavel do openMSX acima primeiro.",
                               #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
            Else
              Protected MachinesDir.s = BadigCfg_OpenMsxShareDir(GetGadgetText(G_EmulatorPath), "machines")
              Protected PickedMachine.s = BadigCfg_PickXmlName(Win, "Selecione a maquina",
                                                               MachinesDir, GetGadgetText(G_EmMachine))
              If PickedMachine <> ""
                SetGadgetText(G_EmMachine, PickedMachine)
              EndIf
            EndIf

          Case G_EmExtensionBrowse
            If Trim(GetGadgetText(G_EmulatorPath)) = ""
              MessageRequester("Extensao", "Informe o caminho do executavel do openMSX acima primeiro.",
                               #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
            Else
              Protected ExtensionsDir.s = BadigCfg_OpenMsxShareDir(GetGadgetText(G_EmulatorPath), "extensions")
              ; preserva ":slot" ja digitado, se houver - so troca o nome da extensao
              Protected CurExt.s = GetGadgetText(G_EmExtension)
              Protected CurExtName.s = CurExt
              Protected ColonPos.i = FindString(CurExt, ":")
              If ColonPos > 0
                CurExtName = Left(CurExt, ColonPos - 1)
              EndIf
              Protected PickedExt.s = BadigCfg_PickXmlName(Win, "Selecione a extensao",
                                                           ExtensionsDir, CurExtName)
              If PickedExt <> ""
                If ColonPos > 0
                  SetGadgetText(G_EmExtension, PickedExt + Mid(CurExt, ColonPos))
                Else
                  SetGadgetText(G_EmExtension, PickedExt)
                EndIf
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
    Protected InstallDirText.s = GetGadgetText(G_InstallDir)
    If Right(InstallDirText, 1) = "\" Or Right(InstallDirText, 1) = "/"
      InstallDirText = Left(InstallDirText, Len(InstallDirText) - 1)
    EndIf
    BadigCfg\InstallDir = InstallDirText

    BadigCfg\LineStart = Val(GetGadgetText(G_LineStart))
    BadigCfg\LineStep = Val(GetGadgetText(G_LineStep))
    BadigCfg\TabLenght = Val(GetGadgetText(G_TabLenght))
    BadigCfg\VerboseLevel = Val(GetGadgetText(G_VerboseLevel))
    BadigCfg\RemHeader = GetGadgetState(G_RemHeader)
    BadigCfg\StripSpaces = GetGadgetState(G_StripSpaces)
    BadigCfg\CapitalizeAll = GetGadgetState(G_CapitalizeAll)
    BadigCfg\Translate = GetGadgetState(G_Translate)
    BadigCfg\PrintReport = GetGadgetState(G_PrintReport)
    BadigCfg\LabelReport = GetGadgetState(G_LabelReport)
    BadigCfg\LineReport = GetGadgetState(G_LineReport)
    BadigCfg\VarReport = GetGadgetState(G_VarReport)
    BadigCfg\LexerReport = GetGadgetState(G_LexerReport)
    BadigCfg\ParserReport = GetGadgetState(G_ParserReport)

    ; item 1 = "? -> PRINT" (forma final PRINT); item 2 = "PRINT -> ?" (forma final ?)
    Select GetGadgetState(G_ConvertPrint)
      Case 1 : BadigCfg\ConvertPrint = "P"
      Case 2 : BadigCfg\ConvertPrint = "?"
      Default : BadigCfg\ConvertPrint = ""
    EndSelect

    Select GetGadgetState(G_StripThenGoto)
      Case 1 : BadigCfg\StripThenGoto = "T"
      Case 2 : BadigCfg\StripThenGoto = "G"
      Default : BadigCfg\StripThenGoto = ""
    EndSelect

    BadigCfg\TkList = GetGadgetState(G_TkList)
    BadigCfg\TkListWidth = Val(GetGadgetText(G_TkListWidth))
    BadigCfg\TkDelAscii = GetGadgetState(G_TkDelAscii)
    If Trim(GetGadgetText(G_TkVerbose)) = ""
      BadigCfg\TkVerbose = -1
    Else
      BadigCfg\TkVerbose = Val(GetGadgetText(G_TkVerbose))
    EndIf

    BadigCfg\EmRun = GetGadgetState(G_EmRun)
    BadigCfg\EmSetting = GetGadgetText(G_EmSetting)
    BadigCfg\EmMachine = GetGadgetText(G_EmMachine)
    BadigCfg\EmExtension = GetGadgetText(G_EmExtension)
    BadigCfg\EmNoThrottle = GetGadgetState(G_EmNoThrottle)
    BadigCfg\EmMonitor = GetGadgetState(G_EmMonitor)
    If Trim(GetGadgetText(G_EmVerbose)) = ""
      BadigCfg\EmVerbose = -1
    Else
      BadigCfg\EmVerbose = Val(GetGadgetText(G_EmVerbose))
    EndIf
    BadigCfg\EmulatorPath = GetGadgetText(G_EmulatorPath)

    BadigCfg_Save()
    BadigCfg_SyncEmulatorIni()
  EndIf

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
EndProcedure
