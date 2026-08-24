;
; ------------------------------------------------------------
;  Carregador do arquivo de notas do SUPER-X ("SUPER-X.TNK", docs/SPEC.md
;  modulo 45e) - pedido explicito do usuario: "Por hora apenas carregue
;  estas notas na memoria, vamos usar elas em outros comandos" (comandos
;  iM/iC/iL/iS ainda nao existem, ficam pra uma sessao futura, fase F do
;  modulo 45). Este arquivo so' tem o PARSER/estrutura em memoria - nenhum
;  comando do MON> chama Mamute_LoadNoteFile() ainda.
;
;  Formato do arquivo (doc do SUPER-X, secao "Note function"): 2 bytes no
;  inicio = quantidade de notas gravadas (nao "notas que sobram", como a
;  doc em ingles sugere - confirmado lendo o arquivo real de exemplo:
;  campo = 471, exatamente a quantidade de notas com conteudo real; as
;  512-471 = 41 restantes sao so padding, preenchido com 0x20 (espaco), nao
;  zero) + ate 512 registros fixos de 64 bytes cada:
;    endereco   2 bytes (little-endian)
;    slot       1 byte  (classificacao PROPRIA do SUPER-X: 0=Geral 1=MAIN
;                        2=SUB 3=FDC 4=RAM - NAO e' o mesmo conceito do
;                        #slot/sub-slot do enderecamento estendido,
;                        modulo 45b/Mamute_SxTarget - essas duas coisas so'
;                        coincidem de nome)
;    tipo       1 byte  (0=Geral 1=BIOS 2=WORK 3=DATA 4=PORT 5=MATH 6=KEY
;                        7=HOOK)
;    texto      60 bytes (japones - katakana meia-largura, Shift-JIS de
;                        byte unico 0xA1-0xDF, mesma faixa da doc: "ASCII
;                        128-255 e' japones" - confirmado decodificando o
;                        arquivo real com Shift-JIS, nao um encoding
;                        customizado como se suspeitava antes de olhar os
;                        bytes de verdade)
;  = 2 + 512*64 = 32770 bytes, bate exato com a doc.
;
;  O texto e' guardado CRU (Chr() byte a byte, sem tentar decodificar
;  Shift-JIS em tempo de execucao) - a traducao pro portugues das 471 notas
;  reais do arquivo de exemplo do SUPER-X vira conteudo ESTATICO da Ajuda
;  (MamuteSuperXNotesHelpData.pbi), nao decodificacao dinamica.
; ------------------------------------------------------------
;

Structure MamuteNote
  Addr.u
  SlotData.a
  TypeData.a
  Text.s ; bytes crus (Chr() 1 a 1) - pode conter caracteres > 127 (japones), sem decodificar
EndStructure

Global NewList MamuteNotes.MamuteNote()

; Le um arquivo .TNK inteiro pra MamuteNotes() (ClearList antes, sempre
; substitui o que tinha). #True se leu com sucesso; #False se nao abriu o
; arquivo OU se o tamanho nao bate com o formato esperado (2 + 512*64
; bytes) - nesse caso MamuteNotes() fica vazia, sem tentar interpretar
; dado corrompido/incompleto.
Procedure.b Mamute_LoadNoteFile(FilePath.s)
  ClearList(MamuteNotes())

  Protected Fh.i = ReadFile(#PB_Any, FilePath)
  If Not Fh
    ProcedureReturn #False
  EndIf

  ; ">=", nao "=" - o .TNK real de exemplo (SUPER-X.TNK original) tem 126
  ; bytes A MAIS que o esperado (32896 em vez de 32770) - achado real,
  ; confirmado inspecionando o arquivo: sobra depois do ultimo dos 512
  ; registros, nao faz parte do formato descrito na doc, provavelmente lixo/
  ; padding do gravador original. So' recusa arquivo CURTO demais (truncado).
  Protected FileSize.i = Lof(Fh)
  If FileSize < 2 + 512 * 64
    CloseFile(Fh)
    ProcedureReturn #False
  EndIf

  Protected CountLow.a = ReadByte(Fh)
  Protected CountHigh.a = ReadByte(Fh)
  Protected NoteCount.i = CountLow | (CountHigh << 8)
  If NoteCount < 0 Or NoteCount > 512
    CloseFile(Fh)
    ProcedureReturn #False
  EndIf

  Protected i.i, b.i
  Protected AddrLow.a, AddrHigh.a, SlotByte.a, TypeByte.a
  Protected TextByte.a
  For i = 0 To NoteCount - 1
    AddrLow = ReadByte(Fh)
    AddrHigh = ReadByte(Fh)
    SlotByte = ReadByte(Fh)
    TypeByte = ReadByte(Fh)
    Protected TextRaw.s = ""
    For b = 0 To 59
      TextByte = ReadByte(Fh)
      TextRaw + Chr(TextByte)
    Next

    AddElement(MamuteNotes())
    MamuteNotes()\Addr = AddrLow | (AddrHigh << 8)
    MamuteNotes()\SlotData = SlotByte
    MamuteNotes()\TypeData = TypeByte
    MamuteNotes()\Text = TextRaw
  Next

  CloseFile(Fh)
  ProcedureReturn #True
EndProcedure
