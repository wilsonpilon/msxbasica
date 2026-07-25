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
| 2 | Assembler Z80 (2 passes, nativo) | médio-alto | **Completo (2026-07-25)** — motor `editor/Z80Asm.pbi` (opcodes/expressões/diretivas/condicionais/macros básicas, saída absoluta e relocável `.REL`), validado byte-a-byte contra os oráculos `N80.exe`/`LK80.exe`/`LB80.exe` (Nestor80). Menu completo: **Executar → Montar Assembly (.bin)/relocável (.REL)/Linkar (.REL) → binário**, **Criar → Biblioteca Z80 (.LIB)/Assembly Sub Project** ("Makefile primitivo" — vários `.asm` + libs numa lista ordenada, monta tudo de uma vez, ver módulo 2d). Saída consumível por MSX-BASIC e MSX-DOS (`.bin`/`.com`/disco `.dsk`/listing `DATA`+`POKE`, módulo 2c) e sistema de projeto (`asm_builds`/`asm_subprojects` em `ProjectDB.pbi`). Detalhe em `docs/resumo-asm.md`, módulos 2b/2c/2d abaixo |
| 3 | Basic Dignified reescrito nativo | depende do escopo do original | **Completo (2026-07-15)** — `editor/DignifiedPreprocessor.pbi`, incluindo `INCLUDE` e remtags, ver módulo 3g |
| 4 | Editor sprite/char | baixo | **Sprite e alfabeto implementados (2026-07-19)** — `editor/SpriteEditorGui.pbi`/`editor/CharsetEditorGui.pbi`, ambos integrados ao sistema de projeto (módulo 13), ver seção 4. **Editor de alfabetos Aquarela (.FNT) implementado (2026-07-23)** — `editor/AquarelaCharsetEditorGui.pbi`, ferramenta autocontida baseada em arquivo, sem integração com o sistema de projeto, ver seção 4b. **Editor de alfabetos Graphos III ganhou 13 efeitos de edição em lote (2026-07-23)** — desfazer/refazer, marcar tudo, espelhar/girar/apagar/estreitar/itálico/negrito/largo (+ variantes bold e largo-bold), ver seção 4c. Tile (além do charset/fonte 8×8) ainda não iniciado |
| 5 | Editor gráfico LINE/CIRCLE/PSET/DRAW | baixo-médio | **Implementado (2026-07-24)** — `editor/Screen2Synth.pbi` (motor)/`editor/Screen2EditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 5 |
| 6 | Editor de som SOUND (PSG) | baixo | **Implementado (2026-07-21)** — `editor/PsgSynth.pbi` (motor)/`editor/PsgEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 6 |
| 7 | Tracker | alto | Só escopo geral, sem detalhe de UI/formato |
| 8 | Editor MML (comando `PLAY`) | médio | **Implementado (2026-07-21)** — `editor/MmlSynth.pbi` (motor)/`editor/MmlEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 8 |
| 9 | Extensão NestorBASIC (nbasic) | médio | Definido, com exemplo de sintaxe (seção 7) |
| 10 | Dialeto msxbas2rom / geração de ROM | médio | Definido como back-end opcional (seção 8) — **usuário disse "só se valer a pena"** |
| 11 | Saída tokenizada (.bas tokenizado) | baixo (bem documentado) | **Implementado e verificado** — `editor/MsxTokenizer.pbi`, ver detalhe abaixo |
| 12 | Controle do openMSX via socket | médio (alto no item de detecção de erro) | **Parcial (2026-07-16)**: gerar disco + abrir o openMSX já rodando o programa está implementado, mais uma CLI `--diskmanipulator` standalone embutida no `.exe`; controle via socket/XML, input simulado e detecção de erro em runtime ainda não |
| 13 | Sistema de projeto (arquivo `.msxproject`, SQLite) | baixo-médio | **Implementado (2026-07-18), estendido (2026-07-19)** — `editor/ProjectDB.pbi`, ver seção 13. Sprites, alfabetos, cópia das abas de texto e diretório de trabalho já ligados; **Salvar projeto/Salvar projeto como...**; "projeto 0" de defaults sempre em memória. Demais tipos de conteúdo entram quando tiverem editor próprio |
| 14 | Graphos III — edição de telas SCREEN 2 (`Criar → Graphos III Screen 2...`) | alto (várias fases) | **Fase 1: tela + color clash (2026-07-25)** — canvas SCREEN 2 fiel ao hardware (reaproveita `Screen2Synth.pbi`/`Screen2EditorGui.pbi` do módulo 5 sem nenhuma mudança), paleta INK/PAPER, ferramentas TRAÇO (Lápis/Borracha) e LIMPA TELA. **Fase 2: resto do menu DESENHO (2026-07-25, mesma sessão)** — BLOCO/LINHA/RETÂNGULO/RAIO/CÍRCULO/PINTURA/SPRAY/FILL, ver seção 14b. **Fase 3: menu TEXTO (2026-07-25, mesma sessão)** — escreve na tela com um alfabeto do projeto, 6 variações (NORMAL/ITALIC/BOLD/DUPLO/DUPLO BOLD/LARGO), ver seção 14c. **Fase 4: menu TELA + reorganização de layout (2026-07-25, mesma sessão)** — SALVA TELA/Restaurar, INVERTE VIDEO/ATRIBUTOS, RETIRA/REPOE VIDEO/ATRIBUTOS, todos com ícone; coluna direita e faixa abaixo do canvas reequilibradas, ver seção 14d. **Fase 5: persistência no projeto (2026-07-25, mesma sessão)** — Telas/Layouts/Shapes no `.msxproject` via `ProjectDB.pbi`, mesmo padrão número/navegação/tag/Novo/Registrar do editor de sprites/alfabetos, ver seção 14e. **Fase 6: menu AJUSTE (2026-07-25, mesma sessão)** — SCROLL/ROTAÇÃO, 1px e 8x8, 4 direções, ver seção 14f. **Fase 7: menu MISCELÂNEA (2026-07-25, mesma sessão)** — ZOOM (janela à parte), SHAPE (carimbo com 4 modos lógicos), CORTE (Inverter/Espelhar), GRID (overlay não destrutivo), ver seção 14g. **Fase 8 (2026-07-25, mesma sessão): cursor de teclado — tentada e revertida**, ver seção 14h (usuário achou desnecessária com o mouse já disponível). **Fase 9: formatos nativos .ALF/.LAY/.SCR/.SHP (2026-07-25, mesma sessão)** — importar/exportar telas/layouts/shapes no formato binário que o Graphos III de verdade grava em disco (`editor/GraphosNativeIO.pbi`), verificado por round-trip contra arquivos reais (`editor/tools/GraphosNativeIOTestCli.pb`), ver seção 14i. Réplica do **Graphos III** original (`graphos/graphos.txt`, manual completo) — escopo desta IDE cobre só telas/shapes/layout (o editor de alfabetos do Graphos III já existe, módulo 4). **Todos os 5 menus do original (DESENHO/TEXTO/TELA/AJUSTE/MISCELÂNEA) + os formatos de arquivo nativos estão implementados.** Ver seções 14/14b a 14i |

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
- Referência de comportamento: **Nestor80** (Konamiman, github.com/Konamiman/Nestor80) — assembler C#
  moderno, 100% compatível M80/L80, clonado como material de leitura em `nestor80/` (gitignored, mesmo
  tratamento de `badig/` — não dependência de runtime, ver módulo 3). Decisão fechada com o usuário
  2026-07-24: **portar 100% do comportamento do Nestor80** (não só estudar arquitetura genérica de
  sjasmplus/z88dk como cogitado originalmente), incluindo eventualmente REL/linker/biblioteca
  (Linkstor80/Libstor80-equivalentes, ver módulo 2b abaixo).
- Integração com editor: bloco de assembly dentro do mesmo arquivo `.dmx`/`.bas` (marcador tipo
  `' ASM` ... `' ENDASM`) com highlighting dinâmico, ou abas separadas `.BAS`/`.ASM` referenciadas.
- Saída: `.bin`/listagem hexa para uso com `BLOAD` ou rotina clássica de carga hexa em runtime.

**Status (2026-07-24): motor implementado (Fase A) e integrado ao editor.** Detalhe completo do
processo de implementação (decisões técnicas, bugs encontrados/corrigidos, gotchas de PureBasic) em
**`docs/resumo-asm.md`** — este é só o resumo funcional. Spec de linguagem portada documentada em
`docs/reference/nestor80-language.md`.

- **Lado editor** (2026-07-16, sem mudança desde então): a decisão de arquitetura acima escolheu "abas
  separadas", não o marcador `' ASM`/`' ENDASM` embutido no mesmo arquivo. Menu **Arquivo → Novo
  Assembly** (`Ctrl+Shift+N`, ao lado de "Novo") cria uma aba `.asm` em vez de `.dmx`; o tipo de cada
  aba é rastreado em `Document\Mode` (`"DMX"` ou `"ASM"`, `editor/BadigEditor.pb`), detectado
  automaticamente pela extensão ao abrir um arquivo existente (`.asm`/`.z80`/`.mac` → `ASM`). Diálogos
  de Abrir/Salvar já filtram e sugerem a extensão certa por modo (`#File_Pattern_ASM`/
  `#File_Pattern_Open`).
