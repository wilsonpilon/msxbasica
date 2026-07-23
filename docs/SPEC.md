# Especificação — IDE MSX BASIC + Z80 (PureBasic)

> Documento vivo de especificação. Reorganizado a partir de `transcricao.md` (chat de planejamento
> exportado do claude.ai). Atualizar esta página conforme a especificação evoluir; usar `transcricao.md`
> só como material bruto de referência histórica.

## Visão geral

IDE completa em **PureBasic** (licença vitalícia já disponível), construída a partir do editor MSX
BASIC já existente (`editor/BadigEditor.pb`). Escopo final: editor de texto com highlighting via
Scintilla/`EditorGadget` + assembler Z80 embutido + pré-processador Basic Dignified reescrito nativo +
conjunto de editores visuais + múltiplos back-ends de saída + controle do openMSX para rodar/depurar
direto da IDE.

Decisão de arquitetura (fechada): **tudo nativo em PureBasic**, sem subprocess/dependência externa
embutida — exceção único caso onde subprocess faz sentido: `msxbas2rom` (compilador C++ separado,
opcional, ver módulo 8).

## Referências técnicas (leitura do código-fonte original em `badig/`)

Documentação extraída lendo o código Python de `badig/` diretamente (não só a doc humana), para
servir de especificação byte-a-byte ao port nativo:

- **`docs/reference/dignified-core.md`** — arquitetura do motor genérico (`badig.py`): Lexer,
  Parser em 5 passes + geração, sistema de configuração (código/`.ini`/cmdl/remtags), vocabulário
  Dignified puro (`badig_dignified.py`).
- **`docs/reference/badig-msx-module.md`** — parte específica do dialeto MSX clássico
  (`badig_msx.py`): vocabulário reservado, algoritmo de nomes curtos de variável (`ZZ`→`AA`),
  define embutido `[?](x,y)`, tabela de tradução Unicode→ASCII MSX, ordem tokenizer→emulador.
- **`docs/reference/badig-dignifier.md`** — conversor clássico→Dignified (`msxbader.py`).
- **`docs/reference/badig-emulator-tokenizer-interfaces.md`** — protocolo **real** de controle do
  openMSX (sequência de comandos XML efetivamente usada) e como o tokenizer é invocado
  internamente. **Importante**: revela que o mecanismo de detecção de erro em runtime já
  implementado no projeto original é mais simples do que o plano especulado em `transcricao.md`
  (convenção `CHR$(7)`+linha lida do stdout via script Tcl, não hook de memória/breakpoint) — ver
  módulo 12 abaixo, atualizado com essa informação.

## Módulos

| # | Módulo | Esforço relativo | Status da spec |
|---|--------|-------------------|-----------------|
| 1 | Editor MSX BASIC (base) | — | **Em código** (`editor/BadigEditor.pb`) |
| 2 | Assembler Z80 (2 passes, nativo) | médio-alto | Lado editor pronto (arquivo `.asm` + syntax highlight, 2026-07-16) — motor do assembler em si ainda não iniciado |
| 3 | Basic Dignified reescrito nativo | depende do escopo do original | **Completo (2026-07-15)** — `editor/DignifiedPreprocessor.pbi`, incluindo `INCLUDE` e remtags, ver módulo 3g |
| 4 | Editor sprite/char | baixo | **Sprite e alfabeto implementados (2026-07-19)** — `editor/SpriteEditorGui.pbi`/`editor/CharsetEditorGui.pbi`, ambos integrados ao sistema de projeto (módulo 13), ver seção 4. **Editor de alfabetos Aquarela (.FNT) implementado (2026-07-23)** — `editor/AquarelaCharsetEditorGui.pbi`, ferramenta autocontida baseada em arquivo, sem integração com o sistema de projeto, ver seção 4b. **Editor de alfabetos Graphos III ganhou 13 efeitos de edição em lote (2026-07-23)** — desfazer/refazer, marcar tudo, espelhar/girar/apagar/estreitar/itálico/negrito/largo (+ variantes bold e largo-bold), ver seção 4c. Tile (além do charset/fonte 8×8) ainda não iniciado |
| 5 | Editor gráfico LINE/CIRCLE/PSET/DRAW | baixo-médio | Definido (seção 5) |
| 6 | Editor de som SOUND (PSG) | baixo | **Implementado (2026-07-21)** — `editor/PsgSynth.pbi` (motor)/`editor/PsgEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 6 |
| 7 | Tracker | alto | Só escopo geral, sem detalhe de UI/formato |
| 8 | Editor MML (comando `PLAY`) | médio | **Implementado (2026-07-21)** — `editor/MmlSynth.pbi` (motor)/`editor/MmlEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 8 |
| 9 | Extensão NestorBASIC (nbasic) | médio | Definido, com exemplo de sintaxe (seção 7) |
| 10 | Dialeto msxbas2rom / geração de ROM | médio | Definido como back-end opcional (seção 8) — **usuário disse "só se valer a pena"** |
| 11 | Saída tokenizada (.bas tokenizado) | baixo (bem documentado) | **Implementado e verificado** — `editor/MsxTokenizer.pbi`, ver detalhe abaixo |
| 12 | Controle do openMSX via socket | médio (alto no item de detecção de erro) | **Parcial (2026-07-16)**: gerar disco + abrir o openMSX já rodando o programa está implementado, mais uma CLI `--diskmanipulator` standalone embutida no `.exe`; controle via socket/XML, input simulado e detecção de erro em runtime ainda não |
| 13 | Sistema de projeto (arquivo `.msxproject`, SQLite) | baixo-médio | **Implementado (2026-07-18), estendido (2026-07-19)** — `editor/ProjectDB.pbi`, ver seção 13. Sprites, alfabetos, cópia das abas de texto e diretório de trabalho já ligados; **Salvar projeto/Salvar projeto como...**; "projeto 0" de defaults sempre em memória. Demais tipos de conteúdo entram quando tiverem editor próprio |

## Decisões fechadas

- Linguagem: PureBasic, sem trocar para Go/Fyne/Wails (avaliado e descartado).
- Editor: `EditorGadget`/Scintilla, lexer customizado escrito à mão (mesma abordagem já usada no
  editor MSX BASIC atual).
- Sem subprocess para o pipeline principal; `msxbas2rom` é a única exceção aceita.
- **`badig/` é referência de leitura, não dependência de runtime** (confirmado 2026-07-13). O objetivo
  final é um `.exe` PureBasic autocontido, distribuível para outras máquinas, sem exigir Python
  instalado nem chamar `badig.py` via subprocess. Todo o pré-processador Dignified e o tokenizador
  precisam ser **portados/reescritos nativamente em PureBasic**, usando o código Python de `badig/`
  como especificação de comportamento a replicar (tabelas de dados e algoritmo), não como biblioteca a
  chamar.
  - **Débito técnico resolvido (2026-07-15)**: o menu "Gerar tokenizado MSX via Python (.bmx)..." e a
    procedure `SaveTokenized()` (que chamava `python badig.py ... --tk_tokenize` via `RunProgram`) foram
    removidos de `editor/BadigEditor.pb`, junto com `BadigCfg_BuildCliArgs()`/`BadigCfg_QuoteArg()` em
    `editor/BadigSettings.pbi` (ficaram sem nenhum chamador). O caminho nativo (`Dignified -> ASCII/
    tokenizado nativo`) já cobre 100% do escopo do original, incluindo `INCLUDE` e remtags (módulo 3g) -
    o `.exe` do editor não chama mais Python em nenhum menu. ~~Ficou como leftover conhecido, de baixo
    risco: os campos `BadigCfg\EmRun`/`EmSetting`/`EmMachine`/etc. e a aba "Emulador" da tela de
    configurações continuam existindo (JSON + UI), mas hoje não têm nenhum efeito prático~~ —
    **atualizado 2026-07-16**: `EmRun`/`EmMachine`/`EmExtension`/`EmulatorPath` passaram a ter efeito
    real de novo, agora ligados ao fluxo nativo `RunOnOpenMSX()` (ver módulo 12) em vez do `python
    badig.py` removido. Só `EmSetting`/`EmMonitor`/`EmNoThrottle`/`EmVerbose` continuam sem
    consumidor.
- Duas (potencialmente três) saídas do pré-processador: ASCII clássico, tokenizado, e opcionalmente
  dialeto msxbas2rom para gerar ROM.
- Editores visuais (sprite, som, tracker, MML, draw) todos alimentam o mesmo pipeline de saída
  (blocos BASIC/DATA/POKE ou bytes hexa para bloco `#asm`), não são apêndices isolados.
- NestorBASIC: tabela de aliases (função → número `USR`, parâmetro → posição em array `P`/`F$`),
  gerada como extensão do sistema de símbolos do Basic Dignified.

## Detalhe por módulo

### 2. Assembler Z80
- Dois passes: (1) tokeniza + resolve labels/símbolos + calcula endereços; (2) gera código de máquina.
- Referência de arquitetura/opcodes: sjasmplus e z88dk (estudar só a arquitetura/tabela, não reaproveitar
  código — evita problema de licença).
- Integração com editor: bloco de assembly dentro do mesmo arquivo `.dmx`/`.bas` (marcador tipo
  `' ASM` ... `' ENDASM`) com highlighting dinâmico, ou abas separadas `.BAS`/`.ASM` referenciadas.
- Saída: `.bin`/listagem hexa para uso com `BLOAD` ou rotina clássica de carga hexa em runtime.

