;
; ------------------------------------------------------------
;  Helpers compartilhados por MsxBas2RomSupport.pbi e N80Support.pbi: baixar
;  um release do GitHub (API + asset zip), descompactar e capturar a saida de
;  "-h"/"--help" de um executavel baixado. Reaproveita UseNetworkTLS() (ja
;  chamado globalmente em BadigSettings.pbi) e BadigCfg_ExtractZip() (mesmo
;  arquivo) - nao reimplementa nada disso.
; ------------------------------------------------------------
;

; Bombeia a fila de eventos do Windows sem processa-los (mesmo truque de
; FontDownloader_FlushEvents()) - as chamadas de rede/RunProgram abaixo sao
; bloqueantes, entao isso e o que faz um SetGadgetText() de status aparecer
; na tela antes da proxima chamada bloqueante travar a UI de novo.
Procedure ExtTool_FlushEvents()
  Repeat
  Until WindowEvent() = 0
EndProcedure

; Atualiza StatusGadget (se houver - 0 e permitido pra chamadas sem UI) e
; bombeia a fila logo em seguida, pra o texto aparecer antes do proximo
; passo bloqueante do download.
Procedure ExtTool_SetStatus(StatusGadget, Text.s)
  If StatusGadget
    SetGadgetText(StatusGadget, Text)
    ExtTool_FlushEvents()
  EndIf
EndProcedure

; GET simples (JSON da API do GitHub ou .md cru de raw.githubusercontent.com)
; devolvido como string UTF8. "" em qualquer falha de rede.
Procedure.s ExtTool_HttpGetText(Url.s)
  Protected *Buf = ReceiveHTTPMemory(Url)
  If Not *Buf
    ProcedureReturn ""
  EndIf
  Protected Result.s = PeekS(*Buf, MemorySize(*Buf), #PB_UTF8 | #PB_ByteLength)
  FreeMemory(*Buf)
  ProcedureReturn Result
EndProcedure

; CreateDirectory() nativo do PureBasic NAO cria pastas intermediarias que
; ainda nao existem (confirmado: falha silenciosa contra um caminho de 2+
; niveis novo) - BadigCfg_ExtractZip() (BadigSettings.pbi) tambem so faz
; CreateDirectory() direto e nunca precisou disso porque seus alvos ja
; tinham a pasta-pai existente. "tools\msxbas2rom\"/"tools\n80\" sao
; caminhos de 2 niveis inteiramente novos na primeira execucao, entao
; precisam de verdade de criacao recursiva - garante isso aqui (sem mexer
; em BadigCfg_ExtractZip, que continua funcionando igual pros chamadores
; que ja tinham a pasta-pai pronta).
Procedure ExtTool_CreateDirectoryRecursive(Dir.s)
  If Right(Dir, 1) = "\" Or Right(Dir, 1) = "/"
    Dir = Left(Dir, Len(Dir) - 1)
  EndIf
  If Dir = "" Or FileSize(Dir) = -2
    ProcedureReturn ; raiz ou ja existe
  EndIf
  Protected Parent.s = GetPathPart(Dir)
  If Parent <> "" And Parent <> Dir
    ExtTool_CreateDirectoryRecursive(Parent)
  EndIf
  CreateDirectory(Dir)
EndProcedure

; Baixa Url (asset .zip de uma release) pra um arquivo temporario e
; descompacta em TargetDir via BadigCfg_ExtractZip() (BadigSettings.pbi) -
; mesma que ja lida corretamente com zip sem pasta-wrapper (caso do
; msxbas2rom/N80: exe direto na raiz do zip). Apaga o zip temporario ao
; final, sucesso ou falha.
Procedure.b ExtTool_DownloadAndExtractZip(Url.s, TargetDir.s)
  ExtTool_CreateDirectoryRecursive(TargetDir)
  Protected TempZip.s = GetTemporaryDirectory() + "ExtTool_" + Str(Random(999999999)) + ".zip"
  Protected Ok.b = ReceiveHTTPFile(Url, TempZip)
  If Ok
    Ok = BadigCfg_ExtractZip(TempZip, TargetDir)
  EndIf
  If FileSize(TempZip) >= 0
    DeleteFile(TempZip)
  EndIf
  ProcedureReturn Ok
EndProcedure

; Roda ExePath com Params e devolve stdout+stderr combinados como texto -
; usado pra capturar "-h"/"--help" de um binario recem-baixado e transformar
; em topico de Ajuda. Mesmo padrao de RunProgram(...#PB_Program_Open|Read|
; Error) de OpenMSXBridge.pbi: ReadProgramString() (stdout) precisa checar
; AvailableProgramOutput() antes (senao bloqueia), ReadProgramError() (stderr)
; ja e nao-bloqueante por conta propria (devolve "" se nao ha nada), mesma
; observacao documentada la.
Procedure.s ExtTool_RunCaptureOutput(ExePath.s, Params.s)
  Protected Prog = RunProgram(ExePath, Params, GetPathPart(ExePath),
                               #PB_Program_Open | #PB_Program_Read | #PB_Program_Error | #PB_Program_Hide)
  If Not Prog
    ProcedureReturn ""
  EndIf

  Protected Output.s = "", Line.s
  While ProgramRunning(Prog)
    If AvailableProgramOutput(Prog)
      Output + ReadProgramString(Prog) + #CRLF$
    EndIf
    Line = ReadProgramError(Prog)
    If Line <> ""
      Output + Line + #CRLF$
    EndIf
  Wend
  While AvailableProgramOutput(Prog)
    Output + ReadProgramString(Prog) + #CRLF$
  Wend
  Repeat
    Line = ReadProgramError(Prog)
    If Line = "" : Break : EndIf
    Output + Line + #CRLF$
  ForEver

  CloseProgram(Prog)
  ProcedureReturn Output
EndProcedure
