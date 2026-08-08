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

; Mesma ideia (alimentado por "<update type="setting" ...>", nao por reply de
; comando - ver OMSX_Poll()) pros controles da aba "Outros comandos"
; (OpenMSXConsoleGui.pbi): velocidade de emulacao ("speed", 1-9999%),
; interruptor de firmware residente ("firmwareswitch", so existe em algumas
; maquinas) e Ren Sha Turbo ("renshaturbo", 0-100, so existe em maquinas com
; suporte de hardware - turboR etc.). "*Known" comeca #False pelo mesmo
; motivo de OMSX_PowerKnown: nao sabemos o valor real ate a primeira
; atualizacao chegar.
Global OMSX_SpeedKnown.b = #False
Global OMSX_Speed.i = 100
Global OMSX_FirmwareKnown.b = #False
Global OMSX_FirmwareOn.b = #False
Global OMSX_RenshaKnown.b = #False
Global OMSX_RenshaOn.b = #False

; LEDs da aba "Video" (OpenMSXConsoleGui.pbi) - "power" e "pause" reaproveitam
; OMSX_PowerOn/OMSX_Paused acima (mesmo settings, ja rastreados: ligar a
; maquina ou pausar TAMBEM acende o LED correspondente, nao sao coisas
; separadas). Caps/Kana/Turbo/FDD sao read-only (o openMSX que controla,
; nunca setados por nos) mas passam pelo MESMO mecanismo de "<update
; type="setting">" que tudo mais aqui - simples questao de assinar o nome
; certo.
Global OMSX_LedCapsKnown.b = #False
Global OMSX_LedCapsOn.b = #False
Global OMSX_LedKanaKnown.b = #False
Global OMSX_LedKanaOn.b = #False
Global OMSX_LedTurboKnown.b = #False
Global OMSX_LedTurboOn.b = #False
Global OMSX_LedFddKnown.b = #False
Global OMSX_LedFddOn.b = #False

; FPS (aba "Video") - NAO e um "setting" (nao vem via "openmsx_update"), e
; uma estatistica de execucao consultada sob demanda com "openmsx_info fps".
; Como o protocolo daqui e "fire and forget" (sem id de correlacao
; comando->resposta), OMSX_AwaitingFps marca "a proxima linha <reply> que
; chegar e a resposta dessa consulta" - funciona bem desde que ninguem mais
; mande outro comando bem no meio (mesma suposicao de ordem serial que o
; resto da ponte ja faz implicitamente). Quem dispara a consulta
; periodicamente e a GUI (nao aqui, pra nao gerar trafego sem ninguem
; pedindo) - ver OMSX_QueryFps().
Global OMSX_FpsKnown.b = #False
Global OMSX_Fps.s = ""
Global OMSX_AwaitingFps.b = #False

; Toggles da aba "Video" (OpenMSXConsoleGui.pbi) - mesmo mecanismo de
; sempre ("<update type="setting">", ver OMSX_Poll()). OMSX_TvModeOn e
; derivado da string de "scale_algorithm" (nao um bool nativo do openMSX):
; #True quando o valor atual e exatamente "TV" (ver RenderSettings.cc real -
; "simple"/"ScaleNx"/"hq"/"RGBtriplet"/"TV" sao os valores possiveis, so
; expomos o toggle simple<->TV pedido, nao o combo completo).
Global OMSX_VSyncKnown.b = #False
Global OMSX_VSyncOn.b = #False
; "Modo TV" virou dropdown de verdade (pedido explicito do usuario, "como no
; Catapult") com as 5 opcoes reais de scale_algorithm (simple/ScaleNx/hq/
; RGBtriplet/TV, ver RenderSettings.cc do openMSX) em vez de um toggle
; simple<->TV so - guarda a string crua, nao um booleano.
Global OMSX_ScaleAlgorithmKnown.b = #False
Global OMSX_ScaleAlgorithm.s = "simple"
Global OMSX_DeinterlaceKnown.b = #False
Global OMSX_DeinterlaceOn.b = #False
Global OMSX_LimitSpritesKnown.b = #False
Global OMSX_LimitSpritesOn.b = #False
Global OMSX_FullscreenKnown.b = #False
Global OMSX_FullscreenOn.b = #False
Global OMSX_DisableSpritesKnown.b = #False
Global OMSX_DisableSpritesOn.b = #False

