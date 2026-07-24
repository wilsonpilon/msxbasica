;
; ------------------------------------------------------------
;  Z80AsmTestCli.pb - harness headless (sem GUI) do assembler Z80 nativo
;  (Z80Asm.pbi). Mesmo padrao PASS/FAIL de Screen2TestCli.pb/PsgTestCli.pb -
;  exit code = numero de falhas (0 = tudo passou).
;
;  Compilar:
;  "C:\Basic\Compilers\pbcompiler.exe" editor\tools\Z80AsmTestCli.pb /EXE editor\tools\Z80AsmTestCli.exe /CONSOLE
;  (ajustar o caminho do pbcompiler.exe pra o da maquina - ver build.config.json)
;
;  Uso: Z80AsmTestCli.exe            roda a suite de testes do avaliador de
;                                     expressao/tabela de simbolos (unica
;                                     parte do motor implementada ate agora -
;                                     ver docs/resumo-asm.md)
;
;  Cada caso novo de instrucao/diretiva/macro ganha aqui um bloco PASS/FAIL
;  proprio conforme as proximas tarefas da Fase A forem sendo implementadas;
;  o oraculo real (N80.exe, ver docs/resumo-asm.md) e usado a parte, por
;  comparacao manual, ate existir uma saida binaria pra comparar byte a byte.
; ------------------------------------------------------------
;

EnableExplicit

XIncludeFile "..\Z80Asm.pbi"

