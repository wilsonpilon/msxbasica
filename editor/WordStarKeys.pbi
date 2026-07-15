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
;  undo/redo): busca (^QF/^L), reformatar paragrafo (^B), salvar bloco em
;  arquivo (^KW) e o menu de opcoes (^O) ficam para uma proxima etapa.
; ------------------------------------------------------------
;

; Indicador do Scintilla usado só para destacar visualmente o bloco marcado
; (^KB/^KK) - independente da selecao "de verdade", porque no WordStar/JOE a
; marcacao e um par de posicoes fixas no texto, nao uma selecao normal que
; desaparece quando o cursor se move.
#WS_MarkIndicator = 10

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
    Case Asc("R") : ScintillaSendMessage(Sci, #SCI_PAGEUP)
    Case Asc("C") : ScintillaSendMessage(Sci, #SCI_PAGEDOWN)
    Case Asc("G") : ScintillaSendMessage(Sci, #SCI_CLEAR)          ; apaga caractere a frente
    Case Asc("V")
      ScintillaSendMessage(Sci, #SCI_EDITTOGGLEOVERTYPE)
      UpdateStatusBar()
    Case Asc("T") : ScintillaSendMessage(Sci, #SCI_DELWORDRIGHT)
    Case Asc("Y") : ScintillaSendMessage(Sci, #SCI_LINEDELETE)
    Case Asc("U") : ScintillaSendMessage(Sci, #SCI_UNDO)
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
    EndSelect

  ElseIf Prefix = Asc("Q")
    Select VKCode
      Case Asc("S") : ScintillaSendMessage(Sci, #SCI_HOME)
      Case Asc("D") : ScintillaSendMessage(Sci, #SCI_LINEEND)
      Case Asc("R") : ScintillaSendMessage(Sci, #SCI_DOCUMENTSTART)
      Case Asc("C") : ScintillaSendMessage(Sci, #SCI_DOCUMENTEND)
      Case Asc("Y") : ScintillaSendMessage(Sci, #SCI_DELLINERIGHT)
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
          WS_TryChord(WS_ChordPrefix, wParam)
          WS_ChordPrefix = 0
          WS_SwallowChar = #True
          Handled = #True
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
          ElseIf WS_TryDirect(wParam, ShiftDown)
            WS_SwallowChar = #True
            Handled = #True
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

Procedure.s WS_HelpRow(Key1.s, Desc1.s, Key2.s = "", Desc2.s = "")
  Protected Line.s = "  " + LSet(Key1, 13) + LSet(Desc1, 32)
  If Key2 <> ""
    Line + LSet(Key2, 13) + Desc2
  EndIf
  ProcedureReturn Line
EndProcedure

Procedure.s WS_BuildHelpText()
  Protected T.s

  T + "  Ajuda - teclado estilo WordStar/JOE" + Chr(10)
  T + "  (baseado no JOE - joe-editor.sourceforge.io) - qualquer tecla fecha esta tela" + Chr(10)
  T + Chr(10)
  T + "  CURSOR" + Chr(10)
  T + WS_HelpRow("Ctrl+S", "caractere a esquerda", "Ctrl+Q S", "inicio da linha") + Chr(10)
  T + WS_HelpRow("Ctrl+D", "caractere a direita", "Ctrl+Q D", "fim da linha") + Chr(10)
  T + WS_HelpRow("Ctrl+E", "linha acima", "Ctrl+Q R", "inicio do arquivo") + Chr(10)
  T + WS_HelpRow("Ctrl+X", "linha abaixo", "Ctrl+Q C", "fim do arquivo") + Chr(10)
  T + WS_HelpRow("Ctrl+A", "palavra anterior", "Ctrl+R", "tela anterior") + Chr(10)
  T + WS_HelpRow("Ctrl+F", "proxima palavra", "Ctrl+C", "proxima tela") + Chr(10)
  T + Chr(10)
  T + "  APAGAR" + Chr(10)
  T + WS_HelpRow("Ctrl+G", "caractere sob o cursor", "Ctrl+T", "palavra a direita") + Chr(10)
  T + WS_HelpRow("Ctrl+H", "caractere anterior", "Ctrl+Y", "linha inteira") + Chr(10)
  T + WS_HelpRow("Ctrl+Q Y", "ate o fim da linha") + Chr(10)
  T + Chr(10)
  T + "  BLOCO MARCADO" + Chr(10)
  T + WS_HelpRow("Ctrl+K B", "marca o inicio", "Ctrl+K V", "move o bloco") + Chr(10)
  T + WS_HelpRow("Ctrl+K K", "marca o fim", "Ctrl+K Y", "apaga o bloco") + Chr(10)
  T + WS_HelpRow("Ctrl+K C", "copia o bloco") + Chr(10)
  T + Chr(10)
  T + "  ARQUIVO" + Chr(10)
  T + WS_HelpRow("Ctrl+K D", "salvar", "Ctrl+K X", "salvar e fechar") + Chr(10)
  T + WS_HelpRow("Ctrl+K E", "abrir", "Ctrl+K Q", "fechar") + Chr(10)
  T + Chr(10)
  T + "  OUTROS" + Chr(10)
  T + WS_HelpRow("Ctrl+U", "desfazer", "Ctrl+Shift+6", "refazer") + Chr(10)
  T + WS_HelpRow("Ctrl+V", "inserir/sobrescrever", "Ctrl+K H", "esta ajuda") + Chr(10)

  ProcedureReturn T
EndProcedure

Procedure WS_ShowHelp()
  Protected Sci = ActiveSciGadget()
  If Not Sci Or WS_HelpVisible
    ProcedureReturn
  EndIf
  WS_HelpVisible = #True
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

; Qualquer tecla (ou clique) fecha a ajuda - nao precisa reproduzir o
; despacho WordStar inteiro aqui, so devolver o foco ao editor.
Procedure WS_HelpWndProc(hWnd, uMsg, wParam, lParam)
  Select uMsg
    Case #WM_KEYDOWN, #WM_SYSKEYDOWN, #WM_CHAR, #WM_LBUTTONDOWN
      WS_HideHelp()
      ProcedureReturn 0
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

  Protected *Buf = UTF8(WS_BuildHelpText())
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
