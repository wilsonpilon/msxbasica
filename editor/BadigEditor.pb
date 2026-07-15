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
XIncludeFile "EditorSettings.pbi"
XIncludeFile "BadigSettings.pbi"

;- ------------------------------------------------------------
;- Constantes gerais
;- ------------------------------------------------------------

Enumeration Windows
  #MainWindow
EndEnumeration

Enumeration Gadgets
  #TabBarGadget
  #RulerGadget
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
  #Menu_ConfigureEditor
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
#Event_UpdateUI    = #PB_Event_FirstCustomValue + 1

#App_Title      = "Basic Dignified Editor"
#File_Pattern   = "MSX-BASIC Dignified (*.dmx)|*.dmx|MSX Basic ASCII (*.amx)|*.amx|Todos os arquivos (*.*)|*.*"

; Tab bar / regua de colunas - abas customizadas (com botao de fechar) desenhadas
; num CanvasGadget, no lugar do PanelGadget nativo (que nao suporta isso e tem
; visual datado demais nas 3 plataformas).
#TabBar_Height   = 36
#Ruler_Height    = 20
#Tab_PadX        = 14
#Tab_MinWidth    = 90
#Tab_MaxWidth    = 220
#Tab_CloseSize   = 14
#Tab_CloseGap    = 10
#Tab_Gap         = 2

