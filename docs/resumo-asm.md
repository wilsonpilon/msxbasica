# Assembler Z80 nativo (módulo 2) — resumo de progresso

> Documento de acompanhamento desta frente de trabalho (não é a spec funcional — essa é
> `docs/SPEC.md` módulo 2 — este arquivo é o "estado da implementação", para retomar em qualquer
> máquina). Atualizado a cada marco concluído.

## Objetivo

Assembler Z80 nativo em PureBasic, **compatível com M80/L80** (Microsoft MACRO-80/LINK-80),
integrado ao editor. Especificação de comportamento: **Nestor80** (Konamiman,
github.com/Konamiman/Nestor80) — assembler C# moderno, 100% compatível M80/L80.

## Decisões de escopo (fechadas com o usuário, 2026-07-24)

1. **REL + Linker desde já** — arquitetura completa tipo N80/LK80 (assembler emite `.REL`
   relocável, linker separado resolve símbolos entre módulos, gera binário final), não só saída
   absoluta.
2. **Macros básicas na v1** — `MACRO`/`ENDM` com parâmetros e expansão, `IF`/`ENDIF`. `REPT`/`IRP`/
   `IRPC`/`IRPS` ficam para depois.
3. **Motor já integrado ao menu do editor** — item de menu "Montar" real já na v1, não só CLI
   headless.
