;
; ------------------------------------------------------------
;  OpenMSXBridge.pbi - ponte com o openMSX pra controle externo (menu
;  "Executar -> openMSX", janela em OpenMSXConsoleGui.pbi).
;
;  Historico curto (por que isto NAO usa "-control stdio"): a primeira
;  versao usava "-control stdio" + RunProgram(...#PB_Program_Write) pra
;  escrever comandos no stdin do processo, seguindo a doc oficial
;  "Controlling openMSX from External Applications". Nao funcionou -
;  nenhum comando surtia efeito, nem resposta nenhuma no log (so o boot
;  default do openMSX, independente do nosso lado do pipe). Lendo o
;  Catapult de verdade (openmsx/catapult/src/openMSXController.cpp,
;  Launch(), bloco #ifdef __WXMSW__) ficou claro o motivo: NO WINDOWS, o
;  proprio Catapult NUNCA usa "-control stdio" - ele usa
;  "-control pipe:<nome>" (um NAMED PIPE dedicado so pra comandos de
;  entrada) e mantem STDOUT/STDERR normais (via pipe anonimo comum,
;  CreateProcess+STARTF_USESTDHANDLES) so pra ler respostas/log. Ou seja: a
;  metade "escrever no stdin" do protocolo "-control stdio" e a que nao e
;  confiavel no Windows (motivo exato nao documentado nem no codigo do
;  Catapult, so o workaround) - a metade "ler do stdout" continua normal
;  (mesmo RunProgram(...#PB_Program_Read|Error) que ja usavamos).
;
;  Reescrito aqui pra seguir exatamente esse padrao: comandos saem por um
;  named pipe que ABRIMOS NOS MESMOS (CreateNamedPipe_ com
;  PIPE_ACCESS_OUTBOUND - so escrita, mesma direcao que o Catapult usa),
;  openMSX conecta nele sozinho ao processar "-control pipe:<nome>"
;  (CliConnection.cc, PipeConnection::PipeConnection() abre o pipe como
;  cliente via CreateFileA) - e so RunProgram(...#PB_Program_Read|Error)
;  pra ler as respostas/log, sem #PB_Program_Write nenhum (nao mexemos no
;  stdin de verdade do processo).
;
;  ConnectNamedPipe_() bloqueia ate o openMSX conectar - roda numa
;  CreateThread() dedicada (mesma ideia exata de
;  openmsx/catapult/src/PipeConnectThread.cpp) pra nao travar a GUI
;  enquanto o openMSX ainda esta subindo.
; ------------------------------------------------------------
;

#PIPE_ACCESS_OUTBOUND = $00000002
#OMSX_PipeType_Byte    = $00000000
#OMSX_PipeMode_Wait    = $00000000
#OMSX_PipeBufSize      = 8192

Global OMSX_Prog.i = 0
Global OMSX_PipeHandle.i = 0
Global OMSX_PipeConnected.b = #False
Global OMSX_PipeThread.i = 0
Global OMSX_LaunchCounter.i = 0

; Estado ao vivo (Ligado/Pausado) - alimentado por "<update type="setting" ...>", NAO por
; reply de comando. Ver comentario de OMSX_PipeConnectThread() ("openmsx_update enable
; setting"): diferente de so ler a resposta do comando que A GENTE mandou (que fica muda
; se o estado mudar por outro caminho - tecla de pause dentro da janela do openMSX, script
; Tcl, etc.), isso reflete QUALQUER mudanca de "power"/"pause", nao só a nossa própria.
; "*Known" comeca #False porque nao sabemos o estado real ate a primeira atualizacao chegar
; (o boot manda "set power on" mas a confirmacao só vem depois, de forma assíncrona).
Global OMSX_PowerKnown.b = #False
Global OMSX_PowerOn.b = #False
Global OMSX_PausedKnown.b = #False
Global OMSX_Paused.b = #False

Declare OMSX_SendCommand(Cmd.s)
Declare OMSX_ShowWindow()

; #True se o processo guardado em OMSX_Prog ainda esta vivo. Alem de
; consultar, tambem faz a faxina (fecha handles e zera estado) quando o
; openMSX ja morreu por fora (usuario fechou a janela do emulador, crash,
; etc.) - assim o resto do modulo nunca precisa checar isso duas vezes.
Procedure.b OMSX_IsRunning()
  If OMSX_Prog = 0
    ProcedureReturn #False
  EndIf
  If Not ProgramRunning(OMSX_Prog)
    CloseProgram(OMSX_Prog)
    OMSX_Prog = 0
    If OMSX_PipeHandle
      CloseHandle_(OMSX_PipeHandle)
      OMSX_PipeHandle = 0
    EndIf
    OMSX_PipeConnected = #False
    OMSX_PowerKnown = #False
    OMSX_PausedKnown = #False
    ProcedureReturn #False
  EndIf
  ProcedureReturn #True
EndProcedure

; Mesma convencao "-machine"/"-ext" (aceitando "Nome" ou "Nome:slot", onde o
; slot vira parte do NOME da flag, ex. "-exta") ja usada por RunOnOpenMSX()
; em BadigEditor.pb - mantida separada aqui porque as duas funcoes montam
; parametros diferentes (RunOnOpenMSX tambem monta "-diska", esta so
; acrescenta "-control pipe:<nome>").
Procedure.s OMSX_BuildParams(PipeName.s)
  Protected Params.s = "-control pipe:" + PipeName + " "
  If BadigCfg\EmMachine <> ""
    Params + "-machine " + Chr(34) + BadigCfg\EmMachine + Chr(34) + " "
  EndIf
  If BadigCfg\EmExtension <> ""
    Protected ExtValue.s = BadigCfg\EmExtension
    Protected ExtFlag.s = "-ext"
    Protected ColonPos.i = FindString(ExtValue, ":")
    If ColonPos > 0
      ExtFlag = "-" + Mid(ExtValue, ColonPos + 1)
      ExtValue = Left(ExtValue, ColonPos - 1)
    EndIf
    Params + ExtFlag + " " + Chr(34) + ExtValue + Chr(34) + " "
  EndIf
  ProcedureReturn Params
EndProcedure

; Escreve bytes crus no named pipe de comando - usado tanto pelo handshake
; "<openmsx-control>" quanto por OMSX_SendCommand() (que so embrulha o
; texto em "<command>...</command>" antes de chamar isto).
Procedure OMSX_SendRaw(Text.s)
  If OMSX_PipeHandle = 0
    ProcedureReturn
  EndIf
  Protected *Buf = UTF8(Text)
  Protected BufLen = StringByteLength(Text, #PB_UTF8)
  Protected BytesWritten.l
  WriteFile_(OMSX_PipeHandle, *Buf, BufLen, @BytesWritten, #Null)
  FreeMemory(*Buf)
EndProcedure

; Roda numa thread a parte (ver comentario no topo do arquivo) - bloqueia
; em ConnectNamedPipe_() ate o openMSX (processo cliente) conectar nesse
; pipe, depois manda a sequencia de boot direto daqui (equivalente ao
; PostLaunch()/InitLaunchScript() do Catapult): handshake
; "<openmsx-control>", "unset renderer" (tira do renderer "none" que
; "-control" força por padrao - nome do renderer padrao varia entre builds
; do openMSX, entao reverter pro default e mais seguro que um nome fixo
; tipo "SDL"), "set power on" (a maquina fica desligada sob "-control",
; confirmado lendo CommandLineParser::parse()/main.cc do openMSX: o
; reactor.powerOn() so roda quando o parseStatus e RUN, nao CONTROL).
Procedure OMSX_PipeConnectThread(*Dummy)
  Protected Ok = ConnectNamedPipe_(OMSX_PipeHandle, #Null)
  ; ERROR_PIPE_CONNECTED (535): cliente ja tinha conectado antes desta
  ; chamada (corrida rara, mas nao e erro de verdade nesse caso).
  If Ok Or GetLastError_() = 535
    OMSX_PipeConnected = #True
    OMSX_SendRaw("<openmsx-control>" + Chr(10))
    ; Assina notificacoes de mudanca de qualquer "setting" (comando real do
    ; openMSX, GlobalCommandController.cc "openmsx_update enable <tipo>")
    ; ANTES do "set power on" abaixo, de proposito - assim ja capturamos a
    ; propria transicao de ligar no boot, nao so mudancas futuras. Sem isso,
    ; o unico jeito de saber se a maquina esta ligada/pausada e o reply
    ; direto de um comando que A GENTE mandou (fica cego se o estado mudar
    ; por outro caminho, ex. o usuario apertando pause na janela do proprio
    ; openMSX). Com a assinatura, toda mudanca de "power"/"pause" (nossa ou
    ; nao) chega como "<update type="setting" name="...">valor</update>" -
    ; ver OMSX_Poll()/OMSX_ExtractSettingUpdate().
    OMSX_SendCommand("openmsx_update enable setting")
    OMSX_SendCommand("unset renderer")
    OMSX_SendCommand("set power on")
  EndIf
EndProcedure

; Abre o openMSX com o named pipe de comando ja criado ANTES do processo
; subir (precisa existir primeiro - o construtor de PipeConnection do
; openMSX tenta abrir o pipe como cliente assim que processa
; "-control pipe:<nome>" na linha de comando, e falha se o servidor - nos -
; ainda nao tiver criado). Reaproveita o processo atual se ja estiver
; rodando (#True direto, sem abrir um segundo). Nao mostra
; MessageRequester nenhum - quem chama decide como avisar o usuario (a
; janela de console, em OpenMSXConsoleGui.pbi, ja checa EmulatorPath antes
; de chegar aqui).
Procedure.b OMSX_Start()
  If OMSX_IsRunning()
    ProcedureReturn #True
  EndIf
  If BadigCfg\EmulatorPath = ""
    ProcedureReturn #False
  EndIf

  OMSX_LaunchCounter + 1
  ; Nome unico por lancamento (PID do editor + contador), mesma ideia do
  ; Catapult ("Catapult-<pid>-<contador>") - evita colisao entre duas
  ; instancias do editor ou dois "Executar -> openMSX" seguidos.
  Protected PipeName.s = "BadigEditorOMSX_" + Str(GetCurrentProcessId_()) + "_" + Str(OMSX_LaunchCounter)
  Protected FullPipePath.s = "\\.\pipe\" + PipeName

  OMSX_PipeHandle = CreateNamedPipe_(FullPipePath, #PIPE_ACCESS_OUTBOUND,
                                      #OMSX_PipeType_Byte | #OMSX_PipeMode_Wait,
                                      1, #OMSX_PipeBufSize, #OMSX_PipeBufSize, 0, #Null)
  If OMSX_PipeHandle = 0 Or OMSX_PipeHandle = -1
    OMSX_PipeHandle = 0
    ProcedureReturn #False
  EndIf

  Protected Params.s = OMSX_BuildParams(PipeName)
  OMSX_Prog = RunProgram(BadigCfg\EmulatorPath, Params, GetPathPart(BadigCfg\EmulatorPath),
                          #PB_Program_Open | #PB_Program_Read | #PB_Program_Error)
  If Not OMSX_Prog
    CloseHandle_(OMSX_PipeHandle)
    OMSX_PipeHandle = 0
    ProcedureReturn #False
  EndIf

  OMSX_PipeConnected = #False
  OMSX_PipeThread = CreateThread(@OMSX_PipeConnectThread(), 0)
  ProcedureReturn #True
EndProcedure

; Escapa "&"/"<"/">" como entidades XML antes de embrulhar em "<command>...</command>" -
; sem isso, um comando (ou texto digitado via OMSX_TypeText()) contendo esses caracteres
; quebra silenciosamente o parser real do openMSX. Confirmado lendo
; openmsx/openmsx/src/events/AdhocCliCommParser.cc: e uma maquina de estados byte-a-byte
; que, dentro de "<command>", trata "<" e "&" como inicio de tag/entidade - um "<" cru
; NAO seguido por "/command>" (ex. "IF X<10" colado de um listing BASIC) faz o parser
; voltar pro estado inicial "procurando <command>", **descartando** o resto do comando
; sem erro nenhum reportado. Mesma logica de escape que o Catapult de verdade usa
; (openmsx/catapult/src/openMSXController.cpp, WriteCommand(),
; "xmlEncodeEntitiesReentrant()") antes de mandar qualquer comando pelo pipe.
Procedure.s OMSX_XmlEscape(Text.s)
  Protected Escaped.s = Text
  Escaped = ReplaceString(Escaped, "&", "&amp;")
  Escaped = ReplaceString(Escaped, "<", "&lt;")
  Escaped = ReplaceString(Escaped, ">", "&gt;")
  ProcedureReturn Escaped
EndProcedure

Procedure OMSX_SendCommand(Cmd.s)
  If OMSX_IsRunning() And OMSX_PipeConnected And Trim(Cmd) <> ""
    OMSX_SendRaw("<command>" + OMSX_XmlEscape(Cmd) + "</command>" + Chr(10))
  EndIf
EndProcedure

; Escapa Text pra virar UMA "palavra" Tcl valida (nivel Tcl, ANTES do XML-escape acima,
; que e nivel transporte - as duas camadas juntas espelham exatamente o Catapult:
; utils::tclEscapeWord() + xmlEncodeEntitiesReentrant() em WriteCommand()). Preserva o
; conteudo literal (espacos, quebras de linha, chaves, etc.) escapando o que o parser Tcl
; do proprio comando (nao o parser XML) trataria como separador/especial dentro de
; "<command>...</command>". ORDEM IMPORTA: escapar a barra invertida primeiro, senao os
; escapes inseridos pelos passos seguintes seriam escapados de novo.
Procedure.s OMSX_TclEscapeWord(Text.s)
  Protected Escaped.s = Text
  Escaped = ReplaceString(Escaped, "\", "\\")
  ; CRLF (EditorGadget no Windows) -> um so marcador antes de virar "\r" (2 chars: barra +
  ; r) - o Tcl interpreta essa sequencia como um CR de verdade (Enter) ao "digitar",
  ; equivalente ao "\n" -> "\\r" do Catapult (wxTextCtrl la so usa "\n").
  Escaped = ReplaceString(Escaped, Chr(13) + Chr(10), Chr(10))
  Escaped = ReplaceString(Escaped, Chr(10), "\r")
  Escaped = ReplaceString(Escaped, "$", "\$")
  Escaped = ReplaceString(Escaped, Chr(34), "\" + Chr(34))
  Escaped = ReplaceString(Escaped, "[", "\[")
  Escaped = ReplaceString(Escaped, "]", "\]")
  Escaped = ReplaceString(Escaped, "}", "\}")
  Escaped = ReplaceString(Escaped, "{", "\{")
  Escaped = ReplaceString(Escaped, " ", "\ ")
  Escaped = ReplaceString(Escaped, ";", "\;")
  ProcedureReturn Escaped
EndProcedure

; Digita Text no MSX emulado, como se fosse teclado de verdade - mesmo mecanismo do
; Catapult (InputPage.cpp, OnTypeText(): "type -- " + tclEscapeWord(texto)). O comando
; "type" (script Tcl embutido no openMSX, share/scripts/type.tcl) delega por padrao pro
; comando nativo "type_via_keyboard" (Keyboard.cc, KeyInserter::execute()), que pressiona/
; solta teclas de verdade na matriz de teclado emulada - "\r" dentro do texto vira Enter.
; "--" avisa o parser de flags do openMSX (parseTclArgs) que acabaram as opcoes tipo
; "-freq"/"-release"/"-cancel", entao mesmo um texto comecando com "-" nao e confundido
; com uma flag.
Procedure OMSX_TypeText(Text.s)
  If Trim(Text) = ""
    ProcedureReturn
  EndIf
  OMSX_SendCommand("type -- " + OMSX_TclEscapeWord(Text))
EndProcedure

; Atalho pro botao "Mostrar janela" da console (OpenMSXConsoleGui.pbi) -
; mesmo comando que o boot automatico ja manda (ver
; OMSX_PipeConnectThread()), disponivel sob demanda pra quando o usuario
; tiver voltado pro renderer "none" na mao (ex. via "set renderer none").
;
; "unset renderer" (reverte pro valor padrao), NAO "set renderer SDL" - o
; nome exato do renderer com janela varia entre builds do openMSX (SDL,
; SDLGL, SDLGL-PP...) e um nome errado so gera um "nok" silencioso no
; console sem abrir nada. O Catapult de verdade (openMSX/catapult no
; GitHub, src/player.py, classe VisibleSetting.setValue - e tambem
; InitLaunchScript() do C++ real, "AddCommand(wxT("unset renderer"))")
; faz exatamente isso.
Procedure OMSX_ShowWindow()
  OMSX_SendCommand("unset renderer")
EndProcedure

; Tira as tags XML mais comuns do protocolo pra sobrar so o texto legivel no
; console - limpeza simples por substituicao de string (nao um parser XML de
; verdade), mesmo espirito do msx_bridge.py (que so faz .replace("<reply>",
; "").replace("</reply>", "")). Suficiente pra um console de comando manual;
; se um dia precisar interpretar o resultado (ok/nok) por codigo, ai sim
; vale a pena um parser de verdade.
; Extrai o valor de uma linha crua "<update type="setting" name="X">valor</update>"
; (ANTES de OMSX_CleanLine(), que mutila as tags) - "" se a linha nao for uma atualizacao
; de "SettingName". Usado por OMSX_Poll() pra manter OMSX_PowerOn/OMSX_Paused sincronizados
; com o estado real do openMSX (ver assinatura "openmsx_update enable setting" em
; OMSX_PipeConnectThread()). Parser simples por substring (mesmo espirito de
; OMSX_CleanLine() - nao um parser XML de verdade), suficiente porque o formato de
; "<update>" do proprio openMSX (CliConnection.cc, update()) e sempre essa forma fixa.
Procedure.s OMSX_ExtractSettingUpdate(RawLine.s, SettingName.s)
  If FindString(RawLine, "<update type=" + Chr(34) + "setting" + Chr(34)) = 0
    ProcedureReturn ""
  EndIf
  Protected Needle.s = "name=" + Chr(34) + SettingName + Chr(34) + ">"
  Protected NamePos.i = FindString(RawLine, Needle)
  If NamePos = 0
    ProcedureReturn ""
  EndIf
  Protected ValueStart.i = NamePos + Len(Needle)
  Protected ValueEnd.i = FindString(RawLine, "<", ValueStart)
  If ValueEnd = 0
    ProcedureReturn ""
  EndIf
  ProcedureReturn Mid(RawLine, ValueStart, ValueEnd - ValueStart)
EndProcedure

Procedure.s OMSX_CleanLine(Line.s)
  Protected Clean.s = Trim(Line)
  Clean = ReplaceString(Clean, "<reply result=" + Chr(34) + "nok" + Chr(34) + ">", "[ERRO] ")
  Clean = ReplaceString(Clean, "<reply result=" + Chr(34) + "ok" + Chr(34) + ">", "")
  Clean = ReplaceString(Clean, "<reply>", "")
  Clean = ReplaceString(Clean, "</reply>", "")
  Clean = ReplaceString(Clean, "<log level=" + Chr(34) + "info" + Chr(34) + ">", "[log] ")
  Clean = ReplaceString(Clean, "<log level=" + Chr(34) + "warning" + Chr(34) + ">", "[aviso] ")
  Clean = ReplaceString(Clean, "<log level=" + Chr(34) + "error" + Chr(34) + ">", "[ERRO] ")
  Clean = ReplaceString(Clean, "</log>", "")
  Clean = ReplaceString(Clean, "<update type=" + Chr(34), "[update ")
  Clean = ReplaceString(Clean, "</update>", "")
  Clean = ReplaceString(Clean, "<openmsx-output>", "")
  Clean = ReplaceString(Clean, "</openmsx-output>", "")
  ProcedureReturn Trim(Clean)
EndProcedure

; Chamada a cada tick do timer da janela de console (ver OpenMSXConsoleGui.pbi):
; devolve as linhas novas de stdout/stderr ja limpas, uma por linha
; separadas por Chr(10) ("" se nao houver nada novo). "" tambem quando o
; processo ja nao esta mais rodando - quem chama usa OMSX_IsRunning() a
; parte pra distinguir esse caso. A sequencia de boot (handshake/renderer/
; power) NAO e mais disparada daqui - ver OMSX_PipeConnectThread(), que
; dispara assim que a conexao de verdade acontece, em vez de um timer fixo.
Procedure.s OMSX_Poll()
  If Not OMSX_IsRunning()
    ProcedureReturn ""
  EndIf

  Protected Result.s = ""
  Protected Line.s
  Protected SettingVal.s
  While OMSX_Prog And AvailableProgramOutput(OMSX_Prog)
    Line = ReadProgramString(OMSX_Prog)
    If Line = "" : Break : EndIf

    ; Le o estado ao vivo da linha CRUA, antes de limpar (OMSX_CleanLine() mutila as
    ; tags) - ver comentario de OMSX_ExtractSettingUpdate() e a assinatura
    ; "openmsx_update enable setting" em OMSX_PipeConnectThread().
    SettingVal = OMSX_ExtractSettingUpdate(Line, "power")
    If SettingVal <> ""
      OMSX_PowerOn = Bool(SettingVal = "true")
      OMSX_PowerKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "pause")
    If SettingVal <> ""
      OMSX_Paused = Bool(SettingVal = "true")
      OMSX_PausedKnown = #True
    EndIf

    Line = OMSX_CleanLine(Line)
    If Line <> ""
      Result + Line + Chr(10)
    EndIf
  Wend
  ; ReadProgramError() nao tem uma "AvailableProgramError()" irma (so existe
  ; AvailableProgramOutput(), pro stdout) - mas ao contrario de
  ; ReadProgramString()/ReadProgramData(), ela ja e nao-bloqueante por conta
  ; propria (doc: "doesn't halt the program flow if no error output is
  ; available"), devolvendo "" quando nao ha nada novo - dá pra chamar direto
  ; em loop ate isso acontecer.
  If OMSX_Prog
    Repeat
      Line = ReadProgramError(OMSX_Prog)
      If Line = "" : Break : EndIf
      Result + "[stderr] " + Trim(Line) + Chr(10)
    ForEver
  EndIf

  ProcedureReturn Result
EndProcedure

; Texto curto pra um indicador de estado na GUI (OpenMSXConsoleGui.pbi) - "?" enquanto o
; primeiro "<update type="setting" ...>" ainda nao chegou (ver OMSX_PowerKnown/
; OMSX_PausedKnown). Chamar so quando OMSX_IsRunning() for #True.
Procedure.s OMSX_StatusText()
  Protected Txt.s
  If OMSX_PowerKnown
    If OMSX_PowerOn : Txt = "Ligado" : Else : Txt = "Desligado" : EndIf
  Else
    Txt = "?"
  EndIf
  Txt + "  |  "
  If OMSX_PausedKnown
    If OMSX_Paused : Txt + "PAUSADO" : Else : Txt + "Rodando" : EndIf
  Else
    Txt + "?"
  EndIf
  ProcedureReturn Txt
EndProcedure