; Modo "--assemble <entrada.asm> <saida.bin>": monta e grava o binario cru
; (mesma faixa min..max endereco tocado que N80.exe produz por padrao com a
; estrategia "memory map") - usado pra comparar byte a byte com o oraculo
; via ferramenta externa (fc/cmp), sem precisar reimplementar leitura de
; binario aqui dentro. Roda ANTES da suite de testes normal e sai.
If CountProgramParameters() >= 3 And ProgramParameter(0) = "--assemble"
  OpenConsole()
  Define InPath.s = ProgramParameter(1)
  Define OutPath.s = ProgramParameter(2)
  Define Dim AsmBytes.a(65535)

  If Not ReadFile(0, InPath)
    PrintN("ERRO: nao abriu " + InPath)
    End 1
  EndIf
  Define SrcLen = Lof(0)
  Define *Buf = AllocateMemory(SrcLen + 1)
  ReadData(0, *Buf, SrcLen)
  CloseFile(0)
  Define Source.s = PeekS(*Buf, SrcLen, #PB_Ascii)
  FreeMemory(*Buf)

  Define N = Z80Asm::Assemble(Source, AsmBytes())
  If N < 0
    PrintN("ASMERROR linha " + Str(Z80Asm::GetAssembleErrorLine()) + ": " + Z80Asm::GetAssembleErrorText())
    End 1
  EndIf

  If CreateFile(0, OutPath)
    If N > 0
      Define Dim WriteBuf.a(N - 1)
      Define Idx0
      For Idx0 = 0 To N - 1
        WriteBuf(Idx0) = AsmBytes(Idx0)
      Next
      WriteData(0, @WriteBuf(), N)
    EndIf
    CloseFile(0)
  EndIf
  PrintN(Str(N) + " bytes")
  End 0
EndIf

Global TestCount = 0
Global FailCount = 0

Procedure CheckEval(Expr.s, ExpectedValue.u, Desc.s = "")
  Protected R.Z80Asm::Z80Addr
  TestCount + 1
  If Not Z80Asm::EvalExpr(Expr, @R)
    FailCount + 1
    PrintN("FAIL  " + Expr + "  (nao avaliou - erro: " + Z80Asm::GetLastEvalError() + " / simbolo desconhecido: " + Z80Asm::GetLastEvalUnknownSymbol() + ")  " + Desc)
    ProcedureReturn
  EndIf
  If R\Value = ExpectedValue
    PrintN("PASS  " + Expr + "  = " + Str(R\Value) + "  " + Desc)
  Else
    FailCount + 1
    PrintN("FAIL  " + Expr + "  esperado " + Str(ExpectedValue) + " (" + Hex(ExpectedValue) + "h) obtido " + Str(R\Value) + " (" + Hex(R\Value) + "h)  " + Desc)
  EndIf
EndProcedure

Procedure CheckEvalFails(Expr.s, Desc.s = "")
  Protected R.Z80Asm::Z80Addr
  TestCount + 1
  If Z80Asm::EvalExpr(Expr, @R)
    FailCount + 1
    PrintN("FAIL  " + Expr + "  (deveria ter falhado, avaliou = " + Str(R\Value) + ")  " + Desc)
  Else
    PrintN("PASS  " + Expr + "  (falhou como esperado)  " + Desc)
  EndIf
EndProcedure

Procedure CheckKw(Word.s, ExpectMnemonic.b, ExpectRegister.b, ExpectDirective.b, ExpectOperator.b)
  TestCount + 1
  Protected Ok.b = #True
  If Z80Asm::IsMnemonic(Word) <> ExpectMnemonic : Ok = #False : EndIf
  If Z80Asm::IsRegister(Word) <> ExpectRegister : Ok = #False : EndIf
  If Z80Asm::IsDirective(Word) <> ExpectDirective : Ok = #False : EndIf
  If Z80Asm::IsOperatorWord(Word) <> ExpectOperator : Ok = #False : EndIf
  If Ok
    PrintN("PASS  vocabulario(" + Word + ")")
  Else
    FailCount + 1
    PrintN("FAIL  vocabulario(" + Word + ")  mnem=" + Str(Z80Asm::IsMnemonic(Word)) + " reg=" + Str(Z80Asm::IsRegister(Word)) + " dir=" + Str(Z80Asm::IsDirective(Word)) + " op=" + Str(Z80Asm::IsOperatorWord(Word)))
  EndIf
EndProcedure

Procedure CheckParse(Line.s, ExpLabel.s, ExpLabelHasColon.b, ExpLabelPublic.b, ExpOperator.s, ExpArgs.s, ExpComment.s, ExpBlank.b, Desc.s = "")
  Protected PL.Z80Asm::Z80ParsedLine
  TestCount + 1
  Z80Asm::ParseLine(Line, @PL)
  Protected Ok.b = #True
  If PL\HasLabel And PL\Label <> ExpLabel : Ok = #False : EndIf
  If (Not PL\HasLabel) And ExpLabel <> "" : Ok = #False : EndIf
  If PL\LabelHasColon <> ExpLabelHasColon : Ok = #False : EndIf
  If PL\LabelIsPublic <> ExpLabelPublic : Ok = #False : EndIf
  If PL\HasOperator And PL\Operator <> ExpOperator : Ok = #False : EndIf
  If (Not PL\HasOperator) And ExpOperator <> "" : Ok = #False : EndIf
  If PL\ArgsText <> ExpArgs : Ok = #False : EndIf
  If PL\HasComment And PL\Comment <> ExpComment : Ok = #False : EndIf
  If (Not PL\HasComment) And ExpComment <> "" : Ok = #False : EndIf
  If PL\IsBlank <> ExpBlank : Ok = #False : EndIf
  If Ok
    PrintN("PASS  ParseLine(" + Line + ")  " + Desc)
  Else
    FailCount + 1
    PrintN("FAIL  ParseLine(" + Line + ")  label=[" + PL\Label + "]/colon=" + Str(PL\LabelHasColon) + "/pub=" + Str(PL\LabelIsPublic) + " op=[" + PL\Operator + "] args=[" + PL\ArgsText + "] comment=[" + PL\Comment + "] blank=" + Str(PL\IsBlank) + "  " + Desc)
  EndIf
EndProcedure

OpenConsole()

PrintN("=== Z80Asm - vocabulario ===")
Z80Asm::InitKeywordMaps()
CheckKw("LD", #True, #False, #False, #False)
CheckKw("HL", #False, #True, #False, #False)
CheckKw("ORG", #False, #False, #True, #False)
CheckKw("HIGH", #False, #False, #False, #True)
CheckKw("FOOBAR", #False, #False, #False, #False)
CheckKw("SET", #True, #False, #False, #False)  ; SET e so mnemonico Z80 aqui (ver docs/reference/nestor80-language.md - MACRO-80.txt documenta como alias de DEFL mas o Nestor80 nao implementa assim)

PrintN("")
PrintN("=== Z80Asm - avaliador de expressao: literais numericos ===")
Z80Asm::ResetState()
CheckEval("42", 42, "decimal puro")
CheckEval("0FFh", 255, "hex com sufixo H, precisa do 0 na frente")
CheckEval("1Ah", 26, "hex com sufixo h minusculo")
CheckEval("0x1A", 26, "hex com prefixo 0x")
CheckEval("#1A", 26, "hex com prefixo #")
CheckEval("377Q", 255, "octal com sufixo Q")
CheckEval("377O", 255, "octal com sufixo O")
CheckEval("1010B", 10, "binario com sufixo B")
CheckEval("%1010", 10, "binario com prefixo %")
CheckEval("0b1010", 10, "binario com prefixo 0b")
CheckEval("100D", 100, "decimal com sufixo D explicito")
CheckEval("'A'", Asc("A"), "string de 1 char = ascii")
CheckEval(Chr(34)+"AB"+Chr(34), (Asc("A") << 8) | Asc("B"), "string de 2 chars = byte alto+byte baixo")

PrintN("")
PrintN("=== Z80Asm - avaliador de expressao: operadores/precedencia ===")
Z80Asm::ResetState()
CheckEval("2+3*4", 14, "* liga mais forte que +")
CheckEval("(2+3)*4", 20, "parenteses vencem precedencia")
CheckEval("10-2-3", 5, "- associativo a esquerda: (10-2)-3")
CheckEval("-5+10", 5, "menos unario")
CheckEval("2*-3", -6 & $FFFF, "menos unario depois de operador")
CheckEval("NOT 0", $FFFF, "NOT bitwise de 0")
CheckEval("HIGH 1234h", $12, "HIGH extrai byte alto")
CheckEval("LOW 1234h", $34, "LOW extrai byte baixo")
CheckEval("5 AND 3", 1, "AND bitwise")
CheckEval("5 OR 2", 7, "OR bitwise")
CheckEval("5 XOR 1", 4, "XOR bitwise")
CheckEval("1 SHL 4", 16, "SHL")
CheckEval("16 SHR 2", 4, "SHR")
CheckEval("7 MOD 3", 1, "MOD")
CheckEval("3 EQ 3", $FFFF, "EQ verdadeiro = FFFFh")
CheckEval("3 EQ 4", 0, "EQ falso = 0")
CheckEval("3 LT 4", $FFFF, "LT verdadeiro")
CheckEval("3 GT 4", 0, "GT falso")
CheckEval("1+2 EQ 3", $FFFF, "+ liga mais forte que EQ")
CheckEval("1 AND 0 OR 1", 1, "AND liga mais forte que OR: (1 AND 0) OR 1 = 0 OR 1 = 1 (bitwise, nao logico)")

PrintN("")
PrintN("=== Z80Asm - avaliador de expressao: simbolos e $ ===")
Z80Asm::ResetState()
Z80Asm::DefineSymbol("FOO", 100, #True)
CheckEval("FOO", 100, "simbolo definido (EQU)")
CheckEval("FOO+1", 101, "simbolo em expressao")
Z80Asm::SetCurrentLocation(200)
CheckEval("$", 200, "$ isolado = contador de localizacao atual")
CheckEval("$+2", 202, "$ em expressao")
CheckEvalFails("BAR", "simbolo nao definido deve falhar (nao e erro fatal, so 'desconhecido')")

PrintN("")
PrintN("=== Z80Asm - parser de linha ===")
CheckParse("START: LD A,1", "START", #True, #False, "LD", "A,1", "", #False, "rotulo classico + mnemonico + args")
CheckParse("START:: LD A,1", "START", #True, #True, "LD", "A,1", "", #False, "rotulo publico (::)")
CheckParse("  LD A,1", "", #False, #False, "LD", "A,1", "", #False, "sem rotulo, so mnemonico")
CheckParse("; so comentario", "", #False, #False, "", "", "so comentario", #True, "linha so-comentario")
CheckParse("", "", #False, #False, "", "", "", #True, "linha vazia")
CheckParse("   ", "", #False, #False, "", "", "", #True, "linha so espaco/tab")
CheckParse(Chr(9)+"LD A,1"+Chr(9)+"; carrega", "", #False, #False, "LD", "A,1", "carrega", #False, "tab como separador (nao Trim())")
CheckParse("LOOP:", "LOOP", #True, #False, "", "", "", #False, "so rotulo, sem operador")
CheckParse("LOOP: ; com comentario", "LOOP", #True, #False, "", "", "com comentario", #False, "rotulo + comentario, sem operador")
CheckParse("FOO EQU 5", "FOO", #False, #False, "EQU", "5", "", #False, "simbolo EQU valor - sem ':' (constantDefinitionOpcodes)")
CheckParse("BAR DEFL 10", "BAR", #False, #False, "DEFL", "10", "", #False, "simbolo DEFL valor - sem ':'")
CheckParse("	ORG 100h", "", #False, #False, "ORG", "100h", "", #False, "diretiva sem rotulo (indentada com tab)")
CheckParse("MSG: DB "+Chr(34)+"A;B"+Chr(34)+" ; comentario de verdade", "MSG", #True, #False, "DB", Chr(34)+"A;B"+Chr(34), "comentario de verdade", #False, "';' dentro de string nao conta como comentario")
CheckParse(".RADIX 16", "", #False, #False, ".RADIX", "16", "", #False, "diretiva com ponto vira 1 so operador")
CheckParse("NOP", "", #False, #False, "NOP", "", "", #False, "mnemonico sem argumento")

PrintN("")
PrintN("=== Resultado ===")
PrintN(Str(TestCount) + " testes, " + Str(FailCount) + " falhas")

End FailCount