; Barras estilo CRT da aba "Video" - mesmo mecanismo, sincroniza o valor
; real (idempotente durante arraste manual - ver comentario no timer de
; poll, OpenMSXConsoleGui.pbi). Gamma fica como STRING (nao Int) porque e
; float ("1.10" etc.) - convertido pra posicao de trackbar (*10) so na hora
; de exibir, ver OMSXGui_OpenWindow().
Global OMSX_ScanlineKnown.b = #False
Global OMSX_Scanline.i = 20
Global OMSX_BlurKnown.b = #False
Global OMSX_Blur.i = 50
Global OMSX_GlowKnown.b = #False
Global OMSX_Glow.i = 0
Global OMSX_GammaKnown.b = #False
Global OMSX_Gamma.s = "1.1"
Global OMSX_NoiseKnown.b = #False
Global OMSX_Noise.i = 0

; Dispositivos de som da aba "Volume" (OpenMSXConsoleGui.pbi) - descobertos
; DINAMICAMENTE, nunca por nome fixo. Confirmado ao vivo contra um openMSX de
; verdade (2026-08-08): so "PSG" e "keyclick" sao nomes fixos - qualquer
; outro dispositivo (SCC+, MSX-MUSIC/FM-PAC, MoonSound FM/wave, MSX-AUDIO,
; cassete, DAC de cartucho) usa o nome comercial COMPLETO do hardware
; especifico conectado (ex.: "Konami SCC+ Cartridge with expanded RAM (1)",
; "Sunrise MoonSound (1) FM") - varia por ROM/config/quantidade de
; instancias, entao fixar sliders por nome simplesmente nao funcionaria.
; Em vez disso, qualquer "<update type="setting" name="X_volume">" que
; chegar (todo device de som manda isso assim que existe, ja que
; "openmsx_update enable setting" - assinado no boot - cobre TODOS os
; settings, nao so os que a gente conhece de antemao) vira uma entrada no
; Map abaixo, keyed pelo nome real do dispositivo. OMSX_DeviceListDirty
; avisa a GUI que a lista mudou (dispositivo novo apareceu) pra ela
; reconstruir o ListView so quando precisa, nao a cada tick.
Global NewMap OMSX_DeviceVolume.i()
Global NewMap OMSX_DeviceBalance.i()
Global OMSX_DeviceListDirty.b = #False

; Conectores MIDI (aba "Volume") - MESMO problema dos dispositivos de som:
; nao sao nomes fixos tipo "midi-in"/"midi-out" (confirmado ao vivo: nesta
; maquina sao "Generic MSX-Audio-MIDI-in"/"...-MIDI-out", nomes do hardware
; especifico). Descobertos com UMA consulta "plug" (lista todos os
; conectores) ao abrir a aba - ver OMSX_QueryMidiConnectors()/
; OMSX_FindConnectorByName() mais abaixo.
Global OMSX_MidiInConnector.s = ""
Global OMSX_MidiOutConnector.s = ""
Global OMSX_AwaitingPlugList.b = #False

; "Adicionar dispositivo" manual (aba "Volume") - consultar "set
; NOME_volume" (SEM valor - so LEITURA, nao muda nada) nao dispara
; "<update>" nenhum (confirmado ao vivo: so mudancas de verdade notificam,
; nao consultas), entao a descoberta passiva sozinha tem um problema de
; "ovo e galinha" no boot (nada mudou ainda, lista fica vazia pra sempre).
; Isto complementa com consulta ativa sob demanda pra UM nome que o usuario
; digitou (descoberto por ele via o proprio menu do openMSX, "Mostrar
; ajustes dos chips de som", ja que os nomes variam por cartucho - ver
; comentario de OMSX_DeviceVolume() acima). Funcao em si fica perto de
; OMSX_QueryFps()/OMSX_QueryMidiConnectors() mais abaixo (precisa de
; OMSX_IsRunning() ja definida).
Global OMSX_AwaitingDeviceQuery.s = ""

; Caminho de um .dsk pendente de carregar assim que o pipe conectar - ver
; OMSX_LoadDisk() e o final de OMSX_PipeConnectThread() (mesma logica ja
; usada pra sequencia de boot: nao da pra mandar comando nenhum antes do
; pipe conectar de verdade, entao um pedido feito nesse meio-tempo fica
; guardado aqui em vez de se perder).
Global OMSX_PendingDiskPath.s = ""

