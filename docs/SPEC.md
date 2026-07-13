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
| 2 | Assembler Z80 (2 passes, nativo) | médio-alto | Arquitetura definida, sem detalhe de tabela de opcodes |
| 3 | Basic Dignified reescrito nativo | depende do escopo do original | **v1 implementada e verificada** — `editor/DignifiedPreprocessor.pbi`, ver detalhe abaixo |
| 4 | Editor sprite/char | baixo | **Gap**: explicação detalhada não recuperada da conversa original |
| 5 | Editor gráfico LINE/CIRCLE/PSET/DRAW | baixo-médio | Definido (seção 5) |
| 6 | Editor de som SOUND (PSG) | baixo | Definido (seção 6) |
| 7 | Tracker | alto | Só escopo geral, sem detalhe de UI/formato |
| 8 | Editor MML (comando `PLAY`) | médio | **Gap**: explicação não recuperada |
| 9 | Extensão NestorBASIC (nbasic) | médio | Definido, com exemplo de sintaxe (seção 7) |
| 10 | Dialeto msxbas2rom / geração de ROM | médio | Definido como back-end opcional (seção 8) — **usuário disse "só se valer a pena"** |
| 11 | Saída tokenizada (.bas tokenizado) | baixo (bem documentado) | **Implementado e verificado** — `editor/MsxTokenizer.pbi`, ver detalhe abaixo |
| 12 | Controle do openMSX via socket | médio (alto no item de detecção de erro) | Definido (seção 10) |

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
  - **Débito técnico atual**: `editor/BadigEditor.pb` → `SaveTokenized()` hoje chama
    `python badig.py ... --tk_tokenize` via `RunProgram` (ver `editor/BadigEditor.pb:741-786`). Isso
    contradiz a decisão acima e precisa ser substituído por um tokenizador nativo antes de considerar
    o EXE "limpo".
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

**Escopo não implementado nesta v1** (com guard-rail: `INCLUDE` ainda dá erro explícito "ainda não
suportado" em vez de gerar código corrompido silenciosamente):
- `INCLUDE` (arquivos múltiplos com namespace separado).
- Remtags (`##BB:...`) e a hierarquia completa `.ini`/linha de comando — a v1 usa defaults fixos
  (`line_start=10`, `line_step=10`, `rem_header=True`, sem strip_spaces/capitalize).
- Tradução Unicode→ASCII (`-tr`), conversão `?`/`PRINT` e strip `THEN`/`GOTO` (`-cp`/`-tg`).
- Relatórios de debug (`-lbr`/`-lnr`/`-var`/`-lex`/`-par`).
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
`BadigCfg_BuildCliArgs()` monta a linha de comando do `badig.py` a partir da configuração salva; usada
por `SaveTokenized()` no lugar dos flags fixos que tinha antes.

**Importante — isso é só para o caminho Python**: o pipeline nativo (`DignifiedPreprocessor.pbi` +
`MsxTokenizer.pbi`, módulo 3/3b) ainda usa defaults fixos e **não lê** `BadigCfg` — a lacuna listada em
3d ("Remtags e a hierarquia `.ini`/linha de comando... a v1 usa defaults fixos") continua aberta. Já
existem globals prontos para receber isso sem refatoração (`Dig_LineStart`, `Dig_LineStep`,
`Dig_RemHeader` em `DignifiedPreprocessor.pbi`) — próximo passo natural é ler `BadigCfg` nesses globals
antes de chamar `Dig_Preprocess()`/`Tok_Tokenize()`, unificando as duas telas de configuração num só
conjunto de opções.

### 5. Editor gráfico LINE/CIRCLE/PSET/DRAW
- Mais simples que DRAW puro isolado porque LINE/CIRCLE/PSET são coordenadas absolutas (sem estado de
  posição/ângulo atual).
- Saída: lista de comandos BASIC prontos (`LINE...`, `CIRCLE...`, `PSET...`, `DRAW...`) na ordem
  desenhada, para injeção como bloco/include.

### 6. Editor de som SOUND (PSG / AY-3-8910 / YM2149)
- 3 canais de tom + 1 de ruído + envelope de volume por hardware.
- UI: sliders/campos para tom (frequência → período de registrador), volume (0-15 ou "usar envelope"),
  forma de envelope (~10 formatos de hardware), período de envelope.
- Saída: sequência de `SOUND n, valor`, ou bytes de registrador crus para rotina Z80 (mais rápido que
  várias chamadas `SOUND`).

### 7. Tracker (escopo alto, não detalhado)
- Sequenciador de padrões, editor de padrão (grade linha × canal, nota/volume/efeito), motor de
  playback (tempo real ou geração de trilha para tocar via Z80/interrupção), "instrumentos" = envelope +
  volume ao longo do tempo (sem sample/wavetable, diferente de tracker MOD).

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

## Lacunas conhecidas (a preencher em conversas futuras)

- Seção 4 (editor sprite/char): detalhe da conversa original não foi recuperado.
- Seção 8 (editor MML/`PLAY`): detalhe da conversa original não foi recuperado.
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

**Estado ao fim de 2026-07-13**: núcleo do Basic Dignified reescrito nativo já existe e roda de ponta
a ponta contra `teste.dmx` (`editor/DignifiedPreprocessor.pbi` + `editor/MsxTokenizer.pbi`, módulos
3/3b/11), incluindo `FUNC`/`RET`. Bug de charset do caminho Python corrigido (módulo 3e) e nova tela
de configuração nativa (`editor/BadigSettings.pbi`, menu "Configurar → Basic Dignified...") criada
para o caminho Python. A especificação do núcleo (Basic Dignified + tokenizador MSX + controle do
openMSX) está completamente documentada a partir do código-fonte original — as lacunas remanescentes
são só os módulos que dependiam de conteúdo não recuperado da conversa original (sprite/char,
MML/`PLAY`) ou de levantamento de dados externo (NestorBASIC, msxbas2rom).

**Próximo passo sugerido (ainda não decidido com o usuário)**: escolher entre —
1. Ligar `BadigCfg` (a nova tela de configuração) ao pipeline **nativo**, lendo os globals que já
   existem em `DignifiedPreprocessor.pbi` (`Dig_LineStart`, `Dig_LineStep`, `Dig_RemHeader`) a partir
   da struct salva, e implementando as opções que faltam nele (`INCLUDE`, remtags/`-tr`/`-cp`/`-tg`,
   ver módulo 3d) — fecharia de vez a paridade com o caminho Python e permitiria remover os menus
   Python de `BadigEditor.pb` (débito técnico listado acima).
2. Ou seguir para um módulo totalmente novo (assembler Z80, editor sprite/char, controle do openMSX
   via módulo 12) — falta decidir qual com o usuário.
