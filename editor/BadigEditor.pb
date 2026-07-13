;
; ------------------------------------------------------------
;  Basic Dignified Editor
;  Editor de codigos para o dialeto MSX-BASIC do Basic Dignified Suite.
;  Escrito em PureBasic (Windows / Linux).
;  Realce de sintaxe via ScintillaGadget e geracao de MSX-BASIC
;  tokenizado atraves do proprio toolchain Python do Basic Dignified.
; ------------------------------------------------------------
;

EnableExplicit

XIncludeFile "MsxTokenizer.pbi"
XIncludeFile "DignifiedPreprocessor.pbi"
XIncludeFile "BadigSettings.pbi"

;- ------------------------------------------------------------
;- Constantes gerais
;- ------------------------------------------------------------

Enumeration Windows
  #MainWindow
EndEnumeration

Enumeration Gadgets
  #PanelGadget
EndEnumeration

Enumeration StatusBars
  #MainStatusBar
EndEnumeration

Enumeration Menus
  #MainMenu
EndEnumeration

Enumeration MenuItems
  #Menu_New
  #Menu_Open
  #Menu_Save
  #Menu_SaveAs
  #Menu_Tokenize
  #Menu_TokenizeNative
  #Menu_DignifiedToAscii
  #Menu_DignifiedToTokenized
  #Menu_CloseTab
  #Menu_Exit
  #Menu_ConfigureBadig
EndEnumeration

; Numeros de estilo do Scintilla usados pelo realce de sintaxe.
; 0 (STYLE_DEFAULT) fica reservado para texto/identificadores comuns.
Enumeration 1
  #Style_Comment
  #Style_String
  #Style_Statement
  #Style_Operator
  #Style_Function
  #Style_Number
  #Style_Label
  #Style_DignifiedStmt
  #Style_Remtag
EndEnumeration

#Event_Rehighlight = #PB_Event_FirstCustomValue

#App_Title      = "Basic Dignified Editor"
#File_Pattern   = "MSX-BASIC Dignified (*.dmx)|*.dmx|MSX Basic ASCII (*.amx)|*.amx|Todos os arquivos (*.*)|*.*"
#Linux_TabGuess = 30 ; altura estimada da faixa de abas no Linux/GTK, onde o atributo nao esta disponivel

;- ------------------------------------------------------------
;- Estruturas e listas globais
;- ------------------------------------------------------------

Structure Document
  Path.s          ; caminho completo no disco, vazio se ainda nao foi salvo
  Modified.b      ; 1 se ha alteracoes nao salvas
  SciGadget.i     ; ScintillaGadget associado a esta aba
EndStructure

Global NewList Docs.Document()
Global UntitledCount = 0

; Enquanto verdadeiro, mudancas de texto no Scintilla nao marcam o
; documento como modificado (usado ao carregar conteudo programaticamente).
Global SuppressModifiedTracking.b = #False

; Tabelas de palavras-chave do dialeto MSX-BASIC/Dignified, usadas tanto
; pelo realce de sintaxe quanto como base para a futura tokenizacao.
Global NewMap KwStatement.b()
Global NewMap KwFunctionPlain.b()
Global NewMap KwFunctionDollar.b()
Global NewMap KwOperatorWord.b()
Global NewMap KwDignifiedStmt.b()
Global NewMap KwBoolean.b()

;- ------------------------------------------------------------
;- Declaracoes
;- ------------------------------------------------------------

