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

Procedure BadigCfg_SetDefaults()
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

  Protected IniPath.s = GetPathPart(ProgramFilename()) + "..\badig\msx\emulator_interface.ini"
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
;- Linha de comando equivalente do badig.py a partir das configuracoes
;- ------------------------------------------------------------

Procedure.s BadigCfg_QuoteArg(Value.s)
  If FindString(Value, " ")
    ProcedureReturn Chr(34) + Value + Chr(34)
  Else
    ProcedureReturn Value
  EndIf
EndProcedure

Procedure.s BadigCfg_BuildCliArgs()
  Protected Args.s = ""

  Args + " -id " + BadigCfg\SystemId
  Args + " -tl " + Str(BadigCfg\TabLenght)
  Args + " -ls " + Str(BadigCfg\LineStart)
  Args + " -lp " + Str(BadigCfg\LineStep)
  If Not BadigCfg\RemHeader   : Args + " -rh"  : EndIf
  If BadigCfg\StripSpaces     : Args + " -ss"  : EndIf
  If BadigCfg\CapitalizeAll   : Args + " -ca"  : EndIf
  If BadigCfg\Translate       : Args + " -tr"  : EndIf
  Args + " -vb " + Str(BadigCfg\VerboseLevel)
  If BadigCfg\PrintReport     : Args + " -prr" : EndIf
  If BadigCfg\LabelReport     : Args + " -lbr" : EndIf
  If BadigCfg\LineReport      : Args + " -lnr" : EndIf
  If BadigCfg\VarReport       : Args + " -var" : EndIf
  If BadigCfg\LexerReport     : Args + " -lex" : EndIf
  If BadigCfg\ParserReport    : Args + " -par" : EndIf

  If BadigCfg\ConvertPrint <> ""
    Args + " -cp " + LCase(BadigCfg\ConvertPrint)
  EndIf
  If BadigCfg\StripThenGoto <> ""
    Args + " -tg " + LCase(BadigCfg\StripThenGoto)
  EndIf

  Args + " --tk_tokenize"
  If BadigCfg\TkList
    Args + " --tk_list " + Str(BadigCfg\TkListWidth)
  EndIf
  If BadigCfg\TkDelAscii
    Args + " --tk_del_ascii"
  EndIf
  If BadigCfg\TkVerbose >= 0
    Args + " --tk_verbose " + Str(BadigCfg\TkVerbose)
  EndIf

  If BadigCfg\EmRun
    Args + " --em_run"
    If BadigCfg\EmSetting <> ""   : Args + " --em_setting " + BadigCfg_QuoteArg(BadigCfg\EmSetting) : EndIf
    If BadigCfg\EmMachine <> ""   : Args + " --em_machine " + BadigCfg_QuoteArg(BadigCfg\EmMachine) : EndIf
    If BadigCfg\EmExtension <> "" : Args + " --em_extension " + BadigCfg_QuoteArg(BadigCfg\EmExtension) : EndIf
    If BadigCfg\EmNoThrottle      : Args + " --em_nothrottle" : EndIf
    If BadigCfg\EmMonitor         : Args + " --em_monitor" : EndIf
    If BadigCfg\EmVerbose >= 0    : Args + " --em_verbose " + Str(BadigCfg\EmVerbose) : EndIf
  EndIf

  ProcedureReturn Args
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
  Protected G_EmMachine = StringGadget(#PB_Any, 15, 180, 545, 22, BadigCfg\EmMachine)

  TextGadget(#PB_Any, 15, 212, 400, 20, "Extensao de disco (extension), formato Nome:slot")
  Protected G_EmExtension = StringGadget(#PB_Any, 15, 232, 545, 22, BadigCfg\EmExtension)

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
      Case #PB_Event_Menu
        Select EventGadget()
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