; Maquina/extensao com que a instancia ATUAL foi de fato lancada (preenchido
; em OMSX_Start() so quando ele realmente sobe um processo novo, nao quando
; so reaproveita um ja rodando) - "-machine"/"-ext" so valem no lancamento,
; entao isso serve pra comparar com BadigCfg\EmMachine/EmExtension e avisar
; o usuario se ele mudou a configuracao com o openMSX ja aberto (ver
; OpenMSXConsoleGui.pbi).
Global OMSX_LaunchedMachine.s = ""
Global OMSX_LaunchedExtension.s = ""

; Usada por OMSX_ExtractAnySettingUpdate() - diferente de
; OMSX_ExtractSettingUpdate() (que so serve quando ja sabemos o nome exato
; do setting de antemao), extrai nome E valor de QUALQUER "<update
; type="setting">", pra descobrir dispositivos de som na hora (ver
; OMSX_DeviceVolume()/OMSX_DeviceBalance() acima).
Structure OMSX_SettingUpdate
  Name.s
  Value.s
EndStructure

Declare OMSX_SendCommand(Cmd.s)
Declare OMSX_ShowWindow()

; Zera todo o estado ligado a UMA instancia do openMSX (handles, flags de
; conexao/power/pause, disco pendente) - usado tanto quando
; OMSX_IsRunning() detecta que o processo morreu por fora quanto por
; OMSX_Stop() (encerramento de proposito). NAO zera OMSX_Prog - quem chama
; decide isso (precisa do valor antigo pra CloseProgram() antes de zerar).
Procedure OMSX_ResetState()
  If OMSX_PipeHandle
    CloseHandle_(OMSX_PipeHandle)
    OMSX_PipeHandle = 0
  EndIf
  OMSX_PipeConnected = #False
  OMSX_PowerKnown = #False
  OMSX_PausedKnown = #False
  OMSX_PendingDiskPath = ""
EndProcedure

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
    OMSX_ResetState()
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

    ; Disco pedido enquanto o openMSX ainda estava subindo (ver
    ; OMSX_LoadDisk()) - manda agora que a conexao de verdade acabou de
    ; completar, mesmo espirito da sequencia de boot acima.
    If OMSX_PendingDiskPath <> ""
      OMSX_SendCommand("diska insert " + Chr(34) + OMSX_PendingDiskPath + Chr(34))
      OMSX_SendCommand("reset")
      OMSX_PendingDiskPath = ""
    EndIf
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

  ; "-machine"/"-ext" so valem no lancamento - guarda o que foi de fato usado
  ; pra dar pra comparar depois com BadigCfg\EmMachine/EmExtension (ver
  ; comentario dos globais, topo do arquivo).
  OMSX_LaunchedMachine = BadigCfg\EmMachine
  OMSX_LaunchedExtension = BadigCfg\EmExtension

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

; Carrega DiskPath (um .dsk ja pronto, ver RunOnOpenMSX() em BadigEditor.pb)
; na instancia ATUAL do openMSX em vez de abrir uma nova - sobe o emulador se
; precisar (OMSX_Start(), reaproveita se ja estiver rodando) e troca o disco
; da unidade A com "diska insert" + "reset" (equivalente a trocar o
; disquete e reiniciar um MSX de verdade, sem fechar a janela do emulador).
; Se o pipe ainda nao tiver conectado (openMSX acabou de subir agora
; mesmo), guarda DiskPath em OMSX_PendingDiskPath pra
; OMSX_PipeConnectThread() mandar os mesmos dois comandos assim que a
; conexao completar, em vez de perder o pedido.
Procedure.b OMSX_LoadDisk(DiskPath.s)
  If OMSX_IsRunning() And OMSX_PipeConnected
    OMSX_SendCommand("diska insert " + Chr(34) + DiskPath + Chr(34))
    OMSX_SendCommand("reset")
    ProcedureReturn #True
  EndIf

  If Not OMSX_Start()
    ProcedureReturn #False
  EndIf
  OMSX_PendingDiskPath = DiskPath
  ProcedureReturn #True
EndProcedure

