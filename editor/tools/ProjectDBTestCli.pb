;
; ------------------------------------------------------------
;  Ferramenta de linha de comando para testar o modulo de projeto MSX
;  (editor\ProjectDB.pbi) sem precisar abrir o editor nem simular cliques
;  de mouse num canvas (automacao de canvas se mostrou nao-confiavel neste
;  ambiente - ver conversas anteriores sobre o editor de sprites).
;
;  Roda um round-trip completo contra um projeto SQLite descartavel: cria o
;  projeto temporario implicito, registra sprites de tamanhos/modos
;  diferentes, lista os numeros, recarrega e compara byte a byte, sobrescreve
;  um sprite existente (confirma que nao duplica), promove o projeto pra um
;  arquivo permanente (SaveAs) e confirma que os dados continuam la.
;
;  Uso:
;    ProjectDBTestCli.exe <pasta_de_trabalho>
;      <pasta_de_trabalho>  pasta onde o projeto salvo (SaveAs) sera criado
;                           (apagada e recriada a cada execucao)
;
;  Compilar com:
;    "C:\Basic\Compilers\pbcompiler.exe" editor\tools\ProjectDBTestCli.pb /EXE editor\tools\ProjectDBTestCli.exe /CONSOLE
; ------------------------------------------------------------
;

EnableExplicit
OpenConsole()

XIncludeFile "..\ProjectDB.pbi"

Define WorkDir.s = ProgramParameter(0)
If WorkDir = ""
  PrintN("Uso: ProjectDBTestCli.exe <pasta_de_trabalho>")
  End 1
EndIf
If Right(WorkDir, 1) <> "\" And Right(WorkDir, 1) <> "/"
  WorkDir + "\"
EndIf
If FileSize(WorkDir) <> -2
  CreateDirectory(WorkDir)
EndIf

Define Failures = 0

Procedure CheckTrue(Ok.i, Label.s)
  Shared Failures
  If Ok
    PrintN("OK    - " + Label)
  Else
    PrintN("FALHA - " + Label + " -> " + ProjectDB::GetLastError())
    Failures + 1
  EndIf
EndProcedure

; Preenche Grid com um padrao determinístico e facil de comparar depois
; (cada bloco = (Row*GridSize+Col) mod 16, cobre todos os indices 0-15).
Procedure FillPattern(Array Grid.b(2), GridSize.i)
  Protected Row, Col
  For Row = 0 To GridSize - 1
    For Col = 0 To GridSize - 1
      Grid(Row, Col) = (Row * GridSize + Col) % 16
    Next
  Next
EndProcedure

Procedure.i GridsMatch(Array A.b(2), Array B.b(2), GridSize.i)
  Protected Row, Col
  For Row = 0 To GridSize - 1
    For Col = 0 To GridSize - 1
      If A(Row, Col) <> B(Row, Col)
        ProcedureReturn #False
      EndIf
    Next
  Next
  ProcedureReturn #True
EndProcedure

; 1) EnsureOpen cria o projeto temporario implicito ("noname")
CheckTrue(ProjectDB::EnsureOpen(), "EnsureOpen (projeto temporario implicito)")
CheckTrue(ProjectDB::IsTemp(), "IsTemp() = #True logo apos EnsureOpen")

; 2) Salva 3 sprites de tamanhos/modos diferentes
Dim GridA.b(15, 15) : FillPattern(GridA(), 16)
Dim GridB.b(15, 15) : FillPattern(GridB(), 8)
Dim GridC.b(15, 15) : FillPattern(GridC(), 16)

CheckTrue(ProjectDB::StoreSprite(1, "heroi", 16, 1, GridA()), "SaveSprite #1 (16x16, MSX1, tag 'heroi')")
CheckTrue(ProjectDB::StoreSprite(2, "bala", 8, 2, GridB()), "SaveSprite #2 (8x8, MSX2, tag 'bala')")
CheckTrue(ProjectDB::StoreSprite(3, "", 16, 1, GridC()), "SaveSprite #3 (16x16, MSX1, sem tag)")