; Cores da tab bar/regua/sintaxe (RGB() e uma funcao em tempo de execucao no
; PureBasic, entao essas nao podem ser #Constantes - sao globais, atribuidas
; por ApplyTheme() de acordo com EditorCfg\Theme (ver EditorSettings.pbi),
; chamada antes de qualquer janela/gadget ser criado e de novo sempre que o
; usuario troca o tema em Configurar -> Editor...
Global Color_AppBg, Color_EditorBg, Color_TabInactive, Color_TabHover
Global Color_TextActive, Color_TextInactive, Color_Accent, Color_CloseHover
Global Color_RulerBg, Color_RulerText, Color_RulerTick

Global Color_Syntax_Default, Color_Syntax_Comment, Color_Syntax_String
Global Color_Syntax_Statement, Color_Syntax_Operator, Color_Syntax_Function
Global Color_Syntax_Number, Color_Syntax_Label, Color_Syntax_DignifiedStmt
Global Color_Syntax_Remtag, Color_Caret, Color_SelBack, Color_LineNumberFore

; Preenche todos os globais Color_* acima de acordo com EditorCfg\Theme.
Procedure ApplyTheme()
  If EditorCfg\Theme = "Light"
    Color_AppBg        = RGB(245, 246, 248)
    Color_EditorBg      = RGB(255, 255, 255)
    Color_TabInactive   = RGB(230, 231, 235)
    Color_TabHover      = RGB(220, 222, 228)
    Color_TextActive    = RGB(40, 42, 48)
    Color_TextInactive  = RGB(120, 124, 132)
    Color_Accent        = RGB(64, 120, 192)
    Color_CloseHover    = RGB(200, 60, 70)
    Color_RulerBg       = RGB(238, 239, 242)
    Color_RulerText     = RGB(120, 124, 132)
    Color_RulerTick     = RGB(200, 202, 208)

    Color_Syntax_Default       = RGB(56, 58, 66)
    Color_Syntax_Comment       = RGB(160, 161, 167)
    Color_Syntax_String        = RGB(80, 161, 79)
    Color_Syntax_Statement     = RGB(166, 38, 164)
    Color_Syntax_Operator      = RGB(228, 86, 73)
    Color_Syntax_Function      = RGB(64, 120, 192)
    Color_Syntax_Number        = RGB(152, 104, 1)
    Color_Syntax_Label         = RGB(196, 143, 0)
    Color_Syntax_DignifiedStmt = RGB(202, 57, 84)
    Color_Syntax_Remtag        = RGB(178, 120, 0)
    Color_Caret                = RGB(0, 0, 0)
    Color_SelBack               = RGB(198, 214, 251)
    Color_LineNumberFore       = RGB(140, 144, 152)
  Else
    Color_AppBg        = RGB(15, 16, 21)   ; um pouco mais escuro que o fundo do editor, para dar profundidade
    Color_EditorBg      = RGB(24, 26, 34)  ; mesma cor de fundo do ScintillaGadget
    Color_TabInactive   = RGB(30, 32, 40)
    Color_TabHover      = RGB(38, 41, 52)
    Color_TextActive    = RGB(220, 223, 230)
    Color_TextInactive  = RGB(140, 145, 160)
    Color_Accent        = RGB(97, 175, 239) ; mesmo azul de #Style_Function
    Color_CloseHover    = RGB(224, 108, 117); mesmo vermelho de #Style_Operator
    Color_RulerBg       = RGB(20, 21, 28)
    Color_RulerText     = RGB(110, 116, 130)
    Color_RulerTick     = RGB(60, 64, 76)

    Color_Syntax_Default       = RGB(220, 223, 230)
    Color_Syntax_Comment       = RGB(98, 114, 142)
    Color_Syntax_String        = RGB(152, 195, 121)
    Color_Syntax_Statement     = RGB(198, 120, 221)
    Color_Syntax_Operator      = RGB(224, 108, 117)
    Color_Syntax_Function      = RGB(97, 175, 239)
    Color_Syntax_Number        = RGB(209, 154, 102)
    Color_Syntax_Label         = RGB(229, 181, 103)
    Color_Syntax_DignifiedStmt = RGB(230, 126, 144)
    Color_Syntax_Remtag        = RGB(255, 203, 107)
    Color_Caret                = RGB(255, 255, 255)
    Color_SelBack               = RGB(60, 80, 110)
    Color_LineNumberFore       = RGB(100, 106, 122)
  EndIf
EndProcedure

;- ------------------------------------------------------------
;- Estruturas e listas globais
;- ------------------------------------------------------------

Structure Document
  Path.s            ; caminho completo no disco, vazio se ainda nao foi salvo
  Modified.b        ; 1 se ha alteracoes nao salvas
  SciGadget.i       ; ScintillaGadget associado a esta aba
  UntitledName.s    ; nome estavel ("Sem titulo N"), so usado enquanto Path = ""
  DisplayCaption.s  ; rotulo ja computado (nome + " *" se modificado), cache para RedrawTabBar
  TabX1.i           ; retangulo da aba inteira na tab bar (hit-test de clique/hover)
  TabX2.i
  CloseX1.i         ; retangulo do botao "x" de fechar, dentro da aba
  CloseX2.i
EndStructure

Global NewList Docs.Document()
Global UntitledCount = 0
Global ActiveTabPosition.i = -1
Global HoverTabPosition.i = -1
Global HoverCloseTabPosition.i = -1

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
Declare   UpdateLineNumberMargin(Sci)
Declare   ActiveSciGadget()
Declare   ScintillaCallBack(Gadget, *scinotify.SCNotification)
Declare.s ComputeTabCaption(Position)
Declare   RedrawTabBar()
Declare   RedrawRuler()
Declare   SetActiveTab(Position)
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
Declare   Dig_SyncConfigFromBadigCfg()
Declare   ResizeInterface()

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

  UpdateLineNumberMargin(Sci)
  If Sci = ActiveSciGadget()
    RedrawRuler()
  EndIf

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
;- Aparencia do ScintillaGadget (fonte/tema conforme EditorCfg - ver
;- ApplyTheme() e EditorSettings.pbi)
;- ------------------------------------------------------------

Procedure SetupEditorStyles(Sci)
  Protected *FontName

  ScintillaSendMessage(Sci, #SCI_SETCODEPAGE, #SC_CP_UTF8)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #STYLE_DEFAULT, Color_Syntax_Default)
  ScintillaSendMessage(Sci, #SCI_STYLESETBACK, #STYLE_DEFAULT, Color_EditorBg)
  *FontName = UTF8(EditorCfg\FontName)
  ScintillaSendMessage(Sci, #SCI_STYLESETFONT, #STYLE_DEFAULT, *FontName)
  FreeMemory(*FontName)
  ScintillaSendMessage(Sci, #SCI_STYLESETSIZE, #STYLE_DEFAULT, EditorCfg\FontSize)
  ScintillaSendMessage(Sci, #SCI_STYLECLEARALL)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Comment, Color_Syntax_Comment)
  ScintillaSendMessage(Sci, #SCI_STYLESETITALIC, #Style_Comment, #True)

  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_String, Color_Syntax_String)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Statement, Color_Syntax_Statement)
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Statement, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Operator, Color_Syntax_Operator)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Function, Color_Syntax_Function)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Number, Color_Syntax_Number)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Label, Color_Syntax_Label)
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Label, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_DignifiedStmt, Color_Syntax_DignifiedStmt)
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_DignifiedStmt, #True)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #Style_Remtag, Color_Syntax_Remtag)
  ScintillaSendMessage(Sci, #SCI_STYLESETBOLD, #Style_Remtag, #True)

  ScintillaSendMessage(Sci, #SCI_SETCARETFORE, Color_Caret)
  ScintillaSendMessage(Sci, #SCI_SETSELBACK, 1, Color_SelBack)
  ScintillaSendMessage(Sci, #SCI_SETTABWIDTH, 4)

  ; Margem de numeros de linha - unica margem usada (sem marcadores/folding)
  ScintillaSendMessage(Sci, #SCI_STYLESETFORE, #STYLE_LINENUMBER, Color_LineNumberFore)
  ScintillaSendMessage(Sci, #SCI_STYLESETBACK, #STYLE_LINENUMBER, Color_RulerBg)
  ScintillaSendMessage(Sci, #SCI_SETMARGINTYPEN, 0, #SC_MARGIN_NUMBER)
  ScintillaSendMessage(Sci, #SCI_SETMARGINWIDTHN, 1, 0)
  ScintillaSendMessage(Sci, #SCI_SETMARGINWIDTHN, 2, 0)
  UpdateLineNumberMargin(Sci)
EndProcedure

; Recalcula a largura da margem de numeros de linha com base na quantidade de
; digitos necessaria (numero de linhas do documento) e na largura real do
; caractere na fonte monoespacada em uso - mantem a margem sempre do tamanho
; certo (nem apertada demais, nem larga demais) conforme o arquivo cresce.
Procedure UpdateLineNumberMargin(Sci)
  Protected Digits = Len(Str(ScintillaSendMessage(Sci, #SCI_GETLINECOUNT)))
  If Digits < 3 : Digits = 3 : EndIf
  Protected *Sample = UTF8(RSet("", Digits, "9"))
  Protected TextW = ScintillaSendMessage(Sci, #SCI_TEXTWIDTH, #STYLE_LINENUMBER, *Sample)
  FreeMemory(*Sample)
  ScintillaSendMessage(Sci, #SCI_SETMARGINWIDTHN, 0, TextW + 16)
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

    Case #SCN_UPDATEUI
      ; disparado em scroll/mudanca de selecao/caret - mantem a regua de colunas
      ; e a margem de numeros de linha alinhadas com o que esta sendo exibido
      PostEvent(#Event_UpdateUI, #MainWindow, Gadget, 0, 0)
  EndSelect
EndProcedure

;- ------------------------------------------------------------
;- Documentos / abas (tab bar customizada - ver RedrawTabBar/RedrawRuler)
;- ------------------------------------------------------------

; Gadget Scintilla da aba ativa no momento, ou 0 se nao houver nenhuma aba.
Procedure ActiveSciGadget()
  If ActiveTabPosition < 0 Or Not SelectElement(Docs(), ActiveTabPosition)
    ProcedureReturn 0
  EndIf
  ProcedureReturn Docs()\SciGadget
EndProcedure

; Torna a aba em Position a aba visivel/ativa: mostra o ScintillaGadget dela e
; esconde todos os outros, atualiza a selecao visual da tab bar e a regua.
Procedure SetActiveTab(Position)
  If Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  ActiveTabPosition = Position

  Protected P = 0
  ForEach Docs()
    HideGadget(Docs()\SciGadget, Bool(P <> Position))
    P + 1
  Next

  SelectElement(Docs(), Position)
  SetActiveGadget(Docs()\SciGadget)
  UpdateLineNumberMargin(Docs()\SciGadget)

  RedrawTabBar()
  RedrawRuler()
EndProcedure

Procedure AddDocumentTab(Path.s = "", Content.s = "")
  Protected InnerW, InnerH, Sci

  InnerW = GadgetWidth(#RulerGadget)
  InnerH = WindowHeight(#MainWindow) - StatusBarHeight(#MainStatusBar) - #TabBar_Height - #Ruler_Height
  If InnerW <= 0 : InnerW = WindowWidth(#MainWindow) : EndIf
  If InnerH <= 0 : InnerH = 200 : EndIf

  Sci = ScintillaGadget(#PB_Any, 0, #TabBar_Height + #Ruler_Height, InnerW, InnerH, @ScintillaCallBack())
  SetupEditorStyles(Sci)

  AddElement(Docs())
  Docs()\Path      = Path
  Docs()\Modified  = #False
  Docs()\SciGadget = Sci

  If Path = ""
    UntitledCount + 1
    Docs()\UntitledName = "Sem titulo " + Str(UntitledCount)
  EndIf

  If Content <> ""
    SuppressModifiedTracking = #True
    WriteSciText(Sci, Content)
    SuppressModifiedTracking = #False
  EndIf

  ScintillaSendMessage(Sci, #SCI_EMPTYUNDOBUFFER)
  Docs()\Modified = #False

  Protected NewPosition = ListSize(Docs()) - 1
  UpdateTabCaption(NewPosition)
  SetActiveTab(NewPosition)
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

; Recalcula Docs()\DisplayCaption (nome + " *" se modificado) e redesenha a tab
; bar. Chamada sempre que o nome, caminho ou estado "modificado" de uma aba muda.
Procedure UpdateTabCaption(Position)
  If Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  Protected Caption.s
  If Docs()\Path = ""
    Caption = Docs()\UntitledName
  Else
    Caption = GetFilePart(Docs()\Path)
  EndIf
  If Docs()\Modified
    Caption + " *"
  EndIf
  Docs()\DisplayCaption = Caption

  RedrawTabBar()
EndProcedure

; Desenha a tab bar customizada (uma aba "chip" arredondada por documento, com
; botao de fechar embutido) - ver hit-test correspondente no loop de eventos
; principal (#PB_Event_Gadget / #TabBarGadget).
Procedure RedrawTabBar()
  Protected W = GadgetWidth(#TabBarGadget)
  Protected H = GadgetHeight(#TabBarGadget)
  If W <= 0 Or H <= 0 Or Not StartDrawing(CanvasOutput(#TabBarGadget))
    ProcedureReturn
  EndIf

  Box(0, 0, W, H, Color_AppBg)
  DrawingMode(#PB_2DDrawing_Transparent)

  Protected X = 4, Position = 0
  Protected TabW, TextW, AvailTextW, BgColor, TextColor, CloseColor
  Protected Caption.s, DrawCaption.s, CloseX, CloseY

  ForEach Docs()
    Caption = Docs()\DisplayCaption
    TextW = TextWidth(Caption)
    TabW = TextW + 2 * #Tab_PadX + #Tab_CloseSize + #Tab_CloseGap
    If TabW < #Tab_MinWidth : TabW = #Tab_MinWidth : EndIf
    If TabW > #Tab_MaxWidth : TabW = #Tab_MaxWidth : EndIf

    Docs()\TabX1 = X
    Docs()\TabX2 = X + TabW

    If Position = ActiveTabPosition
      BgColor = Color_EditorBg : TextColor = Color_TextActive
    ElseIf Position = HoverTabPosition
      BgColor = Color_TabHover : TextColor = Color_TextActive
    Else
      BgColor = Color_TabInactive : TextColor = Color_TextInactive
    EndIf

    DrawingMode(#PB_2DDrawing_Default)
    If EditorCfg\Style = "Classic"
      Box(X, 6, TabW, H - 6, BgColor)
    Else
      RoundBox(X, 6, TabW, H - 6, 6, 6, BgColor)
    EndIf
    DrawingMode(#PB_2DDrawing_Transparent)

    AvailTextW = TabW - 2 * #Tab_PadX - #Tab_CloseSize - #Tab_CloseGap
    DrawCaption = Caption
    While TextWidth(DrawCaption) > AvailTextW And Len(DrawCaption) > 1
      DrawCaption = Left(DrawCaption, Len(DrawCaption) - 1)
    Wend
    If DrawCaption <> Caption
      DrawCaption = Left(DrawCaption, Len(DrawCaption) - 1) + "…"
    EndIf

    FrontColor(TextColor)
    DrawText(X + #Tab_PadX, (H - TextHeight(DrawCaption)) / 2, DrawCaption)

    CloseX = X + TabW - #Tab_PadX - #Tab_CloseSize
    CloseY = (H - #Tab_CloseSize) / 2 + 3
    Docs()\CloseX1 = CloseX
    Docs()\CloseX2 = CloseX + #Tab_CloseSize

    If Position = HoverCloseTabPosition
      CloseColor = Color_CloseHover
    Else
      CloseColor = TextColor
    EndIf
    FrontColor(CloseColor)
    LineXY(CloseX, CloseY, CloseX + #Tab_CloseSize, CloseY + #Tab_CloseSize)
    LineXY(CloseX, CloseY + #Tab_CloseSize, CloseX + #Tab_CloseSize, CloseY)

    If Position = ActiveTabPosition And TabW > 12
      Box(X + 6, H - 3, TabW - 12, 3, Color_Accent)
    EndIf

    X + TabW + #Tab_Gap
    Position + 1
  Next

  StopDrawing()
EndProcedure

; Desenha a regua de colunas da aba ativa, alinhada pixel a pixel com o texto
; do ScintillaGadget correspondente (mesma largura de caractere, mesma margem,
; mesmo deslocamento de rolagem horizontal) - ver #Event_UpdateUI no loop
; principal, que redesenha isto a cada rolagem/mudanca de caret.
Procedure RedrawRuler()
  Protected Sci = ActiveSciGadget()
  Protected W = GadgetWidth(#RulerGadget)
  Protected H = GadgetHeight(#RulerGadget)
  If W <= 0 Or H <= 0 Or Not StartDrawing(CanvasOutput(#RulerGadget))
    ProcedureReturn
  EndIf

  Box(0, 0, W, H, Color_RulerBg)

  If Sci
    Protected *Zero = UTF8("0")
    Protected CharW = ScintillaSendMessage(Sci, #SCI_TEXTWIDTH, #STYLE_DEFAULT, *Zero)
    FreeMemory(*Zero)
    If CharW <= 0 : CharW = 8 : EndIf

    Protected MarginTotal = ScintillaSendMessage(Sci, #SCI_GETMARGINWIDTHN, 0) + ScintillaSendMessage(Sci, #SCI_GETMARGINWIDTHN, 1) + ScintillaSendMessage(Sci, #SCI_GETMARGINWIDTHN, 2) + ScintillaSendMessage(Sci, #SCI_GETMARGINWIDTHN, 3) + ScintillaSendMessage(Sci, #SCI_GETMARGINWIDTHN, 4)
    Protected XOffset = ScintillaSendMessage(Sci, #SCI_GETXOFFSET)
    Protected FirstColX = MarginTotal - XOffset

    Protected FirstCol = 0
    If FirstColX < 0
      FirstCol = (0 - FirstColX) / CharW
    EndIf

    DrawingMode(#PB_2DDrawing_Transparent)

    Protected Col = FirstCol, X, Label.s
    Repeat
      X = FirstColX + Col * CharW
      If X > W
        Break
      EndIf
      If X >= 0
        If (Col + 1) % 10 = 0
          FrontColor(Color_RulerTick)
          LineXY(X, H - 10, X, H - 1)
          Label = Str(Col + 1)
          FrontColor(Color_RulerText)
          DrawText(X - TextWidth(Label) / 2, 1, Label)
        ElseIf (Col + 1) % 5 = 0
          FrontColor(Color_RulerTick)
          LineXY(X, H - 6, X, H - 1)
        Else
          FrontColor(Color_RulerTick)
          LineXY(X, H - 3, X, H - 1)
        EndIf
      EndIf
      Col + 1
    Until Col > FirstCol + 2000 ; guarda de seguranca (evita loop infinito se CharW ficar 0)
  EndIf

  StopDrawing()
EndProcedure

Procedure OpenDocumentDialog()
  Protected Path.s = OpenFileRequester("Abrir arquivo", "", #File_Pattern, 0)
  If Path = ""
    ProcedureReturn
  EndIf

  Protected Position = 0
  ForEach Docs()
    If Docs()\Path = Path
      SetActiveTab(Position)
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
  Protected Position = ActiveTabPosition
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn #False
  EndIf

  Protected Path.s = Docs()\Path

  If SaveAs Or Path = ""
    Protected Suggestion.s = Path
    If Suggestion = ""
      Suggestion = Docs()\UntitledName + ".dmx"
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

  FreeGadget(Docs()\SciGadget)
  DeleteElement(Docs())

  If ListSize(Docs()) = 0
    AddDocumentTab()
    ProcedureReturn
  EndIf

  Protected NewActive = Position
  If NewActive >= ListSize(Docs())
    NewActive = ListSize(Docs()) - 1
  EndIf
  SetActiveTab(NewActive)
EndProcedure

;- ------------------------------------------------------------
;- Gerar MSX-BASIC tokenizado (.bmx) via o toolchain do Basic Dignified
;- ------------------------------------------------------------

Procedure SaveTokenized()
  Protected Position = ActiveTabPosition
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  ; Garante que o arquivo esteja salvo em disco (com extensao .dmx) e
  ; refletindo o conteudo atual antes de tokenizar.
  If Not SaveDocument(#False)
    ProcedureReturn
  EndIf

  Protected Path.s = Docs()\Path
  Protected BadigRoot.s = BadigCfg\InstallDir + "\"
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
  Protected Position = ActiveTabPosition
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
    Suggestion = Docs()\UntitledName
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

; Copia as configuracoes da tela "Configurar -> Basic Dignified..." (BadigCfg,
; ver editor/BadigSettings.pbi) para os globals Dig_* lidos pelo pre-processador
; nativo (editor/DignifiedPreprocessor.pbi), unificando as duas telas de
; configuracao num so conjunto de opcoes (ver docs/SPEC.md modulo 3e).
Procedure Dig_SyncConfigFromBadigCfg()
  Dig_LineStart = BadigCfg\LineStart
  Dig_LineStep = BadigCfg\LineStep
  Dig_RemHeader = BadigCfg\RemHeader
  Dig_TabLength = BadigCfg\TabLenght
  Dig_StripSpaces = BadigCfg\StripSpaces
  Dig_CapitalizeAll = BadigCfg\CapitalizeAll
  Dig_Translate = BadigCfg\Translate
  Dig_ConvertPrintCfg = BadigCfg\ConvertPrint
  Dig_StripThenGotoCfg = BadigCfg\StripThenGoto
EndProcedure

; Roda o pre-processador Dignified nativo (DignifiedPreprocessor.pbi) sobre o
; conteudo da aba atual e devolve o texto ASCII classico resultante, ou ""
; em erro (mostrando o dialogo de erro). Usado pelas duas procedures abaixo.
Procedure.s RunDignifiedPreprocessor()
  Dig_SyncConfigFromBadigCfg()
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
  Protected Position = ActiveTabPosition
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  Protected AsciiOut.s = RunDignifiedPreprocessor()
  If AsciiOut = ""
    ProcedureReturn
  EndIf

  Protected Suggestion.s = Docs()\Path
  If Suggestion = ""
    Suggestion = Docs()\UntitledName
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
  Protected Position = ActiveTabPosition
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
    Suggestion = Docs()\UntitledName
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
  Protected FullW = WindowWidth(#MainWindow)
  Protected FullH = WindowHeight(#MainWindow) - StatusBarHeight(#MainStatusBar)
  If FullH < 0 : FullH = 0 : EndIf

  ResizeGadget(#TabBarGadget, 0, 0, FullW, #TabBar_Height)
  ResizeGadget(#RulerGadget, 0, #TabBar_Height, FullW, #Ruler_Height)

  Protected InnerH = FullH - #TabBar_Height - #Ruler_Height
  If InnerH < 0 : InnerH = 0 : EndIf

  ForEach Docs()
    ResizeGadget(Docs()\SciGadget, 0, #TabBar_Height + #Ruler_Height, FullW, InnerH)
  Next

  RedrawTabBar()
  RedrawRuler()
EndProcedure

;- ------------------------------------------------------------
;- Programa principal
;- ------------------------------------------------------------

InitKeywordMaps()
EditorCfg_Load()
EditorCfg_LoadCustomFonts()
ApplyTheme()
BadigCfg_Load()

If Not OpenWindow(#MainWindow, 0, 0, 1000, 700, #App_Title, #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget | #PB_Window_MinimizeGadget | #PB_Window_MaximizeGadget)
  End
EndIf
SetWindowColor(#MainWindow, Color_AppBg)

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
    MenuItem(#Menu_ConfigureEditor, "Editor...")

AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_N, #Menu_New)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_O, #Menu_Open)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_S, #Menu_Save)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_Shift | #PB_Shortcut_S, #Menu_SaveAs)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_W, #Menu_CloseTab)

CanvasGadget(#TabBarGadget, 0, 0, WindowWidth(#MainWindow), #TabBar_Height)
CanvasGadget(#RulerGadget, 0, #TabBar_Height, WindowWidth(#MainWindow), #Ruler_Height)

CreateStatusBar(#MainStatusBar, WindowID(#MainWindow))
  AddStatusBarField(#PB_Ignore)

AddDocumentTab()
ResizeInterface()

Define Event, Quit, Position, AllSaved, Discard, ChangedGadget, DocPos
Define MouseX, MouseY, HitPos, NewHoverTab, NewHoverClose

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
          CloseTab(ActiveTabPosition)

        Case #Menu_Exit
          Quit = 1

        Case #Menu_ConfigureBadig
          BadigCfg_OpenSettingsWindow(#MainWindow)

        Case #Menu_ConfigureEditor
          If EditorCfg_OpenSettingsWindow(#MainWindow)
            ApplyTheme()
            SetWindowColor(#MainWindow, Color_AppBg)
            ForEach Docs()
              SetupEditorStyles(Docs()\SciGadget)
              HighlightDocument(Docs()\SciGadget)
            Next
            ResizeInterface()
          EndIf
      EndSelect

    Case #PB_Event_Gadget
      Select EventGadget()
        Case #TabBarGadget
          Select EventType()
            Case #PB_EventType_LeftButtonDown
              MouseX = GetGadgetAttribute(#TabBarGadget, #PB_Canvas_MouseX)
              MouseY = GetGadgetAttribute(#TabBarGadget, #PB_Canvas_MouseY)
              HitPos = 0
              ForEach Docs()
                If MouseX >= Docs()\TabX1 And MouseX < Docs()\TabX2
                  If MouseX >= Docs()\CloseX1 - 4 And MouseX <= Docs()\CloseX2 + 4 And MouseY >= 4 And MouseY <= #TabBar_Height - 4
                    CloseTab(HitPos)
                  Else
                    SetActiveTab(HitPos)
                  EndIf
                  Break
                EndIf
                HitPos + 1
              Next

            Case #PB_EventType_MouseMove
              MouseX = GetGadgetAttribute(#TabBarGadget, #PB_Canvas_MouseX)
              MouseY = GetGadgetAttribute(#TabBarGadget, #PB_Canvas_MouseY)
              NewHoverTab = -1
              NewHoverClose = -1
              HitPos = 0
              ForEach Docs()
                If MouseX >= Docs()\TabX1 And MouseX < Docs()\TabX2
                  NewHoverTab = HitPos
                  If MouseX >= Docs()\CloseX1 - 4 And MouseX <= Docs()\CloseX2 + 4
                    NewHoverClose = HitPos
                  EndIf
                  Break
                EndIf
                HitPos + 1
              Next
              If NewHoverTab <> HoverTabPosition Or NewHoverClose <> HoverCloseTabPosition
                HoverTabPosition = NewHoverTab
                HoverCloseTabPosition = NewHoverClose
                RedrawTabBar()
              EndIf

            Case #PB_EventType_MouseLeave
              If HoverTabPosition <> -1 Or HoverCloseTabPosition <> -1
                HoverTabPosition = -1
                HoverCloseTabPosition = -1
                RedrawTabBar()
              EndIf
          EndSelect
      EndSelect

    Case #PB_Event_CloseWindow
      Quit = 1

    Case #PB_Event_SizeWindow
      ResizeInterface()

    Case #Event_UpdateUI
      ChangedGadget = EventGadget()
      If ChangedGadget = ActiveSciGadget()
        UpdateLineNumberMargin(ChangedGadget)
        RedrawRuler()
      EndIf

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