4. **(2026-07-24, adicionado depois do plano original) Libstor80 (gerenciador de biblioteca) também
   entra em escopo**, não só o Linkstor80/LK80 (linker). O pedido explícito do usuário: gerar uma
   biblioteca (`.LIB`, várias rotinas montadas separadamente) e, na hora de linkar um programa contra
   ela, só as partes/módulos realmente referenciados são puxados pro `.COM` final (linkagem estática
   seletiva — nenhuma rotina não usada da lib entra no binário). Isso **não muda a arquitetura do
   linker em si**: o algoritmo de resolução de `.REQUEST`/biblioteca já pesquisado (ver
   `nestor80-linker.md`, Fase B) já é exatamente esse comportamento — uma "biblioteca" é só um
   arquivo com vários "programas" `.REL` concatenados (cada um já auto-delimitado pelo item "End of
   program" do formato), e o linker só puxa pra dentro o(s) programa(s) que resolvem um símbolo
   externo pendente (sem esse programa, ninguém referenciado → não entra). O que falta é um **gerenciador de biblioteca próprio**
   (`editor/Z80Lib.pbi`, `DeclareModule Z80Lib`, equivalente ao LB80/Libstor80 — criar/listar/
   adicionar/remover módulos `.REL` dentro de um arquivo `.LIB`), reaproveitando o parser/escritor de
   `.REL` que `Z80Link.pbi` já vai ter. Ver checklist da Fase B abaixo.
5. **(2026-07-24, adicionado ao fechar a sessão) Duas integrações adicionais confirmadas como objetivo
   do módulo, nenhuma iniciada ainda** — registradas aqui pra não se perderem entre sessões:
   - **Integração com o sistema de projeto** (módulo 13 do `docs/SPEC.md`) — o assembler ainda não tem
     tabela própria no `.msxproject` (número/tag/navegação/Registrar, mesmo padrão de sprites/
     alfabetos/sons/músicas/telas). O texto-fonte `.asm` já é salvo como `documents` (mecanismo
     genérico que toda aba de texto já tem), mas o **binário montado** não tem lugar nenhum no banco
     hoje.
   - **Integração com MSX-BASIC** — hoje "Montar" só salva um `.bin` solto no disco do PC. Dois
     caminhos pedidos: (1) **`BLOAD`** — colocar o `.bin` num `.dsk` (reaproveitando `MSXDisk.pbi`,
     mesmo mecanismo de `RunOnOpenMSX()`); (2) **listing `DATA`/`POKE` em hexadecimal** gerado a partir
     do binário montado, pro código Z80 poder ser colado dentro de um programa BASIC sem depender de
     carregar um arquivo à parte (mesmo espírito de `PsgGen_RawBytes()`, o botão "Gerar bytes crus" já
     existente no editor de som PSG — ver módulo 6 do `docs/SPEC.md` como referência de como esse tipo
     de botão já funciona no resto da IDE).
   Ver `docs/SPEC.md` módulo 2c pro texto completo dessas duas pendências.

Plano completo (fases A/B/C, arquitetura de arquivos, convenções PureBasic a seguir):
`C:\Users\wilso\.claude\plans\lazy-soaring-swing.md` (máquina local do Claude Code, não faz parte
do repo — o resumo abaixo é a versão persistida/git-tracked do que importa desse plano).

## Material de referência

- **`E:\msxbasica\nestor80\`** — clone raso do Nestor80, **gitignored** (`.gitignore` já tem
  `/nestor80/`, mesmo tratamento de `/badig/`: referência de leitura, não dependência de runtime).
  Para recriar em outra máquina:
  ```powershell
  git clone --depth 1 https://github.com/Konamiman/Nestor80.git nestor80
  ```
  Docs mais importantes dentro do clone: `docs/LanguageReference.md` (sintaxe/diretivas),
  `docs/MACRO-80.txt` (manual original Microsoft MACRO-80), `docs/asmlnk.txt` (manual original
  LINK-80), `docs/RelocatableFileFormat.md` (formato `.REL` byte-a-byte),
  `docs/WritingRelocatableCode.md` (modelo ASEG/CSEG/DSEG/COMMON/PUBLIC/EXTRN).
- **Oráculos de teste `N80.exe`/`LK80.exe`/`LB80.exe`** — o próprio Nestor80 (assembler + linker +
  gerenciador de biblioteca) compila e roda neste ambiente (`dotnet` 10.0.300 instalado). Usados para
  validar bytes gerados pelo port PureBasic, mesma técnica já usada para o tokenizador nativo
  (`docs/SPEC.md` módulo 11). Para recriar em qualquer máquina com `dotnet` instalado:
  ```powershell
  cd nestor80
  dotnet build N80/N80.csproj -c Release    # assembler - binário em N80\bin\Release\net6.0\N80.exe
  dotnet build LK80/LK80.csproj -c Release  # linker - binário em LK80\bin\Release\net6.0\LK80.exe
  dotnet build LB80/LB80.csproj -c Release  # biblioteca - binário em LB80\bin\Release\net6.0\LB80.exe
  ```
  Uso do assembler: `N80.exe fonte.asm saida.bin` (segundo argumento posicional = arquivo de saída,
  **não** `--output-file`). `LK80.exe`/`LB80.exe` ainda não foram exercitados além do `--help` nesta
  sessão (Fase B não começou de verdade) — `--help` de cada um já dá a sintaxe completa. Todos os três
  testados e confirmados compilando/funcionando 2026-07-24.
- `docs/reference/nestor80-language.md`, `docs/reference/nestor80-rel-format.md`,
  `docs/reference/nestor80-linker.md` — notas extraídas, mesmo padrão de
  `docs/reference/dignified-core.md`.

## Arquitetura (arquivos)

| Arquivo | Papel | Status |
|---|---|---|
| `editor/Z80RelFormat.pbi` | só tipos: `Enumeration Z80SegType` + `Structure Z80Addr` (valor+segmento) — nenhuma `Procedure` (ver "Módulo não enxerga Structure externa" no log técnico) | **Fase A pronto**; Fase B só reaproveita, sem mudar |
| `editor/Z80Asm.pbi` | `DeclareModule Z80Asm` — vocabulário, avaliador de expressão, parser de linha, tabela de opcodes Z80 completa, driver de 2 passes, diretivas de dados, condicionais, macros básicas | **Fase A completa** (~2300 linhas). Fase B adiciona: serialização `.REL` real quando o build for relocável |
| `editor/tools/Z80AsmTestCli.pb` | harness `/CONSOLE`, PASS/FAIL (59 testes unitários) + modo `--assemble <fonte> <saida.bin>` pra comparar contra `N80.exe` | **Fase A completo** |
| `editor/Z80Link.pbi` | `DeclareModule Z80Link` — leitor `.REL`, algoritmo de linkagem completo (segmentos, `PUBLIC`/`EXTRN`, `.REQUEST`/biblioteca, saída binária) | **Não iniciado** — ver `docs/reference/nestor80-linker.md` |
| `editor/Z80Lib.pbi` | `DeclareModule Z80Lib` — gerenciador de biblioteca `.LIB` (criar/listar/adicionar/remover módulos `.REL`), equivalente Libstor80/LB80 | **Não iniciado** |
| `editor/tools/Z80LinkTestCli.pb` | harness pro linker + biblioteca, mesmo padrão do `Z80AsmTestCli.pb` | **Não iniciado** |
| (a definir) integração com `ProjectDB.pbi` | tabela pro binário montado no `.msxproject` | **Não iniciado**, ver decisão de escopo 5 |
| (a definir) geração de listing hex / `BLOAD` | consumir o `.bin` a partir de MSX-BASIC | **Não iniciado**, ver decisão de escopo 5 |

Convenções obrigatórias (já confirmadas por exploração do código existente e, durante a
implementação, por testes empíricos de compilação — ver "Log de decisões técnicas" abaixo para o
detalhe mais importante, a visibilidade de `Structure` através de `Module`):
- `DeclareModule`/`Module` real para `Z80Asm`/`Z80Link` (mesmo padrão de `ProjectDB.pbi`), não só
  prefixo — o subsistema tem verbos genéricos demais para prefixo simples não colidir.
- Buffer de saída do assembler: array 1D fixo de 64KB, nunca `ReDim` (gotcha conhecido: `ReDim` só
  redimensiona a última dimensão de um array multi-dim — ver
  `C:\Users\wilso\.claude\projects\E--msxbasica\memory\purebasic_redim_last_dim_only.md`). Ainda não
  implementado (parte da tarefa "driver de 2 passes").
- Listas de tamanho variável (símbolos, fixups, itens REL) usam `NewList ... Structure()`.
- Símbolos são case-insensitive — normalizado para maiúsculas em todo lookup/definição de símbolo
  (`Z80Asm::DefineSymbol`/uso interno de `Symbols()`).
- `KwZ80Mnemonic`/`KwZ80Register`/`KwZ80Directive`/`KwZ80Operator` (antes em `BadigEditor.pb`) **já
  migraram** para dentro de `Z80Asm.pbi` (`Z80Asm::IsMnemonic()`/`IsRegister()`/`IsDirective()`/
  `IsOperatorWord()`) — `HighlightZ80Text()` já consome de lá, vocabulário duplicado eliminado.

## Checklist Fase A

- [x] Clonar `nestor80/` como referência (gitignored)
- [x] Confirmar `dotnet`/`N80.exe` como oráculo de teste
- [x] Plano de arquitetura aprovado pelo usuário
- [x] `docs/reference/nestor80-language.md` — extração da spec (674 linhas)
- [x] `editor/Z80RelFormat.pbi` — tipos (`Z80Addr`/`Z80SegType`, sem `Procedure`)
- [x] Migrar `KwZ80Mnemonic`/etc. + `InitZ80KeywordMaps()` para `Z80Asm.pbi`
- [x] Tokenizador de expressão (números em todas as bases, strings de 1-2 chars, `$`, símbolos)
- [x] Avaliador de expressão (RPN/shunting-yard, precedência idêntica ao Nestor80 — conferida direto
      no C# fonte, não só na doc — 20 operadores, `HIGH`/`LOW`/`NOT`/unários) — **44/44 testes
      passando, incluindo comparação byte-a-byte com `N80.exe`**
- [x] Parser de **linha completa** (`Z80Asm::ParseLine()`) — label clássico (`nome:`/`nome::`),
      forma `símbolo EQU/DEFL/ASET valor` (sem `:` — ver nota abaixo), operador, argumentos crus,
      comentário com`;` (consciente de aspas), linha em branco/só-comentário. **15/15 testes
      passando** (59/59 no total do harness até agora)
- [x] **Tabela de opcodes Z80 completa** — todo o conjunto documentado (LD/aritmética/lógica/INC-DEC/
      16-bit/PUSH-POP/EX/rotação-deslocamento CB/BIT-SET-RES/saltos-condicionais/CALL-RET/RST/IM/
      IN-OUT/blocos ED LDI-LDIR-etc/IX-IY completo incl. `(IX+d)`/`(IY+d)` e os CB indexados
      DD-CB-d-op) **+ o subconjunto indocumentado comum de IXH/IXL/IYH/IYL** (LD/INC/DEC/aritmética
      com A). `Z80Asm::ClassifyOperand()` classifica forma do operando, `Z80Asm::EncodeInstruction()`
      despacha por família de mnemônico (~20 procedures `EncodeXxx` internas)
- [x] **Driver de 2 passes** (`Z80Asm::Assemble()`) — reprocessa o texto-fonte inteiro do zero em
      cada pass (mesma estratégia do próprio Nestor80), buffer de saída fixo de 64KB (`Dim
      Mem.a(65535)`, nunca `ReDim`), sem lista de fixups (desnecessária com 2 passes completos — ver
      log). `ORG`/rótulo/`EQU`/`DEFL`/`ASET`/`END` tratados; `ASEG`/`CSEG`/`DSEG`/`COMMON`/`PUBLIC`/
      `EXTRN`/etc. reconhecidos sem efeito pleno (Fase B)
- [x] **Diretivas de dados**: `DB`/`DEFB`/`DEFM` (string de qualquer tamanho ou expressão de 1 byte,
      lista separada por vírgula), `DW`/`DEFW` (expressão de 2 bytes LE, string de 1-2 chars via o
      mesmo empacotamento do avaliador de expressão), `DS`/`DEFS` (tamanho + valor de preenchimento
      opcional — tamanho precisa resolver já no pass 1, conferido), `DC` (como `DB`, mas o último byte
      recebe bit 7 setado), `DZ`/`DEFZ` (como `DB`, mas acrescenta um `0x00` no final). Reaproveitam
      `CountOperands`/`GetOperand` (mesmos helpers de split de operando das instruções de CPU).
      **Validado contra `N80.exe`**: `sample/teste.asm` ampliado com um bloco de exemplos de cada
      diretiva → **441 bytes idênticos byte a byte** (era 394 antes do bloco de dados)
- [x] **Condicionais**: `IF`/`IFT`/`IFE`/`IFF`/`IFDEF`/`IFNDEF`/`IF1`/`IF2`/`ELSE`/`ENDIF`
      (`IFB`/`IFNB`/`IFIDN`/`IFDIF`/`IFIDNI`/`IFDIFI`/`IFABS`/`IFREL`/`IFCPU`/`IFNCPU` ficaram de fora
      — formas raras, não fazem parte de "macros básicas")
- [x] **Macros básicas**: `MACRO`/`ENDM`/`EXITM`/`LOCAL`, sintaxe `nome MACRO p1,p2` (nome em posição
      de rótulo, `:` opcional — igual a `EQU`/`DEFL`/`ASET`), parâmetros substituídos por posição,
      `LOCAL` gera um sufixo único por expansão (evita colisão de rótulo interno entre invocações da
      mesma macro). Implementado em `Z80Asm::ExpandLines()` — roda **uma vez no início de cada pass**
      (não uma vez só pro `Assemble()` inteiro inteiro), produzindo uma lista "achatada" sem
      `IF`/`MACRO`/`ENDM` nenhum, que só então passa pelo processamento normal de linha. Isso é o que
      permite `IF1`/`IF2` verem o pass certo. Fora de escopo desta fase: `REPT`/`IRP`/`IRPC`/`IRPS`,
      aninhamento de macro nomeada dentro de macro nomeada (não suportado nem no Nestor80), o
      modificador `&` de colagem de texto e os prefixos `!`/`%` de passagem de argumento (ver
      `docs/reference/nestor80-language.md`) — todos ficam pra Fase C se algum dia forem pedidos.
      **Validado contra `N80.exe`**: `sample/teste2_macros.asm` (novo arquivo, cobre os 6 tipos de
      condicional + uma macro chamada 2x testando `LOCAL`) → **21 bytes idênticos byte a byte**
- [x] `editor/tools/Z80AsmTestCli.pb` — suíte unitária (59 casos: vocabulário/expressão/ParseLine) +
      **modo `--assemble <entrada.asm> <saida.bin>`** pra comparação binária direta contra `N80.exe`
- [x] **`sample/teste.asm`** (206 linhas, ~190 formas de instrução distintas — ORG/EQU/rótulos/toda a
      família de mnemônicos incl. IX/IY/indexado/indocumentado) — **suíte de regressão oficial deste
      módulo, mesmo papel de `sample/teste.dmx` pro pré-processador Dignified**. Rodar depois de
      qualquer mudança em `Z80Asm.pbi`:
      ```
      editor\tools\Z80AsmTestCli.exe --assemble sample\teste.asm saida_minha.bin
      nestor80\N80\bin\Release\net6.0\N80.exe sample\teste.asm saida_oracle.bin
      fc /b saida_minha.bin saida_oracle.bin
      ```
- [x] **Validação byte-a-byte contra `N80.exe`**: `sample/teste.asm` produz **394 bytes idênticos**
      byte a byte ao `N80.exe` real (confirmado 2026-07-24). Suíte unitária: 59/59 também passando.
- [x] **Menu "Montar" no editor** — `Executar → Montar Assembly (.bin)...` (`Ctrl+F5`),
      `AssembleZ80FromActiveTab()` em `BadigEditor.pb`, habilitado quando `Docs()\Mode = "ASM"`,
      salva via `SaveFileRequester`, erro mostra linha + mensagem
- [x] Atualizar `docs/SPEC.md` módulo 2 (+ módulo 2b/2c), `README.md` (bullet + changelog + créditos
      ao Nestor Soriano/Konamiman) e `docs/MANUAL.md` (nova seção "Assembler Z80") — **Fase A 100%
      completa e documentada em todos os `*.md` do projeto**, versão embutida `7.3.1`

## Checklist Fase B (em andamento a partir de 2026-07-24)

- [x] `docs/reference/nestor80-rel-format.md` + `nestor80-linker.md` — extraídos de
      `RelocatableFileFormat.md`/`WritingRelocatableCode.md` + leitura direta do C# do linker
      (`Linker/RelocatableFilesProcessor.cs`)
- [x] **`LK80.exe`/`LB80.exe` compilados localmente** (mesma receita do `N80.exe`) — oráculo de teste
      também pro linker e pro gerenciador de biblioteca, não só pro assembler
- [ ] Serialização `.REL` real (detecção de build type absoluto vs. relocável)
- [ ] `editor/Z80Link.pbi` (`DeclareModule Z80Link`) — algoritmo de linkagem completo: concatenação
      de segmentos (`ASEG`/`CSEG`/`DSEG`/`COMMON`), resolução `PUBLIC`/`EXTRN`, geração do binário
      final
- [ ] **`.REQUEST`/pesquisa de biblioteca no linker** — resolver externos pendentes procurando em
      arquivo(s) de biblioteca informados, puxando só o(s) "programa" `.REL` que resolve cada
      símbolo (sem dead-stripping dentro de um programa, mas também sem puxar programas não
      referenciados — mesmo comportamento do LINK-80/Linkstor80 real, ver
      `nestor80-linker.md` quando escrito)
- [ ] **`editor/Z80Lib.pbi`** (`DeclareModule Z80Lib`, equivalente Libstor80/LB80) — criar/listar/
      adicionar/remover módulos `.REL` de um arquivo `.LIB`, reaproveitando o parser/escritor `.REL`
      de `Z80Link.pbi` (pedido explícito do usuário, 2026-07-24 — ver "Decisões de escopo" item 4)
- [ ] `editor/tools/Z80LinkTestCli.pb` (cobre linker + biblioteca)
- [ ] Segunda opção de menu / fluxo multi-arquivo (Montar → gerar `.REL`; Linkar/Montar biblioteca →
      UI própria ou reaproveitando o padrão de diálogo do gerenciador de disco)

## Integrações planejadas (não fazem parte da Fase B em si, mas foram confirmadas como objetivo do
## módulo em 2026-07-24 — ver decisão de escopo 5 acima)

- [ ] **Sistema de projeto**: tabela dedicada no `.msxproject` pro binário montado (número/tag/
      navegação/Registrar, mesmo padrão de sprites/alfabetos/sons/músicas/telas em `ProjectDB.pbi`)
- [ ] **`BLOAD`**: colocar o `.bin` montado num `.dsk`, reaproveitando `MSXDisk.pbi`/mesma mecânica de
      `RunOnOpenMSX()`
- [ ] **Listing hexadecimal**: gerar um bloco `DATA`/`POKE` a partir do binário montado, pro código Z80
      poder ser colado direto num programa BASIC (mesmo espírito de `PsgGen_RawBytes()` no editor de
      som PSG, `editor/PsgSynth.pbi`)

## Fora de escopo (Fase C, backlog distante)

`REPT`/`IRP`/`IRPC`/`IRPS`, `MODULE`/`ENDMOD` e labels locais/relativos, saída Intel HEX, arquivo de
listagem `.LST`, R800/Z280. (Biblioteca/`.REQUEST` **saiu daqui e entrou na Fase B**, ver acima —
pedido explícito do usuário 2026-07-24.)

## Log de decisões técnicas durante a implementação

_(preenchido conforme a implementação avança — bugs encontrados, ajustes de design em relação ao
plano original, etc., mesmo espírito do "Próximos passos em aberto" do `docs/SPEC.md`)_

- **2026-07-24 — gotcha real de PureBasic descoberto e confirmado empiricamente: um `Module` não
  enxerga NENHUMA `Structure`/`Enumeration` definida fora dele**, nem para uso como campo aninhado
  (`Field.OutraStructure`) nem como tipo de parâmetro de ponteiro (`*P.OutraStructure`) — mesmo que a
  `Structure` externa esteja definida bem antes, textualmente, do `Module`. Confirmado com um
  repro mínimo isolado (`Structure Outer` global + `Module Foo` tentando usar `Outer` → erro
  "Structure not found: Outer", tanto pra campo aninhado quanto pra parâmetro `*P.Outer`).
  **Correção**: a `Structure`/`Enumeration` precisa ser declarada **dentro do próprio
  `DeclareModule ... EndDeclareModule`** (não só dentro do `Module ... EndModule` — `DeclareModule`
  só aceita declarações, não corpo de `Procedure`, então isso força uma separação: tipos entram via
  `XIncludeFile` dentro do bloco `DeclareModule`, e `Procedure`s que os usam entram separadamente
  dentro do `Module`). Confirmado funcionando com um segundo repro (`Structure Outer` dentro de
  `DeclareModule Foo`, usada sem qualificar dentro do próprio módulo, e como `Foo::Outer` de fora).
  **Mesma causa raiz do comentário já existente em `ProjectDB.pbi` sobre `DefaultCharsetMsx.pbi`**
  ("um Module nao enxerga procedures/DataSection definidas fora dele") — só que aqui o problema pega
  `Structure`/`Enumeration` também, não só `Procedure`/`DataSection`.
  **Efeito na arquitetura**: `editor/Z80RelFormat.pbi` (destinado a ser compartilhado entre
  `Z80Asm.pbi` e o futuro `Z80Link.pbi`, Fase B) só pode conter `Structure`/`Enumeration` — nenhuma
  `Procedure` — e é incluído via `XIncludeFile "Z80RelFormat.pbi"` **de dentro do
  `DeclareModule Z80Asm`** (não mais no topo de `BadigEditor.pb` junto com os outros
  `XIncludeFile`). Os 3 helpers pequenos que antes estavam nesse arquivo (`Z80Addr_Make`/
  `Z80Addr_IsAbsolute`/`Z80Addr_SameSegment`) moraram para dentro do `Module Z80Asm` — quando o
  `Z80Link.pbi` da Fase B existir, ele terá sua própria cópia trivial desses 3 helpers (mesmo
  espírito de não compartilhar `Structure`/lógica pequena entre módulos já visto em
  `ProjectDB.pbi`/`psg_sounds`/`screens`, ver comentários lá). Código do `Module` que usa um tipo de
  outro módulo por fora precisa qualificar (`Z80Asm::Z80Addr`), inclusive em código-cliente como
  `editor/tools/Z80AsmTestCli.pb`.
- **2026-07-24 — bug real (não gotcha de linguagem, erro meu) encontrado via o debugger do
  PureBasic** (`pbcompiler.exe ... /DEBUGGER /LINENUMBERING`, dá crash com linha exata em vez de só
  "exit code X"): `EvalPostfixExpr()` fazia `CopyStructure(@Stack(), Out, Z80Addr)` em vez de
  `CopyStructure(@Stack(), *Out, Z80Addr)` — usar o nome do parâmetro sem o `*` em vez do ponteiro de
  verdade. **Notável**: `EnableExplicit` **não pegou isso em tempo de compilação** (seria de se
  esperar um erro "variável não declarada" para `Out`) — compilou limpo e só quebrou em runtime
  ("Invalid memory access, read error at address 3"). Lição: quando uma `Procedure` recebe
  `*Nome.Tipo`, sempre usar `*Nome` (nunca `Nome` sozinho) ao repassar como argumento de ponteiro pra
  outra função — `EnableExplicit` não é uma rede de segurança confiável pra esse erro específico.
  **Como foi encontrado**: compilar com `/DEBUGGER /LINENUMBERING` deu a linha exata do crash
  (diferente do build normal, que só dá "exit code 5" sem contexto) — vale a pena usar essas duas
  flags sempre que um `.exe`/harness crashar sem explicação durante o desenvolvimento deste módulo.
- **2026-07-24 — confirmado por leitura direta do C#** (não só da doc): a tabela de precedência de
  operadores do Nestor80 (`ArithmeticOperator.Precedence` em cada classe de
  `Assembler/Expressions/ExpressionParts/ArithmeticOperators/*.cs`) tem `TYPE`=0, `HIGH`/`LOW`=1,
  `* / MOD SHL SHR`=2, unário `+`/`-`=3, `+`/`-` binário=4, relacionais (`EQ NE LT LE GT GE`)=5,
  `NOT`=6, `AND`=7, `OR`/`XOR`=8 (menor número liga mais forte) — ordem não-óbvia (o `+`/`-` unário
  liga **mais fraco** que `*`/`/`, e `NOT` liga mais fraco que os relacionais) que bateu exatamente
  com o algoritmo de shunting-yard implementado (`Postfixize()` em `Expression.Evaluation.cs`,
  operadores unários sempre empilhados sem checar precedência, só resolvidos no próximo operador
  binário ou `)`). Replicado fielmente em `Z80Asm::OpPrecedence()`/`OpIsUnary()`/`ToPostfixExpr()`.
  Convenção verdadeiro/falso dos operadores relacionais (`FFFFh`/`0000h`) confirmada tanto pelo C#
  quanto por teste real no `N80.exe` (`db 3 eq 3` → byte `255`, ou seja `FFFFh` truncado pro `DB`).
- **2026-07-24 — regra de rótulo que quebraria `EQU`/`DEFL`/`ASET` se implementada ingenuamente**: a
  primeira suposição (rótulo = "primeira palavra da linha, se não bater com nenhuma keyword" — regra
  usada só cosmeticamente pelo highlighter, `HighlightZ80Text()`) está **errada** pro parser de
  verdade. A doc (LR:161) é explícita: rótulo **sempre** precisa terminar em `:`/`::` — não existe
  rótulo implícito por coluna/posição. Só que isso sozinho quebraria a forma clássica e onipresente
  `SIMBOLO EQU valor` (sem `:`) — resolvido porque `EQU`/`DEFL`/`ASET` são os
  "constantDefinitionOpcodes" do Nestor80 (achado já registrado na pesquisa original): quando a
  **segunda** palavra da linha é uma dessas três, a primeira palavra é o símbolo sendo definido,
  mesmo sem `:`. `Z80Asm::ParseLine()` implementa isso com um lookahead de 1 palavra (só quando a
  primeira palavra não tem `:` na sequência) — ver `Structure Z80ParsedLine\LabelHasColon` (distingue
  as duas formas, caso algum consumidor futuro precise saber qual delas foi usada).
- **2026-07-24 — dois bugs pequenos pegos pelos testes (harness compensou bem)**:
  (1) variável local chamada `WEnd` colidiu com a palavra-chave `Wend` do PureBasic
  (`While...Wend`) — erro de compilação claro ("A variable can't be named the same as a keyword"),
  renomeada pra `WStop`. Lição: evitar nomes de variável que sejam também palavra-chave de controle
  de fluxo, mesmo com capitalização diferente (PureBasic é case-insensitive pra palavras-chave).
  (2) `ParseLine()` não tirava o espaço **à esquerda** do texto do comentário (só `RTrimWs`, nunca um
  "skip whitespace" depois do `;`) — `"; foo"` virava `Comment = " foo"` em vez de `"foo"`. Pego por
  4 dos 15 testes novos de `ParseLine` falharem de forma idêntica (mesmo padrão "sobrou um espaço no
  início"), o que tornou o diagnóstico rápido. Corrigido com `SkipWs()` antes do `RTrimWs()`.
- **2026-07-24 — segundo gotcha real de PureBasic (grande): não dá pra passar uma `Structure` POR
  VALOR como parâmetro de `Procedure`** (`Procedure X(Campo.MinhaStructure)`) — só por ponteiro
  (`Procedure X(*Campo.MinhaStructure)`). Confirmado com repro mínimo (`Procedure.i Test(F.Foo, N.l)`
  → "Syntax error" na própria linha da assinatura). Isso derrubou a primeira versão inteira do
  codificador de instruções (~20 procedures `EncodeXxx` recebendo `Z80Operand` por valor). Corrigido
  em massa com um script Perl (`perl -i -pe` com regex de word-boundary + lookbehind negativo pra não
  mexer em usos já corretos como `@Op1`) que converteu assinatura (`Op1.Z80Operand` →
  `*Op1.Z80Operand`), acesso a campo (`Op1\X` → `*Op1\X`) e passagem por valor como argumento (`Op1`
  cru → `*Op1`) em massa, deixando de fora deliberadamente o dispatcher `EncodeInstruction()` (onde
  `Op1`/`Op2` são de fato variáveis locais por valor, preenchidas por `ClassifyOperand(..., @Op1)`) —
  esse precisou de um ajuste manual separado (trocar as chamadas `EncodeXxx(Op1, ...)` por
  `EncodeXxx(@Op1, ...)`). **Lição prática**: ao escrever uma nova `Procedure` que recebe uma
  `Structure` "de leitura" (não é lista/array), já nascer com `*Nome.Tipo` — nunca `Nome.Tipo` puro.
- **2026-07-24 — terceiro gotcha: `Protected NomeArray.tipo(N)` não declara array — precisa de
  `Protected Dim NomeArray.tipo(N)`** (confirmado com repro mínimo). Sem o `Dim`, erro de sintaxe na
  própria linha. Achado ao declarar o buffer temporário de 4 bytes (`Bytes`) dentro do driver de
  passes e o buffer fixo de 64KB (`Mem`) dentro de `Assemble()`.
- **2026-07-24 — quarto gotcha, o mais sutil: `Variavel = Not OutraVariavel` (atribuição direta) é
  erro de sintaxe** ("A variável não pode ter o mesmo nome de uma palavra reservada: Not"), mas
  `If Not OutraVariavel ... EndIf` (contexto condicional) funciona normalmente — confirmado com repro
  isolado. `Not` como operador prefixo só parece ser aceito pelo parser em posição de condição
  booleana, não numa atribuição de valor solta. **Correção**: envolver em `Bool(...)` quando precisar
  do resultado de `Not` como valor atribuível (`X = Bool(Not Y)`), nunca `X = Not Y` cru.
- **2026-07-24 — bug real de lógica (não de sintaxe): ambiguidade "C" registrador vs. "C" condição**.
  `ClassifyOperand()` classifica um `"C"` isolado como `#Z80Opnd_Reg8` (RegCode=1, o mais comum),
  nunca como `#Z80Opnd_Cond` — mas `JP C,nn`/`JR C,e`/`CALL C,nn`/`RET C` também usam exatamente esse
  texto, só que como condição (RegCode de condição = 3, valor diferente!). Pego pelo teste de
  regressão contra `N80.exe` (`sample/teste.asm` tem `jp c,start`) — sem o oráculo, um teste unitário
  ingênuo que não cobrisse justo essa combinação passaria batido. Corrigido com um helper dedicado,
  `Z80Asm::CondCodeOf()`, chamado nos 4 pontos que aceitam condição na posição 1 (`JP cc,nn`/
  `JR cc,e`/`CALL cc,nn`/`RET cc`) — trata tanto `#Z80Opnd_Cond` quanto o caso especial "Reg8 com
  RegCode=1" (ou seja, literalmente `C`), devolvendo o código de condição certo (3) nos dois casos.
- **2026-07-24 — bug real de arquitetura do driver de 2 passes: `EQU` "já definido" disparando no
  PASS 2 pra toda constante**. Como `Assemble()` roda os 2 passes sobre a MESMA tabela de símbolos
  (só um `ResetState()` no início, nunca entre os passes — de propósito, pra rótulos definidos no
  pass 1 continuarem visíveis no pass 2), toda linha `EQU` processada no pass 1 batia de novo no pass
  2 contra o próprio guard "EQU não pode ser redefinido" — `sample/teste.asm` já tinha um `CONST equ
  42` que disparava isso na primeira tentativa. **Correção**: `DefineSymbol()` só rejeita quando o
  NOVO valor difere do já existente — redefinir um `EQU` com o mesmo valor (exatamente o que
  acontece relendo a mesma linha no pass 2) agora é um no-op silencioso; só um `EQU` genuinamente
  conflitante (duas definições DIFERENTES pro mesmo nome) ainda erra.
- **2026-07-24 — validação por oráculo, resultado**: `sample/teste.asm` (206 linhas, ~190 formas de
  instrução distintas cobrindo praticamente toda a tabela — 8 condições de desvio, indexado IX/IY com
  deslocamento positivo/negativo, CB indexado, blocos ED, halves indocumentados IXH/IXL/IYH/IYL)
  monta pra um binário de **394 bytes idêntico byte a byte ao `N80.exe` real**. Esse nível de
  cobertura + comparação binária direta (não só alguns `CheckEval` manuais) dá confiança alta na
  tabela de opcodes inteira, não só nos casos individualmente testados.
- **2026-07-24 — erro de arquitetura pego pelo oráculo, não pelo raciocínio**: a primeira versão de
  `ExpandLines()` (condicionais/macros) rodava como um **pré-processamento totalmente separado**,
  antes de qualquer EQU/rótulo ser resolvido pelo loop principal de `RunOnePass()` — parecia razoável
  ("achatar tudo primeiro, montar depois"), mas quebra o caso mais comum de todos:
  `FLAG equ 1` seguido de `if FLAG` no mesmo arquivo. `sample/teste2_macros.asm` (que tem exatamente
  esse padrão, `DEBUG equ 0` / `if DEBUG`) falhou na primeira tentativa com "símbolo desconhecido:
  DEBUG" — o `EQU` simplesmente ainda não tinha rodado quando o `IF` tentava ler o valor, porque os
  dois vivem em estágios diferentes (macro/condicional resolvido num sub-passo antes de tudo; EQU só
  no loop principal, depois). **Correção**: `ExpandLines()` ganhou uma cópia enxuta da lógica de
  `EQU`/`DEFL`/`ASET` (chamando `DefineSymbol()` na hora, igual o loop principal já faz) — assim
  o walk de cima a baixo do próprio `ExpandLines()` mantém a tabela de símbolos atualizada o
  suficiente pra um `IF` mais adiante NA MESMA passada já enxergar qualquer `EQU` anterior. Rótulo
  (valor = contador de localização) ficou de fora de propósito — `ExpandLines()` não rastreia
  tamanho de instrução/endereço (só `RunOnePass()` faz isso), então um `IF` que dependa do *valor* de
  um rótulo (não de uma `EQU`) é uma lacuna conhecida e aceita nesta fase (padrão raro). Rodar
  `DefineSymbol()` de novo mais tarde no loop principal pro mesmo `EQU` é seguro (mesmo mecanismo de
  "redefinição idêntica é no-op" já implementado pro problema do EQU-duplicado-entre-pass-1-e-pass-2).
  **Lição mais ampla**: mesmo com plano/arquitetura bem pensados de antemão, o oráculo (`N80.exe`)
  continua sendo o jeito mais rápido de achar esse tipo de erro de sequenciamento — o raciocínio
  isolado ("isso devia funcionar") não pegou, o teste ponta a ponta pegou na primeira tentativa.
- **2026-07-24 — groundwork da Fase B**: `LK80.exe` (linker) e `LB80.exe` (gerenciador de biblioteca)
  compilam limpo a partir do mesmo clone `nestor80/` (`dotnet build LK80/LK80.csproj -c Release` /
  `LB80/LB80.csproj` — mesma receita do `N80.exe`), confirmando que os **três** oráculos (assembler +
  linker + biblioteca) estão disponíveis pra validar o port nativo byte a byte, não só o assembler.
  `docs/reference/nestor80-rel-format.md` (formato `.REL` bit-a-bit — não byte-alinhado, precisa de
  um leitor/escritor de bit-stream próprio) e `docs/reference/nestor80-linker.md` (algoritmo completo
  do linker, lido direto do C# já que a doc oficial não descreve o algoritmo em si) escritos. Ainda
  **não iniciada** a implementação de verdade (bit-stream writer/reader, `Z80Link.pbi`, `Z80Lib.pbi`) —
  ver checklist Fase B acima pra retomar.
- **2026-07-24 — fechamento da sessão (Fase A entregue, Fase B pausada por escolha, não por
  bloqueio)**: usuário pediu uma pausa antes de começar a implementação de verdade da Fase B (bit-stream
  writer/reader/linker/biblioteca — trabalho do mesmo porte da Fase A inteira, decisão deliberada de
  não escrever isso às cegas sem espaço pra validar com o mesmo rigor). Documentação atualizada em
  todos os `*.md` do projeto nesta sessão de fechamento: `README.md` (novo bullet dedicado ao
  assembler em "O que já temos", changelog, crédito ao **Nestor Soriano (Konamiman)** — autor do
  Nestor80 — na seção "Agradecimentos"), `docs/SPEC.md` (módulo 2 reescrito com status real + novo
  módulo 2c documentando as integrações planejadas de projeto/BASIC), `docs/MANUAL.md` (nova seção
  "Assembler Z80" — uso prático: aba `.asm`, `Ctrl+F5`, o que é/não é suportado ainda). Versão do
  executável corrigida de `7.2.0` pra **`7.3.1`** — convenção do projeto (registrada em memória
  também, `version_numbering_convention.md`): **minor ímpar = build interno/dev, minor par = release
  de verdade**; como ainda não houve nenhum release, nunca pular pra minor par. **Para retomar a Fase
  B (nesta máquina ou em outra)**: este arquivo já tem tudo — clonar/compilar `nestor80/` (seção
  "Material de referência" acima, agora com N80+LK80+LB80), ler `docs/reference/nestor80-rel-format.md`
  e `nestor80-linker.md` (já escritos), e seguir o checklist "Fase B" + "Integrações planejadas" acima,
  primeiro item pendente é o escritor de bit-stream dentro de `Z80Asm.pbi`.
- 2026-07-24: início da Fase A.
