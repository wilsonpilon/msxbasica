;
; ------------------------------------------------------------
;  Basic Dignified Editor
;  Editor de codigos para o dialeto MSX-BASIC do Basic Dignified Suite.
;  Escrito em PureBasic (Windows / Linux).
;  Realce de sintaxe via ScintillaGadget e pre-processador/tokenizador
;  Basic Dignified nativos (sem Python) em DignifiedPreprocessor.pbi/
;  MsxTokenizer.pbi.
; ------------------------------------------------------------
;

EnableExplicit

; Referenciada em EditorSettings.pbi (botao "Baixar fontes...") mas definida em
; FontDownloader.pbi, que precisa vir depois (usa EditorCfg_NormalizeDir e
; BadigCfg_ExtractZip) - forward declaration para quebrar a dependencia circular.
Declare.s FontDownloader_OpenWindow(ParentWindow, InitialFolder.s)

XIncludeFile "MsxTokenizer.pbi"
XIncludeFile "DignifiedPreprocessor.pbi"
XIncludeFile "EditorSettings.pbi"
XIncludeFile "BadigSettings.pbi"
XIncludeFile "FontDownloader.pbi"
XIncludeFile "MSXDisk.pbi"

;- ------------------------------------------------------------
;- Constantes gerais
;- ------------------------------------------------------------

Enumeration Windows
  #MainWindow
EndEnumeration

Enumeration Gadgets
  #TabBarGadget
  #RulerGadget
  #HelpGadget      ; ver WordStarKeys.pbi (Ctrl+K H) - ocupa o lugar do Scintilla ativo
EndEnumeration

Enumeration StatusBars
  #MainStatusBar
EndEnumeration

Enumeration Menus
  #MainMenu
EndEnumeration

Enumeration MenuItems
  #Menu_New
  #Menu_NewAssembly
  #Menu_Open
  #Menu_Save
  #Menu_SaveAs
  #Menu_TokenizeNative
  #Menu_DignifiedToAscii
  #Menu_DignifiedToTokenized
  #Menu_CloseTab
  #Menu_Exit
  #Menu_RunBasic
  #Menu_ConfigureBadig
  #Menu_ConfigureEditor
  #Menu_HelpCommands
  #Menu_HelpAbout
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
; Usado por WordStarKeys.pbi (^KX/^KQ) para adiar o fechamento da aba ativa -
; ver comentario no proprio arquivo.
#Event_WS_CloseTab = #PB_Event_FirstCustomValue + 2

#App_Title      = "Basic Dignified Editor"
#File_Pattern     = "MSX-BASIC Dignified (*.dmx)|*.dmx|MSX Basic ASCII (*.amx)|*.amx|Todos os arquivos (*.*)|*.*"
#File_Pattern_ASM = "Z80 Assembly (*.asm)|*.asm|Todos os arquivos (*.*)|*.*"
#File_Pattern_Open = "Todos os suportados (*.dmx;*.amx;*.asm)|*.dmx;*.amx;*.asm|" +
                     "MSX-BASIC Dignified (*.dmx)|*.dmx|MSX Basic ASCII (*.amx)|*.amx|" +
                     "Z80 Assembly (*.asm)|*.asm|Todos os arquivos (*.*)|*.*"