- **Motor** (`editor/Z80Asm.pbi`, `DeclareModule Z80Asm` — mesmo padrão de `ProjectDB.pbi`/
  `MSXDisk.pbi`): avaliador de expressão completo (precedência idêntica ao Nestor80, conferida direto
  no C# fonte), parser de linha (`nome:`/`nome::`/forma `EQU`/`DEFL`/`ASET`/`MACRO` sem `:`), tabela de
  opcodes Z80 completa (documentados + subconjunto indocumentado comum `IXH`/`IXL`/`IYH`/`IYL`),
  driver de 2 passes absoluto (`ORG`/rótulo/`EQU`/`DEFL`/`ASET`/`END`), diretivas de dados
  (`DB`/`DW`/`DS`/`DC`/`DZ`), condicionais (`IF`/`IFT`/`IFE`/`IFF`/`IFDEF`/`IFNDEF`/`IF1`/`IF2`/`ELSE`/
  `ENDIF`) e macros básicas (`MACRO`/`ENDM`/`EXITM`/`LOCAL`). `ASEG`/`CSEG`/`DSEG`/`COMMON`/`PUBLIC`/
  `EXTRN`/etc. reconhecidas sintaticamente, sem efeito pleno ainda (só fazem sentido pra saída
  relocável, módulo 2b). Fora de escopo desta fase: `REPT`/`IRP`/`IRPC`/`IRPS`, `MODULE`/labels
  locais, saída Intel HEX, listagem `.LST`, R800/Z280.
- **Validação**: `dotnet`/`N80.exe` (o próprio Nestor80 compilado localmente) serve de **oráculo de
  teste byte-a-byte** durante todo o desenvolvimento — mesma técnica já usada pro tokenizador nativo
  (módulo 11). `editor/tools/Z80AsmTestCli.pb` (59 testes unitários de vocabulário/expressão/parser de
  linha + modo `--assemble <fonte> <saida.bin>` pra comparação binária direta) e dois arquivos de
  regressão oficiais, **`sample/teste_opcodes.asm`** (206 linhas, ~190 formas de instrução distintas — papel
  equivalente a `sample/teste.dmx` pro Dignified) e **`sample/teste2_macros.asm`** (condicionais +
  macro com `LOCAL`) — ambos **idênticos byte a byte** ao `N80.exe` real (394 e 21 bytes,
  respectivamente).
- **Integração**: menu **Executar → Montar Assembly (.bin)...** (`Ctrl+F5`), habilitado quando a aba
  ativa está em modo `ASM` — monta e salva via `SaveFileRequester` (sugestão de nome = mesmo nome da
  aba, extensão `.bin`), erro mostra linha + mensagem (`Z80Asm::GetAssembleErrorLine()`/
  `GetAssembleErrorText()`).

**Módulo 2b — Linkstor80/Libstor80 (linker + gerenciador de biblioteca), Fase B: motor completo**:
pedido explícito do usuário 2026-07-24 — gerar uma biblioteca de rotinas montadas separadamente e, ao
linkar contra ela, só os módulos realmente referenciados entram no `.COM` final (linkagem estática
seletiva). **Geração do `.REL` funciona ponta a ponta** (`Z80Asm::AssembleRelocatable()`): escritor de
bit-stream (`RelW_*`) + driver de 2 passes relocável dedicado (`RunOnePassRel`), `ASEG`/`CSEG`/`DSEG`/
`COMMON`/`PUBLIC`/`EXTRN`/`.REQUEST` com efeito real. **O linker (`editor/Z80Link.pbi`) linka múltiplos
`.REL` E resolve `.REQUEST`/biblioteca** (leitor de bit-stream + `ProcessProgram()`/`LinkFiles()`,
indexação por-programa dos símbolos públicos de cada biblioteca pedida + ponto fixo pra resolução
transitiva — linkagem estática seletiva de verdade). **`editor/Z80Lib.pbi` gerencia bibliotecas `.LIB`**
(`CreateOrAddLibrary`/`ListLibrary`/`RemoveProgram`). Tudo validado byte a byte contra `N80.exe`/
`LK80.exe`/`LB80.exe` reais (um bug/limitação real encontrado no `LK80.exe` local — só reconhece o
símbolo público do primeiro programa de uma biblioteca multi-programa pedida via `.REQUEST` — está
documentado em `docs/resumo-asm.md`, contornado com validação por auto-consistência nesse caso
específico). Ainda faltam: `--code`/`--data`/`--align-*`/`--code-before-data` do linker, detecção de
sobreposição de segmento, saída Intel HEX. `LK80.exe`/`LB80.exe` compilados localmente como oráculo
(mesma receita do `N80.exe`, ver `docs/resumo-asm.md`). Especificação de formato/algoritmo documentada
em `docs/reference/nestor80-rel-format.md` e `docs/reference/nestor80-linker.md`. Detalhe do checklist
em `docs/resumo-asm.md`, seção "Checklist Fase B".

**Integração de menu do linker/biblioteca — implementada (2026-07-25)**: `editor/Z80LinkGui.pbi`
(**Executar → Linkar (.REL) → binário...**) lista .REL numa ordem editável (Adicionar/Remover/Subir/
Descer), aceita uma pasta de biblioteca opcional (`.REQUEST`) e chama `Z80Link::LinkFiles()`;
`editor/Z80LibGui.pbi` (**Criar → Biblioteca Z80 (.LIB)...**) cria/abre uma `.LIB`, lista programas
(`Z80Lib::ListLibrary`) com nome/tamanho/símbolos públicos, adiciona `.REL` (`CreateOrAddLibrary`) e
remove programa (`RemoveProgram`) — sem cópia de rascunho temporária (diferente do gerenciador de
disco): as chamadas de `Z80Lib.pbi` já gravam direto e de forma atômica no arquivo escolhido. Novo item
**Executar → Montar Assembly relocável (.REL)...** (`AssembleZ80RelFromActiveTab()`, `BadigEditor.pb`)
monta a aba `.asm` ativa via `Z80Asm::AssembleRelocatable()` e salva o `.REL` — o insumo que faltava
pra alimentar o linker/biblioteca a partir do editor, sem precisar do CLI de teste.

**Bug real encontrado durante esta integração**: `Z80Link.pbi` e `Z80Asm.pbi` faziam cada um seu próprio
`XIncludeFile "Z80RelFormat.pbi"` de dentro do respectivo `DeclareModule`, mas `XIncludeFile` deduplica
por **caminho de arquivo em todo o programa**, não por `Module` — funcionava no CLI de teste
(`Z80LinkTestCli.pb`, que nunca inclui `Z80Asm.pbi`), mas quebrava assim que os dois módulos passaram a
coexistir na mesma unidade de compilação (`BadigEditor.pb`): a segunda inclusão virava no-op, deixando
`#Z80Seg_Code`/etc. inexistentes dentro do namespace de `Z80Link` (erro "Constant not found" em
`LEffectiveAddr`). Corrigido criando `editor/Z80RelFormatLink.pbi`, uma cópia dedicada pro `Module
Z80Link` — mesmo espírito de "cada Module tem sua cópia" já usado pra `Z80LinkItemType`.

**Módulo 2c — integrações com o resto da IDE — implementado (2026-07-25)**:
- **Saída consumível por MSX-BASIC e por MSX-DOS puro**: `editor/Z80OutputGui.pbi` centraliza o que
  fazer com um binário já montado (absoluto), já linkado ou já construído por um subprojeto — janela de
  escolha com quatro caminhos: (1) `.bin` solto no PC (com ou sem cabeçalho MSX BLOAD, comportamento que
  já existia, só extraído pra cá); (2) **`.COM` (MSX-DOS)** — `Z80Out_ExportCom()` (2026-07-25, pedido
  explícito do usuário "assim o assembler pode trabalhar independente do MSX BASIC"), binário cru sem
  cabeçalho nenhum (formato CP/M/MSX-DOS clássico), avisa sem bloquear se `StartAddr <> 0100h`; (3)
  **disco MSX (`.dsk`)** pronto pra rodar via `AUTOEXEC.BAS` (`"10 BLOAD"NOME.BIN",R"`, sempre com
  cabeçalho — reaproveita `MSXDisk.pbi`, mesmo mecanismo já usado por `RunOnOpenMSX()` no fluxo
  Dignified); (4) **listing BASIC** (`Z80Gen_BasicLoader()` — loop `FOR/READ/POKE` + blocos `DATA` em
  hexa, 16 bytes por linha, mais um comentário `DEFUSR=.../A=USR(0)` pronto pra chamar — mesmo espírito
  do "Gerar bytes crus" do editor de som PSG, mas com o loop de `POKE` que o PSG não precisa) numa
  janela com **Copiar**/**Injetar no cursor** (reaproveita `InjectTextAtCursor()`). Usado por "Montar
  Assembly (.bin)...", "Linkar (.REL) → binário..." e "Assembly Sub Project → Montar tudo (Build)...".
- **Sistema de projeto** (módulo 13): nova tabela `asm_builds` em `ProjectDB.pbi` — metadado da
  **última** exportação de binário/disco por `SourceKey` (caminho do `.asm`, pra montagem absoluta; ou
  `"LINK|" + .rel's` na ordem escolhida, pra uma sessão de link — não há uma única aba de origem nesse
  caso), gravado automaticamente por `Z80Out_ExportBin`/`Z80Out_ExportDisk` sempre que a exportação
  produz um arquivo de verdade (não o listing, que só vai pra área de transferência/cursor). Mesmo
  padrão `Store*/Fetch*/Has*/List*` dos demais tipos de conteúdo (DELETE+INSERT); fora da soma de
  `HasUnsavedContent()` de propósito, mesmo motivo de `documents` — é metadado de algo que já foi
  exportado pra um arquivo independente em disco. Coberto por round-trip em
  `editor/tools/ProjectDBTestCli.pb` (store/fetch/overwrite/list/has + through `SaveAs`/`OpenExisting`).

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

### 2d. Assembly Sub Project — "Makefile primitivo" (implementado 2026-07-25)

**Status: implementado**, pedido explícito do usuário depois de fechado o módulo 2b/2c: **Criar →
Assembly Sub Project...** (`editor/Z80SubProjectGui.pbi`, motor sem GUI em `editor/Z80SubProject.pbi`)
— um subprojeto onde o usuário reúne vários `.asm` (cada um vira um `.REL` na hora do build) mais
bibliotecas referenciadas via `.REQUEST`, numa lista **ordenada**, e manda montar tudo de uma vez num
binário final (`.bin`/`.com`) — "como um Makefile primitivo". Também gera bibliotecas a partir de um
subconjunto dos `.asm` do próprio subprojeto e oferece adicioná-las de volta à lista.

- **Motor** (`Z80SubProject.pbi`): `Z80SubProj_Build()` monta cada `.asm` em `.REL`
  (`Z80Asm::AssembleRelocatable`, nome de programa = nome do arquivo maiúsculo) numa pasta de trabalho
  temporária dedicada e linka tudo (`Z80Link::LinkFiles`); `Z80SubProj_BuildLibraryFromAsm()` monta um
  subconjunto e empacota via `Z80Lib::CreateOrAddLibrary`.
- **Achado real**: `Z80Link::LResolveLibPath()` (motor do linker, módulo 2b) sempre resolve um nome de
  `.REQUEST` bare para `"<nome>.rel"` — **mesmo que o nome já termine em `.lib`** (vira
  `"nome.lib.rel"`, nunca encontrado) — então bibliotecas geradas por **Criar → Biblioteca Z80 (.LIB)**
  (que sugere extensão `.lib`) não funcionavam sozinhas via `.REQUEST`. Corrigido no nível certo:
  `Z80SubProj_StageLibraries()` sempre copia+renomeia cada biblioteca da lista do usuário para
  `"<nome-base>.rel"` numa pasta de trabalho temporária antes de linkar, independente da extensão
  original — `Z80LibGui.pbi`/`Z80Lib.pbi` não precisaram de nenhuma mudança. Detalhe completo em
  `docs/resumo-asm.md`.
- **Persistência** (`ProjectDB.pbi`): tabela `asm_subprojects` (`asm_files`/`lib_files` como TEXT unidos
  por `Chr(10)` na ordem escolhida, mesmo padrão de `mml_songs`) — diferente de `asm_builds` (metadado
  de algo já exportado, fora da soma), um subprojeto é configuração real sem cópia em outro lugar e
  **entra** na soma de `HasUnsavedContent()`.
- **GUI**: mesma barra de projeto (número/tag/navegação/Novo/Registrar) dos demais tipos de conteúdo
  registrados no `.msxproject`, reaproveitando os ícones/lógica de navegação do editor de sprites.
  Botão **"Montar tudo (Build)..."** manda o resultado pro mesmo escolhedor de saída do assembler/
  linker (`Z80Out_ChooseAndExport`, módulo 2c) — `.bin`/`.com`, disco `.dsk` ou listing BASIC.
- **Validação**: `editor/tools/Z80SubProjectTestCli.pb` (4/4, self-contained) monta pares `.asm` reais
  de `sample/` DIRETO dos fontes (não dos `.rel` já prontos) e confere byte a byte contra os mesmos
  resultados já validados contra o `LK80.exe` real no módulo 2b, incluindo o caso completo "gerar
  biblioteca a partir de `.asm` → build final resolvendo `.REQUEST` contra ela" (linkagem estática
  seletiva confirmada de ponta a ponta).

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

**Status (2026-07-24): implementado.** Menu **Criar → Draw Screen 2...**, mesma arquitetura tríade dos
módulos 6/8: motor sem GUI (`editor/Screen2Synth.pbi`, prefixo `Scr2_`), janela
(`editor/Screen2EditorGui.pbi`, prefixo `Scr2Ed_`) e harness headless (`editor/tools/Screen2TestCli.pb`,
69 casos). Primeiro modo de tela implementado — **SCREEN 2** (TMS9918 Graphics II, 256×192); outros
modos (SCREEN 1/5/7/8) ficam para quando o usuário pedir, reaproveitando o mesmo motor.

**Modelo de dados (color clash fiel ao hardware)**: 3 arrays fixos, nunca `ReDim` —
`PatternBit.a(191,255)` (1 bit por pixel), `RowFG.a(191,31)`/`RowBG.a(191,31)` (cor 0-15 por *faixa de
scanline* de 8×1 pixels — 1 par tinta/fundo por scanline de cada célula de 8px, do tamanho exato da
Color Table real, 192×32 = 6144 bytes). `Scr2_SetPixel()` é o primitivo único de escrita: liga o bit e
**sobrescreve** a `RowFG`/`RowBG` inteira daquela faixa — o clash aparece sozinho ao reler
(`Scr2_GetPixelColor()`), sem nenhuma lógica extra de detecção, porque é exatamente o que a ROM real
faz. Confirmado por harness (pintar 2 cores na mesma faixa de 8px faz a faixa inteira mostrar só a
última cor gravada) e por um caso de PAINT que pega o clash "de brinde" (preencher o interior de uma
caixa muda a cor da borda esquerda também, porque compartilham a faixa/scanline — documentado
explicitamente no teste como comportamento correto, não bug).

**Sete ferramentas** (uma aba por `PanelGadget`, `Scr2_Command` guarda o tipo + parâmetros de cada
comando na lista, `Scr2_ReplayAll()`/`Scr2Ed_ReplayAllWithText()` reconstroem o framebuffer do zero a
cada mudança — mesma filosofia "sem estado incremental frágil" das listas de passos do PSG/linhas do
MML):
- **PSET/PRESET** — clique no canvas já liga/apaga o pixel na cor selecionada.
- **LINE** — reta/caixa (`B`)/caixa cheia (`BF`); dois cliques (ponto inicial, ponto final) com **linha
  elástica** (`Scr2Ed_DrawLinePreview`) acompanhando o mouse antes do segundo clique.
- **CIRCLE** — círculo (1º clique = centro, 2º = raio) ou elipse (os 2 cliques marcam os cantos do
  quadro), com preview elástica equivalente (`Scr2Ed_DrawCirclePreview`), suporta ângulo inicial/final
  (fatia de pizza) e aspecto.
- **PAINT** — preenchimento por vizinhança 4-direções, pilha (não recursivo).
- **DRAW** — interpretador completo da mini-linguagem de tartaruga do MSX-BASIC (`Scr2_ExecuteDraw`):
  `U D L R E F G H` (movimento reto/diagonal), `B`/`N` (não traça / traça e volta), `M[+-]x,[+-]y`
  (absoluto/relativo), `C` (cor), `S` (escala), `A` (ângulo 0-3 × 90°) e `TA` (ângulo livre em graus).
  Rotação em passos de 90° usa transformação inteira exata `(Dx,Dy)→(-Dy,Dx)` em vez de
  `Cos`/`Sin` (que não batem exato em 90°/180°/270° por imprecisão de ponto flutuante — bug pego e
  corrigido durante o desenvolvimento, ver `Scr2_RoundF`); trigonometria só é usada mesmo para `TA`
  (ângulo arbitrário), sempre com arredondamento half-away-from-zero na conversão pra pixel inteiro.
  Não implementado (limitação deliberada): `X`string`;` (executar sub-string de variável) — não faz
  sentido numa ferramenta WYSIWYG sem variáveis BASIC de verdade por trás.
- **TEXTO** — escreve usando um alfabeto do banco do projeto (módulo 4/4b). Redesenhado
  (2026-07-24, sessão do mesmo dia) de campos digitáveis de coluna/linha para um **quadro elástico
  arrastável**: ao clicar em "Posicionar TEXTO...", um quadro com o texto de verdade (glifos reais do
  alfabeto escolhido, cores Tinta/Fundo escolhidas — `Scr2Ed_DrawTextPreview`) passa a seguir o mouse,
  começando na posição Y correspondente ao terço marcado (Cima/Meio/Baixo, só um ponto de partida —
  depois disso o quadro é livre). Move de 8 em 8 pixels por padrão (encaixa no grid de tiles de
  caractere) ou pixel a pixel segurando **Ctrl** (`GetKeyState_(#VK_CONTROL)`, mesma chamada já usada em
  `WordStarKeys.pbi`); clique fixa o texto (vira um comando com `X1`/`Y1` = âncora em pixel bruto, igual
  a qualquer outro comando do módulo); botão direito cancela.

**STEP e `LINE -(x,y)`** (2026-07-24): `Scr2_Command` ganhou `StepP1`/`StepP2`/`LineNoStart`, e o motor
passou a simular um **cursor gráfico** (`Scr2_CursorX/Y`, globals) igual ao do MSX-BASIC real — todo
comando de desenho deixa o cursor na sua coordenada de referência ao terminar (LINE no ponto final;
CIRCLE/PSET/PRESET/PAINT no próprio ponto; DRAW na posição final calculada), e `Scr2_ReplayAll()` reseta
o cursor pra (0,0) no início de cada replay. `StepP1`/`StepP2` fazem `X`/`Y` serem lidos como
deslocamento a partir do cursor (`StepP2` da LINE é relativo ao **ponto 1 da própria LINE**, não ao
cursor pré-comando — semântica de `LINE (x,y)-STEP(dx,dy)` do MSX-BASIC real); `LineNoStart` equivale a
`LINE -(x2,y2)` (usa o cursor como ponto 1, ignorando `X1`/`Y1`/`StepP1`). Resolução implementada como
duas funções `Scr2_ResolveP1X`/`Scr2_ResolveP1Y` com `ProcedureReturn` — uma primeira tentativa usando
um único procedure com parâmetros de saída por ponteiro (`*OutX.Integer`, dereferenciado via `\i`) foi
descartada **antes de compilar**, por depender de um dereferenciamento de ponteiro pra tipo básico que o
PureBasic não aceita (`\campo` exige ponteiro tipado pra `Structure`); o padrão do resto do projeto —
devolver valor extra via `Global` ou, aqui, via duas funções de retorno simples — evitou o problema.
Geração de código (`Scr2_GenBasicLines`) emite `STEP(x,y)` e `LINE -(x,y)` textualmente, espelhando
exatamente o que `Scr2_ReplayCommand` calcula em tempo de desenho.

**Texto fora do grid de 8px**: como `LOCATE`/`PRINT` só endereçam célula de caractere inteira,
`Scr2Ed_GenBasicLinesWithText` escolhe entre dois caminhos na hora de gerar código pro comando TEXTO,
conforme a âncora `(X1,Y1)` cair ou não em múltiplo de 8: alinhado usa o carregador `DATA`+`VPOKE` (
`Scr2Ed_GenAlphabetLoader`, sobrescreve a Pattern/Color Table do terço correspondente) + `LOCATE`/
`PRINT`, igual ao mecanismo real do MSX-BASIC; fora do grid (posicionado pixel a pixel com Ctrl) usa
`Scr2Ed_GenTextPixelBurn`, que "queima" cada pixel do glifo via `PSET`/`PRESET` (mais verboso, mas
funciona em qualquer posição sem depender de sobrescrever a ROM de caracteres).

**UX de clique no canvas**: PSET/PRESET adicionam na hora do clique; LINE/CIRCLE usam gesto de 2 cliques
(1º marca ponto pendente, 2º completa); cada ferramenta com clique-para-adicionar tem seu **mini buffer**
(`ListIconGadget` filtrado por tipo de comando, `SetGadgetItemData` guarda a posição real na lista
principal pra permitir apagar certo mesmo filtrado) com botão Remover que também some do canvas.

**Persistência**: tabela `screens` em `ProjectDB.pbi` (mesmo padrão hex-encoded de `alphabets`, mas
guardando a **lista de comandos serializada** — não o framebuffer — pra poder editar/reordenar depois
de recarregar; formato texto delimitado por `|`/quebra de linha, um comando por linha), barra de
projeto completa (número/tag/navegação/Registrar/Novo/Copiar/Colar) idêntica aos demais editores.

**Geração de código**: `Scr2_GenBasicLines`/`Scr2Ed_GenBasicLinesWithText` produzem `PSET`/`PRESET`/
`LINE`/`CIRCLE`/`PAINT`/`DRAW` prontos, um por linha, na ordem da lista — **Injetar no cursor**/
**Copiar** como nos demais editores.

**Verificação**: `editor/tools/Screen2TestCli.pb` (69 casos) cobre clash, `DrawLine`, `ExecuteDraw`
(quadrado fechado, troca de cor, escala, ângulos 0-3, `B`/`N`), `CIRCLE` (completo e fatia de pizza),
`LINE` em modo caixa/caixa cheia, `PAINT` (incluindo o clash proposital), replay de lista + geração de
código, e o bloco novo de STEP/`LINE -(x,y)` (resolução pra cada tipo de comando, `LineNoStart`, avanço
do cursor por tipo, reset do cursor a cada `Scr2_ReplayAll`, texto do código gerado).

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

### 14. Graphos III — edição de telas SCREEN 2 (Fase 1: implementada 2026-07-25)

Pedido explícito do usuário: replicar o **Graphos III** (Renato Degiovani, 1987; revisão A&L Software,
1997 — manual completo em `graphos/graphos.txt`, lido integralmente para levantar o escopo de funções),
um editor de vídeo clássico do MSX que só trabalha em **SCREEN 2**. Cada função do Graphos III original
vira uma opção **separada** dentro de "Criar" nesta IDE (pedido explícito) — o editor de alfabetos do
Graphos III **já existe** (`CharsetEditorGui.pbi`, formato `.ALF`, módulo 4) e fica **de fora** deste
módulo de propósito. O Graphos III original navegava os menus **DESENHO/TEXTO/TELA/AJUSTE/MISCELANEA**
pelas teclas **F1-F5**; aqui cada operação vira um botão/ícone, no mesmo espírito do editor de sprites,
em vez de teclas de função.

**Arquivo**: `editor/GraphosScreenGui.pbi` (menu **Criar → Graphos III Screen 2...**). Sem motor próprio
novo — reaproveita **na íntegra**, sem nenhuma mudança, o motor já validado do módulo 5
(`editor/Screen2Synth.pbi`: `Scr2_SetPixel`/`GetPixelColor`/`ClearFramebuffer`, mesmo modelo
`PatternBit`/`RowFG`/`RowBG` fiel ao color clash real do TMS9918 — 1 par tinta/fundo por faixa de
scanline de 8 pixels, já coberto por 69 casos de teste) e os helpers de desenho de canvas/paleta já
escritos em `editor/Screen2EditorGui.pbi` (`Scr2Ed_RedrawCanvas`/`RedrawMiniPalette`) e
`editor/SpriteEditorGui.pbi` (`SpriteEd_FillPalette`, ícones `CreatePencilIcon`/`CreateEraserIcon`,
`SpriteEd_UnpressOtherTools`) — a mesma paleta MSX1 de 16 cores e o mesmo desenho de swatch já usados
pelo editor "Draw Screen 2..." aparecem aqui identicamente.

**Fase 1 (esta sessão) cobre só "a tela que representa a SCREEN 2"**, pedido explícito do usuário como
ponto de partida antes do resto do toolset:
- Canvas 256×192 (zoom 2× = 512×384) com color clash idêntico ao MSX de verdade (herdado do motor, não
  reimplementado).
- Paleta **INK**/**PAPER** (16 cores fixas MSX1, clicáveis).
- **TRAÇO** do menu DESENHO/F1 original — **Lápis** (INS, liga o pixel com INK) e **Borracha** (DEL,
  apaga o pixel gravando PAPER na faixa), ambos com **arrastar contínuo** (mesmo padrão de
  `SpriteEd_ApplyTool`/`#PB_Canvas_Buttons` do editor de sprites) e alternância mutuamente exclusiva via
  `ButtonImageGadget` com `#PB_Button_Toggle`.
- **LIMPA TELA** do menu TELA/F3 original — apaga tudo e grava INK/PAPER atuais em toda a tela
  (`GraphosScr_ClearWithColors`, variante de `Scr2_ClearFramebuffer` que usa as cores escolhidas pelo
  usuário em vez dos defaults fixos).

**Deliberadamente fora desta fase** (próximos cortes, um por vez): resto do menu **DESENHO** (BLOCO com
tamanho de cursor ajustável, LINHA/RAIO encadeados, RETÂNGULO, CÍRCULO, PINTURA — só cor de fundo sem
alterar pixels —, SPRAY, FILL); menu **TEXTO** (NORMAL/ITALIC/BOLD/DUPLO/DUPLO BOLD/LARGO, usando um
alfabeto do banco já existente); menu **TELA** (INVERTE VÍDEO/ATRIBUTOS, RETIRA/REPÕE VÍDEO/ATRIBUTOS,
IMPRIME TELA); menu **AJUSTE** (SCROLL/SCROLL 8×8/ROTAÇÃO/ROTAÇÃO 8×8); menu **MISCELÂNEA** (ZOOM,
SHAPE — carimbar shapes do banco com MÁSCARA/AND/OR/XOR —, CORTE — inverter/espelhar um recorte —,
GRID); **CRIA/ARQUIVA/RECUPERA SHAPES** (4 tipos de shape, ver `graphos/graphos.txt` seção 3.8);
integração com o sistema de projeto (nenhuma tabela nova em `ProjectDB.pbi` ainda — sem número/tag/
Registrar/navegação por enquanto, já que o formato de conteúdo real só faz sentido definir depois que o
toolset estiver mais completo); e os formatos de arquivo nativos do Graphos III — **DISPLAY** (`.SCR`,
BSAVE de `&H9200`, Pattern+Color Table completas — o mesmo layout que `BLOAD "nome.SCR",R` do
MSX-BASIC espera em SCREEN 2), **LAYOUT** (`.LAY`, só o vídeo sem atributos, compactado RLE) e
**COMPAC** (`.VTC`+`.ATC`, vídeo e atributos separados, RLE) — nenhum lido/escrito ainda.

**Verificação**: compilação limpa (`/CHECK` inclusive); a correção do color clash em si já vem
integralmente testada pelo módulo 5 (`editor/tools/Screen2TestCli.pb`, 69 casos) — nenhuma lógica de
clash nova foi escrita aqui. Automação de clique ao vivo não foi possível neste ambiente (mesma
limitação de isolamento de sessão do Windows já registrada em `docs/resumo-asm.md`), então a UI em si
foi verificada por revisão de código cuidadosa em vez de clique real.

### 14b. Graphos III — Fase 2: resto do menu DESENHO (2026-07-25, mesma sessão)

Completa o menu **DESENHO (F1)** do Graphos III original: **BLOCO**, **LINHA**, **RETÂNGULO**, **RAIO**,
**CÍRCULO**, **PINTURA**, **SPRAY** e **FILL**, todos em `editor/GraphosScreenGui.pbi`. Nenhuma delas
precisou de motor gráfico novo — `Scr2_DrawLine`/`Scr2_LineStatement` (`BoxMode=1`, contorno de
retângulo)/`Scr2_DrawCircle`/`Scr2_FloodFill` (todos de `editor/Screen2Synth.pbi`, já usados pelo editor
"Draw Screen 2...") cobrem LINHA/RETÂNGULO/RAIO/CÍRCULO/FILL sem nenhuma mudança; as prévias elásticas
de LINHA/CÍRCULO reaproveitam `Scr2Ed_DrawLinePreview`/`Scr2Ed_DrawCirclePreview`
(`editor/Screen2EditorGui.pbi`) também sem mudança. Só **PINTURA** e **SPRAY** precisaram de lógica
nova, pequena:

- **BLOCO** (`GraphosScr_ApplyBlock`) — mesma semântica de TRAÇO (seta com INK/Lápis ou reseta com
  PAPER/Borracha, `Scr2_SetPixel`), mas sobre um retângulo `BlockW × BlockH` de pixels centrado no
  cursor em vez de um pixel só. Tamanho ajustável por dois `StringGadget` (sem `SpinGadget` nesta base
  de código), validado na hora do uso por `GraphosScr_ClampBlockSize` (`1..64`, `Val()` de texto vazio
  vira `0` → clampado pra `1`).
- **PINTURA** (`GraphosScr_PaintBackground`) — fiel ao manual ("altera a cor de fundo dos pontos
  indicados pelo cursor... sem alterar a cor de frente do desenho"): grava só `RowBG(Y, X/8)`, nunca
  `PatternBit`/`RowFG` — diferente de `Scr2_SetPixel`, que sempre acende/apaga o bit junto. Sempre usa
  PAPER, nunca respeita o alternador Lápis/Borracha (não faz sentido "apagar o fundo").
- **SPRAY** (`GraphosScr_ApplySpray`) — "imita o resultado de uma pintura com spray... padrão aleatório,
  tende a formar um borrão compacto caso não haja deslocamento do cursor": a cada clique/passo de
  arraste, borrifa `#GraphosScr_SprayDabs = 6` pixels em posições aleatórias dentro de um raio quadrado
  `#GraphosScr_SprayRadius = 5` ao redor do cursor, respeitando PenMode como TRAÇO/BLOCO.
- **LINHA/RETÂNGULO/RAIO/CÍRCULO** — todas seguem o padrão "âncora + prévia elástica + segundo clique
  confirma", com uma diferença de semântica ditada pelo manual original que separa LINHA das outras
  três: em **LINHA** o ponto final vira automaticamente o ponto inicial do próximo segmento (poligonal
  aberta, `AnchorX/Y` avança a cada clique); em **RETÂNGULO/RAIO/CÍRCULO** a âncora (vértice fixo/origem
  do raio/centro) permanece **fixa** entre desenhos — o usuário clica várias vezes e cada clique produz
  uma nova forma a partir da mesma âncora. Botão direito do mouse sobre o canvas cancela a âncora
  pendente das quatro (equivalente ao ESC do original); trocar de ferramenta também cancela.

**Alternador Lápis(INS)/Borracha(DEL)**: fiel ao manual ("INSERT/DELETE funciona com TRACO, BLOCO,
SPRAY e todo o menu de TEXTO"), só essas ferramentas respeitam `PenMode`
(`GraphosScr_ToolUsesPenMode`) — os dois botões (reaproveitando `SpriteEd_CreatePencilIcon`/
`CreateEraserIcon` da fase 1, agora com o papel de alternador de modo em vez de seletor de ferramenta)
ficam desabilitados (`DisableGadget`) quando LINHA/RETÂNGULO/RAIO/CÍRCULO/PINTURA/FILL está ativa —
essas sempre desenham com INK (exceto PINTURA, sempre PAPER), nunca apagam.

**Ícones novos** (`GraphosScr_Create*Icon`, mesmo estilo monocromático 24bpp dos ícones do editor de
sprites): `CreatePixelIcon` (TRAÇO — um pixel isolado ampliado), `CreateRayIcon` (RAIO — leque de linhas
partindo de uma origem fixa), `CreatePaintIcon` (PINTURA — quadrado dividido, metade "tinta" intocada e
metade "fundo" recolorida), `CreateSprayIcon` (SPRAY — nuvem de pontos). BLOCO/LINHA/RETÂNGULO/CÍRCULO/
FILL reaproveitam ícones já existentes do editor de sprites (`CreateBrushIcon`/`CreateLineToolIcon`/
`CreateRectOutlineIcon`/`CreateEllipseOutlineIcon`/`CreateFillIcon`) sem nenhuma mudança.

**Verificação**: compilação limpa (`.\build.ps1`). Mesma limitação já registrada acima (fase 1) e em
`docs/resumo-asm.md` impede automação de clique ao vivo neste ambiente — verificado por revisão de
código cuidadosa da lógica de âncora/prévia/PenMode/clamp, mais execução do `.exe` compilado
(`.\build.ps1 -R`) para o usuário testar interativamente.

**Continua de fora** (próximos cortes, sem mudança de escopo): menu TEXTO (F2), menu TELA (F3), menu
AJUSTE (F4), menu MISCELÂNEA (F5) e CRIA/ARQUIVA/RECUPERA SHAPES, os formatos nativos `.SCR`/`.LAY`/
`.VTC`+`.ATC`, e integração com o sistema de projeto (`ProjectDB.pbi`).

### 14c. Graphos III — Fase 3: menu TEXTO (2026-07-25, mesma sessão)

Implementa o menu **TEXTO (F2)** do Graphos III original: escreve na tela usando um alfabeto já
registrado no projeto (`ProjectDB::FetchAlphabet`, mesmo formato `CharsetBytes(255,7)` do módulo 4 —
não cria nenhuma tabela nova, só lê o que o editor de alfabetos já grava). Seis variações, na mesma
ordem do manual (`graphos/graphos.txt`, seção 3.2.2):

- **NORMAL** — glifo 8×8 sem transformação.
- **ITALIC**/**BOLD** — reaproveitam, sem duplicar a fórmula de bits, as mesmas transformações já
  escritas pro editor de alfabetos (`CharEd_ItalicEditGrid`/`CharEd_BoldEditGrid`, `CharsetEditorGui.pbi`,
  módulo 4c). A diferença crucial: lá a transformação é aplicada e **gravada** de volta no alfabeto
  (`Registrar`); aqui (`GraphosScr_BlitTextStyled`/`GraphosScr_DrawTextPreview`) ela só existe no
  instante do blit — o alfabeto no banco nunca é alterado, cada impressão parte sempre do glifo
  original via `CharEd_UnpackChar`.
- **DUPLO**/**LARGO**/**DUPLO BOLD** — duplicação geométrica de linha/coluna no framebuffer (cada pixel
  do glifo vira um bloco `ScaleX×ScaleY`), sem alterar a forma — o mesmo sentido de "dupla altura/
  largura" de impressora matricial que dá nome às opções originais (não confundir com o "Largo"/
  "Estreitar" do editor de alfabetos, que são um truque de **compressão** de bits pra caber mais
  colunas na mesma célula 8px, o oposto do que se quer aqui). `GraphosScr_TextScaleX`/`TextScaleY`
  resolvem as 6 combinações com um único par de loops de duplicação em vez de 6 blits especializados.

