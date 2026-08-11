# Release Notes

Notas de lançamento formais, uma entrada por versão com codinome — versão mais recente primeiro.
Para o histórico completo e detalhado sessão a sessão (incluindo versões sem codinome), ver o
"Changelog resumido" em `README.md`. Para a arquitetura/spec de cada módulo, ver `docs/SPEC.md`.

---

## 7.33.19 — "SETOR ZERO" (2026-08-11)

**Tema da versão**: **`ZAP`**, o segundo comando do Mamute Assembler que lê/escreve dados de verdade —
"muito parecido com o `DM`", pedido explícito do usuário, mas em vez da memória simulada do MSX, edita
**setores de uma imagem de disco (.dsk)** direto, sem passar pela estrutura FAT12.

### Novidades

- **`ZAP <setor inicial>[,<deslocamento>]`** — pede um arquivo `.dsk` (janela normal de escolher
  arquivo) e abre a mesma grade do `DM` (128 bytes, 16 linhas de 8, hexa+ASCII) a partir do setor
  informado (hexa — sector 0 = boot sector). `<deslocamento>` idêntico ao do `DM`. Prioridade pra
  disquetes de **720KB**, mas 360KB/180KB também funcionam — o ZAP não interpreta a estrutura FAT12,
  só lê/escreve bytes crus por posição, igual um editor de setor de verdade da época.
- Mesma navegação do `DM` (mouse/teclado/setas/`TAB`/`PgUp`/`PgDn`/`+`/`-`) — a diferença visível é o
  rótulo de cada linha (deslocamento dentro do setor, `000`-`1F8`) e as linhas de status (`Setor:`/
  `Byte:` em vez de `Endereço:`).
- **Diferença chave em relação ao `DM`**: editar um byte só muda a memória — grava no arquivo `.dsk`
  de verdade só quando você aperta **`Ctrl+S`** ou clica o botão amarelo **"SALVAR SETOR"** (pedido
  explícito do usuário: "escolha uma tecla para salvar o setor no disco"). Só o setor sob o cursor é
  gravado (cirúrgico, não o disco inteiro). O título da janela ganha um `*` enquanto há alterações não
  salvas; fechar nesse estado pede confirmação antes de descartar.

### Bastidores

- `editor/MamuteZapGui.pbi` (novo arquivo) — adaptação quase literal de `MamuteDumpGui.pbi`: mesma
  técnica de desenho/hit-test/edição em 2 estágios, só trocando a "fonte de dados" (`MamuteMem()` via
  slot/página → um buffer `Global Dim MamuteZapDisk.a()` carregado do arquivo escolhido) e adicionando
  o mecanismo de salvar. Sem conceito de "só RAM é editável" aqui — qualquer byte do disco pode ser
  editado (diferente do `DM`, onde ROM/BASIC são somente-leitura).
- `MamuteZap_SaveSector()` grava exatamente 512 bytes no offset do setor via `FileSeek`+`WriteData` —
  não reescreve o disco inteiro a cada edição.
- **Achado real de automação de UI, corrigindo uma suposição anterior**: numa sessão passada (divisão
  de arquivo BIOS+BASIC de 32KB), descartei automatizar o `OpenFileRequester` nativo do Windows por
  achar o Common Item Dialog (Vista+) sem IDs de controle simples. Testando o `ZAP` de verdade, o
  diálogo **respondeu normalmente** ao clássico `GetDlgItem(hDlg, 1148)` (campo de nome de arquivo) +
  `GetDlgItem(hDlg, 1)` (botão OK) + `BM_CLICK` — a suposição anterior era prematura, não confirmada
  meticulosamente antes de descartar a técnica. Guardado pra próxima vez que precisar automatizar um
  seletor de arquivo nesta IDE.
- **Verificado de ponta a ponta, de verdade** (não só por revisão de código desta vez): criado um disco
  de teste real via `BadigEditor.exe --diskmanipulator create` (720KB), aberto no `ZAP` via automação
  completa do diálogo de arquivo (técnica acima), cursor movido, um byte editado pra `5A` via o campo
  de edição, `Ctrl+S` disparado — e o arquivo `.dsk` real no disco **lido de volta de forma
  independente** (fora do app) confirmou o byte gravado no offset certo. Título da janela perdeu o `*`
  após salvar, confirmando o flag de alterações pendentes também funciona.

---

## 7.33.18 — "MEMORIA VIVA" (2026-08-11)

**Tema da versão**: o primeiro comando do Mamute Assembler que realmente lê e escreve na memória
simulada — **`DM`** (Despejo de Memória), pedido em detalhe pelo usuário. Até aqui `PAGE` só arrumava
o mapeamento; `DM` é quem de fato mostra e edita os 256KB simulados por trás dele.

### Novidades

- **`DM <endereço>[,<deslocamento>]`** — abre uma janela nova mostrando 128 bytes (16 linhas de 8) em
  hexa + ASCII lado a lado, a partir do endereço informado (hexadecimal — **agora o padrão de entrada
  em qualquer comando do Mamute Assembler**, pedido explícito do usuário). `<deslocamento>` opcional
  (também hexa, com sinal, `-7F` a `80`) "criptografa/descriptografa" só a interpretação ASCII exibida
  (byte cru + deslocamento, módulo 256) — o bloco hexa sempre mostra o byte cru.
- Cursor navegável por **mouse** (clique direto numa célula, ou nas 4 setas pequenas na tela) e por
  **teclado** (setas, ou `TAB` pra alternar entre o bloco hexa e o bloco texto). Duas setas maiores
  (`<<`/`>>`, ou `PgUp`/`PgDn`) pulam ±128 bytes no endereço base. Botões `+`/`-` ajustam o deslocamento.
- **`RETURN`** abre um campo de edição pro bloco ativo; **`RETURN`** de novo confirma. No bloco hexa,
  digite 1-2 dígitos e vira o byte cru sob o cursor. No bloco texto, digite um texto — cada caractere
  vira um byte (revertendo o deslocamento), escritos a partir do cursor, que avança sozinho. **`ESC`**
  cancela a edição em andamento, ou fecha a janela do DM se não havia edição.
- Escrita só tem efeito em células mapeadas como **RAM** agora (`PAGE`) — ROM/BASIC/Vazio continuam
  somente-leitura, igual hardware real.

### Bastidores

- `MamuteSupport.pbi` ganhou o elo que faltava entre endereço de CPU e a memória simulada:
  `Mamute_ResolveAddress()` (endereço → Slot/Página/Offset via `MamutePageMap()`, o mapeamento ativo do
  `PAGE`), `Mamute_ReadByte()`/`Mamute_WriteByte()` (esta última recusa silenciosamente se a célula
  mapeada não for RAM), mais parsers hexadecimais (`Mamute_ParseHexAddr`/`Mamute_ParseHexOffset`, a
  última já validando a faixa `-7F`/`80`).
- `editor/MamuteDumpGui.pbi` (novo arquivo): grade desenhada num `CanvasGadget` próprio, técnica de
  desenho/hit-test-por-clique adaptada de `HexEditorGui.pbi` (8 bytes/linha em vez de 16, sem scroll —
  os 128 bytes cabem inteiros de uma vez). Cursor via `Box()` cheio + texto em preto sobre verde
  ("video reverso"), não um `Box()` vazado como no Editor Hexa. Navegação por teclado (ausente no Editor
  Hexa) via `AddKeyboardShortcut()` no nível da janela — mesmo mecanismo já comprovado pro Enter do
  prompt `MON>`, só que com mais teclas (setas/PgUp/PgDn/Tab/Return/Esc/+/-). Edição em 2 estágios
  (Return abre um `StringGadget` normalmente oculto pré-preenchido com o valor atual, Return de novo
  confirma) em vez de digitação direta no canvas — evita depender da API de teclado do `CanvasGadget`
  (incerta) e reaproveita a mesma entrada de texto nativa já usada em todo o resto do projeto.
- Reaproveita a fonte configurável em `Configurar → Mamute Assembler...` (não fixa outra fonte à toa).
- **Achado real de PureBasic**: uma `Macro` expandida em mais de um ponto do mesmo `Procedure` não pode
  ter um `Protected` próprio dentro dela (cada expansão gera outra declaração do MESMO nome, que o
  compilador rejeita) — `MamuteDump_DoOffset` (chamada de 4 lugares: 2 botões + 2 atalhos de teclado)
  precisou ter sua variável (`NewOff`) içada pra fora, declarada uma vez só no `Procedure` pai.
- **Verificado de ponta a ponta**, sem simulação de teclado real: build `/CONSOLE` descartável, `DM
  8000` digitado via `WM_SETTEXT` no prompt, depois `PostMessage(WM_COMMAND)` nos IDs dos atalhos de
  teclado (mover cursor, `TAB`, paginar, ajustar deslocamento, abrir/confirmar edição) — confirmado por
  captura de tela em cada passo: cursor se move certo, paginação soma/subtrai 128 certo, deslocamento
  atualiza o rótulo, e o teste decisivo — editar o byte sob o cursor pra `42` com deslocamento `+05`
  mostrou `42` no hexa e **`G`** no texto (0x42+5=0x47='G'), confirmando a "criptografia" ASCII
  funcionando e a escrita batendo com a configuração de RAM real do usuário (endereço testado caía numa
  célula RAM de verdade). Cliques do mouse nos botões/grade não foram automatizados (usam a mesma lógica
  interna dos atalhos de teclado já testados, risco considerado baixo).