; 3) ListSpriteNumbers - espera [1,2,3]
NewList Numbers.i()
ProjectDB::ListSpriteNumbers(Numbers())
CheckTrue(Bool(ListSize(Numbers()) = 3), "ListSpriteNumbers (esperado 3, achou " + Str(ListSize(Numbers())) + ")")
Define OrderOk.i = #True
If ListSize(Numbers()) = 3
  SelectElement(Numbers(), 0) : If Numbers() <> 1 : OrderOk = #False : EndIf
  SelectElement(Numbers(), 1) : If Numbers() <> 2 : OrderOk = #False : EndIf
  SelectElement(Numbers(), 2) : If Numbers() <> 3 : OrderOk = #False : EndIf
EndIf
CheckTrue(OrderOk, "ListSpriteNumbers em ordem crescente [1,2,3]")

; 4) LoadSprite #1 - confere grade, tag, tamanho e modo
Dim LoadedA.b(15, 15)
Define Loaded1.i = ProjectDB::FetchSprite(1, LoadedA())
CheckTrue(Loaded1, "LoadSprite #1")
CheckTrue(Bool(ProjectDB::LastGridSize() = 16), "Sprite #1: grid_size = 16 (achou " + Str(ProjectDB::LastGridSize()) + ")")
CheckTrue(Bool(ProjectDB::LastSpriteMode() = 1), "Sprite #1: sprite_mode = 1/MSX1 (achou " + Str(ProjectDB::LastSpriteMode()) + ")")
CheckTrue(Bool(ProjectDB::LastTag() = "heroi"), "Sprite #1: tag = 'heroi' (achou '" + ProjectDB::LastTag() + "')")
CheckTrue(GridsMatch(GridA(), LoadedA(), 16), "Sprite #1: grade recarregada bate byte a byte com a original")

; 5) LoadSprite #2 (8x8/MSX2) - mesmo round-trip com outro tamanho/modo
Dim LoadedB.b(15, 15)
Define Loaded2.i = ProjectDB::FetchSprite(2, LoadedB())
CheckTrue(Loaded2, "LoadSprite #2")
CheckTrue(Bool(ProjectDB::LastGridSize() = 8), "Sprite #2: grid_size = 8 (achou " + Str(ProjectDB::LastGridSize()) + ")")
CheckTrue(Bool(ProjectDB::LastSpriteMode() = 2), "Sprite #2: sprite_mode = 2/MSX2 (achou " + Str(ProjectDB::LastSpriteMode()) + ")")
CheckTrue(GridsMatch(GridB(), LoadedB(), 8), "Sprite #2: grade recarregada bate byte a byte com a original")

; 6) Sobrescreve o sprite #1 (tag e cor diferentes) - nao pode duplicar
Dim GridA2.b(15, 15)
Define Row, Col
For Row = 0 To 15 : For Col = 0 To 15 : GridA2(Row, Col) = 5 : Next : Next
CheckTrue(ProjectDB::StoreSprite(1, "heroi2", 16, 2, GridA2()), "SaveSprite #1 de novo (sobrescrevendo tag/modo)")
ClearList(Numbers())
ProjectDB::ListSpriteNumbers(Numbers())
CheckTrue(Bool(ListSize(Numbers()) = 3), "Ainda 3 sprites apos sobrescrever #1 (nao duplicou)")
Dim ReloadedA.b(15, 15)
ProjectDB::FetchSprite(1, ReloadedA())
CheckTrue(Bool(ProjectDB::LastTag() = "heroi2"), "Sprite #1: tag atualizada para 'heroi2'")
CheckTrue(Bool(ProjectDB::LastSpriteMode() = 2), "Sprite #1: sprite_mode atualizado para 2/MSX2")

; 7) SpriteExists
CheckTrue(ProjectDB::HasSprite(2), "SpriteExists(2) = #True")
CheckTrue(Bool(Not ProjectDB::HasSprite(99)), "SpriteExists(99) = #False")