; Encerra a instancia atual DE PROPOSITO (diferente de "set power off", que
; so desliga a maquina virtual mas deixa o processo/janela do openMSX
; abertos) - usado pelo botao "Reiniciar openMSX" (OpenMSXConsoleGui.pbi)
; quando o usuario mudou maquina/extensao em Configurar -> openMSX e quer
; aplicar de verdade (nao da pra trocar isso a quente, sao flags so de
; lancamento). Pede uma saida limpa primeiro (comando Tcl nativo "exit"),
; da um tempo curto pra processar e so entao fecha na marra via
; CloseProgram() - mesmo padrao que o resto do modulo ja usa pra tratar o
; processo como podendo morrer a qualquer momento.
Procedure OMSX_Stop()
  If Not OMSX_IsRunning()
    ProcedureReturn
  EndIf
  OMSX_SendCommand("exit")
  Delay(300)
  CloseProgram(OMSX_Prog)
  OMSX_Prog = 0
  OMSX_ResetState()
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

; Extrai o conteudo cru de uma linha "<reply result="...">CONTEUDO</reply>"
; (ANTES de OMSX_CleanLine() mutilar as tags) - "" se a linha nao for uma
; reply. Usado so por OMSX_QueryFps()/OMSX_Poll() pra pegar a resposta de
; "openmsx_info fps" sem esperar um "<update type=setting>" (que so existe
; pra settings de verdade, nao pra consultas avulsas tipo openmsx_info).
Procedure.s OMSX_ExtractReplyContent(RawLine.s)
  Protected TagPos.i = FindString(RawLine, "<reply")
  If TagPos = 0
    ProcedureReturn ""
  EndIf
  Protected GtPos.i = FindString(RawLine, ">", TagPos)
  If GtPos = 0
    ProcedureReturn ""
  EndIf
  Protected CloseStart.i = FindString(RawLine, "</reply>", GtPos)
  If CloseStart = 0
    ProcedureReturn ""
  EndIf
  ProcedureReturn Mid(RawLine, GtPos + 1, CloseStart - GtPos - 1)
EndProcedure

; Extrai nome+valor de QUALQUER "<update type="setting" ...name="X">valor</update>"
; (ANTES de OMSX_CleanLine() mutilar as tags, mesmo motivo de sempre) - #False
; se a linha nao for uma atualizacao de setting. Usado so pra descoberta
; dinamica de dispositivo de som (OMSX_Poll() confere se Name termina em
; "_volume"/"_balance") - diferente de OMSX_ExtractSettingUpdate(), que
; exige saber o nome exato de antemao.
Procedure.b OMSX_ExtractAnySettingUpdate(RawLine.s, *Out.OMSX_SettingUpdate)
  If FindString(RawLine, "<update type=" + Chr(34) + "setting" + Chr(34)) = 0
    ProcedureReturn #False
  EndIf
  Protected Needle.s = "name=" + Chr(34)
  Protected NamePos.i = FindString(RawLine, Needle)
  If NamePos = 0
    ProcedureReturn #False
  EndIf
  Protected NameStart.i = NamePos + Len(Needle)
  Protected NameEnd.i = FindString(RawLine, Chr(34), NameStart)
  If NameEnd = 0
    ProcedureReturn #False
  EndIf
  Protected GtPos.i = FindString(RawLine, ">", NameEnd)
  If GtPos = 0
    ProcedureReturn #False
  EndIf
  Protected CloseStart.i = FindString(RawLine, "</update>", GtPos)
  If CloseStart = 0
    ProcedureReturn #False
  EndIf
  *Out\Name = Mid(RawLine, NameStart, NameEnd - NameStart)
  *Out\Value = Mid(RawLine, GtPos + 1, CloseStart - GtPos - 1)
  ProcedureReturn #True
EndProcedure

; Acha, dentro da resposta cheia do comando "plug" (sem argumentos - lista
; TODOS os conectores/pluggables atuais, uma "linha" por conector no
; formato "conector: pluggable", separadas por "&#x0a;" ja que veio dentro
; de um XML), o nome de um conector cujo PROPRIO NOME contem NeedleLower
; (case-insensitive) - usado pra achar o conector MIDI-in/MIDI-out de
; verdade, que varia por hardware (ver comentario de OMSX_MidiInConnector
; acima). "" se nao achar.
Procedure.s OMSX_FindConnectorByName(ReplyContent.s, NeedleLower.s)
  Protected Lines.s = ReplaceString(ReplyContent, "&#x0a;", Chr(10))
  Protected N.i = CountString(Lines, Chr(10)) + 1
  Protected I.i
  For I = 1 To N
    Protected OneLine.s = StringField(Lines, I, Chr(10))
    Protected ColonPos.i = FindString(OneLine, ":")
    If ColonPos > 0
      Protected ConnName.s = Trim(Left(OneLine, ColonPos - 1))
      If FindString(LCase(ConnName), NeedleLower) > 0
        ProcedureReturn ConnName
      EndIf
    EndIf
  Next
  ProcedureReturn ""
