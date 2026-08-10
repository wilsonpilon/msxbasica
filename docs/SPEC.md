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
| 1 | Editor MSX BASIC (base) | — | **Em código** (`editor/BadigEditor.pb`). **Arquivo → Salvar Tudo implementado (2026-08-08)**, ver seção 1b |
| 2 | Assembler Z80 (2 passes, nativo) | médio-alto | **Completo (2026-07-25)** — motor `editor/Z80Asm.pbi` (opcodes/expressões/diretivas/condicionais/macros básicas, saída absoluta e relocável `.REL`), validado byte-a-byte contra os oráculos `N80.exe`/`LK80.exe`/`LB80.exe` (Nestor80). Menu completo: **Executar → Montar Assembly (.bin)/relocável (.REL)/Linkar (.REL) → binário**, **Criar → Biblioteca Z80 (.LIB)/Assembly Sub Project** ("Makefile primitivo" — vários `.asm` + libs numa lista ordenada, monta tudo de uma vez, ver módulo 2d). Saída consumível por MSX-BASIC e MSX-DOS (`.bin`/`.com`/disco `.dsk`/listing `DATA`+`POKE`, módulo 2c) e sistema de projeto (`asm_builds`/`asm_subprojects` em `ProjectDB.pbi`). Detalhe em `docs/resumo-asm.md`, módulos 2b/2c/2d abaixo |
| 3 | Basic Dignified reescrito nativo | depende do escopo do original | **Completo (2026-07-15)** — `editor/DignifiedPreprocessor.pbi`, incluindo `INCLUDE` e remtags, ver módulo 3g |
| 4 | Editor sprite/char | baixo | **Sprite e alfabeto implementados (2026-07-19)** — `editor/SpriteEditorGui.pbi`/`editor/CharsetEditorGui.pbi`, ambos integrados ao sistema de projeto (módulo 13), ver seção 4. **Editor de alfabetos Aquarela (.FNT) implementado (2026-07-23)** — `editor/AquarelaCharsetEditorGui.pbi`, ferramenta autocontida baseada em arquivo, sem integração com o sistema de projeto, ver seção 4b. **Editor de alfabetos Graphos III ganhou 13 efeitos de edição em lote (2026-07-23)** — desfazer/refazer, marcar tudo, espelhar/girar/apagar/estreitar/itálico/negrito/largo (+ variantes bold e largo-bold), ver seção 4c. Tile (além do charset/fonte 8×8) ainda não iniciado |
| 5 | Editor gráfico LINE/CIRCLE/PSET/DRAW | baixo-médio | **Implementado (2026-07-24)** — `editor/Screen2Synth.pbi` (motor)/`editor/Screen2EditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 5 |
| 6 | Editor de som SOUND (PSG) | baixo | **Implementado (2026-07-21)** — `editor/PsgSynth.pbi` (motor)/`editor/PsgEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 6 |
| 7 | Tracker | alto | Só escopo geral, sem detalhe de UI/formato |
| 8 | Editor MML (comando `PLAY`) | médio | **Implementado (2026-07-21)** — `editor/MmlSynth.pbi` (motor)/`editor/MmlEditorGui.pbi` (janela), integrado ao sistema de projeto (módulo 13), ver seção 8 |
| 9 | Suporte a NestorBASIC | médio | **Implementado (2026-07-27)** — `editor/NestorBasicSupport.pbi` (template com loader + 87 wrappers `.NB_*`) + `editor/NestorBasicHelpData.pbi`/`NestorBasicHelpGui.pbi` (janela de ajuda). Abordagem real ficou mais simples que a spec original desta seção (texto colado, sem extensão de sintaxe no pré-processador), ver seção 9 abaixo |
| 10 | Dialeto msxbas2rom / geração de ROM | médio | Definido como back-end opcional (seção 8) — **usuário disse "só se valer a pena"** |
| 11 | Saída tokenizada (.bas tokenizado) | baixo (bem documentado) | **Implementado e verificado** — `editor/MsxTokenizer.pbi`, ver detalhe abaixo |
| 12 | Controle do openMSX via socket | médio (alto no item de detecção de erro) | **Parcial (2026-07-16)**: gerar disco + abrir o openMSX já rodando o programa está implementado, mais uma CLI `--diskmanipulator` standalone embutida no `.exe`; controle via socket/XML, input simulado e detecção de erro em runtime ainda não |
| 13 | Sistema de projeto (arquivo `.msxproject`, SQLite) | baixo-médio | **Implementado (2026-07-18), estendido (2026-07-19)** — `editor/ProjectDB.pbi`, ver seção 13. Sprites, alfabetos, cópia das abas de texto e diretório de trabalho já ligados; **Salvar projeto/Salvar projeto como...**; "projeto 0" de defaults sempre em memória. Demais tipos de conteúdo entram quando tiverem editor próprio. **2026-08-10**: projeto ganhou resincronização/restauração automática dos fontes BASIC/Assembly entre disco e `.msxproject`, pra poder levar só o arquivo de projeto de uma máquina pra outra — ver seção 13 |
| 14 | Graphos III — edição de telas SCREEN 2 (`Criar → Graphos III Screen 2...`) | alto (várias fases) | **Fase 1: tela + color clash (2026-07-25)** — canvas SCREEN 2 fiel ao hardware (reaproveita `Screen2Synth.pbi`/`Screen2EditorGui.pbi` do módulo 5 sem nenhuma mudança), paleta INK/PAPER, ferramentas TRAÇO (Lápis/Borracha) e LIMPA TELA. **Fase 2: resto do menu DESENHO (2026-07-25, mesma sessão)** — BLOCO/LINHA/RETÂNGULO/RAIO/CÍRCULO/PINTURA/SPRAY/FILL, ver seção 14b. **Fase 3: menu TEXTO (2026-07-25, mesma sessão)** — escreve na tela com um alfabeto do projeto, 6 variações (NORMAL/ITALIC/BOLD/DUPLO/DUPLO BOLD/LARGO), ver seção 14c. **Fase 4: menu TELA + reorganização de layout (2026-07-25, mesma sessão)** — SALVA TELA/Restaurar, INVERTE VIDEO/ATRIBUTOS, RETIRA/REPOE VIDEO/ATRIBUTOS, todos com ícone; coluna direita e faixa abaixo do canvas reequilibradas, ver seção 14d. **Fase 5: persistência no projeto (2026-07-25, mesma sessão)** — Telas/Layouts/Shapes no `.msxproject` via `ProjectDB.pbi`, mesmo padrão número/navegação/tag/Novo/Registrar do editor de sprites/alfabetos, ver seção 14e. **Fase 6: menu AJUSTE (2026-07-25, mesma sessão)** — SCROLL/ROTAÇÃO, 1px e 8x8, 4 direções, ver seção 14f. **Fase 7: menu MISCELÂNEA (2026-07-25, mesma sessão)** — ZOOM (janela à parte), SHAPE (carimbo com 4 modos lógicos), CORTE (Inverter/Espelhar), GRID (overlay não destrutivo), ver seção 14g. **Fase 8 (2026-07-25, mesma sessão): cursor de teclado — tentada e revertida**, ver seção 14h (usuário achou desnecessária com o mouse já disponível). **Fase 9: formatos nativos .ALF/.LAY/.SCR/.SHP (2026-07-25, mesma sessão)** — importar/exportar telas/layouts/shapes no formato binário que o Graphos III de verdade grava em disco (`editor/GraphosNativeIO.pbi`), verificado por round-trip contra arquivos reais (`editor/tools/GraphosNativeIOTestCli.pb`), ver seção 14i. Réplica do **Graphos III** original (`graphos/graphos.txt`, manual completo) — escopo desta IDE cobre só telas/shapes/layout (o editor de alfabetos do Graphos III já existe, módulo 4). **Todos os 5 menus do original (DESENHO/TEXTO/TELA/AJUSTE/MISCELÂNEA) + os formatos de arquivo nativos estão implementados.** Ver seções 14/14b a 14i |
| 15 | Sistema de Ajuda MSX BASIC (dicionário + manual, MSX1 e MSX2+) | médio | **Implementado (2026-07-27)** — `editor/MsxBasicHelpGui.pbi` (menu **Ajuda → MSX BASIC...**), reaproveitando a infraestrutura de navegação/busca/histórico de `NestorBasicHelpGui.pbi`. MSX1: 141 palavras reservadas (`MsxBasicDictData.pbi`) + prosa/tabelas do livro Gradiente (`MsxBasicManualData.pbi`). MSX2+: 45 verbetes extras/estendidos (`MsxBasic2PlusDictData.pbi`) + 7 tópicos de prosa/apêndices do manual ACVS FM (`MsxBasic2PlusManualData.pbi`). Ver seção 15 |
| 16 | Ajuda do Basic Dignified (sintaxe + configurações desta IDE) | baixo-médio | **Implementado (2026-07-28)** — `editor/BasicDignifiedHelpData.pbi` (menu **Ajuda → Basic Dignified...**), reaproveitando a mesma infraestrutura de `NestorBasicHelpGui.pbi`. 21 tópicos em 4 grupos, compilados a partir de `basic-dignified/documentation/*.md` (Basic Dignified Suite original) cruzados com o código real desta IDE — diz explicitamente quais campos de `Configurar → Basic Dignified...` afetam a conversão hoje e quais são vestigiais. Ver seção 16 |
| 17 | Editor Hexa genérico | baixo-médio | **Implementado (2026-07-29), reconhecimento estendido (2026-08-07)** — `editor/HexEditorGui.pbi` (menu **Executar → Editor Hexa...**): abre qualquer arquivo, grade offset/hex/ASCII rolável, edição byte a byte, reconhece formatos nativos da IDE (BLOAD/BSAVE, tokenizado, boot sector FAT12) com galeria de templates persistida em JSON, operações de bloco (preencher/inserir/sobrepor/excluir) e rolagem customizada. **2026-08-07**: reconhece também executável MSX-DOS (`.COM`), diferencia texto ASCII puro de BASIC clássico numerado, **planilha SuperCalc 2 MSX (`.CAL`)** — assinatura + título + início da seção de dados, validado contra 6 arquivos `.CAL` reais (ver `docs/reference/supercalc2-cal-format.md`) —, **banco de dados dBase II (`.DBF`)** — formato totalmente decifrado (cabeçalho + descritores de campo + registros), validado registro a registro contra um `.DBF` real (ver `docs/reference/dbase2-dbf-format.md`) — e **os 4 formatos nativos do Graphos III (`.ALF`/`.LAY`/`.SCR`/`.SHP`)**, reaproveitando a spec já validada em `GraphosNativeIO.pbi` (módulo 14i), validado em lote contra ~4100 arquivos reais do repositório (97-100% reconhecidos, ver seção 17); WordStar/MSX-Word seguem pendentes. |
| 18 | Integração de toolchains externas: MSXBas2Rom e N80/LinkStor80/LibStor80 | médio-alto | **Implementado (2026-08-01)** — download direto do GitHub, Ajuda gerada a partir do conteúdo baixado, destaque de sintaxe estendido. **2026-08-10**: motor Dignified ganhou um modo MSXBAS2ROM (vocabulário estendido protegido contra encurtamento de variável, diretivas `FILE`/`TEXT` sem número de linha), novo **Executar → Compilar ROM (MSXBas2Rom)...** que chama o `msxbas2rom.exe` configurado, e **Configurar → Projeto...** (config por projeto pras 3 telas globais). Ver seção 18 |
| 19 | Inserir → Caractere Especial (mapa de caracteres MSX) | baixo | **Implementado (2026-08-04)** — `editor/CharMapGui.pbi`, novo menu de topo **Inserir**. Grade estilo "Mapa de Caracteres" do Windows com os 159 caracteres que `-tr` traduz pra ASCII nativo MSX. Ver seção 19 |
| 20 | Editor de tela SCREEN 0 estilo TheDraw/AcidDraw (`Criar → Screen 0...`) | médio | **Implementado (2026-08-04), estendido (mesma sessão)** — `editor/Screen0EditorGui.pbi`, integrado ao sistema de projeto (módulo 13, tabela `screen0_screens`). Grade de caracteres 40/80×24, INK/PAPER único pra tela inteira (fiel ao hardware, sem cor por célula), fonte padrão ou do banco de alfabetos, 7 ferramentas (Texto/Caractere/Quadro/Sombra/Bloco/Borracha/**Atributo**). **Em 80 colunas, segunda cor de texto real do MSX2+ (modo T2)** — estática (travada) ou piscante, velocidade configurável, via `VDP(13)`/`VDP(14)` + tabela de pisca de verdade do VDP. Primeira de uma família de 3 editores — **completa** desde o módulo 22, ver linhas abaixo |
| 21 | Editor de tela SCREEN 1 estilo TheDraw/AcidDraw (`Criar → Screen 1...`) | médio | **Implementado (2026-08-05)** — `editor/Screen1EditorGui.pbi`, integrado ao sistema de projeto (módulo 13, tabela `screen1_screens`). Mesma grade 32×24 e mesmas 6 ferramentas do módulo 20, mas com a Color Table real do SCREEN 1 (1 par tinta/fundo por grupo de 8 códigos de caractere, `&H2000`) — tabela ASCII de 256 células com o bitmap real de cada código já pintado na cor do seu octeto. Ver seção 21 |
| 22 | Editor de tela SCREEN 1+2 — Color Table real do SCREEN 2, 3 alfabetos, cor por linha de scanline (`Criar → Screen 1+2...`) | alto | **Implementado (2026-08-05), estendido (mesma sessão)** — `editor/Screen12EditorGui.pbi`, integrado ao sistema de projeto (módulo 13, tabela `screen12_screens`). Terceira e mais complexa da família: `SCREEN 2` de verdade, 3 alfabetos (1 por terço de 8 linhas de tela) e cor por LINHA DE SCANLINE de cada código (8 cores/glifo, color clash real do hardware). Correção de UX real (linha-guia + seletor de terço acompanhando o clique no canvas) e escolha de bloco por 2 cliques na tabela ASCII + botões de reset de cor, ambos no mesmo dia do lançamento. Ver seção 22 |
| 23 | Ajuda SEE Tracker — estudo do formato SEE/.SEE (`Ajuda → SEE Tracker...`) | baixo (estudo) | **Implementado (2026-08-06)** — `editor/SeeTrackerHelpData.pbi`/`SeeTrackerHelpGui.pbi`, manual original + formato de arquivo `.SEE` + mecanismo real do driver de replay (`see/SEE3PLAY.ASC`). Preparou o terreno pro tracker de verdade, construído na sequência da mesma sessão — ver módulo 24 |
| 24 | Editor SEE Tracker — efeitos sonoros compatíveis com .SEE (`Criar → SEE Tracker...`) | alto | **Implementado (2026-08-06), estendido (mesma sessão)** — `editor/SeeTrackerEditorGui.pbi` (janela) + `editor/SeeTrackerSynth.pbi` (modelo de dados/interpretador/gerador/**importador**) + `editor/SeeTrackerDriverAsm.pbi` (porta do driver de replay, montada em tempo real pelo assembler Z80 nativo, `editor/Z80Asm.pbi`). Integrado ao sistema de projeto (módulo 13, tabela `see_sfx`). **Importar .SEE...** lê arquivos reais do editor original (validado contra `see/FIREBIRD.SEE`, 33 SFX). Ver seção 24 |
| 25 | Auto completar ("Palpiteiro") — MSX-BASIC/Dignified e Assembly | médio | **Implementado (2026-08-08)** — sugestões via popup nativo do Scintilla (`SCI_AUTOCSHOW`), disparadas ao digitar. Abas `.dmx`/`.bas`: palavras-chave clássicas + Dignified + MSXBAS2ROM (quando aplicável) + os 87 wrappers `.NB_*` do NestorBASIC + variáveis do documento; config em `editor/BasicOptionsSettings.pbi` (`Configurar → Basic Options...`). Abas `.asm`: mnemônicos/registradores/diretivas do Z80 (`Z80Asm.pbi`) + rótulos do documento; config em `editor/AssemblyOptionsSettings.pbi` (`Configurar → Assembly...`). Ver seção 25 |
| 26 | Internacionalização (i18n) da UI — inglês (e depois espanhol/holandês/italiano) | alto (mecânico, incremental) | **Planejado, não iniciado (2026-08-08)** — usuário pediu pra registrar a ideia antes de decidir quando começar. Escopo inicial: só a **UI** (menus/botões/diálogos), português continua existindo como opção, inglês é o padrão sem configuração salva; documentação (`*HelpData.pbi`/`*DictData.pbi`/`*ManualData.pbi`, ~13.500 linhas de prosa) fica pra depois, de propósito. Ver seção 26 |
| 27 | Fim do teclado WordStar/JOE + atalhos de teclado modernos | médio | **Implementado (2026-08-08)** — `editor/WordStarKeys.pbi` removido por completo (não só desligado); teclado do editor principal virou o padrão Scintilla/Windows. Buscar/Substituir/Ir para linha sobreviveram, portados pra `editor/EditorSearch.pbi` com atalhos convencionais (`Ctrl+F`/`F3`/`Ctrl+H`/`Ctrl+G`). Mais 22 atalhos novos cobrindo o resto da IDE (projeto, inserir, executar, criar). Ver seção 27 |
| 28 | Temas de cores (`Configurar → Editor...`) | médio | **Implementado (2026-08-08), reduzido pra 4 temas claros em 2026-08-10** — `EditorCfg\Theme` virou um de 4 IDs (Snow/Paper/Mist/Linen, todos claros — os 5 escuros originais foram removidos, contraste ruim contra controles nativos não-tematizáveis) em vez de um booleano Dark/Light; paletas desenhadas e aprovadas num mockup HTML fora do PureBasic antes de virar código. `editor_settings.json` antigo migra sozinho. Ver seção 28 |
| 29 | Botões tematizados em toda a IDE + ícones Nerd Font opcionais | alto | **Implementado (2026-08-08)** — `editor/ThemedButtons.pbi` (novo módulo compartilhado, nasceu como piloto no Editor Hexa): 293 botões em 33 arquivos deixam de ser `ButtonGadget` nativo (chrome do Windows, ignora `Color_*`) e viram imagens desenhadas na hora, seguindo o tema; mais de 140 ganham ícone real de uma Nerd Font quando configurada. Ver seção 29 |
| 30 | Base de conhecimento MSX embutida no Ajuda (7 janelas: Manuais MSX, MSX-Basic/DOS/CP-M, BIOS Chamadas/Hardware/Documentação, Livro Vermelho, MSX2 Technical Handbook) | alto | **Implementado (2026-08-10)** — ~3300 tópicos extraídos de `help/*.CHM` (RuMSX) + "The MSX Red Book" + MSX2 Technical Handbook (edições Markdown de terceiros) por scripts Python descartáveis; dois estilos de renderizador (monoespaçado vs. proporcional com link clicável de verdade via hotspot do Scintilla); 137 figuras originais (SVG→PNG e PNG direto) clicáveis em popup. Ver seção 30 |

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
- ~~NestorBASIC: tabela de aliases (função → número `USR`, parâmetro → posição em array `P`/`F$`),
  gerada como extensão do sistema de símbolos do Basic Dignified.~~ — **atualizado 2026-07-27**: a
  abordagem implementada de fato foi mais simples (ver módulo 9/seção 9 abaixo): em vez de estender o
  sistema de símbolos do pré-processador, `Arquivo → Novo Nestor Basic...` cola um texto Basic Dignified
  pronto (loader + biblioteca de wrappers `.NB_*` com `func`/`ret`) direto na aba nova — os `p(n)`/`usr(n)`
  crus ficam escondidos dentro dos próprios wrappers, sem precisar de nenhuma diretiva nova no
  pré-processador nem de tabela de símbolos separada.

## Detalhe por módulo

### 1b. Arquivo → Salvar Tudo — implementado (2026-08-08)

`Ctrl+Alt+S` / **Arquivo → Salvar Tudo** (`#Menu_SaveAll`, `SaveAllDocuments()` em `editor/BadigEditor.pb`)
salva todas as abas abertas mais o projeto atual numa ação só.

- **Cada aba**: `SaveDocument(SaveAs.b = #False)` já existente só opera na aba **ativa no momento**
  (usa `ActiveTabPosition` direto, sem parâmetro pra apontar pra outra aba) — `SaveAllDocuments()`
  percorre `Docs()` chamando `SetActiveTab(Position)` antes de cada `SaveDocument(#False)`, e restaura
  a aba que estava ativa antes no final. Abas sem nome ainda pedem "Salvar como..." normalmente (mesmo
  caminho de `SaveDocument`); se o usuário cancelar esse diálogo numa aba, o loop continua salvando as
  demais em vez de abortar tudo (melhor esforço) — o retorno de `SaveAllDocuments()` indica se **tudo**
  foi salvo com sucesso.
- **Projeto**: só chama `SaveProject(#False)` se o projeto já tiver arquivo `.msxproject` permanente
  (nesse caso é barato/silencioso — mesmo guard interno de `SaveProject`) **ou** se o projeto ainda
  temporário ("noname") já tiver conteúdo de verdade (`ProjectDB::HasUnsavedContent()`, mesmo critério
  usado por `OfferSaveProject()`) — sem essa checagem, "Salvar Tudo" num projeto temporário vazio
  forçaria sempre um diálogo "Salvar projeto como..." só para salvar arquivos de texto soltos, o que
  seria surpreendente. Deliberadamente **sem** o diálogo de confirmação Sim/Não que `OfferSaveProject()`
  mostra antes de salvar — aqui o usuário já pediu explicitamente "salvar tudo", perguntar de novo
  "quer salvar?" seria redundante.
- Sem harness de teste dedicado — validado por compilação limpa + revisão de código (a lógica reusa
  inteiramente `SaveDocument`/`SaveProject`/`SetActiveTab` já existentes e testados, só a orquestração
  do loop é nova).

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

**Gap encontrado e corrigido (2026-08-01)**: a heurística acima só cobria o menu manual de tokenizar;
os fluxos "Executar -> BASIC" (F5) e "Executar -> Nestor Basic" chamavam `RunDignifiedPreprocessor()`
incondicionalmente (só checavam `Docs()\Mode = "ASM"`), então abrir um `.amx`/programa MSX-BASIC
clássico já numerado (com `GOTO`/`GOSUB` para número de linha, sem labels Dignified) e apertar F5
rodava o texto pelo pré-processador Dignified mesmo assim — que não reconhece números de linha como
já resolvidos e trata cada linha como se fosse texto Dignified sem label, prefixando sua própria
numeração na frente da numeração original (`"10 PRINT..."` virava `"20 10 PRINT..."`), quebrando o
programa. A checagem heurística de `SaveAsTokenizedNative()` foi extraída para
`LooksLikeClassicAscii()` e reusada em `RunBasicFromActiveTab()`/`RunNestorBasicFromActiveTab()`: se a
aba já contém ASCII clássico, o pré-processador é pulado e o texto vai direto para `Tok_Tokenize()`,
mesmo caminho que o `msxbatoken.py`/tokenizador original sempre suportou (aceita ASCII clássico puro,
com ou sem o restante do Basic Dignified Suite — ver `-asc` em `BATOKEN.md`).

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
`THEN`/`GOTO` (`-tg`), tradução Unicode→ASCII nativo MSX (`-tr`), maiusculização geral (`-ca`) e
tamanho de TAB configurável. `strip_spaces` (`-ss`) foi reinterpretado de forma pragmática — **revisado
2026-08-04, ver módulo 3h**: a versão original desta reinterpretação preservava um espaço entre
*qualquer* par de palavras adjacentes (conservador demais, deixava `SCREEN 2`/`FOR ZZ` intocados); a
versão atual só preserva o espaço quando removê-lo colaria dois números adjacentes ou faria nascer uma
palavra-chave diferente na fronteira (ex. `X`+`OR`→`XOR`) — continua não sendo garantido byte-a-byte
idêntico ao Python original, mas remove bem mais espaços cosméticos que antes.

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

### 3h. Bugs reais achados/corrigidos em `DignifiedPreprocessor.pbi` (2026-08-04)

Sessão motivada por um bug reportado pelo usuário (`-ss` deixava `for linha=0 to 191 step 10` como
`forzz=0to191step10` esperado virar, mas o pipeline gerava com espaços sobrando) que puxou o fio de
mais dois bugs reais e não relacionados entre si, achados investigando o primeiro.

**1. `Dig_StripSpaces_Piece` conservador demais (o bug original reportado)**: a reinterpretação
pragmática do `-ss` (ver módulo 3f) preservava um espaço entre *qualquer* par de átomos-palavra
adjacentes, achando (errado) que isso era necessário pra não gerar `PRINTA` a partir de `PRINT A`.
Rastreando o tokenizador de verdade (`Tok_TokenizeLineBody`/`MsxTokenizer.pbi`) até o fim: ele casa
palavras-chave por "maior prefixo primeiro" em **qualquer posição**, sem exigir fronteira de palavra —
exatamente por isso o truque clássico `FORI=1TO10` funciona no MSX real, e `PRINTA` tokeniza
corretamente como `PRINT`+`A`. O risco real é bem mais estreito: só quando colar dois átomos faz nascer
uma palavra-chave **diferente** bem na fronteira (ex. `X`+`OR`→`XOR`, ou `ERR`+`OR`→`ERROR`, que é ela
mesma uma palavra-chave distinta e mais longa que `ERR`). `Dig_BoundaryFormsKeyword()` (nova) varre essa
fronteira contra a lista de palavras reservadas (`Dig_IsReservedWord`, já existente) e só aí mantém o
espaço; caso contrário remove. Números adjacentes (`1 2`→`12`) continuam protegidos (`Dig_AtomIsNumeric`,
já existente) — só a regra letra-letra ficou mais permissiva.

**2. `CopyMap()` trava com mapa de origem vazio e elemento de 1-2 bytes (bug do PureBasic 6.40
instalado, não do código-fonte)**: confirmado com um repro isolado fora do projeto — `CopyMap()` num
mapa `.b()`/`.w()` (byte/word) **vazio** causa "Invalid memory access" no compilador 6.40 instalado
nesta máquina; mapas `.i()`/`.s()` vazios não têm o problema. `Dig_Keeps()` (toggle-rem, ver módulo 3)
é exatamente um mapa `.b()` que começa vazio sempre que o arquivo não usa nenhum `#toggle` — ou seja, no
caminho comum, batendo `DigTestCli.exe`/o próprio `RunOnOpenMSX()` em quase qualquer conversão real.
Sintoma: crash silencioso (access violation) ao converter, sem nenhuma mensagem de erro do pré-
processador. Contorno em `Dig_ProcessSource` (ambas as direções, salvar e restaurar): só chama
`CopyMap()` quando `MapSize()` do lado de origem é maior que zero; caso contrário `ClearMap()` no
destino já produz o mesmo resultado que um `CopyMap()` de origem vazia deveria produzir. Achado só
porque `DigTestCli.exe` foi recompilado e rodado de verdade nesta sessão (não só lido/inspecionado) —
o `.exe` já commitado no repo tinha sido compilado antes dessa regressão do compilador aparecer (versão
de PureBasic diferente na máquina que o gerou, provavelmente).

**3. `Dig_TransReplacement` sem o byte de escape `Chr(1)` (bug histórico real do port, não do
PureBasic)**: os 31 símbolos extras traduzíveis por `-tr` (carinhas/naipes/linhas tipo CP437, ver
`docs/reference/badig-msx-module.md`) viravam só uma letra solta (`"☺"` → `"A"`) em vez do escape de
dois bytes que o driver de tela do MSX espera (`Chr(1)` + letra — `Chr(1)` sinaliza "o próximo byte
escolhe um dos 31 gráficos especiais", evitando colisão com os códigos de controle de verdade que
ocupam a mesma faixa 1-31). Confirmado rodando o `badig.py` de referência de verdade (presente no repo
em `basic-dignified/`, não só lendo o código): `"☺"` converte pra bytes `01 41`, não pro byte `01`
sozinho nem pra letra `"A"` sozinha. A causa raiz do gap no port: `Chr(1)` é um caractere de controle
invisível, então sumia sem deixar rastro visual tanto no `c_replacements` do Python original quanto
neste `.pbi`, ao serem lidos num visualizador de texto normal — só apareceu inspecionando os bytes crus
dos dois arquivos lado a lado. Corrigido devolvendo `Chr(1) + <letra>` (letra hardcoded por símbolo,
igual ao original — a atribuição de letras **não** segue estritamente `"A" + (posição-1)`: as duas
últimas entradas, `╳`→`]` e `╱`→`\`, estão fora de ordem alfabética em relação às demais, confirmado
byte a byte contra o Python, então não dá pra calcular por fórmula). `Dig_TransReplacementOrder` (nova
global, os 31 símbolos na mesma ordem) foi extraída pra reaproveitar em `CharMapGui.pbi` (módulo 19) sem
retranscrever a lista uma segunda vez.

**4. Vários arquivos `.pbi` sem BOM UTF-8 (achado enquanto investigava o bug 3, bug de *ambiente*, não
do código-fonte em si)**: `editor/BadigEditor.pb` (arquivo raiz passado ao `pbcompiler.exe`) tem BOM;
14 arquivos `.pbi` incluídos via `XIncludeFile` e que contêm literais de string não-ASCII **não**
tinham — o `pbcompiler.exe` 6.40 instalado detecta a codificação **por arquivo incluído**, não por
unidade de compilação inteira, então sem BOM ele decodifica UTF-8 como Latin-1/CP1252, corrompendo
qualquer literal não-ASCII (foi assim que o bug 3 acima foi originalmente descoberto — o grid de
`CharMapGui.pbi` mostrava lixo em vez da tabela certa). Isso também corrompia **texto de ajuda visível
pro usuário**: 121 ocorrências da seta `→` (navegação de menu) em `OpenMsxHelpData.pbi` e exemplos com
linhas de caixa em `BasicDignifiedHelpData.pbi`. Corrigido adicionando BOM UTF-8 (só metadado, byte a
byte sem mudança de conteúdo) aos 14 arquivos: `BasicDignifiedHelpData.pbi`, `CharMapGui.pbi`,
`DignifiedPreprocessor.pbi`, `GraphosScreenGui.pbi`, `MmlSynth.pbi`, `MsxBasic2PlusDictData.pbi`,
`MsxBasicManualData.pbi`, `OpenMSXBridge.pbi`, `OpenMsxHelpData.pbi`, `SpriteEditorGui.pbi`,
`WordStarKeys.pbi`, `Z80Asm.pbi`, `Z80RelFormat.pbi`, `Z80RelFormatLink.pbi`, `Z80SubProject.pbi`. Nota
pra manutenção futura: qualquer novo `.pbi` que ganhe um literal de string não-ASCII precisa de BOM
UTF-8 (a maioria dos editores de texto adiciona automaticamente ao salvar como UTF-8 "com assinatura"/
"with BOM"; arquivos sem nenhum caractere não-ASCII não precisam, mas ganhar BOM de qualquer forma não
tem custo).

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

### 9. Suporte a NestorBASIC — implementado (2026-07-27)

**Spec original (pré-implementação)**, mantida aqui como contexto histórico — a ideia era estender o
pré-processador com uma sintaxe dedicada:
- Todas as funções do NestorMan/InterNestor Suite/InterNestor Lite passam por um único `USR` com array
  de parâmetros inteiros `P` (e array de strings próprio para arquivo/string) — padrão "uma função,
  várias posições de array", compatível com Turbo-BASIC.
- Sintaxe de definição no pré-processador cogitada:
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

**O que foi de fato implementado** ficou mais simples que essa spec: nenhuma sintaxe nova entrou no
pré-processador. Em vez disso, `editor/NestorBasicSupport.pbi` monta um texto Basic Dignified pronto
(loader + biblioteca inteira de wrappers `.NB_*`) que o menu **Arquivo → Novo Nestor Basic...** cola
direto numa aba nova (`AddDocumentTab("", NestorBasicTemplateText(), "DMX", "nbasic")`). Não há
highlighting dedicado — os wrappers já ficam visíveis como `func`/`ret` normais do Basic Dignified.

- **Fonte de referência**: `nestor/SRC/NBASIC/nbas111e.txt` (manual original do NestorBASIC 1.11, Nestor
  Soriano/Konami Man) — mapeamento completo de funções/parâmetros feito (resolve a lacuna "trabalho real"
  citada acima).
- **Loader** (rótulos `{NBasicLoad}`/`{VoltaNBasicLoad}` em `NestorBasicTemplateText()`): `BLOAD
  "NBASIC.BIN",R` seguido de checagem do código de erro em `p(0)`. Escrito com `GOTO` puro, nunca
  `func`/`ret` — achado do usuário: `BLOAD"...",R` mexe na pilha do BASIC, então um `GOSUB`/`RETURN` ao
  redor dessa chamada específica quebra (`RETURN` sem saber pra onde voltar). Os wrappers `.NB_*`
  continuam usando `usr()` puro (sem `BLOAD`), esses são seguros com `func`/`ret` normal.
- **87 funções (0-86)** organizadas em 3 tiers, cada uma um wrapper `.NB_NomeDaFuncao(...)`:
  - **Tier 1** (`NestorBasicLibraryText()`) — funções gerais (0-1), acesso a segmentos RAM (2-12), VRAM
    (13-25), disco (26-52).
  - **Tier 2** (`NestorBasicLibraryTier2Text()`) — compressão/descompressão gráfica (53-54), execução de
    programas BASIC guardados em RAM (55-57), execução de código de máquina/rotinas diversas (58-66),
    efeitos PSG (67-70), tocador Moonblaster (71-79).
  - **Tier 3** (`NestorBasicLibraryTier3Text()`) — controle de quantos segmentos o NestorBASIC aloca pra
    si (80), interação com NestorMan/InterNestor Suite/Lite (81-86).
  - Convenção: cada `.NB_*` devolve só o(s) valor(es) "principal(is)" da chamada, sempre com o código de
    erro por último; `.NB_ErrorText(codigo)` traduz o código para mensagem. Os demais resultados
    documentados no manual (ex. versão, DOS, VRAM em K) continuam disponíveis direto em `p()`/`f$()` logo
    após a chamada — os arrays globais não são copiados pelo wrapper, então "menos retornos que a
    definição original" nunca perde informação, é só preferência por brevidade no uso comum.
- **Decisão de entrega** (confirmada com o usuário): texto inteiro colado por aba, sem `INCLUDE`
  separado — `INCLUDE` só resolve caminho relativo ao arquivo salvo (ou absoluto), e uma aba nova ainda
  sem salvar (`Path=""`) não teria de onde puxar um `nestorbasic.dmx` externo.
- **Executar → Nestor Basic** (`RunNestorBasicFromActiveTab()`) — idêntico a **Executar → BASIC**, mas
  chama `RunOnOpenMSX(..., IncludeNestorBasic=#True)`, que copia `NBASIC.BIN`/`NBASIC.DAT` (de `res/`)
  para o disco `.dsk` gerado antes de abrir o openMSX — sem isso o `BLOAD` do loader falha dentro do
  emulador.
- **Ajuda → Nestor Basic...** (`editor/NestorBasicHelpData.pbi`/`NestorBasicHelpGui.pbi`) — janela de
  referência não-modal com árvore (grupos = seções do manual, funções numeradas como filhos) + busca
  (nome/número/grupo) + histórico (Alt+seta-esquerda). Conteúdo em Markdown bem limitado (`## `
  subtítulo, `**negrito**`, `` `código` `` inline) — mesma base de dados também gera
  `docs/reference/nestorbasic.md` via `NBHelp_ExportMarkdown()`, então editar o conteúdo em um lugar
  atualiza os dois ao mesmo tempo.

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

- **Status (2026-08-01): integração leve implementada** (pedido explícito do usuário) - bem mais simples
  que o pipeline "editores gráficos → dialeto msxbas2rom" desenhado acima (que segue não implementado,
  prioridade baixa como já estava): **Arquivo → Novo MSXBas2Rom...** (`MsxBas2RomTemplateText()`, ASCII
  clássico numerado - é o formato que o `msxbas2rom` real espera, não Dignified) e **Configurar →
  MSXBas2Rom...** (baixa o binário mais recente do GitHub + gera `Ajuda → MSXBas2Rom...`). Ver módulo 18
  para os detalhes (motor de download/Ajuda compartilhado com o N80/LinkStor80/LibStor80, achados sobre
  `-doc` não ser o que parecia, etc.) - não duplicado aqui de propósito.

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

- **Renumeração nativa + "criar .BAS" — implementado (2026-08-01)**, pedido explícito do usuário: dado
  ASCII clássico já numerado (mesma entrada de `SaveAsTokenizedNative()`), gerar um `.BAS` "padrão"
  MSX-DOS renumerado o mais compacto possível — sem simplesmente *adicionar* uma segunda numeração por
  cima da original (isso é o mesmo bug de duplicar números da correção anterior desta seção, "Gap
  encontrado e corrigido (2026-08-01)"), mas *substituindo* de fato os números e corrigindo todos os
  alvos de `GOTO`/`GOSUB`/`THEN`/`ELSE`/`RESTORE`/`RESUME`/`RETURN`/`RUN` (inclusive listas
  `ON...GOTO`/`ON...GOSUB` separadas por vírgula, com posições vazias `,,` preservadas) para apontar
  para a linha renumerada certa. Novas funções em `editor/MsxTokenizer.pbi`:
  - `Tok_RenumberAscii(SourceText, NewStart=1, NewStep=1)`: passe 1 mapeia número-antigo→número-novo na
    ordem do arquivo (números baixos tokenizam em menos bytes — `1..9` cabem em 1 byte contra 2-4 de
    números maiores, ver `isShortInt` em `Tok_ScanNumber` — por isso o padrão aqui é `1,1`, mais
    compacto que o `LineStart`/`LineStep` `10,10` do pré-processador Dignified, que existe pra
    numeração ser legível por humano, não é o objetivo aqui); passe 2 reconstrói cada linha via
    `Tok_RenumberLineBody()`.
  - `Tok_RenumberLineBody()`: **deliberadamente espelha o mesmo fluxo de controle de
    `Tok_TokenizeLineBody`** (casamento de comando por comando na ordem da tabela `Tok_Cmd`/reuso do
    `Tok_JumpSet` já existente, tratamento de literais `DATA`/`REM`/`'`/`CALL`/`_`, o mesmo "quirk" de
    identificador com prefixo de palavra-chave embutido tipo `TOTAL` → tokeniza como `TO`+`TAL`, mesmo
    texto na saída de qualquer forma) em vez de reimplementar um parser do zero — decisão deliberada:
    uma reimplementação simplificada arriscaria não reconhecer um `GOTO` de verdade (deixando o alvo
    velho intacto) ou, pior, reescrever um número que não é um alvo de jump (ex.: um literal dentro de
    `DATA`). Só o "emit" muda (texto em vez de hex) e a substituição do número em si.
  - **Bug real encontrado testando contra `sample/teste.dmx`** (mesmo suite de regressão do módulo 3a):
    `ON ERROR GOTO 0` é um idioma documentado do MSX-BASIC onde `0` é sentinela de "desliga tratamento
    de erro", não uma referência de linha real — a primeira versão falhava com "GOTO para linha
    inexistente: 0". Corrigido tratando alvo `0` como sempre passthrough (nunca remapeado, nunca erro)
    para os comandos remapeáveis; nunca colide com um número remapeado de verdade já que `NewStart`
    mínimo é 1.
  - Comandos do `Tok_JumpSet` que **não** são efetivamente remapeados (`AUTO`, `RENUM`, `DELETE`,
    `LIST`, `LLIST`, `ERL`): ficam de fora do subconjunto `Tok_IsRenumberTargetCmd()` de propósito —
    `RENUM`/`AUTO` têm o primeiro argumento como um número *novo* de destino (não uma referência
    existente) e os outros raramente aparecem embutidos na lógica de um programa (são comandos de modo
    direto); o número segue sendo consumido pela mesma sintaxe de jump (pra não confundir o resto do
    scanner) mas copiado sem alteração.
  - **Verificado** com um harness fora do projeto: casos sintéticos (GOTO/GOSUB básico, espaços
    redundantes colapsados, `ON X GOTO 10,,30` com posição vazia preservada, alvo inexistente rejeitado
    com erro claro, `REM`/`DATA` contendo texto parecido com `GOTO` intocado, variável `TOTAL`
    preservada) e, mais importante, o arquivo de produção real de ~900 linhas
    (`sample/teste.dmx` → ASCII clássico → renumerado): reduziu de 18241 para 18179 bytes tokenizados
    (números mais baixos = menos bytes) e batendo manualmente 4 referências cruzadas
    (`ON STOP GOSUB`/`RESUME`) contra a posição real de cada linha-alvo no arquivo.
  - Integrado em `editor/BadigEditor.pb` via novo item de menu **"ASCII clássico já aberto → renumerar
    e criar .BAS..."** (`SaveAsRenumberedBas()`), reaproveitando a mesma heurística de detecção de
    ASCII clássico de `SaveAsTokenizedNative()` (extraída para `LooksLikeClassicAscii()` na correção
    anterior desta seção). O diálogo de salvar aceita `.bas` (ASCII, extensão padrão MSX-DOS/MSX-BASIC,
    diferente da convenção interna deste projeto `.dmx`/`.amx`/`.bmx`), `.amx` (ASCII, convenção
    interna) ou `.bmx` (encadeia com `Tok_Tokenize()` sobre o resultado já renumerado).

- **"Executar → Renumerar..." — implementado (2026-08-01), pedido explícito do usuário**: equivalente
  nativo do comando `RENUM` real do MSX-BASIC (`RENUM [nova linha][,[linha antiga][,incremento]]`),
  diferente de `SaveAsRenumberedBas()` (sempre renumera o programa inteiro pra numeração mais compacta
  e exporta pra um arquivo novo) — este renumera o programa **digitado na aba, no lugar** (como o
  `RENUM` real faz ao vivo na máquina), com os mesmos 3 parâmetros do comando original coletados via 3
  `InputRequester()` sequenciais (mesmo padrão já usado em `WordStarKeys.pbi` pro "Ir para linha"):
  nova linha inicial (default `10`), incremento (default `10`), linha antiga a partir de qual renumerar
  (em branco = programa inteiro, igual ao `oldline` omitido no `RENUM` real).
  - `Tok_RenumberAscii()` ganhou um 4º parâmetro `OldLineFrom.i = 0`: linhas com número antigo menor
    que `OldLineFrom` mantêm o número **original intocado** (só entram no mapa `OldToNew` como
    identidade, pra remapeamento de `GOTO`/`GOSUB` que apontam pra elas continuar correto) — mesma
    semântica do "linhas antes de `oldline` não são renumeradas" do `RENUM` real. Validação nova: se a
    nova numeração escolhida fosse ficar menor ou igual ao maior número já preservado (colidindo com a
    ordem do programa), falha com erro claro em vez de gerar um programa com linhas fora de ordem —
    mesma recusa que o `RENUM` real faz.
  - **Já não precisou de nenhuma mudança no motor de resolução de jumps** (`Tok_RenumberLineBody()`) —
    o pedido do usuário de "usar mais de um passo pra renumerar corretamente GOTO/GOSUB/RESTORE/
    ON X GOTO/GOSUB/IF...THEN GOTO" já estava coberto pelo desenho de duas passadas da correção
    anterior desta seção (passe 1 mapeia número-antigo→novo percorrendo o arquivo inteiro antes de
    reescrever qualquer linha; passe 2 resolve cada alvo contra esse mapa já completo) — é exatamente o
    que permite um `GOTO` que aponta **para a frente** no arquivo (referencia uma linha que só vai
    aparecer/ser numerada depois) resolver corretamente, confirmado no teste sintético abaixo.
  - **Verificado** com harness fora do projeto: `RENUM` completo (`1000,,100`) com referência pra frente
    e pra trás, ambas resolvidas certas; `RENUM` parcial (`500,100,10`) preservando linhas antes da
    linha-antiga-100 com seus números originais E as referências que apontam pra elas; e o caso de
    colisão (nova numeração pequena demais esbarrando na faixa preservada) rejeitado com erro claro.
  - Escreve o resultado direto no `ScintillaGadget` da aba (`WriteSciText()`, sem
    `SuppressModifiedTracking` — a edição fica no histórico de undo normal do Scintilla e marca a aba
    como modificada pelo fluxo já existente de `#Event_Rehighlight`), não salva em disco sozinho -
    usuário revisa e salva com Ctrl+K D/Ctrl+Shift+S como qualquer outra edição.

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
   `RunProgram`, já que rodar o programa MSX de outro jeito não faz sentido). **Atualizado
   (2026-07-28)**: auditoria confirmou zero dependência de build ou runtime no diretório separado
   `msxDiskUtil/` (`editor/MSXDisk.pbi` é 100% self-contained, sem `XIncludeFile` externo) — um bug de
   `MatchesFAT11` sob Unicode (comparação por `Mid()`/`Asc()` por índice de caractere em vez de byte
   cru, que quebrava casamento por curinga tipo `extract *.BAS`) só tinha sido corrigido na cópia
   vendorizada; portado de volta para `msxDiskUtil/MSXDisk.pbi` antes da remoção. `msxDiskUtil/` foi
   removido do repositório nesta data.
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

**Não implementado ainda** (a fatia "difícil" do módulo): envio de input simulado durante a execução
(além do console manual — ver abaixo) e detecção de erro em runtime com retorno à linha certa no editor
— nenhuma das duas abordagens documentadas acima (script Tcl+convenção `CHR$(7)`, ou hook de erro via
`POKE`+breakpoint) foi implementada. O controle via named pipe (ver abaixo) cobre o caso manual; o fluxo
`RunOnOpenMSX()` (F5/"Executar → BASIC") continua sendo "gerar disco e abrir o openMSX já rodando", sem
`-control`, sem nenhuma comunicação de volta da emulação para a IDE.

**Painel de controle — menu "Executar → openMSX..." (implementado 2026-07-29, arquitetura corrigida no
mesmo dia, validado ao vivo 2026-07-30, unificado com `RunOnOpenMSX()` e ampliado pra 6 abas em
2026-08-08 — ver "Estado ao fim de 2026-08-08" mais abaixo pro detalhe completo)**:
`editor/OpenMSXBridge.pbi` (processo/protocolo) + `editor/OpenMSXConsoleGui.pbi` (janela). Desde
2026-08-08, `RunOnOpenMSX()` acima **usa esta mesma ponte** (via `OMSX_LoadDisk()`) em vez de lançar um
processo `RunProgram()` próprio — F5 e este painel controlam a mesma instância, não são mais processos
separados.

**Status: validado ao vivo contra o openMSX de verdade (2026-07-30)** — ver "Validação ao vivo" no
final desta lista. Anteriormente rotulado experimental (ver histórico logo abaixo) porque não havia um
binário openMSX disponível no ambiente onde a arquitetura foi escrita; confirmado nesta máquina contra
um openMSX 21.0 real (`C:\msx\openMSX\openmsx.exe`).

- **Primeira tentativa (não funcionou)**: `-control stdio` + `RunProgram(...#PB_Program_Write)`
  escrevendo comandos no stdin do processo, seguindo a doc oficial "Controlling openMSX from External
  Applications" à risca (incluindo o handshake `<openmsx-control>\n` antes do primeiro `<command>`).
  Nenhum comando surtia efeito nem gerava resposta no log, nem mesmo os botões Ligar/Desligar.
- **Causa raiz** (achada lendo o código de verdade, a pedido do usuário, em vez de só a doc): duas
  fontes cruzadas —
  1. `openmsx/openmsx/src/events/AdhocCliCommParser.cc` mostra que o parser real é uma máquina de
     estados byte-a-byte que só procura `<command>...</command>` em qualquer lugar do stream — **não
     exige handshake nenhum**, a doc estava incompleta/genérica nesse ponto.
  2. `openmsx/catapult/src/openMSXController.cpp`, método `Launch()`, bloco `#ifdef __WXMSW__`: o
     Catapult real **nunca usa `-control stdio` no Windows**. Ele usa `-control pipe:<nome>` — um named
     pipe dedicado só pra comandos de entrada (`CreateNamedPipe_` com `PIPE_ACCESS_OUTBOUND`, o mesmo
     processo conecta como cliente ao processar essa flag — `openmsx/openmsx/src/events/CliConnection.cc`,
     `PipeConnection::PipeConnection()`) — mantendo STDOUT/STDERR normais (pipe anônimo comum via
     `CreateProcess`+`STARTF_USESTDHANDLES`) só pra ler respostas/log. Ou seja: a metade "escrever no
     stdin" de `-control stdio` é a que não é confiável no Windows (motivo exato não documentado nem no
     próprio Catapult, só o workaround); a metade "ler do stdout" sempre funcionou normalmente.
- **Arquitetura atual** (`OpenMSXBridge.pbi`), espelhando exatamente o Catapult real:
  - `OMSX_Start()` cria um named pipe próprio (`CreateNamedPipe_`, `PIPE_ACCESS_OUTBOUND`, nome
    `BadigEditorOMSX_<pid>_<contador>`) **antes** de lançar o processo (o construtor de `PipeConnection`
    do openMSX tenta abrir esse pipe como cliente assim que processa `-control pipe:<nome>` — falharia se
    o servidor, nós, ainda não tivesse criado). Continua passando os mesmos `-machine`/`-ext<slot>` de
    `RunOnOpenMSX()`. `RunProgram(...#PB_Program_Open|Read|Error)` — **sem** `#PB_Program_Write` (não
    mexe no stdin de verdade do processo, igual ao Catapult).
  - `ConnectNamedPipe_()` bloqueia até o openMSX conectar — roda numa `CreateThread()` dedicada (mesma
    ideia exata de `openmsx/catapult/src/PipeConnectThread.cpp`) pra não travar a GUI. Assim que conecta,
    essa mesma thread manda o handshake `<openmsx-control>` + `unset renderer` (reverte pro renderer
    padrão — `-control` sobe com `renderer none`; nome fixo tipo `SDL` quebra em builds onde só existe
    `SDLGL-PP`, mesma lição do `InitLaunchScript()`/`player.py` do Catapult) + `set power on` (a máquina
    fica desligada sob `-control` — confirmado lendo `main.cc` do openMSX: `reactor.powerOn()` só roda
    quando `parseStatus == RUN`, não `CONTROL`) — evento-driven, sem timer fixo de "esperar 3 segundos"
    como na primeira tentativa.
  - `OMSX_SendCommand()`/`OMSX_ShowWindow()` escrevem via `WriteFile_()` direto no handle do named pipe.
  - Guarda o processo (`OMSX_Prog`) e o pipe (`OMSX_PipeHandle`) em `Global`s pra reaproveitar a mesma
    instância se o menu for aberto de novo.
- `OMSXGui_OpenWindow()`: log de saída (tags XML limpas, não é parser de verdade) + campo de comando
  (Enter ou botão) + atalhos Reset/Pausar/Continuar/Ligar/Desligar/"Mostrar janela" (`unset renderer` sob
  demanda) + botão "Ajuda" (abre a janela do módulo 12b abaixo, pra consulta sem sair do console). Modal
  em relação à janela principal (`DisableWindow`), mesmo motivo de toda outra janela secundária deste app
  (loop de eventos compartilhado — ver módulo do gerenciador de disco acima); fechar o console **não**
  mata o openMSX, só desconecta a janela (reabrir o menu reconecta na mesma instância).
- **Validação ao vivo (2026-07-30)**: novo harness `editor/tools/OpenMsxBridgeTestCli.pb` (mesmo padrão
  dos outros `editor/tools/*TestCli.pb` — stub mínimo de `BadigCfg` com só os 3 campos que
  `OpenMSXBridge.pbi` lê, `XIncludeFile` direto do módulo, sem puxar `BadigSettings.pbi`/GUI) sobe
  `OMSX_Start()` isolado contra `C:\msx\openMSX\openmsx.exe` (openMSX 21.0 real, instalado nesta
  máquina) e confirma: pipe conecta em ~300ms, o boot automático (`unset renderer` + `set power on`)
  funciona (janela do emulador aparece com o nome da máquina configurada, não fica em `renderer none`),
  e comandos manuais recebem replies corretos via `OMSX_Poll()` (`set power off`/`set power on` →
  `false`/`true`, `openmsx_info platform` → `mingw32`).
  - **Achado real no caminho, causa raiz documentada pra não repetir a investigação**: a primeira
    rodada de teste (rodando o harness direto de um terminal, sem cuidado nenhum) devolveu **0 bytes**
    de saída capturada em absolutamente tudo — nem o `<openmsx-output>` que o protocolo garante logo no
    handshake. Parecia um bug grave em `OMSX_Poll()`/`RunProgram`, mas não era: lendo
    `openmsx/openmsx/src/main.cc` (`EnableConsoleOutput()`, chamada logo no início de `main()`) —
    ```cpp
    if (AttachConsole(ATTACH_PARENT_PROCESS)) {
        freopen("CONOUT$", "w", stdout);
        freopen("CONOUT$", "w", stderr);
    }
    ```
    — o openMSX **sempre** tenta anexar ao console do processo pai e, se conseguir, reabre seu próprio
    `stdout`/`stderr` apontando pro console herdado (`CONOUT$`) — **descartando** o pipe anônimo que
    `RunProgram(...#PB_Program_Read|Error)` preparou pra capturar a saída. Isso só acontece quando o
    processo que chama `RunProgram()` (o pai do openMSX) tem um console de verdade anexado. Como o
    harness de teste, compilado como app normal e rodado direto de um terminal, tinha console,
    `AttachConsole` teve sucesso e a captura ficou cega. O `BadigEditor.exe` real **nunca** bate nesse
    caso: já chama `FreeConsole_()` antes de abrir qualquer janela/chamar `OMSX_Start()` (ver seção
    "CLI de disco embutida" acima) — sem console pra anexar, `AttachConsole` falha, o openMSX mantém os
    handles herdados via `STARTUPINFO`/`STARTF_USESTDHANDLES` e a captura funciona normal. Corrigido no
    harness chamando `FreeConsole_()` logo no início (reproduzindo o estado real do editor) e gravando
    o log num arquivo em vez de `PrintN` (sem console não dá pra imprimir) — com isso, os replies reais
    apareceram. **Lição pra qualquer ferramenta de teste futura que toque `RunProgram()` +
    `-control`/leitura de stdout do openMSX**: rodar sem console anexado (`FreeConsole_()` ou similar),
    senão o resultado "não capturei nada" é um falso negativo do ambiente de teste, não do código.

**Indicador de estado ao vivo (2026-07-30)**: `OMSX_PowerOn`/`OMSX_Paused` (`Global`s em
`OpenMSXBridge.pbi`) + `OMSX_StatusText()`, exibido no topo da janela do console
(`OpenMSXConsoleGui.pbi`, `G_Status`) como "Ligado/Desligado | Rodando/Pausado". Alimentado assinando
`openmsx_update enable setting` (comando real do openMSX, `GlobalCommandController.cc`,
`UpdateCmd::execute()`) logo no boot, ANTES de `set power on` (pra capturar a própria transição de
ligar, não só mudanças futuras) — toda mudança de qualquer `Setting` (incluindo `power`/`pause`) dispara
`Setting::notify()` (`settings/Setting.cc`), que gera
`<update type="setting" name="X">valor</update>` via `CliConnection::update()`. Diferente de só ler o
reply do comando que a própria janela mandou (que fica cego se o estado mudar por outro caminho — ex.
usuário pausando pela janela do próprio openMSX), essa assinatura reflete o estado real
independentemente de quem mudou. Parseado da linha CRUA (antes de `OMSX_CleanLine()` mutilar as tags)
por `OMSX_ExtractSettingUpdate()` — parser por substring, não XML de verdade, suficiente porque o
formato de `<update>` do openMSX é sempre fixo. Validado ao vivo (harness
`editor/tools/OpenMsxBridgeTestCli.pb`): `set pause on`/`off` e `set power off` refletem corretamente no
indicador.

**Bug real relatado pelo usuário, corrigido (2026-07-30)**: digitar um comando (ex. `set pause on`,
`set renderer` sem valor) e clicar "Enviar" não mostrava nenhum feedback, e nenhum comando seguinte
parecia surtir efeito. Isolado por teste direto do protocolo (`OpenMSXBridge.pbi` sozinho, via harness,
sem a GUI): a mesma sequência de comandos (incluindo `set renderer` sem valor, seguido de
`reset`/`set pause on`/`set pause off`/`openmsx_info platform`) recebeu replies corretos o tempo todo —
o pipe/protocolo nunca quebrou. Confirmado com o usuário: openMSX continuava respondendo normalmente,
só a JANELA do console é que parava de mostrar qualquer coisa nova. Causa: `OMSXGui_AppendLog()`
(`OpenMSXConsoleGui.pbi`) fazia `GetGadgetText()` (releitura completa do log) + `SetGadgetText()`
(regravação completa) a cada tick do timer de poll (150ms) — em algum ponto essa releitura passava a
devolver vazio (causa exata dentro do controle nativo do Windows não identificada; um teste isolado só
de `EditorGadget`/`GetGadgetText`/`SetGadgetText` em memória, sem openMSX nenhum, não reproduziu
truncamento até 120.000 caracteres acumulados, então não é um limite de tamanho simples), e a próxima
gravação então sobrescrevia tudo com só o texto mais novo. Corrigido trocando a assinatura de
`OMSXGui_AppendLog()`/`OMSXGui_Send()` pra receber/devolver o texto acumulado explicitamente (parâmetro
`Accum`/`LogAccum` na `Procedure` que chama `OMSXGui_OpenWindow()`), nunca mais lendo de volta do
widget — elimina essa classe inteira de bug, não só o sintoma pontual.

**"Inserir no openMSX" — digitar/colar texto no MSX (2026-07-30)**: a pedido do usuário ("crie uma
outra área de texto, permita colar texto nesta área e ao clicar em um botão inserir o texto no
openmsx"), replicando o mecanismo real do Catapult: `openmsx/catapult/src/InputPage.cpp`,
`InputPage::OnTypeText()`:
```cpp
wxString text = utils::tclEscapeWord(m_inputtext->GetValue());
m_controller.WriteCommand(wxT("type -- ") + text);
```
- Janela aumentada de 900×420 para 900×500 pra caber a nova área (`OpenMSXConsoleGui.pbi`): log
  reduzido de 276px pra 190px de altura, nova `EditorGadget` editável (SEM `#PB_Editor_ReadOnly` —
  aceita colar com Ctrl+V nativamente, nenhum código extra necessário) + botões "Inserir no openMSX" e
  "Limpar" logo abaixo.
- `OMSX_TypeText()` (novo, `OpenMSXBridge.pbi`) manda `type -- <texto escapado>` via
  `OMSX_SendCommand()`. `type` é um script Tcl embutido do openMSX (`share/scripts/type.tcl`), que
  delega por padrão pro comando nativo `type_via_keyboard` (`src/input/Keyboard.cc`,
  `KeyInserter::execute()`) — pressiona/solta teclas de verdade na matriz de teclado emulada, então
  `\r` dentro do texto vira Enter de verdade. `--` avisa o parser de flags do openMSX
  (`parseTclArgs`) que acabaram as opções tipo `-freq`/`-release`/`-cancel`, pra um texto começando com
  `-` não ser confundido com uma flag.
- `OMSX_TclEscapeWord()` (novo) replica `utils::tclEscapeWord()` do Catapult (`utils.cpp`) caractere por
  caractere, na mesma ordem (backslash primeiro, senão os escapes dos passos seguintes seriam escapados
  de novo): `\`→`\\`, quebra de linha→`\r` (CRLF do `EditorGadget` no Windows normalizado pra um só
  marcador antes), `$`→`\$`, `"`→`\"`, `[`→`\[`, `]`→`\]`, `}`→`\}`, `{`→`\{`, espaço→`\ `, `;`→`\;`.

**Segundo bug real, achado ao implementar o item acima (2026-07-30)**: nenhum comando — nem os já
existentes do console manual, não só o novo "Inserir no openMSX" — escapava `&`/`<`/`>` antes de
embrulhar em `<command>...</command>` (`OMSX_SendCommand()`). Lendo o parser de verdade do openMSX
(`openmsx/openmsx/src/events/AdhocCliCommParser.cc`) — uma máquina de estados byte-a-byte que decodifica
`&lt;`/`&gt;`/`&amp;`/`&quot;`/`&apos;`/`&#NN;` dentro de `<command>...</command>` — confirmou-se que:
- Um `<` cru (comum em BASIC: `IF X<10`) que não seja seguido exatamente por `/command>` faz o parser
  voltar pro estado inicial `O0` ("procurando `<command>`"), **descartando o resto do comando sem erro
  nenhum reportado**.
- Um `&` cru fora de uma sequência de entidade válida tem o mesmo efeito.

Ou seja, qualquer comando (digitado manualmente ou via `type --`) contendo esses caracteres já quebrava
silenciosamente, mesmo antes desta sessão — só não tinha sido notado porque nenhum teste anterior
mandou um comando com `<`/`&`. Corrigido com `OMSX_XmlEscape()` (novo, escapa `&` primeiro, depois `<`,
depois `>`) aplicado a todo `Cmd` dentro de `OMSX_SendCommand()` — mesma camada que o Catapult de
verdade já tem (`openMSXController.cpp`, `WriteCommand()`, `xmlEncodeEntitiesReentrant()`). Resultado:
duas camadas de escape empilhadas, mesma arquitetura do Catapult — `OMSX_TclEscapeWord()` (nível Tcl,
uma "palavra" só) aplicado primeiro pelo chamador (`OMSX_TypeText()`), `OMSX_XmlEscape()` (nível
transporte/wire) aplicado por último, sempre, dentro de `OMSX_SendCommand()` (protege até comandos
digitados manualmente no console, que nunca passam por `OMSX_TclEscapeWord()`).

Validado ao vivo (harness `editor/tools/OpenMsxBridgeTestCli.pb`, entrada
`10 PRINT "A<B & C>D"` + Enter + `RUN`): `OMSX_TclEscapeWord()` produziu
`10\ PRINT\ \"A<B\ &\ C>D\"` (espaços/aspas escapados, `<`/`&`/`>` intocados — corretos nesse nível,
não são especiais pro Tcl); `OMSX_XmlEscape()` sobre esse resultado produziu
`10\ PRINT\ \"A&lt;B\ &amp;\ C&gt;D\"` (agora sim `<`/`&`/`>` viram entidades). O comando foi aceito sem
erro pelo openMSX e o console continuou respondendo normalmente a um comando seguinte
(`openmsx_info platform` → `mingw32`) — confirma que o "bug silencioso" de fato existia e que a correção
resolve. **Não verificado ao vivo**: leitura visual da tela do MSX confirmando que o texto realmente
apareceu certo (`A<B & C>D`) após o `RUN` — o bridge não tem mecanismo de leitura de tela (ver
`OMSX_Poll()`, só lê stdout/replies, não framebuffer); só a camada de protocolo/parser foi confirmada.

### 12b. Ajuda → openMSX... — implementado (2026-07-29)

- `editor/OpenMsxHelpData.pbi` (dados) + `editor/OpenMsxHelpGui.pbi` (janela) — mesmo padrão exato das
  outras 3 janelas de Ajuda (`BasicDignifiedHelpGui.pbi`/`NestorBasicHelpGui.pbi`/`MsxBasicHelpGui.pbi`):
  árvore agrupada (grupo = `"<manual> - <seção>"`) + busca por título/grupo + histórico
  (Alt+seta-esquerda), reaproveitando o mesmo mini-Markdown/renderizador (`NBHelpGui_RenderMarkdown`).
  Sem hyperlink clicável dentro do corpo (a mini-Markdown não suporta isso, nem nenhuma das outras 3
  janelas) — a navegação entre tópicos relacionados é via árvore/busca, como no resto da Ajuda.
- Conteúdo: os 5 manuais originais do openMSX (`docs/openmsx-setup.html`/`-user.html`/
  `-diskmanipulator.html`/`-control.html`/`-commands.html` — Setup Guide, User's Manual, Using
  Diskmanipulator, Controlling openMSX from External Applications, Console Command Reference),
  convertidos de HTML pra mini-Markdown por um script Python descartável (não versionado) rodado uma
  única vez — 252 tópicos no total. Divertida em 7 `Build*()` (uma por manual, duas pro Manual do
  Usuário e duas pra Referência de Comandos — Comandos/Configurações, por volume), mesmo motivo de
  `NestorBasicHelpData.pbi` (`BuildDataDisk`/`BuildDataVram`/etc.): manter cada `Procedure` de tamanho
  razoável.
- **Limite real do PB encontrado**: uma cadeia de concatenação `"a" + "b" + ...` só com literais é
  constant-folded em tempo de compilação, e o literal resultante não pode passar de 8192 caracteres — um
  punhado de tópicos grandes (subseções `<h4>` sem `<h3>` próprio, mescladas no corpo do tópico pai)
  passavam disso. Corrigido dividindo esses corpos em múltiplas atribuições a uma variável `CBody`
  (variável no lado esquerdo quebra o fold puramente-literal) em vez de uma expressão única gigante.
- `OMSXHelp_ExportMarkdown()` gera `docs/reference/openmsx.md` a partir da mesma base de dados (mesma
  ideia de `NBHelp_ExportMarkdown()` em `NestorBasicHelpData.pbi`) — `editor/tools/OpenMsxHelpExportCli.pb`
  é uma ferramenta de linha de comando de verdade pra rodar de novo (`OpenMsxHelpExportCli.exe
  <saida.md>`), diferente do precedente do Nestor Basic (exportado uma única vez, sem ferramenta pra
  regenerar).

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

**Resincronização/restauração de fontes BASIC/Assembly (2026-08-10, pedido explícito do usuário)**: o
`.msxproject` já guardava uma cópia de cada aba de texto salva (`ProjectDB::StoreDocument()`, chamado
por `SaveDocument()` a cada `Ctrl+S`) — mas só nesse momento pontual, sem garantia de que o espelho
ficasse fresco em outros pontos, e sem nada que reconstituísse os arquivos no disco ao abrir o projeto
numa máquina onde eles não existem. Pedido do usuário: tornar o `.msxproject` **autocontido/portátil**
— levar só esse arquivo de um PC pro outro e os fontes "irem junto".

- **`ResyncProjectDocumentsFromDisk()`** (`BadigEditor.pb`) — lê o conteúdo REAL do disco (não o buffer
  do Scintilla, "pegar as versões que estão no disco" foi o pedido literal) de todo caminho que o
  projeto já conhece (`ProjectDB::ListDocumentPaths()`, novo) mais toda aba aberta na sessão atual, e
  regrava cada um via `StoreDocument()`. Chamada em 3 pontos: **Salvar projeto** (mesmo no caso comum
  onde a função normalmente não fazia nada, por já ser um SQLite "sempre gravado"), depois de um
  **Salvar projeto como...** bem-sucedido, e ao **encerrar o programa** (antes de `ProjectDB::Close()`).
  `Salvar Tudo` já cobre isso indiretamente — salva cada aba (que já chama `StoreDocument()`) e depois
  chama `SaveProject()`.
- **`RestoreMissingDocumentsToDisk()`** (`BadigEditor.pb`) — chamada depois de `ProjectDB::OpenExisting()`
  bem-sucedido: para todo documento que o projeto conhece mas cujo caminho gravado não existe no disco
  (o caso normal de abrir o MESMO `.msxproject` numa máquina diferente — unidade/usuário/pasta
  diferentes), extrai o conteúdo de volta pro disco. O destino é sempre **ao lado do `.msxproject` que
  está sendo aberto agora** (não o caminho absoluto antigo, que só faz sentido na máquina original) —
  só o nome do arquivo é preservado, garantindo que o projeto fique autocontido de verdade, sem depender
  da estrutura de pastas de onde foi criado. Quando o destino difere do caminho gravado, a linha da
  tabela `documents` é **re-chaveada** pro caminho novo (`ProjectDB::DeleteDocument()` do caminho antigo
  + `StoreDocument()` no novo) — sem isso, um `Salvar` futuro naquela mesma máquina criaria uma segunda
  linha com o caminho antigo, nunca mais alcançável. Não sobrescreve nada que já exista no destino (não
  arrisca perder um arquivo que o usuário já tenha ali por outro motivo). Avisa quantos arquivos foram
  restaurados via `MessageRequester`.
- **Escopo**: só documentos de texto (BASIC `.dmx`/`.amx`/`.bas` e Assembly `.asm`) — exatamente o que o
  usuário pediu. Sprites/alfabetos/telas/sons/músicas/`asm_builds`/`asm_subprojects` já vivem nativamente
  dentro do SQLite (nunca dependeram de um arquivo em disco pra existir), não são afetados.
- **`ProjectDB::ListDocumentPaths()`**/**`DeleteDocument()`** (novos, `ProjectDB.pbi`) — generalizações
  simples do padrão já usado por `ListSpriteNumbers()`/`StoreDocument()`. Testados no
  `editor/tools/ProjectDBTestCli.pb` (harness de regressão do módulo) — todos os testes novos e
  existentes passaram (achado incidental, não relacionado: um teste pré-existente e não tocado nesta
  sessão, `FetchDefaultAlphabet(0)` vs. `alfabetos\msx.alf`, já falhava antes por um caminho de arquivo
  incorreto no próprio harness — `alfabetos\ALF\msx.alf` é o caminho real — registrado aqui como débito
  técnico conhecido, não corrigido por estar fora do escopo pedido).

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

### 15. Sistema de Ajuda MSX BASIC (dicionário + manual, MSX1 e MSX2+) — implementado (2026-07-27)

Módulo não previsto nas seções anteriores — surgiu como pedido explícito do usuário: transformar dois
livros/manuais MSX de referência (digitalizados/lidos à parte) numa base de ajuda navegável dentro do
próprio editor, em vez de deixar o usuário procurar em PDF.

- **UI compartilhada** (`editor/MsxBasicHelpGui.pbi`, menu **Ajuda → MSX BASIC...**) — reaproveita a
  infraestrutura de renderização/navegação já escrita para `editor/NestorBasicHelpGui.pbi` (seção 9
  acima): `NBHelpGui_SetupStyles`/`_RenderMarkdown`/`_EmitRun` entendem a mesma marcação mínima (`## `,
  `**negrito**`, `` `código` ``). Layout idêntico ao da Ajuda do NestorBASIC (busca no topo, árvore à
  esquerda, conteúdo somente-leitura à direita, histórico Alt+seta-esquerda), janela não-modal — fica
  aberta enquanto o usuário edita.
- **Lista única "achatada"** (`MSXHelpGui_Rows()`, montada uma vez por sessão): junta duas listas
  heterogêneas — `MSXManual_Topics()` (tópicos de prosa/manual, agrupados por `Parte`) e
  `MSXDict_Keywords()` (dicionário de palavras reservadas, um grupo só "Parte II") — mais a página
  especial de cores, guardando o tipo de cada linha (grupo / tópico / palavra / cores) e o índice de
  volta pra lista de origem. `MSXHelpGui_SearchKey()` filtra por essa lista achatada.
- **MSX1** — fonte: livro *"Linguagem BASIC MSX"* (Denise Santoro Cruz, Editora Aleph/Gradiente, 1986).
  - `editor/MsxBasicDictData.pbi` — 141 palavras reservadas (`MSXDict_Add()`), campo `Sistema="MSX1"`
    automático.
  - `editor/MsxBasicManualData.pbi` — tópicos de prosa/tabelas: Parte I (estrutura do BASIC MSX), Parte
    III (aplicações especiais), Apêndices, mais `MSXColor_BuildData()` (as 16 cores do VDP, renderizadas
    como faixas coloridas por `MSXHelpGui_RenderColors` — único ponto que não usa o mini-Markdown
    genérico, porque precisa de uma cor de fundo por linha).
- **MSX 2+** — fonte: *"Manual MSX 2+ FM"* (Ademir Carchano/Flávio Monaco, ACVS Eletrônica), digitalizado
  em `docs/manual_msx2fm_acvs.pdf` (66 páginas).
  - `editor/MsxBasic2PlusDictData.pbi` — 45 verbetes, inseridos na **mesma lista única**
    `MSXDict_Keywords()` do MSX1 (decisão do usuário: não criar uma seção separada) via
    `MSXDict_Add2Plus()` (inserção alfabética ordenada, em vez do `AddElement` no fim usado por
    `MSXDict_Add()`). Comandos do MSX1 com comportamento estendido no MSX2+ (`SCREEN`, `COLOR`, `WIDTH`,
    `CIRCLE`/`DRAW`/`LINE`/`PAINT`/`POINT`/`PRESET`/`PSET`, `PAD`, `PDL`, `BASE`, `VDP`, `PLAY`) ganham um
    segundo verbete `"NOME (MSX2+)"` logo depois do original (a ordenação alfabética de string já garante
    isso: `"SCREEN" < "SCREEN (MSX2+)" < próxima palavra`). Comandos totalmente novos (`COLOR=`,
    `COLORSPRITE`, `COPY`, `SETPAGE`, `CALL MEMINI`, os comandos de música FM como `CALL MUSIC`/`CALL
    VOICE`, etc.) entram na posição alfabética correta. Campo `Sistema="MSX2+"` os distingue dos
    verbetes MSX1. `PaginaLivro` aqui se refere às páginas do manual ACVS, não do livro Gradiente —
    offset descoberto: página impressa no manual = página do PDF − 1.
  - `editor/MsxBasic2PlusManualData.pbi` — 7 tópicos de prosa/apêndices, cobrindo o que **não** é
    comando/função (isso fica no dicionário acima): apresentação do MSX2+ e legenda de sintaxe do manual
    (com uma categoria a mais que o livro Gradiente: COMANDO), apresentação do FM-Music, e os 4 apêndices
    A-D (programação de instrumentos, dicas/macetes, relação de instrumentos, exemplos de música).
    **Apêndice D é caso especial**: o manual traz duas músicas completas ("Unchained Melody" e "Theme
    From Over The Net") com listagens de strings de notas muito densas/concatenadas — em vez de
    transcrever nota a nota (alto risco de erro silencioso: um dígito trocado quebra a música sem gerar
    erro de sintaxe), o tópico **descreve** cada música (canais usados, instrumentos, técnica), a mesma
    lógica já aplicada à tabela ASCII completa e às formas de envelope do `SOUND` no dicionário MSX1.
  - **Cobertura verificada página a página contra o índice real do PDF (66 páginas)**: páginas 7-47 são
    comandos/funções (inteiramente no dicionário), páginas 5-6/37/48-53 são a prosa/apêndices acima,
    páginas 53-62 são as partituras (descritas, não transcritas), páginas 63-66 são certificado de
    garantia/contracapa (sem conteúdo de linguagem, nada a converter), páginas 1-4 são capa/índice. Não
    há lacuna real de conteúdo pendente.
- **Wiring**: `editor/BadigEditor.pb` inclui os 6 arquivos (`MsxBasicDictData.pbi`,
  `MsxBasic2PlusDictData.pbi`, `MsxBasicManualData.pbi`, `MsxBasic2PlusManualData.pbi`,
  `NestorBasicHelpData.pbi`, `NestorBasicHelpGui.pbi`) via `XIncludeFile`; `MSXManual_BuildData()`
  chama `MSXManual_BuildMSX2Plus()` e o equivalente do dicionário chama `MSXDict_BuildMSX2Plus()` — tudo
  já wired na janela de Ajuda, sem passo de registro adicional.

### 16. Ajuda do Basic Dignified (sintaxe + configurações desta IDE) — implementado (2026-07-28)

Pedido explícito do usuário: transformar `basic-dignified/documentation/*.md` (documentação oficial do
Basic Dignified Suite original, baixável pelo botão de download em `Configurar → Basic Dignified...`,
ver módulo 9) numa janela de ajuda navegável dentro do editor, cobrindo tanto a **sintaxe** do dialeto
quanto as **configurações** desta IDE.

- **UI** (`editor/BasicDignifiedHelpGui.pbi`, menu **Ajuda → Basic Dignified...**) — mesmo padrão de
  `MsxBasicHelpGui.pbi`/`NestorBasicHelpGui.pbi`: janela não-modal, árvore agrupada por `Grupo` + busca
  + histórico (`Alt+seta-esquerda`), reaproveitando `NBHelpGui_SetupStyles`/`_RenderMarkdown` sem
  nenhuma renderização própria — mais simples que `MsxBasicHelpGui.pbi` porque só tem uma fonte de
  dados (sem dicionário/página de cores misturados), então a lista achatada guarda só `IsGroup`/
  `RefIndex` em vez de 4 tipos de linha.
- **Dados** (`editor/BasicDignifiedHelpData.pbi`, `BDHelp_Add(Titulo, Grupo, Corpo)`) — 21 tópicos em 4
  grupos, escritos a partir da leitura completa dos 10 `.md` de `basic-dignified/documentation/`
  (`BASIC_DIGNIFIED.md`, `DIFFERENCES.md`, `DIGNIFIER.md`, `BATOKEN.md`, `COCOTOCAS.md`,
  `IDE_TOOLS.md`, `IMPLEMENTATIONS.md`, `INSTALLATION.md`, `MODULE_TOOLS.md`, `NEW_MODULES.md`):
  - **Introdução** (1 tópico) — o que é o dialeto, extensões `.dmx`/`.amx`/`.bmx`, regras gerais de
    formato.
  - **Sintaxe Dignified** (10 tópicos) — labels/loop labels, defines, variáveis longas/`DECLARE`,
    proto-funções `FUNC`/`RET` (incluindo o achado real já registrado em memória de sessão: `func`/
    `ret` precisa ficar depois do `end` do fluxo principal, senão o programa cai dentro da função sem
    ter sido chamada), separação/junção de linha, comentários/toggles, tradução Unicode, `INCLUDE`,
    `TRUE`/`FALSE` e operadores compostos.
  - **Configurar → Basic Dignified...** (6 tópicos) — cada campo das 3 abas da tela de configuração
    (`BadigSettings.pbi`), auditado contra o código real antes de escrever o tópico: confirmado por
    grep que `Dig_SyncConfigFromBadigCfg()` só sincroniza `LineStart`/`LineStep`/`RemHeader`/
    `TabLenght`/`StripSpaces`/`CapitalizeAll`/`Translate`/`ConvertPrint`/`StripThenGoto` — os 6
    checkboxes de relatório + `VerboseLevel` (aba 1), as 4 opções do tokenizador (aba MSX) e
    `EmSetting`/`EmMonitor`/`EmNoThrottle`/`EmVerbose` (aba Emulador) **não têm consumidor** hoje,
    dito explicitamente nos tópicos correspondentes em vez de simplesmente traduzir a doc original
    (que descreve o comportamento do `badig.py` em Python, nem sempre igual ao port nativo).
  - **Remtags** (3 tópicos) — o que são, e a lista exata das flags que `Dig_ApplyArgumentsRemtag()`
    realmente aplica via `##BB:arguments=` (`-tl -ls -lp -rh -ss -ca -tr -cp -tg`) vs. as aceitas e
    ignoradas (`-id -vb -prr -lbr -lnr -var -lex -par -asc -ini -rtg`), mais `export_file=`/`help=`.
  - **Sobre a suíte original** (2 tópicos) — ferramentas não portadas pra esta IDE (DignifieR de
    conversão reversa, integração Sublime/VSCode, suporte CoCo, arquitetura de novos módulos) e uma
    referência rápida do formato tokenizado `.bmx`.
- **Wiring**: `editor/BadigEditor.pb` inclui os dois arquivos via `XIncludeFile`, posicionados depois
  de `MsxBasicDictData.pbi` (usa a constante `MSXQ` de lá) e de `NestorBasicHelpGui.pbi` (usa
  `NBHelpGui_*` de lá); novo item **Ajuda → Basic Dignified...** entre **MSX BASIC...** e **Sobre...**.
- **Verificação**: compilado com sucesso (`build.ps1`) e testado com um lançamento smoke-test do
  `.exe` (processo permanece de pé, sem crash de inicialização) — sem automação de clique real na UI,
  pelos mesmos motivos já documentados no módulo 2 (sessão em janela de outro processo/sessão do
  Windows, inacessível a `FindWindow`/`PostMessage` a partir do shell).

### 17. Editor Hexa genérico — implementado (2026-07-29), reconhecimento estendido (2026-08-07)

Pedido explícito do usuário: um editor hexadecimal genérico dentro da IDE, não amarrado a nenhum
formato específico — abre **qualquer arquivo** do disco (diferente dos demais editores visuais, que só
operam sobre conteúdo do sistema de projeto ou de uma aba de texto).

**Formatos reconhecidos hoje** (`HexEd_DescribeFile`, `editor/HexEditorGui.pbi`) — checagem sempre
automática, sem nenhuma configuração do usuário, nesta ordem:

| Formato | Como é reconhecido | Confiança |
|---|---|---|
| Imagem de disco MSX (`.dsk`, FAT12) | Extensão + boot sector | Formato nativo, offsets de `MSXDisk.pbi` |
| Executável MSX-DOS (`.com`) | Extensão (sem cabeçalho, código Z80 cru) | Convenção CP/M bem estabelecida |
| Planilha SuperCalc 2 MSX (`.cal`) | Assinatura de 22 bytes `"SuperCalc ver. ..."` | Validado contra 6 arquivos reais — só cabeçalho, dados de célula ainda não decifrados (`docs/reference/supercalc2-cal-format.md`) |
| Banco de dados dBase II (`.dbf`) | Byte `02h` + extensão | **Formato inteiro decifrado** — cabeçalho, descritores de campo e registros validados um a um contra um `.dbf` real (`docs/reference/dbase2-dbf-format.md`) |
| Alfabeto Graphos III (`.alf`) | Cabeçalho BLOAD/BSAVE `FEh` + exatamente 2048 bytes de dados | Validado em lote contra 781 arquivos reais (97%) |
| Layout Graphos III (`.lay`) | Cabeçalho BLOAD/BSAVE + decodifica o RLE/ofuscação de verdade | Validado em lote contra 234 arquivos reais (100%) |
| Tela Graphos III (`.scr`) | Cabeçalho BLOAD/BSAVE + 12288 bytes fixos de padrão/cor | Validado em lote contra 86 arquivos reais (100%) |
| Banco de shapes Graphos III (`.shp`) | Percorre a cadeia de blocos até o terminador `FFh` (sem cabeçalho BLOAD/BSAVE) | Validado em lote contra 3028 arquivos reais (96%) |
| Binário MSX BLOAD/BSAVE genérico | Byte `FEh` + endereços | Formato nativo, qualquer arquivo não coberto pelas linhas acima |
| MSX-BASIC tokenizado | Byte `FFh` | Formato nativo, convenção `#Tok_Base` |
| BASIC MSX clássico (ASCII, numerado) vs. texto puro | Primeiro caractere visível | Heurística (regra de entrada do tokenizador) |
| Binário desconhecido / dados crus | Nenhum dos anteriores bateu | — |

**Pendente** (sem arquivo de amostra real suficiente pra validar, ver detalhe mais abaixo): WordStar,
MSX-Word.

- **UI** (`editor/HexEditorGui.pbi`, menu **Executar → Editor Hexa...**) — janela própria com grade
  rolável offset/hex/ASCII; clique seleciona um byte, campo de valor + **Aplicar** grava. Rolagem
  vertical **customizada** (setas topo/base + barra visual com posição proporcional, desenhada à mão)
  em vez do `ScrollBarGadget` nativo do PureBasic, que nesta configuração renderizava enorme e com os
  botões trocados — mesma classe de problema já visto em outros gadgets nativos do projeto, resolvido
  do mesmo jeito (desenho próprio). Roda do mouse também rola.
- **Reconhecimento de formato**: sem exigir nada do usuário, detecta os três formatos binários que a
  própria IDE produz/consome, pelos mesmos offsets que o código que os gera/lê usa: binário MSX
  BLOAD/BSAVE (cabeçalho `FEh` + endereços inicial/final/execução), MSX-BASIC tokenizado (`FFh`,
  endereço de carga fixo `8001h`, ver módulo 11) e o boot sector FAT12 de uma imagem `.dsk` (mesmos
  offsets que `MSXDisk.pbi`, módulo 13, lê/escreve).
- **Galeria de templates** (`hexeditor_templates.json`, mesmo estilo de persistência de
  `editor_settings.json`/`badig_settings.json`) — dá nome amigável a um binário BLOAD/BSAVE reconhecido
  quando byte de tipo + endereço inicial + tamanho dos dados batem com um template registrado. De
  fábrica já vem semeada com os três formatos nativos do Graphos III (módulo 14): **Alfabeto `.ALF`**
  (`FEh`/`9200h`/2048 bytes exatos), **Layout `.LAY`** e **Tela `.SCR`** (`FEh`/`9200h`, tamanho
  variável) — mesmo endereço `9200h` (Pattern Generator Table da VRAM) que já aparecia nesses três
  formatos, batizando o codinome de versão desta sessão ("BFG9200", ver changelog do README).
- **Operações de bloco**: a partir de um intervalo marcado (**Marcar início**/**Marcar fim**/**Limpar
  seleção**) ou, sem marcação, perguntando endereço inicial/final na hora — **Preencher...** (um valor
  num intervalo), **Inserir bloco...** (desloca o resto do arquivo pra frente, cresce o arquivo) e
  **Sobrepor bloco...** (mesmo tamanho, não desloca), ambos podendo trazer os bytes de outro arquivo
  inteiro ou gerar bytes em branco (quantidade + valor); **Excluir bloco...** desloca de verdade
  (encolhendo o arquivo) ou só zera o intervalo com `00`, à escolha do usuário.
- **Bugs corrigidos durante a implementação** (duas rodadas de ajuste pedidas pelo usuário na mesma
  sessão): campo de status sobrepondo o botão "Fechar"; `Hex(v, #PB_Byte)` deste PureBasic não completa
  com zero à esquerda — `HexEd_Hex2`/`Hex4`/`Hex6` resolvem com `RSet` para manter largura fixa nos
  valores hex mostrados; cursor de seleção ganhou borda de destaque visível.
- **Sem integração com o sistema de projeto** (módulo 13) — deliberado: é uma ferramenta autocontida
  baseada em arquivo (como o editor de alfabetos Aquarela, módulo 4b), já que o alvo típico (um binário
  qualquer no disco) não é um tipo de conteúdo do `.msxproject`.
- **Versão embutida no executável**: `7.7.1`, codinome **"BFG9200"** (BFG9000 do Doom + endereço
  `9200h`, pedido explícito do usuário — MSX + Doom + heavy metal).

**Reconhecimento estendido (2026-08-07)** — pedido do usuário pra cobrir mais formatos de disquete/CP-M
da época além dos três nativos da IDE:
- **Executável MSX-DOS (`.COM`)**: reconhecido por **extensão**, checado antes dos bytes mágicos
  `FEh`/`FFh` — um `.COM` é código Z80 cru sem cabeçalho (mesma convenção CP/M, carrega e executa sempre
  em `0100h`), então o primeiro byte real do programa pode perfeitamente valer `FEh` (`CP n`) ou `FFh`
  (`RST 38h`) por coincidência; sem checar a extensão primeiro esses `.COM` cairiam classificados como
  BLOAD/BSAVE ou tokenizado por engano.
- **Texto ASCII puro vs. BASIC MSX clássico numerado**: o fallback antigo rotulava qualquer arquivo
  100% imprimível como "BASIC clássico ou fonte", sem distinguir. Nova heurística
  (`HexEd_LooksLikeBasicSource`) olha só o primeiro caractere visível do arquivo (pulando espaço/tab de
  indentação) — dígito = provável linha numerada (mesma regra que o tokenizador exige de entrada); linha
  em branco antes de qualquer caractere visível = não é (todo BASIC clássico válido começa com número na
  primeira linha).
- **Ainda em aberto no momento deste pedido, aguardando arquivos reais pra estudar** (pedido explícito
  do usuário: WordStar, MSX-Word, SuperCalc II, dBase II) — nenhum dos quatro foi implementado nesta
  primeira rodada porque nenhum tinha cabeçalho/layout binário confirmado contra uma fonte confiável a
  partir daqui (diferente do `.COM`, que é convenção CP/M bem estabelecida, e do padrão line-number, que
  é a própria regra do tokenizador desta IDE). WordStar historicamente marca fim-de-palavra ligando o 8º
  bit do último caractere (sem cabeçalho fixo) — heurística arriscada de acertar sem arquivo real pra
  validar; MSX-Word, SuperCalc II e dBase II não tinham formato de arquivo documentado neste repositório
  ainda. **SuperCalc II e dBase II deixaram de estar pendentes ainda na mesma sessão** — o usuário
  forneceu arquivos de amostra reais pra ambos, ver os dois blocos abaixo; só WordStar/MSX-Word
  continuam em aberto. Mesmo padrão de trabalho já usado pra `MSXDisk.pbi`/`GraphosNativeIO.pbi`/SEE
  Tracker (módulo 24): não crava detecção binária por
  suposição, só depois de validar contra arquivo real.

**SuperCalc 2 MSX (`.CAL`) — reconhecimento adicionado na mesma sessão (2026-08-07)**: o usuário forneceu
`sc2/` (projeto Go pessoal dele, `sc2msx`, uma reescrita do SuperCalc 2 que já lê/grava o formato SDI
texto intermediário) e `sc2/msx/*.CAL` (5 planilhas `.CAL` binárias reais). Achado que destravou o
estudo: o disco original `sc2/msx/supercalc2L.dsk` tem `EXEMPLO.CAL` **e** `EXEMPLO.SDI` lado a lado —
um par binário/texto verdadeiro, extraído com a própria `--diskmanipulator` desta IDE, sem precisar rodar
o `SDI.COM` original num emulador. Cruzando esse par com os outros 5 `.CAL`, confirmado (e só isso foi
implementado em `HexEd_DescribeFile`): assinatura de 22 bytes `"SuperCalc ver.  1.00\r\n"` em
`000000h`, campo de título de 80 bytes terminado em NUL em `000016h`, cabeçalho de tamanho fixo com a
seção de dados sempre começando em `000300h` (confirmado idêntico nos 6 arquivos independente do
tamanho do título/conteúdo). O layout campo a campo de cada célula dentro da seção de dados não foi
decifrado com confiança suficiente ainda — fica como próximo passo, ver
`docs/reference/supercalc2-cal-format.md` (novo arquivo, todas as notas de engenharia reversa, inclusive
o que ficou em aberto e como continuar usando o openMSX real já configurado nesta máquina,
`D:\msx\openMSX\openmsx.exe`). Achado colateral: `sc2/msx/msxdos1.dsk` tem `PESSOAL.DBF`, uma amostra
real de dBase II — guardado pra quando o dBase II do módulo 17 for atacado.

**dBase II (`.DBF`) — reconhecimento adicionado na mesma sessão (2026-08-07)**: usando o achado colateral
acima (`PESSOAL.DBF`, extraído de `sc2/msx/msxdos1.dsk`). Diferente do SuperCalc 2, esse formato saiu
**totalmente decifrado** — não só reconhecido, decodificado campo a campo e registro a registro,
conferido contra o texto legível do próprio arquivo (harness descartável imprimiu os 6 registros reais:
nome/cargo/salário/data de admissão de 6 funcionários, batendo exatamente com o hexdump). Confirmado:
byte `02h` = versão dBase II; bytes `01h`-`02h` (LE) = número de registros; bytes `06h`-`07h` (LE) =
tamanho do registro de dados; descritores de campo de 16 bytes cada a partir de `000008h` (nome de 11
bytes + tipo 1 char + tamanho 1 byte + 3 reservados), terminados por `0Dh`; dados sempre começam no
offset fixo `000209h` (= `8 + 32×16 + 1`, espaço reservado pra até 32 descritores mesmo com menos campos
de verdade — o limite clássico do dBase II); registros = 1 byte de flag + campos concatenados na ordem
dos descritores; `1Ah` marca o fim dos dados (mesma convenção CP/M já vista no `.CAL` do SuperCalc 2).
Ver `docs/reference/dbase2-dbf-format.md` (novo arquivo, spec completa + o que ficou fora do escopo
dessa única amostra: ordem exata dos bytes de data, byte de registro excluído, outros tipos de campo
como `L`/`D`/`M`). `HexEd_DescribeFile` reconhece (extensão `.dbf` + byte `02h`, exigidos juntos porque
um byte sozinho é assinatura fraca demais) e lista os campos decodificados no resumo — não decodifica os
registros de dados em si (ficaria melhor numa ferramenta dedicada, se algum dia fizer sentido).

**Graphos III: `.ALF`/`.LAY`/`.SCR`/`.SHP` — reconhecimento adicionado na mesma sessão (2026-08-07)**:
diferente do SuperCalc 2/dBase II, esses 4 formatos **já estavam totalmente documentados** por uma
sessão anterior (`editor/GraphosNativeIO.pbi`, módulo 14i) — não precisou de engenharia reversa, só
portar o conhecimento já validado pra dentro de `HexEd_DescribeFile` (a galeria de templates genérica já
reconhecia ALF/LAY/SCR fracamente, por header; SHP não tinha cabeçalho BLOAD/BSAVE nenhum pra
reconhecer, passava direto pra "binário desconhecido"). Validado contra **todos os arquivos reais do
repositório** (`graphos/` + `graphos-IV/`, ~4100 arquivos, harness descartável em lote, não só uma
amostra pequena):
- **`.LAY`**: 234/234 (100%) — validação forte: decodifica o RLE+ofuscação de verdade e confere que dá
  exatamente 6144 bytes. Achou e corrigiu um bug real no primeiro rascunho do decodificador (parava cedo
  demais por causa de padding sobrando no fim do stream comprimido, contando com o tamanho declarado no
  cabeçalho em vez de parar assim que os 6144 bytes esperados fossem alcançados — mesma lição do `.SCR`
  abaixo, cabeçalho nem sempre é fonte confiável de tamanho).
- **`.SCR`**: 86/86 (100%) — usa a mesma lógica já validada de `GraphosNative_LoadScr` (tamanho real do
  arquivo, não o cabeçalho, pra achar onde a rotina de apresentação termina).
- **`.ALF`**: 759/781 (97%) — validação em lote revelou duas nuances reais não documentadas antes: (1)
  o endereço de início nem sempre é `9200h` (`LETR-*.ALF` usa outros endereços) — reconhecimento agora
  só exige 2048 bytes de dados, sem travar em endereço fixo (diferente da galeria de templates genérica,
  que continua travada em `9200h` deliberadamente); (2) uma minoria real declara `Fim = Início + 2048`
  em vez de `Início + 2047` (convenção "fim exclusivo", confirmada em 3 arquivos de conteúdo diferente
  com o mesmo padrão) — também aceito. Os ~22 restantes são legitimamente outra coisa: um punhado sem
  cabeçalho `FEh` nenhum (`SHADOW`/`SOMBRA`/`TORTA`/`LETR-40.ALF` etc., formato desconhecido, não
  adivinhado) e alguns genuinamente truncados (menos bytes no disco do que o cabeçalho declara).
- **`.SHP`**: 2920/3028 (96%) — o maior ganho real (não tinha NENHUM reconhecimento antes): percorre a
  cadeia de blocos inteira (mesmo algoritmo de `GraphosNative_ScanShpFile`, sobre bytes em memória em
  vez de arquivo) e só reconhece se terminar exatamente no `FFh`, não em EOF por acaso — deliberadamente
  mais rígido que o importador de verdade (que é tolerante/best-effort) porque aqui o objetivo é
  reconhecimento seguro, não importação. Falhas investigadas uma a uma: a maioria é arquivo de outro
  formato com extensão `.SHP` por coincidência (`TITLE01.SHP` é texto puro, `CLIPART*.SHP` tem campos
  claramente inválidos pro layout Graphos), o resto é arquivo vazio ou sem terminador `FFh` limpo — sem
  nenhum falso positivo encontrado.

**Versão embutida no executável ao fim desta sessão**: `7.25.0`, codinome **"HEXORCIST"** (Hex do Editor
Hexa + Exorcist, pedido explícito do usuário — mesmo espírito de `BFG9200`/7.7.1 acima: a sessão inteira
foi sobre reconhecer/"esconjurar" formato atrás de formato que antes caía em "binário desconhecido/dados
crus"). Ver `docs/RELEASE_NOTES.md` para as notas de lançamento completas desta versão.

### 18. Integração de toolchains externas: MSXBas2Rom e N80/LinkStor80/LibStor80 — implementado (2026-08-01)

Pedido explícito do usuário: integrar duas toolchains de terceiros com um fluxo "baixar do GitHub →
gerar Ajuda a partir do que foi baixado" — **MSXBas2Rom** (compilador MSX-BASIC→ROM de terceiro,
`amaurycarvalho/msxbas2rom`) e **N80/LinkStor80/LibStor80** (assembler/linker/gerenciador de biblioteca
Z80 de terceiro, `Konamiman/Nestor80` — mesmo autor do NestorBASIC já suportado, módulo 9). **Não deve
ser confundido com o assembler/linker/biblioteca Z80 *nativo* do projeto** (`Z80Asm.pbi`/`Z80Link.pbi`/
`Z80Lib.pbi`, "Fase B" do módulo 2b, já implementado do zero antes desta sessão) — N80/LinkStor80/
LibStor80 são um caminho *externo* alternativo, não uma dependência do motor nativo nem uma substituição
dele; convivem lado a lado.

**Achados de pesquisa que mudaram o que foi pedido literalmente** (via `gh`/`curl` direto contra a API
pública do GitHub, sem autenticação — funciona sem header especial, confirmado):
- `msxbas2rom -D`/`--doc` **não despeja documentação** — só imprime um ponteiro pra wiki
  (`github.com/amaurycarvalho/msxbas2rom/wiki/...`). A wiki de verdade é buscável direto via
  `raw.githubusercontent.com/wiki/<owner>/<repo>/<Página>.md` (markdown limpo, com tabelas/links) e é
  de lá que vem o conteúdo de Ajuda, não do "-doc".
- **LinkStor80 e LibStor80 não são repositórios separados** — vivem dentro do próprio
  `Konamiman/Nestor80`, em **release tags diferentes** do mesmo repo (`n80-v1.3.5` pro N80 mais recente,
  `n80-v1.3.3-lk80-v1.1` pro LinkStor80 mais recente, `lb80-v1.0` pro LibStor80). `GET /releases/latest`
  só devolve a release mais recente (N80) — achar LK80/LB80 exige varrer `GET /releases?per_page=100`
  (uma página cobre o histórico inteiro desde a v1.0) procurando o asset `LK80_*`/`LB80_*` mais recente.
- O manual "M80L80" pedido é `docs/MACRO-80.txt` no repositório do Nestor80 ("Microsoft M80 DOC" —
  MACRO-80 Assembler + CREF-80 + LINK-80 + LIB-80, 2675 linhas). Existe também `docs/asmlnk.txt` no
  mesmo repo mas é o manual do ASxxxx/ASLINK do SDCC, sem relação — não foi baixado.

**Motor de Ajuda compartilhado, orientado a pasta** (`editor/GenericMdHelpGui.pbi`) — decisão de design
confirmada com o usuário (`AskUserQuestion`): ao contrário dos helps existentes (NestorBASIC/MSX BASIC/
Basic Dignified/openMSX, módulos 9/15/16 — conteúdo fixo, escrito à mão em `*HelpData.pbi`, compilado no
`.exe`), o conteúdo dos dois novos helps é **baixado e renderizado ao vivo**: o downloader salva `.md`
numa pasta (`tools/<ferramenta>/help/`) mais um manifesto `_index.json` (array `{file,title,group}`,
lido/escrito por `GenMdHelp_LoadIndex()`/`GenMdHelp_SaveIndex()`), e a janela de Ajuda (`GenMdHelp_
OpenWindow()`, mesmo layout busca+árvore+conteúdo+Voltar dos helps existentes) lê isso em tempo de
execução — clicar em "Baixar" de novo no futuro atualiza a Ajuda sozinho, sem precisar de uma nova
versão do `.exe`. Renderizador (`GenMdHelp_RenderMarkdown()`) é um "melhor esforço" mais rico que o
mini-renderer original (`NBHelpGui_RenderMarkdown()`, só `##`/`**bold**`/`` `code` ``): acrescenta
títulos `#`/`##`/`###` (3 estilos), blocos ` ``` ` (monoespaçado, não processa `**`/`` ` `` por dentro) e
`[texto](url)` como **link clicável de verdade** (pedido explícito do usuário, "com links e tudo mais")
via `SCI_STYLESETHOTSPOT` — cada link ganha um número de estilo dedicado (10..254, reciclado a cada
troca de tópico) mapeado pra URL em `GenMdHelp_LinkUrls()` (chave `"gadget_estilo"`, precisa ser por
gadget porque duas janelas de Ajuda abertas ao mesmo tempo reciclam os mesmos números de estilo pra
URLs diferentes); clique dispara `SCN_HOTSPOTCLICK` no callback do próprio gadget
(`GenMdHelp_ScintillaCallback`, mesmo padrão de `ScintillaCallBack()` em `BadigEditor.pb`), resolve a
URL nesse mapa e abre com `explorer.exe`/`xdg-open` (`CompilerIf #PB_Compiler_OS`). Tabelas/listas
markdown ficam como texto corrido — fora do escopo do "melhor esforço" pedido.

**Downloader compartilhado** (`editor/ExternalToolDownload.pbi`) — reaproveita infraestrutura já
existente sem reimplementar: `ReceiveHTTPMemory`/`ReceiveHTTPFile` (`UseNetworkTLS()` já chamado
globalmente em `BadigSettings.pbi`), `BadigCfg_ExtractZip()` (mesmo arquivo — já lida corretamente com
zip sem pasta-wrapper, que é o caso do msxbas2rom/N80: executável direto na raiz do zip), padrão de
progresso `TextGadget` de status + bombear a fila de eventos entre chamadas bloqueantes (mesmo truque de
`FontDownloader_FlushEvents()`, generalizado aqui como `ExtTool_SetStatus()`/`ExtTool_FlushEvents()`).
- **Bug real encontrado testando contra um caminho de pasta genuinamente novo** (`tools/msxbas2rom/`,
  `tools/n80/` — dois níveis que nunca existiam antes da primeira execução): `CreateDirectory()` nativo
  do PureBasic **não cria pastas intermediárias que ainda não existem** (confirmado com teste isolado:
  falha silenciosa contra um caminho de 2+ níveis novo). `BadigCfg_ExtractZip()` nunca precisou disso
  porque seus alvos existentes já tinham a pasta-pai pronta. Corrigido com um helper novo,
  `ExtTool_CreateDirectoryRecursive()` (recursão simples: garante o pai antes do próprio diretório),
  chamado antes de `BadigCfg_ExtractZip()` — sem mexer em `BadigCfg_ExtractZip()` em si, que continua
  igual pros chamadores que já tinham a pasta-pai pronta (evita qualquer risco de regressão no fluxo já
  existente de download do Basic Dignified Suite).
- `ExtTool_RunCaptureOutput()`: `RunProgram(...#PB_Program_Open|Read|Error)` + laço `ReadProgramString()`
  (checa `AvailableProgramOutput()` antes, senão bloqueia) + `ReadProgramError()` (não-bloqueante por
  conta própria) — usado pra capturar `-h`/`--help` de cada binário recém-baixado e virar tópico de
  Ajuda, mesmo padrão de captura de saída de processo já usado em `OpenMSXBridge.pbi`.

**MSXBas2Rom** (`editor/MsxBas2RomSupport.pbi`):
- **Arquivo → Novo MSXBas2Rom...**: `MsxBas2RomTemplateText()` gera um `.bas` ASCII clássico numerado
  (`10 REM.../60 SCREEN 0/70 PRINT "HELLO, MSX!"/80 END`, mesmo espírito do hello-world oficial da wiki,
  `Gettingstarted.md`) — **não** Dignified, é o formato que o `msxbas2rom` real espera direto. Novo modo
  de documento `"BAS"` em `AddDocumentTab()`/`BadigEditor.pb` (extensão padrão `.bas` pra abas sem
  arquivo ainda, e detecção automática ao abrir um `.bas` existente) — se comporta como "não ASM" no
  resto do código (só precisava disso, os únicos `Docs()\Mode = "ASM"` existentes continuam corretos sem
  mudança), e já funciona com tudo que foi construído para ASCII clássico nas duas tarefas anteriores
  desta sessão (Renumerar/RENUM, tokenizar nativo) sem nenhuma mudança adicional — `LooksLikeClassicAscii()`
  detecta por conteúdo, não por extensão/modo.
- **Configurar → MSXBas2Rom...**: **redesenhada (2026-08-09)** com dois botões e um campo de caminho
  separados, em vez de um único botão que baixava executável + Ajuda juntos (decisão explícita do
  usuário: ele nunca é embutido no projeto, é sempre um `.exe` externo chamado por caminho).
  - **"Baixar versão mais recente"** (`MsxBas2Rom_DownloadExe()`) baixa só o asset da release mais
    recente (`GET .../releases/latest`, filtro `-windows-x64-bin.zip`/`-linux-x64-bin.zip` via
    `CompilerIf #PB_Compiler_OS`) para `tools/msxbas2rom/` (subdiretório da instalação do msxbasica) e
    preenche o campo de caminho com o executável encontrado.
  - **Campo de caminho editável** (`StringGadget` + botão "..." → `OpenFileRequester`): cobre o caso do
    usuário já ter o `msxbas2rom` instalado em outro lugar — não precisa baixar, só aponta pro `.exe`
    existente. Pré-preenchido com `MsxBas2RomCfg\ExePath` (o local onde o pacote foi baixado, se já foi
    baixado antes) ou, se ainda vazio, com o resultado de `MsxBas2Rom_FindExe()` contra a pasta padrão
    (cobre o caso de `msxbas2rom_settings.json` ter sido apagado/recriado mas o executável já estar lá).
    Só é persistido no `Salvar` da janela (padrão `G_Save`/`G_Cancel` de `BadigCfg_OpenSettingsWindow()`,
    `BadigSettings.pbi`) — trocar o caminho manualmente zera `MsxBas2RomCfg\Version` (deixa de ser a
    versão que a IDE baixou, então a versão exata é desconhecida).
  - **"Atualizar documentação"** (`MsxBas2Rom_UpdateDocumentation()`) — **implementado (2026-08-09,
    mesma sessão)**: roda `-h` do executável configurado (se houver um caminho válido, senão pula essa
    etapa sem falhar) e baixa 19 páginas da wiki oficial (`raw.githubusercontent.com/wiki/
    amaurycarvalho/msxbas2rom/<Página>.md`), organizadas nos MESMOS grupos/ordem da estrutura real da
    wiki — confirmado clonando `amaurycarvalho/msxbas2rom.wiki.git` e lendo `Home.md` (tabela "Quick
    Reference") e `Documentation.md` (hub "Reference Guide" com as 12 sub-páginas de referência)
    diretamente, não adivinhado: **Primeiros passos** (Home/Install/Gettingstarted/Usage), **Guia de
    referência** (Documentation + as 12 sub-páginas: Compiling-Code, Resource-Directives, Extended-
    Commands, Extended-Functions, Music-Support, MTF-Support, nMT-Support, TS-Support,
    VSCode_integration + seu manual de configuração manual, Debugging_with_OpenMSX, Compiler-
    Architecture, Getting-Help) e **Exemplos** (Examples). `Games`/`Contributing`/`Branding` ficam de
    fora de propósito — são páginas de comunidade/créditos do projeto msxbas2rom, não guia de uso do
    dialeto (pedido explícito do usuário: "guia de referência prático pra quem quer usar este
    dialeto"). Links internos da wiki (`[texto](Install)`, forma normal de link relativo entre páginas
    de uma wiki do GitHub) são reescritos para URL absoluta (`MsxBas2Rom_RewriteWikiLinks()`) antes de
    salvar em disco — sem isso, o clique no link (que `GenMdHelp_OpenUrl()` manda cru pro
    `explorer.exe`/`xdg-open`) tentaria abrir um arquivo local inexistente em vez da página real,
    inclusive pras páginas que este fluxo deliberadamente não baixa (ex.: um link pra `Games`). Mesmo
    padrão bloqueante + `ExtTool_SetStatus()` de `MsxBas2Rom_DownloadExe()`. Pode ser clicado de novo no
    futuro pra resincronizar com a wiki sem precisar de uma nova versão do `.exe`.
  Configurações em `msxbas2rom_settings.json` (mesmo padrão de `editor_settings.json`).
- **Ajuda → MSXBas2Rom...**: `GenMdHelp_OpenWindow(..., MsxBas2Rom_HelpDir())` — mostra o que já tiver
  sido baixado por "Atualizar documentação"; fica vazia num diretório novo até esse botão ser clicado
  pelo menos uma vez.
- **"Baixar exemplos (demo)"/"Baixar jogos completos" (2026-08-09, mesma sessão)**: pedido explícito do
  usuário — quis os exemplos oficiais de `amaurycarvalho/msxbas2rom` (pasta `demo/` do repositório,
  link direto `.../tree/master/demo`) e, se possível, também os jogos completos de
  `amaurycarvalho/msxbasic`, baixados pro disco e navegáveis/legíveis (`.bas`/`.md`) dentro de `Ajuda →
  MSXBas2Rom...`, na mesma estrutura de pastas dos repositórios.
  - **"Baixar exemplos (demo)"** (`MsxBas2Rom_DownloadExamples()`) baixa **só** a pasta `demo/` do
    repositório `msxbas2rom` pra `tools/msxbas2rom/demo/` — repositório inteiro via zip
    (`codeload.github.com/.../zip/refs/heads/master`, ~32 MB, inclui todo o código C++ do compilador)
    seria desperdício de banda/disco só pra chegar aos ~4 MB de `demo/`; em vez de varrer a API de
    conteúdo do GitHub recursivamente (a pasta tem só 13 subdiretórios, mas somado às ~58 subpastas do
    `msxbasic` no mesmo clique/hora estouraria facilmente o limite de 60 requisições/hora sem
    autenticação da API), a extração do zip agora aceita um filtro de prefixo (`BadigCfg_ExtractZip()`/
    `ExtTool_DownloadAndExtractZip()`, `OnlyUnderPrefix` opcional, retrocompatível — `""` continua
    extraindo tudo, como os 2 chamadores existentes já faziam) que só descompacta entradas dentro de
    `demo/`, removendo esse prefixo do caminho final. **TODOS** os arquivos de `demo/` são baixados
    (imagens, ROMs, sprites, música — pedido explícito do usuário "baixe os arquivos no disco"), não só
    `.bas`/`.md`.
  - **"Baixar jogos completos"** (`MsxBas2Rom_DownloadGames()`) baixa o repositório `amaurycarvalho/
    msxbasic` **inteiro** (zip pequeno, ~2.4 MB, sem código C++ pra filtrar) pra `tools/msxbas2rom/
    games/` — 10 jogos completos em MSX BASIC, cada um na própria pasta (`README.md` + `.bas` +
    imagens/música/níveis/disco).
  - Depois de extrair, ambos varrem recursivamente a pasta baixada (`MsxBas2Rom_ScanCodeExamplesRec()`)
    coletando `.bas`/`.md` — cada subpasta de PRIMEIRO NÍVEL vira seu próprio grupo na árvore de Ajuda
    (`"Demo: scroll1"`, `"Jogo: Fortknox"`..., motor de Ajuda só suporta 1 nível de agrupamento),
    arquivos mais profundos (ex.: `Fortknox/disk/AUTOEXEC.BAS`, `Dragon Treasure/music/extra/
    dragon_scream.bas`) ficam no MESMO grupo do jogo/demo, com o título prefixado pelo caminho relativo
    (`"disk\AUTOEXEC.BAS"`). Validado rodando o algoritmo (extração filtrada + varredura) contra os
    zips reais dos dois repositórios num harness `.pb` isolado antes de integrar: 81 arquivos/12
    tópicos pro `demo/` do msxbas2rom, 317 arquivos/23 tópicos pro `msxbasic` (Superman corretamente
    sem `README.md`, `scroll5` corretamente com os 4 `.BAS` maiúsculos sob o mesmo grupo, `Games
    Published` corretamente sem nenhum tópico — só tem `.png` de captura de tela).
  - Os arquivos ficam onde foram baixados (`tools/msxbas2rom/demo/`, `tools/msxbas2rom/games/`), **não**
    copiados pra dentro de `tools/msxbas2rom/help/` — cada tópico no `_index.json` usa um caminho
    relativo com `..\` (ex.: `File = "..\demo\scroll1\scroll1.bas"`) que o Windows resolve normalmente
    a partir de `MsxBas2Rom_HelpDir()`, sem precisar duplicar arquivo nenhum.
  - **Coexistência no MESMO `_index.json`**: com agora 3 botões diferentes gravando tópicos na mesma
    pasta de Ajuda (`Atualizar documentação`/`Baixar exemplos`/`Baixar jogos`), sobrescrever o índice
    inteiro a cada clique apagaria os tópicos dos OUTROS botões. `GenMdHelp_MergeIndex()`
    (`GenericMdHelpGui.pbi`) resolve isso: carrega o índice existente, descarta só os tópicos cujo
    `Group` aparece na lista nova (ou seja, cada download só é "dono" dos grupos que ele mesmo gera),
    acrescenta os novos, salva de volta — os tópicos dos outros downloads sobrevivem intactos.
  - **Exibição de `.bas` como código, não markdown** (`GenMdHelp_RenderPlainCode()` +
    `GenMdHelp_RenderTopic()`, `GenericMdHelpGui.pbi`): rodar um `.bas` de verdade pelo parser de
    markdown existente (`GenMdHelp_RenderMarkdown()`) corromperia a exibição — BASIC usa `**`/`` ` ``/
    `[texto](...)` legitimamente (`PRINT "**"`, `A$(I)`) e o parser interpretaria isso como negrito/
    código/link. `GenMdHelp_RenderTopic()` (novo despachante, substituindo a chamada direta a
    `RenderMarkdown` nos 3 lugares que renderizam um tópico) decide pela extensão do arquivo: `.bas` vai
    pra `GenMdHelp_RenderPlainCode()` (todo o texto num único estilo monoespaçado, `#GenMdHelp_Style_
    Code`, sem nenhum parsing), qualquer outra extensão continua no `RenderMarkdown()` normal. Decisão
    deliberada de **não** reaproveitar o destaque de sintaxe MSX-BASIC real do editor principal
    (`HighlightDignifiedText()`) — os números de estilo do Scintilla que ele usa colidiriam com os já
    ocupados por `GenMdHelp_SetupStyles()` (H1/H2/H3/Bold/Code) na mesma tabela de estilos compartilhada
    por toda janela de Ajuda; texto verbatim monoespaçado (mesmo visual já usado pros blocos ` ``` ` de
    código na Ajuda) já satisfaz o pedido do usuário de "funcionando como verdadeiros exemplos de
    programação" sem esse risco de cruzamento de tabelas de estilo.

**Bug real encontrado testando o conteúdo baixado acima (2026-08-09, mesma sessão)**: usuário reportou
"a fonte do HELP está muito grande... texto aparece desalinhado... quebra em linhas desconexas" em
**toda** janela de Ajuda da IDE (não só a nova de MSXBas2Rom), reproduzido abrindo `Ajuda →
MSXBas2Rom...` — o conteúdo baixado da wiki tem parágrafos de prosa de verdade, ao contrário da maioria
dos outros Helps (escritos à mão, já mais compactos), o que deixou o problema óbvio pela primeira vez.
Causa real: `NBHelpGui_SetupStyles()` (`NestorBasicHelpGui.pbi`, base de 5 janelas de Ajuda — Nestor
Basic/MSX BASIC/Basic Dignified/SEE Tracker/openMSX) e `GenMdHelp_SetupStyles()`
(`GenericMdHelpGui.pbi`, base de outras 3 — Editor/MD Viewer/MSXBas2Rom+N80) usavam
`EditorCfg\FontName`/`EditorCfg\FontSize` — a fonte do **editor de código** do usuário, tipicamente
monoespaçada por design — pra renderizar o corpo do texto (prosa). Fonte monoespaçada em prosa ocupa
mais espaço horizontal por palavra do que uma fonte proporcional do mesmo tamanho nominal (cada letra
tem a mesma largura, mesmo "i" e "m"), o que faz o texto parecer maior do que o configurado E quebra de
linha (`SC_WRAP_WORD`) com muito mais frequência — lido pelo usuário como texto grande/desalinhado/
picotado. Corrigido nas duas funções: no Windows, corpo do texto passa a usar **Segoe UI 10pt fixo**
(desacoplado do `EditorCfg` do usuário) em vez da fonte do editor — mesmo "toque moderno" já aplicado
aos controles nativos de toda janela secundária em `App_ApplyWindowIcon()` (`BadigEditor.pb`), por isso
só Windows (sem equivalente testado noutro OS, mesmo escopo daquela função). Fora do Windows, mantido o
comportamento antigo (`EditorCfg\FontName`/`FontSize`) por falta de um fallback testado. Estilos de
título (H1/H2/H3) mantiveram os mesmos deltas relativos (+6/+3/+1 em `GenMdHelp_*`, +2 em
`NBHelpGui_*`), só a base mudou; bloco de código (`Consolas`, já fixo) não foi afetado.

**Destaque de sintaxe (2026-08-01, mesmo dia, pedido explícito do usuário em seguida)**: até aqui
`HighlightDocument()`/`BadigEditor.pb` só distinguia `"ASM"` de tudo mais — abas em modo `"BAS"` caíam
no mesmo `HighlightDignifiedText()` do Dignified clássico, sem reconhecer nenhum dos comandos/funções
estendidos do MSXBAS2ROM (`CMD TURBO`, `SCREEN LOAD`, `SET TILE PATTERN`, `HEAP()`, `COLLISION()`,
`FILE`/`TEXT` etc. — extraídos do conteúdo real já baixado em `tools/msxbas2rom/help/extended-
commands.md`/`extended-functions.md`, mais `Music-Support` buscado à parte pros comandos `CMD PLY*`).
Resolvido com 3 mapas novos (`KwMsxBas2RomDirective`/`KwMsxBas2RomStatement`/
`KwMsxBas2RomFunctionPlain`) só consultados quando `IsMsxBas2Rom` (`Mode = "BAS"`) — decisão deliberada:
um programa Dignified comum pode ter uma variável chamada `TURBO` ou `COLLISION` sem que isso deva virar
destaque de palavra-chave, então a extensão fica isolada por modo, não misturada nas tabelas globais
existentes (`KwStatement`/`KwFunctionPlain`). Palavras com papel duplo (ex.: `TILE`/`TURBO`, usadas tanto
como parte de comando — `PUT TILE`, `CMD TURBO` — quanto como função — `TILE(x,y)`, `TURBO()`) só entram
no mapa de função: o lexer não olha à frente pra saber se vem um `(` depois, então só um dos dois estilos
vence, e função foi a escolha consistente. `IDATA` dispara o mesmo modo de literal do `DATA` clássico
(`InDataLiteral`). Verificado com harness de console isolado (cópia fiel de `HighlightDignifiedText()`
sem depender de Scintilla real, `EmitRun()` só grava texto+estilo numa lista) — 11 casos, incluindo dois
de isolamento negativo confirmando que `TURBO`/`COLLISION` como variável comum em modo `"BAS" = #False`
continuam caindo no estilo padrão de identificador, não no de palavra-chave.

**Cor própria pro vocabulário estendido (2026-08-10)**: até aqui os 3 mapas acima (`KwMsxBas2RomDirective`/
`KwMsxBas2RomStatement`/`KwMsxBas2RomFunctionPlain`) reaproveitavam as cores JÁ existentes
(`#Style_DignifiedStmt`/`#Style_Statement`/`#Style_Function`, respectivamente) — pedido explícito do
usuário: "todos os comandos [do MSXBAS2ROM] devem aparecer em uma outra cor... tente colocar uma cor
diferente para estes comandos", em vez de se confundir com as palavras clássicas do MSX-BASIC ou do
Dignified. Novo estilo único `#Style_MsxBas2Rom` (`Enumeration 1`, entre `#Style_DignifiedStmt` e
`#Style_Remtag`) unifica as 3 categorias (diretiva/comando/função do MSXBAS2ROM sempre na MESMA cor
nova, não 3 cores emprestadas diferentes) — negrito, mesmo tratamento visual de `#Style_Statement`/
`#Style_DignifiedStmt`. Cor nova (`Color_Syntax_MsxBas2Rom`) escolhida numa família teal/ciano em cada
um dos 7 temas (`ApplyTheme()`) — hue que nenhum tema usava ainda pras outras categorias de sintaxe
(exceto o próprio "Statement" do tema Forest, que por coincidência já é teal-esverdeado — ali a cor do
MSXBAS2ROM foi pro azul-violeta em vez de repetir o teal). Só a COR mudou; os 3 mapas de palavras-chave
em si (quais palavras entram em cada categoria) não foram tocados nesta sessão.

**N80/LinkStor80/LibStor80/M80L80** (`editor/N80Support.pbi`):
- **Configurar → N80...**: `N80_ResolveAllAssets()` varre o histórico completo de releases numa única
  chamada e acha, pra cada um dos 3 prefixos de asset (`N80_`/`LK80_`/`LB80_`), o primeiro (= mais
  recente, a API já devolve nessa ordem) que bater com o padrão `..._SelfContained_<RID>.zip` do SO
  atual. Baixa os 3 binários standalone pra `tools/n80/`, roda `--help` de cada um, busca
  `docs/LanguageReference.md` e `docs/WritingRelocatableCode.md` do N80, e baixa+normaliza
  `docs/MACRO-80.txt` (manual M80L80) — normalização "melhor esforço" (`N80_NormalizeMacro80Text()`):
  texto de largura fixa sem estrutura Markdown nenhuma, então só linhas com pelo menos 1 letra e **sem
  nenhuma letra minúscula** viram título `## ` (pega `CHAPTER 1`, `NOTE`, `2.1  RUNNING MACRO-80`...); o
  resto fica intocado, preservando alinhamento de colunas dos exemplos de código. Efeito colateral
  conhecido e aceito: nomes de pseudo-op em CAIXA ALTA dentro do sumário (`ASEG`, `END`...) também viram
  "título" — ruído cosmético, não corrompe conteúdo, e o texto explica a heurística usada no topo do
  próprio tópico gerado. Configurações em `n80_settings.json`.
- **Ajuda → N80...**: `GenMdHelp_OpenWindow(..., N80_HelpDir())`, 4 grupos na árvore: **N80** (linha de
  comando + referência de linguagem + código relocável), **LinkStor80** (linha de comando),
  **LibStor80** (linha de comando), **M80L80** (o manual).

**Verificado**: compilado com sucesso (`build.ps1`) a cada etapa. Pipeline de download validado **de
ponta a ponta** com harnesses de console fora do projeto (mesma filosofia dos `editor/tools/*TestCli.pb`
já usados no projeto) — baixou/extraiu de verdade contra o GitHub real: MSXBas2Rom v1.2.1.0 (11 tópicos
de Ajuda gerados), N80 1.3.5 + LinkStor80 1.1.0 + LibStor80 1.0 (6 tópicos, incluindo o manual M80L80 de
91KB) — batendo exatamente as versões achadas manualmente durante a pesquisa. `GenMdHelp_RenderMarkdown()`
testado contra **todo** o conteúdo real baixado (17 arquivos, incluindo a referência de linguagem do N80
de 109KB) sem nenhum crash, maior arquivo renderizado em 185ms. Link clicável e aparência visual (cores/
tamanhos de título) **não verificados visualmente** (app GUI nativo, sem ferramenta de screenshot
disponível nesta sessão) — pendente de conferência ao vivo pelo usuário.

**Documentação e versão (2026-08-01, pedido explícito do usuário)**: `docs/MANUAL.md` ganhou as seções
de uso que faltavam pra tudo isso (Renumerar/`RENUM` + pipeline nativo ASCII clássico, Suporte a
MSXBAS2ROM, N80/LinkStor80/LibStor80) — nenhuma dessas features tinha guia de usuário até então, só a
entrada técnica aqui no SPEC. De caminho, corrigido um trecho desatualizado do próprio `MANUAL.md` que
dizia que o motor do assembler Z80 "ainda não existe", contradizendo a seção "Assembler Z80" do mesmo
arquivo (módulo 2b/2c, já implementado há várias sessões). Versão embutida no executável (`build.ps1`/
`#App_Version` em `editor/BadigEditor.pb`) atualizada para **7.9.1**, sem codinome novo.

**Motor Dignified com modo MSXBAS2ROM + compilação pra ROM + config por projeto (2026-08-10, pedido
explícito do usuário)**: até aqui, documentos "Novo MSXBas2Rom..." (`Docs()\Mode = "BAS"`) só suportavam
BASIC clássico numerado escrito à mão (`MsxBas2RomTemplateText()`) — o pré-processador Dignified não
reconhecia o vocabulário exclusivo do MSXBAS2ROM (`FILE`/`TEXT`, sub-comandos de `CMD`/`SET`/`GET`,
`HEAP()`/`TILE()`/`TURBO()`/etc.), então usar essas palavras como nome de variável num programa Dignified
arriscava virar candidato ao encurtamento automático (`Dig_ShortenVars_Piece`), corrompendo o programa.
Também não existia nenhum caminho que efetivamente chamasse `msxbas2rom.exe` pra compilar um arquivo do
usuário — só o downloader.

- **Decisão de arquitetura**: em vez de duplicar `DignifiedPreprocessor.pbi` (~2500 linhas testadas de
  labels/loops/`DEFINE`/`DECLARE`/`FUNC`/`RET`/`INCLUDE`/remtags) num arquivo separado, o motor existente
  ganhou um **modo** — decisão confirmada com o usuário via `AskUserQuestion` (a alternativa, "criar um
  segundo parser", foi descartada pelo risco real dos dois arquivos desalinharem com o tempo).
- **Vocabulário reservado**: `Dig_IsReservedWord()` (`DignifiedPreprocessor.pbi`) agora também consulta
  `KwMsxBas2RomDirective`/`Statement`/`FunctionPlain` — os MESMOS 3 mapas já usados pelo destaque de
  sintaxe (sessão anterior) — quando `Dig_ModeIsMsxBas2Rom` (Global setado por `Dig_Preprocess(...,
  IsMsxBas2Rom)`, lido em vez de recebido por parâmetro nos 3 call sites porque
  `Dig_CollectHardVar_Piece`/`Dig_ShortenVars_Piece`/`Dig_ScanLabelRefs_Piece` são chamadas via ponteiro
  de função de assinatura fixa — `Prototype Dig_PieceFn(Piece.s, LineNum.i)` — e não podem ganhar um
  parâmetro extra; mesmo idioma já usado por `Dig_CurrentPrefix`). Os 3 mapas passaram a ser **declarados
  dentro de `DignifiedPreprocessor.pbi`** (não em `BadigEditor.pb`) e também **populados ali**
  (`Dig_FillWordMap()`, idempotente, convive sem problema com o `FillKeywordMap()` de `BadigEditor.pb`)
  — necessário pra harnesses standalone (`DigTestCli.pb`) que só incluem `DignifiedPreprocessor.pbi`,
  sem o resto do `.exe`.
- **`FILE`/`TEXT` sem número de linha**: confirmado na documentação oficial (`resource-directives.md`)
  que essas diretivas de recurso aparecem SEM número, antes do código numerado — a ORDEM define o índice
  do recurso usado por `SCREEN LOAD 0`/`CMD RESTORE 1`/etc. Novo campo `IsResourceDirective` em
  `DigLogLine` (calculado uma vez, reaproveitado na passagem de numeração — que agora pula essas linhas
  sem consumir um número — e na passagem de geração final — que emite a linha verbatim, sem prefixo).
- **Verificado** rodando `DigTestCli.exe` (ganhou um 4º argumento opcional, `msxbas2rom`) contra um `.dmx`
  de teste com `FILE`/`TEXT`/`CMD TURBO`/`TURBO`/`HEAP` usados como statement E como identificador livre:
  em modo clássico, `FILE`/`TURBO`/`HEAP` saem renomeados (`ZZ`/`ZX`/`ZW`, corrompendo o programa — bug
  confirmado, exatamente o que o modo novo resolve); em modo MSXBAS2ROM, saem intactos e `FILE`/`TEXT`
  saem sem número de linha, na ordem certa.
- **`Executar → Compilar ROM (MSXBas2Rom)...`** (`CompileMsxBas2RomFromActiveTab()`, `BadigEditor.pb`):
  só aceita `Docs()\Mode = "BAS"`; gera ASCII (pulando o pré-processador se o conteúdo já for ASCII
  clássico, mesma detecção de `RunBasicFromActiveTab`) **sem nunca tokenizar** — `msxbas2rom.exe` compila
  direto do texto; salva num `.bas` real (`SaveFileRequester`) e roda `msxbas2rom.exe` via
  `MsxBas2Rom_CompileToRom()` (`MsxBas2RomSupport.pbi`) — `RunProgram` + drenagem de stdout/stderr (mesmo
  padrão de `ExtTool_RunCaptureOutput`) **mais** `ProgramExitCode()` (único sinal confiável de sucesso/
  falha, já que o `msxbas2rom` não tem uma convenção clara de mensagem no stdout) — mesmo idioma de
  `RunProgram`+`ProgramExitCode`+`MessageRequester` já usado em `BadigCfg_DownloadViaGit()` pro `git
  clone`, único outro precedente no projeto de checar exit code de processo externo.
- **`Configurar → Projeto...`** (`ProjectSettingsGui.pbi`, novo arquivo pequeno): até aqui, `BadigCfg`/
  `N80Cfg`/`MsxBas2RomCfg` eram só JSON global ao lado do `.exe` — zero precedente de override por
  projeto (único dado por-projeto era `working_dir`, em `ProjectDB::project_info`). Em vez de duplicar as
  ~700 linhas da tela global do Basic Dignified, as **3 telas de configuração existentes não mudaram
  nada de conteúdo** — só ganharam um parâmetro opcional `OverridePath` (`_FilePath()`/`_Load()`/
  `_Save()`/`_OpenSettingsWindow()` de cada uma, retrocompatível — `""` continua sendo o comportamento
  global de sempre) que redireciona onde leem/gravam. A nova janela é só um `PanelGadget` com 3 abas
  (checkbox "usar config específica" + status + botão "Editar..." que abre a MESMA janela de sempre,
  apontada pro JSON do projeto — `ProjectDB::OverrideSettingsPath()`, ao lado do `.msxproject`, novos
  `ProjectDB::SetInfoValue`/`GetInfoValue` genéricos generalizando o padrão já usado por
  `SetWorkingDir`/`GetWorkingDir`). Desabilitada com um aviso se não há projeto salvo ainda (`GetWorkingDir()
  = ""`). Consumido em `RunDignifiedPreprocessor()`/`CompileMsxBas2RomFromActiveTab()`: quando o override
  está ligado, o Global (`BadigCfg`/`MsxBas2RomCfg`) é trocado só durante a operação (snapshot no começo,
  restaurado antes de qualquer retorno — mesmo idioma de save/restore já usado em `Dig_ProcessSource` pra
  `Dig_CurrentPrefix`/`Dig_Defines()`). N80 ganhou a mesma infraestrutura mas **sem consumidor ainda** —
  não há hoje nenhum fluxo de compilação via N80.exe no editor.

**Opções de linha de comando do msxbas2rom.exe expostas na tela (2026-08-10, pedido explícito do
usuário, lista colada diretamente de `msxbas2rom -h`)**: `MsxBas2RomSettings` (`MsxBas2RomSupport.pbi`)
ganhou 8 campos novos espelhando os grupos de opções do `-h` do compilador — geral (`-q`/`-d`), modo de
compilação (`-c`/`-a`/`-x`/`-6`/`-7`/`-4`/`-k`, mutuamente exclusivos, um `ComboBoxGadget` só) e caminhos
(`-i`/`-o`) na página "Opções de compilação" da MESMA janela (`Configurar → MSXBas2Rom...`/`Configurar →
Projeto...`, já reaproveitada via `OverridePath` desde a sessão anterior — nenhuma mudança extra
necessária pro lado do projeto). `MsxBas2Rom_BuildCliArgs()` monta a linha de argumentos a partir dessa
struct, aplicada em `MsxBas2Rom_CompileToRom()` (antes só passava o `.bas` sem nenhuma flag).
`MsxBas2Rom_ExpectedRomPath()` passou a considerar o override de `-o` (tratado como PASTA, não arquivo,
mesmo espírito de `-i`) ao checar se a compilação gerou o `.rom` esperado. **Decisão de design**: os 4
flags puramente informativos (`-h`/`-D`/`-H`/`-v`, mostram texto e saem sem compilar nada) NÃO entraram
como checkbox persistente — um usuário “esquecer ligado” um desses quebraria silenciosamente o botão
"Compilar ROM" (nunca mais geraria ROM nenhuma). Em vez disso, viraram 4 botões de ação única
("Ajuda"/"Guia rápido"/"Histórico"/"Versão") que rodam só aquele flag e mostram o resultado num
`MessageRequester`, sem afetar nenhuma configuração salva.

### 19. Inserir → Caractere Especial (mapa de caracteres MSX) — implementado (2026-08-04)

Pedido explícito do usuário: um mapa de caracteres estilo Windows (`charmap.exe`) pros 159 caracteres
especiais que `-tr` traduz pra ASCII nativo MSX (ver módulo 3h, itens 3 e 4, pra correções feitas no
próprio `-tr` durante esta sessão).

- **Novo menu de topo "Inserir"** (`editor/BadigEditor.pb`), entre **Criar** e **Executar** — único
  item por enquanto: **Caractere Especial...**.
- **Janela** (`editor/CharMapGui.pbi`, `CharMap_OpenWindow()`) — mesmo padrão modal-com-`DisableWindow`
  de todo outro diálogo secundário da IDE:
  - Grade 16×10 (160 células, a última fica vazia — 159 caracteres reais) desenhada num `CanvasGadget`
    próprio (`StartDrawing`/`DrawingFont`, não uma tabela de controles nativos — o mesmo motivo do
    editor de alfabetos, módulo 4: `App_StyleChildCallback` força fonte 9pt em todo controle nativo
    filho da janela, o que anularia uma fonte grande escolhida a mão). Clique seleciona (contorno
    vermelho); duplo clique adiciona direto ao campo abaixo.
  - **Painel de prévia** — outro `CanvasGadget` (mesmo motivo acima) com o caractere selecionado numa
    fonte grande, mais um texto com posição na tabela (`N/159`), a tradução MSX (`Codigo MSX: XXh` pros
    128 primeiros, `Grafico MSX: CHR$(1);CHR$(N)` pros 31 últimos — a última chamando
    `Dig_TransReplacement()` de verdade em vez de recalcular, pra nunca dessincronizar da tradução real)
    e o codepoint Unicode.
  - **Campo acumulador** (`StringGadget`, editável, até 80 caracteres) — botões **Adicionar**/**Remover
    último**/**Limpar**; **Inserir** copia o conteúdo do campo pra posição do cursor da aba ativa
    (`InjectTextAtCursor()`, já existente — usada também pelo botão "Injetar" do editor de sprites) e
    fecha a janela; **Fechar** só fecha, sem inserir nada.
- **Fonte dos dados**: a grade reaproveita `Dig_TransOriginal`/`Dig_TransReplacementOrder`
  (`DignifiedPreprocessor.pbi`) diretamente em vez de retranscrever a lista de 159 caracteres uma
  segunda vez — evita um segundo ponto de erro de transcrição (o `tradutor.txt`/
  `basic-dignified/documentation/BASIC_DIGNIFIED.md`, seção "Classic Basic ASCII characters", foi usado
  só pra *conferir* a contagem final de 159, não como fonte primária dos dados).
- **Verificado visualmente** — screenshot real da janela rodando (`PrintWindow`, mesma técnica de
  outras sessões, ver `docs/SPEC.md`/memória do projeto) confirmou os 159 caracteres corretos na grade,
  incluindo a linha 9/10 com os 31 símbolos extras (carinhas/naipes/linhas tipo CP437) só depois da
  correção do bug 3h-3 — a primeira versão desta feature só tinha 128 células e mostrava lixo antes da
  correção do bug 3h-4 (BOM).

### 20. Editor de tela SCREEN 0 estilo TheDraw/AcidDraw (`Criar → Screen 0...`) — implementado (2026-08-04)

Pedido explícito do usuário: um editor gráfico de telas de texto MSX **SCREEN 0**, no espírito dos
clássicos editores de tela ANSI da era BBS (TheDraw/AcidDraw/DarkDraw) — primeira de uma família de 3
(SCREEN 1 e SCREEN 1+2, que cobre SCREEN 2, vieram no dia seguinte, ver módulos 21 e 22). Duas decisões
de design foram confirmadas
com o usuário antes de implementar (`AskUserQuestion`), porque SCREEN 0 real do MSX1 **não** tem cor
por célula como um editor ANSI de PC:

- **Cor fiel ao hardware**: uma única cor de tinta e uma de fundo pra tela INTEIRA (equivalente a
  `COLOR fg,bg`), não por caractere — 2 seletores de paleta MSX1 (INK/PAPER) globais por tela.
- **Largura escolhível por tela**: 40 ou 80 colunas (`WIDTH 40`/`WIDTH 80`), escolhida ao criar cada
  tela nova e gravada junto com ela.

**Janela** (`editor/Screen0EditorGui.pbi`, `Screen0Editor_OpenWindow()`):

- **Barra de projeto** — mesmo padrão número/tag/navegação (primeiro/anterior/próximo/último)/Novo/
  Registrar dos demais editores, ícones reaproveitados de `CharsetEditorGui.pbi`
  (`CharEd_CreateNavIcon`/`CreateNewIcon`/`CreateRegisterIcon`). **Novo** pergunta a largura (janela
  auxiliar de 2 opções, `Scr0Ed_AskWidth()`) antes de zerar a grade.
- **Canvas** — largura fixa na tela (~640px); o **zoom se ajusta à largura escolhida** (2x/célula 16×16
  pra 40 colunas, 1x/célula 8×8 pra 80 colunas — `Scr0Ed_ZoomForWidth()`), o que também combina com o
  próprio hardware real (MSX2+ usa fonte fisicamente menor em `WIDTH` acima de 40). Cada célula é
  desenhada pixel a pixel a partir do bitmap 8×8 real da fonte ativa quando disponível (ASCII normal e
  os 128 caracteres de `Dig_TransOriginal`, byte MSX = `$80+índice`); os 31 caracteres de
  `Dig_TransReplacementOrder` (box-drawing/naipes, sem bitmap próprio neste codebase — só existem via
  escape de impressão `CHR$(1)+CHR$(n)`) caem numa aproximação visual com a fonte do sistema, mesma
  técnica do preview de `CharMapGui.pbi`.
- **Fonte** — combo "Padrão" (alfabeto embutido, `ProjectDB::FetchDefaultAlphabet`) + `#N` de cada
  alfabeto já cadastrado no banco do projeto (`ProjectDB::ListAlphabetNumbers`/`FetchAlphabet`), mesmo
  mecanismo já usado pela ferramenta TEXTO do editor **Draw Screen 2...** (`Screen2EditorGui.pbi`).
- **Paleta** — dois `CanvasGadget` (Tinta/Fundo) reaproveitando `SpriteEd_FillPalette` (16 cores MSX1) e
  `Scr2Ed_RedrawMiniPalette`/constantes de grade (`Screen2EditorGui.pbi`) tal como estão, duplicados
  pra INK e PAPER.
- **Seis ferramentas** (uma aba por ferramenta, `PanelGadget`):
  - **Texto** — digita numa `StringGadget`, clique no canvas posiciona horizontalmente a partir da
    célula clicada (corta no fim da linha, sem quebra automática).
  - **Caractere** — a própria grade de 159 caracteres de `Inserir → Caractere Especial...` embutida tal
    como está (`CharMap_Redraw`/`CharMap_CharAt`, `CharMapGui.pbi`, incluído antes deste arquivo); clique
    escolhe, clique/arraste no canvas estampa.
  - **Quadro** — 2 cliques (cantos opostos) desenham uma moldura com linhas simples
    (`Scr0Ed_DrawBox`), unindo automaticamente com quadros já existentes que uma borda nova encoste
    (formando T/cruz) via um **bitmask de 4 direções** (`Scr0Ed_BoxMaskToChar`/`BoxCharToMask` — bit0
    cima/bit1 baixo/bit2 esquerda/bit3 direita, 11 combinações cobrindo exatamente o conjunto de
    caracteres disponível: `─│┌┐└┘├┤┬┴┼`).
  - **Sombra** — 2 cliques estampam uma faixa do bloco de sombra médio `▒` deslocada uma célula
    pra baixo/direita ao longo das bordas direita e inferior do retângulo marcado (`Scr0Ed_ApplyShadow`)
    — padrão clássico de sombra de editor ANSI (não existe `░`/`▓` no conjunto de caracteres deste
    codebase, só `▒`).
  - **Bloco** — 2 cliques preenchem um retângulo com o "caractere atual" (`Scr0Ed_FillRect`).
  - **Borracha** — clique/arraste estampa espaço.
  - Ferramentas de 1 clique-arraste (Caractere/Borracha) reaproveitam o mesmo padrão de
    `#PB_EventType_MouseMove` + checagem de `#PB_Canvas_Buttons & #PB_Canvas_LeftButton` já usado pelo
    lápis/borracha do editor de sprites (`SpriteEditorGui.pbi`).
- **Geração de código** (`Scr0Ed_BuildCode`) — **Injetar no cursor**/**Copiar** emitem `SCREEN 0`/
  `WIDTH`/`COLOR`/uma sequência de `LOCATE 0,linha:PRINT "...";` com os **glifos Unicode literais** de
  cada célula (linhas em branco viram nenhum `PRINT`, não uma linha vazia). A tradução `-tr` do próprio
  pipeline Dignified (já validada, mesmo mecanismo que motivou `CharMapGui.pbi`) resolve pro byte/escape
  nativo MSX na hora de tokenizar — o editor não precisa calcular nenhum endereço de VRAM pro texto em
  si. Quando uma fonte customizada (não-padrão) está escolhida, um carregador `DATA`+`VPOKE` é
  prefixado, carregando os 2048 bytes do alfabeto na **Pattern Generator Table do SCREEN 0, `&H0800`**
  — endereço de hardware **diferente** do `&H0000` usado por SCREEN 1/2 (`CharsetEditorGui.pbi`'s
  `CharEd_ScreenPgtAddress()` simplifica pra `&H0000` "pra todos os modos", o que é certo pra SCREEN
  1/2 mas não pra SCREEN 0 — não foi alterado, só usado o endereço correto aqui). Nenhum endereço de
  VRAM do SCREEN 0 estava documentado neste repo antes desta sessão.

**Armazenamento** (`ProjectDB.pbi`, tabela `screen0_screens`) — desvio real de design em relação ao
`grid_data` como bytes crus originalmente cogitado: a grade guarda o **codepoint Unicode** de cada
célula (4 dígitos hex, `Array GridCodes.u(1)`), não um byte MSX 0-255, porque os 31 caracteres de
`Dig_TransReplacementOrder` (necessários pra ferramenta Quadro) não cabem num único byte — só existem
via o escape de impressão de 2 bytes. Mesmo padrão de `StoreAlphabet`/`FetchAlphabet` (DELETE+INSERT,
tag truncada a 16 chars, valores extras via getters `Last*`), com `width`/`ink_color`/`paper_color`/
`alphabet_number` (-1 = fonte padrão) gravados junto.

**Verificado**: harness de auto-teste temporário (flag `--scr0test`, removido após uso) confirmou a
lógica pura — roundtrip completo do bitmask de moldura (todas as 11 combinações), uma moldura 5×3 real
gerando os caracteres certos em cada posição, sombra deslocada e corretamente cortada na borda da
largura, texto estampado na posição certa, geração de código pulando linhas em branco. Layout
verificado por screenshot real (`PrintWindow` + `RedrawWindow` antes de capturar, ver memória do
projeto) das abas Texto e Caractere — grade de 159 caracteres, paletas e barra de projeto sem
sobreposição/corte. Testes interativos de clique no canvas (desenhar de fato com o mouse) ficam pro
usuário confirmar ao vivo — automatizar clique num `CanvasGadget` a partir de fora do processo exigiria
mensagens de baixo nível num controle sem API pública de hit-testing, mesma cautela já registrada em
`CLAUDE.md` sobre `SendMessage` cross-process em controles customizados.

#### 20b. WIDTH 80: segunda cor de texto (estática ou piscante) — implementado (2026-08-04, mesma sessão)

O usuário pediu (e já suspeitava corretamente) que o modo de 80 colunas do MSX2+ permite 2 cores de
texto fixas na tela, travando o mecanismo de pisca-pisca. **Pesquisado a fundo antes de escrever
qualquer código** (Konamiman MSX2 Technical Handbook + MSX Wiki via `WebSearch`/`WebFetch`, cruzando
duas fontes independentes) em vez de confiar de memória em detalhe de registrador de VDP — o risco de
gerar `VDP`/`VPOKE` errados e o código não funcionar em hardware/openMSX real era alto demais pra
arriscar. Confirmado, não é gambiarra:

- **VDP R#12** = segundo par tinta/fundo ("Cor 2") — em BASIC, `VDP(13) = tinta2*16+fundo2` (o offset
  de +1 entre número de registrador e índice de `VDP()` já estava documentado no próprio dicionário
  desta IDE, `editor/MsxBasic2PlusDictData.pbi`, verbete "VDP (MSX2+)": registradores 8-23 mapeiam pra
  `VDP(9)` a `VDP(24)`).
- **VDP R#13** = duração de cada fase do pisca-pisca — `VDP(14) = duraçãoNormal*16+duraçãoCor2`, nibble
  alto = tempo mostrando a cor normal (R#7), nibble baixo = tempo mostrando a Cor 2 (R#12), cada unidade
  = 1/6 segundo (faixa 0-15, até 2.5s por fase). **`duraçãoNormal=0` trava a célula marcada
  permanentemente na Cor 2** (nunca gasta tempo na fase normal) — o "pisca travado" que o usuário
  descreveu, comportamento documentado de verdade, não suposição.
- **Tabela de "pisca"** (reaproveita o mecanismo físico da Color Table de SCREEN 1) — 1 bit por
  caractere, 240 bytes (80×24÷8), endereço padrão `&H0800` no modo WIDTH 80.
- **Achado real**: o mapa de VRAM padrão do modo WIDTH 80 é diferente do modo de 40 colunas — Name
  Table `&H0000` (igual), tabela de pisca `&H0800`, mas a **Pattern Generator Table fica em `&H1000`**,
  não `&H0800` como em 40 colunas (esse endereço fica ocupado pela tabela de pisca nesse modo). Isso
  expôs um **bug real já existente** no carregador de fonte customizada (`Scr0Ed_BuildCode`, escrito na
  sessão anterior): sempre usava `&H0800` fixo, certo só pra 40 colunas — corrigido calculando o
  endereço certo por largura.

**Ferramenta nova "Atributo"** (7ª aba) — clique/arraste liga, botão direito (clique ou arraste) desliga
o atributo de Cor 2 numa célula, sem tocar no caractere - uma "camada" independente aplicável depois de
já ter desenhado texto/quadro/etc, mesmo espírito de clique/arraste já usado por Caractere/Borracha
(`#PB_EventType_MouseMove` + `#PB_Canvas_Buttons`). Barra de opções ganhou duas paletas "Cor 2"
(Tinta2/Fundo2, reaproveitando `Scr2Ed_RedrawMiniPalette` tal como as paletas Tinta/Fundo já existentes)
e dois campos de duração (0-15, clampados no `#PB_EventType_Change`) — todos desabilitados
automaticamente (`DisableGadget`) quando a tela é de 40 colunas, já que o hardware não tem esse recurso
nesse modo (a ferramenta Atributo também ignora clique se `Width<>80`, defesa em profundidade além do
`DisableGadget`). O canvas mostra uma **prévia estática** da Cor 2 nas células marcadas (não anima o
pisca-pisca de verdade — ver Lacunas abaixo).

**Armazenamento** (`ProjectDB.pbi`, `screen0_screens`) — 5 colunas novas: `ink2_color`/`paper2_color`/
`blink_on_period`/`blink_off_period` (INTEGER, defaults 15/1/8/8) e `attr_data` (TEXT, mesmo padrão hex
2-dígitos/célula de `grid_data`, mas guardando 0/1 por célula em vez de bit-packing de verdade —
simplicidade > espaço, consistente com o resto do arquivo). `StoreScreen0`/`FetchScreen0` ganharam os
parâmetros correspondentes + `Array GridAttrs.a(1)`; sem migração porque a tabela só existe desde a
sessão anterior, ainda não distribuída.

**Verificado**: harness de auto-teste temporário (flag `--scr0test2`, removido após uso) confirmou:
regressão de 40 colunas (nenhum bloco de Cor 2/VDP aparece), endereço da PGT saindo `&H1000` pra 80
colunas com fonte customizada, nenhum bloco de Cor 2 quando nenhuma célula está marcada, e — com 3
células marcadas — `VDP(13)`/`VDP(14)` com os valores exatos esperados e os bytes da tabela de pisca
empacotados bit a bit corretos (`&HC0,&H80,...`, conferido MSB-primeiro). Layout verificado por
screenshot real das duas paletas "Cor 2" novas com a seleção certa, campos de duração desabilitados
numa tela de 40 colunas, e as 7 abas de ferramenta (incluindo "Atributo") sem sobreposição/corte.

**Fora do v1, decisão de escopo deliberada** (não implementado agora): o canvas do editor não anima o
pisca-pisca de verdade durante a edição, só mostra a Cor 2 estaticamente nas células marcadas —
animação ao vivo exigiria um `AddWindowTimer` redesenhando o canvas periodicamente; a duração
configurada só afeta o código gerado (`VDP(14)`), não a prévia. Fica como incremento futuro se o
usuário quiser.

### 21. Editor de tela SCREEN 1 estilo TheDraw/AcidDraw (`Criar → Screen 1...`) — implementado (2026-08-05)

Segunda da família planejada em [[project-screen0-editor]] (SCREEN 0 → SCREEN 1 → SCREEN 2, este módulo
sendo o SCREEN 1). Pedido explícito do usuário: mesmo espírito do editor SCREEN 0, mas com a diferença
de cor real do SCREEN 1 — a Color Table real do TMS9918 guarda 32 bytes (Tinta\<\<4|Fundo cada), **1 por
GRUPO DE 8 CÓDIGOS DE CARACTERE** (código\8, não por posição de tela), endereço padrão `&H2000`
(confirmado contra a MSX Wiki, "VDP Table Base Address Registers"/"SCREEN 1", antes de escrever
qualquer código). Diferente do SCREEN 0, aqui **não há** "uma cor pra tela inteira" nem WIDTH
configurável — a grade é fixa 32×24 (768 células), sem diálogo de "Novo" perguntando largura.

**A "tabela ASCII do alfabeto escolhido"** pedida pelo usuário é a grade de 256 células
(`Scr1Ed_DrawCharPicker`, `editor/Screen1EditorGui.pbi`) na coluna direita — mostra o bitmap real de
cada um dos 256 códigos do alfabeto ativo (padrão ou um alfabeto do banco do projeto), com o FUNDO de
cada célula já pintado na cor do seu octeto (Tinta/Fundo do grupo de 8 a que aquele código pertence) —
a colorização "direto na tabela ASCII" pedida. Clicar escolhe o "byte atual" (usado pelas ferramentas
Caractere/Bloco); as duas paletas Tinta/Fundo ao lado não pintam a tela inteira como no SCREEN 0 — mudam
a cor do OCTETO do byte atual (os 8 códigos daquele grupo), refletido tanto na grade quanto na tela.

**Diferença de armazenamento em relação a `Screen0EditorGui.pbi`**: a grade guarda o **byte MSX cru
(0-255)**, não um codepoint Unicode. Isso é possível — e mais simples — porque, ao contrário do SCREEN
0, o SCREEN 1 não precisa do truque "imprimir o glifo Unicode literal e deixar a tradução `-tr` resolver
depois": os 31 caracteres "gráfico" de `DignifiedPreprocessor.pbi` (`Dig_TransReplacementOrder` —
moldura/naipes/carinhas) **são, na verdade, os códigos MSX 1-31** — achado real, confirmado lendo
`Dig_TransReplacement`: cada um vira `Chr(1)+Chr(64+posição)` (`Chr(1)` é o prefixo de escape que o
driver de tela do MSX usa pra imprimir um dos 31 "gráficos" ocupando os códigos de controle 1-31 sem
colidir com controles de verdade; a letra que segue codifica qual gráfico, exatamente
`Chr(64+posição)`), e `DefaultCharsetMsx.pbi` confirma byte a byte: os bitmaps dos códigos 1-31 do
alfabeto padrão SÃO literalmente carinhas/naipes/moldura na mesma ordem de `Dig_TransReplacementOrder`.
`Scr1Ed_GlyphByteFor()` cobre essa faixa além da ASCII 32-126 e dos 128 `Dig_TransOriginal` (128-255)
que `Scr0Ed_GlyphByteFor` já cobria — juntas, resolvem todos os 256 códigos exceto 0 e 127 (sem
representação Unicode neste codebase; só acessíveis clicando a célula deles direto na grade de 256, não
digitando).

**Geração de código** (`Scr1Ed_BuildCode`) **não** reaproveita a tradução `-tr` como
`Screen0EditorGui.pbi` faz — constrói a expressão BASIC (literais entre aspas + `CHR$(n)` concatenado)
diretamente a partir dos bytes crus da grade (`Scr1Ed_BuildLineExpr`), mais simples e robusto aqui: sem
depender de tabela de tradução no meio do caminho, só ASCII puro no `.dmx` gerado, correto pra qualquer
alfabeto (a fonte só muda a APARÊNCIA do byte, nunca seu número). Emite, em ordem: `SCREEN 1`, a Tabela
de Cores (`FOR CI=0 TO 31:READ CD:VPOKE 8192+CI,CD:NEXT CI` + `DATA`, 32 bytes) e, se uma fonte
customizada estiver escolhida, o carregador da Pattern Generator Table (`&H0000` — mesmo endereço que
`CharEd_ScreenPgtAddress()` já usa pra SCREEN 1/2, `CharsetEditorGui.pbi`), depois `LOCATE`/`PRINT` por
linha (linhas em branco viram nenhum `PRINT`).

**Ferramentas**: as mesmas 6 da primeira versão do SCREEN 0 (Texto, Caractere, Quadro, Sombra, Bloco,
Borracha — sem "Atributo", exclusiva do mecanismo de Cor 2/piscar do WIDTH 80 do SCREEN 0). Molduras/
sombra reaproveitam a lógica de bitmask/junção de `Scr0Ed_BoxMaskToChar`/`BoxCharToMask`
(`Screen0EditorGui.pbi`, já validada) por baixo — só convertendo pra/de byte MSX nas bordas
(`Scr1Ed_BoxMaskToByte`/`Scr1Ed_ByteToChar`) — e `Scr0Ed_DrawGlyphBitmap` é reaproveitado tal como está
pra desenhar qualquer byte 0-255, tanto no canvas principal quanto na grade de 256.

**Armazenamento** (`ProjectDB.pbi`, tabela `screen1_screens`) — `grid_data` hex-codifica 2 dígitos/byte
(768 células, mais simples que os 4 dígitos/célula de `screen0_screens` porque não precisa representar
Unicode); `octet_data` guarda os 32 pares Tinta/Fundo, 1 dígito hex cada (64 dígitos ao todo). Mesmo
padrão DELETE+INSERT de `StoreScreen0`, tag truncada a 16 chars.

**Verificado**: harness de auto-teste temporário (flag `--scr1test`, removido após uso) confirmou:
`Scr1Ed_GlyphByteFor`/`Scr1Ed_ByteToChar` corretos nas 3 faixas (ASCII, `Dig_TransOriginal`,
`Dig_TransReplacementOrder`) e roundtrip perfeito pros 254 bytes com representação Unicode (só 0 e 127
ficam de fora, como esperado); roundtrip de bitmask de moldura pras 11 combinações; uma moldura real
5×3 gerando os bytes certos em cada posição (inclusive contra o cálculo independente da função, não só
valores hardcoded); sombra deslocada correta; `Scr1Ed_StampText` corrigindo posição mesmo com aspas no
meio do texto; `Scr1Ed_BuildLineExpr` produzindo a expressão `CHR$`/literal esperada; `Scr1Ed_BuildCode`
com/sem fonte customizada emitindo os blocos certos. **Bug real pego só na tela, não no harness**: a
primeira versão de `Scr1Ed_DrawCharPicker` deixava o `DrawingMode` em `#PB_2DDrawing_Outlined` (usado
pra desenhar a borda de cada célula) vazar pra iteração seguinte do laço, fazendo o preenchimento do
glifo/fundo da célula seguinte virar só contorno (invisível contra o fundo branco do canvas) — só a
primeira célula (byte 0) renderizava certo; as outras 255 apareciam em branco. Só apareceu no
screenshot real (`RedrawWindow`+`PrintWindow`, ver
[[project-purebasic-gui-screenshot-technique]]), não no harness de lógica pura (que não desenha nada) —
corrigido resetando `DrawingMode(#PB_2DDrawing_Default)` no início de cada iteração, antes de
`Scr0Ed_DrawGlyphBitmap`. Depois do fix, screenshot confirmou os 256 glifos reais (carinhas/naipes/
moldura/ASCII/acentuados) com fundo preto (padrão Tinta 15/Fundo 1 em todos os octetos) e a seleção
(byte 32) destacada na célula certa. **Não verificado**: clique/arraste interativo no canvas ou na grade
de 256 (mesma cautela já registrada pro SCREEN 0 — sem API pública de hit-testing pra simular clique
num `CanvasGadget` de fora do processo) — fica pro usuário confirmar ao vivo.

### 22. Editor de tela SCREEN 1+2 — Color Table real do SCREEN 2, 3 alfabetos, cor por linha de scanline (`Criar → Screen 1+2...`) — implementado (2026-08-05)

Terceira (e mais complexa) da família SCREEN 0/1/2, explicitamente pedida como "o modo mais complexo"
pelo próprio usuário. Mesma grade 32×24/mesmas 6 ferramentas de `Screen1EditorGui.pbi`, mas gerando
**SCREEN 2** (Graphics II) de verdade em vez de SCREEN 1, com os dois recursos extras que só o hardware
do SCREEN 2 tem:

1. **3 alfabetos, um por "terço" da tela** — a Pattern/Color Table reais do SCREEN 2 são divididas em 3
   blocos de 2048 bytes, selecionados por QUAL TERÇO DE LINHAS DE TELA a célula está (0-7/8-15/16-23,
   ou seja `Terço = Linha/8`). O usuário pediu "3 alfabetos diferentes para cada terço da tela", cada um
   iniciando em Padrão mas trocável independentemente — 3 combos "Fonte T1/T2/T3" na coluna direita.
   Endereços confirmados contra a MSX Wiki ("VDP Table Base Address Registers") antes de escrever
   qualquer código, mesma matemática já usada por `Scr2Ed_GenAlphabetLoader` em `Screen2EditorGui.pbi`:
   Pattern = `Terço*2048`, Color = `&H2000+Terço*2048`.
2. **Cor por LINHA DE SCANLINE de cada código de caractere** — a Color Table real do SCREEN 2 guarda 1
   par Tinta/Fundo por linha (8 linhas por glifo), não 1 por célula de tela nem 1 por grupo de 8 códigos
   como o SCREEN 1 (`screen1_screens`/`octet_data`) — o "color clash" de verdade do hardware: toda
   ocorrência do mesmo código no mesmo terço usa a MESMA cor por linha, não importa em que posição de
   tela apareça. 3 tercos × 256 códigos × 8 linhas = 6144 entradas, exatamente do tamanho da Color Table
   real (6144 bytes).

**Reaproveitado DIRETO de `Screen1EditorGui.pbi`, sem nenhuma alteração** (mesma grade 32×24, mesma
semântica de byte MSX cru por célula): `Scr1Ed_GlyphByteFor`/`ByteToChar`, `Scr1Ed_StampText`/`DrawBox`/
`ApplyShadow`/`FillRect`/`StampBoxEdge`/`BoxMaskToByte`, `Scr1Ed_BuildLineExpr` (geração de texto) e
`Scr0Ed_BoxMaskToChar`/`BoxCharToMask` (junção de moldura). Só a renderização e o modelo de cor são
novos — `Scr0Ed_DrawGlyphBitmap` assume 1 tinta/1 fundo pro glifo inteiro e não serve mais;
`Scr12Ed_DrawGlyphRows` (`editor/Screen12EditorGui.pbi`) desenha cada uma das 8 linhas com sua própria
cor.

**A "tabela ASCII"** pedida pelo usuário (grade de 256 células, `Scr12Ed_DrawCharPicker`) mostra 1 terço
por vez — um seletor "Terço 1 (0-7)/Terço 2 (8-15)/Terço 3 (16-23)" acima da grade escolhe QUAL terço
está sendo visualizado/editado ali (identificação explícita pedida pelo usuário), cada célula já
desenhada com as 8 cores por linha daquele código naquele terço. Importante: esse "terço em edição" da
tabela é só uma conveniência de UI — no CANVAS, cada célula sempre usa o alfabeto/cor do seu PRÓPRIO
terço real (`Linha/8`), não o que está selecionado na tabela.

**Bug de UX real reportado pelo usuário e corrigido no mesmo dia do lançamento (2026-08-05)**: o usuário
coloriu um caractere com o seletor em "Terço 1", carimbou no canvas (funcionou), trocou o seletor pra
"Terço 2" e viu a tabela ASCII mostrar o código como colorido, mas carimbar esse mesmo código na área
real do Terço 2 saiu sem cor — porque o seletor nunca teve nenhuma relação com ONDE se clica no canvas
(ver parágrafo acima), só com o que a tabela mostra. Corrigido de duas formas, ambas confirmadas com o
usuário via `AskUserQuestion` (escolheu as duas): (1) `Scr12Ed_RedrawCanvas` desenha uma linha-guia
preta+branca nos limites de linha 8 e 16 do canvas, sempre visível não importa a cor desenhada ali; (2)
`Scr12Ed_SyncEditThirdToRow` (novo helper de topo, `*EditThird` como ponteiro cru + `PokeI`/`PeekI`) é
chamado a cada clique/arraste no canvas — se `Linha/8` for diferente do `EditThird` atual, troca os rádios,
o texto do byte e redesenha a tabela ASCII automaticamente, garantindo que o que a tabela mostra sempre
corresponde ao terço que acabou de ser tocado.

**Edição de cor por linha** — **Cores do caractere...** abre uma janela separada
(`Scr12Ed_ColorEditor_OpenWindow`, confirmado com o usuário via `AskUserQuestion` — popup dedicado, não
painel embutido) com o glifo ampliado (zoom 20×) e 8 linhas, cada uma com sua própria mini-paleta
Tinta/Fundo — clique aplica na hora, sem botão "Aplicar" separado, mesmo padrão de clique-aplica-na-hora
do resto da IDE. **Cores em bloco...** aplica o MESMO padrão de 8 cores a TODOS os códigos de um
intervalo de uma vez; os dois botões compartilham a mesma função (`ByteStart=ByteEnd` para o caractere
único). **Copiar cores**/**Colar cores** movem o padrão de 8 cores de um código pra outro (array de 8
posições em memória, sem popup). **Resetar caractere**/**Resetar bloco...**/**Resetar TODOS os
caracteres do terço** voltam Tinta/Fundo pro padrão (15/1 = letra branca em fundo preto) no byte atual,
num intervalo, ou nos 256 códigos do terço selecionado de uma vez (o último com confirmação via
`MessageRequester`, ação irreversível).

**Melhoria pedida pelo usuário (2026-08-05, mesmo dia)**: o intervalo início/fim de "Cores em bloco..."
e "Resetar bloco..." deixou de ser digitado num popup modal (`Scr12Ed_AskBlockRange`, removido) — agora
os dois botões entram num modo de "escolha de bloco" (`BlockPicking`/`BlockPickStart`/`BlockPickAction`,
estado local de `Screen12Editor_OpenWindow`) onde o próximo clique na tabela ASCII escolhe o código
inicial e o clique seguinte o final (em qualquer ordem, normalizados com `Min`/`Max`), com uma moldura
ciano desenhada por fora da borda cinza normal (`Scr12Ed_DrawCharPicker`, parâmetros opcionais
`RangeLo`/`RangeHi`) indicando quais códigos estão marcados enquanto a escolha está em andamento — "marca
sutil" pedida explicitamente pelo usuário, que não esconde o glifo/cor por baixo por ser só um contorno.
Botão direito na tabela ASCII cancela a escolha pendente (mesmo idioma já usado pro Quadro/Sombra no
canvas); um guard central no topo do `Case #PB_Event_Gadget` cancela automaticamente qualquer escolha
pendente se o usuário interagir com QUALQUER outro gadget antes do 2º clique (evita ficar com um
`BlockPickStart` "órfão" referente a um terço/byte que o usuário já abandonou).

**Geração de código** (`Scr12Ed_BuildCode`) — `SCREEN 2` + Tabela de Cores dos 3 tercos (SEMPRE emitida,
2048 bytes/terço, incondicional — mesma filosofia "sempre emite tudo" já usada em `screen1_screens`) +
Pattern Generator Table só dos tercos com fonte customizada + `LOCATE`/`PRINT` por linha (reaproveita
`Scr1Ed_BuildLineExpr` sem nenhuma mudança).

**Armazenamento** (`ProjectDB.pbi`, tabela `screen12_screens`) — `grid_data` (768 células, 2 dígitos
hex/byte, igual a `screen1_screens`), `alphabet0`/`alphabet1`/`alphabet2` (1 por terço), `color_data`
(6144 entradas × 2 dígitos hex cada = Terço→Código→Linha, mesma convenção 4 bits/cor já usada por
`octet_data` em `screen1_screens`).

**Verificado**: harness de auto-teste temporário (flag `--scr12test`, removido após uso) confirmou:
reaproveitamento de `Scr1Ed_StampText` funcionando sem alteração nesta grade; `Scr12Ed_ByteInfoText`;
`Scr12Ed_BuildCode` com os 3 endereços de Color Table corretos (`&H2000`/`&H2800`/`&H3000`), a primeira e
a última entrada da tabela de cores com o byte exato esperado (Tinta\<\<4|Fundo), e o carregador de fonte
aparecendo SÓ no terço com alfabeto customizado (os outros 2 em Padrão, sem carregador). Layout verificado
por 2 screenshots reais (`RedrawWindow`+`PrintWindow`, ver
[[project-purebasic-gui-screenshot-technique]]): a janela principal (3 combos de fonte, seletor de terço,
grade de 256 com todos os glifos corretos — já nasceu certa desta vez, aplicando de saída a correção do
bug de `DrawingMode` descoberta no SCREEN 1, ver [[project-screen1-editor]] — botões, barra de projeto,
6 abas de ferramenta, sem sobreposição/corte) e o popup "Cores do caractere..." acionado via `SendMessage`
`BM_CLICK` num botão padrão do Win32 (controle nativo, seguro pra automação — diferente de simular clique
num `CanvasGadget`, que continua fora do escopo automatizável nesta IDE) — layout de 2 colunas × 4 linhas,
prévia e as 16 mini-paletas todas corretas para o byte 32 (espaço, prévia preta porque o glifo não tem
pixels de tinta — comportamento esperado). Clique/arraste interativo no canvas e na grade de 256
continuam não automatizados (mesma cautela já registrada pro SCREEN 0/1).

**Verificado (2026-08-05, correções de UX + bloco por clique/resetar)**: linha-guia preto+branco
confirmada por screenshot real separando visualmente os 3 terços no canvas; layout completo com as 3
novas fileiras de botão (`Resetar caractere`/`Resetar bloco...`/`Resetar TODOS...`) confirmado sem
sobreposição/corte contra a barra de projeto abaixo (a coluna direita ainda cabe dentro da altura do
canvas, unchanged `ToolPanelY`); clique em "Cores em bloco..." (`SendMessage`+`BM_CLICK`, botão nativo)
confirmado trocando o texto de dica acima da tabela ASCII pra "Bloco: clique o código INICIAL..."; clique
num rádio "Terço" nativo enquanto uma escolha de bloco estava pendente confirmado cancelando-a (texto de
dica volta ao padrão) via o guard central — o rádio em si não trocou de terço na automação porque
`BM_CLICK` num `OptionGadget` nem sempre gera o `#PB_EventType_Change` que PureBasic espera (limitação
conhecida de clique sintético, não bug do app; o `#PB_Event_Gadget` em si chegou, por isso o guard, que
não depende do `EventType`, disparou corretamente). Clique na grade de 256 pra completar a escolha de
bloco (2º clique) continua não automatizado, mesma cautela de sempre com `CanvasGadget`.

### 23. Ajuda SEE Tracker — estudo do formato SEE/.SEE (`Ajuda → SEE Tracker...`) — implementado (2026-08-06)

Pedido do usuário: ler o material original do **SEE** (Sound Effect Editor, Fuzzy Logic 1991/95,
`see/`) e registrar o máximo entendido numa tela de Ajuda nova, como preparação para um **tracker de
SFX nativo compatível com `.SEE`** a ser construído numa sessão futura (`por hora apenas estudo` — nada
de editor/gerador `.SEE` foi implementado nesta sessão). `editor/SeeTrackerHelpData.pbi` (dados) +
`editor/SeeTrackerHelpGui.pbi` (janela) — clone estrutural exato de `BasicDignifiedHelpGui.pbi`
(árvore agrupada + busca + histórico, reaproveitando `NBHelpGui_SetupStyles`/`_RenderMarkdown` de
`NestorBasicHelpGui.pbi`), menu **Ajuda → SEE Tracker...**.

**Fontes lidas** (todas em `see/`, gitignored/vendorizadas como as outras pastas de ferramentas
externas): `SEE3HELP.TXT` (manual oficial da v3.10a — a versão presente aqui; `SEE3HELP.DOC`/`.TED`
são a v3.00, mais antiga, mantidas só como histórico), `SEE3PLAY.ASC` (fonte Z80 do driver de replay
v3.10a, ASCII salvo do WBass2), `SEE.BAS`/`SEE.LDR`/`SEEV3_10.BAS` (bootstrap BASIC tokenizado, lido
parcialmente via os bytes crus — dá pra reconhecer nomes de variável/comentários mesmo sem
detokenizar), e os 4 arquivos de exemplo reais (`FIREBIRD.SEE`/`PLICS.SEE`/`QUARTH.SEE`/
`SEEDRUMS.SEE`), cujo cabeçalho foi inspecionado byte a byte (`xxd`) pra confirmar contra o manual e o
driver.

**Achado real mais valioso**: o manual descreve o mecanismo de loop (`FOR`/`NEXT`) e retomada
(`START`/`RERUN`) só pelo resultado (“patterns 000+001 repetem 7 vezes”), não pelo mecanismo. Lendo
`SEE3PLAY.ASC` linha a linha, ficou claro que `FOR`/`START` disparam **uma única vez** (na primeira
passagem natural do ponteiro por aquele pattern) — nas repetições seguintes, `NEXT`/`RERUN` só fazem o
ponteiro **revisitar os dados PSG** daquele pattern (pulando o próprio byte de evento, nunca
reprocessado), evitando qualquer re-disparo acidental do `FOR`. Outros achados por leitura cruzada
manual+driver: o byte de evento só tem 3 bits realmente testados pelo player (`AND $70`, 7 códigos
possíveis, não o byte inteiro como o manual dá a entender); o registrador de rustle do PSG é mascarado
pra 5 bits (`$1F`) no driver, não os "6 bits" que o manual descreve; o bit 4 do byte de volume é
literalmente o bit `M` (envelope de hardware) do próprio AY-3-8910 — quando ligado, o driver escreve o
byte cru, sem aplicar slide nem a escala de `Max Volume`; a fórmula exata de `Max Volume`
(`SEEVOL - (15 - volume_bruto)`, travada em 0) só aparece implementada em `FIXVOL`, não descrita em
lugar nenhum do manual; e a checagem de identificação do arquivo que o **player** realmente faz é só
4 bytes (`SEE3`), mais frouxa que os 8 bytes que o manual sugere — confirmado comparando os 4 `.SEE`
reais desta pasta, que usam sufixos de ID diferentes (`SEE3org`+`$10` vs `SEE3EDIT`) mas todos passam
no teste real do driver.

**Atualização (2026-08-06, mesmo dia) — cabeçalho resolvido por análise cruzada**: o usuário pediu pra
insistir em inferir mais sobre o campo `$08-$09` a partir do próprio `SEE3PLAY.ASC`. Rastrear a rotina
`SEE_IN` byte a byte revelou uma inconsistência real: o loop de checagem de ID faz `LD B,4` (só compara
4 bytes), mas o `LDIR` seguinte (que copia o cabeçalho pra memória de trabalho) começa logo depois desse
loop, sem reposicionar o ponteiro — lido ao pé da letra, isso copiaria a partir do byte `4` do arquivo,
não do `8` como os próprios comentários `%HISPT EQU &H08` do driver dizem. Testando as duas leituras
contra os 4 arquivos `.SEE` reais desta pasta (script Python ad-hoc, não commitado): a leitura literal
(byte 4) dá números sem sentido nenhum (nenhuma divisão inteira, nenhuma consistência entre arquivos);
a leitura "como os EQU dizem" (byte 8) bate **perfeitamente nos 4 arquivos** — `$0A-$0B` (HIPTA) menos
528 (16 de cabeçalho + 512 da tabela de posições) dividido por 15 dá um número **inteiro exato** em
todos: 807/125/272/51 patterns respectivamente, apesar de tamanhos de arquivo bem diferentes. Isso
confirma: **`$08-$09` é uma constante de capacidade (`$03FF`=1023, batendo com `%PATTS EQU &H0210 ;max
1024 patts`), não uma contagem por arquivo**, e `$0A-$0B` segue exatamente a fórmula
`patterns_usados*15+528` do manual. Suspeita forte sobre a causa da inconsistência: erro de transcrição
no `.ASC` (`LD B,4` deveria quase certamente ser `LD B,8`, já que o template `SEE_ID` comparado logo
abaixo tem exatamente 8 bytes declarados). Atualizado em `editor/SeeTrackerHelpData.pbi` (tópico
"Cabeçalho do arquivo... RESOLVIDO por análise cruzada").

**Achado colateral, ainda em aberto**: nos 4 arquivos, `tamanho do arquivo - HIPTA` dá exatamente
**1056 bytes sobrando no final**, sempre o mesmo valor independente do tamanho do arquivo — sugere mais
uma área de tamanho fixo não documentada no Apêndice B do manual (hipótese: tabela de nomes de SFX).
Não investigado byte a byte ainda. Também ficou uma anomalia isolada no `QUARTH.SEE` (único com ID
`SEE3EDIT`): seu campo `$0C-$0D` (`Highest used SFX`) leu `48394`, um valor absurdo pra um índice de
SFX de 0-255 — pode ser só uma variante/build diferente do editor, não confirmado. Ambos documentados
explicitamente no tópico "Status desta pesquisa e próximos passos" (`SeeTrackerHelpData.pbi`) para não
serem esquecidos quando a implementação começar de verdade.

**Atualização (2026-08-06, mesmo dia) — o tracker de verdade foi construído na sequência desta mesma
sessão**: ver módulo 24 logo abaixo (`Criar → SEE Tracker...`). O texto acima permanece como registro
do que foi entendido só de LER o material original, antes de qualquer linha de código do editor/driver
nativo ter sido escrita.

### 24. Editor SEE Tracker — efeitos sonoros nativos compatíveis com .SEE (`Criar → SEE Tracker...`) — implementado (2026-08-06)

Pedido do usuário na sequência do estudo (módulo 23, mesmo dia): "vamos criar Criar->See Tracker". Duas
decisões de arquitetura confirmadas com o usuário via `AskUserQuestion` antes de implementar (mesmo
padrão já usado nesta IDE pra toda decisão grande de UI/escopo):

- **Edição em grade nativa** (não uma lista de passos estilo editor PSG) — cada linha da grade é um
  pattern, colunas = os canais do formato real. Na prática, a edição de campo a campo (12 campos
  heterogêneos por pattern — evento, 3 frequências com tuning, rustle compartilhado, 3 volumes com
  wave/tuning, envelope) acontece num **painel lateral com controles de verdade** (combo de evento,
  campos numéricos, checkboxes), não digitando hex direto nas células — a grade em si é uma visão geral
  clicável (clicar uma linha seleciona o pattern pro painel), mais parecido com "clique escolhe, painel
  edita" do que com edição inline célula a célula.
- **Driver de replay Z80 nativo embutido** (não só os dados binários pra usar com o driver original) —
  opção mais ambiciosa das duas oferecidas, escolhida pelo usuário. Motivou portar `see/SEE3PLAY.ASC`
  pra rodar no assembler nativo desta IDE.

**Arquitetura, 3 arquivos:**

- `editor/SeeTrackerDriverAsm.pbi` — `SeeDrv_SourceCode()` devolve a fonte Z80 do driver, uma **porta**
  (não cópia literal) de `see/SEE3PLAY.ASC` adaptada pro `Z80Asm.pbi` desta IDE: hex `&Hxx` → `#xx`
  (única forma sem ambiguidade que o tokenizer aceita), rótulos com `%`/`!` (`%SEEID`, `!EVENT`) → nomes
  normais (`"%"`/`"!"` não são caracteres de identificador válidos aqui — só letras/dígitos/`$.?@_`,
  confirmado lendo `ChIsIdentExtra`; rótulos com `.` no nome, tipo `MAIN.A`, foram mantidos como no
  original, já que `.` É válido). Dois problemas reais corrigidos na porta (não presentes no arquivo
  original, introduzidos ou já existentes nele — ver módulo 23 pra discussão do bug original): a checagem
  de ID (só 4 bytes, permissiva de propósito) e a cópia dos 4 contadores do cabeçalho ficam
  **desacopladas** (a cópia sempre pula pro offset 8 explicitamente, em vez de confiar em onde o loop de
  validação parou); e foi removida a checagem opcional de overflow via `RST #20` (ROM-BIOS) que o próprio
  driver original já descrevia como dispensável — dado que o `.SEE` é sempre gerado por nós mesmos, essa
  situação não pode ocorrer. Vetor **novo** (não existe no original): `BSETFX` (offset +15), adaptador
  que empacota o argumento inteiro de `USR()` (chega em HL) em B (prioridade)+C (número do SFX) antes de
  saltar pro `SETSFX` cru, que precisa dos dois em registradores separados — sem isso, `SETSFX` não seria
  chamável direto de um `USR()` de um argumento só. **Verificado**: harness
  `editor/tools/SeeTrackerDriverTestCli.pb` monta a fonte, confirma 784 bytes sem erro e imprime o
  endereço de cada vetor/variável — os 6 `JP` da tabela de vetores conferidos byte a byte (`c3` + endereço
  little-endian) contra os símbolos resolvidos pelo assembler, todos batendo exatamente.
- `editor/SeeTrackerSynth.pbi` — modelo de dados: cada pattern são os **15 bytes crus exatamente no
  formato de arquivo** (não uma struct interpretada — mesma filosofia de `Screen12EditorGui.pbi` guardar
  byte MSX cru por célula), com procedures `SeeP_*` de acesso a cada campo/flag. `SeeSynth_Expand()` é o
  interpretador: caminha os patterns simulando `MAIN`/`DOEVENT`/`SETPSG` do driver **quadro a quadro**,
  reproduzindo com fidelidade um detalhe que só aparece lendo o driver linha a linha (não documentado no
  manual nem na Ajuda antes desta sessão): `TEMPO` e `HALT` interagem em dois níveis — cada "passo
  lógico" dura `TEMPO+1` quadros reais, e um `HALT(x)` segura o estado ANTERIOR por `x` passos lógicos
  antes de aplicar os dados do próprio pattern do halt, sem nunca reprocessar o evento de novo (mesmo
  princípio do `FOR`/`START`, que também só disparam uma vez — ver módulo 23). O resultado vira uma
  sequência concreta de `PsgStepData` (`PsgSynth.pbi`) — reaproveitamento direto do motor de síntese já
  usado pelo editor de Som PSG, zero código de síntese novo. `SeeGen_BuildSeeBlob()` monta o blob binário
  `.SEE` exato (cabeçalho com os offsets confirmados no módulo 23, tabela de posições **sempre nos 512
  bytes cheios** — bug real pego só ao revisar a função antes do primeiro teste: o driver usa
  `PATTS_OFS=#0210` como constante FIXA pro início dos patterns, uma tabela reduzida deslocaria os dados
  pro lugar errado). `SeeGen_BuildCode()` monta driver+blob e gera `DATA`/`POKE`/`DEFUSR` prontos (mesmo
  espírito "sempre gera tudo" do resto da IDE), consultando `Z80Asm::GetSymbolValue("SEEADR")` pro
  endereço real da variável a pokear, em vez de um offset chumbado. **Verificado**:
  `editor/tools/SeeTrackerSynthTestCli.pb`, 22 asserções cobrindo: pattern só-END não emite nada; `HALT`
  segura o estado anterior pela duração certa e depois aplica os dados do próprio pattern; `FOR(3)/NEXT`
  reaplica os dados do pattern-âncora exatamente 3 vezes (1 disparo + 2 repetições), nunca reprocessando o
  evento `FOR`; `RERUN` sem fim é truncado pelo teto de segurança (não trava o preview); geração de código
  não falha e contém os vetores/endereços certos; blob `.SEE` bate campo a campo com a fórmula confirmada
  no módulo 23.
- `editor/SeeTrackerEditorGui.pbi` — janela: grade (`CanvasGadget`, texto monoespaçado) + painel de edição
  + barra de projeto padrão (número/tag/navegação/Novo/Registrar, mesmo padrão dos demais editores) +
  Inserir/Apagar/Mover pattern + Copiar/Colar de **um** pattern (bloco de intervalo maior fica pra uma
  fase futura) + Tocar/Parar (mesmo mecanismo de `.wav` temporário do editor PSG) + Gerar código/Injetar
  no cursor/Copiar. Gotcha real de PureBasic batido de novo nesta sessão (já documentado nas memórias de
  Screen0/Screen12): `SeeEd_RefreshPanel`/`SeeEd_ApplyPanel` foram escritas inicialmente como
  `Procedure` **aninhada** dentro de `SeeTrackerEditor_OpenWindow` — ilegal em PureBasic — corrigido
  hoisteando as duas pro escopo de arquivo, recebendo os IDs de gadget como parâmetro.

**Integração com o projeto** (`ProjectDB.pbi`) — tabela `see_sfx` (`sfx_number`/`tag`/`pattern_count`/
`patterns_data`), mesmo padrão hex-achatado de `psg_sounds`/`StoreSound`/`FetchSound` (`PatternBytes()` 1D
`PatternBytes(i*15+b)`, não uma matriz 2D, pelo mesmo motivo de `ReDim` só redimensionar a última
dimensão).

**Verificado ao vivo (não só os harnesses headless)**: app completo aberto, menu **Criar → SEE
Tracker...** clicado via `PostMessage`/`WM_COMMAND` (mesma automação segura já usada nesta IDE), grade e
painel renderizando corretos desde a primeira screenshot; **Inserir pattern** clicado (`BM_CLICK`, botão
nativo) confirmado adicionando uma linha e atualizando o painel; **Gerar código** clicado ao vivo gerou
5399 caracteres sem erro (driver assemblado + blob montado dentro do processo real da GUI, não só no
harness); **Copiar** + inspeção do clipboard confirmou os endereços exatos (`49152`=`$C000`,
`49167`=`$C000+15` BSETFX, `49161`=`$C000+9` CUTSFX, `49155`=`$C000+3` SEE_EX, `49170`=`$C012` SEEADR) —
todos batendo com o que o harness standalone já tinha confirmado; **Tocar** num SFX vazio (só END)
respondeu corretamente "Nada pra tocar" sem travar. Clique/arraste na grade em si (`CanvasGadget`)
continua não automatizado (mesma cautela de sempre nesta IDE).

**Bug real corrigido: "Tocar" não tocava nada — achado e corrigido na sequência da mesma sessão
(2026-08-06)**: usuário reportou "quando coloco tocar, não está tocando". Reproduzido ao vivo (não só
supondo): a causa raiz de verdade era `InitSound()` **nunca ter sido chamado** nesta janela —
`PsgEditorGui.pbi`/`MmlEditorGui.pbi` cada um chama `InitSound()` (guardado por um `Global` booleano
"só uma vez", `PsgEd_SoundSystemReady`) dentro da própria abertura de janela, e `SeeTrackerEditorGui.pbi`
nunca ganhou o equivalente ao ser escrito. Sem isso, `LoadSound()` falha (devolve 0) **silenciosamente**,
e como o código não tinha `Else` pros 3 níveis de falha possíveis (`TotalSamp<=0`/`*Buf` nulo/
`SoundHandle` nulo), "Tocar" não fazia literalmente nada visível — nem tocava, nem avisava erro nenhum.
Corrigido com o mesmo padrão `SeeEd_SoundSystemReady`/`InitSound()` guardado, mais mensagens de erro
reais nos 3 pontos que antes falhavam em silêncio. **Achado colateral, também real e corrigido junto**:
mesmo com o áudio funcionando, um SFX novo (1 pattern, evento `END`) tinha um efeito colateral sério —
clicar **Inserir pattern** sempre insere DEPOIS do pattern selecionado, então o primeiro pattern novo
ficava DEPOIS do `END` inicial, ou seja, **nunca alcançado** no playback (que sempre começa no pattern 0
— ver `SeeSynth_Expand`). Corrigido de duas formas: (1) o estado inicial de um SFX novo agora começa com
**2 patterns** (`SeeEd_InitBlankSfx` — 0 em branco editável, 1 com `END`), não 1 só; (2) **Inserir
pattern** agora insere ANTES do pattern selecionado quando esse pattern tem evento `END` (nunca depois),
então um `END` nunca fica bloqueando dados inseridos depois dele por engano. Terceiro ajuste, de
ergonomia (o editor SEE original liga o canal implicitamente ao digitar uma frequência — manual: "to
switch the channel off, simply press on Backspace" — nosso editor exige marcar "Som" à parte, um passo
que o original não tinha): os campos de frequência/volume agora **ligam sozinhos** o checkbox "Som"
daquele canal na primeira vez que o valor digitado fica diferente de zero (nunca desliga sozinho, só o
usuário desmarca de propósito). Mensagem de "Nada pra tocar" também ficou diagnóstica (diz
explicitamente quando a causa é um `END` no pattern 0, com a sugestão de correção). Verificado ao vivo:
depois da correção, digitar frequência+volume no pattern 0 (estado inicial já não tem mais `END` na
frente) liga "Som" sozinho e **Tocar** mostra "Reproduzindo..." de verdade (`GetWindowText` no controle
de status, não só a screenshot — a screenshot do texto de status especificamente se mostrou pouco
confiável nesta automação sem foco real de janela, gotcha novo de automação registrado aqui pra não
repetir: prefira `GetWindowText` a `PrintWindow` pra conferir o CONTEÚDO de um `TextGadget`, screenshot
serve pra layout/grade).

**Bug real corrigido: grade de patterns ilegível ("fundo preto e letras escuras") — achado e corrigido
na sequência da mesma sessão (2026-08-06)**: usuário reportou que as linhas com dados da grade (canvas
à esquerda, `SeeEd_DrawGrid`) apareciam com fundo preto e texto escuro, difícil de ler. **Só foi possível
identificar a causa real com screenshot de verdade** (`PrintWindow` + crop/zoom, técnica descrita no
início deste módulo) — lendo só o código, `SeeEd_DrawGrid` parecia inofensivo
(preenche a grade toda de branco com `Box()`, depois `DrawText()` colorido por cima). A screenshot real
mostrou cada valor dentro de uma "caixinha" preta opaca do tamanho exato do texto, mesmo sobre uma linha
branca/realçada por baixo. **Causa raiz**: nenhum `DrawText()` da função trocava pra
`DrawingMode(#PB_2DDrawing_Transparent)` antes de desenhar — no modo padrão
(`#PB_2DDrawing_Default`), `DrawText()` pinta um retângulo OPACO atrás do texto usando `BackColor()`,
que nunca tinha sido setada em lugar nenhum da função (fica preta, o padrão do PB, se nunca chamada).
Resultado: cada célula (índice, evento, frequência, ruído, volume, envelope) ficava com uma caixa preta
colada atrás do dígito, e como as cores de texto originais já eram tons escuros saturados (pensadas só
pra contraste sobre fundo branco: `RGB(0,0,150)` navy, `RGB(120,0,0)` vinho, `RGB(90,0,90)` roxo escuro
etc.), o resultado era ilegível em qualquer fundo — **presente nos dois temas** (Light e Dark), só mais
perceptível pro usuário no tema Dark porque a caixa preta de cada célula contrasta mais com o resto da
janela escura ao redor. Corrigido com um `DrawingMode(#PB_2DDrawing_Transparent)` logo antes do bloco de
`DrawText()` de cada linha (mantém a cor de fundo já pintada pelo `Box()` da linha, seja branco ou o
realce de seleção). Aproveitado o mesmo fix pra também tornar a grade sensível a `EditorCfg\Theme`
(antes sempre desenhava fundo branco fixo, nunca lido nesta função) — tema Light mantém a paleta
original (branco + cores escuras saturadas, já com bom contraste uma vez removida a caixa preta); tema
Dark usa fundo cinza-azulado bem menos escuro que o preto da janela (`RGB(48,51,60)`, realce de seleção
`RGB(92,76,34)`) com cores de texto claras/vivas (`RGB(140,190,255)` azul, `RGB(255,130,130)` vermelho,
`RGB(255,195,110)` âmbar, `RGB(230,155,235)` magenta, `RGB(230,230,235)` quase-branco pro índice) —
atende ao pedido literal do usuário ("o fundo pode ser menos escuro e as letras mais brilhosas").
Verificado ao vivo nos dois temas via screenshot real (não só suposição): capturas antes/depois
mostram a caixa preta desaparecendo em ambos, e a paleta clara/escura nova renderizando exatamente como
codificado (cores de pixel amostradas em ambas as versões confirmam).

**Cursor de playback + seletor visual de forma do envelope — implementados na sequência da mesma
sessão (2026-08-06)**: usuário pediu (1) "faca o tocar mover uma especie de cursor em cada
pattern/linha para visualmente podermos ver onde estamos naquele momento" e (2) "na parte de Forma,
voce poderia fazer algo visual para podermos ver as formas do PSG? facilitando assim escolher um dos
numeros de forma".

Para o cursor de playback, `SeeSynth_Expand()` (`SeeTrackerSynth.pbi`) ganhou um novo parâmetro
`List OutPatIdx.i()`, preenchido em paralelo a `OutSteps()` (mesmo tamanho, elemento a elemento) com o
índice do PATTERN de origem de cada step — inclusive o step de espera do `HALT` (que também aponta pro
próprio pattern do `HALT`, já que o cursor deve ficar "parado" nele durante a espera, e não em nenhum
outro lugar). Assinatura muda, então os 4 call sites do harness `SeeTrackerSynthTestCli.pb` e o único
call site da GUI precisaram de um `NewList` a mais cada — sem parâmetro default possível pra `List` em
PureBasic (só tipos simples aceitam `=` default), então não dava pra manter compatível sem tocar nos
chamadores. Duas asserções novas no harness (Teste 2 e Teste 3) travam essa tag num nível bem mais
forte que "compila" — conferem os valores REAIS de `PatIdx` produzidos pelos casos já existentes de
`HALT`/`FOR`/`NEXT` (ex.: Teste 3 - FOR(3)/NEXT deve gerar `[0,0,0,1]`, já que o loop inteiro fica
"ancorado" no pattern do `FOR` e só o ÚLTIMO step, quando o contador realmente zera, move o cursor pro
pattern seguinte - exatamente o instante em que o replay avança de verdade). `SeeEd_DrawGrid()`
(`SeeTrackerEditorGui.pbi`) ganhou um parâmetro `PlayCursor.i = -1`, desenhado como uma borda dupla +
faixa de 4px na borda esquerda da linha, numa cor de destaque própria (`ColPlay` - verde, distinta do
realce de seleção tan/dourado e de todas as outras cores já usadas na grade) — deliberadamente
independente do realce de "Selected" (a linha que o usuário clicou pra editar): são dois conceitos
diferentes que podem coincidir ou não. Na janela, `PlayStepStartMs()`/`PlayPatArr()` (arrays
redimensionados via `ReDim` a cada "Tocar", não `Global`) formam a "linha do tempo" do efeito
atualmente carregado; um `AddWindowTimer()` de 40ms consulta `GetSoundPosition(SoundHandle,
#PB_Sound_Millisecond)` de verdade (não estima tempo decorrido por conta própria — imune a qualquer
atraso de início do driver de áudio) e acha em qual step aquele tempo cai, só redesenhando a grade
quando o pattern realmente muda (não a cada tick, pra não piscar à toa). Rola a grade automaticamente
(`ScrollTop`) se o cursor sair da área visível, senão um efeito com mais patterns que as 18 linhas
visíveis deixaria o cursor "desaparecer" ao passar da última linha. O cursor também acompanha corretamente
"Parar" e o fim natural da reprodução (comparando a posição atual contra a duração total já calculada,
sem depender de `GetSoundPosition()` reportar algo específico após o fim). **Verificado ao vivo com
screenshots reais em duas configurações diferentes** (não só suposição): com os dados HALT(15) no
pattern 1, o cursor apareceu corretamente na linha 1; depois de mover esses MESMOS dados pro pattern 0
via "Mover p/ cima" (botão já validado nesta sessão) e tocar de novo, o cursor apareceu na linha 0 -
prova de que o cursor segue o ÍNDICE real de onde os dados estão, não uma linha fixa. Uma terceira
captura depois do fim natural da reprodução confirmou o destaque sumindo sozinho (sem precisar de
"Parar").

Para o seletor visual de forma, `PsgSynth.pbi` já tinha `PsgSynth_ApplyEnvShape()`/`PsgSynth_EnvTick()`
— o MESMO gerador de envelope usado de verdade no motor de síntese (`PsgSynth_RenderStep`) - então a
nova `SeeEd_DrawEnvShapeGraph()` (`SeeTrackerEditorGui.pbi`) só simula 40 "quadros" com essas mesmas
duas procedures e traça a curva resultante, garantindo que o desenho é fiel ao som real (nunca uma
segunda implementação da tabela de formas que podia divergir). Dois usos dessa curva: (1)
`SeeEd_DrawEnvShapeIcon()`, um preview compacto sem rótulo ao lado do campo "Forma" no painel,
redesenhado a cada seleção/edição de pattern (via um novo parâmetro `G_EnvShapeIcon` encadeado em
`SeeEd_RefreshPanel`/`SeeEd_ApplyPanel` — mesmo padrão de "passar cada gadget como parâmetro" já usado
por todo o resto deste arquivo); (2) `SeeEd_PickEnvShape()`, uma janela modal com um botão "..." novo
que mostra as 16 formas reais do registrador 13 do PSG numa grade 4x4 (`SeeEd_DrawEnvShapeCell()`, com
rótulo hex 0-F + a curva + realce na forma atualmente selecionada) — clicar numa célula já escolhe e
fecha, mesmo espírito de um seletor de cor de paleta fixa pequena, sem precisar de OK/Cancelar
separado pra confirmar (só um "Cancelar" pra fechar sem escolher). **Verificado ao vivo via
screenshot**: as 16 formas renderizadas batem exatamente com a tabela padrão do AY-3-8910/YM2149 (0-3
decai e para no zero, 4-7 sobe e para no zero, 8 dente-de-serra descendente repetindo, 9 decai e para
no zero, A triângulo descendente-ascendente repetindo, B decai e para no máximo, C dente-de-serra
ascendente repetindo, D sobe e para no máximo, E triângulo ascendente-descendente repetindo, F sobe e
para no zero) — conferido visualmente contra a tabela de hardware conhecida, não apenas "compilou sem
erro".

**Botões Limpar/Limpar linha/Limpar bloco — implementados na sequência da mesma sessão (2026-08-06)**:
usuário pediu "crie um botão limpar para limpar totalmente os padrões já inseridos, e um botão para
limpar uma linha em particular, e outro para limpar um bloco". Três botões novos numa linha própria
(`SeeTrackerEditorGui.pbi`, entre "Copiar/Colar pattern"+"Tocar/Parar" e "Gerar código" — layout
recalculado com `5 * 34` em vez de `4 * 34` no cálculo de `ProjBarY`, já que agora são 5 linhas de
botões, não 4):

- **Limpar** (`G_ClearAll`) — mesmo padrão "só pede confirmação se `Dirty`" já usado por
  `G_New`/`G_First`/`G_Prev`/`G_Next`/`G_Last` neste arquivo; chama `SeeEd_InitBlankSfx()` (o mesmo
  helper usado por "Novo") mas **sem** trocar `SfxNumber`/`SfxTag` — é o mesmo slot, só esvaziado, não
  um SFX novo.
- **Limpar linha** (`G_ClearLine`) — um `SeeP_Clear(PB(), SelPattern)` direto, sem confirmação (mesmo
  nível de risco de "Colar pattern", que também sobrescreve sem perguntar) - zera os 15 bytes do pattern
  selecionado **no lugar**, sem deslocar nada (diferente de "Apagar pattern", que remove a linha de
  verdade).
- **Limpar bloco** (`G_ClearBlock`) — nova janela modal `SeeEd_AskPatternRange()` (mesmo padrão de
  `SeeEd_PickSfxFromFile()` já existente no arquivo: `DisableWindow` do pai, loop de evento próprio,
  devolve via ponteiro cru + `PokeI`), pede um intervalo `De`/`Até` pré-preenchido com `SelPattern` nos
  dois campos (clicar "Limpar" sem editar equivale a limpar 1 linha só), grampeia em `0..NumPatterns-1`
  e inverte com `Swap` se o usuário digitar `De > Até` em vez de travar. A própria janela modal já é o
  gate de confirmação (não pede um segundo `MessageRequester` em cima). Nenhum dos três remove pattern
  nenhum da lista (`NumPatterns` não muda) — só zeram dados, mesma distinção já explicada acima entre
  "Apagar pattern" (remove) e estes três (zeram no lugar).

**Verificado ao vivo via screenshot** (não só "compilou"): inseridos 3 patterns extras, "Limpar bloco"
com intervalo 0-2 zerou os três em uma tacada só (incluindo o pattern com `END`, virando `None` — sem
guarda especial pra isso, já que `SeeSynth_Expand` já trata "ponteiro correu pra fora da lista" igual a
um `END` explícito, então um efeito sem nenhum `END` de verdade não trava nem quebra); depois "Limpar"
mostrou o `MessageRequester` de confirmação (havia alterações não registradas), e confirmando com "Sim"
voltou exatamente ao estado inicial (`Pattern atual: 0/1`, mesmo `SfxNumber` de antes).

**Bug real corrigido: título das colunas desalinhado com a grade — achado e corrigido na sequência da
mesma sessão (2026-08-06)**: usuário reportou "os títulos das colunas #, Evt, Snd1... está desalinhado
com as colunas". Causa raiz: o cabeçalho era um `TextGadget` comum com o texto alinhado à mão via
espaços (`SeeEd_HeaderLine()`, string fixa "#    Evt   Snd1  Snd2  Snd3..."), renderizado na fonte
padrão da UI (proporcional) - nunca a mesma fonte nem os mesmos offsets X em pixel usados por
`SeeEd_DrawGrid()` pra desenhar os dados abaixo (`#SeeEd_GridColIdx`/`#SeeEd_GridColEvt`/etc.). Como uma
fonte proporcional não tem largura de caractere constante, o espaçamento manual por contagem de
caracteres nunca corresponderia de verdade aos limites de coluna em pixel da grade - alinhamento
"por coincidência de fonte", não por construção. Corrigido substituindo o `TextGadget` por um
`CanvasGadget` (`G_Header`, mesma largura `#SeeEd_GridW`, `#SeeEd_GridHeaderH`=18px de altura) desenhado
uma única vez por `SeeEd_DrawHeader()` usando os MESMOS `#SeeEd_GridColXxx` e o MESMO preenchimento
esquerdo (`X+2`/`X+4`) de cada célula que `SeeEd_DrawGrid()` já usa pros dados - alinhamento garantido por
construção (os dois desenhos compartilham os números), não por espaçamento de texto. `SeeEd_HeaderLine()`
removida (função obsoleta, sem mais chamadores). Também aplica a mesma fonte `Consolas 9` (`FixedFont`)
usada na grade, e segue o tema (fundo levemente diferenciado do resto da janela nos dois temas, texto
claro no Dark). **Verificado ao vivo via screenshot com crop/zoom**: cada rótulo (`#`/`Evt`/`Snd1-3`/
`R1-3`/`V1-3`/`Wv`/`Time`) cai exatamente sobre a coluna de dados correspondente na linha de baixo.

**Importação de `.SEE` real — implementada na sequência da mesma sessão (2026-08-06)**: usuário pediu
"uma opção para ler arquivos SEE gerados pelo SEE original de MSX". Três funções novas em
`SeeTrackerSynth.pbi` — `SeeImp_IsValidHeader` (confere só os 4 bytes `SEE3`, mesmo critério permissivo
do driver real), `SeeImp_ListDefinedSfx` (varre a tabela de posições inteira, 256 slots fixos,
**sem confiar no campo `HISFX`** do cabeçalho — o `QUARTH.SEE` de exemplo já mostrou um valor implausível
nesse campo, ver módulo 23) e `SeeImp_ExtractSfxPatterns` (anda sequencialmente a partir do pattern
inicial do SFX escolhido até encontrar um evento `END`, mesma suposição de layout contíguo que todos os
exemplos do manual original seguem). Botão **Importar .SEE...** na janela (`SeeTrackerEditorGui.pbi`)
abre um `OpenFileRequester`, lista os SFX definidos numa janela auxiliar (`SeeEd_PickSfxFromFile`, mesmo
espírito de `Scr12Ed_AskBlockRange`) e substitui os patterns do SFX atual pelos importados (com
confirmação se houver alterações não registradas). **Validado contra um arquivo real** (`see/FIREBIRD.SEE`,
harness ad-hoc não commitado): 33 SFX encontrados, limites de pattern perfeitamente sequenciais (SFX #0
termina no pattern 7, SFX #1 já começa no 8, sem lacunas) e o primeiro SFX extraído (8 patterns) termina
corretamente num evento `END` (`$F0`, que também liga o bit 7 mencionado no manual — a máscara `$70` do
driver ainda reconhece certo). Verificação ao vivo do botão/diálogo na GUI real **não foi possível**: o
`OpenFileRequester` nativo do Windows, quando disparado por um `BM_CLICK` sintético vindo de outro
processo (a mesma automação usada em todo o resto desta sessão), não recebeu a digitação/Enter
simulados — nenhum travamento (o "Fechar" da mesma janela respondeu normalmente logo depois, confirmando
que a janela nunca ficou presa), só uma limitação conhecida dessa forma de automação com diálogos nativos
do shell, distinta da lista já registrada de `CanvasGadget`/clique real (ver notas de automação em outros
módulos). Confiança na correção vem do teste direto das funções `SeeImp_*` contra o arquivo real, não do
clique no botão em si.

**Deixado como trabalho futuro, não escondido**: cópia/colagem de um **intervalo** de patterns (só
1-a-1 nesta versão); `FIXVOL`/`Max Volume` não é aplicado no preview de áudio (sempre toca como se
`SEEVOL=15` — o código `.SEE` GERADO continua exato e aplica a escala de verdade no hardware/driver
real, é só o preview local que simplifica); nenhuma validação de round-trip byte a byte comparando um
SFX importado com o que o `SeeGen_BuildSeeBlob` geraria de volta a partir dele (o gerador produz um
formato NOVO/próprio, com sua própria tabela de posições reduzida a 1 slot usado — não tenta reescrever
o arquivo original byte a byte).

**Documentação — screenshot adicionado (2026-08-06)**: `README.md` e `docs/MANUAL.md` ganharam a
imagem `images/msxbasica-16.png` (efeito de 8 patterns tocando, cursor de playback visível no pattern 0,
botões **Limpar**/**Limpar linha**/**Limpar bloco** e o seletor visual de forma do envelope à direita),
mesmo padrão dos demais editores desta IDE (uma screenshot real por seção de feature). Descrição da
feature em `README.md` atualizada pra mencionar o cursor de playback, o seletor visual de forma e os
três botões de limpeza, que não estavam cobertos no texto original (escrito antes deles existirem).

### 25. Auto completar ("Palpiteiro") — implementado (2026-08-08)

Popup de sugestões enquanto o usuário digita, em abas `.dmx`/`.bas` (MSX-BASIC/Basic Dignified) e
`.asm` (Z80 Assembly). Mecanismo de exibição é 100% nativo do Scintilla (`SCI_AUTOCSHOW`/
`SCI_AUTOCACTIVE`/`SCI_AUTOCCANCEL`) — Enter/Tab aceitam, setas/Page Up/Page Down navegam, Esc cancela,
e a lista se estreita sozinha conforme mais letras são digitadas, tudo sem nenhuma tecla nova
interceptada (confirmado sem conflito com o teclado WordStar/JOE de `WordStarKeys.pbi`, que só
intercepta combinações com Ctrl).

**Disparo e reentrância**: `ScintillaCallBack()` recebe `#SCN_CHARADDED` a cada caractere inserido, mas
— igual ao padrão já estabelecido por `#SCN_MODIFIED`/`#Event_Rehighlight` — não chama `ScintillaSend-
Message` direto de dentro da notificação (ainda em andamento dentro do próprio `SendMessage` que a
disparou); em vez disso faz `PostEvent(#Event_AutoComplete, ...)` e o trabalho real acontece em
`HandleAutoCompleteCharAdded()`, já fora da notificação, no loop principal. A lista só é remontada
(`ShowAutoComplete()`) no exato instante em que a palavra sendo digitada atinge o mínimo de letras
configurado — depois disso o próprio Scintilla filtra o popup já aberto a cada tecla nova, sem precisar
rechamar `ShowAutoComplete()` (que varre o documento inteiro atrás de variáveis/rótulos) a cada
caractere. Backspace encolhendo a palavra abaixo do mínimo cancela o popup via checagem em
`#Event_UpdateUI` (que já disparava a cada movimento de caret/backspace) — `#SCN_CHARADDED` só dispara
em inserção, não em remoção.

**Vocabulário — abas `.dmx`/`.bas`** (`ShowAutoComplete()`, ramo `Else`):
- Mapas `Kw*` já existentes (usados pelo destaque de sintaxe): `KwStatement`/`KwFunctionPlain`/
  `KwFunctionDollar`/`KwOperatorWord`/`KwDignifiedStmt`/`KwBoolean`, mais `KwMsxBas2Rom*` quando o
  modo do documento é `"BAS"`.
- **`KwNestorBasic`** (novo) — os 87 nomes de wrapper `.NB_*` do NestorBASIC (módulo 9), construído em
  `InitKeywordMaps()` a partir de `NBHelp_Topics()\Wrapper` (mesma fonte de dados de `Ajuda →
  NestorBASIC...`, nunca diverge dela) — `NBHelp_BuildData()` é idempotente, então chamá-la aqui é
  seguro mesmo que a janela de ajuda nunca tenha sido aberta na sessão. Guardado **sem** o `.` inicial:
  como `.` não faz parte do conjunto de "caracteres de palavra" do Scintilla, a fronteira de palavra já
  para exatamente depois dele — o usuário digita a partir do `N` (`.NB_Rea` → prefixo detectado é
  `Rea`) e a inserção do Scintilla só substitui a partir daí, sem tocar no `.` já digitado. Mesmo
  truque, sem código extra, funciona pra rótulos relativos Z80 (`.loop`) e diretivas com ponto
  (`.PHASE`).
- **Variáveis do documento** — `CollectDocumentVariables()`: varredura leve (não um tokenizador
  completo) do texto da aba, coletando qualquer identificador que não seja palavra reservada
  (`IsReservedKeyword()`, reaproveitando os mesmos mapas `Kw*` acima).

**Vocabulário — abas `.asm`** (`ShowAutoComplete()`, ramo `If DocMode = "ASM"`):
- `Z80Asm.pbi` ganhou 4 novos procedimentos **exportados** (`MnemonicList()`/`RegisterList()`/
  `DirectiveList()`/`OperatorWordList()`, retornando string espaço-separada) — os mapas de verdade
  (`KwMnemonic`/`KwRegister`/`KwDirective`/`KwOperatorWord`) são privados dentro do `Module Z80Asm`
  (declarados no corpo do módulo, não no `DeclareModule`), então não dava pra fazer `ForEach
  Z80Asm::KwMnemonic()` de fora; os novos exports espelham o mesmo vocabulário que já alimentava
  `Z80Asm::IsMnemonic()`/`IsRegister()`/etc. (usados pelo destaque de sintaxe `HighlightZ80Text()`) sem
  duplicar a lista em `BadigEditor.pb` — só copiada uma vez pra mapas locais (`KwZ80Mnemonic` etc.) em
  `InitKeywordMaps()`.
- **Rótulos do documento** — `CollectZ80Labels()`: mesma regra clássica MACRO-80/Z80 que
  `HighlightZ80Text()` já usa pra destacar rótulos (a primeira palavra de cada linha que não bate com
  `Z80Asm::IsDirective`/`IsMnemonic`/`IsRegister`/`IsOperatorWord` é rótulo, com ou sem `:` no final;
  rótulos relativos `.nome` também contam) — varredura mais simples que o highlighter de verdade
  (não tokeniza string/comentário token a token no resto da linha) porque só precisa do primeiro token
  de cada linha, o resto é só pulado até a próxima quebra.

**Caixa das sugestões**: `ApplyKeywordCase(Word, Prefix, CaseMode)` — três modos ("AsTyped"/"Upper"/
"Lower"). "AsTyped" (padrão) decide pela caixa do próprio `Prefix` já digitado (não a versão
uppercased usada só pra comparação): prefixo todo minúsculo → sugestão minúscula, todo maiúsculo →
sugestão maiúscula, caixa mista/ambígua (ex. `"Pri"`) → mantém maiúsculas (grafia como os mapas
guardam). Só se aplica a palavras-chave/mnemônicos — variáveis, rótulos e nomes `.NB_*` sempre mantêm
a grafia exata que já aparece no documento, nunca reformatados. Alternativa descartada: detectar
estatisticamente a caixa predominante já usada no documento inteiro — rejeitada por ser menos
previsível (o que aparece depende de todo o histórico do arquivo, não da tecla que acabou de ser
digitada) e mais cara (recalcular a cada sugestão em vez de olhar só o prefixo atual).

**Configuração** — duas telas **independentes** (cada modo guarda sua própria preferência de caixa,
útil pra quem gosta de BASIC minúsculo e Assembly maiúsculo, ou vice-versa), mesmo padrão JSON de
`EditorSettings.pbi`/`BadigSettings.pbi`:
- `editor/BasicOptionsSettings.pbi` (`BasicOptionsCfg`, `basic_options_settings.json`) —
  `Configurar → Basic Options...`, vale pra abas `.dmx`/`.bas`.
- `editor/AssemblyOptionsSettings.pbi` (`AssemblyOptionsCfg`, `assembly_options_settings.json`) —
  `Configurar → Assembly...`, vale pra abas `.asm`.
- Ambas: habilitar/desabilitar, mínimo de letras pra ativar (padrão 3, 1-20), caixa das sugestões
  (`"AsTyped"`/`"Upper"`/`"Lower"`).

**Validação**: compilação limpa (`pbcompiler.exe`, sem erros/avisos) + smoke test de abertura do `.exe`
(sobe e fica de pé sem crash). Sem harness de console dedicado (`editor/tools/*Cli.pb`) e sem teste de
interação real (digitar → ver popup → navegar com seta → aceitar) — a automação de GUI disponível neste
ambiente de desenvolvimento é só de browser (`claude-in-chrome`), não alcança janelas Win32 nativas; ver
nota equivalente já registrada no guia de verificação deste projeto (`CLAUDE.md`, "Verification
approach"). Recomendado testar manualmente antes de confiar às cegas: abrir uma aba `.dmx`/`.asm` real,
digitar um prefixo de 3+ letras e conferir a lista, a navegação por teclado e o efeito de cada opção de
caixa.

### 26. Internacionalização (i18n) da UI — planejado, não iniciado (2026-08-08)

Usuário perguntou a viabilidade de ter a UI também em inglês (português continua existindo), com um
olho em espanhol/holandês/italiano depois — idiomas comuns em software de MSX da época. Pediu só pra
**estudar** por enquanto (sem código); registrado aqui pra não perder a ideia até decidir quando
começar. Nada abaixo foi implementado.

**Escopo decidido com o usuário**:
- Só a **UI** (menus, botões, diálogos, rótulos) por enquanto. Documentação (`Ajuda → ...`) fica pra
  **bem depois**, deliberadamente — é uma frente maior que a UI inteira (ver levantamento abaixo).
- Português continua existindo como opção — não é substituição, é adição.
- Sem arquivo de configuração salvo ainda (primeira execução), o idioma inicial é **inglês**.

**Levantamento feito no código real (2026-08-08)**, antes de decidir arquitetura:
- **Nenhuma infraestrutura de i18n existe hoje** — zero tabela de string, zero `Global Map` de
  tradução, tudo é literal em português espalhado pelo código-fonte.
- `editor/*.pb`/`*.pbi`: 65 arquivos, ~61.600 linhas. Ocorrências de chamadas que carregam texto de UI:
  `MenuItem` 70, `TextGadget` 326, `ButtonGadget` 293, `CheckBoxGadget` 40, `MessageRequester` 209,
  `OpenWindow` (títulos) 113, `AddGadgetItem` 130, `SetGadgetText` 542 (parte é valor dinâmico, não
  string fixa) — mais de 1.000 pontos de string literal ao todo, espalhados em ~55 arquivos.
  **Desatualizado a partir do módulo 29 (2026-08-08)**: os 293 `ButtonGadget` viraram `ThemedButton`
  (mesmos rótulos, mesma contagem de string literal — só a palavra-chave de busca muda, quem for
  levantar os pontos de string de novo procura por `ThemedButton(` em vez de `ButtonGadget(`).
- Os arquivos de **conteúdo de Ajuda** (`BasicDignifiedHelpData.pbi`, `MsxDignifiedHelpData.pbi`,
  `NestorBasicHelpData.pbi`, `OpenMsxHelpData.pbi`, `SeeTrackerHelpData.pbi`,
  `MsxBasic2PlusDictData.pbi`, `MsxBasicDictData.pbi`, `MsxBasic2PlusManualData.pbi`,
  `MsxBasicManualData.pbi`) somam sozinhos **13.507 linhas** de prosa em português — quase 1/4 do
  código do editor. Confirma que documentação é mesmo uma frente separada e maior, correto adiar.

**Arquitetura recomendada (não implementada)**:
1. `Global NewMap UIText.s()` preenchido a partir de um arquivo por idioma (`Lang_PT.pbi`,
   `Lang_EN.pbi`, depois `Lang_ES.pbi`/`Lang_NL.pbi`/`Lang_IT.pbi`) — mesmo estilo de arquivo de dados
   já usado em `NBHelp_Add()`/`*DictData.pbi`, só que chave (ID estável, ex. `"Menu_Save"`) → texto
   naquele idioma, em vez de struct de tópico de ajuda.
2. Helper `UI(Key.s)` fazendo o lookup, com fallback pro português (ou pra própria chave) se a
   tradução não existir — permite rollout **parcial**: chrome principal em inglês enquanto uma tela de
   editor mais obscura ainda mostra português, sem quebrar nada.
3. Cada um dos >1.000 pontos levantados acima precisa trocar a string literal por `UI("Algum_Id")` —
   esse é o trabalho mecânico grande, arquivo por arquivo. É o único jeito de a arquitetura funcionar;
   não tem atalho.
4. **Troca de idioma exige reiniciar o app** (decisão recomendada, não implementada) — PureBasic não
   tem "re-skin ao vivo" de gadget; teria que fechar/reconstruir todas as ~40 janelas abertas sob
   demanda pra trocar em tempo real, custo desproporcional ao benefício. Reiniciar é trivial.
5. Config de idioma: só mais um campo de settings (JSON, mesmo padrão de `EditorSettings.pbi`), zero
   complexidade extra.

**Risco identificado, não só custo de tradução**: este código posiciona gadgets em **coordenadas pixel
fixas e literais** (`TextGadget(#PB_Any, 24, 100, 60, 24, ...)`, confirmado no próprio código de
`BasicOptionsSettings.pbi`/`AssemblyOptionsSettings.pbi`, módulo 25). Holandês e italiano tendem a
gerar texto mais longo que português/inglês pra mesma frase — um botão/rótulo dimensionado exatos pro
texto em PT pode cortar texto em outro idioma. Não trava o projeto, mas significa que parte da migração
não é só trocar string — alguns gadgets vão precisar de largura calculada (`TextWidth()`) em vez de
número fixo.

**Estratégia incremental sugerida** (não decidida com o usuário ainda, só a ideia registrada):
1. Infraestrutura (tabela + helper + tela de idioma) — pequeno, contido.
2. Chrome sempre visível: menu principal + diálogos comuns de salvar/abrir/erro — maior valor por
   esforço, ~150-250 strings.
3. Cada editor/tela de configuração, um por vez (Sprite, Alfabeto, Screen 0/1/2, PSG, MML, SEE Tracker,
   Disco, Hexa, telas de configuração...) — mesmo ritmo módulo-por-módulo-por-sessão que este projeto já
   usa pra construir cada editor (ver histórico deste `docs/SPEC.md`), só que "traduzir módulo X" vira
   mais um tipo de tarefa ao lado de "construir módulo X".
4. Espanhol/Holandês/Italiano depois: uma vez a arquitetura (passo 1) em pé, cada idioma novo é **só**
   um arquivo `Lang_XX.pbi` a mais com as mesmas chaves traduzidas — zero mudança nos >1.000 pontos de
   chamada, que já estariam desacoplados do texto literal. O caro é a migração inicial (passo 2/3), não
   os idiomas extras depois dela.

### 27. Fim do teclado WordStar/JOE + atalhos de teclado modernos — implementado (2026-08-08)

Usuário investiu no teclado estilo WordStar/JOE (`editor/WordStarKeys.pbi`, ver histórico deste
documento em 2026-07-15) mas, no dia a dia, não usa WordStar/JOE/vim — prefere Helix/JetBrains/
VSCode/Sublime/010 Editor. Pediu pra voltar ao padrão Scintilla/Windows.

**Removido por completo, não só desligado**: `editor/WordStarKeys.pbi` (982 linhas — subclass
Win32 de teclado, comandos de duas teclas `Ctrl+K x`/`Ctrl+Q x`, bloco marcado com destaque
persistente, tela de ajuda em tela cheia) saiu do repositório. Bloco marcado não tem substituto —
seleção normal (mouse ou `Shift`+setas) + `Ctrl+C`/`Ctrl+X`/`Ctrl+V` (grátis, keymap padrão do
Scintilla) cobre o mesmo caso de uso. Reformatar parágrafo (`Ctrl+B` no modo antigo) também não
tem substituto — não estava em uso real.

**O que sobreviveu**: Buscar/Buscar próxima/Substituir/Ir para linha eram a única funcionalidade
real do modo antigo sem equivalente automático no Scintilla puro — portadas pra
`editor/EditorSearch.pbi` (arquivo novo, incluído só no fim de `BadigEditor.pb` pelo mesmo motivo
de ordem de `Global`/`Structure` do módulo 29 abaixo), com atalhos convencionais: `Ctrl+F`
(buscar), `F3` (buscar próxima), `Ctrl+H` (substituir — tudo de uma vez ou confirmando ocorrência
por ocorrência), `Ctrl+G` (ir para linha). Novo menu **Editar** no menu principal.

**Atalhos de arquivo voltaram ao convencional**: `Ctrl+N` novo (era `Alt+N`), `Ctrl+S` salva (era
mover cursor — salvar era `Ctrl+K D`), `Ctrl+W` fecha aba (era `Alt+W`).

**`editor/EditorHelpGui.pbi`** (arquivo novo) — `Ajuda → Editor...` (também `F1`, convenção
universal de ajuda) troca a antiga tela cheia por uma janela normal com a referência de atalhos,
reaproveitando o motor de renderização markdown de `GenericMdHelpGui.pbi` (módulo 18) com conteúdo
fixo embutido no `.exe` em vez de vir de uma pasta baixada em tempo de execução.

**22 atalhos novos pro resto da IDE** (pedido separado, mesma sessão) — usuário queria não ficar
preso navegando menu: `Ctrl+Alt+N`/`Ctrl+Alt+O` novo/abrir projeto, `Ctrl+Alt+I` caractere
especial, `Ctrl+Alt+E` Configurar → Editor..., `Shift+F5` Nestor Basic, `F6` renumerar,
`Ctrl+Shift+F5` montar relocável, `Ctrl+Alt+F5` linkar, `F7` Editor Hexa, `F8` console openMSX,
`F9`/`Shift+F9` ver MD/TXT, e `Ctrl+Shift+<letra ou número da tela MSX>` pros 9 editores visuais
mais usados do menu **Criar** (Disco/Sprite/Alfabeto/Som/Tracker/Música/Screen 0-1-2). Os 5 itens
menos usados desse menu (Alfabeto Aquarela, Graphos III Screen 2, Screen 1+2, Biblioteca Z80,
Assembly Sub Project) ficaram só no menu — não valia um 3º/4º modificador só pra caber mais uma
tecla.

**Achado real de arquitetura, corrigido só no módulo 29**: a essa altura `EditorSearch.pbi` já
precisava do mesmo idioma "`Declare` no topo pra dependência circular" que `WordStarKeys.pbi` já
usava — incluído só no fim de `BadigEditor.pb` porque usa `ActiveSciGadget()`, definido ao longo do
arquivo. Documentado por completo só quando o mesmo problema apareceu em escala bem maior no módulo
29 (293 botões em 33 arquivos incluídos *antes* de `Global Color_*`/`Structure EditorSettings`
existirem).

### 28. Sete temas de cores (`Configurar → Editor...`) — implementado (2026-08-08)

Usuário achou os dois temas originais (Escuro/Claro) feios de verdade — "sei que o PureBasic tem
uma baita limitação para GUIs modernas" — e pediu variações mais atraentes: azul escuro, rosa,
vermelho, verde, bege.

**Processo**: paletas desenhadas e aprovadas num **mockup HTML publicado como artifact** fora do
PureBasic antes de virar código — iterar cor em CSS/JS é muito mais rápido que recompilar o app a
cada ajuste. O mockup simulava a janela real (abas com aba ativa/hover, régua de colunas, código
com números de linha, seleção e cursor destacados, todos os ~24 `Color_*` nomeados) com uma amostra
real de código Basic Dignified, e reproduzia com honestidade o teto do PureBasic: a barra de status
(controle nativo do Windows, `CreateStatusBar`) ficava sempre cinza em todos os 7 mockups, porque é
assim que fica no app de verdade. Usuário aprovou todos os 7 de uma vez.

**`EditorCfg\Theme`** (`editor/EditorSettings.pbi`) deixou de ser um booleano Dark/Light e virou um
de 7 IDs: `Graphite`/`Snow` (revisão dos dois temas antigos — mais equilibrados, sem preto/branco
puro) e os cinco novos — `Navy` "Azul Profundo" (clima Night Owl/Nord), `Rose` "Rosé" (Rosé Pine),
`Crimson` "Carmesim" (oxblood/vinho), `Forest` "Floresta" (Everforest), `Paper` "Bege" (Solarized
Light). `ApplyTheme()` (`BadigEditor.pb`) virou um `Select` com as 7 paletas completas (24
`RGB()` cada) em vez do `If/Else` binário anterior.

**Compatibilidade**: `EditorCfg_ThemeIndexById()`/`EditorCfg_ThemeIdByIndex()` fazem a ponte
índice-do-combo ↔ ID persistido, e absorvem os dois IDs antigos (`"Dark"`/`"Light"`) como sinônimo
de `Graphite`/`Snow` — `editor_settings.json` de instalações anteriores migra sozinho no primeiro
carregamento (`EditorCfg_Load()`), sem resetar a preferência do usuário.

**O que muda de verdade vs. o que não muda** (auditado no código antes de prometer): só a área do
editor (Scintilla), as abas e a régua de colunas eram desenhadas pelo próprio app nesta época —
controles nativos (botões, combos, diálogos) continuavam com chrome do Windows em qualquer tema.
Essa limitação começou a cair já na mesma sessão, ver módulo 29.

**Atualização (2026-08-10, `7.33.10` "ADEUS ESCURIDÃO")**: os 5 temas escuros (`Graphite`/`Navy`/
`Rose`/`Crimson`/`Forest`) foram **removidos** — controles nativos não-tematizáveis (combo/checkbox/
lista/scrollbar) ficavam com contraste ruim contra fundo escuro, praticamente invisível contra fundo
claro. Dois temas claros novos (`Mist` "Neblina", `Linen` "Linho") substituíram os removidos, ao lado
dos 2 originais (`Snow`/`Paper`) — **4 temas hoje**, todos claros. `editor_settings.json` de
instalações anteriores migra sozinho (cada tema escuro removido mapeia pro claro de "família" mais
parecida). Detalhe completo no changelog do README (`7.33.10`).

### 29. Botões tematizados em toda a IDE + ícones Nerd Font opcionais — implementado (2026-08-08)

Usuário testou o módulo 28 e reclamou que os diálogos ainda pareciam "Windows 3.1" — "aquele mar de
botões cinza que estragam a aparência". `ButtonGadget` é controle nativo do Windows: ignora
`Color_*` completamente, não tem API de recoloração.

**Piloto no Editor Hexa** (`editor/HexEditorGui.pbi`, `v7.31.3`): os 16 botões da janela viraram
imagens geradas na hora (`CreateImage`/`StartDrawing`/`Box`/`DrawText`, mesma técnica já usada nos
ícones de `CharsetEditorGui.pbi` e nas setas de rolagem customizada desta mesma janela) exibidas
via `ButtonImageGadget` — fundo/borda a partir de `Color_TabInactive` (clareada/escurecida por
`HexEd_ShadeColor`, não depende de qual `Color_*` é mais clara/escura em cada uma das 7 paletas),
texto em `Color_TextActive`, na mesma fonte já escolhida em `Configurar → Editor...`
(`EditorCfg\FontName`) em vez de "Segoe UI" fixo.

**Ícones de verdade, não desenho genérico à mão**: novo campo `EditorCfg\IconFontName` + combo
**Fonte de ícones** na tela de Configurar — com uma Nerd Font escolhida, os botões trocam o texto
por um glifo de ícone real (pasta aberta, disquete, lixeira etc.), com tooltip mostrando o nome ao
passar o mouse; sem fonte escolhida (padrão), continuam com texto normal. Os primeiros 15
codepoints (Nerd Fonts vive em Private Use Area do Unicode — uma fonte comum sem esses glifos
"remendados" mostra quadrado vazio) foram conferidos ao vivo contra o `glyphnames.json` oficial do
projeto (`github.com/ryanoasis/nerd-fonts`, v3.5.0, baixado via `curl` + parseado com Python — não
confiado de memória nem do primeiro resumo de busca web, que errou um codepoint:
`fa-plus_square` como `U+F055` em vez do `U+F0FE` real).

**Rollout pra IDE inteira** (`v7.31.4`, mesma sessão): usuário gostou do piloto e pediu o mesmo
formato em todos os diálogos. `HexEd_*` generalizado pra `editor/ThemedButtons.pbi` (novo módulo
compartilhado — `Macro ThemedButton(X,Y,W,H,Text,Icon)`, ~33 constantes `#Icon_*` verificadas
cobrindo só ações universalmente reconhecíveis: Fechar/Salvar/Copiar/Tocar/Parar/Ejetar/Inserir/
Limpar/Conectar-Desconectar/Voltar/etc. — ações específicas de um módulo, tipo "Gerar código PLAY"
ou os botões de status dinâmico do console openMSX ("VSync: ?"), ficam de propósito só com texto).
`HexEditorGui.pbi` migrado pra usar o módulo compartilhado, sem duplicar código.

**Escala do rollout**: 293 botões em 33 arquivos, 40 janelas ganharam `SetWindowColor(Win,
Color_AppBg)` (antes ficavam brancas/cinza nativas destoando do editor tematizado), mais de 140
botões com ícone + tooltip. Nenhuma edição manual — três scripts Python descartáveis (escritos no
scratchpad da sessão, não fazem parte do repositório) fizeram o trabalho repetitivo:
1. Conversão mecânica `ButtonGadget(#PB_Any, ...)` → `ThemedButton(..., "")` com **parsing de
   parênteses balanceados** (não regex ingênuo — havia chamadas com expressões `WinW - x` dentro
   dos argumentos de posição).
2. Inserção de `SetWindowColor(Win, Color_AppBg)` logo após o guard `If Not Win / EndIf` de cada
   `OpenWindow`.
3. Upgrade de ícone só pra rótulo exato batendo numa lista curada — nenhum texto ambíguo (`"Reset"`
   verificado caso a caso primeiro; `"Cancelar"`/`"OK"`/letras soltas/botões de status dinâmico
   deixados de propósito como texto).

Recompilado (`pbcompiler.exe`, sem erros) depois de cada rodada, pra pegar erro cedo em vez de
acumular 33 arquivos de mudança não testada.

**Achado real de arquitetura**: quase todos os 33 arquivos de diálogo são incluídos bem no topo de
`BadigEditor.pb` — antes de `Global Color_AppBg`/`Structure EditorSettings`/`Global EditorCfg`
existirem (só declarados mais de 400 linhas depois, perto de `ApplyTheme()`). Com `EnableExplicit`
+ `XIncludeFile` só inclusão textual, isso quebra a compilação assim que qualquer um desses
arquivos passa a chamar `ThemedButton()` (que lê `Color_*`/`EditorCfg` por dentro). Resolvido **sem
reordenar os 33 `XIncludeFile` existentes**: as poucas linhas de `Structure EditorSettings`/`Global
EditorCfg`/`Global Color_*` foram movidas pro topo de `BadigEditor.pb`, antes do primeiro
`XIncludeFile` — mesmo idioma dos vários `Declare` de procedure que já ficavam ali por motivo
parecido (dependência circular de include), só que pra dado (`Global`/`Structure`) em vez de
código (`Procedure`). `editor/EditorSettings.pbi` manteve o resto da sua lógica (defaults, load/
save JSON, enumeração de fontes via WinAPI, a própria janela de configuração) na posição de
`XIncludeFile` original, sem precisar mover.

**O que não entrou nesta rodada**: as demais janelas de diálogo (Configurar, SEE Tracker, editores
visuais) usam cores próprias fixas nas suas áreas desenhadas à mão (grade de patterns, tabela de
caracteres etc.) — não migradas pra `Color_*`. Auditado antes de prometer: `SeeTrackerEditorGui.pbi`
tem 22 botões nativos (agora tematizados) contra só 4 áreas de canvas com cor própria;
`CharsetEditorGui.pbi` é parecido. Estender tema pra essas áreas é projeto à parte, arquivo por
arquivo, separando cor de "chrome" (segue o tema) de cor de "conteúdo" (ex.: a paleta MSX real
mostrada no editor de alfabeto/sprite não pode virar rosa só porque o tema é Rosé, senão a
ferramenta mentiria sobre a cor de verdade do hardware).

### 30. Base de conhecimento MSX embutida no Ajuda — implementado (2026-08-10)

Usuário pediu, aos poucos ao longo de uma sessão longa, pra transformar `help/*.CHM` (arquivos de
ajuda do emulador RuMSX, achados no repositório) e mais duas fontes externas ("The MSX Red Book" e o
MSX2 Technical Handbook) em janelas de Ajuda navegáveis dentro do próprio programa. Resultado: sete
janelas novas, ~3300 tópicos, todas geradas por scripts Python descartáveis (escritos no scratchpad da
sessão, não fazem parte do repositório — mesma convenção já usada em `OpenMsxHelpData.pbi`) que
convertem HTML/Markdown de origem pra um dos dois formatos de dados abaixo.

**Fontes e escopo**:
- `help/MANUALS.CHM` → **Ajuda → Manuais MSX...** (18 tópicos): MSX-DOS 2, Z80/R800, Turbo-Basic
  Compiler, FM-PAC, MSX2 Technical Handbook (transcrição de 1997, ver módulo separado abaixo pra
  edição melhor). RS232 e MSXtra excluídos por pedido do usuário (obsoleto/direitos incertos).
- `help/SOFTWARE.CHM` → **Ajuda → MSX-Basic/DOS/CP-M (RuMSX)...** (359 tópicos): comandos MSX-BASIC
  (1/2/2+/Turbo-R/Disk-BASIC/CALL de firmware), MSX-DOS, CP/M. UZIX/HALNOTE/MSXView/Chakkari Copy
  excluídos (fora de escopo). MSX-DOS ganhou um segundo passe: `MsxDos.htm` usa `<UL><LI>` misturando
  comando com link (tem página) e só-nome (sem página) — os sem página viram um tópico placeholder em
  vez de sumir, incluindo apelidos que apontam pro mesmo arquivo (ERA/ERASE → DEL).
- `help/MSXBIOS.CHM` → **Ajuda → BIOS MSX: Chamadas/Hardware/Documentação (RuMSX)...** (597+33+2
  tópicos, 3 janelas separadas espelhando as 3 seções do CHM original): rotinas de BIOS individuais
  extraídas automaticamente de marcadores `ENDEREÇO <B>NOME</B>` no HTML (heurística com alguns
  ajustes reais — ver "Achados" abaixo).
- `help/MSX.CHM` → **descartado** (específico da interface do emulador RuMSX, fora do escopo do
  projeto — decisão explícita do usuário).
- "The MSX Red Book" (Avalon Software/Kuma Computers, 1985), edição Markdown de Gustavo Seidler
  (github.com/gseidler/The-MSX-Red-Book) → **Ajuda → Livro Vermelho...** (973 tópicos, 53 figuras).
- MSX2 Technical Handbook (ASCII Corporation, 1987), edição Markdown de Konamiman
  (github.com/Konamiman/MSX2-Technical-Handbook) → **Ajuda → MSX2 Technical Handbook...** (1356
  tópicos, 84 figuras) — edição bem mais limpa que a transcrição de 1997 já incluída em Manuais MSX
  (headings Markdown reais em vez de marcador ad-hoc, tabelas GFM de verdade, figuras originais).

**Decisão sobre direitos autorais** (avaliada explicitamente com o usuário antes de qualquer
implementação, não assumida): manuais técnicos antigos, há muito fora de catálogo, amplamente
compartilhados pela comunidade MSX há décadas (casos do Red Book e do MSX2 Technical Handbook,
inclusive o texto de 1997 já usado antes) foram reproduzidos como no original. Conteúdo de autoria
própria do RuMSX (Lex Lechz, SOFTWARE.CHM/MSXBIOS.CHM) também foi reproduzido como está, por decisão
explícita do usuário — nível de risco comparável ao que o projeto já tolera desde `MsxBasicDictData.pbi`
(transcrição de um livro comercial de 1986 ainda sob direitos, `docs/Linguagem_Basic_MSX.pdf`, já
commitado no repositório). RS232/MSXtra (direitos mais incertos/conteúdo obsoleto) e MSX.CHM
(fora de escopo) foram excluídos por decisão do usuário, não por limitação técnica.

**Arquitetura de dados** — todo `*HelpData.pbi` segue o mesmo esqueleto (`Structure {Titulo, Grupo,
Corpo}` + `Global NewList *_Topics()` + `*_Begin()`/`*_L()`/`*_Commit()`): o corpo de cada tópico é
montado **linha por linha** (uma chamada `*_L("linha")` por linha do documento original, junta tudo
num `Body.s` só dentro de `*_Commit()`) em vez de uma única expressão `"linha1" + #CRLF$ + "linha2" +
...` gigante — `pbcompiler.exe` tem um limite de "continuation lines" por expressão que os documentos
maiores (MSX-DOS 2 sozinho passa de 3000 linhas) estouravam com a abordagem ingênua. Cada `Add(...)`
tradicional virou `Begin()`/várias `L(...)`/`Commit(...)` justamente por isso.

**Dois estilos de renderizador**, escolhidos por tipo de conteúdo, não por janela:
- **Monoespaçado, sem quebra automática** (Manuais MSX, as 3 janelas de BIOS) — texto pré-formatado
  cheio de tabela ASCII/diagrama de bits, onde reformatar destruiria o alinhamento. Sem suporte a
  negrito/link, só título + corpo.
- **Proporcional com negrito/`código`/link** (MSX-Basic/DOS/CP-M, Livro Vermelho, MSX2 Technical
  Handbook) — prosa corrida, mesmo espírito do "mini-Markdown" já usado em `NestorBasicHelpGui.pbi`
  mas com um parser próprio por janela (não o compartilhado) porque as duas últimas precisam de mais:
  link clicável de verdade e bloco de código multi-linha.

**Links clicáveis de verdade** (só Livro Vermelho e MSX2 Technical Handbook — as ~2911 + ~2000
referências cruzadas internas de cada livro): hotspot nativo do Scintilla
(`SCI_STYLESETHOTSPOT`/`SCN_HOTSPOTCLICK`, capturado no `ScintillaGadget`'s callback e resolvido no
loop principal via `PostEvent` — mesmo motivo de reentrância documentado em `ScintillaCallBack()`,
`BadigEditor.pb`). Cada topico guarda uma lista de `(StartPos, EndPos, Anchor)` em bytes UTF-8
(posição real no documento Scintilla); no clique, acha qual faixa contém a posição, resolve o anchor
num `Map` global (`*_AnchorMap()`) pro índice do tópico alvo, navega igual um clique na árvore (empilha
histórico, `ShowRow`, sincroniza seleção da árvore). Livro Vermelho usa anchors simples (o livro
inteiro era 1 arquivo `.md` só); MSX2 Technical Handbook precisou qualificar o anchor com o nome do
arquivo (`"Chapter1#slug"`) porque cada capítulo era uma página separada no original e headings
repetidos (`"Index"` aparece em quase todo arquivo) colidiriam num mapa só de slug.

**Figuras originais clicáveis** (mesmo mecanismo dos links de texto, prefixo especial `"img:"` no
anchor abre um popup com `ImageGadget` em vez de navegar): 53 do Livro Vermelho (SVG original
convertido pra PNG com ImageMagick, 2x de escala, `editor/redbook_images/`); 84 do MSX2 Technical
Handbook (já PNG no repositório de origem, sem conversão, `editor/th2handbook_images/`). Ambas as
pastas entram no pacote de distribuição (`build.ps1 -D`).

**Achados reais durante os testes ao vivo** (nenhuma janela foi considerada pronta sem abrir de
verdade e clicar):
1. Heurística de "endereço+nome" (BIOS) inicialmente confundia rótulos de posição de bit
   (`b7`/`b6`/.../`b0`, 2 caracteres hex válidos) com endereço de rotina — corrigido exigindo que
   endereços de verdade sejam maiúsculos (padrão real do conteúdo).
2. Mesma heurística, blocos multi-linha sem `<B>` (variáveis de RAM nomeadas tipo `EXPTBL`) estavam
   sendo ignorados porque só a primeira linha do bloco era checada, e o resto (sem nome em negrito)
   não tinha como virar título — corrigido pra tentar a 1ª palavra após o endereço como nome candidato.
3. Parser do Livro Vermelho tratava item de lista aninhado do sumário (`    + [Texto](#link)`,
   indentado com 4 espaços) como bloco de código — mesma indentação usada por blocos de código
   markdown de verdade — corrigido excluindo linhas que começam com marcador de lista (`+`/`-`/`*`/
   `N.`) da detecção de bloco de código.
4. Título duplicado na tela (uma vez renderizado pelo `RenderTopic`, outra como texto puro `"##
   Título"` dentro do próprio corpo) nas 3 janelas de BIOS — sobrou de copiar o padrão de prefixar
   `"## "` de outro conversor sem notar que esta janela já desenha o título separado.
5. **Achado de compilador, não de lógica**: `pbcompiler.exe` rejeita bytes de controle crus (`Chr(1)`,
   `Chr(4)` etc.) dentro de literais de string — `"Literal string not terminated"` mesmo com a string
   visivelmente bem formada. A codificação de sentinela original (Livro Vermelho/MSX2 Technical
   Handbook, marcar span de link/código dentro do texto) usava esses bytes; trocada por sentinelas
   ASCII 100% imprimível (`"[[["`/`"|||"`/`"]]]"` pra link, `"@@@"` como prefixo de linha de código) -
   guardado na memória do projeto (`purebasic-syntax-gotchas-z80asm`), pode aparecer de novo em
   qualquer geração de código PureBasic que precise de marcador inline.

**Verificação**: cada uma das 7 janelas foi compilada e aberta de verdade (não só inspeção de código),
incluindo clique real em link de texto e em figura (via um pequeno driver PureBasic descartável de
automação de UI — `SendMessage`/`PostMessage` diretos no controle nativo — quando a automação via
PowerShell/`Add-Type` ficou instável na sessão).

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
- ~~Mapeamento completo de funções/parâmetros NestorBASIC (módulo 9).~~ — **resolvida (2026-07-27)**:
  todas as 87 funções (0-86) mapeadas a partir de `nestor/SRC/NBASIC/nbas111e.txt`, ver seção 9 acima.
- Lista de comandos suportados/incompatíveis do msxbas2rom (módulo 10) — segue em aberto **só** pro
  pipeline pesado original (editores gráficos → dialeto msxbas2rom); a integração leve pedida em
  2026-08-01 (arquivo novo + download + Ajuda, ver módulo 18) não depende dessa lista.
- ~~`badig/msx/openmsx_output.tcl` ainda não foi lido~~ — **obsoleta (2026-07-30)**: o caminho
  implementado (`OpenMSXBridge.pbi`, módulo 12) não usa `-script openmsx_output.tcl`/convenção
  `CHR$(7)` nenhuma — foi pelo caminho mais simples (named pipe `-control pipe:`, igual ao Catapult),
  então esse script Python de referência não é mais necessário pra portar o módulo.
- ~~Investigar se a leitura de stdout do openMSX funciona de forma não-bloqueante no Windows a partir
  de PureBasic~~ — **resolvida (2026-07-30)**: confirmado ao vivo que `RunProgram(...#PB_Program_Read)`
  + `AvailableProgramOutput()`/`ReadProgramString()` funciona normalmente no Windows (não é limitação
  do openMSX/pipes) **desde que o processo que chama `RunProgram()` não tenha um console de verdade
  anexado** — ver o achado de `AttachConsole`/`EnableConsoleOutput()` no módulo 12 acima. A limitação
  Mac/Linux-only da implementação Python original era do jeito que o Python lidava com isso
  (provavelmente relacionado a esse mesmo comportamento de `main.cc`), não do mecanismo em si.
- ~~Tabela completa de tokens do MSX-BASIC~~ — **resolvida**: está em
  `badig/msx/msxbatoken/msxbatoken.py` (ver módulo 11 acima).
- ~~Mapear pré-processador Dignified~~ — **resolvida**: arquitetura completa (Lexer, Parser 5 passes,
  vocabulário) documentada em `docs/reference/dignified-core.md` e `docs/reference/badig-msx-module.md`.
- ~~Protocolo real de controle do openMSX~~ — **resolvida**: sequência de comandos e mecanismo de
  detecção de erro documentados em `docs/reference/badig-emulator-tokenizer-interfaces.md` e no
  módulo 12 acima (revelou abordagem mais simples que o plano original).

## Próximos passos em aberto

**Estado ao fim de 2026-08-09 — revisão geral: bugs, coesão de módulos, performance e temas, codinome
"PENTE FINO" (v7.33.1)**: sessão de auditoria ampla pedida pelo usuário (7 revisões paralelas por área do
código: pipeline/tokenizer, toolchain Z80, shell principal, editores gráficos, editores de tela texto,
áudio/tracker, settings/integrações externas), seguida de correção do que valia a pena. Resumo (sem
detalhe de release notes cumulativo, pedido explícito do usuário):
- **8 bugs reais corrigidos**: aba errada ativada ao fechar uma aba não-ativa (`BadigEditor.pb`);
  vazamento de handles GDI em `CharsetEditorGui.pbi`/`GraphosScreenGui.pbi`/
  `AquarelaCharsetEditorGui.pbi`; `ProjectDB::SaveAs` podia abandonar o projeto silenciosamente se o
  reabrir do banco novo falhasse; `MSXDisk::ExtractFile` reportava sucesso numa extração truncada;
  downloads parciais sem limpeza em `BadigSettings.pbi`/`FontDownloader.pbi`; vazamento de buffer em
  `Z80Lib::CreateOrAddLibrary`; thread do pipe do openMSX nunca fechada (`OpenMSXBridge.pbi`); loop
  labels aninhados sem limite no pré-processador podiam corromper heap (`DignifiedPreprocessor.pbi`,
  `Dig_LoopStack`).
- **Coesão**: helper de janela compartilhado (`OpenModelessChildWindow`/`CloseModelessChildWindow`,
  `BadigEditor.pb`) extraído e migrado em 35 arquivos de diálogo, ~150 linhas de boilerplate repetido a
  menos; hit-test de paleta (`Scr2Ed_PaletteHitTest`) desduplicado entre Screen0/1/2/12 e Graphos;
  `FontDownloader.pbi` passou a reusar `ExternalToolDownload.pbi` em vez de duplicá-lo.
- **Performance**: `Tok_TokenizeLineBody`/`Tok_RenumberLineBody` (`MsxTokenizer.pbi`) deixaram de
  recomputar `UCase()` do restante da linha a cada posição (O(n²) → O(n) por linha), verificado
  byte-idêntico contra `sample/teste.dmx`; redraw de glifo em Screen0/1/12 funde pixels de tinta
  adjacentes num só `Box()` (verificado pixel-a-pixel contra os 256 padrões de byte possíveis);
  `Scr2Ed_RedrawCanvas` (Graphos + Screen2, chamado a cada mouse-move durante desenho) leu o pixel
  direto do array em vez de por uma função de consulta com checagem de fronteira redundante.
- **Achado maior da sessão — modo escuro nativo sempre desligado**: os 7 temas (`7.31.2` em diante)
  substituíram um modelo binário antigo "Dark"/"Light", e `EditorCfg_Load()` já migra qualquer valor
  legado assim que carrega — mas 8 pontos em `BadigEditor.pb`/`SeeTrackerEditorGui.pbi` continuavam
  comparando `EditorCfg\Theme = "Dark"` literalmente, um valor inatingível depois dessa migração.
  Resultado: `DWMWA_USE_IMMERSIVE_DARK_MODE` (barra de título escura), `SetWindowTheme_`
  "DarkMode_Explorer" e a coloração de campos via `WM_CTLCOLOREDIT`/`WM_CTLCOLORLISTBOX` nunca
  ativavam, em nenhum tema — inclusive nos 5 escuros (Graphite/Navy/Rose/Crimson/Forest). Corrigido com
  `EditorCfg_ThemeIsDark()` (`EditorSettings.pbi`). Um segundo bug relacionado, documentado como
  "abandonado" no próprio código-fonte (tentativa anterior de colorir rótulos via `SetGadgetColor`+
  `GetDlgCtrlID_` não funcionava porque `GetDlgCtrlID_` não devolve o número do gadget do PureBasic
  nesse contexto): rótulos (`TextGadget`) ficavam sempre com fundo claro/texto escuro nativo do Windows
  mesmo em tema escuro. Resolvido tratando `WM_CTLCOLORSTATIC` no mesmo subclass de janela
  (`App_DarkModeWindowProc`) que já tratava `WM_CTLCOLOREDIT`/`LISTBOX` — resolve no nível de mensagem,
  sem precisar do número do gadget, cobre todo diálogo automaticamente. Ambos confirmados com
  screenshot real da IDE rodando (`PrintWindow`) contra o tema `Rose` já salvo nas configurações reais
  do usuário, não só leitura de código — mesmo cuidado do achado de `7.31.4`.
- **Adiado de propósito** (risco/esforço maior do que o pedido desta sessão comportava, ver conversa):
  unificação de caixa/sombra/preenchimento entre `Screen0EditorGui.pbi`/`Screen1EditorGui.pbi`;
  desduplicação do padrão Store/Fetch/Has/List em `ProjectDB.pbi` (~14 repetições); dirty-rect de
  verdade no Graphos (só o redraw completo foi otimizado, não a invalidação parcial por ferramenta);
  rede síncrona na UI thread (`BadigSettings.pbi`/`ExternalToolDownload.pbi`/`FontDownloader.pbi`).

**Estado ao fim de 2026-08-08 (sessão seguinte a "TORRE DE CONTROLE") — auto completar ("PALPITEIRO")
e Arquivo → Salvar Tudo (v7.29.5)**: sessão pedida pelo usuário em três rodadas. Ver módulo 25 (seção
25 abaixo) e módulo 1b para o detalhe técnico completo; resumo aqui:
- **Auto completar em abas `.dmx`/`.bas`**: popup nativo do Scintilla (`SCI_AUTOCSHOW`), disparado
  quando a palavra digitada atinge um mínimo configurável de letras (`Configurar → Basic Options...`).
  Sugere palavras-chave clássicas + Dignified + MSXBAS2ROM (quando aplicável) + variáveis coletadas ao
  vivo do texto do documento.
- **Caixa das sugestões configurável** ("Como digitado"/maiúsculas/minúsculas) — escolhido em vez de
  detectar estatisticamente a caixa predominante já digitada no documento (opção descartada por ser
  menos previsível e mais cara de recalcular a cada sugestão); "Como digitado" cobre o caso comum sem
  esse custo.
- **Os 87 wrappers `.NB_*` do NestorBASIC** entraram na lista de sugestões, fonte única com
  `Ajuda → NestorBASIC...` via `NBHelp_Topics()\Wrapper` (nunca diverge da ajuda).
- **Auto completar chegou nas abas Assembly (`.asm`)**: mnemônicos/registradores/diretivas do Z80
  (`Z80Asm.pbi` ganhou `MnemonicList()`/`RegisterList()`/`DirectiveList()`/`OperatorWordList()`,
  expondo pra fora do módulo o vocabulário que já alimentava o destaque de sintaxe) + rótulos já
  definidos no documento (mesma regra clássica MACRO-80/Z80 do highlighter). Config própria e
  independente em `Configurar → Assembly...`.
- **Arquivo → Salvar Tudo** (`Ctrl+Alt+S`, módulo 1b): salva todas as abas abertas + o projeto atual
  numa ação só.

**Em aberto nessa frente, pra decisão/trabalho futuro**:
- `CollectDocumentVariables()`/`CollectZ80Labels()` (varreduras que alimentam as sugestões de
  variável/rótulo) são varreduras leves, não um tokenizador completo — não distinguem com precisão
  texto dentro de comentário/string do resto do código (mesmo trade-off deliberado já aceito em outras
  varreduras "melhor esforço" desta IDE, ver módulo 3h). Na prática, pouco ruído real: nomes de
  variável/rótulo plausíveis raramente aparecem por acaso dentro de comentários ou literais de string.
- Nenhum teste automatizado dedicado (`editor/tools/*Cli.pb`) foi criado pra essa frente — validado só
  por compilação limpa + smoke test de abertura do `.exe` (não há como automatizar "digitar no editor e
  ver o popup aparecer" neste ambiente sem GUI automation nativa Win32, só a de browser está
  disponível).

**Estado ao fim de 2026-08-06 — estudo do formato SEE concluído (cabeçalho resolvido), tracker ainda
não iniciado**: ver módulo 23 acima para o material já registrado em `Ajuda → SEE Tracker...` (manual
original, formato de arquivo `.SEE`, mecanismo real do driver de replay `SEE3PLAY.ASC`) e a atualização
do mesmo dia que resolveu o significado do campo `$08-$09` (constante de capacidade `$03FF`, não uma
contagem por arquivo) por análise cruzada dos 4 `.SEE` de exemplo. **Em aberto pra quando o tracker de
verdade começar a ser construído**:
- Investigar os **1056 bytes de área extra** no final dos 4 arquivos de exemplo (depois do fim dos
  dados de pattern, tamanho idêntico nos 4 apesar de arquivos de tamanhos bem diferentes) — hipótese de
  uma estrutura não documentada no Apêndice B do manual (nomes de SFX?).
- A anomalia isolada do `QUARTH.SEE` (único com ID `SEE3EDIT`): seu campo `$0C-$0D` leu um valor
  absurdo (`48394`) pra um índice de SFX de 0-255 — pode ser uma variante/build diferente do editor,
  não confirmado.
- Descobrir o layout do arquivo `.SFX` (um único efeito) — só o `.SEE` completo está documentado no
  Apêndice B do manual original; não há nenhum arquivo `.SFX` de exemplo em `see/` pra conferir.
- Decidir a interface do futuro tracker nesta IDE: gerar SFX pra tocar via **NestorBASIC** (caminho
  principal já existente, ver módulo 9) é o objetivo declarado pelo usuário — falta decidir se o
  gerador de código também vai emitir um driver de replay nativo (porta do `SEE3PLAY.ASC`) ou se vai
  reaproveitar/gerar arquivos `.SEE` binários compatíveis com o driver original tal como está.
- Harness de round-trip (`editor/tools/`) contra os 4 arquivos `.SEE` reais desta pasta antes de
  confiar em qualquer leitor/escritor novo, mesmo padrão já usado por `MSXDisk.pbi`/
  `GraphosNativeIO.pbi`.

**Estado ao fim de 2026-08-08 — módulo 12 unificado (F5 = console) e ampliado pra 6 abas (v7.27.3,
"TORRE DE CONTROLE")**: resolve o item em aberto deixado pela sessão de 2026-07-30 abaixo ("F5 e o
console continuam sendo instâncias separadas... pergunta feita ao usuário, ainda sem decisão") — a
pedido do usuário, os dois fluxos foram unificados. Mudanças principais:

- **`OMSX_LoadDisk()`** (novo, `OpenMSXBridge.pbi`): `RunOnOpenMSX()` (usado por F5/Nestor Basic/
  export-com-EmRun) não faz mais `RunProgram()` direto — chama isto, que reaproveita a instância já
  rodando (`diska insert` + `reset`, mesma logica de "trocar o disquete") ou sobe uma nova se
  necessário, com um `OMSX_PendingDiskPath` pra resolver a corrida entre "acabou de lançar" e "pipe
  ainda não conectou" (mesmo padrão já usado pela sequência de boot).
- **`Configurar → openMSX...`** (novo arquivo `OpenMsxSettingsGui.pbi`): tela standalone com os mesmos
  campos da aba "Emulador" de `BadigSettings.pbi` — extraídos pra 4 procedimentos compartilhados
  (`BadigCfg_CreateEmulatorGadgets`/`ApplyEmulatorDefaults`/`HandleEmulatorGadgetEvent`/
  `ApplyEmulatorGadgetsToConfig`) chamados pelas duas telas, garantindo fonte única por construção.
- **`OpenMSXConsoleGui.pbi` virou um `PanelGadget` de 6 abas** (Console/Outros comandos/Vídeo/Volume/
  Input Text/Status Info — detalhe completo de cada uma em `docs/MANUAL.md`, seção "Controle remoto
  do openMSX"). Toda a lógica de estado nova segue o MESMO padrão já estabelecido pra Power/Pause
  (`OMSX_ExtractSettingUpdate()` + par `*Known`/valor, atualizado em `OMSX_Poll()`), só estendido pra
  mais nomes de setting: `speed`, `firmwareswitch`, `renshaturbo`, `vsync`, `scale_algorithm`,
  `deinterlace`, `limitsprites`, `fullscreen`, `disablesprites`, `scanline`/`blur`/`glow`/`gamma`/
  `noise`, `led_caps`/`led_kana`/`led_turbo`/`led_fdd` (LEDs — **nome real tem prefixo `led_`**, um
  nome simples tipo `"caps"` nunca casa, achado só testando ao vivo).
- **Descoberta ativa sob demanda** (além da passiva de sempre): `OMSX_QueryFps()`
  (`openmsx_info fps`), `OMSX_QueryMidiConnectors()` (`plug` sem argumentos, parseia a lista de
  conectores) e `OMSX_QueryDevice()` (consulta `set "NOME_volume"` sem valor). Todas usam o mesmo
  padrão "fire and forget com correlação por ordem" (`OMSX_Awaiting*` + `OMSX_ExtractReplyContent()`),
  não um id de correlação real — assume que nada mais está em trânsito no meio, mesma suposição que o
  resto do módulo já fazia implicitamente.
- **Achado de arquitetura importante (aba Volume)**: nomes de dispositivo de som e de conector MIDI
  **não são fixos** — variam por ROM/cartucho/quantidade de instâncias conectadas (confirmado ao vivo:
  `"Konami SCC+ Cartridge with expanded RAM (1)"`, `"Sunrise MoonSound (1) FM"`,
  `"Generic MSX-Audio-MIDI-in"`). Only `PSG`/`keyclick`/`cassetteplayer` são fixos. Isso descartou um
  design inicial de "sliders fixos por nome" (não funcionaria assim que o usuário trocasse de
  cartucho) em favor de descoberta dinâmica: qualquer `<update type="setting" name="X_volume">` que
  chegar vira uma entrada num `Map` (`OMSX_DeviceVolume()`/`OMSX_DeviceBalance()`), keyed pelo nome
  real — resolvido com o usuário via pergunta direta antes de implementar (opção "lista dinâmica"
  escolhida). Limitação residual: consultas de LEITURA (`set "X_volume"` sem valor) não disparam
  `<update>` nenhum (só mudanças de verdade notificam) — problema de "ovo e galinha" no boot (nada
  mudou ainda, lista fica vazia) resolvido com o campo "Adicionar" manual (`OMSX_QueryDevice()`).
- **Balance substitui o antigo `<soundchip>_mode`** (Mute/Left/Right/Stereo) — setting real removido
  do openMSX atual em favor de um `_balance` contínuo (-100 a 100). A aba Volume usa Volume+Balance em
  vez do dropdown de 4 opções que o usuário pediu originalmente ("como no Catapult"), por não existir
  mais no protocolo atual.
- **Dois crashes do openMSX observados durante a investigação ao vivo**, ao empilhar extensões de som
  conflitantes manualmente (`ext moonsound` + `ext audio` no mesmo teste, fora do fluxo normal do
  editor) — não reproduzido em uso normal/conservador; registrado como observação, não como bug
  confirmado no código deste projeto.

**Em aberto nessa frente, pra decisão/trabalho futuro**:
- Nenhum comando do openMSX encontrado que enumere todos os dispositivos de som de uma vez — a
  descoberta depende de mudança de estado ou adição manual.
- Fluxo de conectar/desconectar MIDI in/out implementado mas não testado ao vivo de ponta a ponta.
- Rastreio de estado é "cego a máquina" — se mais de uma instância MSX existir ao mesmo tempo (visto
  ao vivo: uma config de teste subiu "machine1" e "machine2" simultaneamente), os updates de ambas se
  misturam num único conjunto de globais.
- Os itens já abertos pela sessão de 2026-07-30 abaixo que não foram tocados nesta sessão continuam
  válidos (parsing estruturado de ok/nok, detecção de erro em runtime com retorno à linha, timeout na
  thread de `ConnectNamedPipe_()`).

**Estado ao fim de 2026-07-30 — módulo 12 (controle do openMSX) validado ao vivo e ampliado**: a pedido
do usuário, revisão + testes ao vivo (harness novo, `editor/tools/OpenMsxBridgeTestCli.pb`) contra um
openMSX 21.0 real instalado na máquina. Feito: rótulo "experimental" removido (arquitetura validada
ponta a ponta); indicador de estado Ligado/Pausado ao vivo; área de colar texto + botão "Inserir no
openMSX" (mesmo mecanismo do Catapult, `type --`); dois bugs reais corrigidos (log da janela do console
"esvaziando" sozinho; comandos com `<`/`&`/`>` cru quebrando silenciosamente o parser do openMSX). Ver
detalhe completo no módulo 12 acima. **Em aberto nessa frente, pra decisão/trabalho futuro**:
- **"Executar → BASIC" (F5) e "Executar → openMSX..." continuam sendo instâncias/processos openMSX
  totalmente separados**, por decisão deliberada já documentada — rodar um programa com F5 e depois
  abrir o console não dá controle sobre aquela mesma sessão (abre uma segunda instância vazia). Se o
  usuário quiser que o console (incluindo o novo "Inserir no openMSX") controle a instância que F5
  acabou de abrir, isso exige unificar os dois fluxos — pergunta feita ao usuário em 2026-07-30, ainda
  sem decisão.
- **Sem parsing estruturado de ok/nok** nas respostas de comando — `OMSX_Poll()` só devolve texto já
  limpo pra exibir no log; se algum dia for preciso reagir a sucesso/erro por código (não só mostrar pro
  usuário), vale um parser de verdade (comentário já deixado em `OMSX_CleanLine()`).
- **"Inserir no openMSX" validado só na camada de protocolo/escape**, não visualmente — confirmado que
  o texto escapado chega ao openMSX sem erro e que o console continua respondendo depois, mas não há
  mecanismo de leitura de tela (framebuffer) pra confirmar que o texto digitado aparece certo na tela do
  MSX após um `RUN`. Precisaria de `screenshot` + comparação de imagem, ou o usuário conferindo ao vivo.
- **Detecção de erro em runtime com retorno à linha no editor** e **input simulado durante execução
  automatizada** (não o "Inserir no openMSX" manual, que já cobre o caso manual) continuam não
  implementados — nenhuma das duas abordagens documentadas no início do módulo 12 (script Tcl +
  convenção `CHR$(7)`, ou hook de erro via `POKE`+breakpoint) foi implementada.
- **Sem timeout na thread de `ConnectNamedPipe_()`** (`OMSX_PipeConnectThread()`) — se o openMSX travar/
  crashar logo após abrir (antes de conectar no pipe), a thread fica bloqueada até `OMSX_IsRunning()`
  detectar o processo morto e fechar o handle por fora (dispara o desbloqueio); risco baixo na prática,
  mas sem timeout explícito.

**Estado ao fim de 2026-07-29 — SPEC.md sincronizado com o Editor Hexa**: a sessão de 2026-07-29
(commit `bdf80af "bgf9200"`) implementou o Editor Hexa genérico (`editor/HexEditorGui.pbi`) e bumpou a
versão para `7.7.1`/"BFG9200", já documentado no README (seção "O que já temos" + changelog), mas sem
entrada correspondente no SPEC — mesmo padrão de lacuna já visto na sessão de 2026-07-27/28 (feature
implementada e commitada, documentação de arquitetura ficando pra trás). Fechada nesta sessão: nova
linha 17 na tabela de módulos + seção de detalhe "17. Editor Hexa genérico" acima.

**Estado ao fim de 2026-07-28 — documentação posta em dia (README/SPEC/MANUAL/changelog) para o trabalho
de 2026-07-27 (Nestor BASIC + Ajuda MSX BASIC/MSX2+)**: sessão anterior (2026-07-27) implementou e
**commitou** (`b2307ce "Nesto Basic Support"`) três coisas de uma vez sem atualizar nenhuma documentação
— cota da API estourou no meio do trabalho antes da parte de docs. Esta sessão fechou essa lacuna:
- Confirmado por auditoria (agente de exploração dedicado) que a conversão do **manual MSX2+ ACVS**
  (`docs/manual_msx2fm_acvs.pdf`, 66 páginas) está **completa**, não parcial como parecia à primeira
  vista — o que parecia um buraco (páginas 7-47 sem tópico de prosa) é na verdade conteúdo de
  comandos/funções que mora corretamente em `MsxBasic2PlusDictData.pbi`, não em
  `MsxBasic2PlusManualData.pbi`. Ver seção 15 (novo módulo) para o detalhe completo da divisão dict vs.
  manual e a checagem página a página contra o índice real do PDF.
- README.md: versão do topo corrigida (estava presa em `7.3.3`, defasada da `7.5.12` já em uso desde a
  Fase 9 do Graphos III), duas novas seções em "O que já temos" (sistema de Ajuda MSX BASIC + suporte a
  NestorBASIC, com a imagem `images/msxbasica-13.png`), remoção de "extensão NestorBASIC" da lista de
  não-implementado, changelog com as duas entradas que faltavam (`build.ps1 -D`/`--distribute`,
  2026-07-25; Nestor BASIC + Ajuda MSX BASIC, 2026-07-27).
- SPEC.md: módulo 9 (NestorBASIC) reescrito para refletir a implementação real (mais simples que a spec
  original — texto colado em vez de sintaxe nova no pré-processador); novo módulo 15 (Sistema de Ajuda
  MSX BASIC); lacuna "mapeamento completo de funções NestorBASIC" marcada resolvida.
- MANUAL.md: novas seções de uso final para **Ajuda → MSX BASIC...** e **Arquivo → Novo Nestor
  Basic.../Executar → Nestor Basic/Ajuda → Nestor Basic...**.

**O que fica genuinamente em aberto** (nenhum é bloqueio, só não foi feito ainda):
- ~~Sem bump de versão dedicado~~ para o trabalho de 2026-07-27: o `.exe` commitado em `b2307ce` já
  reflete o código novo, mas `build.ps1`/`#App_Version` continuam em `7.5.12` (mesma versão da Fase 9 do
  Graphos III, sessão anterior) — quebra a convenção do projeto de estampar uma versão nova por sessão de
  feature. — **resolvida (2026-07-28, mesma sessão, pedido explícito do usuário)**: `build.ps1`
  (`$Version`) e `#App_Version` (`editor/BadigEditor.pb`) atualizados juntos para `7.5.13` e o `.exe`
  recompilado, cobrindo de uma vez o trabalho desta sessão inteira (Nestor BASIC, Ajuda MSX BASIC/MSX2+
  e `Ajuda → Basic Dignified...`).
- **Revisão de proofreading do MSX2+** (mencionada mas não feita): todo o texto de
  `MsxBasic2PlusDictData.pbi`/`MsxBasic2PlusManualData.pbi` foi transcrito numa única sessão sem revisão
  incremental linha a linha contra `docs/manual_msx2fm_acvs.pdf` — baixo risco (o dicionário MSX1
  equivalente nunca teve esse tipo de revisão dedicada e não apareceu bug reportado), mas fica registrado
  caso apareçam futuros bugs de conteúdo na Ajuda MSX2+.
- **Nada foi commitado nesta sessão de documentação** (2026-07-28) — só os 3 arquivos `.md` foram
  editados no working tree; commitar fica a critério do usuário, por instrução padrão do projeto (só
  commitar quando pedido explicitamente).
- Itens gerais do projeto (não relacionados a esta sessão) continuam abertos e listados na íntegra em
  "Ainda não implementado" do `README.md`: opções `--code`/`--data`/`--align-*`/detecção de sobreposição
  de segmento/saída Intel HEX no linker Z80, editor de tile, tracker, SCREEN 1/5/7/8 no Graphos, saída
  `msxbas2rom`, controle do openMSX via socket/XML em tempo real.

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