; 8) HasUnsavedContent - projeto ainda e temporario e ja tem sprites
CheckTrue(ProjectDB::HasUnsavedContent(), "HasUnsavedContent() = #True (temporario com sprites)")

; 8b) Diretorio de trabalho (project_info) - round trip simples
ProjectDB::SetWorkingDir("C:\meu\projeto")
CheckTrue(Bool(ProjectDB::GetWorkingDir() = "C:\meu\projeto"), "GetWorkingDir() bate com SetWorkingDir()")

; 8c) StoreDocument/FetchDocument - copia do conteudo das abas de texto,
; guardada junto com o projeto a cada "Salvar"/"Salvar como" de uma aba
; (ver SaveDocument() em BadigEditor.pb).
Define DocPath1.s = WorkDir + "fonte1.dmx"
Define DocContent1.s = "label inicio:" + Chr(10) + "print " + Chr(34) + "ola" + Chr(34) + Chr(10)
CheckTrue(ProjectDB::StoreDocument(DocPath1, "DMX", DocContent1), "StoreDocument(fonte1.dmx)")
CheckTrue(ProjectDB::FetchDocument(DocPath1), "FetchDocument(fonte1.dmx)")
CheckTrue(Bool(ProjectDB::LastDocumentContent() = DocContent1), "Documento: conteudo bate com o salvo")
CheckTrue(Bool(ProjectDB::LastDocumentMode() = "DMX"), "Documento: modo = DMX")

; Salvar a mesma aba de novo (edicao) tem que atualizar, nao duplicar
Define DocContent1b.s = DocContent1 + "' mais uma linha"
CheckTrue(ProjectDB::StoreDocument(DocPath1, "DMX", DocContent1b), "StoreDocument(fonte1.dmx) de novo (edicao)")
ProjectDB::FetchDocument(DocPath1)
CheckTrue(Bool(ProjectDB::LastDocumentContent() = DocContent1b), "Documento: conteudo atualizado apos segunda gravacao")

; Conteudo com aspas simples tem que sobreviver ao escape da query SQL
Define DocPath2.s = WorkDir + "fonte2.asm"
Define DocContent2.s = "; it's a test" + Chr(10) + "ld a,'x'" + Chr(10)
CheckTrue(ProjectDB::StoreDocument(DocPath2, "ASM", DocContent2), "StoreDocument(fonte2.asm) com aspas simples no conteudo")
ProjectDB::FetchDocument(DocPath2)
CheckTrue(Bool(ProjectDB::LastDocumentContent() = DocContent2), "Documento: aspas simples preservadas (escape correto)")

; 8d) StoreAlphabet/FetchAlphabet - alfabetos (charset 256x8) do projeto,
; mesmo padrao Store/Fetch/List dos sprites.
Procedure FillAlphaPattern(Array CharsetBytes.a(2), Seed.i)
  Protected Row, Col
  For Row = 0 To 255
    For Col = 0 To 7
      CharsetBytes(Row, Col) = (Row * 8 + Col + Seed) % 256
    Next
  Next
EndProcedure

Procedure.i AlphaBytesMatch(Array A.a(2), Array B.a(2))
  Protected Row, Col
  For Row = 0 To 255
    For Col = 0 To 7
      If A(Row, Col) <> B(Row, Col)
        ProcedureReturn #False
      EndIf
    Next
  Next
  ProcedureReturn #True
EndProcedure

Dim AlphaA.a(255, 7) : FillAlphaPattern(AlphaA(), 0)
Dim AlphaB.a(255, 7) : FillAlphaPattern(AlphaB(), 37)

CheckTrue(ProjectDB::StoreAlphabet(1, "fonte1", AlphaA()), "StoreAlphabet #1 (tag 'fonte1')")
CheckTrue(ProjectDB::StoreAlphabet(2, "fonte2", AlphaB()), "StoreAlphabet #2 (tag 'fonte2')")