**Fluxo de UI**: alfabeto (`ComboBoxGadget` populado por `ProjectDB::ListAlphabetNumbers`, mesmo padrão
do editor "Draw Screen 2..."), estilo (`ComboBoxGadget` com as 6 opções) e texto (`StringGadget`) ficam
na coluna direita; **Posicionar TEXTO...** congela alfabeto/texto/cores/estilo no momento do clique
(`TextPendingCharset`/`TextPendingStr`/`TextPendingInk`/`TextPendingPaper`/`TextPendingStyle`, pra não
mudar no meio do posicionamento se o usuário mexer nos campos) e arma `TextPlacementActive` — mesmo
padrão de "Posicionar → prévia elástica segue o mouse → clique fixa" já usado pela ferramenta TEXTO do
editor "Draw Screen 2..." (módulo 5), mas sem o grid de 8px/STEP daquele editor (irrelevante aqui, já
que este editor ainda não gera código BASIC — só framebuffer). Botão direito do mouse cancela o
posicionamento pendente (equivalente ao ESC do original); selecionar qualquer ferramenta do menu
DESENHO também cancela (mutuamente exclusivo com TRAÇO/BLOCO/etc., via
`SpriteEd_UnpressOtherTools(ToolGadgets(), -1)` ao entrar em modo TEXTO).