---

## 7.33.17 — "TERMINAL PRE-HISTORICO" (2026-08-11)

**Tema da versão**: `Configurar → Mamute Assembler...` agora reconhece arquivos de BIOS+BASIC
combinados de 32KB - comum em ROMs reais de MSX - e divide automaticamente entre as duas páginas certas.

### Novidades

- Ao escolher um arquivo de **32KB** pra uma célula **ROM na Página 0** (a posição convencional da
  BIOS), a tela pergunta se é BIOS+BASIC combinados. Respondendo **Sim**: a Página 0 (deste mesmo slot)
  fica com os primeiros 16KB do arquivo (BIOS) e a Página 1 fica com os últimos 16KB (BASIC, tipo
  ajustado automaticamente) — o mesmo arquivo repetido nos dois pontos, cada um lendo a metade certa.
  Respondendo **Não**, ou escolhendo um arquivo de outro tamanho, funciona como antes (só a célula
  selecionada recebe o arquivo). O usuário continua livre pra trocar o arquivo da Página 1 na mão depois,
  mesmo após o "Sim" preencher automaticamente.
- A coluna Arquivo da lista mostra **"(últimos 16KB)"** ao lado do caminho quando a célula usa a
  segunda metade de um arquivo compartilhado, pra deixar claro de onde vem cada bloco.

### Bastidores

- `MamuteMemCell` (`MamuteSupport.pbi`) ganhou o campo `FileOffset` — deslocamento em bytes dentro do
  arquivo de onde começam os 16KB desta célula (0 normalmente, 16384 pra metade final de um arquivo
  combinado), persistido no `mamute_settings.json` junto com Tipo/Arquivo. Prepara o terreno pro
  carregamento de arquivo de verdade (ainda pendente) já saber ler o pedaço certo de cada arquivo.
- Verificado: `build.ps1` compilou limpo; a tela reaberta com a configuração real já salva pelo usuário
  não regrediu visualmente. O fluxo completo (escolher um arquivo de 32KB de verdade → confirmar no
  diálogo → ver as duas linhas preenchidas) **não foi automatizado** nesta sessão — o seletor de
  arquivo nativo do Windows (tema Vista+/Common Item Dialog) não expõe IDs de controle simples como os
  diálogos antigos, tornando a automação por mensagem pouco confiável; ficou verificado por revisão de
  código (mesmo padrão já comprovado de atualização de `WorkCells()`/`MamuteSettings_RefreshRow()` usado
  pelas outras edições da tela).

---

## 7.33.16 — "TERMINAL PRE-HISTORICO" (2026-08-11)

**Tema da versão**: pequeno ajuste de legibilidade — a fonte fixa do Mamute Assembler (Consolas 14pt
negrito) virou configurável em `Configurar → Mamute Assembler...`.

### Novidades

- **Configurar → Mamute Assembler...** ganhou uma seção "Fonte do terminal": combo de fonte (mesma
  enumeração de fontes monoespaçadas já usada em `Configurar → Editor...`, `EditorCfg_EnumMonospaceFonts()`),
  campo de tamanho e checkbox "Negrito". Persistido no mesmo `mamute_settings.json`.

### Bastidores

- `MamuteGui_EnsureFont()` deixou de carregar uma fonte fixa uma única vez — agora recarrega a partir de
  `MamuteFontName`/`MamuteFontSize`/`MamuteFontBold` (`MamuteSupport.pbi`) toda vez que a janela do
  monitor abre, liberando a fonte anterior antes (`FreeFont()`) pra não vazar um `HFONT` a cada abertura.
  Trocar a fonte em `Configurar → Mamute Assembler...` só tem efeito na próxima vez que o monitor abrir.
- Verificado com build `/CONSOLE` descartável + captura de tela: combo populado com fontes reais do
  sistema, valores mostrados batendo com a configuração já salva pelo usuário (incluindo a configuração
  de slots real que ele já tinha feito — ROM/BASIC no Slot 0, RAM no Slot 3 — confirmando de quebra que
  o `PAGE` "estado de boot" calcula certo contra dados reais, não só contra a config vazia testada antes).

---

## 7.33.15 — "TERMINAL PRE-HISTORICO" (2026-08-11)

**Tema da versão**: uma ferramenta nova, pedida do zero pelo usuário e construída em duas partes na
mesma sessão — **Mamute Assembler** (`Executar → Mamute Assembler...`), uma janela "monitor" inspirada
nos montadores de linha de comando dos computadores de 8 bits dos anos 80 (referência direta: o
**MegaAssembler** do próprio usuário). Primeiro só a casca (prompt + um comando); depois, uma simulação
de verdade do **sistema de slots do MSX** por baixo dela.

### Novidades

- **Executar → Mamute Assembler...** — janela "terminal" (fundo preto, texto monoespaçado verde e
  **negrito**, fora do tema claro do resto da IDE de propósito) com um prompt `MON>`.
- **`BA` / `QUIT`** — encerra a janela (não diferencia maiúsculas/minúsculas), equivalente a fechar pelo X.
- **`PAGE`** — simula o mapeamento de slots do MSX de verdade: 4 slots (0-3), cada um com 4 páginas de
  16KB (`0000-3FFF`/`4000-7FFF`/`8000-BFFF`/`C000-FFFF`, os mesmos endereços do hardware real).
  `PAGE` sozinho coloca as 4 páginas no slot marcado como RAM; `PAGE ?` mostra o mapeamento ativo sem
  mudar nada; `PAGE X,Y,Z,W` troca o slot comutado em cada uma das 4 páginas de uma vez.
- **Configurar → Mamute Assembler...** — configura o que existe fisicamente em cada um dos 16 blocos de
  memória (Vazio/RAM/ROM/BASIC + arquivo pra ROM/BASIC, ex.: uma BIOS real) — lista de 16 linhas
  (slot × página), editando tipo/arquivo da linha selecionada. Persistido em `mamute_settings.json`.
- **Ajuda → Mamute Assembler...** — manual da ferramenta, mesmo layout de árvore + busca + conteúdo das
  outras janelas de Ajuda, com um tópico por comando já portado (`BA`/`QUIT` e `PAGE`).

### Bastidores

- `editor/MamuteAssemblerGui.pbi`: `EditorGadget` somente-leitura como scrollback + `StringGadget` de
  entrada, Enter submete via `AddKeyboardShortcut` — mesmo idioma já comprovado em
  `OpenMSXConsoleGui.pbi`. `MamuteGui_Dispatch()` isola os comandos num `Select` só, ponto de extensão
  único pras próximas sessões — cresceu de "só o verbo" pra "verbo + argumentos crus" pra acomodar `PAGE`.
- Achado real: `App_StyleChildCallback` (`BadigEditor.pb`) força a fonte Segoe UI em todo controle
  nativo de qualquer janela no primeiro repaint dela, sem opção de desligar por janela — a fonte
  monoespaçada (Consolas, agora 14pt negrito) é reaplicada de novo logo antes do loop de eventos pra
  garantir que vence essa corrida.
- `editor/MamuteSupport.pbi` (novo): modelo de memória (`MamuteMem()`, 4×4×16KB, `Dim` zera sozinho) +
  configuração física por célula (`MamuteCfgCell()`) + mapeamento ativo (`MamutePageMap()`) - conceitos
  deliberadamente separados, igual o registrador de slot primário de um MSX real vs. o que fisicamente
  está ligado em cada slot. `Mamute_ResetPageMapToDefault()` calcula o "estado de boot" a partir da
  configuração (ROM/BASIC ganham de RAM se colidirem na mesma página; página sem nada configurado cai no
  slot 0).