EndProcedure

; Consulta sob demanda UM nome de dispositivo digitado manualmente (botao
; "Adicionar" da aba "Volume") - ver comentario de OMSX_AwaitingDeviceQuery,
; topo do arquivo.
Procedure OMSX_QueryDevice(DevName.s)
  If OMSX_IsRunning() And OMSX_PipeConnected And Trim(DevName) <> ""
    OMSX_AwaitingDeviceQuery = DevName
    OMSX_SendCommand("set " + Chr(34) + DevName + "_volume" + Chr(34))
  EndIf
EndProcedure

; Dispara a consulta que descobre os conectores MIDI-in/MIDI-out de verdade
; desta maquina - ver OMSX_Poll() pra onde a resposta e capturada
; (OMSX_AwaitingPlugList). Chamada uma vez ao abrir a aba "Volume" (nao
; precisa repetir - conectores nao aparecem/somem sozinhos em runtime).
Procedure OMSX_QueryMidiConnectors()
  If OMSX_IsRunning() And OMSX_PipeConnected
    OMSX_AwaitingPlugList = #True
    OMSX_SendCommand("plug")
  EndIf
EndProcedure

; Consulta o FPS atual - so dispara o comando e marca "aguardando resposta",
; ver OMSX_Poll() pra onde a resposta e capturada. Chamada periodicamente
; pela GUI (nao daqui), pra nao gerar trafego sem ninguem pedindo.
Procedure OMSX_QueryFps()
  If OMSX_IsRunning() And OMSX_PipeConnected
    OMSX_AwaitingFps = #True
    OMSX_SendCommand("openmsx_info fps")
  EndIf
EndProcedure