**Verificação**: compilação limpa (`.\build.ps1`). Mesma limitação de automação de clique ao vivo já
registrada nas fases anteriores — verificado por revisão de código cuidadosa da lógica de
transformação/escala/congelamento de estado, mais execução do `.exe` compilado para o usuário testar
interativamente.

**Continua de fora** (próximos cortes, sem mudança de escopo): menu TELA (F3), menu AJUSTE (F4), menu
MISCELÂNEA (F5) e CRIA/ARQUIVA/RECUPERA SHAPES, os formatos nativos `.SCR`/`.LAY`/`.VTC`+`.ATC`, e
integração mais ampla com o sistema de projeto (persistência da própria tela, não só leitura de
alfabetos).

### 14d. Graphos III — Fase 4: menu TELA + reorganização de layout (2026-07-25, mesma sessão)

Três pedidos explícitos do usuário na mesma mensagem: implementar o menu **TELA (F3)**, reorganizar o
layout da janela (coluna direita ficando alta demais, área abaixo do canvas vazia) e usar ícone em todo
botão de ação. Também nesta sessão, fora deste arquivo: seed automático de um alfabeto "padrao" no
arranque da IDE.

**Menu TELA (F3)** — todas as operações do manual (`graphos/graphos.txt`, seção 3.2.3) exceto
**IMPRIME TELA** (sem suporte a impressora nesta IDE, fora de escopo):

- **SALVA TELA**/**Restaurar** (`GraphosScr_SalvaTela`/`RestauraTela`) — backup/restauração da tela
  **inteira** (pixels + Tinta + Fundo) num buffer dedicado (`FullBackupPattern`/`FullBackupFG`/
  `FullBackupBG` + `FullBackupValid`). Equivalente ao "buffer" do Graphos III original, mas escopado só
  a este par de botões — o original salva automaticamente a cada operação (tecla RETURN) e HOME/CLS
  sempre recupera o último passo, o que seria um undo geral pra qualquer ação desta janela (fora de
  escopo).
- **INVERTE VIDEO** (`GraphosScr_InvertVideo`) — inverte `PatternBit(Y,X) = 1 - PatternBit(Y,X)` de
  cada pixel, sem tocar em `RowFG`/`RowBG`.
- **INVERTE ATRIBUTOS** (`GraphosScr_InvertAttrs`) — troca `RowFG(Y,Cx)` com `RowBG(Y,Cx)` de toda
  faixa, sem tocar em `PatternBit`.
- **RETIRA VIDEO**/**REPOE VIDEO** (`GraphosScr_RetiraVideo`/`RepoeVideo`) — RETIRA copia `PatternBit`
  pro backup `VideoBackupPattern` e zera tudo (tela passa a mostrar só a cor de PAPER de cada faixa);
  REPOE devolve. Cada par tem seu **próprio** slot de backup (não compartilha com Atributos/Tela
  inteira) — mais simples de raciocinar, e os 3 backups nunca colidem entre si.