Declare.s GetEditorFontName()
Declare   FillKeywordMap(Map Dest.b(), Words.s)
Declare   InitKeywordMaps()
Declare.s ReadSciText(Sci)
Declare   WriteSciText(Sci, Text.s)
Declare   EmitRun(Sci, Text.s, Style)
Declare.b IsAlphaChar(C.s)
Declare.b IsDigitChar(C.s)
Declare.b IsWordChar(C.s)
Declare   HighlightDocument(Sci)
Declare   SetupEditorStyles(Sci)
Declare   ScintillaCallBack(Gadget, *scinotify.SCNotification)
Declare   AddDocumentTab(Path.s = "", Content.s = "")
Declare   FindDocumentByGadget(GadgetNum)
Declare   UpdateTabCaption(Position)
Declare   OpenDocumentDialog()
Declare.b SaveDocument(SaveAs.b = #False)
Declare.b ConfirmDiscard(Text.s)
Declare   CloseTab(Position)
Declare   SaveTokenized()
Declare   SaveAsTokenizedNative()
Declare   SaveAsAsciiFromDignified()
Declare   SaveAsTokenizedFromDignified()
Declare   ResizeInterface()

;- ------------------------------------------------------------
;- Fonte usada no editor (mono espacada, uma opcao razoavel por SO)
;- ------------------------------------------------------------

Procedure.s GetEditorFontName()
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    ProcedureReturn "Consolas"
  CompilerElseIf #PB_Compiler_OS = #PB_OS_Linux
    ProcedureReturn "DejaVu Sans Mono"
  CompilerElse
    ProcedureReturn "Menlo"
  CompilerEndIf
EndProcedure

;- ------------------------------------------------------------
;- Palavras-chave do dialeto (classicas MSX-BASIC + Dignified)
;- ------------------------------------------------------------

Procedure FillKeywordMap(Map Dest.b(), Words.s)
  Protected Count = CountString(Words, " ") + 1
  Protected Idx, Word.s
  For Idx = 1 To Count
    Word = StringField(Words, Idx, " ")
    If Word <> ""
      Dest(Word) = #True
    EndIf
  Next
EndProcedure

Procedure InitKeywordMaps()
  ; Instrucoes/comandos classicos do MSX-BASIC (incluindo os de desvio)
  FillKeywordMap(KwStatement(),
    "AS AUTO BEEP BLOAD BSAVE CALL CIRCLE CLEAR CLOAD CLOSE CLS CMD COLOR " +
    "CONT COPY CSAVE CSRLIN DATA DEF DEFDBL DEFINT DEFSNG DEFSTR DELETE DIM " +
    "DRAW DSKO ELSE END ERASE ERROR FIELD FILES FOR GET GOSUB GOTO IF INPUT " +
    "IPL KANJI KEY KILL LET LINE LIST LLIST LOAD LOCATE LPRINT LSET " +
    "MAXFILES MERGE MOTOR NAME NEW NEXT OFF ON OPEN OUT OUTPUT PAINT PLAY " +
    "POINT POKE PRESET PRINT PSET PUT READ RENUM RESTORE RESUME RETURN " +
    "RSET RUN SAVE SCREEN SET SOUND SPRITE STEP STOP SWAP THEN TO TROFF " +
    "TRON USING VPOKE WAIT WIDTH")

  ; Funcoes classicas sem sufixo $
  FillKeywordMap(KwFunctionPlain(),
    "ABS ASC ATN BASE CDBL CINT COS CSNG CVD CVI CVS DATE DSKF EOF ERL ERR " +
    "EXP FIX FN FPOS FRE INP INSTR INTERVAL INT LEN LOC LOF LOG LPOS PAD " +
    "PDL PEEK POS RND SGN SIN SPC SQR STICK STRIG TAB TAN TIME USR VAL " +
    "VARPTR VDP VPEEK")

  ; Funcoes classicas com sufixo $ (nome base, sem o $)
  FillKeywordMap(KwFunctionDollar(),
    "ATTR BIN CHR DSKI HEX INKEY INPUT LEFT MID MKD MKI MKS OCT RIGHT " +
    "SPACE SPRITE STR STRING")

  ; Operadores logicos (por extenso)
  FillKeywordMap(KwOperatorWord(), "AND OR NOT XOR MOD EQV IMP")

  ; Instrucoes exclusivas do Basic Dignified
  FillKeywordMap(KwDignifiedStmt(), "DEFINE DECLARE INCLUDE KEEP ENDIF FUNC RET EXIT")

  ; Booleanos do Basic Dignified
  FillKeywordMap(KwBoolean(), "TRUE FALSE")
EndProcedure

;- ------------------------------------------------------------
;- Acesso ao texto do ScintillaGadget (UTF-8)
;- ------------------------------------------------------------

Procedure.s ReadSciText(Sci)
  Protected ByteLen = ScintillaSendMessage(Sci, #SCI_GETTEXTLENGTH)
  Protected *Buffer, Result.s
  If ByteLen <= 0
    ProcedureReturn ""
  EndIf
  *Buffer = AllocateMemory(ByteLen + 1)
  If *Buffer
    ScintillaSendMessage(Sci, #SCI_GETTEXT, ByteLen + 1, *Buffer)
    Result = PeekS(*Buffer, -1, #PB_UTF8)
    FreeMemory(*Buffer)
  EndIf
  ProcedureReturn Result
EndProcedure

Procedure WriteSciText(Sci, Text.s)
  Protected *Buffer = UTF8(Text)
  ScintillaSendMessage(Sci, #SCI_SETTEXT, 0, *Buffer)
  FreeMemory(*Buffer)
EndProcedure

; Aplica um estilo a proxima faixa de bytes, avancando o cursor
; interno de "styling" do Scintilla pelo tamanho (em bytes UTF-8) do texto.
Procedure EmitRun(Sci, Text.s, Style)
  Protected ByteLen = StringByteLength(Text, #PB_UTF8)
  If ByteLen > 0
    ScintillaSendMessage(Sci, #SCI_SETSTYLING, ByteLen, Style)
  EndIf
EndProcedure

Procedure.b IsAlphaChar(C.s)
  ProcedureReturn Bool((C >= "A" And C <= "Z") Or (C >= "a" And C <= "z"))
EndProcedure

Procedure.b IsDigitChar(C.s)
  ProcedureReturn Bool(C >= "0" And C <= "9")
EndProcedure

Procedure.b IsWordChar(C.s)
  ProcedureReturn Bool(IsAlphaChar(C) Or IsDigitChar(C) Or C = "_")
EndProcedure

;- ------------------------------------------------------------
;- Realce de sintaxe (lexer artesanal, executado a cada mudanca)
;- ------------------------------------------------------------

Procedure HighlightDocument(Sci)
  Protected Text.s = ReadSciText(Sci)
  Protected TextLen = Len(Text)
  If TextLen = 0
    ProcedureReturn
  EndIf

  Protected I = 1
  Protected AtLineStart.b = #True
  Protected InsideExclusiveBlock.b = #False
  Protected InsideRegularBlock.b = #False
  Protected InDataLiteral.b = #False

  Protected C.s, C2.s, Start, Word.s, CommentLen
  Protected PeekStart, PeekEnd, LineRest.s, LineTrim.s, LineTrimUC.s

  ScintillaSendMessage(Sci, #SCI_STARTSTYLING, 0, 0)

  While I <= TextLen
    C = Mid(Text, I, 1)

    ; --- Fim de linha ---
    If C = Chr(13) Or C = Chr(10)
      EmitRun(Sci, C, #Style_Default)
      I + 1
      AtLineStart = #True
      InDataLiteral = #False
      Continue
    EndIf

    ; --- Construcoes ancoradas no inicio da linha ---
    If AtLineStart
      PeekStart = I
      PeekEnd = I
      While PeekEnd <= TextLen And Mid(Text, PeekEnd, 1) <> Chr(13) And Mid(Text, PeekEnd, 1) <> Chr(10)
        PeekEnd + 1
      Wend
      LineRest = Mid(Text, PeekStart, PeekEnd - PeekStart)
      LineTrim = Trim(LineRest)
      LineTrimUC = UCase(LineTrim)

      If Left(LineTrimUC, 5) = "##BB:" Or Left(LineTrimUC, 5) = "##BD:"
        EmitRun(Sci, LineRest, #Style_Remtag)
        I = PeekEnd
        AtLineStart = #False
        Continue
      ElseIf LineTrimUC = "###"
        If InsideExclusiveBlock : InsideExclusiveBlock = #False : Else : InsideExclusiveBlock = #True : EndIf
        EmitRun(Sci, LineRest, #Style_Comment)
        I = PeekEnd
        AtLineStart = #False
        Continue
      ElseIf LineTrimUC = "''"
        If InsideRegularBlock : InsideRegularBlock = #False : Else : InsideRegularBlock = #True : EndIf
        EmitRun(Sci, LineRest, #Style_Comment)
        I = PeekEnd
        AtLineStart = #False
        Continue
      ElseIf InsideExclusiveBlock Or InsideRegularBlock
        EmitRun(Sci, LineRest, #Style_Comment)
        I = PeekEnd
        AtLineStart = #False
        Continue
      ElseIf Left(LineTrimUC, 2) = "##"
        EmitRun(Sci, LineRest, #Style_Comment)
        I = PeekEnd
        AtLineStart = #False
        Continue
      ElseIf LineTrim = "}"
        EmitRun(Sci, LineRest, #Style_Label)
        I = PeekEnd
        AtLineStart = #False
        Continue
      EndIf

      AtLineStart = #False
    EndIf

    ; --- Comentario ' ate o final da linha ---
    If C = "'"
      CommentLen = 0
      While I + CommentLen <= TextLen And Mid(Text, I + CommentLen, 1) <> Chr(13) And Mid(Text, I + CommentLen, 1) <> Chr(10)
        CommentLen + 1
      Wend
      EmitRun(Sci, Mid(Text, I, CommentLen), #Style_Comment)
      I + CommentLen
      Continue
    EndIf

    ; --- Literais de texto "..." ---
    If C = Chr(34)
      Start = I
      I + 1
      While I <= TextLen And Mid(Text, I, 1) <> Chr(34) And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        I + 1
      Wend
      If I <= TextLen And Mid(Text, I, 1) = Chr(34)
        I + 1
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_String)
      Continue
    EndIf

    ; --- Rotulos {nome} ---
    If C = "{"
      Start = I
      I + 1
      While I <= TextLen And Mid(Text, I, 1) <> "}" And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        I + 1
      Wend
      If I <= TextLen And Mid(Text, I, 1) = "}"
        I + 1
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
      Continue
    EndIf

    ; --- Defines [nome] ---
    If C = "["
      Start = I
      I + 1
      While I <= TextLen And Mid(Text, I, 1) <> "]" And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        I + 1
      Wend
      If I <= TextLen And Mid(Text, I, 1) = "]"
        I + 1
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
      Continue
    EndIf

    ; --- Chamada de proto-funcao .nome ---
    If C = "." And I < TextLen And IsAlphaChar(Mid(Text, I + 1, 1))
      Start = I
      I + 1
      While I <= TextLen And IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_DignifiedStmt)
      Continue
    EndIf

    ; --- Toggle de rem #nome ---
    If C = "#" And I < TextLen And IsAlphaChar(Mid(Text, I + 1, 1))
      Start = I
      I + 1
      While I <= TextLen And IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
      Continue
    EndIf

    ; --- Identificadores / palavras-chave ---
    If IsAlphaChar(C)
      Start = I
      I + 1
      While I <= TextLen And IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      Word = UCase(Mid(Text, Start, I - Start))

      ; Rotulo de loop: nome{ ... }
      If I <= TextLen And Mid(Text, I, 1) = "{"
        I + 1
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
        Continue
      EndIf

      If I <= TextLen And Mid(Text, I, 1) = "$"
        If FindMapElement(KwFunctionDollar(), Word)
          I + 1
          EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Function)
          Continue
        ElseIf FindMapElement(KwStatement(), Word)
          EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Statement)
          Continue
        EndIf
      EndIf

      If FindMapElement(KwDignifiedStmt(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_DignifiedStmt)
        Continue
      ElseIf FindMapElement(KwBoolean(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
        Continue
      ElseIf FindMapElement(KwStatement(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Statement)
        If Word = "DATA"
          InDataLiteral = #True
        EndIf
        Continue
      ElseIf FindMapElement(KwFunctionPlain(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Function)
        Continue
      ElseIf FindMapElement(KwOperatorWord(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Operator)
        Continue
      Else
        If I <= TextLen And (Mid(Text, I, 1) = "$" Or Mid(Text, I, 1) = "%" Or Mid(Text, I, 1) = "!" Or Mid(Text, I, 1) = "#")
          I + 1
        EndIf
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Default)
        Continue
      EndIf
    EndIf

    ; --- Numeros hexadecimais/octais/binarios &H &O &B ---
    If C = "&" And I < TextLen
      C2 = UCase(Mid(Text, I + 1, 1))
      If C2 = "H" Or C2 = "O" Or C2 = "B"
        Start = I
        I + 2
        While I <= TextLen And IsWordChar(Mid(Text, I, 1))
          I + 1
        Wend
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
        Continue
      EndIf
    EndIf

    ; --- Numeros decimais/ponto flutuante ---
    If IsDigitChar(C) Or (C = "." And I < TextLen And IsDigitChar(Mid(Text, I + 1, 1)))
      Start = I
      While I <= TextLen And (IsDigitChar(Mid(Text, I, 1)) Or Mid(Text, I, 1) = ".")
        I + 1
      Wend
      If I <= TextLen And (UCase(Mid(Text, I, 1)) = "E" Or UCase(Mid(Text, I, 1)) = "D") And I + 1 <= TextLen And (Mid(Text, I + 1, 1) = "+" Or Mid(Text, I + 1, 1) = "-")
        I + 2
        While I <= TextLen And IsDigitChar(Mid(Text, I, 1))
          I + 1
        Wend
      EndIf
      If I <= TextLen And (Mid(Text, I, 1) = "%" Or Mid(Text, I, 1) = "!" Or Mid(Text, I, 1) = "#")
        I + 1
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
      Continue
    EndIf

    ; --- Modo literal de DATA (ate ':' ou fim de linha) ---
    If InDataLiteral And C <> ":"
      Start = I
      While I <= TextLen And Mid(Text, I, 1) <> ":" And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_String)
      Continue
    EndIf

    ; --- Operadores compostos e simbolos ---
    If C = "+" Or C = "-" Or C = "*" Or C = "/" Or C = "^" Or C = "\" Or C = "=" Or C = "<" Or C = ">"
      Start = I
      I + 1
      If I <= TextLen
        C2 = Mid(Text, I, 1)
        If ((C = "+" And (C2 = "+" Or C2 = "=")) Or (C = "-" And (C2 = "-" Or C2 = "=")) Or
            (C = "*" And C2 = "=") Or (C = "/" And C2 = "=") Or (C = "^" And C2 = "=") Or
            (C = "<" And (C2 = ">" Or C2 = "=")) Or (C = ">" And C2 = "="))
          I + 1
        EndIf
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Operator)
      InDataLiteral = #False
      Continue
    EndIf

    ; --- Separadores ---
    If C = ":" Or C = "," Or C = ";" Or C = "(" Or C = ")" Or C = "~" Or C = "@"
      EmitRun(Sci, C, #Style_Operator)
      I + 1
      If C = ":"
        InDataLiteral = #False
      EndIf
      Continue
    EndIf

    ; --- Qualquer outro caractere (espacos, etc) ---
    EmitRun(Sci, C, #Style_Default)
    I + 1
  Wend
EndProcedure

;- ------------------------------------------------------------
;- Aparencia do ScintillaGadget (tema escuro)
;- ------------------------------------------------------------

Procedure SetupEditorStyles(Sci)
  Protected *FontName

  ScintillaSendMessage(Sci, #SCI_SETCODEPAGE, #SC_CP_UTF8)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #STYLE_DEFAULT, RGB(220, 223, 230))
  ScintillaSendMessage(Sci, #SCI_STYLESETBACK, #STYLE_DEFAULT, RGB(24, 26, 34))
  *FontName = UTF8(GetEditorFontName())
  ScintillaSendMessage(Sci, #SCI_STYLESETFONT, #STYLE_DEFAULT, *FontName)
  FreeMemory(*FontName)
  ScintillaSendMessage(Sci, #SCI_STYLESETSIZE, #STYLE_DEFAULT, 11)
  ScintillaSendMessage(Sci, #SCI_STYLECLEARALL)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Comment, RGB(98, 114, 142))
  ScintillaSendMessage(Sci, #SCI_STYLESETITALIC, #Style_Comment, #True)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_String, RGB(152, 195, 121))
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Statement, RGB(198, 120, 221))
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Statement, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Operator, RGB(224, 108, 117))
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Function, RGB(97, 175, 239))
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Number, RGB(209, 154, 102))
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Label, RGB(229, 181, 103))
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Label, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_DignifiedStmt, RGB(230, 126, 144))
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_DignifiedStmt, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Remtag, RGB(255, 203, 107))
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Remtag, #True)

  ScintillaSendMessage(Sci, #SCI_SETCARETFORE, RGB(255, 255, 255))
  ScintillaSendMessage(Sci, #SCI_SETSELBACK, 1, RGB(60, 80, 110))
  ScintillaSendMessage(Sci, #SCI_SETTABWIDTH, 4)
EndProcedure

;- ------------------------------------------------------------
;- Callback do Scintilla (mudancas de texto -> realce + modificado)
;- ------------------------------------------------------------

; Nao chama de volta o Scintilla diretamente daqui: a notificacao ainda
; esta em andamento (dentro do proprio SendMessage que a disparou), entao
; o trabalho real (reler texto, aplicar estilos) e adiado para o loop
; principal atraves de PostEvent, evitando reentrancia no controle.
Procedure ScintillaCallBack(Gadget, *scinotify.SCNotification)
  Select *scinotify\nmhdr\code
    Case #SCN_MODIFIED
      If *scinotify\modificationType & (#SC_MOD_INSERTTEXT | #SC_MOD_DELETETEXT)
        PostEvent(#Event_Rehighlight, #MainWindow, Gadget, 0, SuppressModifiedTracking)
      EndIf
  EndSelect
EndProcedure

;- ------------------------------------------------------------
;- Documentos / abas
;- ------------------------------------------------------------

Procedure AddDocumentTab(Path.s = "", Content.s = "")
  Protected Caption.s
  Protected InnerW, InnerH
  Protected Sci

  If Path = ""
    UntitledCount + 1
    Caption = "Sem titulo " + Str(UntitledCount)
  Else
    Caption = GetFilePart(Path)
  EndIf

  If CountGadgetItems(#PanelGadget) > 0
    InnerW = GetGadgetAttribute(#PanelGadget, #PB_Panel_ItemWidth)
    InnerH = GetGadgetAttribute(#PanelGadget, #PB_Panel_ItemHeight)
  EndIf
  If InnerW <= 0 : InnerW = GadgetWidth(#PanelGadget) : EndIf
  If InnerH <= 0 : InnerH = GadgetHeight(#PanelGadget) : EndIf

  OpenGadgetList(#PanelGadget)
    AddGadgetItem(#PanelGadget, -1, Caption)
    Sci = ScintillaGadget(#PB_Any, 0, 0, InnerW, InnerH, @ScintillaCallBack())
    SetupEditorStyles(Sci)

    AddElement(Docs())
    Docs()\Path      = Path
    Docs()\Modified  = #False
    Docs()\SciGadget = Sci

    If Content <> ""
      SuppressModifiedTracking = #True
      WriteSciText(Sci, Content)
      SuppressModifiedTracking = #False
    EndIf

    ScintillaSendMessage(Sci, #SCI_EMPTYUNDOBUFFER)
    Docs()\Modified = #False
  CloseGadgetList()

  SetGadgetState(#PanelGadget, CountGadgetItems(#PanelGadget) - 1)
  SetActiveGadget(Sci)
EndProcedure

Procedure FindDocumentByGadget(GadgetNum)
  Protected Position = 0
  ForEach Docs()
    If Docs()\SciGadget = GadgetNum
      ProcedureReturn Position
    EndIf
    Position + 1
  Next
  ProcedureReturn -1
EndProcedure

Procedure UpdateTabCaption(Position)
  If SelectElement(Docs(), Position)
    Protected Caption.s
    If Docs()\Path = ""
      Caption = GetGadgetItemText(#PanelGadget, Position)
      If Right(Caption, 2) = " *"
        Caption = Left(Caption, Len(Caption) - 2)
      EndIf
    Else
      Caption = GetFilePart(Docs()\Path)
    EndIf
    If Docs()\Modified
      Caption + " *"
    EndIf
    SetGadgetItemText(#PanelGadget, Position, Caption)
  EndIf
EndProcedure

Procedure OpenDocumentDialog()
  Protected Path.s = OpenFileRequester("Abrir arquivo", "", #File_Pattern, 0)
  If Path = ""
    ProcedureReturn
  EndIf

  Protected Position = 0
  ForEach Docs()
    If Docs()\Path = Path
      SetGadgetState(#PanelGadget, Position)
      ProcedureReturn
    EndIf
    Position + 1
  Next

  Protected FileNum = ReadFile(#PB_Any, Path, #PB_File_BOM)
  If Not FileNum
    MessageRequester("Erro", "Nao foi possivel abrir o arquivo:" + Chr(10) + Path, #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected Content.s
  While Not Eof(FileNum)
    Content + ReadString(FileNum, #PB_File_IgnoreEOL) + Chr(13) + Chr(10)
  Wend
  CloseFile(FileNum)

  AddDocumentTab(Path, Content)
EndProcedure

Procedure.b SaveDocument(SaveAs.b = #False)
  Protected Position = GetGadgetState(#PanelGadget)
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn #False
  EndIf

  Protected Path.s = Docs()\Path

  If SaveAs Or Path = ""
    Protected Suggestion.s = Path
    If Suggestion = ""
      Suggestion = GetGadgetItemText(#PanelGadget, Position)
      If Right(Suggestion, 2) = " *"
        Suggestion = Left(Suggestion, Len(Suggestion) - 2)
      EndIf
      Suggestion + ".dmx"
    EndIf
    Protected NewPath.s = SaveFileRequester("Salvar como", Suggestion, #File_Pattern, 0)
    If NewPath = ""
      ProcedureReturn #False
    EndIf
    Path = NewPath
  EndIf

  Protected FileNum = CreateFile(#PB_Any, Path)
  If Not FileNum
    MessageRequester("Erro", "Nao foi possivel salvar o arquivo:" + Chr(10) + Path, #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn #False
  EndIf

  WriteString(FileNum, ReadSciText(Docs()\SciGadget))
  CloseFile(FileNum)

  Docs()\Path     = Path
  Docs()\Modified = #False
  UpdateTabCaption(Position)
  ProcedureReturn #True
EndProcedure

Procedure.b ConfirmDiscard(Text.s)
  Protected Result = MessageRequester(#App_Title, Text, #PB_MessageRequester_YesNo | #PB_MessageRequester_Warning)
  ProcedureReturn Bool(Result = #PB_MessageRequester_Yes)
EndProcedure

Procedure CloseTab(Position)
  If Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  If Docs()\Modified
    Protected Name.s = GetFilePart(Docs()\Path)
    If Name = "" : Name = "este documento" : EndIf
    If Not ConfirmDiscard("'" + Name + "' tem alteracoes nao salvas." + Chr(10) + "Fechar mesmo assim?")
      ProcedureReturn
    EndIf
  EndIf

  RemoveGadgetItem(#PanelGadget, Position)
  DeleteElement(Docs())

  If CountGadgetItems(#PanelGadget) = 0
    AddDocumentTab()
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Gerar MSX-BASIC tokenizado (.bmx) via o toolchain do Basic Dignified
;- ------------------------------------------------------------

Procedure SaveTokenized()
  Protected Position = GetGadgetState(#PanelGadget)
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  ; Garante que o arquivo esteja salvo em disco (com extensao .dmx) e
  ; refletindo o conteudo atual antes de tokenizar.
  If Not SaveDocument(#False)
    ProcedureReturn
  EndIf

  Protected Path.s = Docs()\Path
  Protected BadigRoot.s = GetPathPart(ProgramFilename()) + "..\badig\"
  Protected Params.s = "badig.py " + Chr(34) + Path + Chr(34) + BadigCfg_BuildCliArgs()

  Protected Prog = RunProgram("python", Params, BadigRoot, #PB_Program_Open | #PB_Program_Read | #PB_Program_Error)
  If Not Prog
    MessageRequester("Erro", "Nao foi possivel executar o Python." + Chr(10) + "Verifique se ele esta instalado e disponivel no PATH.", #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  ; Com "Abrir o openMSX e rodar" ativado nas configuracoes, o processo do
  ; badig.py so termina quando o emulador for fechado - nao esperamos por ele
  ; aqui para nao travar a interface do editor.
  If BadigCfg\EmRun
    MessageRequester("Tokenizado gerado", "Comando enviado ao Basic Dignified." + Chr(10) + "O openMSX sera aberto pelo proprio badig.py.", #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
    ProcedureReturn
  EndIf

  WaitProgram(Prog, 20000)

  Protected Output.s = ""
  While AvailableProgramOutput(Prog)
    Output + ReadProgramString(Prog) + Chr(10)
  Wend

  Protected ErrLine.s
  Repeat
    ErrLine = ReadProgramError(Prog)
    If ErrLine <> ""
      Output + ErrLine + Chr(10)
    EndIf
  Until ErrLine = ""

  Protected ExitCode = ProgramExitCode(Prog)
  CloseProgram(Prog)

  If ExitCode = 0
    MessageRequester("Tokenizado gerado", Output, #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
  Else
    MessageRequester("Erro ao gerar o tokenizado", Output, #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
  EndIf
EndProcedure

; Tokeniza o conteudo da aba atual (MSX-BASIC ASCII classico, com numeros de
; linha) usando o tokenizador nativo (MsxTokenizer.pbi) e salva o binario
; resultante como .bmx. Nao depende de Python nem do toolchain badig/.
Procedure SaveAsTokenizedNative()
  Protected Position = GetGadgetState(#PanelGadget)
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  Protected SourceText.s = ReadSciText(Docs()\SciGadget)

  ; Este menu espera ASCII classico (linhas ja numeradas), nao Dignified.
  ; Deteccao simples: se a primeira linha com conteudo nao comeca com um
  ; numero, o arquivo provavelmente ainda e Dignified - avisa em vez de
  ; deixar o erro criptico do tokenizador confundir o usuario.
  Protected FirstContentLine.s = ""
  Protected LineIdx
  For LineIdx = 0 To CountString(SourceText, Chr(10))
    FirstContentLine = Trim(StringField(ReplaceString(SourceText, Chr(13), ""), LineIdx + 1, Chr(10)))
    If FirstContentLine <> ""
      Break
    EndIf
  Next
  If FirstContentLine <> "" And Not (Asc(FirstContentLine) >= 48 And Asc(FirstContentLine) <= 57)
    MessageRequester("Arquivo nao parece ser ASCII classico",
                     "Este menu tokeniza MSX-BASIC classico (linhas ja numeradas)." + Chr(10) +
                     "Este arquivo parece ser codigo Dignified (nao comeca com numero)." + Chr(10) + Chr(10) +
                     "Use 'Dignified -> tokenizado nativo (.bmx)...' em vez disso.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected HexOut.s = Tok_Tokenize(SourceText)

  If Tok_HasError
    MessageRequester("Erro ao tokenizar",
                     "Linha " + Str(Tok_ErrorLine) + ": " + Tok_ErrorMsg,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected Suggestion.s = Docs()\Path
  If Suggestion = ""
    Suggestion = GetGadgetItemText(#PanelGadget, Position)
    If Right(Suggestion, 2) = " *"
      Suggestion = Left(Suggestion, Len(Suggestion) - 2)
    EndIf
  EndIf
  Suggestion = GetPathPart(Suggestion) + GetFilePart(Suggestion, #PB_FileSystem_NoExtension) + ".bmx"

  Protected SavePath.s = SaveFileRequester("Salvar como tokenizado", Suggestion,
                                           "MSX Basic tokenizado (*.bmx)|*.bmx|Todos os arquivos (*.*)|*.*", 0)
  If SavePath = ""
    ProcedureReturn
  EndIf

  If Not Tok_SaveHexAsBinary(HexOut, SavePath)
    MessageRequester("Erro", "Nao foi possivel salvar o arquivo:" + Chr(10) + SavePath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  MessageRequester("Tokenizado gerado", "Salvo em:" + Chr(10) + SavePath,
                   #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
EndProcedure

; Roda o pre-processador Dignified nativo (DignifiedPreprocessor.pbi) sobre o
; conteudo da aba atual e devolve o texto ASCII classico resultante, ou ""
; em erro (mostrando o dialogo de erro). Usado pelas duas procedures abaixo.
Procedure.s RunDignifiedPreprocessor()
  Protected SourceText.s = ReadSciText(Docs()\SciGadget)
  Protected AsciiOut.s = Dig_Preprocess(SourceText)

  If Dig_HasError
    MessageRequester("Erro no pre-processador Dignified",
                     "Linha " + Str(Dig_ErrorLine) + ": " + Dig_ErrorMsg,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn ""
  EndIf

  ProcedureReturn AsciiOut
EndProcedure

; Converte o Dignified da aba atual para MSX-BASIC ASCII classico (nativo,
; sem Python) e salva como .amx.
Procedure SaveAsAsciiFromDignified()
  Protected Position = GetGadgetState(#PanelGadget)
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  Protected AsciiOut.s = RunDignifiedPreprocessor()
  If AsciiOut = ""
    ProcedureReturn
  EndIf

  Protected Suggestion.s = Docs()\Path
  If Suggestion = ""
    Suggestion = GetGadgetItemText(#PanelGadget, Position)
    If Right(Suggestion, 2) = " *"
      Suggestion = Left(Suggestion, Len(Suggestion) - 2)
    EndIf
  EndIf
  Suggestion = GetPathPart(Suggestion) + GetFilePart(Suggestion, #PB_FileSystem_NoExtension) + ".amx"

  Protected SavePath.s = SaveFileRequester("Salvar como ASCII classico", Suggestion,
                                           "MSX Basic ASCII (*.amx)|*.amx|Todos os arquivos (*.*)|*.*", 0)
  If SavePath = ""
    ProcedureReturn
  EndIf

  Protected FileNum = CreateFile(#PB_Any, SavePath)
  If Not FileNum
    MessageRequester("Erro", "Nao foi possivel salvar o arquivo:" + Chr(10) + SavePath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf
  WriteString(FileNum, AsciiOut)
  CloseFile(FileNum)

  MessageRequester("ASCII gerado", "Salvo em:" + Chr(10) + SavePath,
                   #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
EndProcedure

; Converte o Dignified da aba atual direto para tokenizado .bmx, encadeando
; o pre-processador nativo com o tokenizador nativo. Sem Python em nenhum passo.
Procedure SaveAsTokenizedFromDignified()
  Protected Position = GetGadgetState(#PanelGadget)
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  Protected AsciiOut.s = RunDignifiedPreprocessor()
  If AsciiOut = ""
    ProcedureReturn
  EndIf

  Protected HexOut.s = Tok_Tokenize(AsciiOut)
  If Tok_HasError
    MessageRequester("Erro ao tokenizar",
                     "Linha " + Str(Tok_ErrorLine) + ": " + Tok_ErrorMsg,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected Suggestion.s = Docs()\Path
  If Suggestion = ""
    Suggestion = GetGadgetItemText(#PanelGadget, Position)
    If Right(Suggestion, 2) = " *"
      Suggestion = Left(Suggestion, Len(Suggestion) - 2)
    EndIf
  EndIf
  Suggestion = GetPathPart(Suggestion) + GetFilePart(Suggestion, #PB_FileSystem_NoExtension) + ".bmx"

  Protected SavePath.s = SaveFileRequester("Salvar como tokenizado", Suggestion,
                                           "MSX Basic tokenizado (*.bmx)|*.bmx|Todos os arquivos (*.*)|*.*", 0)
  If SavePath = ""
    ProcedureReturn
  EndIf

  If Not Tok_SaveHexAsBinary(HexOut, SavePath)
    MessageRequester("Erro", "Nao foi possivel salvar o arquivo:" + Chr(10) + SavePath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  MessageRequester("Tokenizado gerado", "Salvo em:" + Chr(10) + SavePath,
                   #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
EndProcedure

;- ------------------------------------------------------------
;- Layout / redimensionamento
;- ------------------------------------------------------------

Procedure ResizeInterface()
  Protected PanelW = WindowWidth(#MainWindow)
  Protected PanelH = WindowHeight(#MainWindow) - StatusBarHeight(#MainStatusBar)
  If PanelH < 0 : PanelH = 0 : EndIf

  ResizeGadget(#PanelGadget, 0, 0, PanelW, PanelH)

  Protected InnerW, InnerH
  If CountGadgetItems(#PanelGadget) > 0
    CompilerIf #PB_Compiler_OS = #PB_OS_Linux
      InnerW = PanelW
      InnerH = PanelH - #Linux_TabGuess
    CompilerElse
      InnerW = GetGadgetAttribute(#PanelGadget, #PB_Panel_ItemWidth)
      InnerH = GetGadgetAttribute(#PanelGadget, #PB_Panel_ItemHeight)
    CompilerEndIf
  EndIf
  If InnerW <= 0 : InnerW = PanelW : EndIf
  If InnerH <= 0 : InnerH = PanelH : EndIf

  ForEach Docs()
    ResizeGadget(Docs()\SciGadget, 0, 0, InnerW, InnerH)
  Next
EndProcedure

;- ------------------------------------------------------------
;- Programa principal
;- ------------------------------------------------------------

InitKeywordMaps()
BadigCfg_Load()

If Not OpenWindow(#MainWindow, 0, 0, 1000, 700, #App_Title, #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget)
  End
EndIf

CreateMenu(#MainMenu, WindowID(#MainWindow))
  MenuTitle("Arquivo")
    MenuItem(#Menu_New,      "Novo" + Chr(9) + "Ctrl+N")
    MenuItem(#Menu_Open,     "Abrir..." + Chr(9) + "Ctrl+O")
    MenuBar()
    MenuItem(#Menu_Save,     "Salvar" + Chr(9) + "Ctrl+S")
    MenuItem(#Menu_SaveAs,   "Salvar como..." + Chr(9) + "Ctrl+Shift+S")
    MenuBar()
    MenuItem(#Menu_Tokenize, "Gerar tokenizado MSX via Python (.bmx)...")
    MenuBar()
    MenuItem(#Menu_DignifiedToAscii, "Dignified -> ASCII nativo (.amx)...")
    MenuItem(#Menu_DignifiedToTokenized, "Dignified -> tokenizado nativo (.bmx)...")
    MenuBar()
    MenuItem(#Menu_TokenizeNative, "ASCII classico ja aberto -> tokenizado nativo (.bmx)...")
    MenuBar()
    MenuItem(#Menu_CloseTab, "Fechar aba" + Chr(9) + "Ctrl+W")
    MenuBar()
    MenuItem(#Menu_Exit,     "Sair" + Chr(9) + "Alt+F4")
  MenuTitle("Configurar")
    MenuItem(#Menu_ConfigureBadig, "Basic Dignified...")

AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_N, #Menu_New)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_O, #Menu_Open)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_S, #Menu_Save)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_Shift | #PB_Shortcut_S, #Menu_SaveAs)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_W, #Menu_CloseTab)

PanelGadget(#PanelGadget, 0, 0, WindowWidth(#MainWindow), WindowHeight(#MainWindow))

CreateStatusBar(#MainStatusBar, WindowID(#MainWindow))
  AddStatusBarField(#PB_Ignore)

AddDocumentTab()
ResizeInterface()

Define Event, Quit, Position, AllSaved, Discard, ChangedGadget, DocPos

Repeat
  Event = WaitWindowEvent()

  Select Event

    Case #PB_Event_Menu
      Select EventMenu()
        Case #Menu_New
          AddDocumentTab()

        Case #Menu_Open
          OpenDocumentDialog()

        Case #Menu_Save
          SaveDocument(#False)

        Case #Menu_SaveAs
          SaveDocument(#True)

        Case #Menu_Tokenize
          SaveTokenized()

        Case #Menu_TokenizeNative
          SaveAsTokenizedNative()

        Case #Menu_DignifiedToAscii
          SaveAsAsciiFromDignified()

        Case #Menu_DignifiedToTokenized
          SaveAsTokenizedFromDignified()

        Case #Menu_CloseTab
          CloseTab(GetGadgetState(#PanelGadget))

        Case #Menu_Exit
          Quit = 1

        Case #Menu_ConfigureBadig
          BadigCfg_OpenSettingsWindow(#MainWindow)
      EndSelect

    Case #PB_Event_CloseWindow
      Quit = 1

    Case #PB_Event_SizeWindow
      ResizeInterface()

    Case #Event_Rehighlight
      ChangedGadget = EventGadget()
      If Not EventData()
        DocPos = FindDocumentByGadget(ChangedGadget)
        If DocPos >= 0
          If SelectElement(Docs(), DocPos)
            If Not Docs()\Modified
              Docs()\Modified = #True
              UpdateTabCaption(DocPos)
            EndIf
          EndIf
        EndIf
      EndIf
      HighlightDocument(ChangedGadget)

  EndSelect

  If Quit
    AllSaved = #True
    ForEach Docs()
      If Docs()\Modified
        AllSaved = #False
        Break
      EndIf
    Next
    If Not AllSaved
      Discard = ConfirmDiscard("Existem documentos com alteracoes nao salvas." + Chr(10) + "Sair mesmo assim?")
      If Not Discard
        Quit = 0
      EndIf
    EndIf
  EndIf

Until Quit = 1

End