**Status (2026-07-16): lado editor implementado** (a decisão de arquitetura acima escolheu "abas
separadas", não o marcador `' ASM`/`' ENDASM` embutido no mesmo arquivo). Menu **Arquivo → Novo
Assembly** (`Ctrl+Shift+N`, ao lado de "Novo") cria uma aba `.asm` em vez de `.dmx`; o tipo de cada
aba é rastreado em `Document\Mode` (`"DMX"` ou `"ASM"`, `editor/BadigEditor.pb`), detectado
automaticamente pela extensão ao abrir um arquivo existente (`.asm`/`.z80`/`.mac` → `ASM`). Diálogos
de Abrir/Salvar já filtram e sugerem a extensão certa por modo (`#File_Pattern_ASM`/
`#File_Pattern_Open`).

Realce de sintaxe do modo `.asm` (`HighlightZ80Text()`) segue estritamente o vocabulário do
**N80/Nestor80** (Konamiman, github.com/Konamiman/Nestor80 — assembler Z80/R800/Z280 compatível com
MACRO-80, referência de sintaxe lida diretamente do `docs/LanguageReference.md` do projeto): mnemônicos
documentados + indocumentados comuns (`SLL` etc.), registradores e códigos de condição (`NZ Z NC C PO
PE P M`, mesmo estilo visual para os dois), diretivas (`EQU DEFL ORG DEFB/DB DEFW/DW MACRO IF/ENDIF
MODULE` e as com ponto do dialeto N80 como `.RADIX`/`.PHASE`), literais numéricos em qualquer radix
(sufixos `B/O/Q/H/D`, prefixos `0x`/`0b`/`#`, forma `X'..'`), strings `"..."`/`'...'` com escapes,
comentário `;`. Reaproveita a mesma paleta de estilos do modo Dignified (`#Style_Comment/String/
Statement/Function/Number/Label`, mais `#Style_DignifiedStmt` reutilizado genericamente como "estilo de
diretiva") — nenhuma cor/estilo novo precisou ser adicionado.

**Regra de rótulo vs. mnemônico/diretiva** (mesma convenção clássica MACRO-80/Z80): a primeira palavra
de uma linha vira rótulo (com ou sem `:`/`::`) somente quando **não** bate com nenhuma tabela de
palavra-chave — cobre tanto `LABEL: LD A,1` quanto `CONST EQU 5` quanto `ORG 100H` (que começa a linha
mas é diretiva conhecida, não rótulo). Testado ao vivo (screenshot com pixel-sampling de cor
confirmando os estilos certos) com rótulos, mnemônicos, registradores, condição de desvio, diretiva
`EQU`/`ORG`/`DEFB`, string e número — todos corretos.

**Limitações conhecidas aceitas**: bloco `.COMMENT <delim>...<delim>` com delimitador arbitrário não é
reconhecido (só o comentário de linha `;`); a fronteira exata "dígitos" vs. "sufixo de radix" dentro de
um literal numérico pode variar internamente sem afetar o destaque visual (o token inteiro sempre fica
colorido como número, ver comentário em `HighlightZ80Text()`).

### 3. Basic Dignified reescrito nativo

**Status (2026-07-13): v1 implementada.** `editor/DignifiedPreprocessor.pbi` — pipeline nativo que
converte código Dignified (`.dmx`) para MSX-BASIC ASCII clássico com numeração de linha, sem Python.
Integrado ao editor via dois novos itens de menu: **"Gerar ASCII nativo a partir do Dignified
(.amx)..."** e **"Gerar tokenizado nativo a partir do Dignified (.bmx)..."** (este último encadeia o
pré-processador com `MsxTokenizer.pbi`, produzindo o `.bmx` final num só passo, 100% nativo).

**Implementado e verificado nesta v1** (testado byte-a-byte contra os exemplos de entrada/saída já
documentados em `badig/documentation/BASIC_DIGNIFIED.md`, que servem de suíte de testes pronta):
- Comentários: `##` (linha, removido), `###...###` (bloco, removido), `''...''` (bloco, mantido como
  REM/`'`).
- Toggle rems `#nome` (forma de linha e de bloco), `keep #a #b`, `#all`/`#none` com precedência.
- Junção de linhas: `_` no fim de linha (removido, insere espaço no join) e `:` no início/fim
  (mantido, join direto sem espaço extra).
- `DEFINE` com variável posicional `[nome](arg)` e valor default, expansão **recursiva** (define
  usado como argumento de outro define), e o `[?](x,y)` embutido do módulo MSX.
- `DECLARE` (atribuição explícita long:short e reserva de nomes) + redução automática de nomes
  longos para curtos (algoritmo `ZZ→AA` decrescente, idêntico ao original) + `~nome` para manter
  nome longo.
- Labels de linha `{nome}`, labels de salto `{nome}` (incluindo `{@}` auto-referência), loop labels
  `nome{ ... }` com `GOTO` de volta automático, `EXIT` (resolve para a linha **depois** do
  fechamento do loop, não para o início — bug corrigido durante os testes).
- `TRUE`/`FALSE` → `-1`/`0`, operadores compostos `++ -- += -= *= /= ^=`.
- `ENDIF` descartado (é puramente cosmético).
- Numeração de linha com resolução de referências para frente (2 passes: numera tudo, depois
  substitui os placeholders de label/loop pelos números reais).
- Cabeçalho `rem_header` opcional (default ligado).

**Bugs encontrados e corrigidos durante os testes desta sessão** (documentados para não reintroduzir):
palavras-chave com `$` (ex. `INKEY$`) não batiam na checagem de "é reservada" (a tabela guardava
`INKEY$` mas a busca comparava `INKEY` sem o sufixo); cabeçalho REM colidia com o número da primeira
linha de conteúdo; o estágio de redução de variáveis não sabia que existiam marcadores internos
(`Chr(2)`) representando referências de label ainda não resolvidas, e corrompia esses marcadores
tratando seu conteúdo como identificador a renomear; `EXIT` resolvia para o início do loop em vez do
fim; `+=`/`-=`/etc. quebravam quando havia espaço entre a variável e o operador (`var3 += 20`).

**Bugs adicionais encontrados (2026-07-13) testando contra um arquivo real** (`teste.dmx`, "Change
Graph Kit" de Fred Rique, ~900 linhas, o mesmo tipo de código de produção que o Basic Dignified
original foi feito pra processar — muito mais valioso como teste de regressão que os exemplos
sintéticos da doc):
- `Trim()` do PureBasic só remove **espaços**, não **tabs** — qualquer linha indentada com TAB (`DEFINE`,
  `DECLARE`, `KEEP`, labels no início de linha) não era reconhecida, porque a "primeira palavra"
  calculada ainda tinha o tab grudado. Corrigido expandindo tabs para espaços logo no início do
  pipeline (`Dig_Preprocess` e `Tok_Tokenize`).
- `define [nome] [conteudo]` **com espaço** entre os dois colchetes é sintaxe válida no original
  (confirmado rodando o `badig.py` real) — meu parser exigia os colchetes colados. Corrigido.
- `##` funciona como comentário exclusivo em **qualquer posição da linha**, não só quando a linha
  inteira começa com `##` — ex. `codigo aqui ## comentário no fim`. Meu `Dig_StripComments` só
  tratava o caso de linha inteira. Corrigido com um scanner consciente de string (`Dig_FindUnquoted`)
  que acha o primeiro `##` fora de aspas e trunca a partir dali.
- `teste.dmx` também usa `FUNC`/`RET` (proto-funções) — confirmou na prática que era uma lacuna real,
  não só teórica. **Implementada em seguida** (ver abaixo).

**Nota de UX**: existem hoje 3 itens de menu relacionados a tokenizar, o que gerou confusão real (um
usuário tentou tokenizar um `.dmx` usando o menu que espera ASCII clássico já numerado, recebendo o
erro genérico do tokenizer "Line not starting with number" em vez de uma mensagem clara). Corrigido
com: (1) renomeação dos 3 itens para deixar a entrada esperada explícita no texto do menu (`Dignified
-> ASCII nativo`, `Dignified -> tokenizado nativo`, `ASCII clássico já aberto -> tokenizado nativo`);
(2) uma checagem heurística em `SaveAsTokenizedNative()` que detecta se a primeira linha não começa
com número e mostra uma mensagem apontando para o menu correto em vez do erro cru do tokenizer.

### 3b. FUNC/RET (proto-funções) — implementado (2026-07-13)

Portado por completo: `func .nome(p1, p2=default, ...)` ... `ret [e1, e2, ...]`, chamadas
`.nome(args)` (com ou sem captura `var1, var2 = .nome(args)`), reaproveitando a mesma infraestrutura
de marcador/resolução-em-2-passes já usada para labels (a entrada da função é tratada como um label
sintético `__func_<nome>`, resolvido no mesmo mapa `Dig_LabelLine`). Verificado contra o exemplo de
`BASIC_DIGNIFIED.md` (bate estruturalmente) e presente em uso real em `teste.dmx` (~20 funções).

**Bug de arquitetura encontrado e corrigido**: a varredura de chamadas `.nome(args)` inicialmente
reusava `Dig_MapCodeSegments` (que processa só os trechos "CODE", pulando strings) — mas isso quebra
quando um ARGUMENTO da chamada contém uma string literal (ex. `.upper("a")`), porque a string no meio
divide a linha em múltiplos segmentos CODE separados, e o casamento de parênteses não enxerga através
dela. Corrigido reescrevendo `Dig_FuncCalls_Piece` como um scanner autocontido que processa a **linha
inteira** com sua própria consciência de string/comentário/DATA, permitindo que o casamento de
parênteses atravesse literais de string normalmente.

**Escopo não coberto por `FUNC`/`RET` nesta v1**: conteúdo na mesma linha após `func .nome(...)` (a
doc original permite, ver `DIFFERENCES.md`: "Can have anything after a function definition") dá erro
explícito em vez de ser descartado silenciosamente — nenhuma ocorrência real disso foi encontrada em
`teste.dmx` (todas as ~20 definições de função têm `func` sozinho na linha).

### 3c. Bugs adicionais encontrados processando `teste.dmx` até o fim

Depois de implementar `FUNC`/`RET`, processar o arquivo completo (900 linhas) revelou mais 3 bugs
reais, todos corrigidos:
- **Literais hex/octal/binário tratados como variável**: `&hda00` virava `&ZZ` porque o estágio de
  redução de nomes de variável não sabia que `&H`/`&O`/`&B` iniciam um literal numérico — lia `hda00`
  como se fosse um identificador comum e o renomeava. Corrigido fazendo os dois scanners de variável
  (`Dig_CollectHardVar_Piece`, `Dig_ShortenVars_Piece`) reconhecerem e pularem esse padrão.
- **Blocos `###`/`''` exigindo estarem sozinhos na linha**: o arquivo real abre com
  `###\tInsert ML routines` (conteúdo colado logo após o marcador de abertura) e fecha com
  `...VRAM=&h1940###` (conteúdo colado antes do marcador de fechamento, no fim da linha) — nenhum dos
  dois é "###" sozinho. Meu detector original exigia igualdade exata com a linha inteira, então nunca
  reconhecia essas aberturas/fechamentos, e o conteúdo do bloco vazava como código real (virava lixo
  renomeado). Corrigido: agora abre quando a linha **começa** com `###`/`''` e fecha quando uma linha
  **termina** com `###`/`''`, tratando o que sobra em cada ponta como conteúdo do bloco (removido para
  `###`, mantido como comentário para `''`).
- **Linhas em branco dentro de bloco `''` sendo descartadas**: ao corrigir o item acima, uma
  simplificação inicial também suprimia linhas vazias dentro do bloco — mas a doc é explícita
  ("blank lines are removed except the ones inside regular block comments"). Corrigido para só
  suprimir a linha quando ela é exatamente o marcador de fechamento sozinho, não qualquer linha vazia.

Depois desses 3 fixes, **o arquivo `teste.dmx` inteiro (900 linhas) processa de ponta a ponta sem
erros**, gerando ASCII válido e, encadeado com o tokenizador, um `.bmx` de 18241 bytes.

### 3d. `teste.dmx` como suíte de regressão oficial do projeto

Por decisão do usuário (2026-07-13), `teste.dmx` (raiz do projeto) é o **arquivo de teste principal**
do pré-processador nativo — código de produção real (não exemplos sintéticos), então é o que deve ser
rodado depois de qualquer mudança em `DignifiedPreprocessor.pbi` ou `MsxTokenizer.pbi`.

Ferramenta permanente para isso: **`editor/tools/DigTestCli.pb`** (compilar com
`pbcompiler.exe editor/tools/DigTestCli.pb /EXE editor/tools/DigTestCli.exe /CONSOLE`) — CLI que roda
o pipeline completo (Dignified → ASCII → opcionalmente tokenizado) sem precisar abrir o editor:
```
DigTestCli.exe teste.dmx saida        ; gera saida.amx
DigTestCli.exe teste.dmx saida tok    ; gera saida.amx e saida.bmx
```
Um exit code diferente de 0 (ou "DIGERROR"/"TOKERROR" na saída) indica regressão. Não há suíte
automatizada de asserts ainda — a verificação até agora foi manual (grep por sintaxe Dignified não
resolvida sobrando no ASCII de saída, checar que `GOTO`/`GOSUB` sempre são seguidos de número, etc.);
uma melhoria futura seria automatizar essas checagens.

**Escopo não implementado**:
- ~~`INCLUDE` (arquivos múltiplos com namespace separado)~~ — **resolvida (2026-07-15)**, ver módulo 3g.
- ~~Remtags (`##BB:...`)~~ — **resolvida (2026-07-15)**, ver módulo 3g.
- Relatórios de debug (`-lbr`/`-lnr`/`-var`/`-lex`/`-par`).
- ~~Tradução Unicode→ASCII (`-tr`), conversão `?`/`PRINT` e strip `THEN`/`GOTO` (`-cp`/`-tg`)~~ —
  **resolvida (2026-07-14)**: implementadas em `DignifiedPreprocessor.pbi`
  (`Dig_TransChar`/`Dig_ConvertPrint_Piece`/`Dig_StripThenGoto_Piece`), configuráveis via `BadigCfg`.
- **Concatenação implícita de strings adjacentes entre linhas** (`PRINT "a "` seguido de `"b"` na
  próxima linha, sem `:`/`_` explícito) — feature documentada em `BASIC_DIGNIFIED.md` mas não
  portada; se usada, produz uma linha extra inválida em vez de juntar as strings. Baixa prioridade
  (raramente usado).
- Diferença cosmética conhecida e aceita: `+=`/`-=` podem deixar um espaço extra antes de um `:`
  subsequente quando o usuário digitou espaço antes do operador (ex. `var1++ :var2--` vira
  `ZZ=ZZ+1 :ZY=ZY-1` em vez de `ZZ=ZZ+1:ZY=ZY-1`) — inofensivo para o tokenizador (espaço é literal
  e ignorado em runtime pelo MSX), só difere visualmente do exemplo do Python original.

### 3e. Bug de charset no caminho Python + tela de configuração (2026-07-13)

**Bug corrigido**: o caminho **Python** (`SaveTokenized()` no editor, menu "Gerar tokenizado MSX via
Python (.bmx)..."; equivalente ao build padrão do Sublime do `badig/`) gerava `.bmx` truncado/corrompido
sempre que o fonte tinha caracteres especiais em string literal (box-drawing, acentos, letras gregas —
ex.: a tela de mapa de caracteres do `teste.dmx`, linha 243 em diante). Causa raiz em
`badig/support/badig_settings.py`: `load_format = 'utf-8' if translate else 'latin1'`, e nem o build
padrão do Sublime nem o editor passavam `-tr` — então o fonte (salvo em UTF-8, como qualquer editor
moderno salva) era lido como `latin1`: cada caractere especial multi-byte virava vários
caracteres-lixo, dessincronizando a contagem de caracteres da linha e corrompendo o cálculo de
tamanho/endereço de linha no tokenizador a partir dali. Corrigido: `load_format` agora é sempre
`'utf-8'` (independente de `-tr`) e `-tr` foi adicionado aos `.sublime-build` de
`badig/msx/Sublime Package/`. As duas correções são necessárias juntas — só `load_format` não bastava
(sem `-tr` os caracteres especiais não são convertidos para código nativo MSX e o `ord()` deles no
tokenizador ainda estoura de 1 byte).

**Novo módulo `editor/BadigSettings.pbi`**: tela de configuração nativa (menu "Configurar" → "Basic
Dignified...") para o caminho Python, com 3 abas espelhando os `.ini` de referência —
"Basic Dignified" (`badig/support/badig.ini`), "MSX" (`badig/msx/badig_msx.ini` +
`badig/msx/msxbatoken/msxbatoken.ini`), "Emulador" (`badig/msx/emulator_interface.ini`). Persistida em
JSON próprio do editor (`editor/badig_settings.json`), não nos `.ini` do Python — exceção:
`emulator_path` (único valor sem flag de CLI no `badig.py`) recebe patch textual direto na seção do SO
correta do `emulator_interface.ini` ao salvar. `Translate` vem com default ligado (fix do bug acima).
`BadigCfg_BuildCliArgs()` montava a linha de comando do `badig.py` a partir da configuração salva; usada
por `SaveTokenized()` no lugar dos flags fixos que tinha antes (ambos removidos em 2026-07-15, ver
"Débito técnico resolvido" acima).

**Ligado ao pipeline nativo (resolvido em 2026-07-14)**: `Dig_SyncConfigFromBadigCfg()` (em
`BadigEditor.pb`, chamada no início de `RunDignifiedPreprocessor()`) copia `BadigCfg` para os globals
`Dig_*` lidos por `DignifiedPreprocessor.pbi`, unificando as duas telas de configuração num só conjunto
de opções — a tela "Configurar → Basic Dignified..." agora vale tanto para o caminho Python quanto para
o nativo. Nessa mesma sessão o pré-processador nativo ganhou os passos finais que faltavam (equivalentes
ao `pass_5`/`generate()` do `badig_msx.py` original): conversão `?`/`PRINT` (`-cp`), strip
`THEN`/`GOTO` (`-tg`), tradução Unicode→ASCII nativo MSX (`-tr`, tabela completa validada contra o
original), maiusculização geral (`-ca`) e tamanho de TAB configurável. `strip_spaces` (`-ss`) foi
reinterpretado de forma pragmática (preserva um espaço entre palavras) — não é garantido byte-a-byte
idêntico ao Python original.

### 3f. Configurações do Editor e instalação do Basic Dignified Suite (2026-07-15)

**Novo módulo `editor/EditorSettings.pbi`**: tela de configuração nativa do editor em si (menu
"Configurar → Editor...", separada de "Configurar → Basic Dignified..."), com:
- **Fonte**: combo listando só fontes monoespaçadas instaladas no sistema, enumeradas via WinAPI
  (`EnumFontFamiliesEx`, filtrando `lfPitchAndFamily & 3 = FIXED_PITCH`) + tamanho.
- **Pasta de fontes customizadas** (opcional): arquivos `.ttf`/`.otf`/`.ttc` da pasta são carregados em
  memória via `AddFontResourceEx` (flag `FR_PRIVATE`) — visíveis só para o processo do editor, sem
  instalar nada no Windows. Como `AddFontResourceEx`/`RemoveFontResourceEx` não fazem parte da `.lib`
  de importação do gdi32 que o PureBasic traz embutida, são resolvidas em tempo de execução via
  `OpenLibrary("gdi32.dll")` + `GetFunction()` (com `Prototype` tipado), em vez de `Import` estático.
- **Caminho de instalação do editor** (`EditorPath`): editável, default = pasta do `.exe`. Não move o
  executável — serve de base para o cálculo do diretório padrão do Basic Dignified Suite (ver abaixo).
  Pensado para o cenário de 2 instalações do editor lado a lado (ex.: estável + beta).
- **Tema** (Escuro/Claro) e **Estilo de abas** (Moderno = chip arredondado, atual desde 2026-07-14;
  Clássico = retângulo plano). `ApplyTheme()` em `BadigEditor.pb` centraliza a paleta (cores de UI e de
  sintaxe) num único lugar, recalculada ao salvar as configurações (reaplica fonte/tema em todas as
  abas abertas via `SetupEditorStyles()` + `HighlightDocument()`, sem precisar reiniciar o editor).

Persistida em `editor/editor_settings.json`, mesmo padrão de `BadigSettings.pbi`.

**Diretório de instalação do Basic Dignified Suite**: `BadigSettings` ganhou o campo `InstallDir`
(struct + JSON + campo com botão de navegação na aba "Basic Dignified"). Default calculado por
`BadigCfg_DefaultInstallDir()`: se a instalação "clássica" (`..\badig`, o submódulo git que já existe
na raiz do projeto) for encontrada, usa ela — preserva o setup atual sem quebrar nada; senão usa o novo
padrão pedido pelo usuário, `EditorPath + "\badig"`. `SaveTokenized()` (caminho Python, removido em
2026-07-15 - ver módulo 3g) e `BadigCfg_SyncEmulatorIni()` foram migrados do caminho fixo antigo
(`GetPathPart(ProgramFilename()) + "..\badig\"`) para esse `BadigCfg\InstallDir` configurável.

**Botão "Baixar Basic Dignified Suite..."**: baixa o toolchain de referência
(`https://github.com/farique1/basic-dignified`) direto para o `InstallDir` configurado, por dois
métodos à escolha do usuário — clonar com `git clone --depth 1` (via `RunProgram`) ou baixar o `.zip`
da branch `main` (`ReceiveHTTPFile`, exige `UseNetworkTLS()` para HTTPS) e descompactar nativamente
(`UseZipPacker()` + `OpenPack()`/`ExaminePack()`/`UncompressPackFile()`, sem depender de nenhuma
ferramenta externa de unzip) — removendo o prefixo de pasta único que o GitHub inclui no `.zip`
(`basic-dignified-main/`) para que o conteúdo caia direto dentro de `InstallDir`, sem subpasta extra.

### 3g. INCLUDE e remtags — paridade nativa completa (2026-07-15)

**Status: implementado e verificado.** Com isso, `editor/DignifiedPreprocessor.pbi` cobre 100% do
escopo do `badig.py` original relevante para esta IDE (única exceção deliberada: relatórios de debug
`-lbr`/`-lnr`/`-var`/`-lex`/`-par`, que não têm consumidor na IDE). O menu Python legado foi removido
do editor (ver "Débito técnico resolvido" acima).

**Arquitetura**: o pipeline deixou de processar "todas as linhas do arquivo de uma vez" para processar
recursivamente **por arquivo** — `Dig_ProcessSource(SourceText, Prefix, OwnBasePath, IsMainFile,
OutLogLines)` roda os estágios de comentário/toggle/join/`DEFINE`/`DECLARE`/labels/`FUNC`/`RET`/
`Dig_FuncCalls_Piece`/`Dig_ScanLabelRefs_Piece` sobre **um** arquivo (principal ou incluído), devolvendo
sua lista de "linhas lógicas" ainda sem numeração (numeração/`TRUE`/`FALSE`/operadores compostos/
redução de variáveis só fazem sentido para a árvore inteira já mesclada, então continuam em
`Dig_Preprocess`, que chama `Dig_ProcessSource` uma vez para o arquivo principal e deixa os `INCLUDE`
se expandirem recursivamente por dentro). Mesma divisão de responsabilidade documentada em
`docs/reference/dignified-core.md` (Pass 1-3 por arquivo, Pass 4-5 só na árvore mesclada) — só que
aqui em uma única função recursiva ao invés de passes separados.

**`INCLUDE "arquivo"`**: resolvido relativo ao diretório do arquivo que contém a instrução
(`OwnBasePath`, propagado recursivamente — cada arquivo incluído resolve os próprios `INCLUDE`
relativos à sua própria pasta, não à do arquivo principal). Caminho absoluto (com `:` ou barra inicial)
é usado como está. Detecção de ciclo via `Dig_IncludeStack` (pilha dos caminhos atualmente abertos,
comparação case-insensitive) e limite de profundidade (`#Dig_MaxIncludeDepth = 16`) — nota: a
detecção de ciclo não cobre o caso em que um include aponta de volta para o **próprio arquivo
principal** na primeira tentativa (só é pega uma recursão depois, quando o arquivo principal é
reprocessado como se fosse um include) porque o caminho do arquivo principal em si nunca é empurrado
na pilha; o limite de profundidade garante que isso nunca vira loop infinito, só um erro relatado
uma recursão mais tarde do que o ideal — melhoria futura de baixo risco.

**Namespace por arquivo**: exatamente como documentado (`docs/reference/dignified-core.md`, Pass 3) —
variáveis (`Dig_Declares`/`Dig_HardShort`/`Dig_HardLong`/`Dig_VarIndex`) são **compartilhadas** entre
arquivo principal e includes (nunca resetadas por `Dig_ProcessSource`, um único pool global de nomes
curtos ZZ→AA para o programa inteiro); já `DEFINE`/toggle-rem/`KEEP`/`FUNC`/`RET` são **isolados** por
arquivo (salvos/restaurados via `CopyMap()` ao redor de cada chamada recursiva). Labels, loop-labels e
nomes de função usam um prefixo interno único por instância de include (`Dig_CurrentPrefix`, formato
`__incN$` incremental, `Dig_IncludeCounter`) aplicado tanto no registro do nome quanto nos marcadores
internos que os referenciam (`Chr(2)+"J"/"B"/"G"/"X"+nome+Chr(2)`, ver comentário no topo do arquivo) —
dois arquivos diferentes podem usar o mesmo nome de label/loop/função sem colidir, cada um resolve
dentro do seu próprio escopo. Verificado com um fixture de teste com labels `{start}`/loop `loop{}`/
função `.show()` de mesmo nome no arquivo principal e no incluído, variáveis diferentes em cada um
(pool compartilhado, sem colisão de nome curto) — todas as chamadas/saltos resolveram para o arquivo
correto, sem erro de "label duplicado".

**Remtags (`##BB:comando=valor`)**: reconhecidos em `Dig_StripComments` (mesma posição do antigo stub
que só descartava a linha) — **só lidos do arquivo principal**, nunca de arquivos incluídos (mesma
regra de `badig_settings.py`: `read_remtags_from_code(self.args.input)`). Comandos suportados (os
únicos de fato registrados como remtag em `badig_settings.py` — `CONVERT_ONLY`/`TOKENIZE`, citados em
`badig_dignified.py`, nunca chegam a virar remtag utilizável nessa versão do toolchain):
- `ARGUMENTS`: aplica um subconjunto das flags de linha de comando do `badig.py`/`badig_msx.py`
  (`-tl -ls -lp -rh -ss -ca -tr -cp -tg`) como override dos globals `Dig_*` **só para esta chamada**
  de `Dig_Preprocess` (as demais flags reconhecidas pelo parser original — relatórios, `-id`, `-vb`,
  `-asc`, `-ini`, `-rtg` — são aceitas e ignoradas, consumindo o valor quando a flag original recebe
  um, só para não desalinhar o parsing das flags seguintes).
- `EXPORT_FILE`: expõe `Dig_ExportFileOverride` (caminho resolvido contra o diretório do arquivo fonte)
  para o chamador usar como sugestão de nome no `SaveFileRequester` (não pula o diálogo de salvar —
  só pré-preenche, mantendo a confirmação do usuário).
- `HELP`: reconhecido (não gera erro de "remtag desconhecido"), mas sem efeito prático — o original
  imprime a lista de remtags disponíveis e sai do processo, o que não faz sentido dentro do fluxo do
  editor GUI.

### 4. Editor sprite/char — sprite e alfabeto (charset) implementados (2026-07-19)

- **Arquivo**: `editor/SpriteEditorGui.pbi`, menu **Criar → Sprite...**. Janela própria (não modal em
  relação ao editor de texto — desabilita a janela principal enquanto aberta, mesmo padrão do
  gerenciador de disco).
- **Grade**: 8×8 ou 16×16 blocos (os dois tamanhos de sprite reais do VDP do MSX), cada bloco guarda um
  índice de cor 0–15 (0 = transparente). Canvas sempre com a mesma área em pixels — o tamanho de cada
  bloco (não o número de blocos) que muda ao trocar 8×8/16×16.
- **Palheta**: as 16 cores fixas do MSX1 (TMS9918), seletor 4×4 clicável; índice 0 mostrado com um "X"
  em vez de preenchimento.
- **Modos de cor MSX1/MSX2** (radio ao lado do tamanho): no **MSX1** o sprite inteiro só pode ter uma
  cor — trocar a cor atual ou pintar recolore instantaneamente todos os blocos já pintados
  (`SpriteEd_RecolorAll`); no **MSX2** cada **linha** pode ter a sua própria cor, mas só uma dentro da
  linha — qualquer linha que receba a cor atual tem seus blocos já pintados recolorados para bater
  (`SpriteEd_EnforceMSX2ForColor`), sem precisar saber de antemão quais linhas uma operação afetou
  (funciona igual para pintar, formas geométricas e balde).
- **Ferramentas** (barra de ícones, todas mutuamente exclusivas — `SpriteEd_UnpressOtherTools`):
  - **Lápis**, **borracha**, **pincel** (bloco 2×2 por clique) — clique único ou arrastar com o botão
    esquerdo pressionado risca/apaga/pinta continuamente.
  - **Reta**, **retângulo** (vazio/cheio), **elipse/círculo** (vazio/cheio) — ferramentas de dois
    pontos: o primeiro clique marca o ponto inicial (marcador piscando via `AddWindowTimer`, 500 ms) e,
    conforme o mouse se move, uma **prévia ao vivo** da forma é recalculada numa máscara separada
    (`SpriteEd_ComputePreviewMask`, reaproveita as mesmas rotinas de desenho de verdade) e desenhada
    por cima da grade (`SpriteEd_DrawPreviewOverlay`) sem tocar nos dados reais. O segundo clique
    confirma e traça; **Esc** (atalho de janela via `AddKeyboardShortcut`) ou o **botão direito** do
    mouse cancelam sem alterar nada.
  - **Balde** — preenchimento por área conectada (flood fill 4-direções, pilha explícita).
  - **Rotacionar** (com "quebra" nas bordas — o que sai de um lado reaparece do outro) e **deslocar**
    (sem quebra — o que sai se perde, o espaço liberado vira transparente) nas quatro direções
    (`SpriteEd_TranslateGrid`), **inverter** todos os pontos, **limpar** tudo.
- **Prévia**: canto da janela mostra o sprite em escala reduzida, mais perto da proporção real (sem as
  linhas de grade da área de edição).
- **Integração com o sistema de projeto** (ver módulo 13): barra própria no topo da janela —
  - Número do sprite atual e tag (nome curto, até 16 caracteres, truncada tanto ao digitar quanto ao
    registrar).
  - **Registrar** — grava (INSERT ou substitui) o sprite atual no projeto aberto no momento.
  - **Novo** — cria o próximo sprite em sequência (maior número já registrado + 1), grade em branco.
  - **Primeiro/Anterior/Próximo/Último** — navegam pelos sprites já registrados no projeto (consulta
    `ProjectDB::ListSpriteNumbers()`, trava nas pontas em vez de dar volta).
  - **Copiar/Colar** — clipboard de sessão (grade + tamanho + modo), só dura enquanto a janela do
    editor de sprites está aberta; permite duplicar um sprite para outro número.
  - Qualquer alteração não registrada (`SpriteDirty`) pede confirmação antes de navegar para outro
    sprite ou fechar a janela.
- **Char/tile - Alfabeto (Graphos III)**: `editor/CharsetEditorGui.pbi`, menu **Criar → Alfabeto...**,
  janela própria (mesmo padrão desabilita-a-principal-enquanto-aberta do sprite/disco). Edita o mesmo
  formato de charset do Graphos III: 256 caracteres × 8 bytes (bitmap 8×8, 1 bit por pixel) = 2048 bytes,
  originalmente carregado em VRAM no endereço `&H9200` (Pattern Generator Table).
  - **Arquivo `.ALF`**: binário MSX clássico — cabeçalho de 7 bytes (byte de tipo `&HFE`, endereço
    inicial/final/execução, 2 bytes cada, little-endian) seguido dos 2048 bytes de dados. Endereço final
    é o do **último** byte (inclusive, `início + 2047`) — confirmado contra o cabeçalho de um `.alf` real
    do Graphos III (`CharEd_LoadAlf`/`CharEd_SaveAlf`); validado na leitura (byte de tipo + tamanho
    mínimo), rejeita com mensagem de erro em vez de carregar lixo silenciosamente.
  - **Tabela de 256 caracteres** (16×16, `CharEd_RedrawTable`): cabeçalho hex de linha (byte alto) e
    coluna (nibble baixo) — a posição na grade já é o próprio código do caractere, como um mapa de
    caracteres clássico. Cada célula é uma miniatura 8×8 (zoom 2×) do glifo atual; a seleção ganha um
    contorno vermelho.
  - **Grade grande editável** (8×8, `CharEd_RedrawEditCanvas`): clique liga/desliga um pixel; arrastar
    com o botão esquerdo pressionado pinta uma sequência de pixels com o mesmo valor do primeiro clique
    (mesmo padrão de arrastar do lápis/borracha do editor de sprites). **Registrar** é que de fato grava
    os pixels editados de volta nos 8 bytes do caractere selecionado (e atualiza a miniatura na tabela) —
    trocar de caractere ou fechar a janela sem registrar pede confirmação (`CharEd_ConfirmDiscardChar`,
    mesmo padrão do `SpriteEd_ConfirmDiscardSprite`). **Limpar** opera na grade em edição (não registra
    sozinho). Leitura auxiliar dos 8 bytes hex do caractere em edição ao lado da grade.
  - **Clipboard de caractere** (2026-07-21, `CharEd_PackGridBytes`/`CharEd_UnpackGridBytes`): botões
    **Copiar**/**Colar** guardam/restauram os 8 bytes do caractere em edição num array local à janela
    (`ClipChar`/`ClipCharValid`, mesma vida útil do clipboard de sprite — só dura enquanto a janela
    estiver aberta). Copiar lê direto do `EditGrid` (o que está desenhado agora, mesmo sem
    "Registrar"); Colar escreve no `EditGrid` e marca `EditDirty` (ainda precisa de "Registrar").
    Funciona entre caracteres do mesmo alfabeto ou de alfabetos diferentes, já que o clipboard não é
    tocado por `CharEd_LoadAlphabetUI` (navegação entre alfabetos).
  - **Clipboard de alfabeto inteiro** (2026-07-21): botões **Copiar alfabeto**/**Colar alfabeto**
    (barra de projeto) guardam/restauram os 256 caracteres via `CopyArray()` num array local
    (`ClipAlpha`/`ClipAlphaValid`, 255×7 igual a `CharsetBytes`). Copiar aplica antes qualquer edição
    pendente do caractere selecionado (mesmo bloco de código do evento `G_AlphaRegister`, reaproveitado
    inline) pra não deixar pixels de fora; Colar substitui `CharsetBytes` inteiro e marca `AlphaDirty`
    (ainda precisa de "Registrar alfabeto"), pedindo confirmação de descarte se havia edição pendente.
  - **Inverter em bloco** (2026-07-21): `BlockStart`/`BlockEnd` (`Protected .i = -1`, "nenhum bloco")
    são marcados pelos botões **Marcar início**/**Marcar fim** (gravam o caractere selecionado na
    tabela no momento do clique) e desfeitos por **Limpar bloco**; `CharEd_BlockStatusText()` mostra o
    intervalo normalizado (`$41..$5A (26 caracteres)`) e `CharEd_RedrawTable()` ganhou um 4º/5º
    parâmetro opcional (`BlockStart.i = -1, BlockEnd.i = -1`) que desenha um contorno azul em cada
    caractere do intervalo (além do contorno vermelho do selecionado). O botão **Inverter** (evento
    `G_Invert`) passou a ramificar: **sem bloco marcado**, comportamento de sempre (inverte só o
    `EditGrid`, via `CharEd_InvertEditGrid`, precisa de "Registrar"); **com bloco marcado**, inverte
    bit a bit (`(~CharsetBytes(i,row)) & $FF`) todos os caracteres do intervalo **direto em
    `CharsetBytes`**, ignorando o `EditGrid` — operação de alfabeto, não de pixel, marca `AlphaDirty`
    em vez de `EditDirty`. Se o caractere selecionado está dentro do intervalo e tem edição pendente
    não registrada, ela seria perdida (o bloco sobrescreve `CharsetBytes` do próprio caractere
    selecionado) — pede confirmação (`CharEd_ConfirmDiscardChar`) antes. `BlockStart`/`BlockEnd` são
    independentes do alfabeto carregado (persistem através de `CharEd_LoadAlphabetUI` durante
    navegação), permitindo repetir a mesma inversão de intervalo em vários alfabetos sem remarcar.
    Layout: linhas dos novos botões (`Copiar alfabeto`/`Colar alfabeto` acima da tabela; `Marcar
    início`/`Marcar fim` numa linha e `Limpar bloco`/status numa segunda, abaixo da tabela; `Copiar`/
    `Colar` de caractere abaixo de `Registrar`/`Limpar`/`Inverter`) foi dimensionado pra caber dentro
    da largura da própria tabela (`#CharEd_TableCanvasW`), evitando invadir a coluna direita (grade de
    edição) na mesma altura — colisão real encontrada e corrigida durante o desenvolvimento (a primeira
    tentativa botou o status do bloco numa única linha larga ao lado dos botões de marcar, que invadia
    a coluna direita e sobrepunha os botões `Copiar`/`Colar` de caractere).
  - **Copiar bloco/Colar bloco** (2026-07-21, mesmo dia): dois botões extras na linha do `Limpar
    bloco`, copiando/colando o **intervalo inteiro** marcado (não um único caractere) — pedido explícito
    do usuário pra permitir ter duas versões (normal e invertida) do mesmo conjunto de caracteres no
    mesmo alfabeto. `Copiar bloco` normaliza `BlockStart`/`BlockEnd`, aplica qualquer pixel pendente do
    caractere selecionado se ele cair dentro do intervalo (mesmo padrão de `G_CopyAlpha`) e copia
    `CpEnd-CpStart+1` caracteres pra um array local (`ClipBlock` 255×7 + `ClipBlockLen` +
    `ClipBlockValid`). `Colar bloco` usa o **caractere atualmente selecionado na tabela** como início do
    destino (`PasteStart = Selected`) — rejeita com mensagem de erro se `PasteStart + ClipBlockLen - 1`
    passar de 255 (não cabe), em vez de truncar ou dar volta silenciosamente; senão escreve direto em
    `CharsetBytes` (mesmo cuidado de confirmação de descarte do Inverter em bloco se o caractere
    selecionado, dentro do destino, tiver edição pendente) e **remarca `BlockStart`/`BlockEnd` pro
    intervalo de destino recém-colado** — permite clicar `Inverter` na sequência sem remarcar,
    fechando o fluxo completo do pedido original (marcar A..Z, copiar, selecionar "a", colar,
    inverter → A..Z normal e a..z invertido, prontos como dois conjuntos). Verificado: compilação
    limpa, screenshot da linha de 3 botões (`Limpar bloco`/`Copiar bloco`/`Colar bloco`, larguras
    100+100+100 com gaps de 6, ainda dentro de `#CharEd_TableCanvasW`) e um smoke test ao vivo via
    `BM_CLICK` (Marcar início + Marcar fim apontando pro mesmo caractere por causa da mesma limitação
    de clique em canvas já registrada acima, depois Copiar bloco e Colar bloco em sequência) confirmando
    que o fluxo roda sem erro e sem travar em nenhum `MessageRequester` inesperado — teste
    deliberadamente evitou os caminhos de erro (`MessageRequester` é modal, travaria a automação) e não
    exercitou um destino realmente diferente do intervalo copiado (depende de clique em canvas, mesma
    ressalva de sempre), mas a lógica é direta e seguiu o mesmo padrão já validado do Inverter em bloco.
  - **Carregar do Graphos III.../Salvar como...** (renomeado de "Abrir..." em 2026-07-21): diálogos
    com filtro `*.alf`; extensão `.alf` acrescentada automaticamente se o usuário não digitar nenhuma
    em "Salvar como..." (`EnsureExtension`, mesma rotina do fluxo de projeto). "Carregar do Graphos
    III..." deixou de sobrescrever o alfabeto atualmente selecionado — agora consulta
    `ProjectDB::ListAlphabetNumbers()` (mesma lógica de "Novo alfabeto") e importa sempre como um
    **alfabeto novo** (`AlphaDirty = #True`, ainda precisa de "Registrar alfabeto" pra valer no
    projeto), evitando sobrescrever sem querer um banco já registrado; "Salvar como..." continua
    independente do sistema de projeto, exporta só o buffer em edição pra um `.alf` de verdade
    (compatibilidade Graphos III).
  - **Integrado ao sistema de projeto** (2026-07-19, módulo 13) — mesmo padrão do editor de sprites:
    tabela `alphabets` no `.msxproject` (`alphabet_number` chave primária, `tag`, `charset_data` — TEXT
    hex, 2 dígitos por byte, 4096 caracteres —, `updated_at`). Barra de projeto própria no topo da
    janela: número do alfabeto atual + **Primeiro/Anterior/Próximo/Último** (`ProjectDB::
    ListAlphabetNumbers()` + `SpriteEd_FindNavTarget()`, reaproveitado do editor de sprites — função
    genérica, sem nada específico de sprite), campo de **tag** (até 16 caracteres), **Registrar
    alfabeto** (grava o alfabeto inteiro — 256 caracteres — no projeto; também aplica antes qualquer
    edição pendente do caractere atual, pra não perder pixels não registrados a nível de caractere) e
    **Novo alfabeto** (numera automaticamente, maior número já registrado + 1). Duas camadas de "não
    registrado" rastreadas separadamente (`EditDirty` por caractere, `AlphaDirty` pelo alfabeto inteiro)
    — qualquer uma pendente pede confirmação (`CharEd_ConfirmDiscardAlphabet`) antes de navegar, criar
    novo ou fechar a janela.
  - **"Projeto 0" (defaults, 2026-07-19)** — `ProjectDB::EnsureDefaultsOpen()`: uma **segunda conexão
    SQLite** (`#DefaultsDB`), sempre `OpenDatabase(#DefaultsDB, ":memory:", ...)`, nunca em arquivo,
    recriada do zero a cada vez que a IDE abre, completamente independente do projeto ativo (`#DB`) —
    o usuário não tem como "Salvar" esse projeto porque não existe nenhum caminho de código que grave
    nele. Semeada com o **alfabeto 0 = charset padrão do MSX**, embutido no próprio `.exe` via
    `editor/DefaultCharsetMsx.pbi` (`DataSection` com os 2048 bytes de `alfabetos\msx.alf`, gerado por
    script a partir do `.alf` real — ver comentário no topo do arquivo dizendo pra regenerar, não editar
    à mão). **Novo alfabeto** sempre parte desse alfabeto 0 (`ProjectDB::FetchDefaultAlphabet(0, ...)`),
    nunca em branco — diferente do "Novo sprite", que começa vazio; foi um pedido explícito. Mesma fonte
    também usada como charset inicial ao abrir a janela quando o projeto ainda não tem nenhum alfabeto
    registrado. **Detalhe de PureBasic**: um `Module` não enxerga uma `Procedure`/`DataSection` externa
    definida fora dele mesmo com forward `Declare` — só funciona com `XIncludeFile
    "DefaultCharsetMsx.pbi"` de dentro do próprio `Module ProjectDB ... EndModule` (ver comentário em
    `ProjectDB.pbi`).
  - **Harness**: `ProjectDBTestCli.pb` ganhou cobertura completa (Store/Fetch/List/Has de alfabetos,
    round-trip via `SaveAs`/`OpenExisting`, e um teste que lê `alfabetos\msx.alf` direto do disco e
    confere que bate byte a byte com `FetchDefaultAlphabet(0, ...)` — pega qualquer futura
    dessincronização entre o `.alf` fonte e os bytes embutidos no `.exe`).
  - **Tile** (além do charset/fonte 8×8): ainda não iniciado.

### 4b. Editor de alfabetos Aquarela (.FNT) — implementado (2026-07-23)

**Arquivo**: `editor/AquarelaCharsetEditorGui.pbi`, menu **Criar → Alfabeto Aquarela...**. Edita o
formato `.FNT` do **Aquarela** (outro editor de fonte MSX, alternativa ao Graphos III do módulo 4) —
engenharia reversa completa em `docs/reference/aquarela.md`. Diferente do editor Graphos III, esta é
uma ferramenta **autocontida baseada em arquivo** (Abrir/Salvar/Salvar como, no espírito do fluxo
"Carregar do Graphos III.../Salvar como..." do módulo 4), **sem** integração com `ProjectDB` (que só
modela o formato 256×8 do Graphos III) e **sem** os efeitos de bloco/desfazer do módulo 4c.

**Formato do glifo**: 16×16 real (não 8×8), armazenado em 2 planos de 16 bytes (bytes 0-15 = coluna
esquerda de cada linha, bytes 16-31 = coluna direita) — a grade de edição sempre mostra as 16 colunas
inteiras, mesmo para os glifos "8×8" do Aquarela (a maioria das amostras reais) que só usam a metade
esquerda. Cada registro de 32 bytes começa **7 bytes depois** do que a fórmula ingênua sugeriria
(`#AqEd_RecordOffset = 7`) — descoberta por comparação pixel a pixel contra uma screenshot real do
Aquarela rodando num emulador (ver `docs/reference/aquarela.md`, seção "DESLOCAMENTO DE 7 BYTES"); sem
esse ajuste, cada caractere aparecia com um "floreio" desconexo no topo (na real, a ponta final do
caractere anterior) e faltavam as últimas ~7 linhas do caractere de verdade.

**46 caracteres editáveis** (grade de 8 colunas × 6 linhas, as 2 últimas células sem uso —
`#AqEd_Slots = 46`), ordem confirmada por teste real do usuário contra o Aquarela de verdade e contra
`LOGO.FNT` (fonte 8×8 completa do disco original): `A-Z`, `&`, `?`, `!`, `"`, `0-9`, `.`, `:`, `-`,
`(`, `)`, `,`. Ampliado de 32 para 46 nesta sessão (os 14 caracteres novos: `2-9`, `.`, `:`, `-`, `(`,
`)`, `,` — antes só ia até `1`, o caso que o usuário reportou como "parece corrompido"). Ao salvar,
grava sempre no formato de 2304 bytes (72 registros — a variante confirmada carregando sem erro contra
todo o corpus de amostras testado), com os 26 registros além dos 46 editáveis preenchidos com o byte
de posição-vazia `$40` e os 7 bytes de deslocamento replicados corretamente.

**Botões** (mesmo estilo de ícones monocromáticos do módulo 4, sem texto): **Novo** (alfabeto em
branco), **Abrir...**/**Salvar**/**Salvar como...** (arquivo `.fnt`), **Registrar** (grava os pixels
editados nos 32 bytes do caractere selecionado), **Limpar**, **Inverter** (todos afetando só o
`EditGrid`, precisam de "Registrar" — sem conceito de bloco/All aqui), **Copiar**/**Colar** de um
caractere isolado (clipboard de sessão, mesmo padrão do módulo 4).

**Validação de arquivo**: `AqEd_LoadFnt` só exige que o arquivo tenha pelo menos 46 registros de 32
bytes (os arquivos reais têm até 71/72); não valida ainda se a posição 0 decodifica como 'A' (a marca
de arquivo íntegro documentada em `docs/reference/aquarela.md`) — fica a cargo do usuário conferir
visualmente por enquanto, mesma lacuna citada em "Lacunas conhecidas" abaixo.

### 4c. Efeitos de edição em lote do editor de alfabetos Graphos III (2026-07-23)

Onze novos botões-ícone no editor Graphos III (módulo 4), todos seguindo o **mesmo padrão dual** já
estabelecido pelo "Inverter" original: **sem bloco marcado**, afetam só o `EditGrid` do caractere em
edição (precisa de "Registrar" pra valer); **com um bloco marcado** (ver "Marcar bloco" no módulo 4,
ou o novo botão **All**), aplicam direto em `CharsetBytes`, em todo o intervalo de uma vez, sem passar
por "Registrar" caractere a caractere. `CharEd_ApplyGridEffectToRange()` centraliza essa aplicação em
lote (unpack → transforma → pack por caractere do intervalo), reaproveitada por todos os efeitos
abaixo em vez de duplicar a lógica de bits em cada botão.

- **All** — marca o alfabeto inteiro (0..255) como bloco de uma vez, sem precisar clicar num caractere
  duas vezes (Marcar início + Marcar fim no mesmo caractere) — atalho pra aplicar um efeito a todos os
  256 caracteres.
- **Desfazer**/**Refazer** — pilha de instantâneos do alfabeto **inteiro** (256×8 = 2048 bytes,
  `CharEd_AlphaSnapshot`, barato de copiar em memória), limitada a `#CharEd_MaxUndo = 50` níveis.
  Empilha um instantâneo só nas operações que de fato gravam em `CharsetBytes` (Registrar, qualquer
  efeito em modo bloco/All, Colar bloco, Colar alfabeto) — pixels editados mas ainda não registrados
  não entram na pilha, mesmo espírito de "editar sem registrar não muda o alfabeto em memória" do
  resto do editor. A pilha é zerada sempre que o alfabeto em edição troca (navegação/Novo/Carregar),
  já que um instantâneo de outro alfabeto não faz sentido pra desfazer o atual. Botões
  habilitados/desabilitados (`DisableGadget`) conforme o que há em cada pilha.
- **Espelhar horizontal**/**Espelhar vertical** — espelha o glifo 8×8 na horizontal/vertical
  (`CharEd_FlipHEditGrid`/`FlipVEditGrid`).
- **Girar 90 graus** — rotação horária de matriz quadrada (`novo(Row,Col) = antigo(7-Col,Row)`,
  `CharEd_RotateEditGrid`).
- **Apagar** — mesmo efeito de "Limpar", mas com o modo dual (bloco/All apaga todo o intervalo direto
  no alfabeto); reaproveita o ícone de "Limpar" (mesma convenção já documentada no módulo 4 — botões
  de escopo diferente reaproveitam o mesmo desenho, a posição/dica é que diferencia).
- **Estreitar** — condensa as 5 colunas da metade esquerda do glifo (0-4) em só 3 colunas de saída,
  juntando pares de colunas por OR: colunas 0-1 → coluna 0, coluna 2 → coluna 1, colunas 3-4 →
  coluna 2, colunas 5-7 sempre apagadas. Truque clássico de texto MSX pra caber 64 colunas onde só
  caberiam 32 (célula de 8px com o glifo condensado nas 3 colunas mais à esquerda).
- **Itálico** — desloca cada linha do glifo à direita por uma quantidade que diminui de cima pra
  baixo: linhas 0-1 deslocam 2 bits, linhas 2-4 deslocam 1 bit, linhas 5-7 ficam iguais (0 bits) —
  "deslocar N bits à direita" empurra as colunas (`NovaCol(c) = VelhaCol(c-N)` para `c≥N`, senão 0;
  as N colunas mais à direita da linha original se perdem, mesmo comportamento de um `SHR` real).
- **Negrito** — cada linha vira OR entre ela mesma e ela deslocada 1 bit à direita
  (`NovaCol(c) = VelhaCol(c) OR VelhaCol(c-1)` para `c≥1`), engrossando cada traço vertical em 1px.
- **Largo** — combina as colunas 0-2 do byte original com as colunas 3-7 do byte deslocado 1 bit à
  direita (`ByteA = Original AND %11100000` OR `ByteB = (Original>>1) AND %00011111`), esticando o
  glifo em 1px (repete a coluna 2 nas posições 2 e 3 do resultado; coluna 7 do original se perde).
- **Bold (esquerda)**/**Bold (direita)** — variantes do Largo que também engrossam (OR, não só
  desloca) um dos lados: **Bold (esquerda)** = `(Original AND %11100000) OR (Original>>1)` inteiro
  (colunas 1-2 recebem OR com a cópia deslocada, colunas 3-7 vêm só da cópia deslocada); **Bold
  (direita)** = espelho, `((Original>>1) AND %00011111) OR Original` inteiro (colunas 0-2 ficam iguais
  ao original, colunas 3-7 recebem o OR). Nomeados/renomeados nesta sessão depois de uma correção do
  usuário — inicialmente chamados "Largo (direita)"/"Largo (esquerda)".
- **Largo (bold)** — `Bold(Largo(x))`: aplica o efeito Largo comum e depois o Negrito em cima do
  resultado já alargado, reaproveitando as duas transformações existentes em vez de uma fórmula de
  bits nova.

Ícones desenhados em memória (mesmo estilo do módulo 4): seta circular de ~270° com ponta triangular
(Desfazer/Refazer, espelhados via `Mirrored.b` — um único desenho, a versão "Desfazer" é a "Refazer"
com cada ponto espelhado no eixo X), setas triangulares apontando pra dentro/fora de uma linha
pontilhada ou barra central (Espelhar H/V, Estreitar, Largo e variantes), quadrado com arco horário ao
redor (Girar), barras empilhadas deslocando (Itálico), barra clara+escura sobrepostas (Negrito),
retângulo pontilhado tipo "marquee" (All). `CharEd_DrawFilledHTri`/`DrawFilledVTri` (extraídos do
desenho de seta de navegação já existente) desenham triângulos preenchidos por faixas de `LineXY`, sem
precisar de preenchimento de polígono — reaproveitados por vários ícones novos.

### 5. Editor gráfico LINE/CIRCLE/PSET/DRAW
- Mais simples que DRAW puro isolado porque LINE/CIRCLE/PSET são coordenadas absolutas (sem estado de
  posição/ângulo atual).
- Saída: lista de comandos BASIC prontos (`LINE...`, `CIRCLE...`, `PSET...`, `DRAW...`) na ordem
  desenhada, para injeção como bloco/include.

### 6. Editor de som SOUND (PSG / AY-3-8910 / YM2149)

**Status (2026-07-21): implementado.** Menu **Criar → Som (PSG)...**, arquitetura em três partes
(mesmo padrão de `MSXDisk.pbi`/`DiskManagerGui.pbi`/`--diskmanipulator`): motor de emulação sem GUI
(`editor/PsgSynth.pbi`), janela (`editor/PsgEditorGui.pbi`) e harness headless
(`editor/tools/PsgTestCli.pb`).

**Escopo fechado com o usuário**: um "som" é um **mini-sequenciador de passos** (lista curta, cada
passo com seus 14 registradores + duração em quadros) — um time-line de UM instrumento/efeito
(tiro, explosão, etc.), não um sequenciador multi-canal/multi-padrão (isso continua sendo escopo do
módulo 7/Tracker, ainda não detalhado). Playback é "sob demanda" (botão Tocar renderiza a sequência
inteira e toca via `.wav` temporário), não streaming ao vivo enquanto arrasta controle.

**Motor (`PsgSynth.pbi`)**: emulação por acumulador de fase (osciladores de tom dos 3 canais, LFSR de
17 bits do ruído, gerador de envelope com as 10 formas de hardware documentadas + tabela de volume
logarítmica de 16 passos), clock `1789772.5` Hz (PSG do MSX = clock da CPU / 2). Estado do chip
persiste entre passos da sequência (fases de tom/ruído nunca resetam; o envelope só reinicia quando um
passo realmente escreve um R13 diferente do anterior, espelhando o hardware real). Validado contra um
tom puro (frequência medida por cruzamento de zero bate com `Clock/(16×TP)` dentro de 5%) e contra
volume 0 = silêncio absoluto (`PsgTestCli.exe <pasta>`).

**Geração de código**: `PsgGen_BasicLines` emite `SOUND n,valor` só para os registradores que mudaram
em relação ao passo anterior (registrador não tocado mantém o valor no hardware real), com um
`FOR/NEXT` de espera aproximada entre passos (constante de calibração `#PsgGen_LoopItersPerFrame`,
deliberadamente não calibrada sample-accurate contra hardware/emulador real — ver comentário no código).
`PsgGen_RawBytes` emite um bloco `DATA` com os 14 bytes crus + duração por passo, para uma futura
rotina Z80/`#asm`. Botões **Injetar no cursor** (reaproveita `InjectTextAtCursor()`, o mesmo helper já
usado pelo editor de sprites) e **Copiar** (`SetClipboardText`).

**Persistência**: tabela `psg_sounds` em `ProjectDB.pbi` (mesmo padrão de `sprites`/`alphabets`,
`StoreSound`/`FetchSound`/`ListSoundNumbers`/`HasSound`), com barra de projeto idêntica à dos editores
de sprite/alfabeto (número do som, tag, Primeiro/Anterior/Próximo/Último, **Novo**/**Registrar** — desde
2026-07-21 (sessão 6) os dois últimos são ícones (`ButtonImageGadget`), reaproveitando
`SpriteEd_CreateNewSpriteIcon`/`SpriteEd_CreateRegisterIcon` do editor de sprites em vez de texto, pra
ficar uniforme com o resto da IDE). Os 14 registradores por passo são serializados como um array **1D
achatado** (`Regs(i*14+r)`), não uma matriz 2D — armadilha real encontrada durante o desenvolvimento:
`ReDim` no PureBasic só redimensiona a **última** dimensão de um array, então `FetchSound` tentando
`ReDim` a primeira dimensão (número de passos) de uma matriz 2D corrompia a heap (crash
`STATUS_HEAP_CORRUPTION`); o array 1D resolve porque sempre tem uma única dimensão redimensionável.
Coberto por round-trip em `editor/tools/ProjectDBTestCli.pb` (store/fetch/list/overwrite/SaveAs/
OpenExisting).

### 7. Tracker (escopo alto, não detalhado)
- Sequenciador de padrões, editor de padrão (grade linha × canal, nota/volume/efeito), motor de
  playback (tempo real ou geração de trilha para tocar via Z80/interrupção), "instrumentos" = envelope +
  volume ao longo do tempo (sem sample/wavetable, diferente de tracker MOD).

### 8. Editor MML (comando `PLAY`)

**Status (2026-07-21): implementado.** Menu **Criar → Música (PLAY)...**, mesma arquitetura triádica
motor/janela/harness dos módulos 6/12: `editor/MmlSynth.pbi` (parser MML + mixagem, sem GUI),
`editor/MmlEditorGui.pbi` (janela), `editor/tools/MmlTestCli.pb` (harness headless).

**Dialeto MML coberto** (MSX-BASIC — confirmado por pesquisa como distinto do MML genérico
GW-BASIC/Microsoft BASIC, que usa `P` para pausa e `M`/`MF`/`MB`/`MN`/`ML`/`MS` para modo de
articulação; o MSX repropõe `M`/`S` para controlar o **envelope de hardware do PSG**, recurso que o
GW-BASIC genérico não tem):

| Comando | Significado | Faixa | Default |
|---|---|---|---|
| `A`-`G` [`+`/`#`\|`-`] [n] [`.`...] | Nota (sustenido/bemol, duração 1-64, pontos) | | usa `L`/oitava atual |
| `R` [n] [`.`...] | Pausa | | usa `L` atual |
| `N`n | Nota absoluta cromática (8 oitavas × 12 semitons) | 1-96 | — |
| `O`n | Define oitava | 1-8 | 4 |
| `>` / `<` | Sobe/desce 1 oitava | | |
| `L`n | Duração padrão | 1-64 | 4 |
| `T`n | Andamento (BPM) | 32-255 | 120 |
| `V`n | Volume do canal (desliga o modo envelope) | 0-15 | 8 |
| `M`n | Período do envelope (= R11/R12 do PSG) | 1-65535 | 1000 (default de UI) |
| `S`n | Forma do envelope (= R13 do PSG) — liga o modo envelope neste canal, retrigga | 0-15 | — |
| `.` | Ponto de aumento — cada ponto multiplica a duração corrente por 1,5× (multiplicativo, não a
  fórmula aditiva clássica de teoria musical — confirmado como o comportamento real de interpretadores
  MML tipo BASIC) | 0-3 pontos | 0 |

Mapeamento nota→frequência: temperamento igual, `A` na oitava 4 = 440 Hz. Caracteres não reconhecidos
(inclusive espaço) são ignorados pelo parser — nunca bloqueia a prévia sonora por erro de digitação; o
código `PLAY` final gerado nunca passa pelo parser, é sempre o texto literal que o usuário montou.

**Decisão de arquitetura — reaproveitar `PsgSynth.pbi` ao máximo**: o `PLAY` toca no mesmo chip que o
`SOUND` (mesmos 3 osciladores de tom, mesmo único gerador de envelope compartilhado pelos 3 canais —
confirmado por pesquisa). `MmlSynth.pbi` não duplica nenhum DSP: (1) parseia cada string de canal numa
lista de `MmlNoteEvent` (início/duração em amostras, período de tom via `PsgSynth_HzToPeriod()`, volume,
usa-envelope) mais uma lista de comandos `M`/`S` com seu instante absoluto; (2) mescla cronologicamente
os 3 canais — uma lista global de pontos de corte (início/fim de nota nos 3 canais + instante de cada
`S`), montando um `PsgStepData` por intervalo, só retriggando o envelope (`Regs[13]` mudando) nos
instantes reais de `S` e herdando o valor do intervalo anterior nos demais (mesmo truque de diff do
módulo 6); (3) chama `PsgSynth_RenderStep()` (inalterado) com o número exato de amostras de cada
intervalo — sem passar pelo caminho baseado em quadros/`DurationFrames` do módulo 6, evitando
arredondamento e ganhando precisão de tempo musical. Um único `PsgChipState` persiste pela música
inteira. `M` sozinho só atualiza um período pendente; só `S` de fato retrigga (write real em R13, igual
ao hardware).

**Janela**: três colunas lado a lado (canal A/B/C "em paralelo", pedido explícito do usuário), cada uma
com uma **"linha atual"** editável (`StringGadget`, os botões de comando acrescentam texto nela, mas
também é digitável direto — mesmo espírito de escape-hatch dos campos numéricos do módulo 6) — notas
(C-B) e **Pausa (`R`)** numa única fileira, com combo de acidente + campo de duração + campo de pontos
ao lado; N, O (+ `>`/`<`), L, T, V, M, S como campo + um ícone `+` compacto ao lado (**layout
compactado em 2026-07-21, sessão 6**: os botões largos originais "Definir O"/"Definir L"/etc. viraram
esse `+` — o rótulo de uma letra já diz o comando MML —, e campos relacionados N+O/L+T/M+S passaram a
dividir a mesma fileira, reduzindo a altura da janela de ~820px pra ~740px); **Limpar linha**,
**Atualizar** (aplica a linha atual sobre a linha selecionada na lista) e **Inserir nova linha** (fecha
a linha atual como uma entrada na lista abaixo e limpa o buffer — pedido explícito do usuário, "mais ou
menos como o sequenciador" do módulo 6). Lista de linhas por canal (`ListIconGadget`) com Remover
(ícone `-`)/Mover ▲▼. Barra comum: **Tocar** (concatena linhas já commitadas + a linha em edição de
cada canal, toca os 3 juntos via `.wav` temporário) / **Parar**; **Gerar código PLAY** (concatenação
literal — sem separador, cada linha já é um trecho MML válido por si só — omitindo canais vazios à
direita) / **Injetar no cursor**
(`InjectTextAtCursor()`, mesmo helper do módulo 6) / **Copiar**. Barra de projeto no topo, mesmo padrão
exato dos módulos 4/6 (número/tag/Primeiro/Anterior/Próximo/Último/**Novo**/**Registrar** — os dois
últimos como ícone desde a sessão 6, mesmo reaproveitamento de `SpriteEd_CreateNewSpriteIcon`/
`CreateRegisterIcon` descrito no módulo 6).

**Persistência**: tabela `mml_songs` em `ProjectDB.pbi` — três colunas TEXT (`lines_a`/`lines_b`/
`lines_c`), cada uma com as linhas daquele canal unidas por `Chr(10)`. Diferente de `psg_sounds`
(módulo 6), aqui **não** houve necessidade do truque de array 1D achatado: `Lines()` é uma matriz 2D
**fixa** (`Dim Lines.s(2, N-1)`, dimensionada uma vez pelo chamador, nunca redimensionada — `LineCount()`
controla quantas linhas de cada canal estão em uso), então a limitação de `ReDim` (só redimensiona a
última dimensão) documentada no módulo 6 nunca chega a ser um problema aqui. Coberto por round-trip em
`editor/tools/ProjectDBTestCli.pb`.

**Verificado ao vivo** (mensagens do Windows, nunca cursor real — mesma técnica do módulo 12/6): abrir a
janela (153 controles, sem crash), digitar num campo `L` e clicar "Definir L" (bug de mapeamento
encontrado e corrigido — não no app, no próprio script de teste: peguei o handle do campo `O` por
engano), clicar as 7 notas, "Inserir nova linha", "Gerar código PLAY" produzindo exatamente
`PLAY "L4CDEFGABL8C"` pra duas linhas commitadas, "Tocar" sem travar o processo, "Fechar" devolvendo o
editor principal intacto.

### 9. Extensão NestorBASIC (nbasic)
- Todas as funções do NestorMan/InterNestor Suite/InterNestor Lite passam por um único `USR` com array
  de parâmetros inteiros `P` (e array de strings próprio para arquivo/string) — padrão "uma função,
  várias posições de array", compatível com Turbo-BASIC.
- Sintaxe de definição no pré-processador:
  ```
  #nbasic_func LOAD_SECTOR = 23      ' número da função NestorBASIC
  #nbasic_param DRIVE = P(1)
  #nbasic_param SECTOR = P(2)
  #nbasic_param BUFFER_SEG = P(3)
  ```
  Uso: `NB_CALL LOAD_SECTOR` → expande para `P(1)=...:P(2)=...:P(3)=...:A=USR(0)`.
- Highlighting: estilo Scintilla separado para chamadas NestorBASIC (distinto de BASIC nativo), para
  deixar visível a dependência de `nbasic.bin`.
- **Atenção**: `DIM P(15)` / `DIM F$(...)` tem regras de posição (ex.: redefinir array `F` dentro de
  bloco turbo deve ser feito na primeira linha do bloco) — o pré-processador precisa conhecer essas
  regras, não pode ser substituição de texto ingênua.
- Trabalho real: mapear com precisão a lista de funções/parâmetros do NestorBASIC (não é desafio de
  algoritmo, é levantamento de dados).

### 10. msxbas2rom (back-end opcional de ROM)
- CLI open source, compilador experimental multiplataforma inspirado no Basic-kun, compilação/geração
  de código do zero.
- Pipeline: editores geram blocos → Basic Dignified resolve labels/numeração/includes → gerar `.bas` no
  dialeto msxbas2rom (superset com comandos turbo/extras, ex. `SET/GET SPRITE COLOR/PATTERN`, suporte a
  MSX Tile Forge) → chamar `msxbas2rom` via subprocess (única exceção à regra "sem subprocess") → ROM.
- **Atenção**: conferir lista de comandos suportados/incompatíveis do msxbas2rom antes de mapear 1:1 os
  editores gráficos para esse dialeto. Precedente: Basic-kun/Turbo original não compilava `DRAW`/`PLAY`
  dentro de bloco turbo. Módulos DRAW e MML/PLAY podem precisar gerar saída alternativa (rotina Z80
  equivalente) quando o alvo for ROM.
- Prioridade: **baixa** — usuário confirmou "só se valer a pena", manter como back-end opcional
  desacoplado, não bloquear o resto do projeto por causa dele.

### 11. Saída tokenizada
- Formato `.bas` tokenizado documentado (mesmo do `SAVE` sem `,A`): por linha — ponteiro para próxima
  linha, número da linha (2 bytes), bytes tokenizados, terminador `0x00`; fim de programa marcado com
  `0x00 0x00 0x00`. Primeiro byte do arquivo `0xFF` = "tokenizado".
- Cada palavra-chave (`PRINT`, `FOR`, `GOTO`...) → 1 byte (maioria) ou 2 bytes com prefixo `0xFF`
  (tokens estendidos, funções/comandos menos comuns).
- **Referência exata para o port nativo**: `badig/msx/msxbatoken/msxbatoken.py` (script standalone,
  "MSX Basic Tokenizer", parte do Basic Dignified Suite mas usável isolado — doc irmã em
  `badig/documentation/BATOKEN.md`). Contém:
  - `TOKENS` (linha ~50-78): lista completa `(comando, byte_hex)` — comandos/operadores de 1 byte e
    funções estendidas com prefixo `ff` (ex. `('PEEK', 'ff97')`), incluindo casos especiais como `'`
    (REM curto) → `3a8fe6` e `ELSE` → `3aa1`.
    `JUMPS` (linha 80): lista de comandos que recebem endereço de linha resolvido (`GOTO`, `GOSUB`,
    `THEN`, `RESTORE`, etc.) — token `0e` + endereço 2 bytes little-endian.
  - Classe `Tokenize.tok()` (linha ~420-704): algoritmo linha a linha — número de linha, busca de
    token mais longo primeiro (`TOKENS` ordenado implicitamente por match), tratamento especial de
    literais após `DATA`/`REM`/`'`/`CALL`/`_`, parsing numérico (inteiro curto 0-9 `+17`, inteiro
    0x0f+byte, inteiro 0x1c+2bytes, single-precision `1d`, double-precision `1f`, hex `&H`→`0c`,
    octal `&O`→`0b`, binário `&B`→`2642`+ASCII), strings entre aspas, nomes de variável.
  - `BASE = 0x8001` — endereço inicial padrão de carga do MSX-BASIC.
  - Discrepâncias conhecidas documentadas no próprio arquivo (seção "Notes" do `.py` e do `.md`):
    `&B` simplificado, espaços finais de linha removidos, números que estouram em instruções de
    salto geram erro em vez de dividir como a MSX faz, erros de sintaxe geram resultado diferente do
    real MSX.
  - **Abordagem de port**: reescrever a lógica em PureBasic usando esse arquivo como especificação de
    comportamento byte-a-byte (não importar/chamar o `.py`). Preservar as mesmas discrepâncias
    conhecidas documentadas (não são bugs a corrigir, são decisões já tomadas no projeto original).

- **Status (2026-07-13): implementado.** `editor/MsxTokenizer.pbi` — port completo e nativo (sem
  Python) da tabela `TOKENS`/`JUMPS` e do algoritmo `Tokenize.tok()`, incluindo a parte mais
  arriscada (codificação BCD de números single/double precision e notação científica). Integrado ao
  editor via novo item de menu **"Salvar como tokenizado nativo (.bmx)..."** em
  `editor/BadigEditor.pb` (`SaveAsTokenizedNative()`), que opera sobre o texto ASCII clássico já
  aberto na aba atual (não sobre Dignified — esse pré-processador ainda não foi portado, ver módulo
  3) e salva o binário via `SaveFileRequester`.
  - **Verificado byte a byte** contra o `msxbatoken.py` original (usado só como oráculo de teste
    nesta sessão de desenvolvimento, via um CLI de teste `tokcli.pb` fora do projeto) em: inteiros
    curtos/médios/longos, hex/octal/binário, single precision (`3.1415926536`, `1.5E+10`), double
    precision (`123456789.123456`), strings, `DATA` com tipos mistos, `ON...GOTO` com posições
    vazias (`,,`), `FOR/STEP`, `IF/THEN/ELSE`, `GOSUB/RETURN`, `REM`. Todos os casos testados
    bateram **idênticos** byte a byte. Também confere corretamente o erro de linha fora de ordem.
  - **Ainda não testado**: casos extremos de arredondamento em ponto flutuante (dígito de
    desempate/carry em `parse_sgn_dbl`), `&B` com múltiplos dígitos grandes, `AS` com número de
    arquivo de 2 dígitos (o próprio código Python original tem uma inconsistência nesse caso — ver
    comentário em `Tok_TokenizeLineBody`, foi portado com uma interpretação razoável, não uma
    tradução literal do bug).
  - O item de menu antigo "Gerar tokenizado MSX (.bmx)..." (que chama `python badig.py` via
    subprocess) continua existindo para o fluxo Dignified→tokenizado, que ainda depende do
    pré-processador Python até o módulo 3 ser portado. Os dois convivem por enquanto.

### 12. Controle do openMSX via socket
- Protocolo: comandos XML no canal (pipe/socket via `-control stdio`), `<command>texto</command>` →
  `<reply result="ok/nok">`. Confirmado por leitura direta de `emulator_interface.py` (ver
  `docs/reference/badig-emulator-tokenizer-interfaces.md` para a sequência completa de comandos).
- **Abordagem já implementada no projeto original (usar como primeira opção, é mais simples que o
  plano inicial deste documento)**:
  - Enviar programa: `type_via_keybuf` simulando digitação de `load"ARQUIVO` (nome truncado 8+3)
    após montar a pasta como disco virtual (`-diska`), com throttle desligado durante a carga e
    religado via um `watchpoint` de memória (`0xFFFE`) + `poke -2,1` feito pelo próprio programa
    carregado — truque de performance, não de detecção de erro.
  - Detectar erro e voltar à linha certa: **não** usa hook de erro via poke nem breakpoint de
    debug/memória. Usa `-script openmsx_output.tcl` (ecoa a tela do MSX pro stdout do processo) +
    convenção de código: o programa BASIC do usuário deve fazer seu `ON ERROR` imprimir `CHR$(7)`
    (BEEP) seguido do número da linha. O lado da IDE lê o stdout, procura pela marca `\x07`, extrai
    o número de linha do fim da string e traduz de volta para a linha do `.dmx` original via o mapa
    linha-clássica→linha-Dignified gerado no Pass 4 do pré-processador.
  - **Limitação conhecida**: esse monitoramento só funciona em Mac/Linux na implementação Python
    original (`if CURRENT_SYSTEM == WINDOWS: return`, sem suporte). Como a IDE aqui é primariamente
    Windows, isso é um risco a investigar cedo — não se sabe ainda se é limitação do openMSX/pipes
    no Windows ou só de como o Python lia o stdout. `RunProgram`/`ReadProgramString` do PureBasic
    (já usado em `BadigEditor.pb` para chamar Python) é não-bloqueante o suficiente para testar.
- **Abordagem alternativa mais poderosa, não implementada em lugar nenhum do projeto original**
  (plano original desta especificação, ver `transcricao.md` seção 10): hook de erro instalado via
  `POKE` + breakpoint de debug/callback Tcl lendo memória diretamente. Mais robusto (funcionaria em
  qualquer OS, não depende de convenção de código do usuário) mas mais trabalhoso — guardar como
  evolução futura caso a abordagem simples não funcione bem no Windows.
- Enviar input em runtime: mesma mecânica de `keymatrixup`/`keymatrixdown` usada para digitar
  comandos (não detalhado a fundo na leitura desta sessão, mas é o mesmo tipo de comando XML).

**Status (2026-07-16): fatia inicial implementada** — bem mais simples que as duas abordagens acima
(nenhuma das duas foi usada): `RunOnOpenMSX()` (`editor/BadigEditor.pb`), acionada pelo menu "Dignified
→ tokenizado nativo..." quando `BadigCfg\EmRun` está marcado (aba "Emulador" de `Configurar → Basic
Dignified...`). Fluxo atual:
1. Monta um disquete `.dsk` (`disk/run.dsk`, pasta irmã de `editor/` — mesma convenção de
   `BadigCfg_DefaultInstallDir()`/`..\badig`) contendo o `.dmx`/`.amx`/`.bmx` recém-gerados **mais**
   um `AUTOEXEC.BAS` sintetizado (`10 RUN "BASENAME.BMX"`) para autorun no boot do MSX-DOS/BASIC.
   Rotinas de disco (FAT12, formato/leitura/escrita de `.dsk`) são vendorizadas de
   `msxDiskUtil/MSXDisk.pbi` (utilitário PureBasic próprio do usuário, não relacionado ao Basic
   Dignified) para `editor/MSXDisk.pbi`, incluído via `XIncludeFile` e chamado com sintaxe qualificada
   de módulo (`MSXDisk::CreateDisk()`/`AddFile()`/etc.) — **compilado direto no executável do editor,
   sem processo externo** para montar o disco (única exceção: o próprio `openMSX` é lançado via
   `RunProgram`, já que rodar o programa MSX de outro jeito não faz sentido).
2. Abre o `openMSX` configurado (`BadigCfg\EmulatorPath`) com `-machine <BadigCfg\EmMachine>` (se
   preenchido), `-ext<slot> <nome>` (se preenchido — o campo aceita `Nome:slot`, ex. `Nome:exta`; o
   slot vira parte do NOME da flag, não um argumento separado, replicando a regra real do openMSX) e
   `-diska <disco>`.
3. Os campos `Maquina`/`Extensão` (aba "Emulador") ganharam botão "..." (`BadigCfg_PickXmlName()`,
   `editor/BadigSettings.pbi`) que lista os arquivos `.xml` de `share/machines/`/`share/extensions/`
   a partir do diretório do executável do openMSX configurado (nome sem a extensão `.xml`), numa
   janela picker simples; ao trocar a extensão, um `:slot` já digitado é preservado.

**CLI de disco embutida (2026-07-16)**: além de montar o disco internamente para "rodar no openMSX",
o `BadigEditor.exe` agora expõe `MSXDisk.pbi` também como utilitário de linha de comando standalone,
mesma sintaxe/comandos do `msxdisk.exe` original (`msxDiskUtil/msxdisk.pb`) do usuário:
`BadigEditor.exe --diskmanipulator <create|list|add|extract|delete> <disco.dsk> [argumentos...]`
(`RunDiskManipulatorCli()`, `editor/BadigEditor.pb`). Detectado no início do `Programa principal`,
antes de qualquer janela abrir — roda a CLI e sai (`End`), sem custo para o caminho normal do editor
gráfico. Para a CLI herdar o console do terminal que chamou (em vez de abrir uma janela de console nova
e desconectada), o `.exe` passou a ser compilado com `/CONSOLE` (`build.ps1`); como isso faz o Windows
anexar um console a *qualquer* execução, o caminho normal (GUI) chama `FreeConsole_()` logo em seguida
para fechar essa janela indesejada antes de `InitKeywordMaps()`/abrir a janela principal. Testado ao
vivo via terminal (não precisa de GUI automation): os 8 comandos (`create`/`add` com curinga e
arquivo único/`list` simples e `-l` detalhado/`extract` com `-d` e máscara/`delete`/ajuda sem
argumentos) rodados ponta a ponta contra um disco novo, e o editor gráfico normal (sem argumentos)
confirmado abrindo sem nenhuma janela de console residual.

**Gerenciador grafico de disco — menu "Criar -> Disco..." (2026-07-16)**: `editor/DiskManagerGui.pbi`
(`DiskMgr_OpenWindow()`), novo menu de topo "Criar" logo apos "Arquivo" (`#Menu_CreateDisk`, ID de menu
10). Janela com dois paineis estilo Norton/Total Commander: esquerda = sistema de arquivos local
(comeca no diretorio corrente do `BadigEditor.exe`, navegacao por duplo-clique em pastas/".."), direita
= conteudo do disco MSX aberto/em criacao. Botoes centrais "Adicionar >>"/"<< Extrair" transferem os
arquivos selecionados (suporta selecao multipla) — **sempre por copia nos dois sentidos** (decisao
confirmada com o usuario; nunca apaga o arquivo de origem). Mais dois botoes centrais, adicionados a
pedido do usuario logo depois (2026-07-16): **"Remover local"** (exclui de verdade os arquivos
selecionados no painel esquerdo, do sistema de arquivos do Windows — sempre habilitado, nao depende de
disco aberto) e **"Remover disco"** (exclui os arquivos selecionados de dentro do disco via
`MSXDisk::DeleteMSXFile`, desabilitado enquanto nenhum disco esta carregado). Ambos pedem confirmacao
(`MessageRequester` Sim/Nao) antes de excluir, por serem destrutivos. Campo superior com botao "..."
(`OpenFileRequester`, filtro `*.dsk`) escolhe um `.dsk` existente para abrir ou digita um caminho novo
para criar.

**Modelo de rascunho (staging), tambem confirmado com o usuario**: ao escolher/criar o disco, todas as
operacoes acontecem numa **copia temporaria** (`GetTemporaryDirectory()`, arquivo unico por sessao) via
`MSXDisk::CreateDisk`/`OpenDisk`/`AddFile`/`ExtractFile` — o arquivo `.dsk` escolhido no campo superior
so e gravado de verdade nos botoes:
- **Salvar**: fecha o disco temporario, copia para o caminho escolhido, fecha a janela.
- **Salvar como...**: igual, mas pergunta um caminho novo (`SaveFileRequester`) e passa a ser esse o
  destino.
- **Duplicar...**: copia o rascunho atual para um caminho extra escolhido pelo usuario **sem** fechar a
  sessao (reabre o mesmo temporario e continua trabalhando no disco original).
- **Excluir disco...**: com confirmacao, apaga o arquivo `.dsk` de destino (se existir) e o rascunho,
  reseta a janela para o estado inicial (sem fechar).
- **Cancelar** (ou fechar a janela): descarta o rascunho sem tocar no arquivo de destino — nao ha o que
  desfazer porque nada foi escrito nele ainda.

Verificado ao vivo (via automação de janela por `WM_COMMAND`/`BM_CLICK` direto nos HWNDs, sem mover o
cursor real — ver nota de cuidado abaixo): layout da janela, listagem/ordenacao do painel esquerdo
(pastas antes de arquivos, alfabetico dentro do grupo, ".." primeiro), habilitação/desabilitação dos
botões de sessão conforme o estado, o fluxo completo de "..." → escolher caminho novo → disco de
rascunho criado e populado, e o **Cancelar** descartando de fato o arquivo temporário sem tocar no
destino (confirmado inspecionando a pasta temp do Windows antes/depois). **Não verificado ao vivo**:
Adicionar/Extrair/Salvar/Salvar como/Duplicar/Excluir disco em si — essas chamadas reusam literalmente
as mesmas funções do `MSXDisk` já validadas ponta a ponta pela CLI `--diskmanipulator` (module acima),
envolvidas por um laço simples sobre os itens selecionados (`GetGadgetItemState`/`#PB_ListIcon_Selected`),
então o risco residual é baixo, mas fica registrado como lacuna de teste ao vivo. Motivo de ter parado a
automação nesse ponto: **tentar selecionar uma linha do `ListIconGadget` via mensagem nativa
(`LVM_SETITEMSTATE`) travou o processo do editor** — essa mensagem espera um ponteiro para uma struct
`LVITEM` valida no espaço de memoria do processo ALVO, e um ponteiro alocado no processo automatizador
não é válido lá (mesma classe de problema já documentada em [[gui_automation_focus_caution]] para
`SCI_SETTEXT`); e **`SetCursorPos`/`mouse_event` (clique real do mouse) não deve ser usado neste
ambiente** porque a maquina é usada interativamente pelo proprio usuario em paralelo (ex.: Steam em
primeiro plano no meio do teste) — mover o cursor de verdade arrisca clicar em algo do usuário. Prática
segura confirmada nesta sessão: `WM_COMMAND` (menu) e `BM_CLICK` (botão) enviados direto ao HWND
funcionam bem sem mover o cursor nem precisar de foco; qualquer coisa que exija um ponteiro
cross-process (`LVM_SETITEMSTATE`, `LVM_GETITEMRECT`, `SCI_SETTEXT`) ou input real de mouse/teclado deve
ser evitada — preferir testar essa lógica por trás das cortinas (harness CLI) quando possível.
confirmado abrindo sem nenhuma janela de console residual.

**Não implementado ainda** (a fatia "difícil" do módulo): controle via socket/protocolo XML em tempo
real, envio de input simulado durante a execução, e detecção de erro em runtime com retorno à linha
certa no editor — nenhuma das duas abordagens documentadas acima (script Tcl+convenção `CHR$(7)`, ou
hook de erro via `POKE`+breakpoint) foi implementada. O fluxo atual é "gerar disco e abrir o openMSX
já rodando", sem nenhuma comunicação de volta da emulação para a IDE.

### 13. Sistema de projeto (arquivo `.msxproject`, SQLite) — implementado (2026-07-18)

- **Arquivo**: `editor/ProjectDB.pbi`, módulo `ProjectDB` (`DeclareModule`/`Module`, mesmo padrão de
  `MSXDisk.pbi` — chamadas qualificadas `ProjectDB::...`). `UseSQLiteDatabase()` — driver estático
  (`sqlite3.lib` do PureBasic), sem DLL extra pra distribuir junto do `.exe`.
- **Um projeto = um arquivo `.msxproject`** (SQLite puro). Schema atual (2026-07-21): `project_info`
  (chave/valor), `documents` (cópia do conteúdo de cada aba de texto já salva), `sprites`, `alphabets`
  (módulo 4), `psg_sounds` (módulo 6) e `mml_songs` (módulo 8) — cada um com sua própria chave primária
  numérica (`sprite_number`/`alphabet_number`/`sound_number`/`song_number`), `tag` e `updated_at`; os
  demais tipos de conteúdo do projeto (Basic/Assembly/Telas/listagens LM permanecem só como `documents`,
  sem tabela dedicada) ganham tabela própria só quando tiverem editor implementado — decisão deliberada
  de não desenhar schema para funcionalidade que ainda não existe.
- **Serialização da grade do sprite**: em vez de usar a API de bind de BLOB do driver SQLite do
  PureBasic (não exercitada em nenhum exemplo local, risco desnecessário), `pixel_data` é uma coluna
  `TEXT` com um dígito hexadecimal por bloco (0–F, cobre os 16 índices de cor), `grid_size*grid_size`
  caracteres, linha a linha. `SaveSprite`/`FetchSprite` viraram `StoreSprite`/`FetchSprite` (o driver
  Sprite nativo do PureBasic reserva os nomes `SaveSprite`/`LoadSprite` — colisão só percebida ao
  compilar: "Invalid name: same as a command (from library 'Sprite')"). Texto do usuário (tag) sempre
  passa por escape de aspas simples antes de entrar numa string SQL montada por concatenação.
- **Projeto implícito "noname"**: `EnsureOpen()` cria (se ainda não existe um banco aberto)
  `GetTemporaryDirectory() + "noname.msxproject"` e roda o schema — chamado explicitamente no início
  do "Programa principal" de `BadigEditor.pb` quando `CountProgramParameters() = 0`, então o projeto já
  existe antes de qualquer janela abrir (não é mais lazy, criado só na primeira gravação).
- **Arquivo → Novo projeto...** / **Arquivo → Abrir projeto...** — `SaveFileRequester`/
  `OpenFileRequester` com filtro `.msxproject` (dialogo único, mesmo padrão já usado no gerenciador de
  disco, em vez de dois passos separados pasta+nome). Os dois passam por `OfferSaveProject()` antes:
  se o projeto atual ainda é o temporário implícito e já tem conteúdo, pergunta se quer salvar antes de
  trocar (cancelar o `SaveFileRequester` cancela a ação toda, sem descartar nada silenciosamente).
- **Ao sair**: mesmo `OfferSaveProject()` reaproveitado no fluxo de saída de `BadigEditor.pb` (depois do
  aviso já existente sobre abas de texto não salvas) — só pergunta se `HasUnsavedContent()` (projeto
  ainda temporário E com pelo menos um registro nas tabelas que só existem dentro do banco — sprites,
  alphabets, psg_sounds, mml_songs; `documents` fica de fora do critério porque é cópia de um arquivo
  que já existe em disco por conta própria, perder a cópia do banco temporário não perde trabalho de
  verdade); `Close()` sempre roda antes do `End` final e apaga o arquivo temporário se ele nunca foi
  promovido a um local permanente. **Bug corrigido (2026-07-21, sessão de ajuste do editor de música)**:
  `HasUnsavedContent()` originalmente só contava `sprites` — um projeto só com alfabetos, sons ou
  músicas nunca disparava o aviso de salvar, risco real de perder esse conteúdo ao fechar sem salvar
  explicitamente. Corrigido somando `COUNT(*)` das 4 tabelas numa única query.
- **Arquivo → Salvar projeto / Salvar projeto como...** (2026-07-19) — `SaveProject(SaveAsFlag.b =
  #False)`: se o projeto já tem caminho permanente e não é "salvar como", não faz nada (o `ProjectDB`
  grava cada `StoreSprite()` na hora via SQLite, nunca fica "sujo" em memória como uma aba de texto);
  senão pede um caminho (`SaveFileRequester`, sugerindo o caminho atual quando já permanente, para
  facilitar salvar uma cópia com outro nome) e promove/copia via `ProjectDB::SaveAs()`. `OfferSaveProject()`
  foi refatorado para chamar `SaveProject(#True)` em vez de duplicar esse bloco. **Extensão automática**:
  `EnsureExtension(Path.s, Ext.s)` (`BadigEditor.pb`) acrescenta `.msxproject` quando o `SaveFileRequester`
  volta um caminho sem nenhuma extensão (usuário só digitou um nome) — aplicado tanto em "Novo projeto..."
  quanto em "Salvar projeto como..."; se o usuário digitar outra extensão, respeita a escolha.
- **Cópia do conteúdo das abas de texto dentro do projeto** (2026-07-19) — nova tabela `documents`
  (`path` chave primária, `mode`, `content`, `updated_at`) e `ProjectDB::StoreDocument()`/`FetchDocument()`/
  `LastDocumentContent()`/`LastDocumentMode()`, mesmo padrão Store/Fetch dos sprites. `SaveDocument()` em
  `BadigEditor.pb` chama `StoreDocument()` logo depois de escrever o arquivo `.dmx`/`.amx`/`.asm` em disco
  — o projeto passa a ter uma cópia sempre atualizada do texto-fonte, além do arquivo físico já salvo.
  Só sincroniza abas que já têm caminho em disco (`Path <> ""`); abas "nonameN" ainda não salvas ficam de
  fora, por enquanto não há como reabri-las a partir do projeto sem passar por esse primeiro save.
- **Diretório de trabalho** (2026-07-19) — chave `working_dir` em `project_info`
  (`ProjectDB::SetWorkingDir()`/`GetWorkingDir()`), inicializada com `GetCurrentDirectory()` quando o
  projeto é criado (implícito "noname" ou "Novo projeto...") e atualizada para a pasta do arquivo (via
  `GetPathPart()`) a cada `SaveDocument()` bem-sucedido — reflete "a pasta que está sendo trabalhada", ou
  o diretório corrente se nenhum arquivo ainda foi salvo explicitamente.
- **Harness de teste**: `editor/tools/ProjectDBTestCli.pb` (mesmo padrão `/CONSOLE` de
  `MSXDiskTestCli.pb`) — round-trip completo sem GUI: cria projeto temporário, registra sprites de
  tamanhos/modos diferentes, lista, recarrega e compara byte a byte, sobrescreve sem duplicar,
  testa `working_dir` e `documents` (incluindo conteúdo com aspas simples, pra validar o escape SQL),
  `SaveAs` para um arquivo permanente, `OpenExisting` reabrindo do zero (confirma que sprites, documents
  e working_dir sobrevivem aos dois), falha graciosa com arquivo inexistente. Foi o principal jeito de
  validar a lógica de dados nesta sessão — automação de clique
  no canvas do editor de sprites se mostrou não confiável neste ambiente (mesmo tipo de fragilidade já
  observada em telas anteriores, ver seção 12 acima sobre `LVM_SETITEMSTATE`/`SCI_SETTEXT`).

## Lacunas conhecidas (a preencher em conversas futuras)

- ~~Seção 4 (editor sprite/char): detalhe da conversa original não foi recuperado.~~ — **parcialmente
  resolvida (2026-07-18)**: a parte de sprite foi implementada com spec própria (não precisou do
  detalhe original recuperado, ver seção 4 acima); char/tile continua em aberto.
- **Editor de alfabetos — suporte a mais formatos/modos além do que já existe** (2026-07-21, em
  aberto): ~~(1) importar fontes `.FNT` do Aquarela~~ — **resolvida (2026-07-23)**: editor dedicado
  próprio (`editor/AquarelaCharsetEditorGui.pbi`, não uma importação para dentro do formato Graphos
  III), ver seção 4b. Segue em aberto: (2) suporte a **SCREEN 2** além do SCREEN 1 atual — hoje os
  dois editores de charset (Graphos III e Aquarela) só modelam a Pattern Generator Table de SCREEN 1
  (256×8 bytes, sem cor); SCREEN 2 precisa de 3 bancos dessa tabela (6144 bytes) mais uma Color Table
  do mesmo tamanho (cor por linha de pixel, não por caractere inteiro) — mudança de modelo de dados
  maior que só formato de arquivo, ver detalhe em `docs/reference/aquarela.md`; (3) validação da
  âncora de posição (posição 0 = 'A') na leitura de `.FNT` do Aquarela — documentada como necessária
  em `docs/reference/aquarela.md` mas ainda não implementada em `AqEd_LoadFnt`.
- ~~Seção 8 (editor MML/`PLAY`): detalhe da conversa original não foi recuperado.~~ — **resolvida
  (2026-07-21)**: implementada com spec própria, não precisou do detalhe original recuperado (dialeto
  MML confirmado por pesquisa direta, não pela conversa perdida) — ver seção 8 acima.
- Mapeamento completo de funções/parâmetros NestorBASIC (módulo 9).
- Lista de comandos suportados/incompatíveis do msxbas2rom (módulo 10), antes de decidir se vale a pena.
- `badig/msx/openmsx_output.tcl` ainda não foi lido (script que faz a tela do openMSX ecoar para o
  stdout — necessário para portar o módulo 12 corretamente).
- Investigar se a leitura de stdout do openMSX (`-control stdio`) funciona de forma não-bloqueante
  no Windows a partir de PureBasic — a implementação Python original **não suporta** monitoramento
  de erro em runtime no Windows (só Mac/Linux); não se sabe se é limitação do openMSX/pipes ou só
  de como o Python original lidava com isso.
- ~~Tabela completa de tokens do MSX-BASIC~~ — **resolvida**: está em
  `badig/msx/msxbatoken/msxbatoken.py` (ver módulo 11 acima).
- ~~Mapear pré-processador Dignified~~ — **resolvida**: arquitetura completa (Lexer, Parser 5 passes,
  vocabulário) documentada em `docs/reference/dignified-core.md` e `docs/reference/badig-msx-module.md`.
- ~~Protocolo real de controle do openMSX~~ — **resolvida**: sequência de comandos e mecanismo de
  detecção de erro documentados em `docs/reference/badig-emulator-tokenizer-interfaces.md` e no
  módulo 12 acima (revelou abordagem mais simples que o plano original).

## Próximos passos em aberto

**Estado ao fim de 2026-07-21 (sessão 6)**: dois ajustes pedidos depois de ver a janela do editor de
música funcionando (sessão 5 abaixo) — nenhum deles muda escopo, só polimento de UI e um bugfix real
encontrado no processo.
- **Disposição dos botões do editor de música compactada**: notas + pausa (`R`) passaram a dividir uma
  única fileira (em vez de "Pausa (R)" numa linha à parte); os antigos botões largos "Definir O"/
  "Definir L"/"Definir T"/"Definir V"/"Definir M"/"Definir S"/"Inserir N" viraram um ícone `+` compacto
  ao lado de cada campo — o rótulo de uma letra (N/O/L/T/V/M/S) já diz o comando MML, o botão só
  confirma "acrescenta na linha atual"; campos relacionados (N+O, L+T, M+S) passaram a dividir a mesma
  fileira. A janela encolheu de ~820px pra ~740px de altura (~430px de `ColH` por coluna, contra os
  520px originais). Verificado ao vivo (mensagens do Windows, nunca cursor real): sem sobreposição de
  controles, fluxo nota+pausa (`C`+`R` → `"CR"`) continua funcionando.
- **Ícones "Novo"/"Registrar" uniformizados**: trocados de `ButtonGadget` de texto pra
  `ButtonImageGadget`, reaproveitando **os mesmos ícones já desenhados** no editor de sprites
  (`SpriteEd_CreateNewSpriteIcon`/`SpriteEd_CreateRegisterIcon` em `SpriteEditorGui.pbi`, chamados
  diretamente de `PsgEditorGui.pbi`/`MmlEditorGui.pbi` — nenhum desenho novo, `SpriteEditorGui.pbi` já
  é incluído antes dos dois no `BadigEditor.pb`). Aplicado nos **dois** editores (som e música): o
  pedido original era só sobre música, mas deixar só o editor de som com texto contrariaria o próprio
  objetivo de "ficar uniforme com o resto dos programas". Verificado ao vivo em ambas as janelas
  (clique no ícone "Novo" dispara o evento certo, `GetWindowText` confirma que os botões realmente não
  têm mais texto).
- **Bug real encontrado nessa checagem**: `HasUnsavedContent()` (módulo 13) só contava a tabela
  `sprites` — um projeto só com alfabetos, sons (PSG) ou músicas (MML) nunca disparava o aviso de
  "salvar antes de sair", risco real de perda silenciosa desse conteúdo (que só existe dentro do banco
  do projeto, sem nenhum arquivo de backup em disco). Corrigido somando `COUNT(*)` de `sprites` +
  `alphabets` + `psg_sounds` + `mml_songs` numa única query — ver módulo 13 acima para o detalhe.
  Coberto pela suíte existente de `ProjectDBTestCli.pb` (o teste já cobre o caso "com conteúdo" desde
  que as 4 tabelas têm registro nesse ponto do teste; não foi adicionado um teste isolado por tipo —
  ver nota de baixo risco abaixo).
- Documentação atualizada na mesma sessão: `README.md` (bullet do editor de música com a imagem
  `images/msxbasica-07.png` — a `06` já era do editor de som —, novo item de changelog),
  `docs/MANUAL.md` (nova seção "Editor de música (MML/PLAY)", corrigida também uma duplicata órfã de
  texto que tinha sobrado no fim do arquivo de uma edição anterior), este arquivo (módulo 13 atualizado
  com o schema completo e o bugfix, esta entrada de log). Versão embutida no executável atualizada para
  `5.9.5`.
- **Risco de baixa prioridade aceito**: a cobertura de `HasUnsavedContent()` em `ProjectDBTestCli.pb`
  não isola cada uma das 4 tabelas (testa só o agregado, já que o teste registra sprite+alfabeto+som+
  música em sequência antes de qualquer verificação) — um regresso que quebrasse a contagem de só uma
  tabela específica não seria pego. Melhoria futura de baixo risco, não bloqueante.

**Estado ao fim de 2026-07-21 (sessão 5)**: novo **editor de música MML** (módulo 8, ver seção 8 acima)
— menu **Criar → Música (PLAY)...**, `editor/MmlSynth.pbi` (motor, sem GUI) + `editor/MmlEditorGui.pbi`
(janela) + `editor/tools/MmlTestCli.pb` (harness headless), mesma arquitetura triádica dos módulos
6/12. Decisão central: reaproveitar o `PsgSynth.pbi` do módulo 6 quase por completo (mesmo chip, mesmo
gerador de envelope compartilhado pelos 3 canais) — só um parser MML por canal e uma mesclagem
cronológica dos 3 canais independentes num único fluxo de `PsgStepData`, chamando `PsgSynth_RenderStep()`
sem alterar nenhuma linha de DSP. Dialeto MML confirmado por pesquisa direta (distinto do MML genérico
GW-BASIC/Microsoft BASIC — o MSX repropõe `M`/`S` para o envelope de hardware do PSG). UI com os 3
canais em paralelo (pedido explícito do usuário), cada um com uma "linha atual" editável que os botões
de comando vão preenchendo, "Inserir nova linha" fecha a linha como uma entrada na lista do canal (mesmo
espírito "sequenciador" do módulo 6). Integrado ao sistema de projeto (tabela `mml_songs`, linhas de
cada canal unidas por `Chr(10)` em 3 colunas TEXT — diferente de `psg_sounds`, aqui não houve
necessidade do truque de array 1D achatado porque `Lines()` é uma matriz 2D **fixa**, nunca
redimensionada), com round-trip coberto em `editor/tools/ProjectDBTestCli.pb`. Validado por
`editor/tools/MmlTestCli.pb` (frequência de nota bate com o esperado, duração/pontos batem com a
matemática, `N` bate com `O`+nota equivalente, `S`/`V` ligam/desligam o modo envelope corretamente) e ao
vivo via mensagens do Windows (abrir a janela, montar `L4CDEFGAB` clicando nos botões, "Inserir nova
linha", "Gerar código PLAY" produzindo exatamente o esperado, "Tocar" sem travar). Preencheu o módulo 8,
que estava marcado como "Gap" (nenhuma especificação registrada) — ver lacuna resolvida acima.

**Estado ao fim de 2026-07-21 (sessão 4)**: novo **editor de som PSG** (módulo 6, ver seção 6 acima) —
menu **Criar → Som (PSG)...**, `editor/PsgSynth.pbi` (motor, sem GUI) + `editor/PsgEditorGui.pbi`
(janela) + `editor/tools/PsgTestCli.pb` (harness headless), mesma arquitetura triádica de
`MSXDisk.pbi`/`DiskManagerGui.pbi`/`--diskmanipulator`. Escopo fechado com o usuário antes de
implementar: um "som" é um mini-sequenciador de passos (não um tracker multi-canal, que continua sendo
o módulo 7), e o playback é "sob demanda" (renderiza e toca via `.wav` temporário, sem streaming ao
vivo). Integrado ao sistema de projeto (tabela `psg_sounds`, mesmo padrão Store/Fetch/List de
sprites/alfabetos), com round-trip coberto em `editor/tools/ProjectDBTestCli.pb`.

Dois bugs reais encontrados e corrigidos durante a sessão, ambos documentados como memória de projeto
para não reintroduzir:
- **Corrupção de heap em `ProjectDB::FetchSound`**: `ReDim` no PureBasic só redimensiona a **última**
  dimensão de um array multi-dimensional — a primeira tentativa guardava os registradores como matriz
  2D (passos × 14) e tentava `ReDim` o número de passos (primeira dimensão), corrompendo a heap
  silenciosamente até um crash `STATUS_HEAP_CORRUPTION` bem depois do ponto real do erro. Corrigido
  serializando `Regs` como array **1D achatado** (`Regs(i*14+r)`), a única forma segura de devolver
  um número de passos variável por um parâmetro `Array` de saída.
- **`SpinGadget` com texto que nunca atualizava visualmente**: reportado pelo usuário como "os spin
  buttons não funcionam" e "sem som". Diagnosticado ao vivo enviando a mensagem nativa `UDM_SETPOS32`
  direto no controle `msctls_updown32` (via `PostMessage`/`SendMessage` num HWND específico, mesma
  técnica de automação segura já documentada no módulo 12) — o valor interno mudava (confirmado por
  `UDM_GETPOS32`) mas o texto do "buddy" `Edit` nunca refletia a mudança, mesmo bypassando o PureBasic
  inteiramente. Como o painel sempre começa com Volume=0 e mixer todo desligado (silêncio proposital,
  ver `PsgEd_ResetPanel`), a combinação "campo parece travado" + "usuário não confia que ajustou o
  volume" explicava as duas queixas de uma vez. Corrigido substituindo os 4 campos afetados (Volume,
  período de ruído, período de envelope, duração) de `SpinGadget` por `StringGadget` digitável — mais
  simples e comprovadamente confiável neste ambiente. Reproduzido/confirmado corrigido com um teste
  ponta a ponta via mensagens do Windows: digitar frequência/volume, marcar "Tom", adicionar passo,
  gerar código (saiu `SOUND 8,12` com `SOUND 7,62` de mixer correto) e Tocar sem travar.

Documentação atualizada na mesma sessão: `README.md` (nova entrada em "O que já temos" com a imagem
`images/msxbasica-06.png`, novo item de changelog), `docs/MANUAL.md` (nova seção "Editor de som (PSG)"),
este arquivo (módulo 6 + esta entrada). Versão embutida no executável atualizada para `5.9.3`
(`build.ps1` e o fallback de compilação direta em `BadigEditor.pb`).

**Estado ao fim de 2026-07-21 (sessão 3)**: todos os botões do editor de alfabetos (`CharsetEditorGui.pbi`)
viraram **ícones monocromáticos** — pedido explícito do usuário. Doze procedures `CharEd_CreateXxxIcon()`
(mesmo padrão `CreateImage`+`StartDrawing` já usado em `SpriteEd_CreateXxxIcon()` no editor de sprites,
mas em tons de cinza só — `#CharEd_IconInk`/`#CharEd_IconInkLt` — em vez de coloridas) desenham cada
ícone em memória (22×22, botão 34×26 via `ButtonImageGadget`, constantes `#CharEd_IconSize`/
`#CharEd_IconBtnW`/`#CharEd_IconBtnH`), sem depender de arquivo externo. Decisão de design: em vez de um
ícone distinto por botão (20 desenhos diferentes), **reaproveitar o mesmo ícone-base entre botões de
escopo diferente** — `CharEd_CreateCopyIcon`/`CreatePasteIcon`/`CreateRegisterIcon` são usados tanto na
versão "caractere" quanto "alfabeto"/"bloco" do respectivo botão; só a posição na janela e o texto do
`GadgetToolTip` diferenciam o escopo. Considerado e descartado: um "selo" (badge) extra no canto do
ícone pra marcar o escopo (grade pequena = alfabeto, colchetes pequenos = bloco) — a 22px o selo ficaria
espremido/pouco legível, e o agrupamento espacial já existente (barra de projeto vs. barra de bloco vs.
área de edição de caractere) já comunica o escopo sozinho. `CharEd_CreateNavIcon(Size, Direction,
WithBar)` é o único ícone parametrizado, reaproveitado pelos 4 botões de navegação (Primeiro/Anterior/
Próximo/Último) via um triângulo preenchido por varredura de linhas horizontais (`Frac`/`EdgeX` em
ponto flutuante) mais uma barra vertical opcional. `G_Close` ("Fechar") deliberadamente **não** virou
ícone — mesmo precedente já usado em `SpriteEditorGui.pbi` (`G_Close` também é texto lá), evita duplicar
visualmente o "X" que a barra de título já mostra. Efeito colateral positivo: a janela encolheu de
~732px pra ~606px de largura, já que botões de 34px ocupam bem menos espaço que os textos antigos
("Carregar do Graphos III...", "Registrar alfabeto" etc.). Verificado: compilação limpa, screenshot
geral (sem sobreposição) e recortes ampliados (nearest-neighbor 4×) de cada grupo de ícones confirmando
legibilidade, e um clique real (`BM_CLICK` via `PostMessage`) em `G_MarkStart`/`G_MarkEnd` (agora
`ButtonImageGadget`) confirmando que o evento `#PB_Event_Gadget`/`EventGadget()` continua disparando
normalmente (troca de `ButtonGadget` pra `ButtonImageGadget` não muda o tipo de evento). Versão
embutida no executável atualizada para `5.7.7`.

**Estado ao fim de 2026-07-21 (sessão 2)**: editor de alfabetos ganhou clipboard e edição em lote —
ver módulo 4 acima para o detalhe completo (`CharEd_PackGridBytes`/`UnpackGridBytes`, `ClipChar`/
`ClipAlpha`, `BlockStart`/`BlockEnd`, ramificação do evento `G_Invert`). Resumo: **Copiar**/**Colar**
de um caractere isolado (entre caracteres do mesmo alfabeto ou de alfabetos diferentes); **Copiar
alfabeto**/**Colar alfabeto** (os 256 caracteres de uma vez); **Marcar início**/**Marcar fim de
bloco**/**Limpar bloco** definem um intervalo (contorno azul na tabela) que faz o botão **Inverter**
passar a inverter o intervalo inteiro direto em `CharsetBytes`, em vez de só o caractere selecionado.
Verificado: compilação limpa (`/CHECK` + build completo), screenshot confirmando o layout das novas
linhas de botão sem sobreposição (uma primeira tentativa colidiu o status do bloco com os botões
`Copiar`/`Colar` de caractere — corrigido dando ao status sua própria linha, larguras dimensionadas
pra caber dentro de `#CharEd_TableCanvasW`), e um teste ao vivo do fluxo marcar-bloco+inverter via
mensagens `BM_CLICK`/`WM_LBUTTONDOWN` postadas direto nos HWNDs dos controles (mesma técnica seguindo
[[gui_automation_focus_caution]] descrita no módulo 12 — sem mover o cursor real). O clique sintético
no **canvas da tabela** pra selecionar um caractere específico não se mostrou confiável neste ambiente
(mesma classe de fragilidade já registrada pra outros canvases do projeto — `WM_LBUTTONDOWN`/`UP`
postados não pareceram ser processados pela `CanvasGadget` antes do próximo evento, ao contrário de
`BM_CLICK` em botões normais, que funcionou de forma confiável); como resultado, os dois marcadores de
bloco acabaram apontando pro mesmo caractere ($00) no teste, mas isso foi suficiente pra confirmar a
lógica ponta a ponta: `CharEd_BlockStatusText` calculou `"Bloco: $00..$00 (1 caracteres)"` corretamente
e o botão Inverter, em modo bloco, converteu os 8 bytes de `&H00` pra `&HFF` como esperado. Copiar/
colar de caractere e de alfabeto não foram exercitados ao vivo (mesma ressalva de sempre pra cliques em
canvas), mas a lógica é direta e reaproveita padrões já validados (`CharEd_PackChar`/`UnpackChar`,
clipboard de sessão do editor de sprites). Versão embutida no executável atualizada para `5.7.5`.

**Estado ao fim de 2026-07-21 (sessão 1)**: dois ajustes pequenos, sem mudança de escopo. Editor de alfabetos:
botão "Abrir..." virou **"Carregar do Graphos III..."** e passou a importar sempre como alfabeto novo
(numeração automática) em vez de sobrescrever o alfabeto selecionado — ver módulo 4 acima. **Ícone do
aplicativo**: `msxbasica.ico` (raiz do projeto) embutido no `.exe` via `/ICON` do `pbcompiler.exe`
(`build.ps1`, cobre o ícone mostrado pelo Windows Explorer/propriedades do arquivo) e reaplicado em
runtime a cada janela top-level (`App_ApplyWindowIcon()` em `editor/BadigEditor.pb`, chamada logo após
cada `OpenWindow()` — janela principal e as seis janelas secundárias: sprite, alfabeto, disco,
configurações do editor, configurações do Basic Dignified, download de fontes). Em vez de carregar o
`.ico` de um caminho relativo ao `.exe` (frágil se o arquivo não acompanhar a distribuição),
`App_ApplyWindowIcon()` usa `ExtractIconEx_()` pra reler o recurso já embutido do **próprio processo em
execução** (`ProgramFilename()`) e aplica via `WM_SETICON` (`#ICON_BIG`/`#ICON_SMALL`) — cobre barra de
título, menu de sistema (canto superior esquerdo), barra de tarefas e Alt+Tab, mantendo o `.exe`
autocontido. Verificado ao vivo: `ExtractAssociatedIcon` no `.exe` compilado retorna um ícone válido
(Explorer) e `WM_GETICON` na janela principal em execução retorna handles não nulos para
`ICON_BIG`/`ICON_SMALL`. Versão embutida no executável atualizada para `5.7.4`.

**Estado ao fim de 2026-07-19 (sessão 2)**: editor de alfabetos ganhou **integração com o sistema de
projeto** (módulo 4/13 acima) — tabela `alphabets` no `.msxproject`, barra de projeto (número/tag/
Primeiro/Anterior/Próximo/Último/**Registrar alfabeto**/**Novo alfabeto**), mesmo padrão do editor de
sprites (`SpriteEd_FindNavTarget` reaproveitado diretamente). Novidade arquitetural: **"projeto 0"**
(`ProjectDB::EnsureDefaultsOpen()`) — segunda conexão SQLite sempre `:memory:`, nunca salva, semeada com
o charset padrão do MSX embutido no `.exe` (`editor/DefaultCharsetMsx.pbi`, `DataSection` gerada a partir
de `alfabetos\msx.alf`) como alfabeto 0; "Novo alfabeto" sempre parte dele. Harness `ProjectDBTestCli`
cobre tudo, incluindo um teste que compara os bytes embutidos contra o `.alf` real no disco (pega
dessincronização futura). Validado por build + harness + verificação visual ao vivo (menu → janela abriu
com a barra de projeto completa, "Alfabeto: #1" carregado do defaults corretamente) — **não foi
confirmado ao vivo** o clique de navegação/registrar em si (mesma ressalva de automação de mouse pouco
confiável já registrada na sessão 1 abaixo), mas a lógica é a mesma já usada no editor de sprites.

**Estado ao fim de 2026-07-19 (sessão 1)**: **Arquivo → Salvar projeto / Salvar projeto como...** (módulo 13),
extensão `.msxproject`/`.alf` automática (`EnsureExtension`), cópia do conteúdo das abas de texto e
diretório de trabalho passaram a ser guardados no `.msxproject` (ver módulo 13). Novo **editor de
alfabetos** (módulo 4, seção 4 acima, menu **Criar → Alfabeto...**): formato `.ALF` do Graphos III (256
caracteres × 8 bytes, cabeçalho binário MSX de 7 bytes), tabela 16×16 com miniaturas + grade grande
editável + **Registrar**, abrir/salvar `.alf`, carrega `alfabetos\msx.alf` como padrão ao abrir. Validado
por build + verificação visual ao vivo (menu → janela abriu, `alfabetos\msx.alf` carregou e renderizou
corretamente na tabela, botão Inverter confirmado). O clique-para-selecionar-caractere na tabela e o
arrastar-para-pintar na grade grande **não foram confirmados ao vivo** nesta sessão — automação por
`PostMessage`/coordenadas de mouse ficou pouco confiável no ambiente (havia outra janela/app real
disputando foco na mesma máquina), mas o código replica exatamente o padrão já validado em produção do
`SpriteEd_` (mesmo uso de `GetGadgetAttribute(#PB_Canvas_MouseX/Y)` e divisão por tamanho de célula) —
revisão de código deu a mesma aritmética correta, só falta uma confirmação visual ao vivo numa sessão
futura. Ainda **não integrado ao sistema de projeto**: alfabeto vive só no arquivo `.alf`.
Alfabeto padrão `alfabetos\msx.alf` foi recapturado pelo usuário durante a sessão (versão anterior tinha
um trecho de texto de sessão MSX BASIC em vez de bitmap, por um bug na captura original via
`VPEEK`/`POKE`).

**Estado ao fim de 2026-07-18**: duas frentes novas, a maior parte validada por harness de console
(`ProjectDBTestCli.exe`, round-trip de dados completo) já que automação de clique no canvas do editor
de sprites não se mostrou confiável neste ambiente — ver detalhe nas seções dos módulos acima:
- **Editor de sprites** (módulo 4, seção 4 acima): grade 8×8/16×16, palheta MSX1 fixa, modos MSX1/MSX2,
  ferramentas de desenho completas (lápis/borracha/pincel/balde/reta/retângulo/elipse com prévia ao
  vivo), rotacionar/deslocar/inverter/limpar. Char/tile continua não iniciado.
- **Sistema de projeto em SQLite** (módulo 13, seção 13 acima): `.msxproject`, projeto implícito
  "noname" criado ao iniciar sem parâmetros, **Arquivo → Novo/Abrir projeto...**, aviso ao sair. Só a
  tabela de Sprites está ligada a editores de verdade por enquanto — o schema cresce quando Basic/
  Assembly/Telas/Sons/Músicas/listagens LM/documentos ganharem integração ou editor próprio.
- Nome padrão de aba sem título mudou de `"Sem titulo N"` para `"nonameN"`. Versão embutida no
  executável atualizada para **5.5.3**.

**Estado ao fim de 2026-07-16**: três frentes novas, todas testadas ao vivo (GUI automation +
screenshot/pixel-sampling, não só compilação):
- **Rodar no openMSX** (módulo 12, ver detalhe na seção do módulo acima): gerar disco `.dsk` com
  `.dmx`/`.amx`/`.bmx`/`AUTOEXEC.BAS` e abrir o openMSX já rodando o programa, com `-machine`/`-ext`
  escolhidos via botão "..." que lista `share/machines`/`share/extensions`. Isso significa que o
  leftover "aba Emulador sem efeito prático" registrado na sessão anterior **não é mais verdade** —
  `EmRun`/`EmMachine`/`EmExtension`/`EmulatorPath` agora têm efeito real; só `EmSetting`/`EmMonitor`/
  `EmNoThrottle`/`EmVerbose` continuam sem consumidor (não foram usados neste fluxo, ficam como
  próximo incremento natural do módulo 12).
- **Arquivo → Novo Assembly** (módulo 2, ver detalhe na seção do módulo acima): aba `.asm` com syntax
  highlight nativo do dialeto N80/Nestor80 (Konamiman). O motor do assembler Z80 em si (montar
  `.asm` → `.bin`) continua não iniciado — só o lado editor (arquivo + destaque) está pronto.
- Versão embutida no executável (`build.ps1`/`BadigEditor.pb`) atualizada para **5.3.1**.

**Estado ao fim de 2026-07-15 (sessão 2)**: o Basic Dignified reescrito nativo ficou **completo** —
`INCLUDE` e remtags (módulo 3g) implementados e verificados (regressão byte-a-byte contra
`sample/teste.dmx` + fixtures novos de `INCLUDE` aninhado/namespace/remtag), fechando a última lacuna
de paridade com o `badig.py` original. Os menus e código do caminho Python (`SaveTokenized()`,
`BadigCfg_BuildCliArgs()`, `BadigCfg_QuoteArg()`) foram removidos de `editor/BadigEditor.pb` e
`editor/BadigSettings.pbi` — o `.exe` do editor não invoca mais Python em nenhum fluxo.

**Estado ao fim de 2026-07-15 (sessão 1)**: núcleo do Basic Dignified reescrito nativo já rodava de
ponta a ponta contra `teste.dmx` (`editor/DignifiedPreprocessor.pbi` + `editor/MsxTokenizer.pbi`,
módulos 3/3b/11), incluindo `FUNC`/`RET` e, desde 2026-07-14, `-cp`/`-tg`/`-tr`/`-ca`/TAB configurável
— e já ligado à tela de configuração (`BadigCfg`, módulo 3e). O editor ganhou tab bar/régua
customizadas e tema escuro (2026-07-14) e uma tela própria de configurações do editor (fonte, tema
claro/escuro, estilo de abas, fontes customizadas, caminho de instalação — módulo 3f) mais um diretório
de instalação configurável e um botão de download para o Basic Dignified Suite (git clone ou zip,
módulo 3f).

**Próximo passo sugerido (ainda não decidido com o usuário)**: candidatos sem nenhum código de motor
ainda: o assembler Z80 em si (módulo 2, o editor já aceita `.asm` mas não monta nada), editor char/tile
(módulo 4 — a parte de sprite já está pronta, char continua com a lacuna de conteúdo original não
recuperada), estender o sistema de projeto (módulo 13) para Basic/Assembly/demais tipos de conteúdo,
ou aprofundar o módulo 12 (input simulado em runtime, detecção de erro com retorno à linha no editor —
o cuidado já registrado sobre suporte a Windows incerto para a parte de detecção de erro continua
valendo).