; Simula a tecla STOP fisica do teclado MSX (Ctrl+Stop interrompe um
; programa BASIC em execucao - "break") - linha 7, bit 0x08 da matriz de
; teclado padrao do MSX, confirmado contra um script real de binding do
; openMSX (share/scripts, "bind PAGEUP keymatrixdown 7 0x08" /
; "keymatrixup 7 0x08"). Pulso curto (down seguido de up), como um toque de
; tecla de verdade - mesmo padrao de delay curto e bloqueante que
; OMSX_Stop() ja usa pra dar tempo do comando anterior ser processado.
Procedure OMSX_PressStop()
  OMSX_SendCommand("keymatrixdown 7 0x08")
  Delay(50)
  OMSX_SendCommand("keymatrixup 7 0x08")
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
    SettingVal = OMSX_ExtractSettingUpdate(Line, "speed")
    If SettingVal <> ""
      OMSX_Speed = Val(SettingVal)
      OMSX_SpeedKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "firmwareswitch")
    If SettingVal <> ""
      OMSX_FirmwareOn = Bool(SettingVal = "true")
      OMSX_FirmwareKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "renshaturbo")
    If SettingVal <> ""
      OMSX_RenshaOn = Bool(Val(SettingVal) > 0)
      OMSX_RenshaKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "caps")
    If SettingVal <> ""
      OMSX_LedCapsOn = Bool(SettingVal = "true")
      OMSX_LedCapsKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "kana")
    If SettingVal <> ""
      OMSX_LedKanaOn = Bool(SettingVal = "true")
      OMSX_LedKanaKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "turbo")
    If SettingVal <> ""
      OMSX_LedTurboOn = Bool(SettingVal = "true")
      OMSX_LedTurboKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "fdd")
    If SettingVal <> ""
      OMSX_LedFddOn = Bool(SettingVal = "true")
      OMSX_LedFddKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "vsync")
    If SettingVal <> ""
      OMSX_VSyncOn = Bool(SettingVal = "true")
      OMSX_VSyncKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "scale_algorithm")
    If SettingVal <> ""
      OMSX_ScaleAlgorithm = SettingVal
      OMSX_ScaleAlgorithmKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "deinterlace")
    If SettingVal <> ""
      OMSX_DeinterlaceOn = Bool(SettingVal = "true")
      OMSX_DeinterlaceKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "limitsprites")
    If SettingVal <> ""
      OMSX_LimitSpritesOn = Bool(SettingVal = "true")
      OMSX_LimitSpritesKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "fullscreen")
    If SettingVal <> ""
      OMSX_FullscreenOn = Bool(SettingVal = "true")
      OMSX_FullscreenKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "disablesprites")
    If SettingVal <> ""
      OMSX_DisableSpritesOn = Bool(SettingVal = "true")
      OMSX_DisableSpritesKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "scanline")
    If SettingVal <> ""
      OMSX_Scanline = Val(SettingVal)
      OMSX_ScanlineKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "blur")
    If SettingVal <> ""
      OMSX_Blur = Val(SettingVal)
      OMSX_BlurKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "glow")
    If SettingVal <> ""
      OMSX_Glow = Val(SettingVal)
      OMSX_GlowKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "gamma")
    If SettingVal <> ""
      OMSX_Gamma = SettingVal
      OMSX_GammaKnown = #True
    EndIf
    SettingVal = OMSX_ExtractSettingUpdate(Line, "noise")
    If SettingVal <> ""
      OMSX_Noise = Val(SettingVal)
      OMSX_NoiseKnown = #True
    EndIf

    ; Resposta de "openmsx_info fps" (nao e um "<update type=setting>", ver
    ; comentario de OMSX_AwaitingFps/OMSX_QueryFps() no topo do arquivo) -
    ; checado ANTES de OMSX_CleanLine() mutilar a linha, mesmo motivo de
    ; tudo acima.
    If OMSX_AwaitingFps
      Protected ReplyContent.s = OMSX_ExtractReplyContent(Line)
      If ReplyContent <> ""
        OMSX_Fps = ReplyContent
        OMSX_FpsKnown = #True
        OMSX_AwaitingFps = #False
      EndIf
    EndIf

    ; Resposta de "set NOME_volume" (consulta manual, ver OMSX_QueryDevice())
    ; - se o nome existir de verdade, isto adiciona o dispositivo ao Map
    ; mesmo sem nenhuma mudanca real ter ocorrido (resolve o "ovo e
    ; galinha" da descoberta so-passiva). Se o nome NAO existir, a resposta
    ; vem como erro (Val() disso vira 0) mas o [ERRO] correspondente ja
    ; aparece no log de qualquer jeito via OMSX_CleanLine() normal - o
    ; usuario ve que falhou.
    If OMSX_AwaitingDeviceQuery <> ""
      Protected DevReply.s = OMSX_ExtractReplyContent(Line)
      If DevReply <> ""
        If AddMapElement(OMSX_DeviceVolume(), OMSX_AwaitingDeviceQuery)
          OMSX_DeviceListDirty = #True
        EndIf
        OMSX_DeviceVolume(OMSX_AwaitingDeviceQuery) = Val(DevReply)
        OMSX_AwaitingDeviceQuery = ""
      EndIf
    EndIf

    ; Resposta de "plug" (lista de conectores) - ver OMSX_QueryMidiConnectors().
    If OMSX_AwaitingPlugList
      Protected PlugReply.s = OMSX_ExtractReplyContent(Line)
      If PlugReply <> ""
        OMSX_MidiInConnector = OMSX_FindConnectorByName(PlugReply, "midi-in")
        OMSX_MidiOutConnector = OMSX_FindConnectorByName(PlugReply, "midi-out")
        OMSX_AwaitingPlugList = #False
      EndIf
    EndIf

    ; Descoberta dinamica de dispositivo de som (aba "Volume") - qualquer
    ; setting terminando em "_volume"/"_balance" vira uma entrada no Map,
    ; keyed pelo nome real do dispositivo (ver comentario de
    ; OMSX_DeviceVolume() no topo do arquivo). AddMapElement() devolve
    ; #True so quando a chave e NOVA - e o sinal certo pra avisar a GUI que
    ; a lista mudou, sem precisar comparar antes/depois.
    Protected Upd.OMSX_SettingUpdate
    If OMSX_ExtractAnySettingUpdate(Line, @Upd)
      If Right(Upd\Name, 7) = "_volume"
        Protected DevName.s = Left(Upd\Name, Len(Upd\Name) - 7)
        If AddMapElement(OMSX_DeviceVolume(), DevName)
          OMSX_DeviceListDirty = #True
        EndIf
        OMSX_DeviceVolume(DevName) = Val(Upd\Value)
      ElseIf Right(Upd\Name, 8) = "_balance"
        Protected DevName2.s = Left(Upd\Name, Len(Upd\Name) - 8)
        AddMapElement(OMSX_DeviceBalance(), DevName2)
        OMSX_DeviceBalance(DevName2) = Val(Upd\Value)
      EndIf
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