NewList AlphaNumbers.i()
ProjectDB::ListAlphabetNumbers(AlphaNumbers())
CheckTrue(Bool(ListSize(AlphaNumbers()) = 2), "ListAlphabetNumbers (esperado 2, achou " + Str(ListSize(AlphaNumbers())) + ")")

Dim LoadedAlphaA.a(255, 7)
CheckTrue(ProjectDB::FetchAlphabet(1, LoadedAlphaA()), "FetchAlphabet #1")
CheckTrue(Bool(ProjectDB::LastAlphabetTag() = "fonte1"), "Alfabeto #1: tag = 'fonte1'")
CheckTrue(AlphaBytesMatch(AlphaA(), LoadedAlphaA()), "Alfabeto #1: 2048 bytes batem com o original")

; Sobrescreve o alfabeto #1 (tag diferente) - nao pode duplicar
CheckTrue(ProjectDB::StoreAlphabet(1, "fonte1b", AlphaB()), "StoreAlphabet #1 de novo (sobrescrevendo tag/dados)")
ClearList(AlphaNumbers())
ProjectDB::ListAlphabetNumbers(AlphaNumbers())
CheckTrue(Bool(ListSize(AlphaNumbers()) = 2), "Ainda 2 alfabetos apos sobrescrever #1 (nao duplicou)")
ProjectDB::FetchAlphabet(1, LoadedAlphaA())
CheckTrue(Bool(ProjectDB::LastAlphabetTag() = "fonte1b"), "Alfabeto #1: tag atualizada para 'fonte1b'")
CheckTrue(AlphaBytesMatch(AlphaB(), LoadedAlphaA()), "Alfabeto #1: dados atualizados apos sobrescrever")

CheckTrue(ProjectDB::HasAlphabet(2), "HasAlphabet(2) = #True")
CheckTrue(Bool(Not ProjectDB::HasAlphabet(99)), "HasAlphabet(99) = #False")

; "Projeto 0" (defaults, sempre em memoria): alfabeto 0 = msx.alf embutido
; no executavel - confere que bate byte a byte com o .alf real do
; repositorio (alfabetos\msx.alf, dois niveis acima de editor\tools\), pra
; pegar caso o embutido fique desatualizado em relacao ao arquivo fonte.
Dim DefaultAlpha.a(255, 7)
CheckTrue(ProjectDB::FetchDefaultAlphabet(0, DefaultAlpha()), "FetchDefaultAlphabet(0) (projeto 0/defaults)")

Define RealAlfPath.s = GetPathPart(ProgramFilename()) + "..\..\alfabetos\msx.alf"
Define RealAlfMatches.i = #False
Define AlfFile = ReadFile(#PB_Any, RealAlfPath)
If AlfFile
  Dim RealAlfBytes.a(255, 7)
  FileSeek(AlfFile, 7)   ; pula o cabecalho binario MSX (ID + enderecos)
  Define RRow, RCol
  For RRow = 0 To 255
    For RCol = 0 To 7
      RealAlfBytes(RRow, RCol) = ReadByte(AlfFile) & $FF
    Next
  Next
  CloseFile(AlfFile)
  RealAlfMatches = AlphaBytesMatch(RealAlfBytes(), DefaultAlpha())
EndIf
CheckTrue(RealAlfMatches, "Alfabeto 0 (defaults) bate byte a byte com alfabetos\msx.alf real")

; 9) SaveAs promove pro arquivo permanente
Define SavedPath.s = WorkDir + "meuprojeto.msxproject"
CheckTrue(ProjectDB::SaveAs(SavedPath), "SaveAs(" + SavedPath + ")")
CheckTrue(Bool(FileSize(SavedPath) > 0), "Arquivo do projeto existe e tem conteudo apos SaveAs")
CheckTrue(Bool(Not ProjectDB::IsTemp()), "IsTemp() = #False apos SaveAs")
CheckTrue(Bool(ProjectDB::GetPath() = SavedPath), "GetPath() aponta pro novo arquivo permanente")
CheckTrue(Bool(Not ProjectDB::HasUnsavedContent()), "HasUnsavedContent() = #False apos SaveAs (ja nao e mais temporario)")