- **RETIRA ATRIBUTOS**/**REPOE ATRIBUTOS** (`GraphosScr_RetiraAtributos`/`RepoeAtributos`) — RETIRA
  copia `RowFG`/`RowBG` pro backup `AttrBackupFG`/`AttrBackupBG` e grava `#Scr2_DefaultFG`/`BG` (branco/
  preto) em toda faixa — "deixando à vista somente os pixels setados", como o manual descreve; REPOE
  devolve as cores guardadas.
- **LIMPA TELA** (já existia desde a Fase 1, `GraphosScr_ClearWithColors`) passou a viver na mesma
  grade de ícones do resto do menu TELA, com ícone em vez de botão-texto.

Todas as 9 operações são botões de ação única (`ButtonImageGadget` **sem** `#PB_Button_Toggle` — não
ficam "pressionados"), e todas cancelam qualquer âncora pendente de LINHA/RETÂNGULO/RAIO/CÍRCULO/TEXTO
(`PendingActive`/`TextPlacementActive = #False`) antes de mexer no framebuffer, já que uma operação de
tela inteira invalida qualquer prévia elástica em andamento.

**Reorganização de layout** — antes desta fase, a coluna direita já somava ~800px de altura (paleta +
9 ferramentas DESENHO em 3 linhas + Lápis/Borracha + BLOCO + TEXTO + Limpar + status), bem mais alta que
o canvas (~490px), deixando a área abaixo do canvas praticamente vazia. Mudanças:

- `RightW` (largura da coluna direita) subiu de 160 pra 200 — permite **5 ícones por linha** em vez de
  3, cortando as grades DESENHO (9 ferramentas) e TELA (9 operações) de 3 linhas pra 2 cada.
- **BLOCO** (Largura×Altura) e **TEXTO** (alfabeto/estilo/string/Posicionar) — controles de texto/combo,
  mais naturais numa faixa horizontal larga do que espremidos numa coluna de 160-200px — desceram pra
  uma faixa abaixo do canvas (`BelowLabelY`/`BelowRowY`), ao lado do botão **Fechar**, ocupando o espaço
  que antes ficava vazio. `WinW` agora é o maior entre "coluna direita + margem" e "faixa abaixo do
  canvas + margem" (a faixa de TEXTO, com 4 controles lado a lado, acaba sendo a mais larga das duas).
- Resultado: janela bem mais baixa (right column ~630px vs ~800px antes) e as duas metades da janela
  (canvas+faixa abaixo vs coluna direita) ficam com alturas parecidas em vez de uma dominar a outra.

**Ícones em todo botão de ação** — `GraphosScr_CreateRetiraRepoeIcon(Size, IsAttrs, IsRepoe)` é um único
gerador parametrizado pros 4 botões RETIRA/REPOE (vídeo e atributos) em vez de 4 ícones quase-idênticos:
quadrado xadrez preto/branco quando `IsAttrs=#False` (VIDEO, é sobre pixel) ou laranja sólido quando
`IsAttrs=#True` (ATRIBUTOS, é sobre cor — mesma cor já usada pelo ícone de PINTURA, módulo 14b, mesma
convenção visual "laranja = cor de fundo"), com uma seta no canto superior direito apontando pra cima
(`IsRepoe=#False`, RETIRA/remove) ou pra baixo (`IsRepoe=#True`, REPOE/devolve). Além desse, 4 ícones
novos de uso único: `GraphosScr_CreateSaveIcon` (disquete, SALVA TELA), `GraphosScr_CreateUndoIcon`
(seta circular, Restaurar), `GraphosScr_CreateInvertVideoIcon` (quadrado metade preta/metade branca com
pontos trocados) e `GraphosScr_CreateInvertAttrsIcon` (dois retalhos laranja/azul com setas opostas).
LIMPA TELA reaproveita `SpriteEd_CreateClearIcon` (já usado pelo editor de alfabetos) em vez de ganhar
um novo.

**Alfabeto padrão automático** (fora deste arquivo — `editor/BadigEditor.pb`): `App_EnsureDefaultAlphabet()`,
chamada logo após `ProjectDB::EnsureOpen()` no arranque normal da IDE (dentro do mesmo `If
CountProgramParameters() = 0`, nunca no caminho `--diskmanipulator`). Percorre `ProjectDB::
ListAlphabetNumbers()` conferindo `LastAlphabetTag()` de cada um; se nenhum tiver a tag **"padrao"**
(comparação case-insensitive, `LCase()`), registra um novo (`ProjectDB::StoreAlphabet`, número =
maior existente + 1, ou 0 se a lista estiver vazia) semeado com `ProjectDB::FetchDefaultAlphabet(0,
...)` — o mesmo charset MSX embutido no `.exe` que "Novo alfabeto" já usa (`DefaultCharsetMsx.pbi`),
nenhum dado novo. Não mexe em nada se um "padrao" já existir (projeto salvo por sessão anterior) — só
garante que ele exista, nunca sobrescreve. Objetivo: o menu TEXTO deste editor (e qualquer consumidor
futuro de alfabetos) sempre encontra pelo menos um alfabeto pronto, sem exigir que o usuário passe por
**Criar → Alfabeto Graphos III...** manualmente antes de usar TEXTO pela primeira vez.

**Verificação**: compilação limpa (`.\build.ps1`). Mesma limitação de automação de clique ao vivo já
registrada nas fases anteriores — verificado por revisão de código cuidadosa da lógica de backup/
inversão/layout, mais execução do `.exe` compilado para o usuário testar interativamente.

**Continua de fora** (próximos cortes, sem mudança de escopo): menu AJUSTE (F4), menu MISCELÂNEA (F5) e
CRIA/ARQUIVA/RECUPERA SHAPES, os formatos nativos `.SCR`/`.LAY`/`.VTC`+`.ATC`. Persistência de Tela/
Layout/Shape no `.msxproject` foi implementada logo em seguida, ver seção 14e.

### 14e. Graphos III — Fase 5: persistência no projeto (2026-07-25, mesma sessão)

Pedido explícito do usuário: "colocar os trabalhos do Graphos no arquivo de Projeto também. Telas,
shapes, layouts... menu similar aos outros onde o usuário pode nomear a tela/shape/layout, adicionar
novos, registrar, avançar para o próximo, retroceder, ir para o primeiro e para o último" — mesmo padrão
já usado pelo editor de sprites/alfabetos (módulos 4/13).

**Três tabelas novas em `ProjectDB.pbi`** (`graphos_screens`/`graphos_layouts`/`graphos_shapes`) —
**deliberadamente separadas** da tabela `screens` já existente (editor "Draw Screen 2...", módulo 5),
que guarda uma **lista de comandos** serializada, não um framebuffer; as tabelas Graphos guardam o
framebuffer puro (`PatternBit`/`RowFG`/`RowBG`), formato incompatível com `screens`. Pattern/Color são
empacotados **1 byte por célula de 8 pixels** (mesmo layout lógico da Pattern/Color Table de verdade do
TMS9918 — INK no nibble alto, PAPER no nibble baixo do byte de cor), hex-codificados 2 dígitos por byte,
mesmo padrão já usado por `StoreAlphabet`. Como `ProjectDB.pbi` compila **antes** de `Screen2Synth.pbi`
na ordem de `XIncludeFile` de `BadigEditor.pb`, os limites 256/192/32 são literais no código, não
`#Scr2_Width`/`Height`/`Cols` — mesmo motivo de `StoreAlphabet` já hardcodar 256/8 em vez de uma
constante externa.

- **`graphos_screens`** (TELA) — `StoreGraphosScreen`/`FetchGraphosScreen`/`HasGraphosScreen`/
  `ListGraphosScreenNumbers`: framebuffer 256×192 completo (pixels + INK/PAPER por faixa).
- **`graphos_layouts`** (LAYOUT) — `StoreGraphosLayout`/`FetchGraphosLayout`/`HasGraphosLayout`/
  `ListGraphosLayoutNumbers`: só `PatternBit`, sem nenhuma cor — equivalente ao `.LAY` original ("só o
  vídeo sem atributos").
- **`graphos_shapes`** (SHAPE) — `StoreGraphosShape`/`FetchGraphosShape`/`HasGraphosShape`/
  `ListGraphosShapeNumbers`: recorte retangular de tamanho **variável** (`Width`/`Height` próprios,
  colunas extras); `PatternBit`/`RowFG`/`RowBG` do chamador continuam dimensionados no tamanho máximo
  do canvas (256×192) — só a sub-região `[0..Height-1, 0..Width-1]` é lida/escrita.

Todas entram na soma de `HasUnsavedContent()` (conteúdo real do usuário, mesmo critério de sprites/
alfabetos/sons/músicas).

**UI em `GraphosScreenGui.pbi`** — três barras de projeto na faixa abaixo do canvas (Tela/Layout/Shape),
cada uma reaproveitando **sem nenhuma mudança** os componentes já validados do editor de alfabetos:
`CharEd_CreateNavIcon`/`CreateNewIcon`/`CreateRegisterIcon` (ícones Primeiro/Anterior/Próximo/Último/
Novo/Registrar), `#CharEd_IconBtnW`/`IconBtnH` (dimensões) e `SpriteEd_FindNavTarget` (lógica de
"qual número é o alvo do botão X", genérica, já usada pelo editor de sprites).

- **TELA e LAYOUT compartilham o mesmo canvas em edição** e a mesma flag `CanvasDirty` — são **2
  formatos de salvar o mesmo framebuffer** (TELA = pixels + cores; LAYOUT = só pixels), não 2 documentos
  independentes, refletindo como o Graphos III original também trata ARQUIVA TELA/LAYOUT (salvar o
  buffer atual em formatos diferentes, não editá-los separadamente). "Novo" em qualquer um dos dois
  limpa o canvas (`Scr2_ClearFramebuffer`) e numera automaticamente (maior número já registrado + 1, ou
  0 se a lista estiver vazia); navegar (Primeiro/Anterior/Próximo/Último) busca do projeto e substitui o
  canvas inteiro. `GraphosScr_ConfirmDiscardChanges()` (mensagem genérica, reaproveitada também por
  Shape e pelo botão Fechar/fechamento da janela) pede confirmação antes de descartar alterações não
  registradas — mesmo padrão de `CharEd_ConfirmDiscardAlphabet`/`Scr2Ed_ConfirmDiscardScreen`.
- **SHAPE tem buffer próprio** (`ShapeCapturePattern`/`ShapeCaptureFG`/`ShapeCaptureBG`, dimensionado no
  tamanho máximo do canvas mas só a sub-região `ShapeW × ShapeH` é significativa) e sua própria flag
  `ShapeDirty`, independentes do canvas principal. **Marcar área...** arma `ShapeMarkPending`/
  `ShapeMarkHasAnchor` — mesmo fluxo de 2 cliques do RETANGULO (`Scr2Ed_DrawLinePreview` com
  `BoxMode=1` como prévia elástica), mas em vez de desenhar, o 2º clique **captura** o recorte marcado
  do canvas principal para o buffer do shape (pixel a pixel + célula de cor a célula de cor). O eixo X
  da seleção é sempre alinhado (snap) ao grid de 8px antes de capturar (`SelX = (SelX/8)*8`, `SelX2`
  arredondado pra cima do mesmo jeito) — garante que cada célula de cor **local** do shape corresponda a
  uma célula **inteira** da tela de origem, sem precisar reamostrar/interpolar cor nenhuma (o eixo Y não
  precisa de snap, já que a cor é por linha de varredura, não por bloco 8×8). `GraphosScr_
  RedrawShapePreview` desenha uma prévia em miniatura do recorte capturado, escalada (zoom inteiro,
  `Min(CaixaW/W, CaixaH/H)`, mínimo 1) pra caber numa caixa fixa de 150×70 — não dá pra reaproveitar
  `Scr2Ed_RedrawCanvas` (fixo em 256×192/zoom 2) pra um recorte de tamanho variável, mas o lookup de cor
  por pixel reaproveita `Scr2_GetPixelColor` sem nenhuma mudança (os limites 256/192 do motor continuam
  válidos mesmo com `W`/`H` lógicos menores).
- A barra do Shape (nav + "Marcar área..." + prévia) acabou sendo a linha mais larga da janela — mais
  larga que "coluna direita + margem", único termo usado no cálculo original de `WinW`. Em vez de prever
  esse total de antemão, a janela é alargada de verdade (`ResizeWindow`) **depois** de todos os gadgets
  já criados com suas posições X absolutas, comparando a extensão real da barra do Shape contra o `WinW`
  já calculado.

**Verificação**: compilação limpa (`.\build.ps1`), aplicação executada (`.\build.ps1 -R`) sem erro em
tempo de execução. Mesma limitação de automação de clique ao vivo já registrada nas fases anteriores —
verificado por revisão de código cuidadosa da lógica de captura/snap de 8px/dirty-tracking/layout, mais
execução do `.exe` compilado para o usuário testar interativamente.

**Continua de fora** (próximos cortes, sem mudança de escopo): menu AJUSTE (F4), menu MISCELÂNEA (F5) e
escolha de máscara/tipo do SHAPE (CRIA SHAPES de verdade, seção 3.8 do manual — fica pro carimbo AND/OR/
XOR de MISCELÂNEA), os formatos de arquivo nativos `.SCR`/`.LAY`/`.VTC`+`.ATC` **em disco** (a
persistência desta fase é só no banco SQLite do projeto, não arquivos `.SCR`/`.LAY`/`.VTC`/`.ATC`
avulsos).

**Correção pós-fase (mesma sessão)**: o usuário reportou o botão "Marcar área..." e a prévia do Shape
aparecendo por cima do fim da coluna direita (grade TELA (F3)/status). Causa raiz: `ScreenBarY` (início
da faixa abaixo do canvas) estava ancorado só em `CanvasY + CanvasH` — mas a coluna direita (paleta +
DESENHO + BLOCO + Modo + TELA + status) é bem mais alta que o canvas sozinho, e a barra do Shape se
estende bastante em X (até a prévia de 150px), então parte dela caía numa faixa Y que a coluna direita
ainda ocupava, mesmo a faixa abaixo do canvas "começando" nominalmente depois do canvas. Corrigido
ancorando em `Max(CanvasY + CanvasH, StatusBottom)` em vez de só `CanvasY + CanvasH` — `StatusBottom`
(fim da coluna direita) já era calculado antes desse ponto do código, só não era considerado. Versão
`7.5.7`.

**Refinamento (mesma sessão, logo em seguida)**: a correção da `7.5.7` resolvia a colisão mas deixava a
janela ocupando quase toda a altura da tela (pedido explícito do usuário: "muito espaço por fora não
aproveitado"). Diagnóstico correto: a colisão nunca foi um problema de **Y** (a faixa abaixo do canvas
"começando tarde demais") — foi um problema de **X**: a barra do Shape se estendia até quase encostar em
`RightX` só por causa de "Marcar área..." + a prévia (150px) penduradas na mesma linha dos navegadores.
Duas colunas lado a lado (esquerda estreita, direita = coluna de ferramentas) podem compartilhar
qualquer faixa de Y livremente, **desde que não se sobreponham em X** — o `Max(..., StatusBottom)` da
`7.5.7` era uma correção de sintoma, não da causa. Correção definitiva:
- `ScreenBarY` voltou a ser só `CanvasY + CanvasH + 14` (removido o `Max` com `StatusBottom`).
- "Marcar área..."/prévia do Shape ganharam **linha própria** (`ShapeMarkRowY = ShapeBarY + 30`),
  abaixo dos 3 navegadores — sem eles, a barra do Shape (só nav + tag) termina em ~X=508, bem antes de
  `RightX` (547 nesta janela), então nunca mais invade a coluna direita, não importa em que Y ela caia.
- **INK/PAPER lado a lado** (pedido explícito do usuário, aproveitando a revisão) em vez de empilhados —
  `DesenhoLabelY` agora é só `CanvasY + 18 + PaletteSize + 16` (removido o bloco `PaperY` inteiro),
  economizando 72px de altura na coluna direita e reduzindo ainda mais a chance de a coluna direita
  ficar mais alta que o canvas.
Versão `7.5.8`.

**Correção (mesma sessão, logo em seguida)**: o usuário reportou que a linha nova de "Marcar área.../
prévia" ainda sobrepunha os botões de navegação da barra do Shape acima. Bug de aritmética: `G_ShapePreview`
usava `ShapeMarkRowY - 22` (tentativa de centralizar verticalmente a prévia de 70px com o botão de 30px),
mas `ShapeMarkRowY` era só `ShapeBarY + 30` — subtrair 22 disso resultava em `ShapeBarY + 8`, bem dentro
da faixa Y que os ícones de navegação do Shape (altura ~30) ainda ocupavam. Corrigido alinhando o topo
da prévia com `ShapeMarkRowY` (sem deslocamento negativo) e aumentando a margem pra `ShapeBarY + 34`.
Versão `7.5.9`.

### 14f. Graphos III — Fase 6: menu AJUSTE (2026-07-25, mesma sessão)

Pedido explícito do usuário: "scroll pixel a pixel nas 4 direções e scroll de 8 pixels por vez... mais
duas opções de rotacionar pixel a pixel e 8 pixels por vez" — as 4 operações do manual original (seção
3.2.4): SCROLL, SCROLL 8x8, ROTAÇÃO, ROTAÇÃO 8x8.

**Distinção "vídeo" vs "atributos"** segue exatamente a mesma convenção já estabelecida por INVERTE
VIDEO/INVERTE ATRIBUTOS (Fase 4, módulo 14b): "vídeo" = só `PatternBit` (pixels); "atributos" = `RowFG`/
`RowBG` (cores). SCROLL/ROTAÇÃO comuns (1px) mexem só no vídeo; as variantes 8x8 mexem nos dois juntos.

- **`GraphosScr_ScrollVideo1px(PatternBit, Direction)`** — desloca 1 pixel na direção indicada (0=cima,
  1=baixo, 2=esquerda, 3=direita, mesma convenção usada em todo o resto do arquivo). A parte que sai da
  tela é perdida (preenchida com `0`).
- **`GraphosScr_ScrollVideo8px(PatternBit, RowFG, RowBG, Direction, InkColor, PaperColor)`** — desloca 8
  *scanlines* (cima/baixo) ou 8 colunas de pixel = **1 célula de cor inteira** (esquerda/direita). A cor
  no MSX real já é por linha de varredura (não por bloco 8×8 como em SCREEN 1), então um deslocamento
  vertical não precisa de nenhum alinhamento especial de célula — só o horizontal precisa (`Cx = X/8`),
  daí deslocar `RowFG`/`RowBG` por **1 célula** em vez de "8 unidades". Área vazia preenchida com
  `InkColor`/`PaperColor` atuais (pixels resetados, células de cor = Tinta/Fundo).
- **`GraphosScr_RotateVideo1px`/`RotateVideo8px`** — mesma lógica, mas com **wraparound** (aritmética
  modular `%`) em vez de perder/preencher a parte que sai — a parte que sai por um lado reentra pelo
  lado oposto, sem nenhuma perda de dado.

Todas as 4 usam uma cópia temporária do framebuffer (`Dim Tmp`) em vez de deslocar in-place — mais
simples de raciocinar (sem se preocupar com ordem de iteração sobrescrevendo dados ainda não lidos) e
barato o bastante numa tela 256×192.

**UI**: nova seção "Ajuste (AJUSTE):" na coluna direita, logo abaixo da grade TELA (F3). Dois
alternadores **independentes** (mesmo padrão botão-imagem + `SpriteEd_UnpressOtherTools` já usado por
Lápis/Borracha — dois grupos à parte do `ToolMode` das ferramentas de DESENHO): **passo** (1px — reusa
`GraphosScr_CreatePixelIcon` da fase 2 — ou 8px — `GraphosScr_CreateStep8Icon`, quadrado sólido maior) e
**modo** (SCROLL — reaproveita `CharEd_CreateNavIcon(Size, 1, #True)`, a "parede" no fim da seta já
existia pra Primeiro/Último e comunica bem "a parte que sai é perdida" — ou ROTAÇÃO —
`GraphosScr_CreateRotateModeIcon`, seta circular com cor própria pra não confundir com o ícone de
"Restaurar"/`GraphosScr_CreateUndoIcon`, mesma ideia conceitual mas ações diferentes). As **4 setas de
direção** são ação única (`GraphosScr_CreateArrowIcon(Size, Direction)`, um só gerador parametrizado
reaproveitando `CharEd_DrawFilledHTri`/`VTri` do editor de alfabetos — módulo 4c — em vez de desenhar
triângulo do zero): aplicam a combinação passo+modo atual assim que clicadas, sem precisar de
"Registrar" (mesmo espírito das operações do menu TELA, módulo 14b). `GraphosScr_AjusteStatusText`
monta a mensagem de status legível pras 16 combinações passo×modo×direção.

**Verificação**: compilação limpa (`.\build.ps1`) na primeira tentativa, aplicação executada
(`.\build.ps1 -R`) sem erro em tempo de execução. Mesma limitação de automação de clique ao vivo já
registrada nas fases anteriores — verificado por revisão de código cuidadosa da lógica de deslocamento/
wraparound/alinhamento de célula de cor, mais execução do `.exe` compilado para o usuário testar
interativamente.

**Continua de fora** (próximos cortes, sem mudança de escopo): menu MISCELÂNEA (F5 — ZOOM, SHAPE com
máscara/AND/OR/XOR, CORTE, GRID), os formatos de arquivo nativos `.SCR`/`.LAY`/`.VTC`+`.ATC` em disco.

### 14g. Graphos III — Fase 7: menu MISCELÂNEA (2026-07-25, mesma sessão)

Pedido explícito do usuário: "Zoom, Shape, Corte, Grid" — as 4 ferramentas avançadas do manual original
(seção 3.2.5).

**GRID** (`GraphosScr_DrawGridOverlay`) — reinterpretação deliberadamente **não destrutiva**: o Graphos
III original altera de verdade a cor de PAPER de toda a tela pra desenhar a malha (limitação de
hardware de 1987, sem camada de renderização separada); aqui é um overlay de linhas finas cinza a cada
8 pixels, desenhado por cima do canvas a cada redesenho, **nunca** gravado em `PatternBit`/`RowFG`/
`RowBG`. Isso exigiu um redesenho "completo" novo — `GraphosScr_RedrawCanvasFull(Canvas, PatternBit,
RowFG, RowBG, Palette, ShowGrid)` — que chama `Scr2Ed_RedrawCanvas` e, se `ShowGrid`, desenha o overlay
em seguida; **as 31 chamadas diretas** a `Scr2Ed_RedrawCanvas(G_Canvas, ...)` espalhadas pelo arquivo
foram substituídas por essa função (find-and-replace mecânico, `GridVisible` já em escopo em todas —
mesma variável local da procedure principal), senão o overlay ficaria desatualizado a cada operação de
desenho.

**CORTE** — marca um retângulo (2 cliques, mesmo padrão âncora+prévia elástica de RETÂNGULO/SHAPE, mas
**sem** o alinhamento de 8px do SHAPE, já que CORTE só mexe em `PatternBit`, nunca em `RowFG`/`RowBG` —
fiel ao manual: "o usuário manipula e modifica os pixels de uma determinada parte da tela"):
- `GraphosScr_CorteInvert(PatternBit, X, Y, W, H)` — inverte cada pixel do recorte.
- `GraphosScr_CorteMirrorH`/`MirrorV` — espelha o recorte na horizontal ("E")/vertical ("R") do manual,
  trocando pares de colunas/linhas dentro do recorte.
Deliberadamente fora: "TECLAS DO CURSOR deslocam o corte" do original (arrastar uma seleção flutuante
pela tela) — mesma simplificação já aplicada em TEXTO/SHAPE (clique fixa o resultado, sem um passo
extra de mover-e-confirmar).

**SHAPE (carimbo)** — usa o shape **já carregado na barra de projeto Shape** (Fase 5, seção 14e);
nenhuma UI de seleção nova precisou ser criada. `GraphosScr_StampShape(PatternBit, RowFG, RowBG,
ShapePattern, ShapeFG, ShapeBG, DestX, DestY, ShapeW, ShapeH, Mode)`:
- **MÁSCARA** (`#GraphosStampMode_Mascara`) — cola pixels **e** cores do shape, substituindo tudo
  ("o shape se sobrepõe à tela, apagando o que está por baixo"). `DestX` precisa estar alinhado ao grid
  de 8px (mesma exigência da captura do SHAPE) pra colar as células de cor corretamente — por isso o
  destino do carimbo é sempre snapado (`(PX / 8) * 8`) antes de chamar `StampShape`, independente do
  modo escolhido (simplifica o modelo mental, mesmo que AND/OR/XOR não precisassem tecnicamente).
- **AND**/**OR**/**XOR** — lógica **só no bit do pixel**, nunca tocam `RowFG`/`RowBG` (fiel ao manual:
  "embora os atributos não sejam alterados") — onde um pixel novo acende nessas 3, ele usa a cor que a
  célula de destino já tinha. `AND = SPix & DPix`, `OR = SPix | DPix`, `XOR = Bool(SPix <> DPix)`.
- Ícones dos 4 modos (`GraphosScr_CreateStampModeIcon(Size, Mode)`) — 2 quadrados sobrepostos (shape
  azul, tela laranja) mostrando exatamente qual região lógica fica colorida em cada modo, em vez de 4
  ícones sem relação visual entre si.
- Posicionamento no mesmo padrão "Posicionar → prévia segue o mouse → clique fixa" de TEXTO
  (`GraphosScr_DrawStampPreview`, sempre mostra as cores próprias do shape independente do modo — é só
  um guia visual, o resultado real depende do modo escolhido na hora de carimbar).
- Deliberadamente fora: distinção de **TIPO** de shape do CRIA SHAPES original (seção 3.8 — só o TIPO 1
  permite escolher máscara/AND/OR/XOR pelas outras seriam diferentes); aqui todo shape aceita os 4
  modos uniformemente, simplificação deliberada já que o sistema de captura de Shape (Fase 5) não
  modela tipos.

**ZOOM** — reinterpretação simplificada: o original tinha 3 quadros de prévia (TELA/INK/PAPER) e modos
A(lterna)/S(eta)/R(eseta) de pixel escolhidos por tecla; aqui é só Lápis/Borracha, mesmo par já usado no
resto do editor. Fluxo: marca uma região (2 cliques, sem alinhamento de 8px — zoom só lê/escreve pixels
absolutos, não precisa de nenhum alinhamento de célula de cor) e `GraphosScr_OpenZoomWindow(ParentWin,
PatternBit, RowFG, RowBG, Palette, RegionX, RegionY, RegionW, RegionH, InkColor, PaperColor)` abre uma
**janela à parte** com seu próprio laço de eventos (`WaitWindowEvent`, modal em relação à janela
principal via `DisableWindow` — mesmo padrão de sub-janela já usado por `SpriteEditorGui`/
`CharsetEditorGui`), mostrando a região ampliada (fator de zoom calculado pra caber numa área de
~300×300px, clampado entre 2x e 24x). Como **arrays são passados por referência no PureBasic**, a
janela de Zoom escreve **direto** nos mesmos `PatternBit`/`RowFG`/`RowBG` da janela principal — não há
cópia nem "aplicar de volta": fechar o Zoom só exige 1 `GraphosScr_RedrawCanvasFull` na janela principal
pra refletir visualmente as edições que já aconteceram nos arrays compartilhados.

**Verificação**: compilação limpa (`.\build.ps1`) na primeira tentativa apesar do tamanho da mudança
(~700 linhas novas), aplicação executada (`.\build.ps1 -R`) sem erro em tempo de execução. Mesma
limitação de automação de clique ao vivo já registrada nas fases anteriores — verificado por revisão de
código cuidadosa da lógica de overlay/recorte/carimbo lógico/janela aninhada, mais execução do `.exe`
compilado para o usuário testar interativamente.

Com isso, **todos os 5 menus do Graphos III original (DESENHO/TEXTO/TELA/AJUSTE/MISCELÂNEA) estão
implementados** nesta IDE, ainda que com simplificações deliberadas documentadas em cada fase. Os
formatos de arquivo nativos (`.SCR`/`.LAY`/`.SHP`) em disco foram endereçados depois, ver seção 14i.

### 14h (tentada e revertida). Cursor de teclado

Uma tentativa de implementar as "TECLAS DO CURSOR" do Graphos III original (setas movendo um cursor
visível dentro do canvas, barra de espaço como clique, TAB pulando 8px, SHIFT/CONTROL alterando a
velocidade) foi feita e **revertida na mesma sessão** — o usuário testou e reportou que não funcionava
como esperado e que, com o mouse já disponível, a navegação por teclado dentro do canvas era
desnecessária. Removida por completo de `GraphosScreenGui.pbi` (nenhum vestígio de
`#PB_Canvas_Keyboard`/`CursorX`/`CursorY`/`TriggerClick` ficou no código); versão voltou a `7.5.11`. Não
reintroduzir esse padrão de interação sem um pedido explícito novo do usuário.

### 14i. Graphos III — Fase 9: formatos de arquivo nativos (.ALF/.LAY/.SCR/.SHP) (2026-07-25, mesma sessão)

Pedido explícito do usuário: entender os formatos nativos que o Graphos III de verdade grava em disco
(usando os visualizadores Python de referência em `graphos-IV/` — `alphabetV.py`/`layoutV.py`/
`screenV.py`/`shapeV_2.py`, gitignored, ver `.gitignore`) e permitir importar/exportar telas, layouts e
shapes nesses formatos, além da persistência já existente no projeto (Fase 5, seção 14e). Novo arquivo
`editor/GraphosNativeIO.pbi`.

**.ALF (alfabeto)** não precisou de nenhuma mudança — já implementado corretamente em
`CharsetEditorGui.pbi` desde antes desta fase (cabeçalho BSAVE de 7 bytes + 2048 bytes crus, base
`$9200`).

**Conversão de endereçamento VRAM** (`GraphosNative_Pack/UnpackPatternVram`, `Pack/UnpackColorVram`) — o
ponto central que os outros 3 codecs dependem: os arrays internos desta IDE (`PatternBit(Y,X)`,
`RowFG`/`RowBG(Y,Cx)`) usam ordem linha-a-linha simples, mas o hardware real do TMS9918 em SCREEN 2
divide a tela em 3 "terços" de 64 scanlines cada, e dentro de cada terço endereça 256 tiles de 8×8 —
`offset = terço*2048 + tile*8 + linha_do_tile`. Essa é a ordem que os arquivos `.LAY`/`.SCR` gravam em
disco; os dois procedimentos convertem nos dois sentidos.

**.LAY (layout, só padrão/pixels, sem cor)** — cabeçalho BSAVE (base `$9200`) + RLE restrito: cada byte
do arquivo tem um deslocamento de `+$99` (mod 256) somado por cima do valor real; só os valores reais
`$00`/`$FF` (branco/preto sólido, os mais comuns num desenho 1-bit) viram um par
marcador+contagem — qualquer outro valor é literal. `GraphosNative_SaveLay`/`LoadLay`.

**.SCR (tela completa)** — cabeçalho BSAVE + uma **rotina de apresentação Z80 de verdade** (copia os
dados pra VRAM quando o MSX executa `BLOAD"nome",R`) + 6144 bytes de padrão + 6144 de cor, em ordem real
de VRAM. Comparando várias amostras reais (`graphos-IV/III/*.SCR`, `graphos/Telas/MSX_310/*.SCR`)
descobriu-se que o tamanho dessa rotina **varia** entre arquivos (129 bytes numas, 121 noutras — parecem
programas ligeiramente diferentes, um deles com texto legível tipo "COMPACTA"/"IMPR" embutido, ainda não
decodificado a fundo) — por isso `GraphosNative_LoadScr` **nunca** confia no endereço-fim do cabeçalho
pra saber quantos bytes pular; calcula a partir do **tamanho real do arquivo em disco**
(`TamanhoArquivo - 7 - 12288`), já que os últimos 12288 bytes são sempre padrão+cor de tamanho fixo. A
rotina é sempre descartada sem ser interpretada (nunca executamos Z80 nenhum, só pulamos os bytes). Ao
exportar, gravamos sempre uma rotina de 129 bytes verificada byte a byte contra `graphos-IV/III/
GRAPHOS.SCR`/`STARWARS.SCR` (funciona de verdade num MSX real via `BLOAD"nome",R`), embutida com
`DataSection`/`Data.b` (mesmo padrão já usado por `DefaultCharsetMsx.pbi`).

**.SHP (banco de shapes)** — sem cabeçalho BSAVE, estrutura própria de blocos
`[K=número][T=tipo 1-4][S=largura em px][H=altura em tiles][dados]` terminada por `$FF`; tipos:
1=padrão, 2=padrão+cor, 3=máscara+padrão, 4=máscara+padrão+cor. `GraphosNative_ScanShpFile` mapeia todos
os blocos de um banco (offset/número/tipo/tamanho, sem ler a imagem) pra uma `List
GraphosNative_ShpEntry()`; `GraphosNative_LoadShapeAt` lê um shape específico já localizado.
Exportação (`GraphosNative_SaveShp`) sempre grava tipo 2 (padrão+cor, sem máscara — o carimbo MÁSCARA/
AND/OR/XOR da Fase 7 já cobre o uso prático) como banco de **um único shape**; a altura é arredondada
pra cima pro múltiplo de 8 mais próximo (tiles inteiros), já que a captura de shape desta IDE (Fase 5)
permite alturas em pixels não-múltiplas de 8. Importação de tipos 3/4 lê e descarta a máscara (nenhuma
ferramenta desta IDE usa máscara de shape ainda).

**UI**: dado o pouco espaço horizontal sobrando nas 3 barras de projeto (Tela/Layout/Shape — a barra já
termina a ~24-39px da borda da coluna direita, ver histórico de regressão de layout na Fase 5), em vez de
adicionar 2 botões de ícone por barra (não cabia), foi adicionado **1** botão por barra (ícone de
disquete, reaproveitando `GraphosScr_CreateSaveIcon`) que abre um `CreatePopupMenu`/`DisplayPopupMenu`
com "Importar.../Exportar..." — a seleção chega de forma assíncrona como `#PB_Event_Menu` no laço de
eventos principal (`DisplayPopupMenu` não bloqueia nem retorna a escolha diretamente), tratada num novo
`Case #PB_Event_Menu` com IDs 1-6 (2 por barra) pra desambiguar de qual das 3 barras a seleção veio, já
que os 3 popups compartilham o mesmo laço de eventos. Importação de Tela é "tudo" (pixels + cores);
importação de Layout mantém as cores atuais da tela (só pixels, mesma filosofia já usada pela navegação
de Layout no projeto - Fase 5); importação de Shape com mais de 1 entrada no banco pede o número (K) via
`InputRequester`.

**Verificação**: harness `editor/tools/GraphosNativeIOTestCli.pb` — round-trip completo (importa arquivo
real → exporta → reimporta → compara bit a bit) contra amostras reais já presentes no repositório
(`graphos/Layout/MSX_327/AFIF1.LAY`, `graphos/Telas/MSX_310/S-SHP01.SCR`,
`graphos/Shapes/MSX_092/PC-1.SHP`) — 24/24 checks OK, incluindo 0 diffs em todos os round-trips.
Cross-validado independentemente com um decodificador Python ad-hoc (fórmula de endereçamento VRAM +
RLE) que confirma visualmente (dump ASCII) uma imagem coerente, não ruído. Compilação limpa
(`.\build.ps1`) na primeira tentativa. Mesma limitação de automação de clique ao vivo das fases
anteriores para a parte de UI (popup/file requesters) — verificado por revisão cuidadosa da lógica de
posicionamento (linha do botão termina em X≈539, RightX=547) e pela bateria de testes do codec em si.

**Continua de fora** (simplificações deliberadas, sem mudança de escopo): a rotina de apresentação
"COMPACTA"/121-byte encontrada em alguns `.SCR` reais não foi decodificada a fundo (só descartada com
segurança no import); máscara de shape (tipos 3/4) é lida mas ignorada, sem ferramenta nesta IDE que a
use ainda; importação de banco `.SHP` com múltiplos shapes só carrega 1 por vez (sem uma lista/prévia de
todos os shapes do banco).

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

**Estado ao fim de 2026-07-25 (mesma sessão, o mais recente — ver módulo 14 acima pro detalhe completo
de cada fase) — Graphos III completo (Fases 1-7 e 9) + revert da Fase 8 + correção de nome de aba
"noname"**: nesta única sessão maratona, todo o **Graphos III** (`editor/GraphosScreenGui.pbi`) foi
implementado partindo do zero (Fase 1: tela+color clash) até cobrir os 5 menus do original
(DESENHO/TEXTO/TELA/AJUSTE/MISCELÂNEA, Fases 2-7) **mais** persistência no projeto (Fase 5:
Telas/Layouts/Shapes em `ProjectDB.pbi`) **mais** os formatos de arquivo nativos do MSX de verdade
(Fase 9: `.ALF`/`.LAY`/`.SCR`/`.SHP`, novo `editor/GraphosNativeIO.pbi` + harness
`editor/tools/GraphosNativeIOTestCli.pb`, 24/24 checks OK contra arquivos reais já presentes no
repositório). A única tentativa revertida foi a Fase 8 (cursor de teclado dentro do canvas — usuário
testou e achou desnecessário com o mouse já disponível, removido por completo, ver seção 14h). Fora do
Graphos III, uma correção pontual no editor de texto principal: as abas "noname" de documentos novos
não tinham extensão nenhuma no nome (`Docs()\UntitledName`); passaram a incluir a extensão real do modo
(`noname1.dmx`, `noname2.dmx`, ... ou `.asm` pra Assembly), evitando duplicar a extensão no diálogo
"Salvar como" (`editor/BadigEditor.pb`, procedures `AddDocumentTab`/`SaveDocument`). Versão embutida no
executável: **`7.5.12`**. **Importante para retomar em outra máquina**: das fases desta sessão, só as
Fases 1-3 estão commitadas (`8f1ce92`/`8797ad5`/`b483acf`) — Fases 4-9 e a correção do "noname" estavam
**sem commit** no fim desta sessão, nenhum `git commit`/`push` foi feito (por instrução padrão do
projeto, só commitar quando pedido explicitamente). Ver `docs/resumo-graphos.md` pra um resumo dedicado
dessa frente de trabalho, incluindo o que falta e como reproduzir os testes.

**Estado ao fim de 2026-07-25 (quarta sessão) — Graphos III, Fase 1 (tela + color clash)**: pedido
explícito do usuário para replicar o Graphos III (manual lido de `graphos/graphos.txt`), começando
pela "tela que representa a SCREEN 2" antes do resto do toolset (menus DESENHO/TEXTO/TELA/AJUSTE/
MISCELANEA, shapes, formatos de arquivo `.SCR`/`.LAY`/`.VTC`+`.ATC`) — ver módulo 14 acima pro detalhe
completo. Resumo: novo **Criar → Graphos III Screen 2...** (`editor/GraphosScreenGui.pbi`), zero motor
novo (reaproveita 100% do módulo 5 — `Screen2Synth.pbi`/`Screen2EditorGui.pbi` — e dos ícones/paleta do
editor de sprites), TRAÇO (Lápis/Borracha com arrastar contínuo) + LIMPA TELA como primeiras
ferramentas. Editor de alfabetos do Graphos III **não** entra aqui — já existe (módulo 4), pedido
explícito do usuário pra manter cada função do Graphos III como opção separada dentro de "Criar".
Ainda sem persistência no `.msxproject` (fica pro corte que definir o formato de conteúdo, depois do
toolset mais completo). Versão embutida no executável atualizada para **7.5.1**.

**Estado ao fim de 2026-07-25 (terceira sessão) — botão "Gerar .COM"**: pedido explícito do usuário
("vamos criar uma opção de gerar .COM, assim o assembler pode trabalhar independente do MSX BASIC")
logo depois do Assembly Sub Project — ver módulo 2c acima pro texto atualizado. Resumo: novo botão
**Gerar .COM (MSX-DOS, independente do BASIC)...** na janela "Saída da montagem"
(`Z80Out_ExportCom()`, `editor/Z80OutputGui.pbi`), reaproveitando `Z80Out_WriteBinFile()` sem nenhuma
mudança (o "binário cru" já gravado desde a sessão anterior já era um `.COM` válido quando `ORG 100h`)
— só formaliza esse caminho como opção de primeira classe, com aviso (não bloqueante) se o endereço de
montagem não for `0100h`. Vale pros três pontos de entrada que já usam essa janela (Montar Assembly,
Linkar, Assembly Sub Project). Versão embutida no executável atualizada para **7.3.9**.

**Estado ao fim de 2026-07-25 (sessão seguinte) — Assembly Sub Project**: pedido explícito do usuário
logo depois de fechado o módulo 2/2b/2c ("no assembly, vamos criar uma opção Criar->Assembly Sub
Project... como se fosse um Makefile primitivo... ter opções de gerar LIBs e de adicionar estas libs
no projeto também") — ver módulo 2d acima pro detalhe completo. Resumo: `editor/Z80SubProject.pbi`
(motor: monta N `.asm` em `.REL` + linka + resolve `.REQUEST`) e `editor/Z80SubProjectGui.pbi` (janela,
**Criar → Assembly Sub Project...**), nova tabela `asm_subprojects` em `ProjectDB.pbi`. Achado real: a
extensão `.rel` é obrigatória pra qualquer coisa referenciada via `.REQUEST` (`Z80Link::
LResolveLibPath()` sempre anexa `.rel`, mesmo a um nome que já termine em `.lib`) — bibliotecas geradas
por **Criar → Biblioteca Z80 (.LIB)** (sessão anterior, extensão `.lib` sugerida) não funcionavam
sozinhas via `.REQUEST`; corrigido normalizando a extensão na hora de montar a pasta de biblioteca do
subprojeto (`Z80SubProj_StageLibraries()`), sem mudar `Z80LibGui.pbi`/`Z80Lib.pbi`. Suíte própria
`editor/tools/Z80SubProjectTestCli.pb` (4/4) reconstrói binários já validados contra `LK80.exe`
diretamente a partir dos `.asm` originais. Versão embutida no executável atualizada para **7.3.7**.

**Estado ao fim de 2026-07-25**: as três lacunas restantes do módulo 2/2b/2c foram fechadas nesta
sessão (pedido explícito do usuário: "1-Menu de UI para o Linker/Lib, 2-Saida consumivel do assembler
para o MSX BASIC, 3 integracao do assembler com o sistema de projeto") — ver módulo 2b/2c acima pro
detalhe técnico completo. Resumo: `editor/Z80LinkGui.pbi` (**Executar → Linkar (.REL) → binário...**) e
`editor/Z80LibGui.pbi` (**Criar → Biblioteca Z80 (.LIB)...**) dão UI ao linker/biblioteca que já
existiam como motor desde a sessão de fechamento anterior; `editor/Z80OutputGui.pbi` centraliza a saída
consumível por MSX-BASIC (`.bin`/disco `.dsk` via `BLOAD`/listing `DATA`+`POKE`), reaproveitada tanto
pela montagem absoluta quanto pelo link; `ProjectDB.pbi` ganhou a tabela `asm_builds`. Único bug real
encontrado: conflito de deduplicação de `XIncludeFile "Z80RelFormat.pbi"` entre `Z80Asm.pbi` e
`Z80Link.pbi` quando os dois coexistem na mesma unidade de compilação (só aparecia agora, o CLI de
teste do linker nunca incluía `Z80Asm.pbi`) — corrigido com uma cópia dedicada,
`editor/Z80RelFormatLink.pbi`. Verificação: harnesses de console (`Z80AsmTestCli.exe` 67/67,
`Z80LinkTestCli.exe` sem regressão, `ProjectDBTestCli.exe` com a nova cobertura de `asm_builds`, todos
passando) e um script isolado confirmando a formatação exata do listing BASIC gerado; automação de GUI
ao vivo (`WM_COMMAND`/`PostMessage`) **não foi possível neste ambiente** — o processo do editor lançado
pelas ferramentas de shell abre numa sessão do Windows diferente da sessão onde o shell roda
(`FindWindow`/`PostMessage` não enxergam janelas de outra sessão), então a verificação da UI em si
ficou por revisão de código cuidadosa em vez de clique real, sem mudar a conclusão de que a lógica seja
direta e reaproveite padrões já validados nos demais editores. Versão embutida no executável atualizada
para **7.3.5**.

**Estado ao fim de 2026-07-24 (sessão de fechamento — Fase B do assembler, motor completo)**: módulo
2b (Linkstor80/Libstor80) saiu de "não iniciado" pra **motor completo** nesta mesma sessão —
`editor/Z80Link.pbi` (linker multi-`.REL`, incl. `.REQUEST`/biblioteca com linkagem estática seletiva e
resolução transitiva) e `editor/Z80Lib.pbi` (gerenciador `.LIB`: `create`/`add`/`list`/`remove`), ambos
validados byte a byte contra `LK80.exe`/`LB80.exe` reais (mesma técnica de oráculo já usada no
assembler). Suíte própria `editor/tools/Z80LinkTestCli.pb` (7/7). Um bug real de assembler pego pela
validação end-to-end (`LD A,(externo)` não reconhecido como referência bare por causa dos parênteses no
operando) e uma limitação real confirmada no `LK80.exe` local (só enxerga o símbolo público do primeiro
programa de uma biblioteca `.REQUEST` multi-programa) — detalhe completo em `docs/resumo-asm.md`.
Documentação atualizada em todos os `*.md` do projeto (este arquivo, módulo 2b acima; `README.md`;
`docs/MANUAL.md` seção "Assembler Z80"). Falta só a integração de menu no editor (hoje é engine/CLI de
teste, sem UI) — ver checklist Fase B em `docs/resumo-asm.md`. Versão embutida no executável atualizada
para **7.3.3**.

**Estado ao fim de 2026-07-24 (sessão do assembler Z80)**: módulo 2 (assembler Z80) saiu de "zero
código de motor" pra **Fase A completa** — ver módulo 2 acima e `docs/resumo-asm.md` (documento de
acompanhamento dedicado desta frente, criado nesta sessão, com o detalhe completo de decisões
técnicas/bugs/gotchas de PureBasic encontrados). Resumo: avaliador de expressão, parser de linha,
tabela de opcodes Z80 completa (documentados + `IXH`/`IXL`/`IYH`/`IYL` indocumentados comuns), driver
de 2 passes absoluto, diretivas de dados, condicionais e macros básicas — tudo validado byte-a-byte
contra o `N80.exe` real (Nestor80 compilado localmente, usado como oráculo de teste) via dois arquivos
de regressão novos, `sample/teste_opcodes.asm` e `sample/teste2_macros.asm`. Integrado ao editor via menu
**Executar → Montar Assembly (.bin)...** (`Ctrl+F5`). Pedido do usuário durante a sessão: Linkstor80
(linker) e Libstor80 (gerenciador de biblioteca, linkagem estática seletiva) também entram no escopo
do módulo — ver módulo 2b e o checklist de Fase B em `docs/resumo-asm.md` (ainda não iniciada).
Versão embutida no executável atualizada para **7.3.1**.

**Estado ao fim de 2026-07-24 (sessão do editor gráfico)**: módulo 5 (editor gráfico SCREEN 2) implementado do zero nesta sessão —
ver seção 5 acima para o detalhe completo (motor/color clash, 7 ferramentas, STEP/`LINE -(x,y)`, TEXTO
com quadro elástico, persistência, geração de código, 69 casos de harness). Também nesta sessão:
`editor/AquarelaCharsetEditorGui.pbi` ampliado de 32 para 46 caracteres editáveis (dígitos `2-9` e
`. : - ( ) ,` que faltavam), e o editor de alfabetos Graphos III ganhou os 11 botões de efeito em lote
documentados na seção 4c (a spec desse trabalho já estava registrada; só a entrada narrativa aqui
faltava). Versão embutida no executável: `7.1.1`.

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

**Próximo passo sugerido (ainda não decidido com o usuário)**: com o módulo 2 (assembler Z80) tendo
saído da estaca zero, os candidatos que restam sem nenhum código de motor são: **Fase B do assembler**
(módulo 2b — `.REL`/Linkstor80/Libstor80, ver `docs/resumo-asm.md`), editor char/tile (módulo 4 — a
parte de sprite já está pronta, char continua com a lacuna de conteúdo original não recuperada),
estender o sistema de projeto (módulo 13) para Basic/Assembly/demais tipos de conteúdo, ou aprofundar
o módulo 12 (input simulado em runtime, detecção de erro com retorno à linha no editor — o cuidado já
registrado sobre suporte a Windows incerto para a parte de detecção de erro continua valendo).
