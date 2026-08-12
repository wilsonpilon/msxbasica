;
; ------------------------------------------------------------
;  Suporte ao Mamute Assembler (MamuteAssemblerGui.pbi): simulacao do
;  sistema de slots do MSX - 4 slots (0-3), 4 paginas de 16KB por slot
;  (Pagina 0: 0000-3FFF, Pagina 1: 4000-7FFF, Pagina 2: 8000-BFFF, Pagina 3:
;  C000-FFFF, exatamente como o hardware real do MSX endereca memoria via
;  paginacao). MamuteMem() e um bloco 4x4 de 16KB cada (256KB no total) -
;  toda em branco por enquanto (Dim zera sozinho), preenchida por arquivo
;  real (BIOS/BASIC/cartucho) numa sessao futura.
;
;  "Configurar -> Mamute Assembler..." (MamuteSettings_OpenWindow abaixo)
;  configura o que existe FISICAMENTE em cada uma das 16 celulas Slot x
;  Pagina (Vazio/RAM/ROM/BASIC + arquivo, pra ROM/BASIC) - configuracao
;  fixa, nao muda em tempo de execucao. Ao escolher um arquivo de 32KB pra
;  uma celula ROM na Pagina 0 (BIOS), a tela pergunta se e BIOS+BASIC
;  combinados (comum em MSX real) - se sim, aponta a Pagina 0 e a Pagina 1
;  do MESMO slot pro MESMO arquivo, cada uma com o FileOffset certo (0 pros
;  primeiros 16KB/BIOS, #Mamute_PageSize pros ultimos 16KB/BASIC).
;  O comando PAGE (MamuteAssemblerGui.pbi)
;  mexe num conceito DIFERENTE: MamutePageMap() e o mapeamento ATIVO agora
;  mesmo - pra cada uma das 4 paginas visiveis pelo Z80 (0-3), qual dos 4
;  slots fisicos esta "comutado" ali - exatamente como o registrador de slot
;  primario (porta A8h) de um MSX de verdade. E esse mapeamento ativo (nao a
;  configuracao fisica) que vai decidir, em sessoes futuras, de qual bloco
;  de 16KB um comando que mostra/edita memoria realmente le/escreve.
; ------------------------------------------------------------
;

#MamuteMem_Empty = 0
#MamuteMem_RAM   = 1
#MamuteMem_ROM   = 2
#MamuteMem_Basic = 3

#Mamute_PageSize = 16384 ; 16KB - tamanho de cada bloco/pagina
#Mamute_CombinedBiosBasicSize = 32768 ; 32KB - BIOS+BASIC combinados num arquivo so (comum em MSX real)

; Bloco de memoria simulada: [Slot][Pagina][Offset 0..16383] - 4x4x16KB =
; 256KB. Global Dim zera sozinho (PureBasic) - "toda a memoria em branco"
; sem precisar de nenhum laco de inicializacao.
Global Dim MamuteMem.a(3, 3, 16383)

; VRAM simulada (comandos V/futuros VLOAD/VSAVE) - pedido explicito do
; usuario, "ainda nao temos VRAM, mas vamos implementar entao". Diferente
; da RAM/ROM (que passa pelo sistema de 4 slots x 4 paginas, espelhando o
; barramento de enderecos de 16 bits do Z80), a VRAM de um MSX real NUNCA
; fica mapeada nesse espaco - e acessada por PORTA de I/O (o VDP tem seu
; proprio contador de endereco interno), entao nao ha "pagina"/"slot" real
; pra simular. Por isso o endereco da VRAM aqui e PLANO e DIRETO, de 0 ate
; #Mamute_VramMaxSize-1 (192KB, o maior tamanho configuravel) - sem bancos,
; sem paginacao, sem PAGE - a opcao mais simples entre as que o usuario
; sugeriu ("permitirmos o enderecamento de ate os 128Kb" - ampliado aqui
; pro teto de 192KB). MamuteVramSize (configuravel em "Configurar -> Mamute
; Assembler...": 16/128/192KB) e so o LIMITE de validacao - o array em si
; sempre aloca o tamanho maximo (192KB e trivial em memoria), evitando
; ReDim/perda de dado se o usuario mudar o tamanho configurado depois.
#Mamute_VramMaxSize = 196608 ; 192KB - maior tamanho configuravel
Global Dim MamuteVRAM.a(#Mamute_VramMaxSize - 1)
Global MamuteVramSize.i = 16384 ; 16KB por padrao - mesmo tamanho que o MegaAssembler original (MSX1) enxergava

; FileOffset: deslocamento (em bytes) dentro de FilePath de onde comecam os
; 16KB desta celula - normalmente 0 (arquivo do tamanho exato da pagina),
; mas #Mamute_PageSize (16384) quando esta celula e a metade FINAL de um
; arquivo BIOS+BASIC combinado de 32KB (ver MamuteSettings_HandleFilePick())
; - assim os dois pontos (BIOS na Pagina 0, BASIC na Pagina 1 do mesmo slot)
; apontam pro MESMO arquivo, cada um lendo a metade certa.
Structure MamuteMemCell
  Tipo.b     ; #MamuteMem_Empty/RAM/ROM/Basic
  FilePath.s ; so usado quando Tipo = ROM ou Basic
  FileOffset.i
EndStructure
Global Dim MamuteCfgCell.MamuteMemCell(3, 3) ; [Slot][Pagina]

; Mapeamento ATIVO agora mesmo - MamutePageMap(Pagina) = Slot comutado
; naquela pagina. Recalculado pro "estado de boot" (Mamute_ResetPageMapToDefault)
; toda vez que a janela do Mamute Assembler abre - ver comentario no topo.
Global Dim MamutePageMap.i(3)

; Fonte do terminal (MamuteAssemblerGui.pbi) - configuravel em "Configurar ->
; Mamute Assembler..." (pedido explicito do usuario, fonte padrao ficou
; pequena demais). Monoespacada de proposito (EditorCfg_EnumMonospaceFonts(),
; EditorSettings.pbi, mesma enumeracao ja usada pela fonte do editor de
; codigo) - uma fonte proporcional quebraria o alinhamento em grade do
; terminal.
Global MamuteFontName.s = "Consolas"
Global MamuteFontSize.i = 16
Global MamuteFontBold.b = #True

; Teclado numerico reduzido do comando S (MamuteMGui.pbi) - pedido explicito
; do usuario: "vamos criar uma opcao no Configurar -> Mamute Assembler pra
; o usuario escolher quais teclas do teclado ele vai usar como
; 1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,0". Indexado pelo VALOR do nibble (0-15),
; nao pela ordem de exibicao pedida (que comeca em 1 e termina em 0) - mais
; simples de usar em tempo de execucao (MamuteSKeyMap(Valor) direto). A tela
; de Configurar e que reordena pra mostrar "1" primeiro e "0" por ultimo.
; Padrao pedido explicitamente pelo usuario: "1,2,3,4,q,w,e,r,a,s,d,f,z,x,c,v"
; - mesmo layout classico de teclado numerico em jogos/emuladores (4x4 nos
; cantos esquerdos do teclado QWERTY).
Global Dim MamuteSKeyMap.s(15)

Procedure Mamute_SKeyMapDefaults()
  MamuteSKeyMap(0)  = "V" ; ultimo na ordem de exibicao (1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,0)
  MamuteSKeyMap(1)  = "1"
  MamuteSKeyMap(2)  = "2"
  MamuteSKeyMap(3)  = "3"
  MamuteSKeyMap(4)  = "4"
  MamuteSKeyMap(5)  = "Q"
  MamuteSKeyMap(6)  = "W"
  MamuteSKeyMap(7)  = "E"
  MamuteSKeyMap(8)  = "R"
  MamuteSKeyMap(9)  = "A"
  MamuteSKeyMap(10) = "S" ; valor A
  MamuteSKeyMap(11) = "D" ; valor B
  MamuteSKeyMap(12) = "F" ; valor C
  MamuteSKeyMap(13) = "Z" ; valor D
  MamuteSKeyMap(14) = "X" ; valor E
  MamuteSKeyMap(15) = "C" ; valor F
EndProcedure

Procedure.s Mamute_PageRangeText(Pagina.i)
  Select Pagina
    Case 0 : ProcedureReturn "0000-3FFF"
    Case 1 : ProcedureReturn "4000-7FFF"
    Case 2 : ProcedureReturn "8000-BFFF"
    Case 3 : ProcedureReturn "C000-FFFF"
  EndSelect
  ProcedureReturn "????-????"
EndProcedure

Procedure.s Mamute_TipoText(Tipo.b)
  Select Tipo
    Case #MamuteMem_RAM   : ProcedureReturn "RAM"
    Case #MamuteMem_ROM   : ProcedureReturn "ROM"
    Case #MamuteMem_Basic : ProcedureReturn "BASIC"
  EndSelect
  ProcedureReturn "Vazio"
EndProcedure

; Descricao do modo de exibicao escolhido pelo comando C - usado por ele
; mesmo (so pra confirmar no log) e, mais tarde, pelos comandos D/P/V que
; vao realmente formatar a saida conforme esse modo.
Procedure.s Mamute_DisplayModeText(Mode.b)
  Select Mode
    Case 0 : ProcedureReturn "HEXA+ASCII, 4 BYTES/LINHA"
    Case 1 : ProcedureReturn "HEXA+ASCII, 16 BYTES/LINHA"
    Case 2 : ProcedureReturn "HEXA, 8 BYTES/LINHA + CHECKSUM (SOMA+ENDERECO)"
    Case 3 : ProcedureReturn "HEXA, 8 BYTES/LINHA + CHECKSUM (SO SOMA)"
  EndSelect
  ProcedureReturn "?"
EndProcedure

; Primeiro slot (0..3, varrendo em ordem) com RAM configurada em QUALQUER
; pagina - usado por "PAGE" sem parametros ("coloca todas as paginas no
; slot marcado como RAM"). -1 se nenhum slot tem RAM configurada ainda.
Procedure Mamute_FindRamSlot()
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      If MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_RAM
        ProcedureReturn Slot
      EndIf
    Next
  Next
  ProcedureReturn -1
EndProcedure

; Recalcula MamutePageMap() a partir da configuracao fisica (MamuteCfgCell) -
; "estado de boot": pra cada pagina, usa o slot configurado ali (ROM/BASIC
; ganham de RAM se as duas existirem na mesma pagina - RAM so vence quando
; e a UNICA coisa configurada); pagina sem nada configurado cai no slot 0
; por padrao (comportamento deterministico, sem "barramento flutuante").
Procedure Mamute_ResetPageMapToDefault()
  Protected Pagina, Slot, Chosen.i, ChosenIsRam.b, Found.b, Tipo.b
  For Pagina = 0 To 3
    Chosen = 0 : ChosenIsRam = #True : Found = #False
    For Slot = 0 To 3
      Tipo = MamuteCfgCell(Slot, Pagina)\Tipo
      If Tipo <> #MamuteMem_Empty
        If Not Found
          Chosen = Slot
          ChosenIsRam = Bool(Tipo = #MamuteMem_RAM)
          Found = #True
        ElseIf ChosenIsRam And Tipo <> #MamuteMem_RAM
          Chosen = Slot
          ChosenIsRam = #False
        EndIf
      EndIf
    Next
    MamutePageMap(Pagina) = Chosen
  Next
EndProcedure

; Le de verdade o conteudo dos arquivos ROM/BASIC configurados
; (MamuteCfgCell()\FilePath) pro bloco de MamuteMem() correspondente,
; respeitando FileOffset (metade final de um arquivo BIOS+BASIC combinado de
; 32KB - ver MamuteSettings_HandleFilePick acima). Ate aqui (SCR, modulo 31)
; MamuteMem() ficava sempre em branco mesmo com ROM configurada - "sessao
; futura" que virou necessaria agora que um comando (SCR) precisa mostrar
; dado real de ROM pra fazer sentido. Zera a celula antes de tentar ler (nao
; so quando falha) - reabrir a janela depois de trocar a config (ex.: tipo
; ROM -> Vazio, ou apontar pra outro arquivo) nao deve deixar lixo de uma
; carga anterior. Arquivo ausente/menor que 16KB: preenche o que der, resto
; fica zerado (nao e erro - igual um MSX real com uma ROM menor instalada).
Procedure Mamute_LoadPhysicalMemory()
  Protected Slot.i, Pagina.i, i.i
  Protected FilePath.s, FileOff.i, Fh.i
  For Slot = 0 To 3
    For Pagina = 0 To 3
      For i = 0 To #Mamute_PageSize - 1
        MamuteMem(Slot, Pagina, i) = 0
      Next

      If MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_ROM Or MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_Basic
        FilePath = MamuteCfgCell(Slot, Pagina)\FilePath
        FileOff = MamuteCfgCell(Slot, Pagina)\FileOffset
        If FilePath <> "" And FileSize(FilePath) > 0
          Fh = ReadFile(#PB_Any, FilePath)
          If Fh
            FileSeek(Fh, FileOff)
            ReadData(Fh, @MamuteMem(Slot, Pagina, 0), #Mamute_PageSize)
            CloseFile(Fh)
          EndIf
        EndIf
      EndIf
    Next
  Next
EndProcedure

;- ------------------------------------------------------------
;- Acesso a memoria por endereco de CPU (0000-FFFF) - usa MamutePageMap()
;- pra achar o slot ativo, exatamente como o comando PAGE deixou configurado.
;- Base de qualquer comando futuro que mostra/edita memoria (DM e o
;- primeiro) - ver comentario no topo do arquivo.
;- ------------------------------------------------------------

; Resolve um endereco de CPU (0-65535, sem checar faixa - chamador garante)
; pro Slot/Pagina/Offset fisicos correspondentes, considerando o mapeamento
; ATIVO agora (MamutePageMap()), nao a configuracao fisica crua.
Procedure Mamute_ResolveAddress(Addr.i, *OutSlot.Integer, *OutPagina.Integer, *OutOffset.Integer)
  Protected Pagina.i = (Addr >> 14) & 3
  *OutPagina\i = Pagina
  *OutSlot\i = MamutePageMap(Pagina)
  *OutOffset\i = Addr & (#Mamute_PageSize - 1)
EndProcedure

; #True so quando a celula fisica mapeada em Addr agora e RAM - ROM/BASIC/
; Vazio sao somente-leitura (fisicamente nao ha o que escrever ali, igual
; hardware real: ROM nao aceita escrita, e sem nada configurado nao ha chip
; nenhum pra responder).
Procedure.b Mamute_CanWriteAt(Addr.i)
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  ProcedureReturn Bool(MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_RAM)
EndProcedure

Procedure.a Mamute_ReadByte(Addr.i)
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  ProcedureReturn MamuteMem(Slot, Pagina, Offset)
EndProcedure

; #True se escreveu de verdade (Mamute_CanWriteAt); #False sem tocar em nada
; se a celula mapeada agora nao for RAM.
Procedure.b Mamute_WriteByte(Addr.i, Value.a)
  If Not Mamute_CanWriteAt(Addr)
    ProcedureReturn #False
  EndIf
  Protected Slot.i, Pagina.i, Offset.i
  Mamute_ResolveAddress(Addr, @Slot, @Pagina, @Offset)
  MamuteMem(Slot, Pagina, Offset) = Value
  ProcedureReturn #True
EndProcedure

;- ------------------------------------------------------------
;- Formatacao/parse hexadecimal - "enderecos em hexa sao o padrao de
;- entrada de todos os comandos" (pedido explicito do usuario).
;- ------------------------------------------------------------

Procedure.s Mamute_Hex2(v.i)
  ProcedureReturn RSet(Hex(v & $FF), 2, "0")
EndProcedure

Procedure.s Mamute_Hex4(v.i)
  ProcedureReturn RSet(Hex(v & $FFFF), 4, "0")
EndProcedure

; Endereco em hexa com largura variavel (usado pra VRAM - ate 5 digitos,
; 0-2FFFF pros 192KB maximos) - Mamute_Hex4() acima fica curto pra isso.
Procedure.s Mamute_HexPad(v.i, Digits.i)
  ProcedureReturn RSet(Hex(v), Digits, "0")
EndProcedure

; Valida que Token so tem digitos hex (0-9A-Fa-f), 1 a MaxLen deles.
Procedure.b Mamute_IsHexString(Token.s, MaxLen.i)
  If Len(Token) < 1 Or Len(Token) > MaxLen
    ProcedureReturn #False
  EndIf
  Protected i
  For i = 1 To Len(Token)
    If FindString("0123456789ABCDEFabcdef", Mid(Token, i, 1)) = 0
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn #True
EndProcedure

; Endereco de 16 bits sem sinal, 1-4 digitos hex (ex.: "4000", "8000").
Procedure.b Mamute_ParseHexAddr(Token.s, *OutValue.Integer)
  If Not Mamute_IsHexString(Token, 4)
    ProcedureReturn #False
  EndIf
  *OutValue\i = Val("$" + Token)
  ProcedureReturn #True
EndProcedure

; Endereco de VRAM - plano, 1-5 digitos hex, validado contra o tamanho
; configurado agora (MamuteSKeyMap ja usa esse idioma de "configuravel em
; Configurar -> Mamute Assembler..." - MamuteVramSize e o mesmo espirito).
; Sem wraparound (diferente dos enderecos de RAM/CPU) - passar do limite e
; erro de sintaxe, nao da volta pro 0.
Procedure.b Mamute_ParseVramAddr(Token.s, *OutValue.Integer)
  If Not Mamute_IsHexString(Token, 5)
    ProcedureReturn #False
  EndIf
  Protected V.i = Val("$" + Token)
  If V < 0 Or V >= MamuteVramSize
    ProcedureReturn #False
  EndIf
  *OutValue\i = V
  ProcedureReturn #True
EndProcedure

; Monta as linhas formatadas de um dump de memoria (StartAddr..EndAddr,
; inclusive) conforme o Mode do comando C - usado pelo D (manda pro log),
; P e V (manda pro PDF). IsVram=#True le de MamuteVRAM() (endereco plano,
; sem PAGE) em vez de Mamute_ReadByte() (RAM/ROM, resolve pelo mapeamento
; ATIVO). Modo 0/1: hexa+ASCII, 4 ou 16 bytes/linha. Modo 2/3: so hexa, 8
; bytes/linha, com checksum (soma dos bytes, +byte baixo do endereco so no
; modo 2) no final de cada linha.
Procedure Mamute_BuildDumpLines(List Lines.s(), StartAddr.i, EndAddr.i, Mode.b, IsVram.b)
  ClearList(Lines())
  Protected BytesPerLine.i
  Select Mode
    Case 0 : BytesPerLine = 4
    Case 1 : BytesPerLine = 16
    Default : BytesPerLine = 8 ; modo 2/3
  EndSelect

  Protected AddrDigits.i = 4
  If IsVram : AddrDigits = 5 : EndIf

  Protected Addr.i = StartAddr
  Protected LineAddr.i, HexPart.s, AsciiPart.s, Checksum.i, i.i, RawByte.a, Line.s
  While Addr <= EndAddr
    LineAddr = Addr
    HexPart = "" : AsciiPart = "" : Checksum = 0
    For i = 0 To BytesPerLine - 1
      If Addr > EndAddr : Break : EndIf
      If IsVram
        RawByte = MamuteVRAM(Addr)
      Else
        RawByte = Mamute_ReadByte(Addr & $FFFF)
      EndIf
      HexPart + Mamute_Hex2(RawByte) + " "
      If Mode = 0 Or Mode = 1
        If RawByte >= 32 And RawByte <= 126
          AsciiPart + Chr(RawByte)
        Else
          AsciiPart + "."
        EndIf
      EndIf
      Checksum + RawByte
      Addr + 1
    Next

    Line = Mamute_HexPad(LineAddr, AddrDigits) + ": " + HexPart
    Select Mode
      Case 0, 1
        Line + " " + AsciiPart
      Case 2
        Line + RSet(Hex((Checksum + (LineAddr & $FF)) & $FF), 2, "0")
      Case 3
        Line + RSet(Hex(Checksum & $FF), 2, "0")
    EndSelect
    AddElement(Lines())
    Lines() = Line
  Wend
EndProcedure

; Deslocamento com sinal opcional ("+"/"-" na frente, 1-2 digitos hex depois)
; - faixa -7Fh (-127) a 80h (128), pedido explicito do usuario. "80" sem
; sinal e tratado como positivo (+80h), igual "+80".
Procedure.b Mamute_ParseHexOffset(Token.s, *OutValue.Integer)
  If Token = ""
    ProcedureReturn #False
  EndIf
  Protected Sign.i = 1
  Protected Digits.s = Token
  If Left(Token, 1) = "+"
    Digits = Mid(Token, 2)
  ElseIf Left(Token, 1) = "-"
    Sign = -1
    Digits = Mid(Token, 2)
  EndIf
  If Not Mamute_IsHexString(Digits, 2)
    ProcedureReturn #False
  EndIf
  Protected Value.i = Sign * Val("$" + Digits)
  If Value < -$7F Or Value > $80
    ProcedureReturn #False
  EndIf
  *OutValue\i = Value
  ProcedureReturn #True
EndProcedure

;- ------------------------------------------------------------
;- Disassembler Z80 (comandos L/LP) - pedido explicito do usuario: "voce tem
;- os dados do Z80 consigo" (confirmado - conjunto de instrucoes documentado
;- e as formas nao-documentadas mais estaveis/conhecidas, como IXH/IXL/IYH/
;- IYL e as formas indexadas do CB, sao bem estabelecidas e usadas aqui) -
;- decodificacao de bytes crus em texto mnemonico, do zero (nao existe
;- nenhuma tabela de opcodes reaproveitavel no assemblador Z80Asm.pbi deste
;- projeto - ele CODIFICA mnemonico->bytes proceduralmente por familia de
;- instrucao, nao tem uma tabela estatica bytes->mnemonico pra inverter).
;-
;- Decomposicao usada (esquema padrao/classico de decodificacao do Z80,
;- amplamente documentado - a mesma base conceitual dos dois projetos que o
;- usuario indicou como referencia, DASM80 e disark): pro byte de opcode b,
;-   x = (b>>6)&3, y=(b>>3)&7, z=b&7, p=y>>1, q=y&1
;- Cada bloco x/z abaixo segue exatamente essa tabela classica.
;-
;- IndexMode (0=nenhum,1=IX,2=IY) troca H/L por IXH/IXL/IYH/IYL, (HL) por
;- (IX+d)/(IY+d), e HL por IX/IY em QUALQUER lugar da tabela base onde esses
;- registradores apareceriam - funciona porque a mesma tabela/formulas sao
;- reaproveitadas com tabelas de nomes de registrador diferentes; opcodes que
;- NAO referenciam H/L/(HL)/HL de jeito nenhum (ex.: "LD BC,nn") produzem o
;- MESMO texto nas 3 tabelas, entao nao precisa de uma lista separada de
;- "quais opcodes o DD/FD afeta" - a substituicao "automatica" ja da o
;- resultado certo em todos os casos (inclusive EX DE,HL/EXX/HALT, que nunca
;- passam pelas tabelas de registrador parametrizadas, entao ficam
;- corretamente IMUNES ao prefixo, igual o hardware real).
;-
;- Prefixos DD/FD encadeados (ex.: "DD FD 21 xx xx") sao tratados exatamente
;- como o hardware real: cada prefixo warning e consumido 1 byte por vez, so
;- o ULTIMO prefixo antes do opcode de verdade "vale" - implementado com um
;- laco simples que consome DD/FD em sequencia antes de decodificar.
;- ------------------------------------------------------------
;-

; Formata um deslocamento de 1 byte com sinal (-80 a +7F) como "+05"/"-05" -
; usado nos operandos "(IX+05)"/"(IY-05)".
Procedure.s Mamute_DisasmSignedDisp(d.a)
  Protected Signed.i = d
  If Signed > 127 : Signed - 256 : EndIf
  If Signed < 0
    ProcedureReturn "-" + Mamute_Hex2(-Signed)
  Else
    ProcedureReturn "+" + Mamute_Hex2(Signed)
  EndIf
EndProcedure

; Tabela "crua" B/C/D/E/H/L/(HL)/A - SEM substituicao de indice, usada pelo
; CB puro (nao-indexado) e pelo registrador-sombra das formas indexadas do
; CB (esse "sombra" sempre grava no registrador de 8 bits de verdade, nunca
; em IXH/IXL - comportamento real do hardware, mesmo nas formas nao
; documentadas).
Procedure.s Mamute_DisasmReg8Plain(Idx.i)
  Select Idx
    Case 0 : ProcedureReturn "B"
    Case 1 : ProcedureReturn "C"
    Case 2 : ProcedureReturn "D"
    Case 3 : ProcedureReturn "E"
    Case 4 : ProcedureReturn "H"
    Case 5 : ProcedureReturn "L"
    Case 6 : ProcedureReturn "(HL)"
    Case 7 : ProcedureReturn "A"
  EndSelect
  ProcedureReturn "?"
EndProcedure

Procedure.s Mamute_DisasmRotName(y.i)
  Select y
    Case 0 : ProcedureReturn "RLC"
    Case 1 : ProcedureReturn "RRC"
    Case 2 : ProcedureReturn "RL"
    Case 3 : ProcedureReturn "RR"
    Case 4 : ProcedureReturn "SLA"
    Case 5 : ProcedureReturn "SRA"
    Case 6 : ProcedureReturn "SLL" ; nao documentada, mas estavel/conhecida
    Case 7 : ProcedureReturn "SRL"
  EndSelect
  ProcedureReturn "?"
EndProcedure

Procedure.s Mamute_DisasmCC8(y.i)
  Select y
    Case 0 : ProcedureReturn "NZ"
    Case 1 : ProcedureReturn "Z"
    Case 2 : ProcedureReturn "NC"
    Case 3 : ProcedureReturn "C"
    Case 4 : ProcedureReturn "PO"
    Case 5 : ProcedureReturn "PE"
    Case 6 : ProcedureReturn "P"
    Case 7 : ProcedureReturn "M"
  EndSelect
  ProcedureReturn "?"
EndProcedure

Procedure.s Mamute_DisasmAluText(y.i, Operand.s)
  Select y
    Case 0 : ProcedureReturn "ADD A," + Operand
    Case 1 : ProcedureReturn "ADC A," + Operand
    Case 2 : ProcedureReturn "SUB " + Operand
    Case 3 : ProcedureReturn "SBC A," + Operand
    Case 4 : ProcedureReturn "AND " + Operand
    Case 5 : ProcedureReturn "XOR " + Operand
    Case 6 : ProcedureReturn "OR " + Operand
    Case 7 : ProcedureReturn "CP " + Operand
  EndSelect
  ProcedureReturn "?"
EndProcedure

; Par de 16 bits no esquema BC/DE/HL/SP (slot 2 = HL, substituido por IX/IY
; conforme IndexMode).
Procedure.s Mamute_DisasmReg16(Slot.i, IndexMode.b)
  Select Slot
    Case 0 : ProcedureReturn "BC"
    Case 1 : ProcedureReturn "DE"
    Case 2
      Select IndexMode
        Case 1 : ProcedureReturn "IX"
        Case 2 : ProcedureReturn "IY"
        Default : ProcedureReturn "HL"
      EndSelect
    Case 3 : ProcedureReturn "SP"
  EndSelect
  ProcedureReturn "?"
EndProcedure

; Mesma ideia, mas esquema BC/DE/HL/AF (usado so por PUSH/POP) - slot 3 e
; SEMPRE "AF" (nunca substituido - PUSH/POP AF nao existe como IX/IY, o
; hardware real ignora o prefixo nesse caso, e como este slot nunca troca de
; nome aqui, o resultado ja sai certo sem precisar de nenhum caso especial).
Procedure.s Mamute_DisasmReg16Alt(Slot.i, IndexMode.b)
  Select Slot
    Case 0 : ProcedureReturn "BC"
    Case 1 : ProcedureReturn "DE"
    Case 2
      Select IndexMode
        Case 1 : ProcedureReturn "IX"
        Case 2 : ProcedureReturn "IY"
        Default : ProcedureReturn "HL"
      EndSelect
    Case 3 : ProcedureReturn "AF"
  EndSelect
  ProcedureReturn "?"
EndProcedure

; Registrador de 8 bits com substituicao de indice - Idx 4/5 viram IXH/IXL/
; IYH/IYL (nao documentado, mas estavel/conhecido), Idx 6 vira (IX+d)/(IY+d)
; e CONSOME 1 byte de deslocamento em *Cursor (le e avanca) - so quando
; IndexMode<>0; sem prefixo, Idx 6 e so "(HL)" direto, sem byte extra.
Procedure.s Mamute_DisasmReg8(Idx.i, IndexMode.b, *Cursor.Integer)
  Select Idx
    Case 0 : ProcedureReturn "B"
    Case 1 : ProcedureReturn "C"
    Case 2 : ProcedureReturn "D"
    Case 3 : ProcedureReturn "E"
    Case 4
      Select IndexMode
        Case 1 : ProcedureReturn "IXH"
        Case 2 : ProcedureReturn "IYH"
        Default : ProcedureReturn "H"
      EndSelect
    Case 5
      Select IndexMode
        Case 1 : ProcedureReturn "IXL"
        Case 2 : ProcedureReturn "IYL"
        Default : ProcedureReturn "L"
      EndSelect
    Case 6
      If IndexMode = 0
        ProcedureReturn "(HL)"
      Else
        Protected D.a = Mamute_ReadByte(*Cursor\i & $FFFF)
        *Cursor\i + 1
        Protected IxName.s
        If IndexMode = 1 : IxName = "IX" : Else : IxName = "IY" : EndIf
        ProcedureReturn "(" + IxName + Mamute_DisasmSignedDisp(D) + ")"
      EndIf
    Case 7 : ProcedureReturn "A"
  EndSelect
  ProcedureReturn "?"
EndProcedure

; Le um imediato de 16 bits little-endian a partir de *Cursor (avanca 2).
Procedure.i Mamute_DisasmReadImm16(*Cursor.Integer)
  Protected Lo.a = Mamute_ReadByte(*Cursor\i & $FFFF)
  Protected Hi.a = Mamute_ReadByte((*Cursor\i + 1) & $FFFF)
  *Cursor\i + 2
  ProcedureReturn Lo | (Hi << 8)
EndProcedure

; Le o deslocamento relativo de 1 byte com sinal do JR/DJNZ a partir de
; *Cursor (avanca 1) e calcula o endereco de destino - relativo ao endereco
; JA DEPOIS do deslocamento (mesma convencao do Z80 de verdade: o PC ja
; avancou pela instrucao inteira antes do calculo) - como *Cursor aqui ja
; inclui qualquer prefixo DD/FD consumido antes (ver Mamute_DisasmOne), o
; destino sai certo mesmo num DD/FD+JR "desperdicado".
Procedure.s Mamute_DisasmRelTarget(*Cursor.Integer)
  Protected e.a = Mamute_ReadByte(*Cursor\i & $FFFF)
  *Cursor\i + 1
  Protected Signed.i = e
  If Signed > 127 : Signed - 256 : EndIf
  ProcedureReturn Mamute_Hex4((*Cursor\i + Signed) & $FFFF)
EndProcedure

; Decodifica um opcode CB-prefixado (bit ops) - IndexMode=0: 2 bytes (CB+op),
; alvo B/C/D/E/H/L/(HL)/A direto. IndexMode<>0: forma indexada de 4 bytes no
; total (DD/FD CB d op, contando o prefixo) - deslocamento 'd' vem ANTES do
; sub-opcode aqui (diferente das formas nao-CB, onde 'd' vem DEPOIS), alvo
; sempre (IX+d)/(IY+d); campo z2 (0-7, 6=sem copia) seleciona uma copia
; "sombra" nao documentada pro registrador de 8 bits real (nunca IXH/IXL) -
; nao existe pro BIT (nao tem escrita nenhuma pra copiar).
Procedure.s Mamute_DisasmDecodeCB(IndexMode.b, *Cursor.Integer)
  Protected d.a
  If IndexMode <> 0
    d = Mamute_ReadByte(*Cursor\i & $FFFF)
    *Cursor\i + 1
  EndIf
  Protected op.a = Mamute_ReadByte(*Cursor\i & $FFFF)
  *Cursor\i + 1

  Protected x2.i = (op >> 6) & 3
  Protected y2.i = (op >> 3) & 7
  Protected z2.i = op & 7

  Protected Target.s
  If IndexMode = 0
    Target = Mamute_DisasmReg8Plain(z2)
  Else
    Protected IxName.s
    If IndexMode = 1 : IxName = "IX" : Else : IxName = "IY" : EndIf
    Target = "(" + IxName + Mamute_DisasmSignedDisp(d) + ")"
  EndIf

  Protected Result.s
  Select x2
    Case 0 : Result = Mamute_DisasmRotName(y2) + " " + Target
    Case 1 : Result = "BIT " + Str(y2) + "," + Target
    Case 2 : Result = "RES " + Str(y2) + "," + Target
    Case 3 : Result = "SET " + Str(y2) + "," + Target
  EndSelect

  If IndexMode <> 0 And z2 <> 6 And x2 <> 1
    Result + "," + Mamute_DisasmReg8Plain(z2)
  EndIf

  ProcedureReturn Result
EndProcedure

; Decodifica um opcode ED-prefixado - NUNCA afetado por IndexMode (hardware
; real: ED ignora completamente qualquer DD/FD pendente, o prefixo fica so
; "desperdicado" mas ainda conta como byte consumido em Mamute_DisasmOne).
; x2=0 e x2=3 (fora dos blocos de bloco y2>=4/z2<=3) sao oficialmente
; indefinidos - comportamento real e estavel: agem como NOP de 2 bytes.
Procedure.s Mamute_DisasmDecodeED(*Cursor.Integer)
  Protected ed.a = Mamute_ReadByte(*Cursor\i & $FFFF)
  *Cursor\i + 1

  Protected x2.i = (ed >> 6) & 3
  Protected y2.i = (ed >> 3) & 7
  Protected z2.i = ed & 7
  Protected p2.i = y2 >> 1
  Protected q2.i = y2 & 1
  Protected Imm16.i
  Protected Rp.s
  Protected ImVal.i

  If x2 = 1
    Select z2
      Case 0
        If y2 = 6 : ProcedureReturn "IN F,(C)" : EndIf
        ProcedureReturn "IN " + Mamute_DisasmReg8Plain(y2) + ",(C)"
      Case 1
        If y2 = 6 : ProcedureReturn "OUT (C),0" : EndIf
        ProcedureReturn "OUT (C)," + Mamute_DisasmReg8Plain(y2)
      Case 2
        Rp = Mamute_DisasmReg16(p2, 0)
        If q2 = 0 : ProcedureReturn "SBC HL," + Rp : EndIf
        ProcedureReturn "ADC HL," + Rp
      Case 3
        Imm16 = Mamute_DisasmReadImm16(*Cursor)
        Rp = Mamute_DisasmReg16(p2, 0)
        If q2 = 0 : ProcedureReturn "LD (" + Mamute_Hex4(Imm16) + ")," + Rp : EndIf
        ProcedureReturn "LD " + Rp + ",(" + Mamute_Hex4(Imm16) + ")"
      Case 4
        ProcedureReturn "NEG"
      Case 5
        If y2 = 1 : ProcedureReturn "RETI" : EndIf
        ProcedureReturn "RETN"
      Case 6
        Select y2
          Case 0, 1, 4, 5 : ImVal = 0
          Case 2, 6 : ImVal = 1
          Case 3, 7 : ImVal = 2
        EndSelect
        ProcedureReturn "IM " + Str(ImVal)
      Case 7
        Select y2
          Case 0 : ProcedureReturn "LD I,A"
          Case 1 : ProcedureReturn "LD R,A"
          Case 2 : ProcedureReturn "LD A,I"
          Case 3 : ProcedureReturn "LD A,R"
          Case 4 : ProcedureReturn "RRD"
          Case 5 : ProcedureReturn "RLD"
          Default : ProcedureReturn "NOP"
        EndSelect
    EndSelect
  ElseIf x2 = 2 And z2 <= 3 And y2 >= 4
    Select y2
      Case 4
        Select z2
          Case 0 : ProcedureReturn "LDI"
          Case 1 : ProcedureReturn "CPI"
          Case 2 : ProcedureReturn "INI"
          Case 3 : ProcedureReturn "OUTI"
        EndSelect
      Case 5
        Select z2
          Case 0 : ProcedureReturn "LDD"
          Case 1 : ProcedureReturn "CPD"
          Case 2 : ProcedureReturn "IND"
          Case 3 : ProcedureReturn "OUTD"
        EndSelect
      Case 6
        Select z2
          Case 0 : ProcedureReturn "LDIR"
          Case 1 : ProcedureReturn "CPIR"
          Case 2 : ProcedureReturn "INIR"
          Case 3 : ProcedureReturn "OTIR"
        EndSelect
      Case 7
        Select z2
          Case 0 : ProcedureReturn "LDDR"
          Case 1 : ProcedureReturn "CPDR"
          Case 2 : ProcedureReturn "INDR"
          Case 3 : ProcedureReturn "OTDR"
        EndSelect
    EndSelect
  EndIf

  ProcedureReturn "NOP"
EndProcedure

; Decodifica um opcode da tabela BASE (nao-CB/ED/DD/FD) - IndexMode troca
; H/L/(HL)/HL pelos equivalentes IX/IY em QUALQUER lugar que apareceriam,
; via Mamute_DisasmReg8()/Reg16()/Reg16Alt() (ver comentario no topo desta
; secao pra por que isso basta, sem precisar de uma lista separada de "quais
; opcodes o prefixo afeta").
Procedure.s Mamute_DisasmDecodeBase(b.a, IndexMode.b, *Cursor.Integer)
  Protected x.i = (b >> 6) & 3
  Protected y.i = (b >> 3) & 7
  Protected z.i = b & 7
  Protected p.i = y >> 1
  Protected q.i = y & 1
  Protected Result.s
  Protected Imm16.i
  Protected Imm8.a
  Protected RegTxt.s

  Select x
    Case 0
      Select z
        Case 0
          Select y
            Case 0 : Result = "NOP"
            Case 1 : Result = "EX AF,AF'"
            Case 2 : Result = "DJNZ " + Mamute_DisasmRelTarget(*Cursor)
            Case 3 : Result = "JR " + Mamute_DisasmRelTarget(*Cursor)
            Default : Result = "JR " + Mamute_DisasmCC8(y - 4) + "," + Mamute_DisasmRelTarget(*Cursor)
          EndSelect
        Case 1
          If q = 0
            Imm16 = Mamute_DisasmReadImm16(*Cursor)
            Result = "LD " + Mamute_DisasmReg16(p, IndexMode) + "," + Mamute_Hex4(Imm16)
          Else
            Result = "ADD " + Mamute_DisasmReg16(2, IndexMode) + "," + Mamute_DisasmReg16(p, IndexMode)
          EndIf
        Case 2
          Select p
            Case 0
              If q = 0 : Result = "LD (BC),A" : Else : Result = "LD A,(BC)" : EndIf
            Case 1
              If q = 0 : Result = "LD (DE),A" : Else : Result = "LD A,(DE)" : EndIf
            Case 2
              Imm16 = Mamute_DisasmReadImm16(*Cursor)
              If q = 0
                Result = "LD (" + Mamute_Hex4(Imm16) + ")," + Mamute_DisasmReg16(2, IndexMode)
              Else
                Result = "LD " + Mamute_DisasmReg16(2, IndexMode) + ",(" + Mamute_Hex4(Imm16) + ")"
              EndIf
            Case 3
              Imm16 = Mamute_DisasmReadImm16(*Cursor)
              If q = 0 : Result = "LD (" + Mamute_Hex4(Imm16) + "),A" : Else : Result = "LD A,(" + Mamute_Hex4(Imm16) + ")" : EndIf
          EndSelect
        Case 3
          If q = 0 : Result = "INC " + Mamute_DisasmReg16(p, IndexMode) : Else : Result = "DEC " + Mamute_DisasmReg16(p, IndexMode) : EndIf
        Case 4
          Result = "INC " + Mamute_DisasmReg8(y, IndexMode, *Cursor)
        Case 5
          Result = "DEC " + Mamute_DisasmReg8(y, IndexMode, *Cursor)
        Case 6
          RegTxt = Mamute_DisasmReg8(y, IndexMode, *Cursor)
          Imm8 = Mamute_ReadByte(*Cursor\i & $FFFF)
          *Cursor\i + 1
          Result = "LD " + RegTxt + "," + Mamute_Hex2(Imm8)
        Case 7
          Select y
            Case 0 : Result = "RLCA"
            Case 1 : Result = "RRCA"
            Case 2 : Result = "RLA"
            Case 3 : Result = "RRA"
            Case 4 : Result = "DAA"
            Case 5 : Result = "CPL"
            Case 6 : Result = "SCF"
            Case 7 : Result = "CCF"
          EndSelect
      EndSelect

    Case 1
      If y = 6 And z = 6
        Result = "HALT"
      Else
        Result = "LD " + Mamute_DisasmReg8(y, IndexMode, *Cursor) + "," + Mamute_DisasmReg8(z, IndexMode, *Cursor)
      EndIf

    Case 2
      Result = Mamute_DisasmAluText(y, Mamute_DisasmReg8(z, IndexMode, *Cursor))

    Case 3
      Select z
        Case 0
          Result = "RET " + Mamute_DisasmCC8(y)
        Case 1
          If q = 0
            Result = "POP " + Mamute_DisasmReg16Alt(p, IndexMode)
          Else
            Select p
              Case 0 : Result = "RET"
              Case 1 : Result = "EXX"
              Case 2 : Result = "JP (" + Mamute_DisasmReg16(2, IndexMode) + ")"
              Case 3 : Result = "LD SP," + Mamute_DisasmReg16(2, IndexMode)
            EndSelect
          EndIf
        Case 2
          Imm16 = Mamute_DisasmReadImm16(*Cursor)
          Result = "JP " + Mamute_DisasmCC8(y) + "," + Mamute_Hex4(Imm16)
        Case 3
          Select y
            Case 0
              Imm16 = Mamute_DisasmReadImm16(*Cursor)
              Result = "JP " + Mamute_Hex4(Imm16)
            Case 1
              Result = "?" ; CB ja interceptado antes desta funcao - nunca deveria chegar aqui
            Case 2
              Imm8 = Mamute_ReadByte(*Cursor\i & $FFFF) : *Cursor\i + 1
              Result = "OUT (" + Mamute_Hex2(Imm8) + "),A"
            Case 3
              Imm8 = Mamute_ReadByte(*Cursor\i & $FFFF) : *Cursor\i + 1
              Result = "IN A,(" + Mamute_Hex2(Imm8) + ")"
            Case 4
              Result = "EX (SP)," + Mamute_DisasmReg16(2, IndexMode)
            Case 5
              Result = "EX DE,HL" ; nunca substituido - hardware real ignora o prefixo aqui
            Case 6
              Result = "DI"
            Case 7
              Result = "EI"
          EndSelect
        Case 4
          Imm16 = Mamute_DisasmReadImm16(*Cursor)
          Result = "CALL " + Mamute_DisasmCC8(y) + "," + Mamute_Hex4(Imm16)
        Case 5
          If q = 0
            Result = "PUSH " + Mamute_DisasmReg16Alt(p, IndexMode)
          Else
            Select p
              Case 0
                Imm16 = Mamute_DisasmReadImm16(*Cursor)
                Result = "CALL " + Mamute_Hex4(Imm16)
              Case 1 : Result = "?" ; DD ja interceptado antes desta funcao
              Case 2 : Result = "?" ; ED ja interceptado antes desta funcao
              Case 3 : Result = "?" ; FD ja interceptado antes desta funcao
            EndSelect
          EndIf
        Case 6
          Imm8 = Mamute_ReadByte(*Cursor\i & $FFFF) : *Cursor\i + 1
          Result = Mamute_DisasmAluText(y, Mamute_Hex2(Imm8))
        Case 7
          Result = "RST " + Mamute_Hex2(y * 8)
      EndSelect
  EndSelect

  ProcedureReturn Result
EndProcedure

; Ponto de entrada: decodifica UMA instrucao a partir de Addr (que pode
; comecar com 0, 1 ou mais bytes DD/FD encadeados - ver comentario no topo
; da secao). Devolve o comprimento TOTAL em *OutLen (incluindo prefixos) e o
; texto mnemonico+operandos em *OutText.
; Devolve o texto mnemonico+operandos diretamente (nao por ponteiro de
; String "Out" - esse padrao, embora documentado, travou com acesso
; invalido de verdade neste build/contexto especifico ao escrever em
; *Ptr.String\s vindo de dentro desta unidade de compilacao gigante;
; comprimento total ainda sai por ponteiro de Integer em *OutLen, que
; funciona sem problema (mesmo padrao ja usado em Mamute_ParseHexAddr()
; etc.) - so o ponteiro de String especificamente que nao e confiavel aqui.
Procedure.s Mamute_DisasmOne(Addr.i, *OutLen.Integer)
  Protected PrefixCount.i = 0
  Protected IndexMode.b = 0
  Protected CurAddr.i = Addr
  Protected b.a = Mamute_ReadByte(CurAddr & $FFFF)

  While (b = $DD Or b = $FD) And PrefixCount < 8 ; guarda defensiva - encadeamento real nunca chega nem perto disso
    If b = $DD : IndexMode = 1 : Else : IndexMode = 2 : EndIf
    PrefixCount + 1
    CurAddr + 1
    b = Mamute_ReadByte(CurAddr & $FFFF)
  Wend

  Protected Cursor.i = CurAddr + 1
  Protected Text.s
  Select b
    Case $CB
      Text = Mamute_DisasmDecodeCB(IndexMode, @Cursor)
    Case $ED
      Text = Mamute_DisasmDecodeED(@Cursor)
    Default
      Text = Mamute_DisasmDecodeBase(b, IndexMode, @Cursor)
  EndSelect

  *OutLen\i = PrefixCount + (Cursor - CurAddr)
  ProcedureReturn Text
EndProcedure

; Monta as linhas formatadas "ENDERECO  BYTES-HEXA  MNEMONICO" pros
; comandos L/LP, a partir de StartAddr - se HasEndAddr, decodifica ate
; ultrapassar EndAddr (instrucao que comeca dentro do intervalo entra
; inteira, mesmo que termine depois - comportamento padrao de disassembler,
; igual o exemplo do manual original); senao, decodifica exatamente 10
; instrucoes. A listagem PARA (nao envolve pro endereco 0000) assim que a
; PROXIMA instrucao comecaria depois de FFFF - decodificar enderecos indo
; pra tras no meio de uma mesma listagem seria confuso de ler, diferente do
; wraparound de leitura ja usado pelo SH/M (que faz sentido ali porque so
; devolve UM endereco encontrado, nao uma sequencia de linhas). Se os
; ULTIMOS bytes de uma unica instrucao que ja comecou dentro do limite
; passarem um pouco de FFFF (ex.: uma instrucao de 3 bytes comecando em
; FFFE), esses bytes finais ainda sao lidos via o wraparound normal de
; Mamute_ReadByte(...&$FFFF) - so a listagem como um todo nao continua
; depois disso. *OutNextAddr recebe o endereco logo apos a ultima instrucao
; mostrada, pra "L sem endereco" continuar dali.
Procedure Mamute_DisasmBuildLines(List Lines.s(), StartAddr.i, HasEndAddr.b, EndAddr.i, *OutNextAddr.Integer)
  ClearList(Lines())
  Protected CurAddr.i = StartAddr
  Protected LineCount.i = 0
  Protected InstrLen.i
  Protected Text.s
  Protected HexBytes.s
  Protected i.i
  Protected RawByte.a
  Protected Line.s

  Repeat
    If HasEndAddr
      If CurAddr > EndAddr : Break : EndIf
    Else
      If LineCount >= 10 : Break : EndIf
    EndIf

    Text = Mamute_DisasmOne(CurAddr, @InstrLen)
    If InstrLen < 1 : InstrLen = 1 : EndIf

    HexBytes = ""
    For i = 0 To InstrLen - 1
      RawByte = Mamute_ReadByte((CurAddr + i) & $FFFF)
      If HexBytes <> "" : HexBytes + " " : EndIf
      HexBytes + Mamute_Hex2(RawByte)
    Next

    Line = Mamute_Hex4(CurAddr & $FFFF) + "  " + LSet(HexBytes, 11, " ") + "  " + Text
    AddElement(Lines())
    Lines() = Line

    CurAddr + InstrLen
    LineCount + 1
  Until CurAddr > $FFFF

  *OutNextAddr\i = CurAddr & $FFFF
EndProcedure

; Converte um caractere ("Q", "1", "z"...) na constante #PB_Shortcut_* certa,
; pra registrar como AddKeyboardShortcut() - usado pelo comando S
; (MamuteMGui.pbi) pras 16 teclas configuraveis. 0 (nenhuma constante) se
; Ch nao for exatamente 1 letra/digito.
Procedure.i Mamute_KeyCharToShortcut(Ch.s)
  If Len(Ch) <> 1
    ProcedureReturn 0
  EndIf
  Select UCase(Ch)
    Case "0" : ProcedureReturn #PB_Shortcut_0
    Case "1" : ProcedureReturn #PB_Shortcut_1
    Case "2" : ProcedureReturn #PB_Shortcut_2
    Case "3" : ProcedureReturn #PB_Shortcut_3
    Case "4" : ProcedureReturn #PB_Shortcut_4
    Case "5" : ProcedureReturn #PB_Shortcut_5
    Case "6" : ProcedureReturn #PB_Shortcut_6
    Case "7" : ProcedureReturn #PB_Shortcut_7
    Case "8" : ProcedureReturn #PB_Shortcut_8
    Case "9" : ProcedureReturn #PB_Shortcut_9
    Case "A" : ProcedureReturn #PB_Shortcut_A
    Case "B" : ProcedureReturn #PB_Shortcut_B
    Case "C" : ProcedureReturn #PB_Shortcut_C
    Case "D" : ProcedureReturn #PB_Shortcut_D
    Case "E" : ProcedureReturn #PB_Shortcut_E
    Case "F" : ProcedureReturn #PB_Shortcut_F
    Case "G" : ProcedureReturn #PB_Shortcut_G
    Case "H" : ProcedureReturn #PB_Shortcut_H
    Case "I" : ProcedureReturn #PB_Shortcut_I
    Case "J" : ProcedureReturn #PB_Shortcut_J
    Case "K" : ProcedureReturn #PB_Shortcut_K
    Case "L" : ProcedureReturn #PB_Shortcut_L
    Case "M" : ProcedureReturn #PB_Shortcut_M
    Case "N" : ProcedureReturn #PB_Shortcut_N
    Case "O" : ProcedureReturn #PB_Shortcut_O
    Case "P" : ProcedureReturn #PB_Shortcut_P
    Case "Q" : ProcedureReturn #PB_Shortcut_Q
    Case "R" : ProcedureReturn #PB_Shortcut_R
    Case "S" : ProcedureReturn #PB_Shortcut_S
    Case "T" : ProcedureReturn #PB_Shortcut_T
    Case "U" : ProcedureReturn #PB_Shortcut_U
    Case "V" : ProcedureReturn #PB_Shortcut_V
    Case "W" : ProcedureReturn #PB_Shortcut_W
    Case "X" : ProcedureReturn #PB_Shortcut_X
    Case "Y" : ProcedureReturn #PB_Shortcut_Y
    Case "Z" : ProcedureReturn #PB_Shortcut_Z
  EndSelect
  ProcedureReturn 0
EndProcedure

;- ------------------------------------------------------------
;- Configuracoes / persistencia
;- ------------------------------------------------------------

Procedure.s MamuteCfg_FilePath()
  ProcedureReturn GetPathPart(ProgramFilename()) + "mamute_settings.json"
EndProcedure

Procedure MamuteCfg_Load()
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      MamuteCfgCell(Slot, Pagina)\Tipo = #MamuteMem_Empty
      MamuteCfgCell(Slot, Pagina)\FilePath = ""
      MamuteCfgCell(Slot, Pagina)\FileOffset = 0
    Next
  Next
  MamuteFontName = "Consolas"
  MamuteFontSize = 16
  MamuteFontBold = #True
  Mamute_SKeyMapDefaults()
  MamuteVramSize = 16384

  Protected FilePath.s = MamuteCfg_FilePath()
  If FileSize(FilePath) <= 0
    ProcedureReturn
  EndIf

  Protected Json = LoadJSON(#PB_Any, FilePath)
  If Not Json
    ProcedureReturn
  EndIf

  Protected Root = JSONValue(Json)
  Protected M
  M = GetJSONMember(Root, "FontName") : If M : MamuteFontName = GetJSONString(M)  : EndIf
  M = GetJSONMember(Root, "FontSize") : If M : MamuteFontSize = GetJSONInteger(M) : EndIf
  M = GetJSONMember(Root, "FontBold") : If M : MamuteFontBold = GetJSONBoolean(M) : EndIf
  M = GetJSONMember(Root, "VramSize") : If M : MamuteVramSize = GetJSONInteger(M) : EndIf
  If MamuteVramSize <> 16384 And MamuteVramSize <> 131072 And MamuteVramSize <> 196608
    MamuteVramSize = 16384 ; valor invalido/corrompido - volta pro padrao seguro
  EndIf

  Protected CellsElem = GetJSONMember(Root, "Cells")
  If CellsElem
    Protected N = JSONArraySize(CellsElem)
    Protected Idx, Item, S, P
    For Idx = 0 To N - 1
      Item = GetJSONElement(CellsElem, Idx)
      If Item
        S = -1 : P = -1
        M = GetJSONMember(Item, "Slot")  : If M : S = GetJSONInteger(M) : EndIf
        M = GetJSONMember(Item, "Pagina") : If M : P = GetJSONInteger(M) : EndIf
        If S >= 0 And S <= 3 And P >= 0 And P <= 3
          M = GetJSONMember(Item, "Tipo") : If M : MamuteCfgCell(S, P)\Tipo = GetJSONInteger(M) : EndIf
          M = GetJSONMember(Item, "Arquivo") : If M : MamuteCfgCell(S, P)\FilePath = GetJSONString(M) : EndIf
          M = GetJSONMember(Item, "Offset") : If M : MamuteCfgCell(S, P)\FileOffset = GetJSONInteger(M) : EndIf
        EndIf
      EndIf
    Next
  EndIf

  ; Teclado do comando S - array plano de 16 strings de 1 caractere,
  ; indexado pelo VALOR do nibble (0-15), nao pela ordem de exibicao.
  Protected SKeysElem = GetJSONMember(Root, "SKeys")
  If SKeysElem And JSONArraySize(SKeysElem) = 16
    Protected KIdx
    For KIdx = 0 To 15
      Protected KItem = GetJSONElement(SKeysElem, KIdx)
      If KItem : MamuteSKeyMap(KIdx) = GetJSONString(KItem) : EndIf
    Next
  EndIf
  FreeJSON(Json)
EndProcedure

Procedure MamuteCfg_Save()
  Protected Json = CreateJSON(#PB_Any)
  Protected Root = SetJSONObject(JSONValue(Json))
  SetJSONString(AddJSONMember(Root, "FontName"), MamuteFontName)
  SetJSONInteger(AddJSONMember(Root, "FontSize"), MamuteFontSize)
  SetJSONBoolean(AddJSONMember(Root, "FontBold"), MamuteFontBold)
  SetJSONInteger(AddJSONMember(Root, "VramSize"), MamuteVramSize)
  Protected CellsElem = SetJSONArray(AddJSONMember(Root, "Cells"))

  Protected Slot, Pagina, Elem
  For Slot = 0 To 3
    For Pagina = 0 To 3
      Elem = AddJSONElement(CellsElem)
      SetJSONObject(Elem)
      SetJSONInteger(AddJSONMember(Elem, "Slot"), Slot)
      SetJSONInteger(AddJSONMember(Elem, "Pagina"), Pagina)
      SetJSONInteger(AddJSONMember(Elem, "Tipo"), MamuteCfgCell(Slot, Pagina)\Tipo)
      SetJSONString(AddJSONMember(Elem, "Arquivo"), MamuteCfgCell(Slot, Pagina)\FilePath)
      SetJSONInteger(AddJSONMember(Elem, "Offset"), MamuteCfgCell(Slot, Pagina)\FileOffset)
    Next
  Next

  Protected SKeysElem = SetJSONArray(AddJSONMember(Root, "SKeys"))
  Protected KIdx2
  For KIdx2 = 0 To 15
    SetJSONString(AddJSONElement(SKeysElem), MamuteSKeyMap(KIdx2))
  Next

  SaveJSON(Json, MamuteCfg_FilePath(), #PB_JSON_PrettyPrint)
  FreeJSON(Json)
EndProcedure

;- ------------------------------------------------------------
;- Tela "Configurar -> Mamute Assembler..."
;- ------------------------------------------------------------

; Atualiza o texto exibido na linha ItemIdx da lista a partir de
; WorkCells(Slot,Pagina) - usado tanto ao popular a lista inteira quanto ao
; refletir uma edicao pontual (Tipo/Arquivo do celula selecionada).
Procedure MamuteSettings_RefreshRow(List, ItemIdx.i, Slot.i, Pagina.i, Array WorkCells.MamuteMemCell(2))
  SetGadgetItemText(List, ItemIdx, Str(Slot), 0)
  SetGadgetItemText(List, ItemIdx, Str(Pagina), 1)
  SetGadgetItemText(List, ItemIdx, Mamute_PageRangeText(Pagina), 2)
  SetGadgetItemText(List, ItemIdx, Mamute_TipoText(WorkCells(Slot, Pagina)\Tipo), 3)
  Protected ArquivoText.s = WorkCells(Slot, Pagina)\FilePath
  If ArquivoText <> "" And WorkCells(Slot, Pagina)\FileOffset > 0
    ArquivoText + " (ultimos 16KB)"
  EndIf
  SetGadgetItemText(List, ItemIdx, ArquivoText, 4)
EndProcedure

Procedure.b MamuteSettings_TipoUsesFile(Tipo.b)
  ProcedureReturn Bool(Tipo = #MamuteMem_ROM Or Tipo = #MamuteMem_Basic)
EndProcedure

Procedure MamuteSettings_OpenWindow(ParentWindow)
  MamuteCfg_Load()

  ; Copia de trabalho - Salvar/Cancelar decide se isso vira o MamuteCfgCell()
  ; global de verdade, mesmo espirito das outras telas de Configurar desta
  ; IDE (nunca aplica edicao direto no global antes de "Salvar").
  Protected Dim WorkCells.MamuteMemCell(3, 3)
  Protected Slot, Pagina
  For Slot = 0 To 3
    For Pagina = 0 To 3
      WorkCells(Slot, Pagina) = MamuteCfgCell(Slot, Pagina)
    Next
  Next

  Protected WinW = 820, WinH = 830
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Configurar - Mamute Assembler",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf

  TextGadget(#PB_Any, 24, 24, WinW - 48, 40,
            "Configuracao fisica dos 16 blocos de memoria (4 slots x 4 paginas de 16KB) simulados pelo" + Chr(10) +
            "Mamute Assembler. Selecione uma linha pra ajustar o tipo/arquivo abaixo.")

  Protected G_List = ListIconGadget(#PB_Any, 24, 76, WinW - 48, 300, "Slot", 60, #PB_ListIcon_FullRowSelect)
  AddGadgetColumn(G_List, 1, "Pagina", 70)
  AddGadgetColumn(G_List, 2, "Endereco", 110)
  AddGadgetColumn(G_List, 3, "Tipo", 90)
  AddGadgetColumn(G_List, 4, "Arquivo", WinW - 48 - 60 - 70 - 110 - 90)

  For Slot = 0 To 3
    For Pagina = 0 To 3
      AddGadgetItem(G_List, -1, "" + Chr(10) + "" + Chr(10) + "" + Chr(10) + "" + Chr(10) + "")
      MamuteSettings_RefreshRow(G_List, Slot * 4 + Pagina, Slot, Pagina, WorkCells())
    Next
  Next

  Protected EditY = 76 + 300 + 24
  TextGadget(#PB_Any, 24, EditY + 4, 50, 20, "Tipo:")
  Protected G_Tipo = ComboBoxGadget(#PB_Any, 80, EditY, 160, 24)
  AddGadgetItem(G_Tipo, #MamuteMem_Empty, "Vazio")
  AddGadgetItem(G_Tipo, #MamuteMem_RAM, "RAM")
  AddGadgetItem(G_Tipo, #MamuteMem_ROM, "ROM")
  AddGadgetItem(G_Tipo, #MamuteMem_Basic, "BASIC")
  DisableGadget(G_Tipo, #True)

  TextGadget(#PB_Any, 260, EditY + 4, 60, 20, "Arquivo:")
  Protected G_File = StringGadget(#PB_Any, 324, EditY, WinW - 324 - 24 - 64 - 8, 24, "")
  Protected G_FileBrowse = ThemedButton(WinW - 24 - 64, EditY, 64, 24, "...", "")
  DisableGadget(G_File, #True)
  DisableGadget(G_FileBrowse, #True)

  ; Fonte do terminal (MamuteAssemblerGui.pbi) - monoespacada de proposito,
  ; mesma enumeracao ja usada pela fonte do editor de codigo
  ; (EditorCfg_EnumMonospaceFonts(), EditorSettings.pbi).
  Protected FontY = EditY + 48
  TextGadget(#PB_Any, 24, FontY + 4, 140, 20, "Fonte do terminal:")
  Protected G_TermFont = ComboBoxGadget(#PB_Any, 170, FontY, 220, 24)

  Protected NewList TermFonts.s()
  EditorCfg_EnumMonospaceFonts(TermFonts())
  Protected TermFontIndex = -1, TermFontIdx = 0
  ForEach TermFonts()
    AddGadgetItem(G_TermFont, -1, TermFonts())
    If TermFonts() = MamuteFontName
      TermFontIndex = TermFontIdx
    EndIf
    TermFontIdx + 1
  Next
  If TermFontIndex < 0
    AddGadgetItem(G_TermFont, -1, MamuteFontName)
    TermFontIndex = CountGadgetItems(G_TermFont) - 1
  EndIf
  SetGadgetState(G_TermFont, TermFontIndex)

  TextGadget(#PB_Any, 400, FontY + 4, 40, 20, "Tam.")
  Protected G_TermFontSize = StringGadget(#PB_Any, 444, FontY, 50, 24, Str(MamuteFontSize))

  Protected G_TermFontBold = CheckBoxGadget(#PB_Any, 510, FontY + 3, 140, 22, "Negrito")
  SetGadgetState(G_TermFontBold, MamuteFontBold)

  ; Teclado do comando S (MamuteMGui.pbi) - pedido explicito do usuario:
  ; "escolher quais teclas do teclado ele vai usar como
  ; 1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,0". Grade 4x4 na MESMA ordem de exibicao
  ; pedida (nao a ordem de armazenamento por valor, ver MamuteSKeyMap() em
  ; MamuteSupport.pbi) - com o padrao 1,2,3,4/Q,W,E,R/A,S,D,F/Z,X,C,V isso
  ; visualmente cai exatamente sobre essas 4 fileiras do teclado QWERTY.
  Protected KeysY = FontY + 48
  TextGadget(#PB_Any, 24, KeysY, WinW - 48, 20,
            "Teclado do comando S - qual tecla digitar pra cada digito hexa (0-9, A-F):")
  KeysY + 26

  ; DisplayOrder(i) = o VALOR do nibble mostrado na posicao i da grade
  ; (0..15, varrendo esquerda->direita, cima->baixo) - "1,2,3,4,5,6,7,8,9,A,
  ; B,C,D,E,F,0" pedido explicito do usuario, valor 0 por ultimo de proposito.
  Protected Dim DisplayOrder.i(15)
  DisplayOrder(0)=1 : DisplayOrder(1)=2 : DisplayOrder(2)=3 : DisplayOrder(3)=4
  DisplayOrder(4)=5 : DisplayOrder(5)=6 : DisplayOrder(6)=7 : DisplayOrder(7)=8
  DisplayOrder(8)=9 : DisplayOrder(9)=10 : DisplayOrder(10)=11 : DisplayOrder(11)=12
  DisplayOrder(12)=13 : DisplayOrder(13)=14 : DisplayOrder(14)=15 : DisplayOrder(15)=0

  Protected Dim G_SKey(15)
  Protected KeyCol.i, KeyRow.i, KeyCellW.i = (WinW - 48) / 4, KeyIdx.i, KeyValue.i, KeyX.i, KeyRowY.i
  For KeyRow = 0 To 3
    KeyRowY = KeysY + KeyRow * 34
    For KeyCol = 0 To 3
      KeyIdx = KeyRow * 4 + KeyCol
      KeyValue = DisplayOrder(KeyIdx)
      KeyX = 24 + KeyCol * KeyCellW
      TextGadget(#PB_Any, KeyX, KeyRowY + 3, 30, 20, Mid("0123456789ABCDEF", KeyValue + 1, 1) + ":")
      G_SKey(KeyIdx) = StringGadget(#PB_Any, KeyX + 34, KeyRowY, 50, 24, MamuteSKeyMap(KeyValue))
    Next
  Next
  KeysY + 4 * 34 + 8

  ; VRAM simulada (comandos V, futuros VLOAD/VSAVE) - pedido explicito do
  ; usuario: "permita incluir tambem configuracao de VRAM... escolha entre
  ; 16, 128 ou 192 Kb". Enderecamento plano (sem bancos - ver comentario de
  ; MamuteVRAM() em MamuteSupport.pbi), entao a unica escolha real aqui e o
  ; tamanho/limite superior.
  TextGadget(#PB_Any, 24, KeysY + 4, 140, 20, "Tamanho da VRAM:")
  Protected G_VramSize = ComboBoxGadget(#PB_Any, 170, KeysY, 160, 24)
  AddGadgetItem(G_VramSize, 0, "16 KB (MSX1)")
  AddGadgetItem(G_VramSize, 1, "128 KB")
  AddGadgetItem(G_VramSize, 2, "192 KB")
  Select MamuteVramSize
    Case 131072 : SetGadgetState(G_VramSize, 1)
    Case 196608 : SetGadgetState(G_VramSize, 2)
    Default     : SetGadgetState(G_VramSize, 0)
  EndSelect
  KeysY + 34

  Protected G_Save = ThemedButton(WinW - 256, WinH - 56, 110, 32, "Salvar", Chr(#Icon_Save))
  GadgetToolTip(G_Save, "Salvar")
  Protected G_Cancel = ThemedButton(WinW - 134, WinH - 56, 110, 32, "Cancelar", "")

  Protected SelectedSlot.i = -1, SelectedPagina.i = -1

  Protected Event, Quit = #False, Saved = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_List
            If EventType() = #PB_EventType_Change
              Protected Sel = GetGadgetState(G_List)
              If Sel >= 0
                SelectedSlot = Sel / 4
                SelectedPagina = Sel % 4
                DisableGadget(G_Tipo, #False)
                SetGadgetState(G_Tipo, WorkCells(SelectedSlot, SelectedPagina)\Tipo)
                SetGadgetText(G_File, WorkCells(SelectedSlot, SelectedPagina)\FilePath)
                Protected UsesFile.b = MamuteSettings_TipoUsesFile(WorkCells(SelectedSlot, SelectedPagina)\Tipo)
                DisableGadget(G_File, Bool(Not UsesFile))
                DisableGadget(G_FileBrowse, Bool(Not UsesFile))
              EndIf
            EndIf

          Case G_Tipo
            If SelectedSlot >= 0
              Protected NewTipo.b = GetGadgetState(G_Tipo)
              WorkCells(SelectedSlot, SelectedPagina)\Tipo = NewTipo
              Protected UsesFile2.b = MamuteSettings_TipoUsesFile(NewTipo)
              DisableGadget(G_File, Bool(Not UsesFile2))
              DisableGadget(G_FileBrowse, Bool(Not UsesFile2))
              If Not UsesFile2
                WorkCells(SelectedSlot, SelectedPagina)\FilePath = ""
                SetGadgetText(G_File, "")
              EndIf
              MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
              SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
            EndIf

          Case G_File
            If SelectedSlot >= 0 And EventType() = #PB_EventType_Change
              WorkCells(SelectedSlot, SelectedPagina)\FilePath = GetGadgetText(G_File)
              WorkCells(SelectedSlot, SelectedPagina)\FileOffset = 0 ; digitado a mao - abandona o offset de uma divisao BIOS+BASIC anterior
              MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
              SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
            EndIf

          Case G_FileBrowse
            If SelectedSlot >= 0
              Protected PickPath.s = OpenFileRequester("Selecione o arquivo (ROM/BASIC)", GetGadgetText(G_File),
                                                       "Todos os arquivos (*.*)|*.*", 0)
              If PickPath <> ""
                ; Arquivo de 32KB escolhido pra uma celula ROM na Pagina 0 (BIOS) -
                ; muito comum a BIOS e o BASIC virem combinados num unico arquivo
                ; assim num MSX real. Pergunta antes de assumir - "Nao" trata como
                ; um arquivo qualquer (usa so os primeiros 16KB aqui, nao mexe na
                ; Pagina 1). O usuario continua livre pra trocar o arquivo da
                ; Pagina 1 manualmente depois, mesmo apos o "Sim" auto-preencher.
                Protected HandledAsCombined.b = #False
                If SelectedPagina = 0 And WorkCells(SelectedSlot, 0)\Tipo = #MamuteMem_ROM And FileSize(PickPath) = #Mamute_CombinedBiosBasicSize
                  Protected CombinedAnswer = MessageRequester("BIOS + BASIC combinados?",
                    "Este arquivo tem 32KB - e comum a BIOS e o BASIC virem combinados num unico" + Chr(10) +
                    "arquivo assim num MSX real." + Chr(10) + Chr(10) +
                    "Usar os primeiros 16KB aqui (BIOS, Pagina 0) e os ultimos 16KB na Pagina 1" + Chr(10) +
                    "(BASIC) deste mesmo slot?",
                    #PB_MessageRequester_YesNo | #PB_MessageRequester_Info)
                  If CombinedAnswer = #PB_MessageRequester_Yes
                    WorkCells(SelectedSlot, 0)\FilePath = PickPath
                    WorkCells(SelectedSlot, 0)\FileOffset = 0
                    WorkCells(SelectedSlot, 1)\Tipo = #MamuteMem_Basic
                    WorkCells(SelectedSlot, 1)\FilePath = PickPath
                    WorkCells(SelectedSlot, 1)\FileOffset = #Mamute_PageSize
                    MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + 0, SelectedSlot, 0, WorkCells())
                    MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + 1, SelectedSlot, 1, WorkCells())
                    HandledAsCombined = #True
                  EndIf
                EndIf

                If Not HandledAsCombined
                  WorkCells(SelectedSlot, SelectedPagina)\FilePath = PickPath
                  WorkCells(SelectedSlot, SelectedPagina)\FileOffset = 0
                  MamuteSettings_RefreshRow(G_List, SelectedSlot * 4 + SelectedPagina, SelectedSlot, SelectedPagina, WorkCells())
                EndIf

                SetGadgetText(G_File, PickPath)
                SetGadgetState(G_List, SelectedSlot * 4 + SelectedPagina)
              EndIf
            EndIf

          Case G_Save
            Saved = #True
            Quit = #True

          Case G_Cancel
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  If Saved
    For Slot = 0 To 3
      For Pagina = 0 To 3
        MamuteCfgCell(Slot, Pagina) = WorkCells(Slot, Pagina)
      Next
    Next
    MamuteFontName = GetGadgetText(G_TermFont)
    Protected TypedSize.i = Val(GetGadgetText(G_TermFontSize))
    If TypedSize < 6 : TypedSize = 6 : EndIf
    If TypedSize > 72 : TypedSize = 72 : EndIf
    MamuteFontSize = TypedSize
    MamuteFontBold = GetGadgetState(G_TermFontBold)

    Protected KIdxSave.i, TypedKey.s
    For KIdxSave = 0 To 15
      TypedKey = Trim(GetGadgetText(G_SKey(KIdxSave)))
      If TypedKey <> ""
        MamuteSKeyMap(DisplayOrder(KIdxSave)) = UCase(Left(TypedKey, 1))
      EndIf
    Next

    Select GetGadgetState(G_VramSize)
      Case 1 : MamuteVramSize = 131072
      Case 2 : MamuteVramSize = 196608
      Default : MamuteVramSize = 16384
    EndSelect

    MamuteCfg_Save()
  EndIf

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