; 10) Dados continuam acessiveis depois do SaveAs (reabriu no novo arquivo)
ClearList(Numbers())
ProjectDB::ListSpriteNumbers(Numbers())
CheckTrue(Bool(ListSize(Numbers()) = 3), "ListSpriteNumbers ainda mostra 3 sprites apos SaveAs")
Dim FinalA.b(15, 15)
ProjectDB::FetchSprite(3, FinalA())
CheckTrue(GridsMatch(GridC(), FinalA(), 16), "Sprite #3 ainda bate byte a byte apos SaveAs + reabrir")
CheckTrue(Bool(ProjectDB::GetWorkingDir() = "C:\meu\projeto"), "GetWorkingDir() ainda bate apos SaveAs")
ProjectDB::FetchDocument(DocPath1)
CheckTrue(Bool(ProjectDB::LastDocumentContent() = DocContent1b), "Documento fonte1.dmx ainda bate apos SaveAs")
ClearList(AlphaNumbers())
ProjectDB::ListAlphabetNumbers(AlphaNumbers())
CheckTrue(Bool(ListSize(AlphaNumbers()) = 2), "ListAlphabetNumbers ainda mostra 2 alfabetos apos SaveAs")
ProjectDB::FetchAlphabet(2, LoadedAlphaA())
CheckTrue(AlphaBytesMatch(AlphaB(), LoadedAlphaA()), "Alfabeto #2 ainda bate byte a byte apos SaveAs")

; 11) OpenExisting - simula "Arquivo -> Abrir projeto...": fecha tudo e
; reabre do zero so a partir do caminho salvo, sem passar por EnsureOpen.
ProjectDB::Close()
CheckTrue(ProjectDB::OpenExisting(SavedPath), "OpenExisting(" + SavedPath + ") apos fechar")
CheckTrue(Bool(Not ProjectDB::IsTemp()), "IsTemp() = #False logo apos OpenExisting")
CheckTrue(Bool(ProjectDB::GetPath() = SavedPath), "GetPath() aponta pro arquivo reaberto")
ClearList(Numbers())
ProjectDB::ListSpriteNumbers(Numbers())
CheckTrue(Bool(ListSize(Numbers()) = 3), "ListSpriteNumbers mostra 3 sprites apos OpenExisting")
Dim ReopenedB.b(15, 15)
ProjectDB::FetchSprite(2, ReopenedB())
CheckTrue(GridsMatch(GridB(), ReopenedB(), 8), "Sprite #2 ainda bate byte a byte apos OpenExisting")
CheckTrue(Bool(ProjectDB::GetWorkingDir() = "C:\meu\projeto"), "GetWorkingDir() ainda bate apos OpenExisting")
ProjectDB::FetchDocument(DocPath2)
CheckTrue(Bool(ProjectDB::LastDocumentContent() = DocContent2), "Documento fonte2.asm ainda bate apos OpenExisting")
ClearList(AlphaNumbers())
ProjectDB::ListAlphabetNumbers(AlphaNumbers())
CheckTrue(Bool(ListSize(AlphaNumbers()) = 2), "ListAlphabetNumbers ainda mostra 2 alfabetos apos OpenExisting")
ProjectDB::FetchAlphabet(1, LoadedAlphaA())
CheckTrue(AlphaBytesMatch(AlphaB(), LoadedAlphaA()), "Alfabeto #1 ainda bate byte a byte apos OpenExisting")
CheckTrue(Bool(Not ProjectDB::OpenExisting(WorkDir + "nao_existe.msxproject")), "OpenExisting falha graciosamente com arquivo inexistente")

; 12) Close nao deve travar (limpeza final)
ProjectDB::Close()
PrintN("Close() executado sem erro.")

PrintN("")
If Failures = 0
  PrintN("TODOS OS TESTES PASSARAM.")
  End 0
Else
  PrintN(Str(Failures) + " TESTE(S) FALHARAM.")
  End 1
EndIf
