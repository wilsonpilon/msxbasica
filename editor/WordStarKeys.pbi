;
; ------------------------------------------------------------
;  Teclas de edicao estilo WordStar/JOE (jstar)
;  Editor baseado no JOE (https://joe-editor.sourceforge.io/), que reproduz o
;  teclado classico do WordStar. Referencia usada: rc/jstarrc.in do
;  repositorio oficial (github.com/joe-editor/joe) - "Basic Help Screen".
;
;  So e possivel reproduzir combinacoes de duas teclas (ex.: Ctrl+K depois B)
;  interceptando o teclado antes do Scintilla - a API dele (SCI_ASSIGNCMDKEY)
;  so cobre uma tecla de cada vez. Por isso cada ScintillaGadget e "subclassed"
;  (WS_AttachSubclass, via SetWindowLongPtr_/CallWindowProc_ - mesmo estilo
;  WinAPI cru ja usado em EditorSettings.pbi para enumerar fontes) para ler
;  WM_KEYDOWN/WM_CHAR diretamente e decidir o que fazer antes do texto chegar
;  ao controle.
;
;  Escopo atual (conjunto "basico" do JOE - cursor, delete, bloco, arquivo,
;  undo/redo, busca, reformatar paragrafo): o menu de opcoes (^O) fica para
;  uma proxima etapa (no JOE real e um menu cheio de configuracoes, muitas
;  sem sentido neste editor - precisa de escopo proprio, nao so "portar").
; ------------------------------------------------------------
;

; Indicador do Scintilla usado só para destacar visualmente o bloco marcado
; (^KB/^KK) - independente da selecao "de verdade", porque no WordStar/JOE a
; marcacao e um par de posicoes fixas no texto, nao uma selecao normal que
; desaparece quando o cursor se move.
#WS_MarkIndicator = 10

; Largura usada por ^B (reformatar paragrafo) para quebrar linhas. JOE le
; isso de uma configuracao ("rmargin"); aqui e fixo por enquanto, ja que o
; editor ainda nao tem um campo de configuracao equivalente.
#WS_FormatMargin = 72

; Ultimo texto buscado (^QF), reaproveitado por ^L (buscar proximo).
Global WS_LastSearchText.s = ""

; Usado por WS_TryChord() (^KH), definido so mais abaixo (perto de
; WS_CreateHelpGadget/#HelpGadget).
Declare WS_ShowHelp()

; WS_ChordPrefix/WS_SwallowChar (usados abaixo) sao globais definidas em
; BadigEditor.pb (UpdateStatusBar() la precisa deles e vem bem antes deste
; include). #Event_WS_CloseTab tambem: adia o fechamento da aba ativa (^KX/
; ^KQ) para depois do loop principal, porque chamar FreeGadget (dentro de
; CloseTab) na propria janela cujo WndProc esta em execucao agora (nossa
; subclass) e perigoso.

;- ------------------------------------------------------------
;- Indicador visual do bloco marcado
;- ------------------------------------------------------------

Procedure WS_SetupIndicator(Sci)
  ScintillaSendMessage(Sci, #SCI_INDICSETSTYLE, #WS_MarkIndicator, #INDIC_STRAIGHTBOX)
  ScintillaSendMessage(Sci, #SCI_INDICSETFORE, #WS_MarkIndicator, Color_Accent)
  ScintillaSendMessage(Sci, #SCI_INDICSETALPHA, #WS_MarkIndicator, 80)
  ScintillaSendMessage(Sci, #SCI_INDICSETOUTLINEALPHA, #WS_MarkIndicator, 160)
EndProcedure

; Redesenha (ou limpa, se nao houver marca completa) o destaque do bloco
; marcado na aba ativa.
Procedure WS_ApplyMarkIndicator()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition)
    ProcedureReturn
  EndIf

  Protected Sci = Docs()\SciGadget
  Protected TextLen = ScintillaSendMessage(Sci, #SCI_GETTEXTLENGTH)

  ScintillaSendMessage(Sci, #SCI_SETINDICATORCURRENT, #WS_MarkIndicator)
  ScintillaSendMessage(Sci, #SCI_INDICATORCLEARRANGE, 0, TextLen)

  If Docs()\MarkBegin >= 0 And Docs()\MarkEnd >= 0
    Protected Lo = Docs()\MarkBegin, Hi = Docs()\MarkEnd
    If Lo > Hi : Swap Lo, Hi : EndIf
    If Hi > Lo
      ScintillaSendMessage(Sci, #SCI_INDICATORFILLRANGE, Lo, Hi - Lo)
    EndIf
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Bloco marcado: ^KB / ^KK / ^KC / ^KV / ^KY
;- (desmarcar nao tem tecla dedicada - marcar de novo no mesmo lugar com ^KB
;- ^KK produz uma marca de tamanho zero, que nao fica destacada)
;- ------------------------------------------------------------

Procedure WS_MarkBegin()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  Docs()\MarkBegin = ScintillaSendMessage(Docs()\SciGadget, #SCI_GETCURRENTPOS)
  WS_ApplyMarkIndicator()
EndProcedure

Procedure WS_MarkEnd()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  Docs()\MarkEnd = ScintillaSendMessage(Docs()\SciGadget, #SCI_GETCURRENTPOS)
  WS_ApplyMarkIndicator()
EndProcedure

; Le o texto entre Lo/Hi (posicoes em bytes) sem depender da selecao atual do
; usuario alem do necessario para a chamada SCI_GETSELTEXT em si.
Procedure.s WS_ReadRangeText(Sci, Lo, Hi)
  Protected ByteLen = Hi - Lo
  Protected *Buffer, Result.s
  If ByteLen <= 0
    ProcedureReturn ""
  EndIf
  ScintillaSendMessage(Sci, #SCI_SETSEL, Lo, Hi)
  *Buffer = AllocateMemory(ByteLen + 1)
  If *Buffer
    ScintillaSendMessage(Sci, #SCI_GETSELTEXT, 0, *Buffer)
    Result = PeekS(*Buffer, -1, #PB_UTF8)
    FreeMemory(*Buffer)
  EndIf
  ProcedureReturn Result
EndProcedure

; No WordStar/JOE, ^KC duplica o bloco marcado na posicao atual do cursor (a
; marca continua no bloco original, entao ^KC pode ser repetido para "carimbar"
; varias copias em lugares diferentes) - nao e so um "copiar para a area de
; transferencia" (isso tambem e feito aqui, por conveniencia/interop, mas e
; um efeito colateral, nao o commando em si).
Procedure WS_CopyBlock()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  If Docs()\MarkBegin < 0 Or Docs()\MarkEnd < 0 : ProcedureReturn : EndIf

  Protected Sci = Docs()\SciGadget
  Protected Lo = Docs()\MarkBegin, Hi = Docs()\MarkEnd
  If Lo > Hi : Swap Lo, Hi : EndIf
  If Hi <= Lo : ProcedureReturn : EndIf

  Protected TargetPos = ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS)
  Protected BlockText.s = WS_ReadRangeText(Sci, Lo, Hi)
  Protected BlockLen = Hi - Lo

  SetClipboardText(BlockText)

  Protected *Buf = UTF8(BlockText)
  ScintillaSendMessage(Sci, #SCI_INSERTTEXT, TargetPos, *Buf)
  FreeMemory(*Buf)

  ; a insercao pode ter deslocado o bloco original (se TargetPos veio antes dele)
  If Lo >= TargetPos : Lo + BlockLen : EndIf
  If Hi >= TargetPos : Hi + BlockLen : EndIf
  Docs()\MarkBegin = Lo
  Docs()\MarkEnd   = Hi

  ScintillaSendMessage(Sci, #SCI_SETSEL, TargetPos + BlockLen, TargetPos + BlockLen)
  WS_ApplyMarkIndicator()
EndProcedure

Procedure WS_DeleteBlock()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  If Docs()\MarkBegin < 0 Or Docs()\MarkEnd < 0 : ProcedureReturn : EndIf

  Protected Sci = Docs()\SciGadget
  Protected Lo = Docs()\MarkBegin, Hi = Docs()\MarkEnd
  If Lo > Hi : Swap Lo, Hi : EndIf
  If Hi <= Lo : ProcedureReturn : EndIf

  ScintillaSendMessage(Sci, #SCI_SETSEL, Lo, Hi)
  ScintillaSendMessage(Sci, #SCI_CLEAR)

  Docs()\MarkBegin = -1
  Docs()\MarkEnd = -1
  WS_ApplyMarkIndicator()
EndProcedure

; Move o bloco marcado para a posicao atual do cursor (que precisa estar fora
; do bloco) - remove do lugar original e reinsere onde o cursor estava,
; deixando o bloco remarcado no novo lugar (mesmo comportamento do JOE).
Procedure WS_MoveBlock()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  If Docs()\MarkBegin < 0 Or Docs()\MarkEnd < 0 : ProcedureReturn : EndIf

  Protected Sci = Docs()\SciGadget
  Protected Lo = Docs()\MarkBegin, Hi = Docs()\MarkEnd
  If Lo > Hi : Swap Lo, Hi : EndIf
  If Hi <= Lo : ProcedureReturn : EndIf

  Protected TargetPos = ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS)
  If TargetPos >= Lo And TargetPos <= Hi
    ProcedureReturn ; cursor dentro do proprio bloco - nao ha para onde mover
  EndIf

  Protected BlockText.s = WS_ReadRangeText(Sci, Lo, Hi)
  Protected BlockLen = Hi - Lo
  SetClipboardText(BlockText)

  ScintillaSendMessage(Sci, #SCI_SETSEL, Lo, Hi)
  ScintillaSendMessage(Sci, #SCI_CLEAR)

  If TargetPos > Hi
    TargetPos - BlockLen ; texto removido antes do alvo desloca a posicao
  EndIf

  Protected *Buf = UTF8(BlockText)
  ScintillaSendMessage(Sci, #SCI_INSERTTEXT, TargetPos, *Buf)
  FreeMemory(*Buf)

  Docs()\MarkBegin = TargetPos
  Docs()\MarkEnd   = TargetPos + BlockLen
  ScintillaSendMessage(Sci, #SCI_SETSEL, Docs()\MarkEnd, Docs()\MarkEnd)
  WS_ApplyMarkIndicator()
EndProcedure

; Grava o bloco marcado num arquivo a parte (^KW) - so grava, nao mexe na
; marca nem no arquivo aberto (diferente de ^KC/^KV, nao insere nada de volta
; no documento).
Procedure WS_WriteBlockToFile()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition) : ProcedureReturn : EndIf
  If Docs()\MarkBegin < 0 Or Docs()\MarkEnd < 0 : ProcedureReturn : EndIf

  Protected Sci = Docs()\SciGadget
  Protected Lo = Docs()\MarkBegin, Hi = Docs()\MarkEnd
  If Lo > Hi : Swap Lo, Hi : EndIf
  If Hi <= Lo : ProcedureReturn : EndIf

  Protected BlockText.s = WS_ReadRangeText(Sci, Lo, Hi)
  ScintillaSendMessage(Sci, #SCI_SETSEL, Lo, Hi) ; devolve a selecao visual ao bloco marcado

  Protected SavePath.s = SaveFileRequester("Salvar bloco marcado (Ctrl+K W)", "", "Todos os arquivos (*.*)|*.*", 0)
  If SavePath = ""
    ProcedureReturn
  EndIf

  Protected FileNum = CreateFile(#PB_Any, SavePath)
  If Not FileNum
    MessageRequester("Erro", "Nao foi possivel salvar o arquivo:" + Chr(10) + SavePath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf
  WriteString(FileNum, BlockText)
  CloseFile(FileNum)
EndProcedure

;- ------------------------------------------------------------
;- Busca: ^QF (buscar) / ^L (buscar proximo)
;- ------------------------------------------------------------

; Le o texto de uma linha (sem o terminador) - usado por WS_FormatParagraph
; para varrer os limites do paragrafo.
Procedure.s WS_GetLineText(Sci, LineNum)
  Protected LineStart = ScintillaSendMessage(Sci, #SCI_POSITIONFROMLINE, LineNum)
  Protected LineEnd   = ScintillaSendMessage(Sci, #SCI_GETLINEENDPOSITION, LineNum)
  ProcedureReturn WS_ReadRangeText(Sci, LineStart, LineEnd)
EndProcedure

; Terminador de linha do documento (CRLF/CR/LF) - usado ao remontar texto de
; varias linhas em WS_FormatParagraph, para nao trocar o EOL do arquivo so
; por causa do reformat.
Procedure.s WS_LineEnding(Sci)
  Select ScintillaSendMessage(Sci, #SCI_GETEOLMODE)
    Case #SC_EOL_CRLF : ProcedureReturn Chr(13) + Chr(10)
    Case #SC_EOL_CR   : ProcedureReturn Chr(13)
    Default           : ProcedureReturn Chr(10)
  EndSelect
EndProcedure

; Busca (sem diferenciar maiusculas/minusculas) a partir de FromPos, com
; wraparound para o inicio do documento se nao achar dali em diante - mesmo
; comportamento pratico do ^L do JOE quando chega ao fim do arquivo.
Procedure.b WS_SearchFrom(Sci, SearchText.s, FromPos)
  Protected TextLen = ScintillaSendMessage(Sci, #SCI_GETTEXTLENGTH)
  ScintillaSendMessage(Sci, #SCI_SETSEARCHFLAGS, 0)

  Protected *Buf = UTF8(SearchText)
  Protected ByteLen = StringByteLength(SearchText, #PB_UTF8)

  ScintillaSendMessage(Sci, #SCI_SETTARGETSTART, FromPos)
  ScintillaSendMessage(Sci, #SCI_SETTARGETEND, TextLen)
  Protected FoundPos = ScintillaSendMessage(Sci, #SCI_SEARCHINTARGET, ByteLen, *Buf)

  If FoundPos < 0
    ScintillaSendMessage(Sci, #SCI_SETTARGETSTART, 0)
    ScintillaSendMessage(Sci, #SCI_SETTARGETEND, FromPos)
    FoundPos = ScintillaSendMessage(Sci, #SCI_SEARCHINTARGET, ByteLen, *Buf)
  EndIf
  FreeMemory(*Buf)

  If FoundPos < 0
    ProcedureReturn #False
  EndIf

  Protected TargetEnd = ScintillaSendMessage(Sci, #SCI_GETTARGETEND)
  ScintillaSendMessage(Sci, #SCI_SETSEL, FoundPos, TargetEnd)
  ScintillaSendMessage(Sci, #SCI_SCROLLCARET)
  ProcedureReturn #True
EndProcedure

Procedure WS_FindFirst()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf

  Protected Query.s = InputRequester("Buscar (Ctrl+Q F)", "Texto a buscar:", WS_LastSearchText, 0, WindowID(#MainWindow))
  If Query = ""
    ProcedureReturn
  EndIf

  WS_LastSearchText = Query
  If Not WS_SearchFrom(Sci, Query, ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS))
    MessageRequester("Buscar", "Texto nao encontrado: " + Query, #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  EndIf
EndProcedure

Procedure WS_FindNext()
  Protected Sci = ActiveSciGadget()
  If Not Sci Or WS_LastSearchText = ""
    ProcedureReturn
  EndIf
  If Not WS_SearchFrom(Sci, WS_LastSearchText, ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS))
    MessageRequester("Buscar", "Texto nao encontrado: " + WS_LastSearchText, #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Substituir: ^QA (busca+substitui, tudo ou uma ocorrencia por vez)
;- ------------------------------------------------------------

; Busca a partir de FromPos ATE O FIM do documento, sem wraparound - usado por
; substituir (tudo/uma-a-uma), que precisam de uma condicao de parada garantida
; (diferente de WS_SearchFrom, que da a volta pro inicio do arquivo e serviria
; mal aqui: reencontraria as ocorrencias ja substituidas). Em caso de sucesso,
; o alvo (#SCI_GETTARGETSTART/END) fica apontando pro trecho achado.
Procedure.i WS_SearchForwardNoWrap(Sci, SearchText.s, FromPos)
  Protected TextLen = ScintillaSendMessage(Sci, #SCI_GETTEXTLENGTH)
  If FromPos > TextLen
    ProcedureReturn -1
  EndIf
  ScintillaSendMessage(Sci, #SCI_SETSEARCHFLAGS, 0)
  Protected *Buf = UTF8(SearchText)
  Protected ByteLen = StringByteLength(SearchText, #PB_UTF8)
  ScintillaSendMessage(Sci, #SCI_SETTARGETSTART, FromPos)
  ScintillaSendMessage(Sci, #SCI_SETTARGETEND, TextLen)
  Protected FoundPos = ScintillaSendMessage(Sci, #SCI_SEARCHINTARGET, ByteLen, *Buf)
  FreeMemory(*Buf)
  ProcedureReturn FoundPos
EndProcedure

; Substitui todas as ocorrencias sem perguntar. Pos avanca sempre para
; FoundPos+ReplaceByteLen (mesmo quando ReplaceText = "" e Pos fica parado em
; FoundPos) - nao trava porque o texto encontrado ja foi removido dali, entao
; o documento so encolhe a cada volta, garantindo que o laco termina.
Procedure.i WS_ReplaceAll(Sci, SearchText.s, ReplaceText.s)
  Protected Count = 0
  Protected *ReplaceBuf = UTF8(ReplaceText)
  Protected ReplaceByteLen = StringByteLength(ReplaceText, #PB_UTF8)
  Protected Pos = 0, FoundPos

  Repeat
    FoundPos = WS_SearchForwardNoWrap(Sci, SearchText, Pos)
    If FoundPos < 0 : Break : EndIf
    ScintillaSendMessage(Sci, #SCI_REPLACETARGET, ReplaceByteLen, *ReplaceBuf)
    Count + 1
    Pos = FoundPos + ReplaceByteLen
  ForEver

  FreeMemory(*ReplaceBuf)
  ProcedureReturn Count
EndProcedure

; Confirma ocorrencia por ocorrencia (Sim substitui e avanca, Nao pula para a
; proxima, Cancelar para o laco inteiro).
Procedure.i WS_ReplaceInteractive(Sci, SearchText.s, ReplaceText.s)
  Protected *ReplaceBuf = UTF8(ReplaceText)
  Protected ReplaceByteLen = StringByteLength(ReplaceText, #PB_UTF8)
  Protected SearchByteLen = StringByteLength(SearchText, #PB_UTF8)
  Protected Pos = 0, FoundPos, Count = 0, Answer

  Repeat
    FoundPos = WS_SearchForwardNoWrap(Sci, SearchText, Pos)
    If FoundPos < 0 : Break : EndIf

    Protected TargetEnd = ScintillaSendMessage(Sci, #SCI_GETTARGETEND)
    ScintillaSendMessage(Sci, #SCI_SETSEL, FoundPos, TargetEnd)
    ScintillaSendMessage(Sci, #SCI_SCROLLCARET)

    Answer = MessageRequester("Substituir (Ctrl+Q A)", "Substituir esta ocorrencia?",
                               #PB_MessageRequester_YesNoCancel | #PB_MessageRequester_Info)
    If Answer = #PB_MessageRequester_Cancel : Break : EndIf

    If Answer = #PB_MessageRequester_Yes
      ScintillaSendMessage(Sci, #SCI_SETTARGETSTART, FoundPos)
      ScintillaSendMessage(Sci, #SCI_SETTARGETEND, TargetEnd)
      ScintillaSendMessage(Sci, #SCI_REPLACETARGET, ReplaceByteLen, *ReplaceBuf)
      Count + 1
      Pos = FoundPos + ReplaceByteLen
    Else
      Pos = FoundPos + SearchByteLen
    EndIf
  ForEver

  FreeMemory(*ReplaceBuf)
  ProcedureReturn Count
EndProcedure

Procedure WS_FindReplace()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf

  Protected SearchText.s = InputRequester("Substituir (Ctrl+Q A)", "Buscar:", WS_LastSearchText, 0, WindowID(#MainWindow))
  If SearchText = ""
    ProcedureReturn
  EndIf
  WS_LastSearchText = SearchText

  ; ReplaceText = "" tanto faz dizer "substituir por nada" quanto "cancelou o
  ; requester" - nao da pra distinguir os dois casos (InputRequester devolve
  ; "" nos dois). Tratado como "substituir por nada"; o passo de confirmacao
  ; logo abaixo (Sim/Nao/Cancelar) da uma chance de desistir se nao era essa
  ; a intencao.
  Protected ReplaceText.s = InputRequester("Substituir (Ctrl+Q A)", "Substituir por:", "", 0, WindowID(#MainWindow))

  Protected Answer = MessageRequester("Substituir (Ctrl+Q A)",
    "Substituir TODAS as ocorrencias sem perguntar?" + Chr(10) + "(Nao = confirmar uma por uma)",
    #PB_MessageRequester_YesNoCancel | #PB_MessageRequester_Info)
  If Answer = #PB_MessageRequester_Cancel
    ProcedureReturn
  EndIf

  Protected Count
  If Answer = #PB_MessageRequester_Yes
    Count = WS_ReplaceAll(Sci, SearchText, ReplaceText)
  Else
    Count = WS_ReplaceInteractive(Sci, SearchText, ReplaceText)
  EndIf

  MessageRequester("Substituir", Str(Count) + " ocorrencia(s) substituida(s).", #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
EndProcedure

;- ------------------------------------------------------------
;- Ir para linha: ^QI
;- ------------------------------------------------------------

Procedure WS_GotoLine()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf

  Protected NumLines = ScintillaSendMessage(Sci, #SCI_GETLINECOUNT)
  Protected CurLine = ScintillaSendMessage(Sci, #SCI_LINEFROMPOSITION, ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS)) + 1
  Protected Answer.s = InputRequester("Ir para linha (Ctrl+Q I)", "Numero da linha (1-" + Str(NumLines) + "):", Str(CurLine), 0, WindowID(#MainWindow))
  If Answer = ""
    ProcedureReturn
  EndIf

  Protected LineNum = Val(Answer)
  If LineNum < 1 : LineNum = 1 : EndIf
  If LineNum > NumLines : LineNum = NumLines : EndIf

  ScintillaSendMessage(Sci, #SCI_GOTOLINE, LineNum - 1)
EndProcedure

;- ------------------------------------------------------------
;- Cursor para topo/fim da janela: ^QE / ^QX
;- ------------------------------------------------------------

Procedure WS_CursorToWindowTop()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf
  Protected TopVisible = ScintillaSendMessage(Sci, #SCI_GETFIRSTVISIBLELINE)
  Protected TopDocLine = ScintillaSendMessage(Sci, #SCI_DOCLINEFROMVISIBLE, TopVisible)
  ScintillaSendMessage(Sci, #SCI_GOTOLINE, TopDocLine)
EndProcedure

Procedure WS_CursorToWindowBottom()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf
  Protected TopVisible = ScintillaSendMessage(Sci, #SCI_GETFIRSTVISIBLELINE)
  Protected LinesOnScreen = ScintillaSendMessage(Sci, #SCI_LINESONSCREEN)
  Protected BottomVisible = TopVisible + LinesOnScreen - 1
  Protected LastVisible = ScintillaSendMessage(Sci, #SCI_VISIBLEFROMDOCLINE, ScintillaSendMessage(Sci, #SCI_GETLINECOUNT) - 1)
  If BottomVisible > LastVisible : BottomVisible = LastVisible : EndIf
  Protected BottomDocLine = ScintillaSendMessage(Sci, #SCI_DOCLINEFROMVISIBLE, BottomVisible)
  ScintillaSendMessage(Sci, #SCI_GOTOLINE, BottomDocLine)
EndProcedure

;- ------------------------------------------------------------
;- Reformatar paragrafo: ^B
;- ------------------------------------------------------------

; Paragrafo = sequencia continua de linhas nao-vazias em volta do cursor
; (linha em branco delimita os dois lados), igual a definicao classica do
; WordStar/JOE. Se o cursor estiver numa linha em branco, nao ha o que fazer.
Procedure WS_FormatParagraph()
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf

  Protected CurPos  = ScintillaSendMessage(Sci, #SCI_GETCURRENTPOS)
  Protected CurLine = ScintillaSendMessage(Sci, #SCI_LINEFROMPOSITION, CurPos)
  If Trim(WS_GetLineText(Sci, CurLine)) = ""
    ProcedureReturn
  EndIf

  Protected NumLines = ScintillaSendMessage(Sci, #SCI_GETLINECOUNT)
  Protected StartLine = CurLine
  While StartLine > 0 And Trim(WS_GetLineText(Sci, StartLine - 1)) <> ""
    StartLine - 1
  Wend
  Protected EndLine = CurLine
  While EndLine < NumLines - 1 And Trim(WS_GetLineText(Sci, EndLine + 1)) <> ""
    EndLine + 1
  Wend

  ; preserva a indentacao da primeira linha do paragrafo em todas as linhas
  ; remontadas (mesma convencao pratica usada por outros reformatadores).
  Protected FirstLineText.s = WS_GetLineText(Sci, StartLine)
  Protected Indent.s = "", p = 1
  While p <= Len(FirstLineText) And Mid(FirstLineText, p, 1) = " "
    Indent + " "
    p + 1
  Wend

  Protected Paragraph.s = ""
  Protected LineNum
  For LineNum = StartLine To EndLine
    Paragraph + ReplaceString(WS_GetLineText(Sci, LineNum), Chr(9), " ") + " "
  Next

  NewList OutLines.s()
  Protected CurLineOut.s = Indent
  Protected NumFields = CountString(Paragraph, " ") + 1
  Protected Field, Word.s
  For Field = 1 To NumFields
    Word = Trim(StringField(Paragraph, Field, " "))
    If Word = "" : Continue : EndIf

    If CurLineOut = Indent
      CurLineOut + Word
    ElseIf Len(CurLineOut) + 1 + Len(Word) <= #WS_FormatMargin
      CurLineOut + " " + Word
    Else
      AddElement(OutLines()) : OutLines() = CurLineOut
      CurLineOut = Indent + Word
    EndIf
  Next
  AddElement(OutLines()) : OutLines() = CurLineOut

  Protected EOL.s = WS_LineEnding(Sci)
  Protected NewText.s = ""
  ForEach OutLines()
    If NewText <> "" : NewText + EOL : EndIf
    NewText + OutLines()
  Next

  Protected RangeStart = ScintillaSendMessage(Sci, #SCI_POSITIONFROMLINE, StartLine)
  Protected RangeEnd   = ScintillaSendMessage(Sci, #SCI_GETLINEENDPOSITION, EndLine)

  ScintillaSendMessage(Sci, #SCI_SETTARGETSTART, RangeStart)
  ScintillaSendMessage(Sci, #SCI_SETTARGETEND, RangeEnd)
  Protected *Buf = UTF8(NewText)
  ScintillaSendMessage(Sci, #SCI_REPLACETARGET, StringByteLength(NewText, #PB_UTF8), *Buf)
  FreeMemory(*Buf)

  ScintillaSendMessage(Sci, #SCI_SETSEL, RangeStart, RangeStart)
EndProcedure

;- ------------------------------------------------------------
;- Despacho dos comandos (tecla direta / segunda tecla de ^K ou ^Q)
;- ------------------------------------------------------------

; Comandos de uma tecla so (Ctrl+<letra>, sem prefixo pendente). Retorna
; #False se a tecla nao faz parte do conjunto WordStar implementado (nesse
; caso o WM_KEYDOWN nao e interceptado, segue normal para o Scintilla).
Procedure.b WS_TryDirect(VKCode, ShiftDown.b)
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn #False : EndIf

  Select VKCode
    Case Asc("S") : ScintillaSendMessage(Sci, #SCI_CHARLEFT)
    Case Asc("D") : ScintillaSendMessage(Sci, #SCI_CHARRIGHT)
    Case Asc("E") : ScintillaSendMessage(Sci, #SCI_LINEUP)
    Case Asc("X") : ScintillaSendMessage(Sci, #SCI_LINEDOWN)
    Case Asc("A") : ScintillaSendMessage(Sci, #SCI_WORDLEFT)
    Case Asc("F") : ScintillaSendMessage(Sci, #SCI_WORDRIGHT)
    Case Asc("R") : ScintillaSendMessage(Sci, #SCI_PAGEUP)         ; tela anterior
    Case Asc("C") : ScintillaSendMessage(Sci, #SCI_PAGEDOWN)       ; proxima tela
    Case Asc("W") : ScintillaSendMessage(Sci, #SCI_LINESCROLL, 0, -1) ; scroll 1 linha p/ cima (nao move o cursor)
    Case Asc("Z") : ScintillaSendMessage(Sci, #SCI_LINESCROLL, 0, 1)  ; scroll 1 linha p/ baixo (nao move o cursor)
    Case Asc("N") : ScintillaSendMessage(Sci, #SCI_NEWLINE)        ; quebra a linha no cursor
    Case Asc("G") : ScintillaSendMessage(Sci, #SCI_CLEAR)          ; apaga caractere a frente
    Case Asc("V")
      ScintillaSendMessage(Sci, #SCI_EDITTOGGLEOVERTYPE)
      UpdateStatusBar()
    Case Asc("T") : ScintillaSendMessage(Sci, #SCI_DELWORDRIGHT)
    Case Asc("Y") : ScintillaSendMessage(Sci, #SCI_LINEDELETE)
    Case Asc("U") : ScintillaSendMessage(Sci, #SCI_UNDO)
    Case Asc("L") : WS_FindNext()
    Case Asc("B") : WS_FormatParagraph()
    Case Asc("6")
      If Not ShiftDown : ProcedureReturn #False : EndIf           ; Ctrl+Shift+6 = Ctrl+^ (redo)
      ScintillaSendMessage(Sci, #SCI_REDO)
    Default
      ProcedureReturn #False
  EndSelect

  ProcedureReturn #True
EndProcedure

; Segunda tecla de um comando composto (^K x ou ^Q x).
Procedure WS_TryChord(Prefix, VKCode)
  Protected Sci = ActiveSciGadget()
  If Not Sci : ProcedureReturn : EndIf

  If Prefix = Asc("K")
    Select VKCode
      Case Asc("B") : WS_MarkBegin()
      Case Asc("K") : WS_MarkEnd()
      Case Asc("C") : WS_CopyBlock()
      Case Asc("V") : WS_MoveBlock()
      Case Asc("Y") : WS_DeleteBlock()
      Case Asc("H") : WS_ShowHelp()
      Case Asc("D"), Asc("S") : SaveDocument(#False)
      Case Asc("X") : PostEvent(#Event_WS_CloseTab, #MainWindow, 0, 0, 1)  ; salvar e fechar
      Case Asc("Q") : PostEvent(#Event_WS_CloseTab, #MainWindow, 0, 0, 0)  ; fechar (avisa se ha alteracoes)
      Case Asc("E") : OpenDocumentDialog()
      Case Asc("W") : WS_WriteBlockToFile()
    EndSelect

  ElseIf Prefix = Asc("Q")
    Select VKCode
      Case Asc("S") : ScintillaSendMessage(Sci, #SCI_HOME)          ; comeco da linha
      Case Asc("D") : ScintillaSendMessage(Sci, #SCI_LINEEND)       ; fim da linha
      Case Asc("R") : ScintillaSendMessage(Sci, #SCI_DOCUMENTSTART) ; comeco do arquivo
      Case Asc("C") : ScintillaSendMessage(Sci, #SCI_DOCUMENTEND)   ; fim do arquivo
      Case Asc("E") : WS_CursorToWindowTop()                        ; topo da janela
      Case Asc("X") : WS_CursorToWindowBottom()                     ; fim da janela
      Case Asc("Y") : ScintillaSendMessage(Sci, #SCI_DELLINERIGHT)  ; apaga ate o fim da linha
      Case #VK_DELETE : ScintillaSendMessage(Sci, #SCI_DELLINELEFT) ; apaga ate o comeco da linha
      Case Asc("T") : ScintillaSendMessage(Sci, #SCI_DELWORDRIGHT)  ; apaga ate o fim da palavra
      Case Asc("F") : WS_FindFirst()
      Case Asc("A") : WS_FindReplace()
      Case Asc("I") : WS_GotoLine()
    EndSelect
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Subclass da janela do Scintilla (intercepta WM_KEYDOWN/WM_CHAR)
;- ------------------------------------------------------------

Procedure.b WS_IsModifierKey(VKCode)
  Select VKCode
    Case #VK_SHIFT, #VK_CONTROL, #VK_MENU, #VK_CAPITAL, #VK_LWIN, #VK_RWIN, #VK_NUMLOCK, #VK_SCROLL
      ProcedureReturn #True
    Case 160 To 165 ; VK_LSHIFT .. VK_RMENU
      ProcedureReturn #True
  EndSelect
  ProcedureReturn #False
EndProcedure

Procedure WS_SciWndProc(hWnd, uMsg, wParam, lParam)
  Protected OldProc = GetProp_(hWnd, "WSOldProc")
  Protected CtrlDown.b, AltDown.b, ShiftDown.b, Handled.b = #False

  Select uMsg
    Case #WM_KEYDOWN
      If WS_ChordPrefix <> 0
        If Not WS_IsModifierKey(wParam)
          ; O WS_SwallowChar precisa estar armado ANTES de chamar WS_TryChord:
          ; comandos como ^QF/^KW/^KE abrem um requester nativo (InputRequester/
          ; SaveFileRequester), que roda seu proprio loop de mensagens *dentro*
          ; desta chamada - se o WM_CHAR pendente da tecla (ja gerado pelo
          ; TranslateMessage do Windows antes deste WM_KEYDOWN chegar aqui) for
          ; bombeado por esse loop aninhado antes do swallow ser armado, ele
          ; escapa e e inserido como texto literal no documento.
          Protected ChordPrefix = WS_ChordPrefix
          WS_ChordPrefix = 0
          WS_SwallowChar = #True
          Handled = #True
          WS_TryChord(ChordPrefix, wParam)
          UpdateStatusBar()
        EndIf
      Else
        CtrlDown  = Bool(GetKeyState_(#VK_CONTROL) & $8000)
        AltDown   = Bool(GetKeyState_(#VK_MENU) & $8000)     ; exclui AltGr (Ctrl+Alt sintetico)
        ShiftDown = Bool(GetKeyState_(#VK_SHIFT) & $8000)

        If CtrlDown And Not AltDown
          If wParam = Asc("K") Or wParam = Asc("Q")
            WS_ChordPrefix = wParam
            WS_SwallowChar = #True
            Handled = #True
            UpdateStatusBar()
          Else
            ; mesmo raciocinio do bloco de cima: arma o swallow antes de
            ; executar o comando (pode abrir requester), desarma se a tecla
            ; nao fizer parte do conjunto WordStar (deixa passar pro Scintilla).
            WS_SwallowChar = #True
            If WS_TryDirect(wParam, ShiftDown)
              Handled = #True
            Else
              WS_SwallowChar = #False
            EndIf
          EndIf
        EndIf
      EndIf

    Case #WM_CHAR
      If WS_SwallowChar
        WS_SwallowChar = #False
        Handled = #True
      EndIf
  EndSelect

  If Handled
    ProcedureReturn 0
  EndIf

  ProcedureReturn CallWindowProc_(OldProc, hWnd, uMsg, wParam, lParam)
EndProcedure

Procedure WS_AttachSubclass(Sci)
  Protected hWnd = GadgetID(Sci)
  Protected OldProc = SetWindowLongPtr_(hWnd, #GWLP_WNDPROC, @WS_SciWndProc())
  SetProp_(hWnd, "WSOldProc", OldProc)
EndProcedure

;- ------------------------------------------------------------
;- Tela de ajuda (^KH) - como no JOE/WordStar, ocupa o lugar do editor e
;- fecha com qualquer tecla (ou clique).
;- ------------------------------------------------------------

Global WS_HelpVisible.b = #False

; Ajuda paginada por tema - PageUp/PageDown ou setas esquerda/direita navegam,
; ESC ou clique fecha (diferente da versao anterior, que fechava com qualquer
; tecla - precisou mudar para dar espaco as teclas de navegacao).
#WS_HelpPageCount = 6
Global WS_HelpPage.i = 0

Procedure.s WS_HelpRow(Key1.s, Desc1.s, Key2.s = "", Desc2.s = "")
  Protected Line.s = "  " + LSet(Key1, 13) + LSet(Desc1, 32)
  If Key2 <> ""
    Line + LSet(Key2, 13) + Desc2
  EndIf
  ProcedureReturn Line
EndProcedure

; Titulo curto de cada pagina - usado no cabecalho e no rodape (indicador
; "pagina X/Y - NOME").
Procedure.s WS_HelpPageTitle(PageIndex)
  Select PageIndex
    Case 0 : ProcedureReturn "CURSOR"
    Case 1 : ProcedureReturn "APAGAR"
    Case 2 : ProcedureReturn "BLOCO MARCADO"
    Case 3 : ProcedureReturn "BUSCA / TEXTO"
    Case 4 : ProcedureReturn "ARQUIVO / ABAS"
    Case 5 : ProcedureReturn "OUTROS"
  EndSelect
  ProcedureReturn ""
EndProcedure

; Linhas de comando de uma pagina especifica (sem cabecalho/rodape - isso e
; montado por WS_BuildHelpPage).
Procedure.s WS_HelpPageBody(PageIndex)
  Protected T.s
  Select PageIndex
    Case 0
      T + WS_HelpRow("Ctrl+S", "caractere a esquerda", "Ctrl+Q S", "inicio da linha") + Chr(10)
      T + WS_HelpRow("Ctrl+D", "caractere a direita", "Ctrl+Q D", "fim da linha") + Chr(10)
      T + WS_HelpRow("Ctrl+E", "linha acima", "Ctrl+Q R", "inicio do arquivo") + Chr(10)
      T + WS_HelpRow("Ctrl+X", "linha abaixo", "Ctrl+Q C", "fim do arquivo") + Chr(10)
      T + WS_HelpRow("Ctrl+A", "palavra anterior", "Ctrl+R", "tela anterior") + Chr(10)
      T + WS_HelpRow("Ctrl+F", "proxima palavra", "Ctrl+C", "proxima tela") + Chr(10)
      T + WS_HelpRow("Ctrl+W", "scroll 1 linha p/ cima", "Ctrl+Z", "scroll 1 linha p/ baixo") + Chr(10)
      T + WS_HelpRow("Ctrl+Q E", "topo da janela", "Ctrl+Q X", "fim da janela") + Chr(10)
      T + WS_HelpRow("Ctrl+Q I", "ir para linha") + Chr(10)

    Case 1
      T + WS_HelpRow("Ctrl+G", "caractere sob o cursor", "Ctrl+T", "palavra a direita") + Chr(10)
      T + WS_HelpRow("Ctrl+H", "caractere anterior", "Ctrl+Y", "linha inteira") + Chr(10)
      T + WS_HelpRow("Ctrl+Q Y", "ate o fim da linha", "Ctrl+Q Del", "ate o comeco da linha") + Chr(10)
      T + WS_HelpRow("Ctrl+Q T", "ate o fim da palavra") + Chr(10)

    Case 2
      T + WS_HelpRow("Ctrl+K B", "marca o inicio", "Ctrl+K V", "move o bloco") + Chr(10)
      T + WS_HelpRow("Ctrl+K K", "marca o fim", "Ctrl+K Y", "apaga o bloco") + Chr(10)
      T + WS_HelpRow("Ctrl+K C", "copia o bloco", "Ctrl+K W", "salva bloco em arquivo") + Chr(10)

    Case 3
      T + WS_HelpRow("Ctrl+Q F", "buscar", "Ctrl+L", "buscar proximo") + Chr(10)
      T + WS_HelpRow("Ctrl+Q A", "buscar e substituir") + Chr(10)
      T + WS_HelpRow("Ctrl+B", "reformatar paragrafo", "Ctrl+N", "quebra a linha") + Chr(10)

    Case 4
      T + WS_HelpRow("Ctrl+K D", "salvar", "Ctrl+K X", "salvar e fechar") + Chr(10)
      T + WS_HelpRow("Ctrl+K E", "abrir", "Ctrl+K Q", "fechar") + Chr(10)
      T + WS_HelpRow("Alt+N", "nova aba", "Alt+W", "fechar aba") + Chr(10)

    Case 5
      T + WS_HelpRow("Ctrl+U", "desfazer", "Ctrl+Shift+6", "refazer") + Chr(10)
      T + WS_HelpRow("Ctrl+V", "inserir/sobrescrever", "Ctrl+K H", "esta ajuda") + Chr(10)
  EndSelect
  ProcedureReturn T
EndProcedure

; Monta a pagina inteira (cabecalho + linhas do tema + rodape com indicador
; de pagina e as teclas de navegacao).
Procedure.s WS_BuildHelpPage(PageIndex)
  Protected T.s

  T + "  Ajuda - teclado estilo WordStar/JOE" + Chr(10)
  T + "  (baseado no JOE - joe-editor.sourceforge.io)" + Chr(10)
  T + Chr(10)
  T + "  " + WS_HelpPageTitle(PageIndex) + Chr(10)
  T + WS_HelpPageBody(PageIndex)
  T + Chr(10)
  T + "  Pagina " + Str(PageIndex + 1) + "/" + Str(#WS_HelpPageCount) +
      "  -  PgDn/-> proxima, PgUp/<- anterior, ESC ou clique fecha" + Chr(10)

  ProcedureReturn T
EndProcedure

; Reescreve o conteudo do gadget de ajuda com a pagina atual (WS_HelpPage) -
; chamado ao abrir a ajuda e a cada navegacao de pagina.
Procedure WS_RenderHelpPage()
  Protected *Buf = UTF8(WS_BuildHelpPage(WS_HelpPage))
  ScintillaSendMessage(#HelpGadget, #SCI_SETREADONLY, 0)
  ScintillaSendMessage(#HelpGadget, #SCI_SETTEXT, 0, *Buf)
  ScintillaSendMessage(#HelpGadget, #SCI_SETREADONLY, 1)
  FreeMemory(*Buf)
EndProcedure

Procedure WS_ShowHelp()
  Protected Sci = ActiveSciGadget()
  If Not Sci Or WS_HelpVisible
    ProcedureReturn
  EndIf
  WS_HelpVisible = #True
  WS_HelpPage = 0
  WS_RenderHelpPage()
  HideGadget(Sci, #True)
  HideGadget(#HelpGadget, #False)
  SetActiveGadget(#HelpGadget)
  UpdateStatusBar()
EndProcedure

Procedure WS_HideHelp()
  If Not WS_HelpVisible
    ProcedureReturn
  EndIf
  WS_HelpVisible = #False
  HideGadget(#HelpGadget, #True)
  Protected Sci = ActiveSciGadget()
  If Sci
    HideGadget(Sci, #False)
    SetActiveGadget(Sci)
  EndIf
  UpdateStatusBar()
EndProcedure

; Click ou ESC fecha; PageUp/PageDown e as setas esquerda/direita navegam
; entre paginas (por isso nao fecha mais com qualquer tecla, como na versao
; anterior - precisava de teclas livres para a navegacao).
Procedure WS_HelpWndProc(hWnd, uMsg, wParam, lParam)
  Select uMsg
    Case #WM_LBUTTONDOWN
      WS_HideHelp()
      ProcedureReturn 0

    Case #WM_KEYDOWN
      Select wParam
        Case #VK_ESCAPE
          WS_HideHelp()
        Case #VK_PRIOR, #VK_LEFT
          WS_HelpPage - 1
          If WS_HelpPage < 0 : WS_HelpPage = #WS_HelpPageCount - 1 : EndIf
          WS_RenderHelpPage()
        Case #VK_NEXT, #VK_RIGHT, #VK_SPACE
          WS_HelpPage + 1
          If WS_HelpPage >= #WS_HelpPageCount : WS_HelpPage = 0 : EndIf
          WS_RenderHelpPage()
      EndSelect
      ProcedureReturn 0

    Case #WM_SYSKEYDOWN, #WM_CHAR
      ProcedureReturn 0 ; engole - so ESC/clique fecham, as demais teclas nao vazam pro Scintilla
  EndSelect

  Protected OldProc = GetProp_(hWnd, "WSOldProc")
  ProcedureReturn CallWindowProc_(OldProc, hWnd, uMsg, wParam, lParam)
EndProcedure

Procedure WS_SetupHelpStyles()
  Protected *FontName = UTF8(EditorCfg\FontName)
  ScintillaSendMessage(#HelpGadget, #SCI_STYLESETFORE, #STYLE_DEFAULT, Color_Syntax_Default)
  ScintillaSendMessage(#HelpGadget, #SCI_STYLESETBACK, #STYLE_DEFAULT, Color_EditorBg)
  ScintillaSendMessage(#HelpGadget, #SCI_STYLESETFONT, #STYLE_DEFAULT, *FontName)
  FreeMemory(*FontName)
  ScintillaSendMessage(#HelpGadget, #SCI_STYLESETSIZE, #STYLE_DEFAULT, EditorCfg\FontSize)
  ScintillaSendMessage(#HelpGadget, #SCI_STYLECLEARALL)
  ScintillaSendMessage(#HelpGadget, #SCI_SETCARETFORE, Color_EditorBg) ; esconde o caret (so leitura)
EndProcedure

Procedure WS_CreateHelpGadget()
  ScintillaGadget(#HelpGadget, 0, #TabBar_Height + #Ruler_Height, WindowWidth(#MainWindow), 200, 0)
  ScintillaSendMessage(#HelpGadget, #SCI_SETCODEPAGE, #SC_CP_UTF8)
  ScintillaSendMessage(#HelpGadget, #SCI_SETMARGINWIDTHN, 0, 0)
  ScintillaSendMessage(#HelpGadget, #SCI_SETMARGINWIDTHN, 1, 0)
  ScintillaSendMessage(#HelpGadget, #SCI_SETMARGINWIDTHN, 2, 0)

  Protected *Buf = UTF8(WS_BuildHelpPage(0))
  ScintillaSendMessage(#HelpGadget, #SCI_SETTEXT, 0, *Buf)
  FreeMemory(*Buf)

  ScintillaSendMessage(#HelpGadget, #SCI_SETREADONLY, 1)
  ScintillaSendMessage(#HelpGadget, #SCI_EMPTYUNDOBUFFER)

  WS_SetupHelpStyles()

  HideGadget(#HelpGadget, #True)

  Protected hWnd = GadgetID(#HelpGadget)
  Protected OldProc = SetWindowLongPtr_(hWnd, #GWLP_WNDPROC, @WS_HelpWndProc())
  SetProp_(hWnd, "WSOldProc", OldProc)
EndProcedure
