;
; ------------------------------------------------------------
;  Z80Asm.pbi - assembler Z80 nativo, compativel M80/L80 (dialeto N80/
;  Nestor80 de Konamiman, https://github.com/Konamiman/Nestor80 - clone de
;  referencia gitignored em nestor80/, NAO dependencia de runtime, ver
;  docs/resumo-asm.md e docs/reference/nestor80-language.md).
;
;  DeclareModule real (nao so prefixo) porque o subsistema tem muitos verbos
;  genericos (Process/Resolve/Emit) que colidiriam com o resto do arquivo -
;  mesma decisao ja tomada para ProjectDB.pbi/MSXDisk.pbi.
;
;  Vocabulario (mnemonicos/registradores/diretivas/operadores) e usado tanto
;  pelo motor quanto pelo realce de sintaxe HighlightZ80Text() em
;  BadigEditor.pb - fonte unica aqui dentro, o highlighter so consome via
;  Z80Asm::IsMnemonic()/IsRegister()/IsDirective()/IsOperatorWord().
; ------------------------------------------------------------
;

DeclareModule Z80Asm
  ; Structure Z80Addr/Enumeration Z80SegType - ver comentario no topo de
  ; Z80RelFormat.pbi sobre por que a inclusao tem que acontecer aqui dentro.
  XIncludeFile "Z80RelFormat.pbi"

  ; Resultado de ParseLine() - precisa estar aqui dentro (nao so no Module)
  ; pelo mesmo motivo de Z80Addr, ver comentario acima/docs/resumo-asm.md.
  Structure Z80ParsedLine
    HasLabel.b
    Label.s          ; maiusculo, sem os dois-pontos
    LabelIsPublic.b  ; "::" em vez de ":" (so relevante pra Fase B/REL)
    LabelHasColon.b  ; #True = rotulo classico "nome:"; #False = veio da forma
                      ; "nome EQU/DEFL/ASET valor" (sem dois-pontos, ver LR/M80 -
                      ; EQU/DEFL/ASET sao "constantDefinitionOpcodes", o simbolo
                      ; antes deles nunca precisa de ":")
    HasOperator.b
    Operator.s       ; maiusculo - mnemonico Z80, diretiva ou (Fase A ainda nao) nome de macro
    ArgsText.s       ; texto cru dos argumentos, comentario ja removido, case original preservado
    HasComment.b
    Comment.s        ; sem o ";" inicial
    IsBlank.b        ; linha vazia ou so comentario (sem label nem operador)
  EndStructure

  Declare InitKeywordMaps()
  Declare.i IsMnemonic(Word.s)
  Declare.i IsRegister(Word.s)
  Declare.i IsDirective(Word.s)
  Declare.i IsOperatorWord(Word.s)

  ; Avaliador de expressao + tabela de simbolos (ver docs/reference/nestor80-language.md)
  Declare   ResetState()
  Declare   SetCurrentLocation(Value.u)
  Declare.i DefineSymbol(Name.s, Value.u, IsConstant.b = #False)
  Declare.i IsSymbolKnown(Name.s)
  Declare.u GetSymbolValue(Name.s)
  Declare.i EvalExpr(Text.s, *Out.Z80Addr)
  Declare.s GetLastEvalError()
  Declare.s GetLastEvalUnknownSymbol()

  ; Parser de linha (ver docs/reference/nestor80-language.md, "Formato da linha-fonte")
  Declare.b ParseLine(RawLine.s, *Out.Z80ParsedLine)

  ; Codificador de instrucao Z80 (tabela de opcodes) - EmitMode=#False so calcula o
  ; tamanho em bytes (usado no pass 1, nao avalia expressao nenhuma); EmitMode=#True
  ; avalia as expressoes de verdade e preenche Out() (usado no pass 2). Out() precisa
  ; vir dimensionado Array Out.a(3) pelo chamador (toda instrucao Z80 cabe em 4 bytes).
  ; ArgsText = texto cru dos operandos (0/1/2, separados por virgula), tipicamente
  ; vindo direto de Z80ParsedLine\ArgsText. Devolve o numero de bytes (0-4) ou -1 em
  ; erro (ver GetLastAsmError()). Le/usa CurLoc (ver SetCurrentLocation()) pra
  ; calcular deslocamento relativo de JR/DJNZ - o chamador precisa ter ajustado
  ; CurLoc pro endereco desta instrucao ANTES de chamar.
  Declare.i EncodeInstruction(Mnemonic.s, ArgsText.s, EmitMode.b, Array Out.a(1))
  Declare.s GetLastAsmError()

  ; Driver de 2 passes - so absoluto por enquanto (ORG/label/EQU/DEFL/ASET/
  ; instrucoes de CPU; ASEG/CSEG/DSEG/COMMON/PUBLIC/EXTRN reconhecidas sem
  ; efeito pleno - Fase B). OutBytes precisa vir dimensionado pelo chamador
  ; com pelo menos 65536 posicoes (Array OutBytes.a(65535)) - devolve quantos
  ; bytes de fato foram usados (0 = nada gerado) ou -1 em erro (ver
  ; GetAssembleErrorLine()/GetAssembleErrorText()).
  Declare.i Assemble(SourceText.s, Array OutBytes.a(1))
  Declare.i GetAssembleErrorLine()
  Declare.s GetAssembleErrorText()
  ; Endereco do primeiro/ultimo byte tocado na ultima chamada a Assemble() -
  ; so tem sentido depois de uma chamada com sucesso (N > 0); usado pra
  ; montar o cabecalho MSX BLOAD (FE + inicio + fim + execucao), ver
  ; AssembleZ80FromActiveTab() em BadigEditor.pb.
  Declare.u GetAssembleStartAddr()
  Declare.u GetAssembleEndAddr()
EndDeclareModule

Module Z80Asm

  Global NewMap KwMnemonic.b()
  Global NewMap KwRegister.b()
  Global NewMap KwDirective.b()
  Global NewMap KwOperatorWord.b()
  Global KeywordMapsReady.b = #False

  ;- ------------------------------------------------------------
  ;- Vocabulario (mesmas listas que estavam em BadigEditor.pb ate 2026-07-24,
  ;- migradas pra ca - ver docs/resumo-asm.md, tarefa "Migrar tabelas de
  ;- keyword Z80 para Z80Asm.pbi")
  ;- ------------------------------------------------------------

  Procedure FillKwMap(Map Dest.b(), Words.s)
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
    If KeywordMapsReady
      ProcedureReturn
    EndIf

    ; Mnemonicos Z80 (documentados + indocumentados de uso comum, ex. SLL)
    FillKwMap(KwMnemonic(),
      "ADC ADD AND BIT CALL CCF CP CPD CPDR CPI CPIR CPL DAA DEC DI DJNZ EI EX " +
      "EXX HALT IM IN INC IND INDR INI INIR JP JR LD LDD LDDR LDI LDIR NEG NOP " +
      "OR OTDR OTIR OUT OUTD OUTI POP PUSH RES RET RETI RETN RL RLA RLC RLCA " +
      "RLD RR RRA RRC RRCA RRD RST SBC SCF SET SLA SLL SRA SRL SUB XOR")

    ; Registradores e codigos de condicao de desvio (NZ/Z/NC/C/PO/PE/P/M) -
    ; tratados com o mesmo estilo (ambos sao "operandos de hardware")
    FillKwMap(KwRegister(),
      "A B C D E H L I R IX IY SP AF BC DE HL PC IXH IXL IYH IYL NZ Z NC PO PE P M")

    ; Diretivas do assembler - inclui as com "." do dialeto N80 (RADIX/PHASE/
    ; etc guardadas SEM o ponto aqui; o "." e reconhecido a parte no lexer,
    ; ver Z80_ScanDotWord() dentro de HighlightZ80Text em BadigEditor.pb)
    FillKwMap(KwDirective(),
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
    FillKwMap(KwOperatorWord(), "LOW HIGH MOD SHR SHL EQ NE NEQ LT LE LTE GT GE GTE NUL TYPE")

    KeywordMapsReady = #True
  EndProcedure

  Procedure.i IsMnemonic(Word.s)
    InitKeywordMaps()
    ProcedureReturn Bool(FindMapElement(KwMnemonic(), UCase(Word)))
  EndProcedure

  Procedure.i IsRegister(Word.s)
    InitKeywordMaps()
    ProcedureReturn Bool(FindMapElement(KwRegister(), UCase(Word)))
  EndProcedure

  Procedure.i IsDirective(Word.s)
    InitKeywordMaps()
    ProcedureReturn Bool(FindMapElement(KwDirective(), UCase(Word)))
  EndProcedure

  Procedure.i IsOperatorWord(Word.s)
    InitKeywordMaps()
    ProcedureReturn Bool(FindMapElement(KwOperatorWord(), UCase(Word)))
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Tabela de simbolos + avaliador de expressao (RPN/shunting-yard) - mesma
  ;- precedencia e regras do Nestor80 (Assembler/Expressions/Expression*.cs,
  ;- valores de Precedence conferidos direto no fonte C#), ver
  ;- docs/reference/nestor80-language.md secao "Expressoes". Motor
  ;- autocontido (nao depende de nenhum helper de BadigEditor.pb - eles sao
  ;- declarados textualmente DEPOIS do ponto de XIncludeFile deste arquivo,
  ;- entao nao estariam visiveis aqui).
  ;- ------------------------------------------------------------

  ; Helpers de Z80Addr (construtor + comparacao de segmento) - vivem aqui
  ; dentro do Module, nao em Z80RelFormat.pbi, porque esse arquivo so pode
  ; conter Structure/Enumeration (ver comentario no topo dele); o futuro
  ; Z80Link.pbi (Fase B) tera sua propria copia trivial destes 3 helpers.

  Procedure Z80Addr_Make(*Out.Z80Addr, Value.u, SegType.b, CommonName.s = "")
    *Out\Value = Value
    *Out\SegType = SegType
    *Out\CommonName = CommonName
  EndProcedure

  Procedure.b Z80Addr_IsAbsolute(*A.Z80Addr)
    ProcedureReturn Bool(*A\SegType = #Z80Seg_Absolute)
  EndProcedure

  ; Compara segmento (nao valor) - usado pelo avaliador de expressao pra
  ; decidir se uma subtracao entre dois valores relocaveis do mesmo segmento
  ; vira um valor absoluto (regra do Nestor80/M80: end1-end2 no mesmo
  ; segmento = distancia absoluta) - sem consumidor ainda na Fase A (so
  ; ASEG existe de verdade), fica pronta pra Fase B.
  Procedure.b Z80Addr_SameSegment(*A.Z80Addr, *B.Z80Addr)
    If *A\SegType <> *B\SegType
      ProcedureReturn #False
    EndIf
    If *A\SegType = #Z80Seg_Common
      ProcedureReturn Bool(*A\CommonName = *B\CommonName)
    EndIf
    ProcedureReturn #True
  EndProcedure

  Structure Z80Symbol
    Addr.Z80Addr
    IsKnown.b     ; ja recebeu um valor (rotulo definido / EQU / DEFL atribuido)
    IsConstant.b  ; EQU - nao pode ser redefinido (DEFL e rotulo podem)
  EndStructure

  Global NewMap Symbols.Z80Symbol()
  Global CurLoc.Z80Addr    ; contador de localizacao "reportado" ($/rotulos/JR) - atualizado pelo
                           ; driver de 2 passes; dentro de um bloco .PHASE, difere da posicao real de
                           ; escrita (ver RealPos/PhaseActive logo abaixo e docs/resumo-asm.md)
  Global RealPos.u         ; posicao real de escrita em Mem() - sempre avanca em lockstep com CurLoc
                           ; (mesma quantidade de bytes a cada instrucao/diretiva), mas so os DOIS
                           ; sao iguais fora de um bloco .PHASE
  Global PhaseActive.b = #False
  Global PassNumber.b = 1  ; 1 ou 2 - idem
  Global LastEvalError.s
  Global LastEvalUnknownSymbol.s

  ; Macros basicas (MACRO/ENDM/EXITM/LOCAL) - ver ExpandLines() mais abaixo.
  ; BodyText guarda o corpo cru com as linhas unidas por Chr(10) (mesmo
  ; padrao de "linhas unidas por Chr(10) numa unica coluna TEXT" ja usado em
  ; mml_songs no ProjectDB.pbi) - substituicao de parametro/LOCAL acontece
  ; por cima desse texto na hora da expansao, nao na hora da definicao.
  Structure Z80MacroDef
    ParamNames.s  ; nomes dos parametros, separados por espaco, em ordem posicional ("" = sem parametro)
    BodyText.s
  EndStructure

  Global NewMap Macros.Z80MacroDef()
  Global MacroExpansionCounter.i = 0

  Enumeration Z80OpCode
    #Z80Op_Plus
    #Z80Op_Minus
    #Z80Op_Mul
    #Z80Op_Div
    #Z80Op_Mod
    #Z80Op_Shl
    #Z80Op_Shr
    #Z80Op_And
    #Z80Op_Or
    #Z80Op_Xor
    #Z80Op_Not        ; unario (bitwise complement)
    #Z80Op_Eq
    #Z80Op_Ne
    #Z80Op_Lt
    #Z80Op_Le
    #Z80Op_Gt
    #Z80Op_Ge
    #Z80Op_High       ; unario
    #Z80Op_Low        ; unario
    #Z80Op_UnaryMinus
    #Z80Op_UnaryPlus
  EndEnumeration

  Enumeration Z80TokKind
    #Z80Tk_Number
    #Z80Tk_Symbol
    #Z80Tk_CurLoc     ; "$" isolado
    #Z80Tk_Operator
    #Z80Tk_LParen
    #Z80Tk_RParen
  EndEnumeration

  Structure Z80ExprTok
    Kind.b
    NumValue.Z80Addr  ; usado quando Kind = Number (e recebe o resultado ja avaliado durante EvalPostfix)
    SymName.s         ; usado quando Kind = Symbol
    IsExternal.b      ; sufixo ## (guardado, sem efeito ate a Fase B/linker)
    OpCode.b          ; usado quando Kind = Operator
  EndStructure

  ;- Classificacao de caracteres (copia local, deliberadamente independente
  ;- dos helpers globais de BadigEditor.pb - ver comentario da secao acima)

  Procedure.b ChIsDigit(C.s)
    ProcedureReturn Bool(C >= "0" And C <= "9")
  EndProcedure

  Procedure.b ChIsHexDigit(C.s)
    Protected U.s = UCase(C)
    ProcedureReturn Bool(ChIsDigit(C) Or (U >= "A" And U <= "F"))
  EndProcedure

  Procedure.b ChIsAlpha(C.s)
    Protected U.s = UCase(C)
    ProcedureReturn Bool(U >= "A" And U <= "Z")
  EndProcedure

  ; Caracteres validos de simbolo alem de letra/digito, por regra da
  ; linguagem (docs/reference/nestor80-language.md: letras, digitos, $.?@_;
  ; primeiro caractere nao pode ser digito). Restrito a ASCII de proposito -
  ; o Nestor80 aceita qualquer letra Unicode, mas fonte MSX/Z80 real e
  ; sempre ASCII na pratica; simplifica o scanner char-a-char em PureBasic.
  Procedure.b ChIsIdentExtra(C.s)
    ProcedureReturn Bool(C = "$" Or C = "." Or C = "?" Or C = "@" Or C = "_")
  EndProcedure

  Procedure.b ChIsIdentStart(C.s)
    ProcedureReturn Bool(ChIsAlpha(C) Or ChIsIdentExtra(C))
  EndProcedure

  Procedure.b ChIsIdentCont(C.s)
    ProcedureReturn Bool(ChIsAlpha(C) Or ChIsDigit(C) Or ChIsIdentExtra(C))
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Parser de linha: "[label:[:]] [operador] [argumentos] [;comentario]"
  ;- (docs/reference/nestor80-language.md, "Formato da linha-fonte", LR:151-177).
  ;- So separa a linha em pedacos - NAO classifica o operador (mnemonico vs.
  ;- diretiva vs. nome de macro), isso e trabalho do driver de 2 passes
  ;- (proxima tarefa), que ja tem Z80Asm::IsMnemonic()/IsDirective() pra isso.
  ;- Nao trata ".COMMENT" (comentario multi-linha) - precisa de estado entre
  ;- linhas, fica a cargo do driver.
  ;- ------------------------------------------------------------

  ; Acha a posicao (1-based) do primeiro ";" fora de aspas, ou 0 se nao achar -
  ; consciente de string entre aspas simples/duplas (mesma regra de escape por
  ; aspa dobrada usada em TokenizeExpr: '' ou "" dentro do mesmo delimitador =
  ; aspa literal, nao fecha a string).
  Procedure.i FindCommentStart(Line.s)
    Protected LineLen = Len(Line)
    Protected I = 1, C.s, Delim.s
    While I <= LineLen
      C = Mid(Line, I, 1)
      If C = ";"
        ProcedureReturn I
      EndIf
      If C = Chr(34) Or C = "'"
        Delim = C
        I + 1
        While I <= LineLen
          C = Mid(Line, I, 1)
          If C = Delim
            If I < LineLen And Mid(Line, I + 1, 1) = Delim
              I + 2
              Continue
            EndIf
            I + 1
            Break
          EndIf
          I + 1
        Wend
        Continue
      EndIf
      I + 1
    Wend
    ProcedureReturn 0
  EndProcedure

  ; Devolve a posicao (1-based) do primeiro caractere nao-espaco/tab a partir
  ; de Start, ou Len(S)+1 se so sobrar espaco ate o fim (NAO usa Trim() -
  ; Trim() so remove espaco, nao tab, mesma armadilha ja documentada no
  ; historico do pre-processador Dignified, ver docs/SPEC.md modulo 3).
  Procedure.i SkipWs(S.s, Start.i)
    Protected L = Len(S), I = Start
    While I <= L And (Mid(S, I, 1) = " " Or Mid(S, I, 1) = Chr(9))
      I + 1
    Wend
    ProcedureReturn I
  EndProcedure

  ; Remove espaco/tab do fim de S (equivalente a RTrim, mas tab-aware).
  Procedure.s RTrimWs(S.s)
    Protected L = Len(S)
    While L > 0 And (Mid(S, L, 1) = " " Or Mid(S, L, 1) = Chr(9))
      L - 1
    Wend
    ProcedureReturn Left(S, L)
  EndProcedure

  Procedure.b ParseLine(RawLine.s, *Out.Z80ParsedLine)
    Protected CommentPos = FindCommentStart(RawLine)
    Protected Code.s
    Protected CodeLen, I, WStart, WStop, Word1.s, Word2.s, AfterWord1, P2, W2Start, W2End

    *Out\HasLabel = #False       : *Out\Label = ""
    *Out\LabelIsPublic = #False  : *Out\LabelHasColon = #False
    *Out\HasOperator = #False    : *Out\Operator = ""
    *Out\ArgsText = ""
    *Out\HasComment = #False     : *Out\Comment = ""
    *Out\IsBlank = #False

    If CommentPos > 0
      *Out\HasComment = #True
      *Out\Comment = RTrimWs(Mid(RawLine, SkipWs(RawLine, CommentPos + 1)))
      Code = Left(RawLine, CommentPos - 1)
    Else
      Code = RawLine
    EndIf

    CodeLen = Len(Code)
    I = SkipWs(Code, 1)

    If I > CodeLen
      ; nada alem de espaco (e talvez comentario) - linha em branco
      *Out\IsBlank = #True
      ProcedureReturn #True
    EndIf

    ; --- primeira palavra da linha ---
    If Not ChIsIdentStart(Mid(Code, I, 1))
      ; nao comeca com identificador valido - devolve tudo como ArgsText cru
      ; e deixa o driver de 2 passes reportar o erro de sintaxe (mesma
      ; postura de "nao implementa bare expression" da Fase A, ver LR:497).
      *Out\ArgsText = RTrimWs(Mid(Code, I))
      ProcedureReturn #True
    EndIf

    WStart = I
    I + 1
    While I <= CodeLen And ChIsIdentCont(Mid(Code, I, 1))
      I + 1
    Wend
    WStop = I - 1
    Word1 = UCase(Mid(Code, WStart, WStop - WStart + 1))
    AfterWord1 = I

    ; --- Forma classica "rotulo:" / "rotulo::" (LR:161) ---
    If I <= CodeLen And Mid(Code, I, 1) = ":"
      *Out\HasLabel = #True
      *Out\Label = Word1
      *Out\LabelHasColon = #True
      I + 1
      If I <= CodeLen And Mid(Code, I, 1) = ":"
        *Out\LabelIsPublic = #True
        I + 1
      EndIf

      I = SkipWs(Code, I)
      If I > CodeLen
        ProcedureReturn #True ; linha so com rotulo, sem operador
      EndIf
      If Not ChIsIdentStart(Mid(Code, I, 1))
        *Out\ArgsText = RTrimWs(Mid(Code, I))
        ProcedureReturn #True
      EndIf

      WStart = I
      I + 1
      While I <= CodeLen And ChIsIdentCont(Mid(Code, I, 1))
        I + 1
      Wend
      WStop = I - 1
      *Out\HasOperator = #True
      *Out\Operator = UCase(Mid(Code, WStart, WStop - WStart + 1))

      I = SkipWs(Code, I)
      If I <= CodeLen
        *Out\ArgsText = RTrimWs(Mid(Code, I))
      EndIf
      ProcedureReturn #True
    EndIf

    ; --- Sem ":" - pode ser "simbolo EQU/DEFL/ASET valor" (constantDefinitionOpcodes
    ; do Nestor80 - o simbolo antes deles NUNCA leva ":", ver
    ; docs/reference/nestor80-language.md, secao EQU/DEFL/ASET) ou "nome MACRO
    ; params" (mesma forma - nome da macro tambem fica em posicao de rotulo,
    ; sem ":" obrigatorio, ver secao "Macros: MACRO/ENDM/EXITM/LOCAL") ou
    ; entao Word1 ja e o proprio operador (mnemonico/diretiva/chamada de
    ; macro). So da pra saber espiando a proxima palavra.
    P2 = SkipWs(Code, AfterWord1)
    If P2 <= CodeLen And ChIsIdentStart(Mid(Code, P2, 1))
      W2Start = P2
      P2 + 1
      While P2 <= CodeLen And ChIsIdentCont(Mid(Code, P2, 1))
        P2 + 1
      Wend
      W2End = P2 - 1
      Word2 = UCase(Mid(Code, W2Start, W2End - W2Start + 1))

      If Word2 = "EQU" Or Word2 = "DEFL" Or Word2 = "ASET" Or Word2 = "MACRO"
        *Out\HasLabel = #True
        *Out\Label = Word1
        *Out\LabelHasColon = #False
        *Out\HasOperator = #True
        *Out\Operator = Word2

        P2 = SkipWs(Code, P2)
        If P2 <= CodeLen
          *Out\ArgsText = RTrimWs(Mid(Code, P2))
        EndIf
        ProcedureReturn #True
      EndIf
    EndIf

    ; --- Word1 e o proprio operador (sem rotulo) ---
    *Out\HasOperator = #True
    *Out\Operator = Word1
    I = SkipWs(Code, AfterWord1)
    If I <= CodeLen
      *Out\ArgsText = RTrimWs(Mid(Code, I))
    EndIf

    ProcedureReturn #True
  EndProcedure

  ;- Precedencia (menor numero = liga mais forte) e teste de "e unario" -
  ;- valores identicos aos de ArithmeticOperator.Precedence no fonte C# do
  ;- Nestor80 (Assembler/Expressions/ExpressionParts/ArithmeticOperators/*.cs).

  Procedure.i OpPrecedence(Op.b)
    Select Op
      Case #Z80Op_High, #Z80Op_Low
        ProcedureReturn 1
      Case #Z80Op_Mul, #Z80Op_Div, #Z80Op_Mod, #Z80Op_Shl, #Z80Op_Shr
        ProcedureReturn 2
      Case #Z80Op_UnaryMinus, #Z80Op_UnaryPlus
        ProcedureReturn 3
      Case #Z80Op_Plus, #Z80Op_Minus
        ProcedureReturn 4
      Case #Z80Op_Eq, #Z80Op_Ne, #Z80Op_Lt, #Z80Op_Le, #Z80Op_Gt, #Z80Op_Ge
        ProcedureReturn 5
      Case #Z80Op_Not
        ProcedureReturn 6
      Case #Z80Op_And
        ProcedureReturn 7
      Case #Z80Op_Or, #Z80Op_Xor
        ProcedureReturn 8
    EndSelect
    ProcedureReturn 99
  EndProcedure

  Procedure.b OpIsUnary(Op.b)
    ProcedureReturn Bool(Op = #Z80Op_Not Or Op = #Z80Op_High Or Op = #Z80Op_Low Or
                          Op = #Z80Op_UnaryMinus Or Op = #Z80Op_UnaryPlus)
  EndProcedure

  ; Palavra reservada -> opcode, para os operadores expressos por extenso
  ; (AND/OR/XOR/NOT sao reconhecidas aqui tambem, apesar de tambem serem
  ; mnemonicos Z80 - contexto de expressao sempre vence nesta funcao).
  ; Retorna -1 quando a palavra nao e nenhum operador conhecido.
  Procedure.i WordToOpCode(Word.s)
    Select UCase(Word)
      Case "AND"          : ProcedureReturn #Z80Op_And
      Case "OR"            : ProcedureReturn #Z80Op_Or
      Case "XOR"           : ProcedureReturn #Z80Op_Xor
      Case "NOT"           : ProcedureReturn #Z80Op_Not
      Case "MOD"           : ProcedureReturn #Z80Op_Mod
      Case "SHR"           : ProcedureReturn #Z80Op_Shr
      Case "SHL"           : ProcedureReturn #Z80Op_Shl
      Case "HIGH"          : ProcedureReturn #Z80Op_High
      Case "LOW"           : ProcedureReturn #Z80Op_Low
      Case "EQ"            : ProcedureReturn #Z80Op_Eq
      Case "NE", "NEQ"     : ProcedureReturn #Z80Op_Ne
      Case "LT"            : ProcedureReturn #Z80Op_Lt
      Case "LE", "LTE"     : ProcedureReturn #Z80Op_Le
      Case "GT"            : ProcedureReturn #Z80Op_Gt
      Case "GE", "GTE"     : ProcedureReturn #Z80Op_Ge
    EndSelect
    ProcedureReturn -1
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Tokenizador de expressao (texto -> lista infixa de Z80ExprTok)
  ;- ------------------------------------------------------------

  ;- Helpers de validacao de digitos por base (usados pelo tokenizador abaixo -
  ;- precisam vir antes dele: PureBasic, dentro de um Module, nao resolve
  ;- chamada a uma Procedure ainda nao definida textualmente).

  Procedure.b CountAllHex(S.s)
    Protected Idx
    For Idx = 1 To Len(S)
      If Not ChIsHexDigit(Mid(S, Idx, 1)) : ProcedureReturn #False : EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  Procedure.b CountAllOctal(S.s)
    Protected Idx, C.s
    For Idx = 1 To Len(S)
      C = Mid(S, Idx, 1)
      If C < "0" Or C > "7" : ProcedureReturn #False : EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  Procedure.b CountAllDecimal(S.s)
    Protected Idx
    For Idx = 1 To Len(S)
      If Not ChIsDigit(Mid(S, Idx, 1)) : ProcedureReturn #False : EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  Procedure.b CountAllBinary(S.s)
    Protected Idx, C.s
    For Idx = 1 To Len(S)
      C = Mid(S, Idx, 1)
      If C <> "0" And C <> "1" : ProcedureReturn #False : EndIf
    Next
    ProcedureReturn #True
  EndProcedure

  ; Converte uma sequencia de digitos octais para uma string hex equivalente
  ; (PureBasic Val() nao tem prefixo nativo pra octal) - constroi o valor
  ; digito a digito e devolve em hex pra reaproveitar Val("$"+...) no chamador.
  Procedure.s Hex_FromOctalDigits(S.s)
    Protected Idx, V.q = 0
    For Idx = 1 To Len(S)
      V = (V * 8) + (Asc(Mid(S, Idx, 1)) - Asc("0"))
    Next
    ProcedureReturn Hex(V)
  EndProcedure

  Procedure.b TokenizeExpr(Text.s, List Toks.Z80ExprTok())
    Protected TextLen = Len(Text)
    Protected I = 1, Start, C.s, C2.s, Word.s, Raw.s
    Protected LastWasOperand.b = #False  ; true logo apos numero/simbolo/$/')'

    ClearList(Toks())
    LastEvalError = ""

    While I <= TextLen
      C = Mid(Text, I, 1)

      If C = " " Or C = Chr(9)
        I + 1
        Continue
      EndIf

      If C = "("
        AddElement(Toks()) : Toks()\Kind = #Z80Tk_LParen
        I + 1 : LastWasOperand = #False
        Continue
      EndIf

      If C = ")"
        AddElement(Toks()) : Toks()\Kind = #Z80Tk_RParen
        I + 1 : LastWasOperand = #True
        Continue
      EndIf

      ; --- "$" isolado = contador de localizacao atual ---
      If C = "$" And (I = TextLen Or Not ChIsIdentCont(Mid(Text, I + 1, 1)))
        AddElement(Toks()) : Toks()\Kind = #Z80Tk_CurLoc
        I + 1 : LastWasOperand = #True
        Continue
      EndIf

      ; --- Hex prefixado com # (#1A2B) ---
      If C = "#" And I < TextLen And ChIsHexDigit(Mid(Text, I + 1, 1))
        Start = I + 1
        I + 1
        While I <= TextLen And ChIsHexDigit(Mid(Text, I, 1))
          I + 1
        Wend
        AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
        Z80Addr_Make(@Toks()\NumValue, Val("$" + Mid(Text, Start, I - Start)), #Z80Seg_Absolute)
        LastWasOperand = #True
        Continue
      EndIf

      ; --- Binario prefixado com % (%1010) ---
      If C = "%" And I < TextLen And (Mid(Text, I + 1, 1) = "0" Or Mid(Text, I + 1, 1) = "1")
        Start = I + 1
        I + 1
        While I <= TextLen And (Mid(Text, I, 1) = "0" Or Mid(Text, I, 1) = "1")
          I + 1
        Wend
        AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
        Z80Addr_Make(@Toks()\NumValue, Val("%" + Mid(Text, Start, I - Start)), #Z80Seg_Absolute)
        LastWasOperand = #True
        Continue
      EndIf

      ; --- Literal de string (1-2 caracteres viram valor numerico; ver
      ; docs/reference/nestor80-language.md - primeiro caractere = byte
      ; alto, segundo = byte baixo) ---
      If C = Chr(34) Or C = "'"
        Protected Delim.s = C
        Protected Body.s = ""
        Start = I
        I + 1
        While I <= TextLen
          C2 = Mid(Text, I, 1)
          If C2 = Delim
            If I < TextLen And Mid(Text, I + 1, 1) = Delim
              Body + Delim : I + 2 : Continue
            EndIf
            I + 1
            Break
          EndIf
          If C2 = Chr(13) Or C2 = Chr(10)
            Break
          EndIf
          Body + C2 : I + 1
        Wend
        Select Len(Body)
          Case 0
            AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
            Z80Addr_Make(@Toks()\NumValue, 0, #Z80Seg_Absolute)
          Case 1
            AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
            Z80Addr_Make(@Toks()\NumValue, Asc(Body), #Z80Seg_Absolute)
          Case 2
            AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
            Z80Addr_Make(@Toks()\NumValue, (Asc(Left(Body,1)) << 8) | Asc(Mid(Body,2,1)), #Z80Seg_Absolute)
          Default
            LastEvalError = "String com mais de 2 caracteres nao pode ser usada como valor numerico: " + Body
            ProcedureReturn #False
        EndSelect
        LastWasOperand = #True
        Continue
      EndIf

      ; --- Numeros (comecam com digito - identificador nao pode comecar com
      ; digito, entao "0FFh"/"1Ah"/"10"/"377Q"/"1010B" etc. so podem cair
      ; aqui; "FFh" sem o "0" na frente vira identificador, mesma regra
      ; classica M80) ---
      If ChIsDigit(C)
        Start = I
        ; prefixos 0x/0X (hex) e 0b/0B (binario) - so quando o token inteiro
        ; comeca exatamente por eles
        If C = "0" And I < TextLen And (UCase(Mid(Text, I + 1, 1)) = "X" Or UCase(Mid(Text, I + 1, 1)) = "B")
          Protected PrefixIsHex.b = Bool(UCase(Mid(Text, I + 1, 1)) = "X")
          Protected PStart = I + 2
          I + 2
          If PrefixIsHex
            While I <= TextLen And ChIsHexDigit(Mid(Text, I, 1))
              I + 1
            Wend
          Else
            While I <= TextLen And (Mid(Text, I, 1) = "0" Or Mid(Text, I, 1) = "1")
              I + 1
            Wend
          EndIf
          If I > PStart
            AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
            If PrefixIsHex
              Z80Addr_Make(@Toks()\NumValue, Val("$" + Mid(Text, PStart, I - PStart)), #Z80Seg_Absolute)
            Else
              Z80Addr_Make(@Toks()\NumValue, Val("%" + Mid(Text, PStart, I - PStart)), #Z80Seg_Absolute)
            EndIf
            LastWasOperand = #True
            Continue
          Else
            I = Start ; nao era prefixo de verdade (ex. "0x" sozinho, sem digitos) - recua e trata como decimal "0"
          EndIf
        EndIf

        ; token cru: maior sequencia alfanumerica a partir do digito inicial
        While I <= TextLen And (ChIsDigit(Mid(Text, I, 1)) Or ChIsAlpha(Mid(Text, I, 1)))
          I + 1
        Wend
        Raw = UCase(Mid(Text, Start, I - Start))
        C2 = Right(Raw, 1)
        Protected Digits.s, Value.u, Ok.b = #False

        If C2 = "H"
          Digits = Left(Raw, Len(Raw) - 1)
          If Digits <> "" And CountAllHex(Digits)
            Value = Val("$" + Digits) : Ok = #True
          EndIf
        ElseIf C2 = "O" Or C2 = "Q"
          Digits = Left(Raw, Len(Raw) - 1)
          If Digits <> "" And CountAllOctal(Digits)
            Value = Val("$" + Hex_FromOctalDigits(Digits)) ; ver helper abaixo
            Ok = #True
          EndIf
        ElseIf C2 = "D" Or C2 = "M"
          Digits = Left(Raw, Len(Raw) - 1)
          If Digits <> "" And CountAllDecimal(Digits)
            Value = Val(Digits) : Ok = #True
          EndIf
        ElseIf C2 = "B" Or C2 = "I"
          Digits = Left(Raw, Len(Raw) - 1)
          If Digits <> "" And CountAllBinary(Digits)
            Value = Val("%" + Digits) : Ok = #True
          EndIf
        EndIf

        If Not Ok
          ; sem sufixo reconhecido (ou sufixo nao bateu com os digitos que
          ; vieram antes) - trata o token inteiro como decimal
          If CountAllDecimal(Raw)
            Value = Val(Raw) : Ok = #True
          EndIf
        EndIf

        If Not Ok
          LastEvalError = "Numero invalido: " + Raw
          ProcedureReturn #False
        EndIf

        AddElement(Toks()) : Toks()\Kind = #Z80Tk_Number
        Z80Addr_Make(@Toks()\NumValue, Value, #Z80Seg_Absolute)
        LastWasOperand = #True
        Continue
      EndIf

      ; --- Identificadores / simbolos / operadores por extenso ---
      If ChIsIdentStart(C)
        Start = I
        I + 1
        While I <= TextLen And ChIsIdentCont(Mid(Text, I, 1))
          I + 1
        Wend
        Word = Mid(Text, Start, I - Start)

        Protected OpCode.i = WordToOpCode(Word)
        If OpCode >= 0
          AddElement(Toks()) : Toks()\Kind = #Z80Tk_Operator : Toks()\OpCode = OpCode
          LastWasOperand = #False
          Continue
        EndIf

        Protected IsExt.b = #False
        If I + 1 <= TextLen And Mid(Text, I, 2) = "##"
          IsExt = #True : I + 2
        EndIf

        AddElement(Toks()) : Toks()\Kind = #Z80Tk_Symbol
        Toks()\SymName = UCase(Word)
        Toks()\IsExternal = IsExt
        LastWasOperand = #True
        Continue
      EndIf

      ; --- Operadores simbolicos ---
      Select C
        Case "+"
          AddElement(Toks()) : Toks()\Kind = #Z80Tk_Operator
          If LastWasOperand
            Toks()\OpCode = #Z80Op_Plus
          Else
            Toks()\OpCode = #Z80Op_UnaryPlus
          EndIf
          I + 1 : LastWasOperand = #False
          Continue
        Case "-"
          AddElement(Toks()) : Toks()\Kind = #Z80Tk_Operator
          If LastWasOperand
            Toks()\OpCode = #Z80Op_Minus
          Else
            Toks()\OpCode = #Z80Op_UnaryMinus
          EndIf
          I + 1 : LastWasOperand = #False
          Continue
        Case "*"
          AddElement(Toks()) : Toks()\Kind = #Z80Tk_Operator : Toks()\OpCode = #Z80Op_Mul
          I + 1 : LastWasOperand = #False
          Continue
        Case "/"
          AddElement(Toks()) : Toks()\Kind = #Z80Tk_Operator : Toks()\OpCode = #Z80Op_Div
          I + 1 : LastWasOperand = #False
          Continue
      EndSelect

      LastEvalError = "Caractere inesperado em expressao: '" + C + "'"
      ProcedureReturn #False
    Wend

    ProcedureReturn #True
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Shunting-yard: lista infixa -> lista posfixa (RPN). Unarios sao
  ;- empilhados sem checar precedencia (igual ao Nestor80: sempre resolvidos
  ;- no proximo operador binario ou ")" - ver Postfixize() em
  ;- Expression.Evaluation.cs); binarios esvaziam a pilha enquanto o topo
  ;- tiver precedencia <= a do operador que esta entrando.
  ;- ------------------------------------------------------------

  Procedure.b ToPostfixExpr(List InToks.Z80ExprTok(), List OutToks.Z80ExprTok())
    NewList OpStack.Z80ExprTok()
    ClearList(OutToks())

    ForEach InToks()
      Select InToks()\Kind
        Case #Z80Tk_Number, #Z80Tk_Symbol, #Z80Tk_CurLoc
          AddElement(OutToks())
          CopyStructure(@InToks(), @OutToks(), Z80ExprTok)

        Case #Z80Tk_LParen
          AddElement(OpStack())
          CopyStructure(@InToks(), @OpStack(), Z80ExprTok)

        Case #Z80Tk_RParen
          Protected FoundOpen.b = #False
          While ListSize(OpStack()) > 0
            LastElement(OpStack())
            If OpStack()\Kind = #Z80Tk_LParen
              FoundOpen = #True
              DeleteElement(OpStack())
              Break
            EndIf
            AddElement(OutToks())
            CopyStructure(@OpStack(), @OutToks(), Z80ExprTok)
            DeleteElement(OpStack())
          Wend
          If Not FoundOpen
            LastEvalError = "Parenteses desbalanceados: falta '('"
            ProcedureReturn #False
          EndIf

        Case #Z80Tk_Operator
          If OpIsUnary(InToks()\OpCode)
            AddElement(OpStack())
            CopyStructure(@InToks(), @OpStack(), Z80ExprTok)
          Else
            Protected NewPrec.i = OpPrecedence(InToks()\OpCode)
            While ListSize(OpStack()) > 0
              LastElement(OpStack())
              If OpStack()\Kind = #Z80Tk_LParen
                Break
              EndIf
              Protected StackPrec.i = OpPrecedence(OpStack()\OpCode)
              If StackPrec > NewPrec And Not OpIsUnary(OpStack()\OpCode)
                Break
              EndIf
              AddElement(OutToks())
              CopyStructure(@OpStack(), @OutToks(), Z80ExprTok)
              DeleteElement(OpStack())
            Wend
            AddElement(OpStack())
            CopyStructure(@InToks(), @OpStack(), Z80ExprTok)
          EndIf
      EndSelect
    Next

    While ListSize(OpStack()) > 0
      LastElement(OpStack())
      If OpStack()\Kind = #Z80Tk_LParen
        LastEvalError = "Parenteses desbalanceados: sobrou '('"
        ProcedureReturn #False
      EndIf
      AddElement(OutToks())
      CopyStructure(@OpStack(), @OutToks(), Z80ExprTok)
      DeleteElement(OpStack())
    Wend

    ProcedureReturn #True
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Avaliacao da lista posfixa contra a tabela de simbolos atual. Devolve
  ;- #False se a expressao referenciar (pelo menos) um simbolo ainda
  ;- desconhecido - nesse caso NAO e erro fatal no pass 1 (ver
  ;- LastEvalUnknownSymbol); o chamador (driver de 2 passes, proxima tarefa)
  ;- decide o que fazer (reservar tamanho e enfileirar fixup).
  ;- ------------------------------------------------------------

  Procedure.b EvalPostfixExpr(List Toks.Z80ExprTok(), *Out.Z80Addr)
    NewList Stack.Z80Addr()
    Protected *A.Z80Addr, *B.Z80Addr, R.Z80Addr

    ForEach Toks()
      Select Toks()\Kind
        Case #Z80Tk_Number
          AddElement(Stack())
          CopyStructure(@Toks()\NumValue, @Stack(), Z80Addr)

        Case #Z80Tk_CurLoc
          AddElement(Stack())
          CopyStructure(@CurLoc, @Stack(), Z80Addr)

        Case #Z80Tk_Symbol
          If Not FindMapElement(Symbols(), Toks()\SymName)
            AddMapElement(Symbols(), Toks()\SymName)
            Symbols()\IsKnown = #False
          EndIf
          If Not Symbols(Toks()\SymName)\IsKnown
            LastEvalUnknownSymbol = Toks()\SymName
            ProcedureReturn #False
          EndIf
          AddElement(Stack())
          CopyStructure(@Symbols(Toks()\SymName)\Addr, @Stack(), Z80Addr)

        Case #Z80Tk_Operator
          If OpIsUnary(Toks()\OpCode)
            If ListSize(Stack()) < 1
              LastEvalError = "Expressao mal formada (operador unario sem operando)"
              ProcedureReturn #False
            EndIf
            LastElement(Stack()) : *A = @Stack()
            Select Toks()\OpCode
              Case #Z80Op_UnaryMinus
                Z80Addr_Make(@R, (-*A\Value) & $FFFF, *A\SegType, *A\CommonName)
              Case #Z80Op_UnaryPlus
                CopyStructure(*A, @R, Z80Addr)
              Case #Z80Op_Not
                Z80Addr_Make(@R, (~*A\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_High
                Z80Addr_Make(@R, (*A\Value >> 8) & $FF, #Z80Seg_Absolute)
              Case #Z80Op_Low
                Z80Addr_Make(@R, *A\Value & $FF, #Z80Seg_Absolute)
            EndSelect
            DeleteElement(Stack())
            AddElement(Stack())
            CopyStructure(@R, @Stack(), Z80Addr)
          Else
            If ListSize(Stack()) < 2
              LastEvalError = "Expressao mal formada (operador binario sem dois operandos)"
              ProcedureReturn #False
            EndIf
            LastElement(Stack()) : *B = @Stack() : DeleteElement(Stack())
            LastElement(Stack()) : *A = @Stack() : DeleteElement(Stack())

            ; Soma/subtracao entre valores relocaveis: por enquanto (Fase A,
            ; so ASEG existe de verdade) os dois operandos sao sempre
            ; absolutos - a regra de "mesmo segmento subtrai pra absoluto"
            ; (Z80Addr_SameSegment) fica pronta pra quando CSEG/DSEG
            ; passarem a valer alguma coisa na Fase B.
            Select Toks()\OpCode
              Case #Z80Op_Plus  : Z80Addr_Make(@R, (*A\Value + *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Minus : Z80Addr_Make(@R, (*A\Value - *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Mul   : Z80Addr_Make(@R, (*A\Value * *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Div
                If *B\Value = 0
                  LastEvalError = "Divisao por zero"
                  ProcedureReturn #False
                EndIf
                Z80Addr_Make(@R, (*A\Value / *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Mod
                If *B\Value = 0
                  LastEvalError = "Divisao por zero (MOD)"
                  ProcedureReturn #False
                EndIf
                Z80Addr_Make(@R, (*A\Value % *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Shl   : Z80Addr_Make(@R, (*A\Value << *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Shr   : Z80Addr_Make(@R, (*A\Value >> *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_And   : Z80Addr_Make(@R, (*A\Value & *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Or    : Z80Addr_Make(@R, (*A\Value | *B\Value) & $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Xor   : Z80Addr_Make(@R, (*A\Value ! *B\Value) & $FFFF, #Z80Seg_Absolute)
              ; Relacionais: convencao M80/Nestor80 - verdadeiro = FFFFh, falso = 0000h
              Case #Z80Op_Eq    : Z80Addr_Make(@R, Bool(*A\Value = *B\Value) * $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Ne    : Z80Addr_Make(@R, Bool(*A\Value <> *B\Value) * $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Lt    : Z80Addr_Make(@R, Bool(*A\Value < *B\Value) * $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Le    : Z80Addr_Make(@R, Bool(*A\Value <= *B\Value) * $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Gt    : Z80Addr_Make(@R, Bool(*A\Value > *B\Value) * $FFFF, #Z80Seg_Absolute)
              Case #Z80Op_Ge    : Z80Addr_Make(@R, Bool(*A\Value >= *B\Value) * $FFFF, #Z80Seg_Absolute)
            EndSelect
            AddElement(Stack())
            CopyStructure(@R, @Stack(), Z80Addr)
          EndIf
      EndSelect
    Next

    If ListSize(Stack()) <> 1
      LastEvalError = "Expressao mal formada (sobrou mais de um valor na pilha)"
      ProcedureReturn #False
    EndIf

    LastElement(Stack())
    CopyStructure(@Stack(), *Out, Z80Addr)
    ProcedureReturn #True
  EndProcedure

  ;- ------------------------------------------------------------
  ;- API publica
  ;- ------------------------------------------------------------

  Procedure ResetState()
    ClearMap(Symbols())
    Z80Addr_Make(@CurLoc, 0, #Z80Seg_Absolute)
    PassNumber = 1
    LastEvalError = ""
    LastEvalUnknownSymbol = ""
  EndProcedure

  Procedure SetCurrentLocation(Value.u)
    CurLoc\Value = Value
  EndProcedure

  Procedure.i DefineSymbol(Name.s, Value.u, IsConstant.b = #False)
    Protected Key.s = UCase(Name)
    If FindMapElement(Symbols(), Key) And Symbols()\IsKnown And Symbols()\IsConstant
      If Symbols()\Addr\Value = Value
        ProcedureReturn #True ; redefinicao idempotente (mesma linha EQU vista de novo no pass 2) - ok
      EndIf
      LastEvalError = "Simbolo ja definido (EQU nao pode ser redefinido): " + Key
      ProcedureReturn #False
    EndIf
    If Not FindMapElement(Symbols(), Key)
      AddMapElement(Symbols(), Key)
    EndIf
    Z80Addr_Make(@Symbols()\Addr, Value, #Z80Seg_Absolute)
    Symbols()\IsKnown = #True
    Symbols()\IsConstant = IsConstant
    ProcedureReturn #True
  EndProcedure

  Procedure.i IsSymbolKnown(Name.s)
    Protected Key.s = UCase(Name)
    If FindMapElement(Symbols(), Key)
      ProcedureReturn Symbols()\IsKnown
    EndIf
    ProcedureReturn #False
  EndProcedure

  Procedure.u GetSymbolValue(Name.s)
    Protected Key.s = UCase(Name)
    If FindMapElement(Symbols(), Key)
      ProcedureReturn Symbols()\Addr\Value
    EndIf
    ProcedureReturn 0
  EndProcedure

  Procedure.i EvalExpr(Text.s, *Out.Z80Addr)
    NewList Infix.Z80ExprTok()
    NewList Postfix.Z80ExprTok()

    LastEvalError = ""
    LastEvalUnknownSymbol = ""

    If Not TokenizeExpr(Text, Infix())
      ProcedureReturn #False
    EndIf
    If ListSize(Infix()) = 0
      LastEvalError = "Expressao vazia"
      ProcedureReturn #False
    EndIf
    If Not ToPostfixExpr(Infix(), Postfix())
      ProcedureReturn #False
    EndIf
    ProcedureReturn EvalPostfixExpr(Postfix(), *Out)
  EndProcedure

  Procedure.s GetLastEvalError()
    ProcedureReturn LastEvalError
  EndProcedure

  Procedure.s GetLastEvalUnknownSymbol()
    ProcedureReturn LastEvalUnknownSymbol
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Codificador de instrucoes Z80 (tabela de opcodes) - ver
  ;- docs/reference/nestor80-language.md, secao "Gramatica de modos de
  ;- enderecamento". Classificacao de operando primeiro (ClassifyOperand),
  ;- depois um dispatcher por familia de mnemonico. O tamanho de qualquer
  ;- instrucao Z80 e 100% determinado pela FORMA do(s) operando(s), nunca
  ;- pelo valor - por isso o pass 1 (EmitMode=#False) nunca chama EvalExpr
  ;- de verdade (EvalOperandExpr/EvalDisplacement so simulam um valor 0),
  ;- so classifica formato.
  ;- ------------------------------------------------------------

  Global LastAsmError.s

  Procedure.s GetLastAsmError()
    ProcedureReturn LastAsmError
  EndProcedure

  Enumeration Z80OperandKind
    #Z80Opnd_None
    #Z80Opnd_Reg8
    #Z80Opnd_Reg16
    #Z80Opnd_RegAF
    #Z80Opnd_IX
    #Z80Opnd_IY
    #Z80Opnd_IXHalf   ; IXH(RegCode=4)/IXL(RegCode=5)
    #Z80Opnd_IYHalf   ; IYH(RegCode=4)/IYL(RegCode=5)
    #Z80Opnd_IndHL
    #Z80Opnd_IndBC
    #Z80Opnd_IndDE
    #Z80Opnd_IndSP
    #Z80Opnd_IndC
    #Z80Opnd_IndIX    ; "(IX)" (Expr="") ou "(IX+d)"/"(IX-d)" (Expr=deslocamento)
    #Z80Opnd_IndIY
    #Z80Opnd_Cond     ; NZ Z NC C PO PE P M
    #Z80Opnd_Imm      ; expressao "solta"
    #Z80Opnd_IndImm   ; "(expressao)" generico, ex. (nn)
  EndEnumeration

  Structure Z80Operand
    Kind.b
    RegCode.b   ; Reg8: B=0 C=1 D=2 E=3 H=4 L=5 A=7 | Reg16/qq/IXHalf/IYHalf: ver comentarios acima | Cond: NZ=0 Z=1 NC=2 C=3 PO=4 PE=5 P=6 M=7
    Expr.s      ; Imm/IndImm: a expressao inteira; IndIX/IndIY: so o deslocamento (pode ser "")
    Present.b
  EndStructure

  ; Espaco/tab nas pontas ja removido por quem monta ArgsText (ParseLine) -
  ; SkipWs/RTrimWs aqui e defesa extra (operando isolado apos split por
  ; virgula pode sobrar com espaco em volta, ex. "LD A, B").
  Procedure ClassifyOperand(Text.s, *Out.Z80Operand)
    Protected T.s = RTrimWs(Mid(Text, SkipWs(Text, 1)))
    Protected U.s = UCase(T)

    *Out\Kind = #Z80Opnd_Imm
    *Out\RegCode = 0
    *Out\Expr = T
    *Out\Present = Bool(T <> "")

    If T = ""
      *Out\Kind = #Z80Opnd_None
      ProcedureReturn
    EndIf

    Select U
      Case "B"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 0 : ProcedureReturn
      Case "C"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 1 : ProcedureReturn
      Case "D"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 2 : ProcedureReturn
      Case "E"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 3 : ProcedureReturn
      Case "H"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 4 : ProcedureReturn
      Case "L"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 5 : ProcedureReturn
      Case "A"  : *Out\Kind = #Z80Opnd_Reg8 : *Out\RegCode = 7 : ProcedureReturn
      Case "BC" : *Out\Kind = #Z80Opnd_Reg16 : *Out\RegCode = 0 : ProcedureReturn
      Case "DE" : *Out\Kind = #Z80Opnd_Reg16 : *Out\RegCode = 1 : ProcedureReturn
      Case "HL" : *Out\Kind = #Z80Opnd_Reg16 : *Out\RegCode = 2 : ProcedureReturn
      Case "SP" : *Out\Kind = #Z80Opnd_Reg16 : *Out\RegCode = 3 : ProcedureReturn
      Case "AF" : *Out\Kind = #Z80Opnd_RegAF : *Out\RegCode = 3 : ProcedureReturn
      Case "IX" : *Out\Kind = #Z80Opnd_IX : ProcedureReturn
      Case "IY" : *Out\Kind = #Z80Opnd_IY : ProcedureReturn
      Case "IXH": *Out\Kind = #Z80Opnd_IXHalf : *Out\RegCode = 4 : ProcedureReturn
      Case "IXL": *Out\Kind = #Z80Opnd_IXHalf : *Out\RegCode = 5 : ProcedureReturn
      Case "IYH": *Out\Kind = #Z80Opnd_IYHalf : *Out\RegCode = 4 : ProcedureReturn
      Case "IYL": *Out\Kind = #Z80Opnd_IYHalf : *Out\RegCode = 5 : ProcedureReturn
      Case "(HL)" : *Out\Kind = #Z80Opnd_IndHL : ProcedureReturn
      Case "(BC)" : *Out\Kind = #Z80Opnd_IndBC : ProcedureReturn
      Case "(DE)" : *Out\Kind = #Z80Opnd_IndDE : ProcedureReturn
      Case "(SP)" : *Out\Kind = #Z80Opnd_IndSP : ProcedureReturn
      Case "(C)"  : *Out\Kind = #Z80Opnd_IndC : ProcedureReturn
      Case "(IX)" : *Out\Kind = #Z80Opnd_IndIX : *Out\Expr = "" : ProcedureReturn
      Case "(IY)" : *Out\Kind = #Z80Opnd_IndIY : *Out\Expr = "" : ProcedureReturn
      Case "NZ" : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 0 : ProcedureReturn
      Case "Z"  : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 1 : ProcedureReturn
      Case "NC" : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 2 : ProcedureReturn
      Case "PO" : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 4 : ProcedureReturn
      Case "PE" : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 5 : ProcedureReturn
      Case "P"  : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 6 : ProcedureReturn
      Case "M"  : *Out\Kind = #Z80Opnd_Cond : *Out\RegCode = 7 : ProcedureReturn
    EndSelect
    ; nota: "C" sozinho fica classificado Reg8 acima (mais comum) - JP/JR/
    ; CALL/RET tratam "C" como condicao explicitamente quando a posicao do
    ; operando pede uma condicao (ver EncodeJp/EncodeJr/EncodeCallRet: elas
    ; conferem Op1\Kind = #Z80Opnd_Cond OU, pro caso especial de "C" sozinho
    ; na posicao de condicao, ainda cai como Reg8 com RegCode=1 - tratado a
    ; parte on ambiguidade importa).

    ; (IX+d)/(IX-d)/(IY+d)/(IY-d) - o operando INTEIRO precisa ser exatamente
    ; essa forma (parenteses de abertura E fechamento cobrindo tudo) - e uma
    ; forma de enderecamento de hardware distinta, nao uma expressao comum.
    If Len(T) >= 2 And Left(T, 1) = "(" And Right(T, 1) = ")"
      Protected Inner.s = Mid(T, 2, Len(T) - 2)
      Protected InnerU.s = UCase(Inner)
      If Left(InnerU, 2) = "IX" And Len(Inner) > 2 And (Mid(InnerU, 3, 1) = "+" Or Mid(InnerU, 3, 1) = "-")
        *Out\Kind = #Z80Opnd_IndIX
        *Out\Expr = Mid(Inner, 3)
        ProcedureReturn
      ElseIf Left(InnerU, 2) = "IY" And Len(Inner) > 2 And (Mid(InnerU, 3, 1) = "+" Or Mid(InnerU, 3, 1) = "-")
        *Out\Kind = #Z80Opnd_IndIY
        *Out\Expr = Mid(Inner, 3)
        ProcedureReturn
      EndIf
    EndIf

    ; "(expressao)" generico = IndImm - QUALQUER operando que comece com "("
    ; e tratado como forma de memoria (nn) pelo M80/Nestor80, MESMO quando
    ; sobra texto depois do ")" que fecha esse primeiro parenteses (ex.
    ; "(FOO SHL 4) OR BAR" - confirmado contra o oraculo N80.exe: produz
    ; LD A,(nn) com nn = FOO SHL 4 OR BAR avaliado inteiro, nao LD A,n).
    ; Por isso NAO tira os parenteses aqui - Expr recebe o texto ORIGINAL
    ; inteiro (parenteses inclusos), e quem resolve o agrupamento e o
    ; proprio avaliador de expressao (que ja trata "("/")" como parenteses
    ; normais de precedencia).
    If Left(T, 1) = "("
      *Out\Kind = #Z80Opnd_IndImm
      *Out\Expr = T
      ProcedureReturn
    EndIf

    ; sobra o caso geral: expressao solta (Imm), ja preenchido no default acima
  EndProcedure

  ; Conta operandos (0/1/2) separados por virgula fora de aspas/parenteses.
  Procedure.i CountOperands(ArgsText.s)
    Protected L = Len(ArgsText), I = 1, C.s, Depth = 0, N
    If RTrimWs(Mid(ArgsText, SkipWs(ArgsText, 1))) = ""
      ProcedureReturn 0
    EndIf
    N = 1
    While I <= L
      C = Mid(ArgsText, I, 1)
      If C = Chr(34) Or C = "'"
        Protected Delim.s = C
        I + 1
        While I <= L And Mid(ArgsText, I, 1) <> Delim
          I + 1
        Wend
      ElseIf C = "("
        Depth + 1
      ElseIf C = ")"
        Depth - 1
      ElseIf C = "," And Depth = 0
        N + 1
      EndIf
      I + 1
    Wend
    ProcedureReturn N
  EndProcedure

  ; Devolve o texto cru do operando Index (1 ou 2), sem aparar espaco nas
  ; pontas (ClassifyOperand ja faz isso).
  Procedure.s GetOperand(ArgsText.s, Index.i)
    Protected L = Len(ArgsText), I = 1, C.s, Depth = 0, N = 1, Start = 1
    While I <= L
      C = Mid(ArgsText, I, 1)
      If C = Chr(34) Or C = "'"
        Protected Delim.s = C
        I + 1
        While I <= L And Mid(ArgsText, I, 1) <> Delim
          I + 1
        Wend
      ElseIf C = "("
        Depth + 1
      ElseIf C = ")"
        Depth - 1
      ElseIf C = "," And Depth = 0
        If N = Index
          ProcedureReturn Mid(ArgsText, Start, I - Start)
        EndIf
        N + 1
        Start = I + 1
      EndIf
      I + 1
    Wend
    If N = Index
      ProcedureReturn Mid(ArgsText, Start)
    EndIf
    ProcedureReturn ""
  EndProcedure

  ; So avalia de verdade quando EmitMode (pass 2) - no pass 1 devolve #True
  ; com valor 0 sem tocar no avaliador/tabela de simbolos (tamanho de
  ; instrucao Z80 nunca depende do VALOR de uma expressao, so da forma).
  Procedure.b EvalOperandExpr(Expr.s, EmitMode.b, *OutVal.Z80Addr)
    If Not EmitMode
      Z80Addr_Make(*OutVal, 0, #Z80Seg_Absolute)
      ProcedureReturn #True
    EndIf
    If Not EvalExpr(Expr, *OutVal)
      ; propaga o motivo pra LastAsmError - sem isso, todo Encode* que so faz
      ; "If Not EvalOperandExpr(...) : ProcedureReturn -1 : EndIf" devolveria
      ; erro sem mensagem nenhuma (achado real depurando sample/teste.asm).
      LastAsmError = "Expressao invalida (" + Expr + "): " + LastEvalError + LastEvalUnknownSymbol
      ProcedureReturn #False
    EndIf
    ProcedureReturn #True
  EndProcedure

  ; Idem, mas pra deslocamento de (IX+d)/(IY+d) - trata Expr="" (forma "(IX)"
  ; pura, sem deslocamento) como zero, sem chamar o avaliador.
  Procedure.b EvalDisplacement(Expr.s, EmitMode.b, *OutVal.Z80Addr)
    If Expr = ""
      Z80Addr_Make(*OutVal, 0, #Z80Seg_Absolute)
      ProcedureReturn #True
    EndIf
    ProcedureReturn EvalOperandExpr(Expr, EmitMode, *OutVal)
  EndProcedure

  ;- Familias de instrucao - cada uma devolve o numero de bytes (0-4) ou -1
  ;- (erro, ver LastAsmError). Precisam vir ANTES de EncodeInstruction() no
  ;- arquivo (PureBasic, dentro de um Module, nao resolve chamada a uma
  ;- Procedure ainda nao definida textualmente - mesma regra ja documentada
  ;- pro tokenizador de expressao).

  Procedure.i EncodeRst(*Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If Not *Op1\Present
      LastAsmError = "RST precisa de um operando (0,8,16,24,32,40,48,56)"
      ProcedureReturn -1
    EndIf
    If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V)
      ProcedureReturn -1
    EndIf
    Out(0) = $C7
    If EmitMode
      If (V\Value & 7) <> 0 Or V\Value > 56
        LastAsmError = "RST: valor invalido (precisa ser 0,8,16,24,32,40,48 ou 56): " + Str(V\Value)
        ProcedureReturn -1
      EndIf
      Out(0) = $C7 | ((V\Value / 8) << 3)
    EndIf
    ProcedureReturn 1
  EndProcedure

  Procedure.i EncodeIm(*Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If Not *Op1\Present
      LastAsmError = "IM precisa de um operando (0, 1 ou 2)"
      ProcedureReturn -1
    EndIf
    If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V)
      ProcedureReturn -1
    EndIf
    Out(0) = $ED
    If EmitMode
      Select V\Value
        Case 0 : Out(1) = $46
        Case 1 : Out(1) = $56
        Case 2 : Out(1) = $5E
        Default
          LastAsmError = "IM: valor invalido (precisa ser 0, 1 ou 2)"
          ProcedureReturn -1
      EndSelect
    EndIf
    ProcedureReturn 2
  EndProcedure

  Procedure.i EncodeEx(*Op1.Z80Operand, *Op2.Z80Operand, EmitMode.b, Array Out.a(1))
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 1 And *Op2\Kind = #Z80Opnd_Reg16 And *Op2\RegCode = 2
      Out(0) = $EB
      ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_RegAF And UCase(*Op2\Expr) = "AF'"
      Out(0) = $08
      ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_IndSP
      If *Op2\Kind = #Z80Opnd_Reg16 And *Op2\RegCode = 2
        Out(0) = $E3
        ProcedureReturn 1
      ElseIf *Op2\Kind = #Z80Opnd_IX
        Out(0) = $DD : Out(1) = $E3
        ProcedureReturn 2
      ElseIf *Op2\Kind = #Z80Opnd_IY
        Out(0) = $FD : Out(1) = $E3
        ProcedureReturn 2
      EndIf
    EndIf
    LastAsmError = "EX: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeIn(*Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If NOps <> 2
      LastAsmError = "IN precisa de 2 operandos"
      ProcedureReturn -1
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7 And *Op2\Kind = #Z80Opnd_IndImm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $DB
      If EmitMode : Out(1) = V\Value & $FF : EndIf
      ProcedureReturn 2
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op2\Kind = #Z80Opnd_IndC
      Out(0) = $ED
      Out(1) = $40 | (*Op1\RegCode << 3)
      ProcedureReturn 2
    EndIf
    LastAsmError = "IN: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeOut(*Op1.Z80Operand, *Op2.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If *Op1\Kind = #Z80Opnd_IndImm And *Op2\Kind = #Z80Opnd_Reg8 And *Op2\RegCode = 7
      If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $D3
      If EmitMode : Out(1) = V\Value & $FF : EndIf
      ProcedureReturn 2
    EndIf
    If *Op1\Kind = #Z80Opnd_IndC And *Op2\Kind = #Z80Opnd_Reg8
      Out(0) = $ED
      Out(1) = $41 | (*Op2\RegCode << 3)
      ProcedureReturn 2
    EndIf
    LastAsmError = "OUT: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodePushPop(Base.a, *Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Select *Op1\Kind
      Case #Z80Opnd_Reg16
        If *Op1\RegCode = 3
          LastAsmError = "PUSH/POP: SP nao existe aqui (o slot 11 e AF, nao SP - quis dizer AF?)"
          ProcedureReturn -1
        EndIf
        Out(0) = Base | (*Op1\RegCode << 4)
        ProcedureReturn 1
      Case #Z80Opnd_RegAF
        Out(0) = Base | (3 << 4)
        ProcedureReturn 1
      Case #Z80Opnd_IX
        Out(0) = $DD : Out(1) = Base | (2 << 4)
        ProcedureReturn 2
      Case #Z80Opnd_IY
        Out(0) = $FD : Out(1) = Base | (2 << 4)
        ProcedureReturn 2
    EndSelect
    LastAsmError = "PUSH/POP: operando invalido (precisa ser BC, DE, HL, AF, IX ou IY)"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeIncDec(IsInc.b, *Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    Protected Op8.a, Op16.a, OpIxIy.a, OpInd.a, OpHalfH.a, OpHalfL.a
    If IsInc
      Op8 = $04 : Op16 = $03 : OpIxIy = $23 : OpInd = $34 : OpHalfH = $24 : OpHalfL = $2C
    Else
      Op8 = $05 : Op16 = $0B : OpIxIy = $2B : OpInd = $35 : OpHalfH = $25 : OpHalfL = $2D
    EndIf

    Select *Op1\Kind
      Case #Z80Opnd_Reg8
        Out(0) = Op8 | (*Op1\RegCode << 3)
        ProcedureReturn 1
      Case #Z80Opnd_IndHL
        Out(0) = Op8 | (6 << 3)
        ProcedureReturn 1
      Case #Z80Opnd_Reg16
        Out(0) = Op16 | (*Op1\RegCode << 4)
        ProcedureReturn 1
      Case #Z80Opnd_IX
        Out(0) = $DD : Out(1) = OpIxIy
        ProcedureReturn 2
      Case #Z80Opnd_IY
        Out(0) = $FD : Out(1) = OpIxIy
        ProcedureReturn 2
      Case #Z80Opnd_IXHalf
        Out(0) = $DD
        If *Op1\RegCode = 4 : Out(1) = OpHalfH : Else : Out(1) = OpHalfL : EndIf
        ProcedureReturn 2
      Case #Z80Opnd_IYHalf
        Out(0) = $FD
        If *Op1\RegCode = 4 : Out(1) = OpHalfH : Else : Out(1) = OpHalfL : EndIf
        ProcedureReturn 2
      Case #Z80Opnd_IndIX
        Out(0) = $DD : Out(1) = OpInd
        If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        ProcedureReturn 3
      Case #Z80Opnd_IndIY
        Out(0) = $FD : Out(1) = OpInd
        If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        ProcedureReturn 3
    EndSelect
    LastAsmError = "INC/DEC: operando invalido"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeAluSingle(Idx.a, *Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    Protected TheOp.Z80Operand
    If NOps = 2
      If *Op1\Kind <> #Z80Opnd_Reg8 Or *Op1\RegCode <> 7
        LastAsmError = "So A pode ser o primeiro operando quando dois sao dados"
        ProcedureReturn -1
      EndIf
      CopyStructure(*Op2, @TheOp, Z80Operand)
    ElseIf NOps = 1
      CopyStructure(*Op1, @TheOp, Z80Operand)
    Else
      LastAsmError = "Precisa de 1 operando (ou 2, com A como o primeiro)"
      ProcedureReturn -1
    EndIf

    Select TheOp\Kind
      Case #Z80Opnd_Reg8
        Out(0) = $80 | (Idx << 3) | TheOp\RegCode
        ProcedureReturn 1
      Case #Z80Opnd_IndHL
        Out(0) = $80 | (Idx << 3) | 6
        ProcedureReturn 1
      Case #Z80Opnd_IXHalf
        Out(0) = $DD : Out(1) = $80 | (Idx << 3) | TheOp\RegCode
        ProcedureReturn 2
      Case #Z80Opnd_IYHalf
        Out(0) = $FD : Out(1) = $80 | (Idx << 3) | TheOp\RegCode
        ProcedureReturn 2
      Case #Z80Opnd_IndIX
        Out(0) = $DD : Out(1) = $86 | (Idx << 3)
        If Not EvalDisplacement(TheOp\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        ProcedureReturn 3
      Case #Z80Opnd_IndIY
        Out(0) = $FD : Out(1) = $86 | (Idx << 3)
        If Not EvalDisplacement(TheOp\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        ProcedureReturn 3
      Case #Z80Opnd_IndImm
        LastAsmError = "So (HL), (IX+d) ou (IY+d) sao validos aqui, nao (nn)"
        ProcedureReturn -1
      Case #Z80Opnd_Imm
        If Not EvalOperandExpr(TheOp\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        Out(0) = $C6 | (Idx << 3)
        If EmitMode : Out(1) = V\Value & $FF : EndIf
        ProcedureReturn 2
    EndSelect
    LastAsmError = "Operando invalido"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeAdd(*Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    If NOps <> 2
      LastAsmError = "ADD precisa de 2 operandos"
      ProcedureReturn -1
    EndIf

    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7
      ProcedureReturn EncodeAluSingle(0, *Op1, *Op2, 2, EmitMode, Out())
    EndIf

    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 2
      If *Op2\Kind = #Z80Opnd_Reg16
        Out(0) = $09 | (*Op2\RegCode << 4)
        ProcedureReturn 1
      EndIf
      LastAsmError = "ADD HL,?: segundo operando precisa ser BC, DE, HL ou SP"
      ProcedureReturn -1
    EndIf

    If *Op1\Kind = #Z80Opnd_IX
      Out(0) = $DD
      If *Op2\Kind = #Z80Opnd_Reg16 And *Op2\RegCode <> 2
        Out(1) = $09 | (*Op2\RegCode << 4)
        ProcedureReturn 2
      ElseIf *Op2\Kind = #Z80Opnd_IX
        Out(1) = $09 | (2 << 4)
        ProcedureReturn 2
      EndIf
      LastAsmError = "ADD IX,?: segundo operando precisa ser BC, DE, IX ou SP"
      ProcedureReturn -1
    EndIf

    If *Op1\Kind = #Z80Opnd_IY
      Out(0) = $FD
      If *Op2\Kind = #Z80Opnd_Reg16 And *Op2\RegCode <> 2
        Out(1) = $09 | (*Op2\RegCode << 4)
        ProcedureReturn 2
      ElseIf *Op2\Kind = #Z80Opnd_IY
        Out(1) = $09 | (2 << 4)
        ProcedureReturn 2
      EndIf
      LastAsmError = "ADD IY,?: segundo operando precisa ser BC, DE, IY ou SP"
      ProcedureReturn -1
    EndIf

    LastAsmError = "ADD: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeAdcSbc(IsAdc.b, *Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    If NOps <> 2
      LastAsmError = "ADC/SBC precisa de 2 operandos"
      ProcedureReturn -1
    EndIf

    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7
      If IsAdc
        ProcedureReturn EncodeAluSingle(1, *Op1, *Op2, 2, EmitMode, Out())
      Else
        ProcedureReturn EncodeAluSingle(3, *Op1, *Op2, 2, EmitMode, Out())
      EndIf
    EndIf

    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 2 And *Op2\Kind = #Z80Opnd_Reg16
      Out(0) = $ED
      If IsAdc
        Out(1) = $4A | (*Op2\RegCode << 4)
      Else
        Out(1) = $42 | (*Op2\RegCode << 4)
      EndIf
      ProcedureReturn 2
    EndIf

    LastAsmError = "ADC/SBC: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  ; "C" sozinho classifica como Reg8 (RegCode=1) em ClassifyOperand, nao como
  ; #Z80Opnd_Cond (colisao de nome registrador-C/condicao-C - so "C" tem esse
  ; problema, NZ/Z/NC/PO/PE/P/M nunca colidem com registrador nenhum). Aqui e
  ; onde a ambiguidade e resolvida: JP/JR/CALL/RET aceitam "C" como condicao
  ; (RegCode de condicao = 3) alem da forma #Z80Opnd_Cond normal.
  Procedure.i CondCodeOf(*Op.Z80Operand)
    If *Op\Kind = #Z80Opnd_Cond
      ProcedureReturn *Op\RegCode
    EndIf
    If *Op\Kind = #Z80Opnd_Reg8 And *Op\RegCode = 1
      ProcedureReturn 3 ; "C" - condicao C tem RegCode 3, nao 1 (esse e o do registrador)
    EndIf
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeJp(*Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If NOps = 1
      Select *Op1\Kind
        Case #Z80Opnd_IndHL
          Out(0) = $E9
          ProcedureReturn 1
        Case #Z80Opnd_IndIX
          Out(0) = $DD : Out(1) = $E9
          ProcedureReturn 2
        Case #Z80Opnd_IndIY
          Out(0) = $FD : Out(1) = $E9
          ProcedureReturn 2
        Case #Z80Opnd_Imm
          If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
          Out(0) = $C3
          If EmitMode
            Out(1) = V\Value & $FF
            Out(2) = (V\Value >> 8) & $FF
          EndIf
          ProcedureReturn 3
      EndSelect
      LastAsmError = "JP: operando invalido"
      ProcedureReturn -1
    ElseIf NOps = 2
      Protected CCjp.i = CondCodeOf(*Op1)
      If CCjp < 0
        LastAsmError = "JP cc,nn: primeiro operando precisa ser uma condicao (NZ,Z,NC,C,PO,PE,P,M)"
        ProcedureReturn -1
      EndIf
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $C2 | (CCjp << 3)
      If EmitMode
        Out(1) = V\Value & $FF
        Out(2) = (V\Value >> 8) & $FF
      EndIf
      ProcedureReturn 3
    EndIf
    LastAsmError = "JP: numero de operandos invalido"
    ProcedureReturn -1
  EndProcedure

  ; JR/DJNZ: deslocamento relativo = alvo - (CurLoc + 2) - CurLoc precisa
  ; estar no endereco desta instrucao (o driver de 2 passes garante isso).
  Procedure.i EncodeJr(*Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    Protected TargetExpr.s
    Protected BaseOp.a

    If NOps = 1
      BaseOp = $18
      TargetExpr = *Op1\Expr
    ElseIf NOps = 2
      Protected CCjr.i = CondCodeOf(*Op1)
      If CCjr < 0 Or CCjr > 3
        LastAsmError = "JR cc,e: condicao precisa ser NZ, Z, NC ou C"
        ProcedureReturn -1
      EndIf
      Select CCjr
        Case 0 : BaseOp = $20
        Case 1 : BaseOp = $28
        Case 2 : BaseOp = $30
        Case 3 : BaseOp = $38
      EndSelect
      TargetExpr = *Op2\Expr
    Else
      LastAsmError = "JR: numero de operandos invalido"
      ProcedureReturn -1
    EndIf

    Out(0) = BaseOp
    If Not EmitMode
      ProcedureReturn 2
    EndIf

    If Not EvalExpr(TargetExpr, @V)
      LastAsmError = "JR: " + LastEvalError + LastEvalUnknownSymbol
      ProcedureReturn -1
    EndIf
    Protected Disp.i = V\Value - (CurLoc\Value + 2)
    If Disp < -128 Or Disp > 127
      LastAsmError = "JR: alvo fora de alcance (-128..127), deslocamento = " + Str(Disp)
      ProcedureReturn -1
    EndIf
    Out(1) = Disp & $FF
    ProcedureReturn 2
  EndProcedure

  Procedure.i EncodeDjnz(*Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    Out(0) = $10
    If Not EmitMode
      ProcedureReturn 2
    EndIf
    If Not EvalExpr(*Op1\Expr, @V)
      LastAsmError = "DJNZ: " + LastEvalError + LastEvalUnknownSymbol
      ProcedureReturn -1
    EndIf
    Protected Disp.i = V\Value - (CurLoc\Value + 2)
    If Disp < -128 Or Disp > 127
      LastAsmError = "DJNZ: alvo fora de alcance (-128..127), deslocamento = " + Str(Disp)
      ProcedureReturn -1
    EndIf
    Out(1) = Disp & $FF
    ProcedureReturn 2
  EndProcedure

  Procedure.i EncodeCallRet(IsCall.b, *Op1.Z80Operand, *Op2.Z80Operand, NOps.i, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr
    If IsCall
      If NOps = 1
        If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        Out(0) = $CD
        If EmitMode
          Out(1) = V\Value & $FF
          Out(2) = (V\Value >> 8) & $FF
        EndIf
        ProcedureReturn 3
      ElseIf NOps = 2
        Protected CCcall.i = CondCodeOf(*Op1)
        If CCcall < 0
          LastAsmError = "CALL cc,nn: primeiro operando precisa ser uma condicao"
          ProcedureReturn -1
        EndIf
        If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        Out(0) = $C4 | (CCcall << 3)
        If EmitMode
          Out(1) = V\Value & $FF
          Out(2) = (V\Value >> 8) & $FF
        EndIf
        ProcedureReturn 3
      EndIf
      LastAsmError = "CALL: numero de operandos invalido"
      ProcedureReturn -1
    Else
      If NOps = 0
        Out(0) = $C9
        ProcedureReturn 1
      ElseIf NOps = 1
        Protected CCret.i = CondCodeOf(*Op1)
        If CCret < 0
          LastAsmError = "RET cc: operando precisa ser uma condicao"
          ProcedureReturn -1
        EndIf
        Out(0) = $C0 | (CCret << 3)
        ProcedureReturn 1
      EndIf
      LastAsmError = "RET: numero de operandos invalido"
      ProcedureReturn -1
    EndIf
  EndProcedure

  Procedure.i EncodeCbShift(M.s, *Op1.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected Idx.a, V.Z80Addr
    Select M
      Case "RLC" : Idx = 0
      Case "RRC" : Idx = 1
      Case "RL"  : Idx = 2
      Case "RR"  : Idx = 3
      Case "SLA" : Idx = 4
      Case "SRA" : Idx = 5
      Case "SLL" : Idx = 6
      Case "SRL" : Idx = 7
    EndSelect

    Select *Op1\Kind
      Case #Z80Opnd_Reg8
        Out(0) = $CB : Out(1) = (Idx << 3) | *Op1\RegCode
        ProcedureReturn 2
      Case #Z80Opnd_IndHL
        Out(0) = $CB : Out(1) = (Idx << 3) | 6
        ProcedureReturn 2
      Case #Z80Opnd_IndIX
        Out(0) = $DD : Out(1) = $CB
        If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        Out(3) = (Idx << 3) | 6
        ProcedureReturn 4
      Case #Z80Opnd_IndIY
        Out(0) = $FD : Out(1) = $CB
        If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        Out(3) = (Idx << 3) | 6
        ProcedureReturn 4
    EndSelect
    LastAsmError = M + ": operando invalido"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeCbBit(M.s, *Op1.Z80Operand, *Op2.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected Base.a, V.Z80Addr, Bv.Z80Addr, B.u
    Select M
      Case "BIT" : Base = $40
      Case "RES" : Base = $80
      Case "SET" : Base = $C0
    EndSelect

    If Not EvalOperandExpr(*Op1\Expr, EmitMode, @Bv) : ProcedureReturn -1 : EndIf
    If EmitMode
      If Bv\Value > 7
        LastAsmError = M + ": numero de bit precisa ser 0-7"
        ProcedureReturn -1
      EndIf
      B = Bv\Value
    EndIf

    Select *Op2\Kind
      Case #Z80Opnd_Reg8
        Out(0) = $CB : Out(1) = Base | (B << 3) | *Op2\RegCode
        ProcedureReturn 2
      Case #Z80Opnd_IndHL
        Out(0) = $CB : Out(1) = Base | (B << 3) | 6
        ProcedureReturn 2
      Case #Z80Opnd_IndIX
        Out(0) = $DD : Out(1) = $CB
        If Not EvalDisplacement(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        Out(3) = Base | (B << 3) | 6
        ProcedureReturn 4
      Case #Z80Opnd_IndIY
        Out(0) = $FD : Out(1) = $CB
        If Not EvalDisplacement(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
        If EmitMode : Out(2) = V\Value & $FF : EndIf
        Out(3) = Base | (B << 3) | 6
        ProcedureReturn 4
    EndSelect
    LastAsmError = M + ": segundo operando invalido"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeLd(*Op1.Z80Operand, *Op2.Z80Operand, EmitMode.b, Array Out.a(1))
    Protected V.Z80Addr

    If Not *Op1\Present Or Not *Op2\Present
      LastAsmError = "LD precisa de 2 operandos"
      ProcedureReturn -1
    EndIf

    ; --- LD A,I / LD I,A / LD A,R / LD R,A (formas fixas - "I"/"R" nao tem
    ; Kind proprio, caem como Imm com Expr="I"/"R") ---
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7 And *Op2\Kind = #Z80Opnd_Imm
      If UCase(*Op2\Expr) = "I"
        Out(0) = $ED : Out(1) = $57 : ProcedureReturn 2
      ElseIf UCase(*Op2\Expr) = "R"
        Out(0) = $ED : Out(1) = $5F : ProcedureReturn 2
      EndIf
    EndIf
    If *Op2\Kind = #Z80Opnd_Reg8 And *Op2\RegCode = 7 And *Op1\Kind = #Z80Opnd_Imm
      If UCase(*Op1\Expr) = "I"
        Out(0) = $ED : Out(1) = $47 : ProcedureReturn 2
      ElseIf UCase(*Op1\Expr) = "R"
        Out(0) = $ED : Out(1) = $4F : ProcedureReturn 2
      EndIf
    EndIf

    ; --- LD r,r' (incluindo (HL) dos dois lados, exceto (HL),(HL) = HALT) ---
    If (*Op1\Kind = #Z80Opnd_Reg8 Or *Op1\Kind = #Z80Opnd_IndHL) And (*Op2\Kind = #Z80Opnd_Reg8 Or *Op2\Kind = #Z80Opnd_IndHL)
      If *Op1\Kind = #Z80Opnd_IndHL And *Op2\Kind = #Z80Opnd_IndHL
        LastAsmError = "LD (HL),(HL) nao existe (seria HALT)"
        ProcedureReturn -1
      EndIf
      Protected R1.a, R2.a
      If *Op1\Kind = #Z80Opnd_IndHL : R1 = 6 : Else : R1 = *Op1\RegCode : EndIf
      If *Op2\Kind = #Z80Opnd_IndHL : R2 = 6 : Else : R2 = *Op2\RegCode : EndIf
      Out(0) = $40 | (R1 << 3) | R2
      ProcedureReturn 1
    EndIf

    ; --- LD r,n / LD (HL),n ---
    If (*Op1\Kind = #Z80Opnd_Reg8 Or *Op1\Kind = #Z80Opnd_IndHL) And *Op2\Kind = #Z80Opnd_Imm
      Protected R1b.a
      If *Op1\Kind = #Z80Opnd_IndHL : R1b = 6 : Else : R1b = *Op1\RegCode : EndIf
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $06 | (R1b << 3)
      If EmitMode : Out(1) = V\Value & $FF : EndIf
      ProcedureReturn 2
    EndIf

    ; --- LD A,(BC)/(DE) ; LD (BC)/(DE),A ---
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7 And *Op2\Kind = #Z80Opnd_IndBC
      Out(0) = $0A : ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7 And *Op2\Kind = #Z80Opnd_IndDE
      Out(0) = $1A : ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_IndBC And *Op2\Kind = #Z80Opnd_Reg8 And *Op2\RegCode = 7
      Out(0) = $02 : ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_IndDE And *Op2\Kind = #Z80Opnd_Reg8 And *Op2\RegCode = 7
      Out(0) = $12 : ProcedureReturn 1
    EndIf

    ; --- LD A,(nn) ; LD (nn),A ---
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op1\RegCode = 7 And *Op2\Kind = #Z80Opnd_IndImm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $3A
      If EmitMode : Out(1) = V\Value & $FF : Out(2) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IndImm And *Op2\Kind = #Z80Opnd_Reg8 And *Op2\RegCode = 7
      If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $32
      If EmitMode : Out(1) = V\Value & $FF : Out(2) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 3
    EndIf

    ; --- LD HL,(nn) ; LD (nn),HL ; LD dd,(nn)/(nn),dd (ED, BC/DE/SP) ---
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op2\Kind = #Z80Opnd_IndImm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If *Op1\RegCode = 2
        Out(0) = $2A
        If EmitMode : Out(1) = V\Value & $FF : Out(2) = (V\Value >> 8) & $FF : EndIf
        ProcedureReturn 3
      Else
        Out(0) = $ED : Out(1) = $4B | (*Op1\RegCode << 4)
        If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
        ProcedureReturn 4
      EndIf
    EndIf
    If *Op1\Kind = #Z80Opnd_IndImm And *Op2\Kind = #Z80Opnd_Reg16
      If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If *Op2\RegCode = 2
        Out(0) = $22
        If EmitMode : Out(1) = V\Value & $FF : Out(2) = (V\Value >> 8) & $FF : EndIf
        ProcedureReturn 3
      Else
        Out(0) = $ED : Out(1) = $43 | (*Op2\RegCode << 4)
        If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
        ProcedureReturn 4
      EndIf
    EndIf

    ; --- LD IX,(nn)/LD(nn),IX ; LD IY,(nn)/LD(nn),IY ---
    If *Op1\Kind = #Z80Opnd_IX And *Op2\Kind = #Z80Opnd_IndImm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $DD : Out(1) = $2A
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf
    If *Op1\Kind = #Z80Opnd_IndImm And *Op2\Kind = #Z80Opnd_IX
      If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $DD : Out(1) = $22
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf
    If *Op1\Kind = #Z80Opnd_IY And *Op2\Kind = #Z80Opnd_IndImm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $FD : Out(1) = $2A
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf
    If *Op1\Kind = #Z80Opnd_IndImm And *Op2\Kind = #Z80Opnd_IY
      If Not EvalOperandExpr(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $FD : Out(1) = $22
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf

    ; --- LD dd,nn / LD IX,nn / LD IY,nn (16-bit imediato) ---
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op2\Kind = #Z80Opnd_Imm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $01 | (*Op1\RegCode << 4)
      If EmitMode : Out(1) = V\Value & $FF : Out(2) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IX And *Op2\Kind = #Z80Opnd_Imm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $DD : Out(1) = $21
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf
    If *Op1\Kind = #Z80Opnd_IY And *Op2\Kind = #Z80Opnd_Imm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $FD : Out(1) = $21
      If EmitMode : Out(2) = V\Value & $FF : Out(3) = (V\Value >> 8) & $FF : EndIf
      ProcedureReturn 4
    EndIf

    ; --- LD SP,HL / LD SP,IX / LD SP,IY ---
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 3 And *Op2\Kind = #Z80Opnd_Reg16 And *Op2\RegCode = 2
      Out(0) = $F9 : ProcedureReturn 1
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 3 And *Op2\Kind = #Z80Opnd_IX
      Out(0) = $DD : Out(1) = $F9 : ProcedureReturn 2
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg16 And *Op1\RegCode = 3 And *Op2\Kind = #Z80Opnd_IY
      Out(0) = $FD : Out(1) = $F9 : ProcedureReturn 2
    EndIf

    ; --- LD r,(IX+d) / LD (IX+d),r / LD (IX+d),n (e IY) ---
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op2\Kind = #Z80Opnd_IndIX
      Out(0) = $DD : Out(1) = $46 | (*Op1\RegCode << 3)
      If Not EvalDisplacement(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_Reg8 And *Op2\Kind = #Z80Opnd_IndIY
      Out(0) = $FD : Out(1) = $46 | (*Op1\RegCode << 3)
      If Not EvalDisplacement(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IndIX And *Op2\Kind = #Z80Opnd_Reg8
      Out(0) = $DD : Out(1) = $70 | *Op2\RegCode
      If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IndIY And *Op2\Kind = #Z80Opnd_Reg8
      Out(0) = $FD : Out(1) = $70 | *Op2\RegCode
      If Not EvalDisplacement(*Op1\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IndIX And *Op2\Kind = #Z80Opnd_Imm
      Protected D1.Z80Addr, N1.Z80Addr
      Out(0) = $DD : Out(1) = $36
      If Not EvalDisplacement(*Op1\Expr, EmitMode, @D1) : ProcedureReturn -1 : EndIf
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @N1) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = D1\Value & $FF : Out(3) = N1\Value & $FF : EndIf
      ProcedureReturn 4
    EndIf
    If *Op1\Kind = #Z80Opnd_IndIY And *Op2\Kind = #Z80Opnd_Imm
      Protected D2.Z80Addr, N2.Z80Addr
      Out(0) = $FD : Out(1) = $36
      If Not EvalDisplacement(*Op1\Expr, EmitMode, @D2) : ProcedureReturn -1 : EndIf
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @N2) : ProcedureReturn -1 : EndIf
      If EmitMode : Out(2) = D2\Value & $FF : Out(3) = N2\Value & $FF : EndIf
      ProcedureReturn 4
    EndIf

    ; --- IXH/IXL/IYH/IYL (indocumentado - subconjunto pratico: LD com n,
    ; LD com A/B/C/D/E ou o outro half do MESMO indice, sem cruzar IX/IY) ---
    If *Op1\Kind = #Z80Opnd_IXHalf And *Op2\Kind = #Z80Opnd_Imm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $DD : Out(1) = $06 | (*Op1\RegCode << 3)
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IYHalf And *Op2\Kind = #Z80Opnd_Imm
      If Not EvalOperandExpr(*Op2\Expr, EmitMode, @V) : ProcedureReturn -1 : EndIf
      Out(0) = $FD : Out(1) = $06 | (*Op1\RegCode << 3)
      If EmitMode : Out(2) = V\Value & $FF : EndIf
      ProcedureReturn 3
    EndIf
    If *Op1\Kind = #Z80Opnd_IXHalf And (*Op2\Kind = #Z80Opnd_Reg8 Or *Op2\Kind = #Z80Opnd_IXHalf)
      Out(0) = $DD : Out(1) = $40 | (*Op1\RegCode << 3) | *Op2\RegCode
      ProcedureReturn 2
    EndIf
    If *Op2\Kind = #Z80Opnd_IXHalf And *Op1\Kind = #Z80Opnd_Reg8
      Out(0) = $DD : Out(1) = $40 | (*Op1\RegCode << 3) | *Op2\RegCode
      ProcedureReturn 2
    EndIf
    If *Op1\Kind = #Z80Opnd_IYHalf And (*Op2\Kind = #Z80Opnd_Reg8 Or *Op2\Kind = #Z80Opnd_IYHalf)
      Out(0) = $FD : Out(1) = $40 | (*Op1\RegCode << 3) | *Op2\RegCode
      ProcedureReturn 2
    EndIf
    If *Op2\Kind = #Z80Opnd_IYHalf And *Op1\Kind = #Z80Opnd_Reg8
      Out(0) = $FD : Out(1) = $40 | (*Op1\RegCode << 3) | *Op2\RegCode
      ProcedureReturn 2
    EndIf

    LastAsmError = "LD: combinacao de operandos invalida"
    ProcedureReturn -1
  EndProcedure

  Procedure.i EncodeInstruction(Mnemonic.s, ArgsText.s, EmitMode.b, Array Out.a(1))
    Protected M.s = UCase(Mnemonic)
    Protected NOps = CountOperands(ArgsText)
    Protected Op1.Z80Operand, Op2.Z80Operand

    LastAsmError = ""

    If NOps >= 1
      ClassifyOperand(GetOperand(ArgsText, 1), @Op1)
    Else
      Op1\Kind = #Z80Opnd_None : Op1\Present = #False
    EndIf
    If NOps >= 2
      ClassifyOperand(GetOperand(ArgsText, 2), @Op2)
    Else
      Op2\Kind = #Z80Opnd_None : Op2\Present = #False
    EndIf

    Select M
      Case "NOP"  : Out(0) = $00 : ProcedureReturn 1
      Case "HALT" : Out(0) = $76 : ProcedureReturn 1
      Case "DI"   : Out(0) = $F3 : ProcedureReturn 1
      Case "EI"   : Out(0) = $FB : ProcedureReturn 1
      Case "DAA"  : Out(0) = $27 : ProcedureReturn 1
      Case "CPL"  : Out(0) = $2F : ProcedureReturn 1
      Case "CCF"  : Out(0) = $3F : ProcedureReturn 1
      Case "SCF"  : Out(0) = $37 : ProcedureReturn 1
      Case "RLCA" : Out(0) = $07 : ProcedureReturn 1
      Case "RLA"  : Out(0) = $17 : ProcedureReturn 1
      Case "RRCA" : Out(0) = $0F : ProcedureReturn 1
      Case "RRA"  : Out(0) = $1F : ProcedureReturn 1
      Case "EXX"  : Out(0) = $D9 : ProcedureReturn 1
      Case "NEG"  : Out(0) = $ED : Out(1) = $44 : ProcedureReturn 2
      Case "RETN" : Out(0) = $ED : Out(1) = $45 : ProcedureReturn 2
      Case "RETI" : Out(0) = $ED : Out(1) = $4D : ProcedureReturn 2
      Case "RLD"  : Out(0) = $ED : Out(1) = $6F : ProcedureReturn 2
      Case "RRD"  : Out(0) = $ED : Out(1) = $67 : ProcedureReturn 2
      Case "LDI"  : Out(0) = $ED : Out(1) = $A0 : ProcedureReturn 2
      Case "LDD"  : Out(0) = $ED : Out(1) = $A8 : ProcedureReturn 2
      Case "LDIR" : Out(0) = $ED : Out(1) = $B0 : ProcedureReturn 2
      Case "LDDR" : Out(0) = $ED : Out(1) = $B8 : ProcedureReturn 2
      Case "CPI"  : Out(0) = $ED : Out(1) = $A1 : ProcedureReturn 2
      Case "CPD"  : Out(0) = $ED : Out(1) = $A9 : ProcedureReturn 2
      Case "CPIR" : Out(0) = $ED : Out(1) = $B1 : ProcedureReturn 2
      Case "CPDR" : Out(0) = $ED : Out(1) = $B9 : ProcedureReturn 2
      Case "INI"  : Out(0) = $ED : Out(1) = $A2 : ProcedureReturn 2
      Case "IND"  : Out(0) = $ED : Out(1) = $AA : ProcedureReturn 2
      Case "INIR" : Out(0) = $ED : Out(1) = $B2 : ProcedureReturn 2
      Case "INDR" : Out(0) = $ED : Out(1) = $BA : ProcedureReturn 2
      Case "OUTI" : Out(0) = $ED : Out(1) = $A3 : ProcedureReturn 2
      Case "OUTD" : Out(0) = $ED : Out(1) = $AB : ProcedureReturn 2
      Case "OTIR" : Out(0) = $ED : Out(1) = $B3 : ProcedureReturn 2
      Case "OTDR" : Out(0) = $ED : Out(1) = $BB : ProcedureReturn 2
      Case "RST"  : ProcedureReturn EncodeRst(@Op1, EmitMode, Out())
      Case "IM"   : ProcedureReturn EncodeIm(@Op1, EmitMode, Out())
      Case "EX"   : ProcedureReturn EncodeEx(@Op1, @Op2, EmitMode, Out())
      Case "IN"   : ProcedureReturn EncodeIn(@Op1, @Op2, NOps, EmitMode, Out())
      Case "OUT"  : ProcedureReturn EncodeOut(@Op1, @Op2, EmitMode, Out())
      Case "PUSH" : ProcedureReturn EncodePushPop($C5, @Op1, EmitMode, Out())
      Case "POP"  : ProcedureReturn EncodePushPop($C1, @Op1, EmitMode, Out())
      Case "INC"  : ProcedureReturn EncodeIncDec(#True, @Op1, EmitMode, Out())
      Case "DEC"  : ProcedureReturn EncodeIncDec(#False, @Op1, EmitMode, Out())
      Case "ADD"  : ProcedureReturn EncodeAdd(@Op1, @Op2, NOps, EmitMode, Out())
      Case "ADC"  : ProcedureReturn EncodeAdcSbc(#True, @Op1, @Op2, NOps, EmitMode, Out())
      Case "SBC"  : ProcedureReturn EncodeAdcSbc(#False, @Op1, @Op2, NOps, EmitMode, Out())
      Case "SUB"  : ProcedureReturn EncodeAluSingle(2, @Op1, @Op2, NOps, EmitMode, Out())
      Case "AND"  : ProcedureReturn EncodeAluSingle(4, @Op1, @Op2, NOps, EmitMode, Out())
      Case "XOR"  : ProcedureReturn EncodeAluSingle(5, @Op1, @Op2, NOps, EmitMode, Out())
      Case "OR"   : ProcedureReturn EncodeAluSingle(6, @Op1, @Op2, NOps, EmitMode, Out())
      Case "CP"   : ProcedureReturn EncodeAluSingle(7, @Op1, @Op2, NOps, EmitMode, Out())
      Case "LD"   : ProcedureReturn EncodeLd(@Op1, @Op2, EmitMode, Out())
      Case "JP"   : ProcedureReturn EncodeJp(@Op1, @Op2, NOps, EmitMode, Out())
      Case "JR"   : ProcedureReturn EncodeJr(@Op1, @Op2, NOps, EmitMode, Out())
      Case "DJNZ" : ProcedureReturn EncodeDjnz(@Op1, EmitMode, Out())
      Case "CALL" : ProcedureReturn EncodeCallRet(#True, @Op1, @Op2, NOps, EmitMode, Out())
      Case "RET"  : ProcedureReturn EncodeCallRet(#False, @Op1, @Op2, NOps, EmitMode, Out())
      Case "RLC", "RRC", "RL", "RR", "SLA", "SRA", "SLL", "SRL"
        ProcedureReturn EncodeCbShift(M, @Op1, EmitMode, Out())
      Case "BIT", "SET", "RES"
        ProcedureReturn EncodeCbBit(M, @Op1, @Op2, EmitMode, Out())
    EndSelect

    LastAsmError = "Mnemonico Z80 desconhecido: " + Mnemonic
    ProcedureReturn -1
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Driver de 2 passes - so absoluto por enquanto (ORG define o contador de
  ;- localizacao; rotulo/EQU/DEFL/ASET; instrucoes de CPU via
  ;- EncodeInstruction; ASEG/CSEG/DSEG/COMMON/PUBLIC/EXTRN reconhecidas sem
  ;- efeito pleno - Fase B; DB/DW/DS/DC/DEFZ/condicionais/macros ainda nao -
  ;- proximas tarefas). Reprocessa o texto-fonte inteiro do zero em cada
  ;- pass (mesma estrategia do proprio Nestor80 - ver docs/resumo-asm.md),
  ;- entao nao precisa de lista de fixups: no pass 2 todo rotulo definido em
  ;- QUALQUER lugar do arquivo ja esta na tabela de simbolos.
  ;- ------------------------------------------------------------

  Global AsmErrorLine.i
  Global AsmErrorText.s
  Global MinAddrTouched.i, MaxAddrTouched.i, AnyByteWritten.b

  Procedure.i GetAssembleErrorLine()
    ProcedureReturn AsmErrorLine
  EndProcedure

  Procedure.s GetAssembleErrorText()
    ProcedureReturn AsmErrorText
  EndProcedure

  Procedure.u GetAssembleStartAddr()
    ProcedureReturn MinAddrTouched & $FFFF
  EndProcedure

  Procedure.u GetAssembleEndAddr()
    ProcedureReturn MaxAddrTouched & $FFFF
  EndProcedure

  Procedure SplitSourceLines(SourceText.s, List Lines.s())
    ClearList(Lines())
    Protected Norm.s = ReplaceString(SourceText, Chr(13) + Chr(10), Chr(10))
    Norm = ReplaceString(Norm, Chr(13), Chr(10))
    Protected N = CountString(Norm, Chr(10)) + 1
    Protected Idx
    For Idx = 1 To N
      AddElement(Lines())
      Lines() = StringField(Norm, Idx, Chr(10))
    Next
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Diretivas de dados (DB/DEFB/DEFM, DW/DEFW, DS/DEFS, DC, DZ/DEFZ) - ver
  ;- docs/reference/nestor80-language.md. Precisam vir ANTES de RunOnePass
  ;- (mesma regra de forward-reference dentro de um Module).
  ;- ------------------------------------------------------------

  ; Um operando de DB/DC/DZ: string entre aspas (qualquer tamanho, aspa
  ; dobrada = aspa literal, mesma regra de TokenizeExpr) vira bytes crus dos
  ; caracteres; senao e uma expressao numerica de 1 byte (& $FF). Bytes
  ; ficam sempre conhecidos em quantidade mesmo no pass 1 (uma expressao
  ; numerica sempre gera exatamente 1 byte, independente do valor - so o
  ; VALOR muda entre passes, nunca a contagem).
  Procedure.b ExpandDataOperand(Text.s, EmitMode.b, List OutBytes.a())
    Protected T.s = RTrimWs(Mid(Text, SkipWs(Text, 1)))
    Protected V.Z80Addr
    Protected Idx

    If Len(T) >= 2 And (Left(T, 1) = Chr(34) Or Left(T, 1) = "'") And Right(T, 1) = Left(T, 1)
      Protected Delim.s = Left(T, 1)
      Protected Body.s = Mid(T, 2, Len(T) - 2)
      Body = ReplaceString(Body, Delim + Delim, Delim)
      For Idx = 1 To Len(Body)
        AddElement(OutBytes())
        OutBytes() = Asc(Mid(Body, Idx, 1)) & $FF
      Next
      ProcedureReturn #True
    EndIf

    If Not EvalOperandExpr(T, EmitMode, @V)
      ProcedureReturn #False
    EndIf
    AddElement(OutBytes())
    OutBytes() = V\Value & $FF
    ProcedureReturn #True
  EndProcedure

  ; Devolve #True/#False (erro, ver LastAsmError). OutBytes (List, cresce
  ; livre - nenhuma diretiva de dados tem tamanho maximo fixo, diferente de
  ; instrucao de CPU) recebe os bytes gerados. Em pass 1 (EmitMode=#False)
  ; a CONTAGEM de bytes ja sai certa sem avaliar valor nenhum (ExpandDataOperand/
  ; EvalOperandExpr ja garantem isso) - excecao: o TAMANHO de DS precisa ser
  ; conhecido de verdade ja no pass 1 (LR:1959, nao pode depender de rotulo
  ; definido so depois - por isso usa EvalExpr direto, nao EvalOperandExpr).
  Procedure.b EncodeDataDirective(Op.s, ArgsText.s, EmitMode.b, List OutBytes.a())
    ClearList(OutBytes())
    Protected NOps = CountOperands(ArgsText)
    Protected Idx

    Select Op
      Case "DB", "DEFB", "DEFM"
        If NOps = 0
          LastAsmError = Op + ": precisa de pelo menos um operando"
          ProcedureReturn #False
        EndIf
        For Idx = 1 To NOps
          If Not ExpandDataOperand(GetOperand(ArgsText, Idx), EmitMode, OutBytes())
            ProcedureReturn #False
          EndIf
        Next
        ProcedureReturn #True

      Case "DZ", "DEFZ"
        If NOps = 0
          LastAsmError = Op + ": precisa de pelo menos um operando"
          ProcedureReturn #False
        EndIf
        For Idx = 1 To NOps
          If Not ExpandDataOperand(GetOperand(ArgsText, Idx), EmitMode, OutBytes())
            ProcedureReturn #False
          EndIf
        Next
        AddElement(OutBytes())
        OutBytes() = 0
        ProcedureReturn #True

      Case "DC"
        If NOps = 0
          LastAsmError = "DC: precisa de pelo menos um operando"
          ProcedureReturn #False
        EndIf
        For Idx = 1 To NOps
          If Not ExpandDataOperand(GetOperand(ArgsText, Idx), EmitMode, OutBytes())
            ProcedureReturn #False
          EndIf
        Next
        If EmitMode And ListSize(OutBytes()) > 0
          LastElement(OutBytes())
          OutBytes() = OutBytes() | $80
        EndIf
        ProcedureReturn #True

      Case "DW", "DEFW"
        If NOps = 0
          LastAsmError = Op + ": precisa de pelo menos um operando"
          ProcedureReturn #False
        EndIf
        Protected VW.Z80Addr
        For Idx = 1 To NOps
          If Not EvalOperandExpr(GetOperand(ArgsText, Idx), EmitMode, @VW)
            ProcedureReturn #False
          EndIf
          AddElement(OutBytes()) : OutBytes() = VW\Value & $FF
          AddElement(OutBytes()) : OutBytes() = (VW\Value >> 8) & $FF
        Next
        ProcedureReturn #True

      Case "DS", "DEFS"
        If NOps < 1 Or NOps > 2
          LastAsmError = "DS: precisa de 1 ou 2 operandos (tamanho[,valor])"
          ProcedureReturn #False
        EndIf
        Protected SizeV.Z80Addr
        If Not EvalExpr(GetOperand(ArgsText, 1), @SizeV)
          LastAsmError = "DS: tamanho precisa ser conhecido ja no pass 1 (nao pode depender de rotulo definido so depois): " + LastEvalError + LastEvalUnknownSymbol
          ProcedureReturn #False
        EndIf
        Protected FillV.u = 0
        If NOps = 2
          Protected FillAddr.Z80Addr
          If Not EvalOperandExpr(GetOperand(ArgsText, 2), EmitMode, @FillAddr)
            ProcedureReturn #False
          EndIf
          FillV = FillAddr\Value & $FF
        EndIf
        Protected DsIdx
        For DsIdx = 1 To SizeV\Value
          AddElement(OutBytes()) : OutBytes() = FillV
        Next
        ProcedureReturn #True
    EndSelect

    LastAsmError = "Diretiva de dados desconhecida: " + Op
    ProcedureReturn #False
  EndProcedure

  ;- ------------------------------------------------------------
  ;- Condicionais (IF/IFT/IFE/IFF/IFDEF/IFNDEF/IF1/IF2/ELSE/ENDIF) e macros
  ;- basicas (MACRO/ENDM/EXITM/LOCAL) - ver docs/reference/nestor80-language.md.
  ;- ExpandLines() roda uma vez no INICIO de cada pass (RunOnePass chama,
  ;- ve abaixo) e devolve uma lista "achatada" sem IF/MACRO/ENDM nenhum -
  ;- so linhas de verdade pra montar. Rodar isso a cada pass (nao uma vez so
  ;- pro Assemble() inteiro) e o que permite IF1/IF2 enxergarem o pass certo.
  ;- REPT/IRP/IRPC/MODULE/labels locais ficam pra depois (Fase C, ver
  ;- docs/resumo-asm.md).
  ;- ------------------------------------------------------------

  ; Troca toda ocorrencia de Word (case-insensitive, respeitando fronteira de
  ; identificador - nao troca dentro de "FOOBAR" procurando "FOO") por
  ; Replacement, em Text inteiro (pode ter varias linhas). Usado tanto pra
  ; substituicao de parametro de macro quanto pra renomeacao de simbolo LOCAL.
  Procedure.s SubstituteWord(Text.s, Word.s, Replacement.s)
    If Word = ""
      ProcedureReturn Text
    EndIf
    Protected Result.s = ""
    Protected L = Len(Text), I = 1, C.s
    Protected WU.s = UCase(Word)
    Protected Start, Tok.s

    While I <= L
      C = Mid(Text, I, 1)
      If ChIsIdentStart(C)
        Start = I
        I + 1
        While I <= L And ChIsIdentCont(Mid(Text, I, 1))
          I + 1
        Wend
        Tok = Mid(Text, Start, I - Start)
        If UCase(Tok) = WU
          Result + Replacement
        Else
          Result + Tok
        EndIf
        Continue
      EndIf
      Result + C
      I + 1
    Wend
    ProcedureReturn Result
  EndProcedure

  Declare.b ExpandLines(List InLines.s(), List OutLines.s(), SizeOnly.b, Depth.i)

  #Z80Asm_MaxMacroDepth = 16

  Procedure.b ExpandLines(List InLines.s(), List OutLines.s(), SizeOnly.b, Depth.i)
    ClearList(OutLines())

    If Depth > #Z80Asm_MaxMacroDepth
      LastAsmError = "Macros aninhadas demais (limite " + Str(#Z80Asm_MaxMacroDepth) + ") - possivel recursao infinita"
      ProcedureReturn #False
    EndIf

    If Depth = 0
      ; chamada de fora (nao recursiva de corpo de macro) - reconstroi a
      ; tabela de macros e reseta o contador de LOCAL do zero, pra pass 1 e
      ; pass 2 produzirem exatamente a mesma sequencia de sufixos (mesma
      ; ordem de expansao, mesmo texto-fonte).
      ClearMap(Macros())
      MacroExpansionCounter = 0
    EndIf

    Protected NewList CondStack.b()  ; um nivel por IF ativo - #True = condicao bateu nesse nivel

    Protected DefiningMacro.b = #False
    Protected DefMacroName.s, DefMacroParams.s, DefMacroBody.s
    Protected DefMacroDepth.i = 0

    ForEach InLines()
      Protected RawLine.s = InLines()
      Protected PLx.Z80ParsedLine
      ParseLine(RawLine, @PLx)

      ; --- capturando o corpo de uma definicao MACRO...ENDM ---
      If DefiningMacro
        If PLx\HasOperator And PLx\Operator = "MACRO"
          DefMacroDepth + 1
        ElseIf PLx\HasOperator And PLx\Operator = "ENDM"
          If DefMacroDepth > 0
            DefMacroDepth - 1
          Else
            If Not FindMapElement(Macros(), DefMacroName)
              AddMapElement(Macros(), DefMacroName)
            EndIf
            Macros()\ParamNames = DefMacroParams
            Macros()\BodyText = DefMacroBody
            DefiningMacro = #False
            Continue
          EndIf
        EndIf
        DefMacroBody + RawLine + Chr(10)
        Continue
      EndIf

      Protected Skipping.b = #False
      ForEach CondStack()
        If Not CondStack()
          Skipping = #True
          Break
        EndIf
      Next

      ; EQU/DEFL/ASET precisam ser resolvidos AQUI TAMBEM (nao so na passada
      ; principal em RunOnePass, que so acontece DEPOIS que ExpandLines()
      ; termina) - senao "FLAG equ 1" seguido de "if FLAG" no mesmo arquivo
      ; nunca veria o simbolo pronto a tempo. Rotulo (posicao = contador de
      ; localizacao) fica de fora de proposito - ExpandLines nao rastreia
      ; tamanho de instrucao/endereco, so RunOnePass faz isso; um `IF` que
      ; dependa do VALOR de um rotulo (nao de uma EQU) e uma lacuna conhecida
      ; e aceita nesta fase (baixa prioridade, padrao raro). DefineSymbol()
      ; e seguro de chamar de novo aqui e mais uma vez em RunOnePass (mesma
      ; ideia ja usada pra permitir EQU "repetido" entre pass 1 e pass 2).
      If Not Skipping And PLx\HasOperator And PLx\HasLabel And Not PLx\LabelHasColon
        Select PLx\Operator
          Case "EQU"
            Protected EqV.Z80Addr
            If EvalExpr(PLx\ArgsText, @EqV)
              DefineSymbol(PLx\Label, EqV\Value, #True)
            EndIf
          Case "DEFL", "ASET"
            Protected DlV.Z80Addr
            If EvalExpr(PLx\ArgsText, @DlV)
              Protected DlKey.s = UCase(PLx\Label)
              If Not FindMapElement(Symbols(), DlKey)
                AddMapElement(Symbols(), DlKey)
              EndIf
              Z80Addr_Make(@Symbols()\Addr, DlV\Value, #Z80Seg_Absolute)
              Symbols()\IsKnown = #True
              Symbols()\IsConstant = #False
            EndIf
        EndSelect
      EndIf

      If PLx\HasOperator
        Select PLx\Operator
          Case "IF", "IFT"
            Protected CV1.Z80Addr, C1.b = #False
            If Not Skipping
              If Not EvalExpr(PLx\ArgsText, @CV1)
                LastAsmError = "IF: " + LastEvalError + LastEvalUnknownSymbol
                ProcedureReturn #False
              EndIf
              C1 = Bool(CV1\Value <> 0)
            EndIf
            AddElement(CondStack()) : CondStack() = C1
            Continue

          Case "IFE", "IFF"
            Protected CV2.Z80Addr, C2.b = #False
            If Not Skipping
              If Not EvalExpr(PLx\ArgsText, @CV2)
                LastAsmError = "IFE/IFF: " + LastEvalError + LastEvalUnknownSymbol
                ProcedureReturn #False
              EndIf
              C2 = Bool(CV2\Value = 0)
            EndIf
            AddElement(CondStack()) : CondStack() = C2
            Continue

          Case "IFDEF"
            AddElement(CondStack()) : CondStack() = IsSymbolKnown(RTrimWs(Mid(PLx\ArgsText, SkipWs(PLx\ArgsText, 1))))
            Continue

          Case "IFNDEF"
            AddElement(CondStack()) : CondStack() = Bool(Not IsSymbolKnown(RTrimWs(Mid(PLx\ArgsText, SkipWs(PLx\ArgsText, 1)))))
            Continue

          Case "IF1"
            AddElement(CondStack()) : CondStack() = SizeOnly
            Continue

          Case "IF2"
            AddElement(CondStack()) : CondStack() = Bool(Not SizeOnly)
            Continue

          Case "ELSE"
            If ListSize(CondStack()) = 0
              LastAsmError = "ELSE sem IF correspondente"
              ProcedureReturn #False
            EndIf
            LastElement(CondStack())
            CondStack() = Bool(Not CondStack())
            Continue

          Case "ENDIF"
            If ListSize(CondStack()) = 0
              LastAsmError = "ENDIF sem IF correspondente"
              ProcedureReturn #False
            EndIf
            LastElement(CondStack())
            DeleteElement(CondStack())
            Continue

          Case "EXITM"
            If Skipping
              Continue
            EndIf
            Break

          Case "LOCAL"
            ; so faz sentido dentro do corpo de uma macro (chamado de dentro
            ; de uma recursao de ExpandLines) - fora disso, so ignora.
            Continue

          Case "MACRO"
            If Skipping
              Continue
            EndIf
            ; nome da macro vem em posicao de rotulo ("nome MACRO p1,p2" ou
            ; "nome: MACRO p1,p2" - ":" opcional, LR:883-923) - ParseLine ja
            ; resolve os dois jeitos (lookahead EQU/DEFL/ASET/MACRO ou rotulo
            ; classico), entao aqui e so ler PLx\Label.
            If Not PLx\HasLabel
              LastAsmError = "MACRO precisa de um nome antes: nome MACRO param1,param2"
              ProcedureReturn #False
            EndIf
            DefMacroName = UCase(PLx\Label)
            DefMacroParams = ReplaceString(PLx\ArgsText, ",", " ")
            DefMacroBody = ""
            DefMacroDepth = 0
            DefiningMacro = #True
            Continue
        EndSelect

        If Not Skipping And FindMapElement(Macros(), UCase(PLx\Operator))
          Protected ParamNames.s = Macros()\ParamNames
          Protected Body.s = Macros()\BodyText
          Protected NParams = 0
          If RTrimWs(Mid(ParamNames, SkipWs(ParamNames, 1))) <> ""
            NParams = CountString(Trim(ParamNames), " ") + 1
          EndIf

          MacroExpansionCounter + 1
          Protected Suffix.s = "__m" + Str(MacroExpansionCounter)

          ; LOCAL <nomes> - primeiro renomeia (sufixo unico desta expansao)
          ; todos os simbolos declarados, pra nao colidir entre invocacoes
          ; diferentes da mesma macro.
          Protected NewList BodyPreLines.s()
          SplitSourceLines(Body, BodyPreLines())
          ForEach BodyPreLines()
            Protected PLl.Z80ParsedLine
            ParseLine(BodyPreLines(), @PLl)
            If PLl\HasOperator And PLl\Operator = "LOCAL"
              Protected LNames.s = ReplaceString(PLl\ArgsText, ",", " ")
              Protected LCount = CountString(Trim(LNames), " ") + 1
              Protected LIdx
              For LIdx = 1 To LCount
                Protected LName.s = Trim(StringField(LNames, LIdx, " "))
                If LName <> ""
                  Body = SubstituteWord(Body, LName, LName + Suffix)
                EndIf
              Next
            EndIf
          Next

          Protected PIdx
          For PIdx = 1 To NParams
            Protected PName.s = UCase(StringField(Trim(ParamNames), PIdx, " "))
            Protected PVal.s = GetOperand(PLx\ArgsText, PIdx)
            Body = SubstituteWord(Body, PName, PVal)
          Next

          Protected NewList MacroLines.s()
          SplitSourceLines(Body, MacroLines())
          Protected NewList MacroOut.s()
          If Not ExpandLines(MacroLines(), MacroOut(), SizeOnly, Depth + 1)
            ProcedureReturn #False
          EndIf
          ForEach MacroOut()
            AddElement(OutLines())
            OutLines() = MacroOut()
          Next
          Continue
        EndIf
      EndIf

      If Skipping
        Continue
      EndIf

      AddElement(OutLines())
      OutLines() = RawLine
    Next

    ProcedureReturn #True
  EndProcedure

  Procedure.b RunOnePass(List Lines.s(), SizeOnly.b, Array Mem.a(1))
    Protected LineNum = 0
    Protected PL.Z80ParsedLine
    Protected Dim Bytes.a(3)
    Protected Len4.i, Idx
    Protected Ended.b = #False
    Protected V1.Z80Addr, V2.Z80Addr, V3.Z80Addr
    Protected EmitNow.b
    EmitNow = Bool(Not SizeOnly)

    Z80Addr_Make(@CurLoc, 0, #Z80Seg_Absolute)
    RealPos = 0
    PhaseActive = #False

    Protected NewList ExpLines.s()
    If Not ExpandLines(Lines(), ExpLines(), SizeOnly, 0)
      AsmErrorLine = LineNum : AsmErrorText = LastAsmError
      ProcedureReturn #False
    EndIf

    ForEach ExpLines()
      If Ended
        Break
      EndIf
      LineNum + 1

      ParseLine(ExpLines(), @PL)

      If PL\IsBlank
        Continue
      EndIf

      If PL\HasLabel And PL\LabelHasColon
        If Not DefineSymbol(PL\Label, CurLoc\Value, #False)
          AsmErrorLine = LineNum : AsmErrorText = LastEvalError
          ProcedureReturn #False
        EndIf
      EndIf

      If Not PL\HasOperator
        Continue
      EndIf

      Select PL\Operator
        Case "EQU"
          If EvalExpr(PL\ArgsText, @V1)
            If Not DefineSymbol(PL\Label, V1\Value, #True)
              AsmErrorLine = LineNum : AsmErrorText = LastEvalError
              ProcedureReturn #False
            EndIf
          ElseIf Not SizeOnly
            AsmErrorLine = LineNum : AsmErrorText = "EQU: " + LastEvalError + LastEvalUnknownSymbol
            ProcedureReturn #False
          EndIf
          Continue

        Case "DEFL", "ASET"
          If EvalExpr(PL\ArgsText, @V2)
            Protected Key2.s = UCase(PL\Label)
            If Not FindMapElement(Symbols(), Key2)
              AddMapElement(Symbols(), Key2)
            EndIf
            Z80Addr_Make(@Symbols()\Addr, V2\Value, #Z80Seg_Absolute)
            Symbols()\IsKnown = #True
            Symbols()\IsConstant = #False
          ElseIf Not SizeOnly
            AsmErrorLine = LineNum : AsmErrorText = "DEFL/ASET: " + LastEvalError + LastEvalUnknownSymbol
            ProcedureReturn #False
          EndIf
          Continue

        Case "ORG"
          If EvalExpr(PL\ArgsText, @V3)
            CurLoc\Value = V3\Value
            RealPos = V3\Value ; ORG dentro de um bloco .PHASE nao e suportado (restricao tambem
                                ; existente no Nestor80 pra ASEG/CSEG/etc dentro de .PHASE) - fora
                                ; de um bloco, mantem CurLoc/RealPos sincronizados como sempre
          ElseIf Not SizeOnly
            AsmErrorLine = LineNum : AsmErrorText = "ORG: " + LastEvalError + LastEvalUnknownSymbol
            ProcedureReturn #False
          EndIf
          Continue

        Case "END"
          Ended = #True
          Continue

        Case ".PHASE", "PHASE"
          ; Contador de localizacao "reportado" ($/rotulos/JR) passa a mostrar
          ; o endereco pedido, mas a escrita real continua de onde estava
          ; (RealPos intocado) - ver docs/reference/nestor80-language.md e
          ; MACRO-80.txt secao 2.6.29 "Relocation Before Loading". O valor
          ; precisa ser conhecido JA (nao pode depender de rotulo definido
          ; so depois - mesma restricao de DS, documentada no Nestor80).
          Protected VPhase.Z80Addr
          If EvalExpr(PL\ArgsText, @VPhase)
            CurLoc\Value = VPhase\Value
            PhaseActive = #True
          ElseIf Not SizeOnly
            AsmErrorLine = LineNum : AsmErrorText = ".PHASE: " + LastEvalError + LastEvalUnknownSymbol
            ProcedureReturn #False
          EndIf
          Continue

        Case ".DEPHASE", "DEPHASE"
          ; CurLoc volta a bater com RealPos (equivalente a "nunca ter saido
          ; do endereco real") - ver comentario da Structure no topo do
          ; modulo pra explicacao completa do mecanismo.
          CurLoc\Value = RealPos
          PhaseActive = #False
          Continue

        Case "ASEG", "CSEG", "DSEG", "COMMON", "PUBLIC", "EXTRN", "EXT", "EXTERNAL", "ENTRY", "GLOBAL"
          Continue

        Case "DB", "DEFB", "DEFM", "DW", "DEFW", "DS", "DEFS", "DC", "DZ", "DEFZ"
          NewList DataBytes.a()
          If Not EncodeDataDirective(PL\Operator, PL\ArgsText, EmitNow, DataBytes())
            AsmErrorLine = LineNum : AsmErrorText = LastAsmError
            ProcedureReturn #False
          EndIf
          If Not SizeOnly
            Protected DIdx = 0
            Protected DA.i
            ForEach DataBytes()
              DA = (RealPos + DIdx) & $FFFF
              Mem(DA) = DataBytes()
              If Not AnyByteWritten
                MinAddrTouched = DA : MaxAddrTouched = DA : AnyByteWritten = #True
              Else
                If DA < MinAddrTouched : MinAddrTouched = DA : EndIf
                If DA > MaxAddrTouched : MaxAddrTouched = DA : EndIf
              EndIf
              DIdx + 1
            Next
          EndIf
          CurLoc\Value = (CurLoc\Value + ListSize(DataBytes())) & $FFFF
          RealPos = (RealPos + ListSize(DataBytes())) & $FFFF
          Continue
      EndSelect

      If Not IsMnemonic(PL\Operator)
        AsmErrorLine = LineNum
        AsmErrorText = "Diretiva/mnemonico nao suportado ainda nesta fase: " + PL\Operator
        ProcedureReturn #False
      EndIf

      Len4 = EncodeInstruction(PL\Operator, PL\ArgsText, EmitNow, Bytes())
      If Len4 < 0
        AsmErrorLine = LineNum : AsmErrorText = LastAsmError
        ProcedureReturn #False
      EndIf

      If Not SizeOnly
        For Idx = 0 To Len4 - 1
          Protected A.i = (RealPos + Idx) & $FFFF
          Mem(A) = Bytes(Idx)
          If Not AnyByteWritten
            MinAddrTouched = A : MaxAddrTouched = A : AnyByteWritten = #True
          Else
            If A < MinAddrTouched : MinAddrTouched = A : EndIf
            If A > MaxAddrTouched : MaxAddrTouched = A : EndIf
          EndIf
        Next
      EndIf

      CurLoc\Value = (CurLoc\Value + Len4) & $FFFF
      RealPos = (RealPos + Len4) & $FFFF
    Next

    ProcedureReturn #True
  EndProcedure

  Procedure.i Assemble(SourceText.s, Array OutBytes.a(1))
    NewList Lines.s()
    Protected Dim Mem.a(65535)
    Protected Idx

    ResetState()
    AsmErrorLine = 0 : AsmErrorText = ""
    MinAddrTouched = 0 : MaxAddrTouched = 0 : AnyByteWritten = #False

    SplitSourceLines(SourceText, Lines())

    If Not RunOnePass(Lines(), #True, Mem())
      ProcedureReturn -1
    EndIf

    If Not RunOnePass(Lines(), #False, Mem())
      ProcedureReturn -1
    EndIf

    If Not AnyByteWritten
      ProcedureReturn 0
    EndIf

    Protected N = MaxAddrTouched - MinAddrTouched + 1
    For Idx = 0 To N - 1
      OutBytes(Idx) = Mem(MinAddrTouched + Idx)
    Next
    ProcedureReturn N
  EndProcedure

EndModule