- **Achado de sintaxe do PureBasic**: `NewMap` não pode ser usado como nome de variável comum (mesmo
  para um array `Dim`) — é a mesma palavra reservada do comando `NewMap` (declarar `Map`) e o compilador
  tenta interpretar como tal, com uma mensagem de erro enganosa ("A map name needs to start with a
  character"). Renomeado pra `ParsedSlots`.
- Conteúdo de `Ajuda → Mamute Assembler...` é escrito à mão (`MamuteHelp_Add()`), ao contrário do
  `Ajuda → asMSX...` (convertido de um manual externo) — o Mamute Assembler é uma ferramenta nova desta
  IDE, sem documento de origem pra converter.
- Verificado com build `/CONSOLE` descartável + captura real de tela de todas as janelas. O comando
  `PAGE` foi testado de ponta a ponta **sem simulação de teclado real** (a diretriz do projeto evita
  isso): texto injetado direto no `StringGadget` via `WM_SETTEXT` (achado por classe `Edit`/altura entre
  os filhos da janela) + `PostMessage(WM_COMMAND)` no ID do atalho Enter - confirmou `PAGE 2,2,2,2`
  aplicando corretamente, `PAGE 9,9,9,9` rejeitado (`?ERRO DE SINTAXE`, fora de 0-3) e `XYZ` rejeitado
  (`?COMANDO INVALIDO`). A tela `Configurar → Mamute Assembler...` foi verificada só visualmente (16
  linhas/colunas corretas) - a seleção de linha da lista não foi automatizada de propósito
  (`LVM_SETITEMSTATE` via `SendMessage` é um dos casos que a diretriz do projeto marca como podendo
  travar/crashar o processo alvo).

---

## 7.33.13 — "TRIPLA MONTAGEM" (2026-08-11)

**Tema da versão**: terceiro assembler Z80 suportado pela IDE — **asMSX**
([github.com/Fubukimaru/asMSX](https://github.com/Fubukimaru/asMSX)), ao lado do assembler nativo
(`Z80Asm.pbi`) e do N80/Nestor80 externo. Pedido explícito do usuário, em duas partes na mesma sessão:
primeiro configuração + download + Ajuda + template de arquivo novo (mesmo padrão já usado pro N80/
MSXBas2Rom), depois um botão de verdade pra montar chamando o executável.

### Novidades

- **Configurar → asMSX...** — caminho do executável (editável + "..." pra apontar pra uma instalação já
  existente) e botão "Baixar versão mais recente" (release oficial do GitHub, executável avulso por SO/
  arquitetura, sem precisar descompactar zip nenhum). Mais as opções de linha de comando usadas ao
  montar: sintaxe Zilog padrão (`-z`), modo silencioso (`-s`), modo verboso (`-vv`) e caminho/prefixo de
  saída (`-o`).
- **Ajuda → asMSX...** — o manual oficial (`asmsx.md`) navegável/pesquisável, mesmo padrão de árvore +
  busca + conteúdo das outras janelas de Ajuda, com título/negrito/código/blocos de código formatados.
- **Arquivo → Novo asMSX...** — cria um `.asm` já com cabeçalho de comentário e as diretivas `.BASIC`/
  `.ORG` mais pertinentes pra um programa MSX típico carregável via `BLOAD"...",R`, mais uma nota sobre a
  diferença de sintaxe mais visível do asMSX (colchetes `[ ]` em vez de parênteses pra endereçamento
  indireto).
- **Executar → Montar Fonte asMSX...** — monta a aba `.asm` ativa chamando o executável de verdade
  (salva num arquivo real primeiro, já que o asMSX só assembla arquivo em disco), mostrando a saída do
  programa ao final. Ao contrário do MSXBas2Rom, o tipo do arquivo gerado (`.rom`/`.bin`/`.com`/etc.) vem
  de diretivas dentro do próprio fonte, não de uma opção da IDE.
- **Configurar → Projeto...** ganhou uma 4ª aba, "asMSX" — configuração específica de um projeto (caminho
  + opções), mesmo padrão já usado pro Basic Dignified/N80/MSXBas2Rom.

### Bastidores

- Diferente do N80 (3 programas, precisa varrer o histórico de releases) e do MSXBas2Rom (asset `.zip`),
  o asMSX publica **um único executável avulso por SO/arquitetura** em `releases/latest` — novo helper
  `ExtTool_DownloadFile()` (`ExternalToolDownload.pbi`), mais simples que `ExtTool_DownloadAndExtractZip()`,
  com `chmod +x` explícito fora do Windows (o asset baixado não é um zip, então não há permissão nenhuma
  pra preservar).
- O manual do asMSX já é Markdown real e limpo, sem nenhum link interno — ao contrário do Livro Vermelho/
  MSX2 Technical Handbook (módulo 30), não precisou de nenhuma infraestrutura de âncora/link: a janela de
  Ajuda reaproveita o renderizador genérico (`GenMdHelp_RenderMarkdown()`) direto, sem parser próprio.
  Conteúdo baked em `AsmsxHelpData.pbi` em tempo de compilação (script descartável `convert_asmsx.py`),
  não baixado em tempo de execução — a cópia local do repositório do asMSX é só referência de build,
  gitignored, igual `badig/`/`nestor80/`.
- `AssembleAsmsxFromActiveTab()` não distingue se a aba `.asm` ativa nasceu de "Novo Assembly" ou "Novo
  asMSX..." — `Docs()\Mode` não carrega essa informação, e não precisa: o asMSX só vê texto de assembly,
  tanto faz de qual dos dois menus a aba veio.
- Verificado com um build `/CONSOLE` descartável + `PostMessage(WM_COMMAND)` pelos IDs de menu + captura
  real de tela (nenhuma janela foi considerada pronta só por compilar) — inclusive o caminho de erro
  ("configure o executável primeiro"). A 4ª aba de `Configurar → Projeto...` reaproveita infraestrutura
  já usada pelas outras 3 sem alteração, não verificada visualmente nesta sessão (exige projeto salvo).

---

## 7.33.11 — "ACERVO VIVO" (2026-08-10)

**Tema da versão**: o menu Ajuda ganhou uma base de conhecimento MSX inteira — sete janelas novas,
~3300 tópicos, extraídos automaticamente dos 3 arquivos CHM do emulador RuMSX encontrados no
repositório (`help/*.CHM`) mais duas referências externas clássicas ("The MSX Red Book" e o MSX2
Technical Handbook), com links internos e figuras originais **clicáveis de verdade** nas duas últimas.

### Novidades

- **Ajuda → Manuais MSX...** — MSX-DOS 2, Z80/R800, Turbo-Basic Compiler, FM-PAC e a transcrição
  original de 1997 do MSX2 Technical Handbook, extraídos de `help/MANUALS.CHM`.
- **Ajuda → MSX-Basic/DOS/CP-M (RuMSX)...** — 359 comandos de `help/SOFTWARE.CHM`; segunda fonte de
  referência MSX-BASIC em paralelo com "Ajuda → MSX BASIC..." (livro brasileiro).
- **Ajuda → BIOS MSX: Chamadas/Hardware/Documentação (RuMSX)...** — três janelas, `help/MSXBIOS.CHM`;
  597 rotinas de BIOS individuais, uma por endereço/nome.
- **Ajuda → Livro Vermelho...** — "The MSX Red Book" (1985) completo, 973 tópicos, com as ~2911
  referências cruzadas do livro clicáveis de verdade (hotspot nativo do Scintilla) e as 53 figuras
  originais num popup.
- **Ajuda → MSX2 Technical Handbook...** — edição Markdown de Konamiman, 1356 tópicos, mesmos links e
  84 figuras clicáveis do Livro Vermelho.

### Bastidores

- Dois estilos de renderizador por tipo de conteúdo: monoespaçado/sem quebra automática pra texto
  pré-formatado (tabela ASCII, diagrama de bits); proporcional com negrito/código/link pra prosa.
- Cada `*HelpData.pbi` monta o corpo linha a linha (`Begin()`/`L()`/`Commit()`) em vez de uma
  expressão gigante `"l1" + #CRLF$ + "l2" + ...` — `pbcompiler.exe` tem um limite de "continuation
  lines" que os documentos maiores estouravam.
- Achado de compilador: bytes de controle crus (`Chr(1)` etc.) dentro de um literal de string
  quebram o `pbcompiler.exe` ("Literal string not terminated") mesmo com a string bem formada —
  sentinelas de link/código trocadas por ASCII imprimível (`"[[["`/`"|||"`/`"]]]"`/`"@@@"`).
- 3 bugs reais corrigidos durante testes ao vivo (nenhuma janela considerada pronta sem abrir de
  verdade): heurística de endereço confundindo rótulo de bit (`b7`) com endereço de rotina;
  indentação de item de lista aninhado do Livro Vermelho tratada como bloco de código; título
  duplicado na tela nas janelas monoespaçadas.
- Decisão de direitos autorais sobre o conteúdo reproduzido (documentos antigos amplamente
  disponíveis + conteúdo do próprio RuMSX) avaliada explicitamente com o usuário antes de
  implementar — detalhe completo em `docs/SPEC.md`, módulo 30.
- Versão do PureBasic usada no projeto atualizada na documentação para **6.41**.

---

## 7.33.10 — "ADEUS ESCURIDÃO" (2026-08-10)

**Tema da versão**: usuário pediu pra atacar o visual datado da IDE sem entrar numa reforma grande
(reescrita de UI, framework novo, etc.) — o pior ponto era os temas escuros, onde os controles nativos
que os botões tematizados não alcançam (combo/checkbox/lista/scrollbar) ficavam com contraste ruim
contra fundo escuro. Três mudanças pequenas e de baixo risco, todas reaproveitando infraestrutura que
já existia, em vez de uma reforma de interface.

### Novidades

- **Só temas claros**: os 5 temas escuros (Grafite/Azul Profundo/Rosé/Carmesim/Floresta) foram
  removidos. Dois temas claros novos — **Neblina** (azulado, frio) e **Linho** (lilás) — entraram ao
  lado dos 2 originais (Neve/Bege), mantendo 4 opções em **Configurar → Editor...**. Neve é o novo
  padrão.
- **Ícones de botão ligados por padrão**: uma Nerd Font só-de-ícones
  (`editor/fonts/SymbolsNerdFontMono-Regular.ttf`, licença SIL OFL) passou a ser empacotada junto do
  executável e carregada automaticamente na inicialização — os 311 botões tematizados da IDE que já
  sabiam mostrar ícone (infraestrutura da v7.31.3) deixam de depender de o usuário achar e configurar
  manualmente uma fonte. O combo **Fonte de ícones** ganhou a opção **"(Padrão - ícones embutidos)"**;
  ainda dá pra desligar (**"(Nenhuma - usa texto)"**) ou trocar por outra Nerd Font instalada.
- **Manifesto `/XP` no build**: `build.ps1` agora compila com a flag `/XP` do `pbcompiler.exe`
  (dependência do `comctl32` v6) — os controles nativos não-tematizáveis citados acima passam a usar o
  visual moderno do Windows em vez do estilo antigo sem tema, em qualquer tema da IDE.

### Bastidores

- `editor_settings.json` de instalações anteriores migra sozinho: cada tema escuro removido mapeia
  pro claro de "família" mais parecida (`Navy`→`Mist`, `Rose`→`Linen`, `Crimson`/`Forest`→`Paper`,
  `Graphite`/legado→`Snow`) — ninguém reabre a IDE num tema que não existe mais.
  `EditorCfg_ThemeIsDark()` foi mantida (sempre retornando `#False`) em vez de excluída, já que 2
  arquivos ainda a chamam para decidir quando acionar as APIs de modo escuro nativo do Windows — sem
  tema escuro nenhum, esse código agora fica permanentemente inerte, o que é o comportamento correto.
- Novo campo `IconsEnabled` (booleano) na struct de configurações, separado de `IconFontName` — sem
  ele não dava pra distinguir "sem preferência salva" (usa a fonte embutida) de "usuário desligou de
  propósito", já que `IconFontName` vazio passou a significar "usa o padrão" em vez de "sem ícone".
  `EditorCfg_LoadCustomFonts()` foi fatorada em `EditorCfg_LoadFontsFromFolder()`, chamada duas vezes
  (pasta de fontes empacotada + pasta customizada do usuário) em vez de duplicar a varredura de
  diretório.
- **Investigado e descartado nesta rodada**: reescrever a apresentação em HTML/CSS/JS via
  `WebViewGadget()` nativo do PureBasic 6.10+ (`BindWebViewCallback()`/`WebViewExecuteScript()` pra
  IPC), ou separar o "motor" da IDE numa DLL consumida por uma GUI em outra linguagem (Go, Tauri,
  Electron). Tecnicamente viável e sem dependência de runtime além do WebView2 já presente no Windows
  11, mas um esforço grande (~40 arquivos `.pbi` de diálogo virariam HTML) pro ganho puramente visual
  perseguido aqui — descartado a favor das 3 mudanças acima.

---

## 7.33.9 — "CARTUCHO DE VERDADE" (2026-08-10)

**Tema da versão**: o `msxbas2rom` (compilador de terceiro que gera ROM de verdade a partir de
MSX-BASIC) deixou de ser só um executável baixado — agora faz parte do fluxo de trabalho de ponta a
ponta da IDE, e o projeto inteiro (com todos os fontes) ficou portátil entre máquinas.

### Novidades

- **Basic Dignified entende o dialeto do MSXBAS2ROM**: programas escritos com labels/`DEFINE`/`FUNC`/
  `RET` (em vez de BASIC clássico numerado) agora protegem o vocabulário exclusivo do compilador
  (`FILE`/`TEXT`, sub-comandos de `CMD`/`SET`/`GET`, `HEAP()`/`TILE()`/`TURBO()`...) contra o
  encurtamento automático de variáveis — antes, usar essas palavras como identificador corrompia o
  programa silenciosamente.
- **Executar → Compilar ROM (MSXBas2Rom)...**: gera o `.bas` e chama o `msxbas2rom.exe` de verdade,
  produzindo um `.rom` — antes só existia o downloader do executável, nenhum caminho de fato o usava.
- **Configurar → MSXBas2Rom...** ganhou uma tela completa de opções de compilação (modo ROM simples/
  MegaROM em 5 variantes, silencioso/debug, caminhos de entrada/saída, geração de símbolos de
  depuração, números de linha no binário, projeto VSCode) — espelhando 1:1 as opções reais do
  compilador.
- **Configurar → Projeto...**: Basic Dignified, N80 e MSXBas2Rom agora podem usar uma configuração
  própria de cada projeto em vez da global da máquina.
- **Projeto `.msxproject` portátil**: os fontes BASIC/Assembly são resincronizados automaticamente com
  o disco ao salvar o projeto e restaurados sozinhos ao abrir num local novo — leva só o arquivo de
  projeto de um PC pro outro e o código-fonte vai junto.
- **Ajuda → MSXBas2Rom...**: passou a incluir os exemplos oficiais do compilador (pasta `demo/`) e os
  10 jogos completos de `amaurycarvalho/msxbasic`, navegáveis com destaque de código de verdade, além
  da documentação da wiki oficial já baixada automaticamente. Destaque de sintaxe do dialeto ganhou uma
  cor própria, em vez de reaproveitar as cores do MSX-BASIC clássico.

### Bastidores

- O motor Dignified (`DignifiedPreprocessor.pbi`) ganhou um **modo**, não um segundo parser — evita
  duplicar ~2500 linhas testadas de labels/loops/`INCLUDE`/remtags que teriam que evoluir em paralelo.
- As 3 telas de configuração (Basic Dignified/N80/MSXBas2Rom) não mudaram de conteúdo pra virar
  "por projeto" — só ganharam um caminho de arquivo alternativo, reaproveitado tanto pela tela global
  quanto pela nova tela de projeto.

---

## 7.33.1 — "PENTE FINO" (2026-08-09)

**Tema da versão**: usuário pediu uma revisão geral do programa — bugs, unidade dos módulos,
performance e integração. Sete auditorias paralelas (uma por área do código: pipeline/tokenizer,
toolchain Z80, shell principal, editores gráficos, editores de tela texto, áudio/tracker, settings/
integrações externas) levantaram uma lista de achados; esta versão fecha os que valiam a pena corrigir
nesta rodada.

### Novidades

- **Helper de janela compartilhado** (`OpenModelessChildWindow`/`CloseModelessChildWindow`,
  `BadigEditor.pb`) — a mesma sequência de abrir/fechar diálogo (cor de fundo, ícone, desabilitar
  janela principal) que se repetia em ~30 arquivos virou duas chamadas, migrado em 35 arquivos.
- **Modo escuro nativo do Windows, de verdade** — barra de título, campos de texto/lista e agora
  também rótulos (`TextGadget`) seguem o tema escolhido nos 5 temas escuros (Graphite/Navy/Rose/
  Crimson/Forest); antes disso o mecanismo existia mas nunca acionava, ver "Bastidores".

### Bugs corrigidos nesta versão

- Fechar uma aba **não-ativa** (pelo próprio "x") trocava o documento visível pra aba errada.
- Vazamento de handles GDI (ícones de toolbar nunca liberados) em `CharsetEditorGui.pbi`,
  `GraphosScreenGui.pbi` e `AquarelaCharsetEditorGui.pbi`.
- `ProjectDB::SaveAs` podia abandonar o projeto do usuário silenciosamente se copiar o arquivo desse
  certo mas reabrir o banco no novo local falhasse.
- `MSXDisk::ExtractFile` reportava sucesso numa extração de disco truncada.
- Download de zip parcial (ZIP incompleto por queda de rede) não era apagado em `BadigSettings.pbi`/
  `FontDownloader.pbi`.
- Vazamento de buffer em `Z80Lib::CreateOrAddLibrary` quando uma entrada `.REL` posterior falhava a
  validação.
- Thread do pipe de comando do openMSX nunca fechada (`OpenMSXBridge.pbi`).
- Loop labels aninhados sem limite no pré-processador Dignified podiam corromper heap silenciosamente
  em vez de falhar limpo (`Dig_LoopStack`, `DignifiedPreprocessor.pbi`).
- **O achado maior**: 8 pontos comparando `EditorCfg\Theme = "Dark"` literalmente — valor legado que a
  própria migração pros 7 temas (`7.31.2`) já tornava inatingível — deixavam o modo escuro nativo do
  Windows sempre desligado, em qualquer tema.

### Documentação nova

- `CLAUDE.md` ganhou uma nota técnica sobre o bug do tema morto e a técnica `WM_CTLCOLORSTATIC`.
- `docs/SPEC.md`: nova entrada em "Próximos passos em aberto" com o resumo completo, incluindo o que
  foi adiado de propósito (unificação Screen0/Screen1, dedup do `ProjectDB`, dirty-rect do Graphos,
  rede síncrona na UI thread).

### Bastidores

- **Por que o modo escuro nunca funcionava**: o sistema de 7 temas substituiu um modelo binário antigo
  "Dark"/"Light" — `EditorCfg_Load()` já migra qualquer valor legado assim que carrega, mas 8 lugares
  em `BadigEditor.pb`/`SeeTrackerEditorGui.pbi` continuavam comparando contra o literal `"Dark"` que a
  própria migração tornava impossível de ocorrer. Corrigido com um helper novo,
  `EditorCfg_ThemeIsDark()`, em vez da comparação direta.
- **O bug dos rótulos que o próprio código já tinha marcado como "abandonado"**: uma tentativa anterior
  de colorir `TextGadget` via `SetGadgetColor()` + `GetDlgCtrlID_(hWnd)` (dentro do callback de
  `EnumChildWindows_`) não funcionava porque `GetDlgCtrlID_` não devolve o número do gadget do
  PureBasic nesse contexto. A correção não precisa do número do gadget: tratar `#WM_CTLCOLORSTATIC` no
  mesmo subclass de janela que já tratava `#WM_CTLCOLOREDIT`/`#WM_CTLCOLORLISTBOX` resolve no nível de
  mensagem Win32, cobrindo todo rótulo de todo diálogo automaticamente.
- **Verificado com screenshot real, não só leitura de código** — mesmo cuidado do achado de `7.31.4`:
  como não existe automação de GUI pronta pra este app nativo Win32, foi escrito um driver PowerShell
  descartável (P/Invoke: `EnumWindows`/`GetMenu`/`PostMessage`/`PrintWindow`) que abre o `.exe` de
  verdade, navega o menu real, abre um diálogo e captura a imagem — confirmado contra o tema `Rose` já
  salvo nas configurações reais do usuário.
- **Um "bug" que não era bug**: a auditoria original apontou `Z80SubProj_ReadTextFile`
  (`Z80SubProject.pbi`) como O(n²) por concatenar string linha a linha. Implementar o "fix" e testar
  byte a byte contra o original revelou que `ReadString(FileNum, #PB_File_IgnoreEOL)` **sem** parâmetro
  `Length` já lê o arquivo inteiro numa chamada só — o loop só roda uma vez, já era O(n). Revertido, com
  uma nota no código pra não repetir o engano.

---

## 7.31.4 — "ADEUS WINDOWS 3.1" (2026-08-08)

**Tema da versão**: o piloto no Editor Hexa (`7.31.3`) agradou — usuário pediu pra replicar o
mesmo formato (botões tematizados + ícones Nerd Font opcionais) em **todos** os diálogos e
módulos da IDE. 293 botões em 33 arquivos convertidos numa sessão só.

### Novidades

- **Todo diálogo da IDE agora segue o tema** — telas de Configurar, editores visuais (Sprite,
  Alfabetos, Som, SEE Tracker, Telas, Música, DRAW Screen 2), gerenciador de disco, console do
  openMSX, todas as telas de Ajuda: fundo da janela + todos os botões (293 ao todo) seguem a
  paleta do tema escolhido, em vez de chrome branco/cinza nativo do Windows.
- **Mais de 140 botões com ícone Nerd Font** quando uma fonte de ícones está configurada — Fechar,
  Salvar, Salvar como, Copiar, Tocar, Parar, Ejetar, Inserir, Limpar, Adicionar, Remover, Conectar/
  Desconectar, Voltar, Reset, Montar (Build), Linkar, Importar, Mudo e mais, cada um com tooltip
  mostrando o nome ao passar o mouse. Ações bem específicas de um módulo (ex.: "Gerar código PLAY",
  "Injetar no cursor", "Transferir programa atual") ficam de propósito só com texto — um ícone
  genérico ali confundiria mais do que ajudaria; o mesmo vale pros botões de estado dinâmico do
  console do openMSX ("VSync: ?", "Power: ?" etc.) e pros de uma letra só dos editores de
  som/música/tracker.
- **Infraestrutura generalizada**: o que nasceu especificamente no Editor Hexa (`HexEd_*`,
  `7.31.3`) virou `editor/ThemedButtons.pbi` — módulo compartilhado com a `Macro ThemedButton()` e
  as constantes `#Icon_*`, usado por todos os 33 arquivos. `HexEditorGui.pbi` foi migrado pra usar
  o módulo compartilhado também, sem duplicar código.

### Bugs corrigidos nesta versão

- Nenhum — rollout de um padrão já validado no piloto anterior, sem correção de regressão
  conhecida.

### Documentação nova

- `docs/MANUAL.md`: seção **Botões com ícones** reescrita pra refletir o escopo novo (todos os
  diálogos, não só o Editor Hexa); `CLAUDE.md` ganhou uma nota de arquitetura sobre a ordem de
  declaração `Global`/`Structure` exigida por `EnableExplicit` + inclusão textual — pegadinha real
  encontrada ao mover `ThemedButtons.pbi` pra cedo o bastante na cadeia de `XIncludeFile`.

### Bastidores

- **Achado real de arquitetura**: quase todos os 33 arquivos de diálogo são incluídos bem no topo
  de `BadigEditor.pb` (antes de `Global Color_*`/`Structure EditorSettings` existirem) — igual ao
  motivo que já forçava `WordStarKeys.pbi` (removido em `7.31.0`)/`MdViewerGui.pbi`/
  `EditorSearch.pbi` a ficarem no fim do arquivo. A correção não foi mover os 33 arquivos (mudaria
  a ordem de dezenas de `Declare` existentes) e sim mover as poucas linhas de `Structure`/`Global`
  de que `ThemedButtons.pbi` precisa pro topo do arquivo, antes do primeiro `XIncludeFile` —
  mesmo idioma que os `Declare` de procedure já usados ali, só que pra dado em vez de código.
- **Como a conversão foi feita em escala sem virar bagunça**: nenhuma das ~400 edições (267
  botões + 40 janelas + 127 ícones + 104 tooltips) foi digitada uma por uma — três scripts Python
  pequenos e descartáveis (conversão mecânica `ButtonGadget`→`ThemedButton` com parsing de parênteses
  balanceados, não regex ingênuo; inserção de `SetWindowColor` após o guard `If Not Win`; upgrade de
  ícone só pra rótulos exatos de uma lista curada) fizeram o trabalho repetitivo, com
  recompilação depois de cada rodada pra pegar erro cedo. Foram escritos no scratchpad da sessão,
  não fazem parte do repositório.
- **Por que só ~140 dos 293 botões ganharam ícone**: a lista de conceitos com ícone verificado
  (contra o `glyphnames.json` oficial, mesmo cuidado do piloto) ficou deliberadamente pequena e
  só com ações universais — o resto continua em texto, o que é a escolha certa pra ação
  específica de um módulo, não uma lacuna a preencher depois.

---

## 7.31.3 — "NERD DE VERDADE" (2026-08-08)

**Tema da versão**: o usuário achou que os diálogos ainda pareciam "Windows 3.1" mesmo com os 7
temas novos — "aquele mar de botões cinza que estragam a aparência". Piloto no **Editor Hexa**:
botões deixam de ser controle nativo do Windows (que ignora `Color_*`) e viram imagens desenhadas
na hora, na cor do tema — com a opção de trocar o texto por ícone de verdade de uma Nerd Font,
não um desenho genérico à mão.

### Novidades

- **Editor Hexa (`F7`) com botões tematizados**: os 16 botões da janela (Abrir arquivo, Salvar,
  Marcar início/fim, Preencher..., Excluir bloco... etc., mais os 3 da Galeria de templates) agora
  são desenhados na cor do tema (fundo + borda a partir de `Color_TabInactive`, texto em
  `Color_TextActive`) em vez de chrome cinza nativo do Windows. As setas da barra de rolagem
  customizada também deixaram de ser quadradinhos brancos fixos.
- **Fonte da interface reaproveitada**: os botões tematizados usam a mesma fonte já escolhida em
  **Configurar → Editor...** (`EditorCfg\FontName`) em vez de "Segoe UI" fixo — qualquer `.ttf`
  colocado na pasta de fontes customizadas (ou baixado pelo botão **Baixar fontes (Nerd
  Fonts)...**, que já existia) já deixa a interface mais bonita, sem precisar instalar nada no
  Windows (mesmo mecanismo `AddFontResourceEx` privado ao processo que já existia).
- **Ícones de verdade, não desenhados à mão**: novo combo **Fonte de ícones** em **Configurar →
  Editor...** — escolhendo uma Nerd Font ali, os botões do Editor Hexa trocam o texto por um
  glifo de ícone real (pasta aberta, disquete, lixeira, cadeado etc.), com o nome continuando
  disponível via tooltip ao passar o mouse. Os 15 codepoints usados foram conferidos ao vivo
  contra o `glyphnames.json` oficial do projeto Nerd Fonts (v3.5.0) antes de entrar no código —
  não chutados de memória. Sem fonte de ícones escolhida (padrão), os botões continuam com texto
  normalmente.

### Bugs corrigidos nesta versão

- Nenhum — recurso novo, sem correção de regressão conhecida.

### Documentação nova

- `docs/MANUAL.md` ganhou a seção **Botões com ícones** e a menção à nova opção **Fonte de
  ícones** em **Configurar → Editor...**.

### Bastidores

- **Por que não confiar no primeiro resultado da busca web pra codepoints**: uma primeira consulta
  (resumida por IA a partir do `glyphnames.json`) devolveu `fa-plus_square = U+F055`; conferindo
  o JSON bruto direto (`curl` + parse Python), o valor real é `U+F0FE`. Motivo pra sempre verificar
  codepoint exato contra a fonte primária antes de gravar no código, em vez de confiar num resumo
  de segunda mão.
- **Por que fonte de ícones é uma opção separada da fonte de código**: nem toda fonte bonita pro
  código é uma Nerd Font (a maioria não é), e forçar os botões a tentar usar qualquer fonte
  escolhida arriscaria mostrar o quadradinho de "glifo ausente" em vez de um ícone — combo próprio,
  com "(Nenhuma - usa texto)" como padrão seguro, deixa a decisão explícita com o usuário.
- **O que NÃO entrou nesta rodada**: o mesmo tratamento (botões tematizados + ícones opcionais)
  vale só pro Editor Hexa por enquanto — as ~10 outras janelas de diálogo (Configurar, SEE
  Tracker, editores visuais) continuam com botão nativo. Replicar o padrão (macro
  `HexEd_Button`/`HexEd_CreateButtonImage`, generalizada) fica pra uma próxima rodada, se o
  resultado deste piloto agradar.

---

## 7.31.2 — "CAMALEÃO" (2026-08-08)

**Tema da versão**: os dois temas originais (Escuro/Claro) viraram sete. O usuário achou os dois
atuais feios de verdade e pediu variações mais atraentes — azul escuro, rosa, vermelho, verde,
bege. As paletas foram desenhadas e aprovadas num mockup HTML fora do PureBasic antes de virar
código de verdade (iterar cor em CSS é muito mais rápido que recompilar o app a cada ajuste).

### Novidades

- **7 temas** em **Configurar → Editor...**: **Grafite** e **Neve** (revisão dos dois atuais —
  mais equilibrados, sem preto/branco puro) e cinco novos — **Azul Profundo** (clima Night Owl/
  Nord), **Rosé** (Rosé Pine), **Carmesim** (oxblood/vinho), **Floresta** (Everforest) e **Bege**
  (Solarized Light). Cada um define as ~24 cores nomeadas da área de edição, abas, régua e
  destaque de sintaxe (`ApplyTheme()`, `BadigEditor.pb`) num pacote coerente só.
- `EditorCfg\Theme` deixou de ser um booleano Dark/Light e virou um dos 7 IDs (`Graphite`/`Snow`/
  `Navy`/`Rose`/`Crimson`/`Forest`/`Paper`) — `editor_settings.json` de instalações antigas com
  `"Dark"`/`"Light"` migra sozinho pra `Graphite`/`Snow` no primeiro carregamento, sem resetar a
  preferência do usuário.

### Bugs corrigidos nesta versão

- Nenhum — troca de mecanismo de tema, sem correção de regressão conhecida.

### Documentação nova

- `docs/MANUAL.md` ganhou a seção **Temas** (tabela com as 7 opções e o que muda/não muda de
  verdade em cada uma).

### Bastidores

- **O que NÃO entrou nesta rodada**: os 7 temas valem só pra área do editor + Editor Hexa (os
  únicos dois já ligados ao `ApplyTheme()`). As demais janelas (SEE Tracker, editores de
  Alfabeto/Sprite/Som/Telas, disco, todas as telas de Configurar) usam cores próprias fixas e
  controles nativos do Windows (botões/combos não são temáveis de jeito nenhum, é chrome do SO) —
  auditado ao vivo no código antes de prometer algo: `SeeTrackerEditorGui.pbi` tem 22 botões
  nativos contra só 4 áreas desenhadas à mão, `CharsetEditorGui.pbi` é parecido. Estender tema pra
  essas janelas é um projeto à parte, arquivo por arquivo — cada cor hardcoded precisa ser
  separada em "chrome" (segue o tema) vs. "conteúdo" (ex.: a paleta MSX real mostrada no editor de
  alfabeto/sprite não pode virar rosa só porque o tema é Rosé, senão a ferramenta mentiria sobre a
  cor de verdade do hardware). Fica como próximo passo, uma janela de cada vez, se o usuário
  quiser seguir.
- **Por que migrar `"Dark"`/`"Light"` em vez de só aceitar os dois como sinônimos permanentes**:
  mais simples normalizar uma vez no carregamento (`EditorCfg_Load()`) do que espalhar `Case
  "Dark", "Graphite"` em todo lugar que olha `EditorCfg\Theme` — `ApplyTheme()` só precisa
  conhecer os 7 IDs canônicos.

---

## 7.31.1 — "ATALHO DE TUDO" (2026-08-08)

**Tema da versão**: continuação da mesma sessão de `7.31.0` — depois de tirar o modo WordStar/JOE,
o usuário pediu atalhos de teclado pro resto da IDE (novo projeto, caractere especial, openMSX,
editor hexa, editores gráficos/sprites/som/tracker...) pra não ficar tão preso navegando menu.

### Novidades

- **22 atalhos novos** cobrindo praticamente toda a IDE, seguindo convenções de editor moderno onde
  fazia sentido e reaproveitando teclas já livres onde não havia convenção óbvia:
  - **Projeto**: `Ctrl+Alt+N` novo projeto, `Ctrl+Alt+O` abrir projeto.
  - **Inserir/Configurar**: `Ctrl+Alt+I` caractere especial, `Ctrl+Alt+E` Configurar → Editor...
  - **Executar**: `Shift+F5` Nestor Basic, `F6` renumerar, `Ctrl+Shift+F5` montar relocável,
    `Ctrl+Alt+F5` linkar, `F7` Editor Hexa, `F8` console openMSX, `F9`/`Shift+F9` ver MD/TXT.
  - **Criar (editores visuais)**: `Ctrl+Shift+D` disco, `Ctrl+Shift+P` sprite, `Ctrl+Shift+A`
    alfabeto Graphos III, `Ctrl+Shift+G` som PSG, `Ctrl+Shift+T` SEE Tracker, `Ctrl+Shift+M`
    música, `Ctrl+Shift+2`/`0`/`1` Draw Screen 2/Screen 0/Screen 1.
  - **Ajuda**: `F1` abre `Ajuda → Editor...` — convenção universal de "ajuda", além do menu.
- **Menu Editar novo** (adicionado já em `7.31.0`) segue documentado e sem mudanças aqui.
- **`Ajuda → Editor...`** (`F1`) ganhou as seções novas (Executar, Criar, Inserir/Configurar/Ajuda)
  na referência de atalhos, e a janela cresceu (`680×760`) pra caber o conteúdo sem espremer.

### Bugs corrigidos nesta versão

- Nenhum.

### Documentação nova

- `docs/MANUAL.md`: seções **Executar**, **Criar (editores visuais)** e **Outros atalhos** novas
  dentro de "O editor de texto"; nota de atalho adicionada em cada seção de editor visual
  individual (sprites, alfabetos, som, SEE Tracker, música, Screen 0/1/2) e nos menus Novo
  projeto/Abrir projeto, Caractere Especial e Configurar → Editor.

### Bastidores

- **Por que nem todo item de "Criar" ganhou tecla**: Alfabeto Aquarela, Graphos III Screen 2,
  Screen 1+2, Biblioteca Z80 e Assembly Sub Project são variantes menos usadas dos editores que já
  ganharam atalho — precisariam de um terceiro ou quarto modificador pra não colidir com nada, o que
  deixaria de ser um atalho rápido pra virar mais um exercício de memorização. Ficaram só no menu.
- **Por que `Ctrl+Alt+` para projeto/inserir/configurar em vez de mnemônicos diretos**: `Ctrl+N`/
  `Ctrl+O`/`Ctrl+S` já estavam ocupados pelas ações de arquivo (mais comuns) desde `7.31.0`; `Ctrl+Alt+`
  ficou reservado como o "segundo andar" dessas mesmas letras para as ações de projeto equivalentes,
  em vez de inventar letras sem relação.

---

## 7.31.0 — "APOSENTADORIA" (2026-08-08)

**Tema da versão**: aposentadoria do teclado estilo WordStar/JOE. O usuário nunca tinha se apegado
tanto ao modo assim no dia a dia (usa Helix/JetBrains/VSCode/Sublime/010 Editor no resto do tempo) e
pediu pra voltar ao padrão Scintilla/Windows — setas, `Ctrl+C/V/X/Z/Y`, `Home`/`End` etc. — sem nenhum
modo de teclado próprio por cima.

### Novidades

- **Teclado do editor agora é o padrão Scintilla/Windows**, sem nenhuma interceptação por cima — o
  antigo modo WordStar/JOE (`editor/WordStarKeys.pbi`: subclass de HWND, comandos de duas teclas
  `Ctrl+K x`/`Ctrl+Q x`, bloco marcado com destaque persistente) foi removido por completo.
- **Buscar/Substituir/Ir para linha** ganharam atalhos padrão — `Ctrl+F` (buscar), `F3` (buscar
  próxima), `Ctrl+H` (substituir, tudo de uma vez ou confirmando ocorrência por ocorrência) e `Ctrl+G`
  (ir para linha) — também no novo menu **Editar**. A lógica de busca já existia (portátil, só fala
  com o Scintilla) e foi só desacoplada do antigo mecanismo de teclas duplas.
- **Atalhos de arquivo voltaram ao convencional**: `Ctrl+N` novo, `Ctrl+S` salva (antes `Ctrl+S` movia
  o cursor e salvar era `Ctrl+K D`), `Ctrl+W` fecha aba.
- **`Ajuda → Editor...`** troca a antiga tela cheia (`Ctrl+K H`, ocupava o lugar do editor, fechava
  com qualquer tecla) por uma janela normal com a referência completa dos atalhos, no mesmo estilo
  visual das outras telas de Ajuda.
- **Bloco marcado com destaque persistente foi removido** — seleção normal (mouse ou `Shift`+setas) +
  `Ctrl+C`/`Ctrl+X`/`Ctrl+V` cobre o mesmo caso de uso com o padrão que todo editor moderno já usa.
  Reformatar parágrafo (`Ctrl+B` no modo antigo) e salvar bloco marcado direto num arquivo (`Ctrl+K W`)
  não têm substituto — não estavam em uso real e ficaram de fora desta rodada.

### Bugs corrigidos nesta versão

- Nenhum — troca de mecanismo de teclado, sem correção de regressão conhecida.

### Documentação nova

- `docs/MANUAL.md`: seção "O editor de texto" reescrita (atalhos padrão, Buscar/Substituir/Ir para
  linha, `Ajuda → Editor...`); `CLAUDE.md` e `README.md` perderam as referências ao arquivo removido.

### Bastidores

- **Por que remover em vez de só desligar por padrão**: o usuário deixou claro que quer esquecer o
  WordStar/JOE de vez, não só desativar — então o código morto (subclass Win32, tela de ajuda em tela
  cheia, bloco marcado) saiu do repositório, não ficou guardado atrás de uma flag.
- **Por que Buscar/Substituir/Ir para linha sobreviveram**: essas três eram a única funcionalidade real
  do modo antigo sem equivalente automático no Scintilla puro (diferente de copiar/colar/desfazer, que
  já vêm de graça do keymap padrão) — descartá-las teria sido uma regressão de verdade, não só uma
  mudança de tecla.

---

## 7.29.5 — "PALPITEIRO" (2026-08-08)

**Tema da versão**: o editor aprendeu a "dar palpite" — auto completar de verdade, tanto em BASIC/
Basic Dignified quanto em Assembly, mais um jeito de salvar tudo de uma vez sem precisar passar aba por
aba.

### Novidades

- **Auto completar em abas `.dmx`/`.bas`** — sugere palavras-chave clássicas do MSX-BASIC, instruções
  do Basic Dignified, comandos MSXBAS2ROM (quando aplicável) e variáveis já usadas no documento
  (coletadas ao vivo do texto, sem precisar de `DECLARE`), assim que a palavra digitada atinge um
  mínimo configurável de letras. Nova tela **`Configurar → Basic Options...`** (habilitar, mínimo de
  letras, caixa das sugestões).
- **Os 87 wrappers `.NB_*` do NestorBASIC** entraram na lista de sugestões — fonte única com
  `Ajuda → NestorBASIC...`, nunca diverge dela. Basta digitar a partir da letra depois do `.`
  (`.NB_Rea` já sugere).
- **Auto completar em abas Assembly (`.asm`)** — mnemônicos, registradores/condições e diretivas do
  Z80 (incluindo as com ponto do dialeto N80), mais rótulos já definidos no documento, pela mesma
  regra clássica MACRO-80/Z80 que o destaque de sintaxe já usa. Nova tela própria
  **`Configurar → Assembly...`**, independente da tela de BASIC (cada modo guarda sua própria caixa).
- **Caixa das sugestões configurável** — "Como digitado" (`pri` sugere `print`, `PRI` sugere `PRINT`),
  sempre maiúsculas ou sempre minúsculas. Variáveis, rótulos e nomes `.NB_*` sempre mantêm a grafia
  original do documento, nunca reformatados.
- **Navegação 100% nativa do Scintilla** — Enter/Tab aceitam a opção destacada, setas navegam, Esc
  cancela, digitar mais estreita a lista sozinha. Nenhuma tecla nova foi interceptada; sem conflito com
  o teclado WordStar/JOE (que só usa combinações com Ctrl).
- **Arquivo → Salvar Tudo** (`Ctrl+Alt+S`) — salva todas as abas abertas (na ordem, pedindo "Salvar
  como..." só pras que ainda não têm nome, sem travar as demais se uma for cancelada) e o projeto atual
  numa ação só. Só grava o projeto se ele já tiver arquivo permanente ou se o projeto temporário tiver
  conteúdo de verdade — não força um diálogo "Salvar projeto como..." vazio à toa.

### Bugs corrigidos nesta versão

- Nenhum — versão inteira de recursos novos, sem correção de regressão conhecida.

### Documentação nova

- `docs/MANUAL.md` ganhou a seção **Auto completar** (nova, com tabela de navegação e o que é sugerido
  em cada modo) e a entrada de **Salvar Tudo** na seção Arquivo; `docs/SPEC.md` ganhou os módulos **25**
  (Auto completar) e **1b** (Salvar Tudo); `README.md` atualizado (versão, feature list, changelog).

### Bastidores

- **Por que um campo de configuração em vez de detectar a caixa predominante do documento**: o usuário
  perguntou diretamente se dava pra "ver estatisticamente" se a maioria dos comandos já digitados
  estava em maiúsculo ou minúsculo. A alternativa de detecção estatística foi descartada — precisaria
  reescanear o documento inteiro a cada sugestão (custo), e o resultado dependeria do histórico inteiro
  do arquivo em vez da última coisa digitada (menos previsível). "Como digitado" resolve o caso comum
  sem nenhum dos dois problemas.
- **Por que os mapas de palavra-chave do Z80 não estavam acessíveis de fora do módulo**: `Z80Asm.pbi`
  usa `DeclareModule`/`Module` de verdade (não só prefixo de nome, ver módulo 2 do `SPEC.md`) — os
  `Global NewMap KwMnemonic()` etc. são declarados dentro do `Module`, não do `DeclareModule`, então
  ficam privados por escopo do PureBasic. Resolvido com 4 novos procedimentos exportados
  (`MnemonicList()`/`RegisterList()`/`DirectiveList()`/`OperatorWordList()`) que devolvem o vocabulário
  como string espaço-separada — mesmo formato que `FillKeywordMap()` já consome do lado de fora,
  nenhuma abstração nova precisou ser inventada.
- **Por que o "." do `.NB_*`/rótulos relativos não precisou de tratamento especial**: o conjunto de
  "caracteres de palavra" que o Scintilla usa pra decidir onde uma palavra começa não inclui `.` — a
  fronteira de palavra já para exatamente depois do ponto sozinha, então guardar os nomes sem o `.` no
  mapa de candidatos e deixar o Scintilla substituir só a partir dali já produz o resultado certo, sem
  nenhum código extra pra detectar/preservar o `.` manualmente.
- Codinome **"PALPITEIRO"** — gíria brasileira pra quem "dá palpite" sem ser convidado, exatamente o
  que um motor de auto completar faz por natureza (torcendo pra acertar na maioria das vezes).

### Ainda pendente

- `CollectDocumentVariables()`/`CollectZ80Labels()` são varreduras leves (não um tokenizador completo)
  — não distinguem com precisão texto dentro de comentário/string do resto do código. Na prática, pouco
  ruído real (nomes de variável/rótulo plausíveis raramente aparecem por acaso dentro de comentários ou
  literais de string), mas é uma limitação conhecida, não testada exaustivamente contra casos extremos.
- Sem harness de teste automatizado dedicado (`editor/tools/*Cli.pb`) para essa frente — validado só
  por compilação limpa e smoke test de abertura do `.exe`; teste de interação real (digitar, ver o
  popup, navegar, aceitar uma sugestão) não foi automatizado neste ambiente (sem GUI automation nativa
  Win32 disponível, só a de browser) — recomendado testar manualmente antes de confiar às cegas.

---

## 7.27.3 — "TORRE DE CONTROLE" (2026-08-08)

**Tema da versão**: o controle remoto do openMSX deixou de ser um console de comando avulso e virou um
painel de bordo completo — 6 abas cobrindo praticamente tudo que o Catapult original oferecia (e
algumas coisas que ele não oferece mais). **Executar → BASIC** (F5) também parou de abrir uma janela
nova do openMSX a cada execução: agora reaproveita a instância já aberta, trocando só o disco e dando
reset, como trocar o disquete de um MSX de verdade.

### Novidades

- **`Configurar → openMSX...`** (`editor/OpenMsxSettingsGui.pbi`, novo arquivo) — tela própria só com
  os campos do emulador (executável, máquina, extensão), lendo/gravando exatamente os mesmos campos
  que a aba "Emulador" de `Configurar → Basic Dignified...` já usava (mesma struct `BadigCfg`, mesmo
  `badig_settings.json`) — as duas telas nunca divergem, por construção, não por sincronização.
- **`Executar → BASIC` (F5) reaproveita a instância aberta do openMSX** em vez de abrir uma nova a cada
  run (`OMSX_LoadDisk()`, `editor/OpenMSXBridge.pbi`) — só troca o disco da unidade A e reinicia.
- **`Executar → openMSX...` virou um painel de 6 abas** (`editor/OpenMSXConsoleGui.pbi`):
  - **Console** — mídia (disco/cartucho/cassete, inserir/ejetar), botão "Transferir programa atual"
    (mesmo caminho do F5), log de comandos, campo de comando livre.
  - **Outros comandos** — velocidade (barra + 100% + Turbo segurando o mouse, acelera ao máximo e
    volta a 100% ao soltar), Power/Reset/Pause, interruptor de firmware residente, conectores das
    portas Joystick 1/2 (Nada/Mouse/Teclado como joystick P1/P2/Paddle), Ren Sha Turbo.
  - **Vídeo** — renderer, escala (2/3/4), VSync, Modo TV (dropdown com as 5 opções reais do openMSX —
    simple/ScaleNx/hq/RGBtriplet/TV, como no Catapult), deinterlace/limitar sprites/tela cheia/
    desabilitar sprites, fonte de vídeo (MSX/GFX9000/Video9000), efeitos estilo CRT (scanline/blur/
    glow/gamma/noise — barra + valor + reset pro padrão de fábrica), screenshot (nome base + diretório
    opcional + numeração sequencial automática), LEDs visuais (Power/Caps/Kana/Pause/Turbo/FDD) +
    botão STOP (tecla física do teclado MSX) + FPS ao vivo.
  - **Volume** — mixer do openMSX com **descoberta dinâmica de dispositivo de som**: como o nome real
    de cada chip varia por cartucho/ROM conectado (confirmado ao vivo: coisas como
    `"Konami SCC+ Cartridge with expanded RAM (1)"`, não um nome fixo tipo "SCC+"), a lista aparece
    sozinha conforme o openMSX avisa que algo mudou, ou você adiciona manualmente digitando o nome.
    Volume + Balance (substitui o antigo esquema Mute/Left/Right/? do Catapult, removido do openMSX
    atual em favor de um balanço contínuo -100..100). MIDI in (arquivo `.mid`) e MIDI out (log em
    arquivo), conectores também descobertos dinamicamente.
  - **Input Text** — área grande dedicada pra colar/digitar texto + botões **Type**/**Clear** (mesmo
    mecanismo do Catapult: digita no MSX como se fosse teclado de verdade).
  - **Status Info** — log passivo de tudo que o openMSX reporta (mudou por comando nosso ou não),
    separado do log interativo da aba Console.

### Bugs corrigidos nesta versão

- LEDs Caps/Kana/Turbo/FDD nunca atualizavam — o nome real do setting é `led_caps`/`led_kana`/
  `led_turbo`/`led_fdd` (prefixo `led_`), não o nome simples usado na primeira tentativa. Só achado
  testando ao vivo contra um openMSX de verdade.
- Documentação "resumida" do openMSX errava os valores padrão de vários efeitos de vídeo (dizia
  scanline=0/blur=0/gamma=1.0); os valores reais, conferidos direto no código-fonte
  (`RenderSettings.cc`), são scanline=20/blur=50/gamma=1.1 — usados agora nos botões "Reset".

### Documentação nova

- `docs/RELEASE_NOTES.md` (este arquivo).
- `docs/MANUAL.md`, seção "Controle remoto do openMSX" reescrita do zero pra descrever as 6 abas e o
  novo comportamento do F5 (a nota antiga dizia explicitamente que F5 e o console eram sessões
  separadas — não é mais verdade).
- `README.md` atualizado com a nova tela de configuração e o painel de controle expandido.

### Bastidores

- **Nomes de dispositivo de som e conector MIDI não são fixos** — variam por ROM/cartucho/quantidade
  de instâncias (ex. `"Sunrise MoonSound (1) FM"`, `"Generic MSX-Audio-MIDI-in"`). Confirmado ao vivo
  antes de implementar a aba Volume, o que mudou o design de "sliders fixos por nome" pra "lista
  dinâmica descoberta em runtime" — evita uma aba que simplesmente não funciona assim que o usuário
  troca de cartucho.
- Consulta de FPS (`openmsx_info fps`) e a lista de conectores (`plug` sem argumentos) usam o mesmo
  protocolo "fire and forget" de sempre (`OpenMSXBridge.pbi`), com uma correlação simples de "a próxima
  resposta que chegar é a desta consulta" — não há id de correlação real no protocolo do openMSX,
  então isso assume que nada mais está sendo mandado bem no meio (mesma suposição que o resto da ponte
  já fazia implicitamente).
- Durante a investigação ao vivo, o openMSX caiu duas vezes ao empilhar extensões de som conflitantes
  manualmente (`ext moonsound` + `ext audio` juntos, fora do fluxo normal) — não parece ligado ao
  código novo (testes subsequentes, mais conservadores, rodaram sem problema), mas fica registrado
  caso apareça de novo em uso normal.

### Ainda pendente

- **Balance** de um dispositivo adicionado manualmente na aba Volume só aparece com valor real depois
  de mudado pelo menos uma vez — o botão "Adicionar" só consulta Volume ativamente.
- Fluxo de conectar/desconectar MIDI in/out não foi testado ao vivo de ponta a ponta (evitado depois
  das quedas do openMSX durante a investigação de nomes).
- Não existe (ou não foi encontrado) um comando do openMSX que liste todos os dispositivos de som de
  uma vez — a descoberta depende de mudança de estado ou de adição manual, nunca de enumeração
  completa automática.
- Máquinas com mais de uma instância MSX simultânea (visto ao vivo: uma configuração de teste chegou a
  subir "machine1" e "machine2" ao mesmo tempo) não são distinguidas — o rastreio de estado é "cego a
  máquina", mistura updates de qualquer instância que exista.

---

## 7.25.0 — "HEXORCIST" (2026-08-07)

**Tema da versão**: o Editor Hexa (`Executar → Editor Hexa...`) aprendeu a reconhecer sete formatos de
arquivo novos — da era MSX/CP-M — além dos três nativos desta IDE que já reconhecia. Praticamente
qualquer disquete antigo de MSX que passar por aqui agora sai com nome e sobrenome em vez de cair em
"binário desconhecido/dados crus".

### Novidades

- **Executável MSX-DOS (`.COM`)** — reconhecido por extensão (código Z80 cru, sem cabeçalho, convenção
  CP/M, carrega e executa sempre em `0100h`).
- **Texto ASCII puro vs. BASIC MSX clássico (linhas numeradas)** — o antigo rótulo genérico "BASIC
  clássico ou fonte" virou dois rótulos diferentes, decidido pelo primeiro caractere visível do arquivo.
- **Planilha SuperCalc 2 MSX (`.CAL`)** — assinatura, título e onde a seção de dados começa. Validado
  contra 6 planilhas `.CAL` reais; o layout célula a célula ainda não foi decifrado (ver
  `docs/reference/supercalc2-cal-format.md` para o que falta e como continuar).
- **Banco de dados dBase II (`.DBF`)** — formato **totalmente decifrado**: cabeçalho, descritores de
  campo e os próprios registros de dados, validados registro a registro contra um `.DBF` real (ver
  `docs/reference/dbase2-dbf-format.md`).
- **Os 4 formatos nativos do Graphos III**, validados em lote contra praticamente todo o acervo real
  deste repositório (~4100 arquivos entre `graphos/` e `graphos-IV/`, não uma amostra pequena):
  - **Alfabeto (`.ALF`)** — 759/781 (97%)
  - **Layout (`.LAY`)** — 234/234 (100%) — decodifica o RLE+ofuscação de verdade, não só olha o cabeçalho
  - **Tela (`.SCR`)** — 86/86 (100%)
  - **Banco de shapes (`.SHP`)** — 2920/3028 (96%) — o ganho mais significativo: esse formato não tinha
    **nenhum** reconhecimento antes (não tem cabeçalho BLOAD/BSAVE)

### Bugs corrigidos nesta versão

- Decodificador do `.LAY` parava cedo demais quando sobrava padding no fim do stream comprimido
  (confiava no tamanho declarado pelo cabeçalho em vez de parar assim que os 6144 bytes esperados fossem
  decodificados).

### Documentação nova

- `docs/reference/supercalc2-cal-format.md` — notas de engenharia reversa do formato `.CAL`.
- `docs/reference/dbase2-dbf-format.md` — spec completa do formato `.DBF` (dBase II).
- `docs/MANUAL.md` e `README.md` atualizados com a lista completa de formatos reconhecidos pelo Editor
  Hexa.
- `docs/SPEC.md`, módulo 17, ganhou uma tabela única consolidando todos os formatos reconhecidos hoje e
  o nível de confiança de cada validação, em vez de só parágrafos cronológicos.

### Bastidores

- `sc2/` (projeto Go pessoal do usuário que ajudou a decifrar o `.CAL`, mais os discos originais do
  SuperCalc 2 MSX) entrou no `.gitignore` — contém software de terceiros, mesmo tratamento já dado a
  `see/`.
- O par binário/texto `EXEMPLO.CAL`/`EXEMPLO.SDI`, achado dentro de um disco original do SuperCalc 2, foi
  o que destravou o estudo do `.CAL` sem precisar rodar o `SDI.COM` original num emulador.
- `PESSOAL.DBF`, achado no mesmo lote de arquivos, foi decifrado por completo cruzando os bytes contra o
  próprio conteúdo legível do arquivo (nomes/cargos/salários reais).

### Ainda pendente

- **WordStar** e **MSX-Word** — sem arquivo de amostra real suficiente pra validar um reconhecimento
  seguro ainda (WordStar em particular não tem cabeçalho fixo, só liga o 8º bit no fim de cada palavra —
  arriscado demais adivinhar sem arquivo real).

---

## 7.7.1 — "BFG9200" (2026-07-29)

Editor Hexa genérico (`editor/HexEditorGui.pbi`) lançado: abre qualquer arquivo do disco, grade
offset/hex/ASCII, edição byte a byte, reconhecimento automático dos três formatos nativos desta IDE
(binário MSX BLOAD/BSAVE, MSX-BASIC tokenizado, boot sector FAT12 de imagem `.dsk`), galeria de
templates persistida em JSON (semeada com os três formatos nativos do Graphos III — Alfabeto/Layout/
Tela) e operações de bloco (preencher/inserir/sobrepor/excluir). Codinome: BFG9000 (a arma mais brutal
de Doom) cruzado com `9200h`, o endereço de VRAM que assinava os três formatos do Graphos III na galeria
de templates dessa versão. Ver `docs/SPEC.md`, módulo 17, para o detalhe completo.