; Versao/build normalmente injetadas via build.ps1 (/CONSTANT App_Version=...,
; -Version/-BuildDate) - fallback aqui so para compilar direto pela IDE do
; PureBasic (F5), fora do build.ps1.
CompilerIf Not Defined(App_Version, #PB_Constant)
  #App_Version = "5.3.1"
CompilerEndIf
CompilerIf Not Defined(App_Build, #PB_Constant)
  #App_Build = "DEV"
CompilerEndIf
CompilerIf Not Defined(App_BuildDate, #PB_Constant)
  #App_BuildDate = "compilado fora do build.ps1"
CompilerEndIf

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
  Mode.s            ; "DMX" (MSX-BASIC/Dignified, default) ou "ASM" (Z80 Assembly)
  Modified.b        ; 1 se ha alteracoes nao salvas
  SciGadget.i       ; ScintillaGadget associado a esta aba
  UntitledName.s    ; nome estavel ("Sem titulo N"), so usado enquanto Path = ""
  DisplayCaption.s  ; rotulo ja computado (nome + " *" se modificado), cache para RedrawTabBar
  TabX1.i           ; retangulo da aba inteira na tab bar (hit-test de clique/hover)
  TabX2.i
  CloseX1.i         ; retangulo do botao "x" de fechar, dentro da aba
  CloseX2.i
  MarkBegin.i       ; posicao (bytes) do bloco marcado no estilo WordStar/JOE
  MarkEnd.i         ; (^KB/^KK, ver WordStarKeys.pbi) - -1 quando nao ha marca
EndStructure

Global NewList Docs.Document()
Global UntitledCount = 0
Global ActiveTabPosition.i = -1
Global HoverTabPosition.i = -1
Global HoverCloseTabPosition.i = -1

; Estado do teclado WordStar/JOE (ver WordStarKeys.pbi) - declarados aqui (e
; nao no proprio WordStarKeys.pbi, incluido so no fim do arquivo) porque
; UpdateStatusBar() [abaixo] precisa deles e e definida bem antes disso.
Global WS_ChordPrefix.i = 0      ; 0 = nenhum, Asc("K")/Asc("Q") = prefixo pendente
Global WS_SwallowChar.b = #False ; engole o proximo WM_CHAR (par do WM_KEYDOWN ja tratado)

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

; Tabelas do lexer de Z80 Assembly (modo "ASM" dos documentos) - vocabulario
; do dialeto N80/Nestor80 (Konamiman, compativel com MACRO-80), ver
; InitZ80KeywordMaps() e docs/SPEC.md.
Global NewMap KwZ80Mnemonic.b()
Global NewMap KwZ80Register.b()
Global NewMap KwZ80Directive.b()
Global NewMap KwZ80Operator.b()

;- ------------------------------------------------------------
;- Declaracoes
;- ------------------------------------------------------------

Declare   FillKeywordMap(Map Dest.b(), Words.s)
Declare   InitKeywordMaps()
Declare   InitZ80KeywordMaps()
Declare.s ReadSciText(Sci)
Declare   WriteSciText(Sci, Text.s)
Declare   EmitRun(Sci, Text.s, Style)
Declare.b IsAlphaChar(C.s)
Declare.b IsDigitChar(C.s)
Declare.b IsWordChar(C.s)
Declare   HighlightDocument(Sci)
Declare   HighlightDignifiedText(Sci, Text.s)
Declare   HighlightZ80Text(Sci, Text.s)
Declare   SetupEditorStyles(Sci)
Declare   UpdateLineNumberMargin(Sci)
Declare   ActiveSciGadget()
Declare   UpdateStatusBar()
Declare   ScintillaCallBack(Gadget, *scinotify.SCNotification)
Declare   WS_AttachSubclass(Sci)   ; WordStarKeys.pbi (incluido no fim do arquivo)
Declare   WS_SetupIndicator(Sci)
Declare   WS_CreateHelpGadget()
Declare   WS_SetupHelpStyles()
Declare   WS_ShowHelp()
Declare.s ComputeTabCaption(Position)
Declare   RedrawTabBar()
Declare   RedrawRuler()
Declare   SetActiveTab(Position)
Declare   AddDocumentTab(Path.s = "", Content.s = "", Mode.s = "DMX")
Declare   FindDocumentByGadget(GadgetNum)
Declare   UpdateTabCaption(Position)
Declare   OpenDocumentDialog()
Declare.b SaveDocument(SaveAs.b = #False)
Declare.b ConfirmDiscard(Text.s)
Declare   CloseTab(Position)
Declare   SaveAsTokenizedNative()
Declare   SaveAsAsciiFromDignified()
Declare   SaveAsTokenizedFromDignified()
Declare   RunOnOpenMSX(BaseName.s, DmxText.s, AsciiText.s, HexOut.s)
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
;- Palavras-chave do Z80 Assembly (dialeto N80/Nestor80, Konamiman -
;- https://github.com/Konamiman/Nestor80 - assembler compativel com
;- MACRO-80). Usadas so pelo lexer de arquivos .asm (modo "ASM" dos
;- documentos, ver HighlightZ80Text()).
;- ------------------------------------------------------------

Procedure InitZ80KeywordMaps()
  ; Mnemonicos Z80 (documentados + indocumentados de uso comum, ex. SLL)
  FillKeywordMap(KwZ80Mnemonic(),
    "ADC ADD AND BIT CALL CCF CP CPD CPDR CPI CPIR CPL DAA DEC DI DJNZ EI EX " +
    "EXX HALT IM IN INC IND INDR INI INIR JP JR LD LDD LDDR LDI LDIR NEG NOP " +
    "OR OTDR OTIR OUT OUTD OUTI POP PUSH RES RET RETI RETN RL RLA RLC RLCA " +
    "RLD RR RRA RRC RRCA RRD RST SBC SCF SET SLA SLL SRA SRL SUB XOR")

  ; Registradores e codigos de condicao de desvio (NZ/Z/NC/C/PO/PE/P/M) -
  ; tratados com o mesmo estilo (ambos sao "operandos de hardware")
  FillKeywordMap(KwZ80Register(),
    "A B C D E H L I R IX IY SP AF BC DE HL PC IXH IXL IYH IYL NZ Z NC PO PE P M")

  ; Diretivas do assembler - inclui as com "." do dialeto N80 (RADIX/PHASE/
  ; etc guardadas SEM o ponto aqui; o "." e reconhecido a parte no lexer,
  ; ver Z80_ScanDotWord() dentro de HighlightZ80Text)
  FillKeywordMap(KwZ80Directive(),
    "EQU DEFL ASET ORG DEFB DB DEFM DEFW DW DEFS DS DEFZ DZ INCBIN PUBLIC " +
    "ENTRY GLOBAL EXTRN EXT EXTERNAL ROOT IF IFT COND IFF IFE IF1 IF2 IFABS " +
    "IFREL IFDEF IFNDEF IFB IFNB IFIDN IFIDNI IFDIF IFDIFI IFCPU IFNCPU ELSE " +
    "ENDIF MACRO ENDM REPT IRP IRPC IRPS LOCAL EXITM CONTM MODULE ENDMOD " +
    "ASEG CSEG DSEG COMMON AREA TITLE SUBTTL PAGE MAINPAGE END ENDOUT " +
    "RELAB XRELAB EXTROOT XEXTROOT PHASE DEPHASE LIST XLIST LALL SALL XALL " +
    "LFCOND SFCOND TFCOND CPU Z80 STRENC STRESC PRINT PRINT1 PRINT2 PRINTX " +
    "WARN ERROR FATAL REQUEST RADIX ALIGN COMMENT CREF XCREF")

  ; Operadores por extenso usados em expressoes (AND/OR/XOR/NOT ficam de fora
  ; daqui de proposito - ja sao reconhecidos como mnemonicos acima, e o
  ; destaque visual e o mesmo nos dois usos)
  FillKeywordMap(KwZ80Operator(), "LOW HIGH MOD SHR SHL EQ NE NEQ LT LE LTE GT GE GTE NUL TYPE")
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

; Despacha para o lexer certo conforme o modo do documento dono deste
; ScintillaGadget ("DMX" = MSX-BASIC/Dignified, "ASM" = Z80 Assembly) -
; margem de numeros de linha e regua sao independentes de modo, ficam aqui.
Procedure HighlightDocument(Sci)
  Protected Text.s = ReadSciText(Sci)

  UpdateLineNumberMargin(Sci)
  If Sci = ActiveSciGadget()
    RedrawRuler()
  EndIf

  If Len(Text) = 0
    ProcedureReturn
  EndIf

  Protected DocPos = FindDocumentByGadget(Sci)
  Protected Mode.s = "DMX"
  If DocPos >= 0 And SelectElement(Docs(), DocPos)
    Mode = Docs()\Mode
  EndIf

  If Mode = "ASM"
    HighlightZ80Text(Sci, Text)
  Else
    HighlightDignifiedText(Sci, Text)
  EndIf
EndProcedure

Procedure HighlightDignifiedText(Sci, Text.s)
  Protected TextLen = Len(Text)
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
;- Realce de sintaxe - Z80 Assembly (dialeto N80/Nestor80)
;-
;- Estilos reaproveitados do modo Dignified (mesma paleta, sem globals
;- novos): #Style_Comment (";"), #Style_String ('..'/".."), #Style_Statement
;- (mnemonicos), #Style_Function (registradores/condicoes), #Style_Number
;- (literais numericos em qualquer radix), #Style_Label (rotulos e rotulos
;- relativos ".nome"), #Style_DignifiedStmt (diretivas do assembler,
;- reaproveitado aqui como estilo generico de "diretiva"), #Style_Operator
;- (operadores por extenso e simbolos).
;-
;- Regra de rotulo vs. mnemonico/diretiva na 1a palavra da linha: se a
;- palavra bate com alguma tabela de palavra-chave (diretiva/mnemonico/
;- registrador/operador), usa o estilo correspondente ONDE QUER que apareca
;- na linha; só cai para "rotulo" quando e a PRIMEIRA palavra da linha E nao
;- bate com nenhuma tabela - mesma convencao classica MACRO-80/Z80 (rotulo
;- sem dois-pontos e reconhecido por nao ser palavra reservada, nao por
;- coluna). Cobre tanto "LABEL: LD A,1" quanto "CONST EQU 5" quanto "ORG
;- 100H" (ORG e diretiva conhecida, nao vira rotulo mesmo comecando a linha).
;-
;- Escopo nao coberto (limitacoes conhecidas, aceitas por simplicidade):
;- bloco ".COMMENT <delim>...<delim>" com delimitador arbitrario (so o
;- comentario de linha ";" e reconhecido); precisao total de qual sufixo de
;- radix fecha um literal numerico multi-digito (visualmente inofensivo -
;- o token inteiro ainda e destacado como numero, so a fronteira exata entre
;- "digitos" e "sufixo" internamente pode variar).
;- ------------------------------------------------------------

Procedure.b Z80_IsWordStartChar(C.s)
  ProcedureReturn Bool(IsAlphaChar(C) Or C = "?" Or C = "@" Or C = "_")
EndProcedure

Procedure.b Z80_IsWordChar(C.s)
  ProcedureReturn Bool(IsWordChar(C) Or C = "?" Or C = "@" Or C = "$" Or C = ".")
EndProcedure

Procedure HighlightZ80Text(Sci, Text.s)
  Protected TextLen = Len(Text)
  Protected I = 1
  Protected AtLineStart.b = #True
  Protected C.s, C2.s, Start, Word.s, CommentLen

  ScintillaSendMessage(Sci, #SCI_STARTSTYLING, 0, 0)

  While I <= TextLen
    C = Mid(Text, I, 1)

    ; --- Fim de linha ---
    If C = Chr(13) Or C = Chr(10)
      EmitRun(Sci, C, #Style_Default)
      I + 1
      AtLineStart = #True
      Continue
    EndIf

    ; --- Espaco/tab no inicio da linha nao conta como token real ---
    If AtLineStart And (C = " " Or C = Chr(9))
      EmitRun(Sci, C, #Style_Default)
      I + 1
      Continue
    EndIf

    ; --- Comentario ; ate o final da linha ---
    If C = ";"
      CommentLen = 0
      While I + CommentLen <= TextLen And Mid(Text, I + CommentLen, 1) <> Chr(13) And Mid(Text, I + CommentLen, 1) <> Chr(10)
        CommentLen + 1
      Wend
      EmitRun(Sci, Mid(Text, I, CommentLen), #Style_Comment)
      I + CommentLen
      AtLineStart = #False
      Continue
    EndIf

    ; --- Literais de string "..." (com escapes \" e \\) ---
    If C = Chr(34)
      Start = I
      I + 1
      While I <= TextLen And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        If Mid(Text, I, 1) = "\" And I < TextLen
          I + 2
          Continue
        EndIf
        If Mid(Text, I, 1) = Chr(34)
          I + 1
          Break
        EndIf
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_String)
      AtLineStart = #False
      Continue
    EndIf

    ; --- Literais de string/char '...' (aspa simples dobrada '' = escapada) ---
    If C = "'"
      Start = I
      I + 1
      While I <= TextLen And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        If Mid(Text, I, 1) = "'"
          If I < TextLen And Mid(Text, I + 1, 1) = "'"
            I + 2
            Continue
          EndIf
          I + 1
          Break
        EndIf
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_String)
      AtLineStart = #False
      Continue
    EndIf

    ; --- Hex entre aspas simples: X'1A2B' / x'1a2b' ---
    If (C = "X" Or C = "x") And I < TextLen And Mid(Text, I + 1, 1) = "'"
      Start = I
      I + 2
      While I <= TextLen And Mid(Text, I, 1) <> "'" And Mid(Text, I, 1) <> Chr(13) And Mid(Text, I, 1) <> Chr(10)
        I + 1
      Wend
      If I <= TextLen And Mid(Text, I, 1) = "'"
        I + 1
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
      AtLineStart = #False
      Continue
    EndIf

    ; --- Prefixos numericos 0x.. (hex) e 0b.. (binario) ---
    If C = "0" And I < TextLen And (UCase(Mid(Text, I + 1, 1)) = "X" Or UCase(Mid(Text, I + 1, 1)) = "B")
      Start = I
      I + 2
      While I <= TextLen And Z80_IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
      AtLineStart = #False
      Continue
    EndIf

    ; --- Hex prefixado com # (#1A2B) ---
    If C = "#" And I < TextLen And IsWordChar(Mid(Text, I + 1, 1))
      Start = I
      I + 1
      While I <= TextLen And Z80_IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
      AtLineStart = #False
      Continue
    EndIf

    ; --- Numeros: digitos + letras hex A-F, sufixo de radix opcional
    ; (B/I/D/M/O/Q/H) - ver nota de escopo no cabecalho desta procedure ---
    If IsDigitChar(C)
      Start = I
      While I <= TextLen And (IsDigitChar(Mid(Text, I, 1)) Or (UCase(Mid(Text, I, 1)) >= "A" And UCase(Mid(Text, I, 1)) <= "F"))
        I + 1
      Wend
      If I <= TextLen
        C2 = UCase(Mid(Text, I, 1))
        If C2 = "B" Or C2 = "I" Or C2 = "D" Or C2 = "M" Or C2 = "O" Or C2 = "Q" Or C2 = "H"
          I + 1
        EndIf
      EndIf
      EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Number)
      AtLineStart = #False
      Continue
    EndIf

    ; --- "$" isolado = endereco/posicao atual (nao colado a um identificador) ---
    If C = "$" And (I = TextLen Or Not IsWordChar(Mid(Text, I + 1, 1)))
      EmitRun(Sci, C, #Style_Number)
      I + 1
      AtLineStart = #False
      Continue
    EndIf

    ; --- Diretiva com ponto (.RADIX, .PHASE, ...) ou rotulo relativo (.nome) ---
    If C = "." And I < TextLen And Z80_IsWordStartChar(Mid(Text, I + 1, 1))
      Start = I
      I + 1
      While I <= TextLen And Z80_IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      Word = UCase(Mid(Text, Start + 1, I - Start - 1))
      If FindMapElement(KwZ80Directive(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_DignifiedStmt)
      Else
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
      EndIf
      AtLineStart = #False
      Continue
    EndIf

    ; --- Identificadores / mnemonicos / registradores / diretivas / rotulos ---
    If Z80_IsWordStartChar(C)
      Start = I
      I + 1
      While I <= TextLen And Z80_IsWordChar(Mid(Text, I, 1))
        I + 1
      Wend
      Word = UCase(Mid(Text, Start, I - Start))

      ; "AF'" (par de registrador sombra) - inclui o apostrofo no token
      If Word = "AF" And I <= TextLen And Mid(Text, I, 1) = "'"
        I + 1
      EndIf

      If FindMapElement(KwZ80Directive(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_DignifiedStmt)
      ElseIf FindMapElement(KwZ80Mnemonic(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Statement)
      ElseIf FindMapElement(KwZ80Register(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Function)
      ElseIf FindMapElement(KwZ80Operator(), Word)
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Operator)
      ElseIf AtLineStart
        ; primeira palavra da linha, nao e palavra reservada -> rotulo
        ; (consome ":" ou "::" final, se houver)
        If I <= TextLen And Mid(Text, I, 1) = ":"
          I + 1
          If I <= TextLen And Mid(Text, I, 1) = ":"
            I + 1
          EndIf
        EndIf
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Label)
      Else
        EmitRun(Sci, Mid(Text, Start, I - Start), #Style_Default)
      EndIf
      AtLineStart = #False
      Continue
    EndIf

    ; --- Operadores/simbolos ---
    If C = "+" Or C = "-" Or C = "*" Or C = "/" Or C = "=" Or C = "<" Or C = ">" Or
       C = ":" Or C = "," Or C = "(" Or C = ")" Or C = "!" Or C = "%" Or C = "&"
      EmitRun(Sci, C, #Style_Operator)
      I + 1
      AtLineStart = #False
      Continue
    EndIf

    ; --- Qualquer outro caractere (espacos no meio da linha, etc) ---
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

  WS_SetupIndicator(Sci)
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
  UpdateStatusBar()
EndProcedure

Procedure AddDocumentTab(Path.s = "", Content.s = "", Mode.s = "DMX")
  Protected InnerW, InnerH, Sci

  InnerW = GadgetWidth(#RulerGadget)
  InnerH = WindowHeight(#MainWindow) - StatusBarHeight(#MainStatusBar) - #TabBar_Height - #Ruler_Height
  If InnerW <= 0 : InnerW = WindowWidth(#MainWindow) : EndIf
  If InnerH <= 0 : InnerH = 200 : EndIf

  Sci = ScintillaGadget(#PB_Any, 0, #TabBar_Height + #Ruler_Height, InnerW, InnerH, @ScintillaCallBack())
  SetupEditorStyles(Sci)
  WS_AttachSubclass(Sci)

  ; Se Path foi informado (abrindo um arquivo existente), o modo e detectado
  ; pela extensao, ignorando o parametro Mode (que so vale para "Novo"/"Novo
  ; Assembly", quando ainda nao ha arquivo em disco).
  Protected DocMode.s = Mode
  If Path <> ""
    Select LCase(GetExtensionPart(Path))
      Case "asm", "z80", "mac"
        DocMode = "ASM"
      Default
        DocMode = "DMX"
    EndSelect
  EndIf

  AddElement(Docs())
  Docs()\Path      = Path
  Docs()\Mode      = DocMode
  Docs()\Modified  = #False
  Docs()\SciGadget = Sci
  Docs()\MarkBegin = -1
  Docs()\MarkEnd   = -1

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

; Atualiza a barra de status (rodape): campo 0 = modo (INS/SBR) ou prefixo de
; comando WordStar pendente (^K/^Q, ver WordStarKeys.pbi); campo 1 = nome do
; arquivo da aba ativa; campo 2 = linha/coluna do cursor.
Procedure UpdateStatusBar()
  Protected ModeText.s = "", NameText.s = "", PosText.s = ""

  If WS_ChordPrefix <> 0
    ModeText = "^" + Chr(WS_ChordPrefix)
  Else
    Protected Sci = ActiveSciGadget()
    If Sci
      If ScintillaSendMessage(Sci, #SCI_GETOVERTYPE)
        ModeText = "SBR"
      Else
        ModeText = "INS"
      EndIf
    EndIf
  EndIf

  If ActiveTabPosition >= 0 And SelectElement(Docs(), ActiveTabPosition)
    NameText = Docs()\DisplayCaption
    Protected Sci2 = Docs()\SciGadget
    Protected Pos = ScintillaSendMessage(Sci2, #SCI_GETCURRENTPOS)
    Protected Line = ScintillaSendMessage(Sci2, #SCI_LINEFROMPOSITION, Pos) + 1
    Protected Col = ScintillaSendMessage(Sci2, #SCI_GETCOLUMN, Pos) + 1
    PosText = "Lin " + Str(Line) + ", Col " + Str(Col)
  EndIf

  StatusBarText(#MainStatusBar, 0, ModeText)
  StatusBarText(#MainStatusBar, 1, NameText)
  StatusBarText(#MainStatusBar, 2, PosText, #PB_StatusBar_Right)
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
  UpdateStatusBar()
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
  Protected Path.s = OpenFileRequester("Abrir arquivo", "", #File_Pattern_Open, 0)
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
  Protected DefaultExt.s = ".dmx"
  Protected Pattern.s = #File_Pattern
  If Docs()\Mode = "ASM"
    DefaultExt = ".asm"
    Pattern = #File_Pattern_ASM
  EndIf

  If SaveAs Or Path = ""
    Protected Suggestion.s = Path
    If Suggestion = ""
      Suggestion = Docs()\UntitledName + DefaultExt
    EndIf
    Protected NewPath.s = SaveFileRequester("Salvar como", Suggestion, Pattern, 0)
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

; Versao/build/data sao constantes de compilacao injetadas pelo build.ps1
; (via /CONSTANT) - ver fallback no topo do arquivo para compilacao direto
; pela IDE do PureBasic.
Procedure ShowAboutDialog()
  Protected Text.s = #App_Title + Chr(10) + Chr(10) +
    "Versao: " + #App_Version + Chr(10) +
    "Build: " + #App_Build + Chr(10) +
    "Data: " + #App_BuildDate + Chr(10) + Chr(10) +
    "(C) " + Str(Year(Date())) + " Wilson Pilon"

  MessageRequester("Sobre", Text, #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
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
  Protected BasePath.s = ""
  If Docs()\Path <> ""
    BasePath = GetPathPart(Docs()\Path)
  EndIf
  Protected AsciiOut.s = Dig_Preprocess(SourceText, BasePath)

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
  If Dig_ExportFileOverride <> ""
    ; remtag ##BB:export_file=... da linha fonte - so preenche a sugestao,
    ; usuario ainda confirma/troca no dialogo de salvar
    Suggestion = Dig_ExportFileOverride
  EndIf

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
  If Dig_ExportFileOverride <> ""
    Suggestion = Dig_ExportFileOverride
  EndIf

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

  If BadigCfg\EmRun
    Protected DmxSource.s = ReadSciText(Docs()\SciGadget)
    Protected BaseName.s = GetFilePart(SavePath, #PB_FileSystem_NoExtension)
    RunOnOpenMSX(BaseName, DmxSource, AsciiOut, HexOut)
  EndIf
EndProcedure

; Menu "Executar -> BASIC" (F5): preprocessa (Dignified -> ASCII), tokeniza e
; manda direto para RunOnOpenMSX() - mesmo pipeline final de
; SaveAsTokenizedFromDignified() quando "Abrir o openMSX e rodar o codigo
; apos gerar" esta marcado, so que aqui e sempre (acao explicita de "rodar",
; sem depender do checkbox EmRun nem passar pelo dialogo de Salvar Como).
Procedure RunBasicFromActiveTab()
  Protected Position = ActiveTabPosition
  If Position < 0 Or Not SelectElement(Docs(), Position)
    ProcedureReturn
  EndIf

  If Docs()\Mode = "ASM"
    MessageRequester("Executar -> BASIC",
                     "A aba ativa e Assembly (.asm), nao MSX-BASIC/Dignified." + Chr(10) +
                     "Executar Assembly ainda nao e suportado.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
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
  Protected BaseName.s = GetFilePart(Suggestion, #PB_FileSystem_NoExtension)

  Protected DmxSource.s = ReadSciText(Docs()\SciGadget)
  RunOnOpenMSX(BaseName, DmxSource, AsciiOut, HexOut)
EndProcedure

;- ------------------------------------------------------------
;- Rodar no openMSX: monta um disquete .dsk com o .dmx/.amx/.bmx
;- gerados e abre o openMSX ja com esse disco montado (menu "Dignified
;- -> tokenizado nativo...", quando "Abrir o openMSX e rodar o codigo
;- apos gerar" esta marcado nas configuracoes). Rotinas de disco
;- vendorizadas de msxDiskUtil (MSXDisk.pbi, modulo MSXDisk) - nada de
;- subprocess externo para montar o .dsk, so para abrir o proprio
;- openMSX (unico subprocess desta funcao, e nao tem como no PC rodar
;- o programa MSX de outro jeito).
;- ------------------------------------------------------------

; Diretorio "disk" irmao da pasta do editor (mesma convencao do default de
; InstallDir, "..\badig" - ver BadigCfg_DefaultInstallDir()) - area de
; trabalho onde o disquete de execucao e montado a cada "rodar no openMSX".
Procedure.s RunOnOpenMSX_DiskDir()
  Protected Dir.s = GetPathPart(ProgramFilename()) + "..\disk\"
  If FileSize(Dir) <> -2
    CreateDirectory(Dir)
  EndIf
  ProcedureReturn Dir
EndProcedure

; Apaga o conteudo de DiskDir antes de montar um disco novo - sem isso, cada
; "Executar" com um BaseName diferente (outro projeto/arquivo) so acumulava
; .dmx/.amx/.bmx/autoexec.bas de execucoes anteriores na mesma pasta (o
; MSXDisk::CreateDisk() sobrescreve o run.dsk, mas os arquivos LOCAIS soltos
; ao lado ficavam para tras). So arquivos (nao entra em subpastas).
Procedure ClearDiskDir(Dir.s)
  Protected d = ExamineDirectory(#PB_Any, Dir, "*.*")
  If Not d : ProcedureReturn : EndIf
  While NextDirectoryEntry(d)
    If DirectoryEntryType(d) = #PB_DirectoryEntry_File
      DeleteFile(Dir + DirectoryEntryName(d))
    EndIf
  Wend
  FinishDirectory(d)
EndProcedure

Procedure RunOnOpenMSX(BaseName.s, DmxText.s, AsciiText.s, HexOut.s)
  If BadigCfg\EmulatorPath = ""
    MessageRequester("openMSX nao configurado",
                     "Configure o caminho do executavel do openMSX em" + Chr(10) +
                     "Configurar -> Basic Dignified... -> aba Emulador.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected DiskDir.s = RunOnOpenMSX_DiskDir()
  If FileSize(DiskDir) <> -2
    MessageRequester("Erro", "Nao foi possivel criar o diretorio:" + Chr(10) + DiskDir,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  ClearDiskDir(DiskDir)

  Protected UBase.s = UCase(BaseName)

  Protected DmxLocal.s = DiskDir + BaseName + ".dmx"
  Protected AmxLocal.s = DiskDir + BaseName + ".amx"
  Protected BmxLocal.s = DiskDir + BaseName + ".bmx"
  Protected AutoexecLocal.s = DiskDir + "autoexec.bas"

  Protected f
  f = CreateFile(#PB_Any, DmxLocal)
  If f : WriteString(f, DmxText) : CloseFile(f) : EndIf
  f = CreateFile(#PB_Any, AmxLocal)
  If f : WriteString(f, AsciiText) : CloseFile(f) : EndIf
  If Not Tok_SaveHexAsBinary(HexOut, BmxLocal)
    MessageRequester("Erro", "Nao foi possivel gravar:" + Chr(10) + BmxLocal,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  ; AUTOEXEC.BAS - convencao do MSX-BASIC/MSX-DOS: se esse arquivo existir no
  ; disco de boot, e carregado e rodado automaticamente ao ligar/reiniciar -
  ; aqui so encaminha para o .BMX que acabou de ser gerado.
  f = CreateFile(#PB_Any, AutoexecLocal)
  If f : WriteString(f, "10 RUN " + Chr(34) + UBase + ".BMX" + Chr(34) + Chr(13) + Chr(10)) : CloseFile(f) : EndIf

  ; MSX-DOS/FAT12 e 8.3 - nomes de arquivo maiores que 8 caracteres sao
  ; truncados automaticamente por MSXDisk::ConvertToFAT11() ao adicionar.
  Protected DiskPath.s = DiskDir + "run.dsk"
  If Not MSXDisk::CreateDisk(DiskPath)
    MessageRequester("Erro ao criar o disco", MSXDisk::GetLastErrorMessage(),
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected Ok.b = #True
  If Ok : Ok = MSXDisk::AddFile(DmxLocal, UBase + ".DMX") : EndIf
  If Ok : Ok = MSXDisk::AddFile(AmxLocal, UBase + ".AMX") : EndIf
  If Ok : Ok = MSXDisk::AddFile(BmxLocal, UBase + ".BMX") : EndIf
  If Ok : Ok = MSXDisk::AddFile(AutoexecLocal, "AUTOEXEC.BAS") : EndIf
  Protected DiskErr.s = MSXDisk::GetLastErrorMessage()
  MSXDisk::CloseDisk()

  If Not Ok
    MessageRequester("Erro ao montar o disco", DiskErr,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected Params.s = ""
  If BadigCfg\EmMachine <> ""
    Params + "-machine " + Chr(34) + BadigCfg\EmMachine + Chr(34) + " "
  EndIf
  If BadigCfg\EmExtension <> ""
    ; campo aceita "Nome" ou "Nome:slot" (ex. "Nome:exta") - o slot vira
    ; parte do NOME da flag no openMSX (-exta), nao um argumento separado
    Protected ExtValue.s = BadigCfg\EmExtension
    Protected ExtFlag.s = "-ext"
    Protected ColonPos.i = FindString(ExtValue, ":")
    If ColonPos > 0
      ExtFlag = "-" + Mid(ExtValue, ColonPos + 1)
      ExtValue = Left(ExtValue, ColonPos - 1)
    EndIf
    Params + ExtFlag + " " + Chr(34) + ExtValue + Chr(34) + " "
  EndIf
  Params + "-diska " + Chr(34) + DiskPath + Chr(34)

  Protected Prog = RunProgram(BadigCfg\EmulatorPath, Params, GetPathPart(BadigCfg\EmulatorPath), #PB_Program_Open)
  If Not Prog
    MessageRequester("Erro", "Nao foi possivel executar o openMSX:" + Chr(10) + BadigCfg\EmulatorPath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
  EndIf
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
  ResizeGadget(#HelpGadget, 0, #TabBar_Height + #Ruler_Height, FullW, InnerH)

  RedrawTabBar()
  RedrawRuler()
EndProcedure

;- ------------------------------------------------------------
;- Programa principal
;- ------------------------------------------------------------

InitKeywordMaps()
InitZ80KeywordMaps()
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
    MenuItem(#Menu_New,      "Novo" + Chr(9) + "Alt+N")
    MenuItem(#Menu_NewAssembly, "Novo Assembly" + Chr(9) + "Ctrl+Shift+N")
    MenuItem(#Menu_Open,     "Abrir..." + Chr(9) + "Ctrl+O")
    MenuBar()
    MenuItem(#Menu_Save,     "Salvar" + Chr(9) + "Ctrl+K D")
    MenuItem(#Menu_SaveAs,   "Salvar como..." + Chr(9) + "Ctrl+Shift+S")
    MenuBar()
    MenuItem(#Menu_DignifiedToAscii, "Dignified -> ASCII nativo (.amx)...")
    MenuItem(#Menu_DignifiedToTokenized, "Dignified -> tokenizado nativo (.bmx)...")
    MenuBar()
    MenuItem(#Menu_TokenizeNative, "ASCII classico ja aberto -> tokenizado nativo (.bmx)...")
    MenuBar()
    MenuItem(#Menu_CloseTab, "Fechar aba" + Chr(9) + "Alt+W")
    MenuBar()
    MenuItem(#Menu_Exit,     "Sair" + Chr(9) + "Alt+F4")
  MenuTitle("Executar")
    MenuItem(#Menu_RunBasic, "BASIC" + Chr(9) + "F5")
  MenuTitle("Configurar")
    MenuItem(#Menu_ConfigureBadig, "Basic Dignified...")
    MenuItem(#Menu_ConfigureEditor, "Editor...")
  MenuTitle("Ajuda")
    MenuItem(#Menu_HelpCommands, "Comandos..." + Chr(9) + "Ctrl+K H")
    MenuItem(#Menu_HelpAbout, "Sobre...")

; Novo/Fechar aba usam Alt (nao Ctrl) porque Ctrl+N e Ctrl+W tem funcao propria
; no teclado WordStar/JOE (^N = quebra de linha, ^W = scroll da tela para cima -
; ver WordStarKeys.pbi) e nao podem ficar reservados para o app.
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Alt | #PB_Shortcut_N, #Menu_New)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_Shift | #PB_Shortcut_N, #Menu_NewAssembly)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_O, #Menu_Open)
; Ctrl+S NAO fica com "Salvar" - no teclado WordStar/JOE (ver WordStarKeys.pbi)
; Ctrl+S move o cursor para a esquerda. Salvar passou a ser Ctrl+K D.
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Control | #PB_Shortcut_Shift | #PB_Shortcut_S, #Menu_SaveAs)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_Alt | #PB_Shortcut_W, #Menu_CloseTab)
AddKeyboardShortcut(#MainWindow, #PB_Shortcut_F5, #Menu_RunBasic)

CanvasGadget(#TabBarGadget, 0, 0, WindowWidth(#MainWindow), #TabBar_Height)
CanvasGadget(#RulerGadget, 0, #TabBar_Height, WindowWidth(#MainWindow), #Ruler_Height)

CreateStatusBar(#MainStatusBar, WindowID(#MainWindow))
  AddStatusBarField(70)          ; modo (INS/SBR) ou prefixo de comando pendente (^K/^Q)
  AddStatusBarField(#PB_Ignore)  ; nome do arquivo
  AddStatusBarField(160)         ; linha/coluna

WS_CreateHelpGadget()
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

        Case #Menu_NewAssembly
          AddDocumentTab("", "", "ASM")

        Case #Menu_Open
          OpenDocumentDialog()

        Case #Menu_Save
          SaveDocument(#False)

        Case #Menu_SaveAs
          SaveDocument(#True)

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

        Case #Menu_RunBasic
          RunBasicFromActiveTab()

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
            WS_SetupHelpStyles()
            ResizeInterface()
          EndIf

        Case #Menu_HelpCommands
          WS_ShowHelp()

        Case #Menu_HelpAbout
          ShowAboutDialog()
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
        UpdateStatusBar()
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

    Case #Event_WS_CloseTab
      ; ^KX (salvar e fechar) / ^KQ (fechar) do teclado WordStar/JOE - ver
      ; WordStarKeys.pbi. Adiado para aqui (fora da subclass do Scintilla) por
      ; causa do FreeGadget dentro de CloseTab.
      If EventData()
        If SaveDocument(#False)
          CloseTab(ActiveTabPosition)
        EndIf
      Else
        CloseTab(ActiveTabPosition)
      EndIf

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

; Incluido so aqui no fim (nao junto com os demais XIncludeFile no topo) porque
; usa Docs()/SaveDocument()/OpenDocumentDialog()/CloseTab()/Color_Accent, todos
; definidos ao longo deste arquivo - ver Declare de WS_AttachSubclass/
; WS_SetupIndicator perto do topo para as poucas chamadas na direcao inversa.
XIncludeFile "WordStarKeys.pbi"
