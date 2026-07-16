# MSX BASIC + Z80 IDE

![Editor com destaque de sintaxe para o dialeto Basic Dignified](images/msxbasica-01.png)

**Versão atual: 5.3.1** — versão e build (data/hora UTC de compilação, em hexadecimal) são embutidas
no executável pelo `build.ps1` e exibidas em `Ajuda → Sobre...`.

IDE nativa em **PureBasic** para desenvolvimento em MSX BASIC (dialeto "Dignified", sem números de
linha) e Z80 assembly, construída em torno de um editor com highlighting via Scintilla e um
pré-processador/tokenizador reescritos nativamente — sem depender de Python instalado na máquina do
usuário final.

> Documento vivo. O detalhe completo da especificação (escopo, decisões de arquitetura, módulos
> planejados) está em [`docs/SPEC.md`](docs/SPEC.md) — é a fonte de verdade do projeto. Para
> compilar, executar e usar o editor de texto (atalhos estilo WordStar/JOE), veja
> [`docs/MANUAL.md`](docs/MANUAL.md).

## Sobre o projeto

O ponto de partida foi um editor de texto simples para MSX BASIC. A ideia é fazer ele crescer até
virar uma IDE completa cobrindo todo o fluxo de desenvolvimento para MSX: BASIC + assembly Z80 +
assets gráficos/sonoros + build + debug direto no emulador, tudo num único executável PureBasic
autocontido (Windows/Linux), sem exigir Python nem outras dependências externas em tempo de execução.

O dialeto de entrada é o **Basic Dignified** (labels em vez de números de linha, includes, macros,
proto-funções, etc.), inspirado e compatível com o [Basic Dignified Suite](#agradecimentos) original em
Python — que serve de referência de comportamento a ser portada, não de dependência de runtime.

## O que já temos

- **Editor** (`editor/BadigEditor.pb`) — `ScintillaGadget` com lexer próprio para o dialeto Dignified
  e outro para **Z80 Assembly** (`.asm`, dialeto do assembler
  [N80/Nestor80](https://github.com/Konamiman/Nestor80)), abas customizadas (fechar, hover, arrastar
  visual), régua de colunas, margem de números de linha dinâmica, tema claro/escuro e estilo de abas
  moderno/clássico configuráveis. Menu **Arquivo → Novo** (`.dmx`) e **Novo Assembly** (`.asm`,
  `Ctrl+Shift+N`) — cada aba detecta e lembra seu próprio tipo.
- **Pré-processador Dignified nativo** (`editor/DignifiedPreprocessor.pbi`) — **cobre 100% do escopo
  do `badig.py` original**: labels, loop labels, `EXIT`, `DEFINE` recursivo, `DECLARE` com redução
  automática de nomes longos, comentários/blocos de comentário, `TRUE`/`FALSE`, operadores compostos,
  proto-funções `FUNC`/`RET`, conversão `?`/`PRINT`, strip `THEN`/`GOTO`, tradução Unicode→charset
  nativo MSX, maiusculização, tamanho de TAB configurável, **`INCLUDE` recursivo** (namespace de
  label/loop/função isolado por arquivo, variáveis compartilhadas) e **remtags**
  (`##BB:arguments=`/`export_file=`/`help=`). Testado de ponta a ponta contra código de produção real
  (não só exemplos sintéticos — ver [`sample/teste.dmx`](sample/teste.dmx), ~900 linhas) e contra
  fixtures de `INCLUDE`/remtags. O `.exe` do editor não depende mais de Python em nenhum fluxo (menus
  legados removidos).
- **Tokenizador MSX-BASIC nativo** (`editor/MsxTokenizer.pbi`) — converte ASCII clássico em binário
  `.bmx`, validado byte a byte contra o tokenizador Python original.
- **Rodar no openMSX** (`RunOnOpenMSX()` em `editor/BadigEditor.pb`) — com a opção "Abrir o openMSX e
  rodar o código após gerar" marcada, tokenizar monta um disquete `.dsk` (`.dmx`+`.amx`+`.bmx` mais um
  `AUTOEXEC.BAS` de autorun) e abre o openMSX já rodando o programa, com a máquina/extensão
  configuradas. Rotinas de disco `.dsk` (FAT12) vendorizadas de `msxDiskUtil/MSXDisk.pbi` — compiladas
  direto no executável do editor, sem depender de processo externo para montar o disco.
- **Telas de configuração nativas**:
  - `Configurar → Basic Dignified...` (`editor/BadigSettings.pbi`) — três abas: pré-processador/
    tokenizador, opções específicas do MSX, e **Emulador** (caminho do openMSX, máquina/extensão com
    botão de busca automática em `share/machines`/`share/extensions`, opção de rodar após gerar).
    Diretório de instalação do toolchain com botão para baixar o Basic Dignified Suite direto do
    GitHub (`git clone` ou `.zip`), tudo persistido em JSON.
  - `Configurar → Editor...` (`editor/EditorSettings.pbi`) — fonte (só monoespaçadas, com suporte a
    pasta de fontes customizadas carregadas em memória), tema, estilo de abas, caminho de instalação do
    editor.
- **CLI de teste de regressão** (`editor/tools/DigTestCli.pb`) — roda o pipeline completo
  (Dignified → ASCII → tokenizado) fora do editor, para validar mudanças no pré-processador/tokenizador.

Ainda não implementado (ver [Lacunas conhecidas](docs/SPEC.md#lacunas-conhecidas-a-preencher-em-conversas-futuras)
e [Próximos passos](docs/SPEC.md#próximos-passos-em-aberto) em `docs/SPEC.md`): motor do assembler Z80
em si (o editor já edita `.asm` com syntax highlight, mas não monta nada ainda), editores visuais
(sprite/char, LINE/CIRCLE/DRAW, som, tracker, MML/`PLAY`), extensão NestorBASIC, saída via
`msxbas2rom`, controle do openMSX via socket/XML em tempo real (input simulado, detecção de erro com
retorno à linha no editor — hoje só "gerar disco e abrir o openMSX" está pronto, sem comunicação de
volta da emulação para a IDE).

## Changelog resumido

- **2026-07-13** — Projeto criado; editor base migrado para repositório git com `badig/` como
  submódulo. Pré-processador Dignified e tokenizador MSX-BASIC nativos escritos em PureBasic
  (`DignifiedPreprocessor.pbi`, `MsxTokenizer.pbi`), incluindo proto-funções `FUNC`/`RET`. Primeira
  tela de configuração nativa (`BadigSettings.pbi`). Documentação de referência completa extraída do
  código-fonte Python original em `docs/reference/`.
- **2026-07-14** — Corrigido bug de charset que truncava a saída `.bmx` com caracteres especiais
  (box-drawing, acentos, gregas) em strings. Reforma visual do editor: abas customizadas em formato
  "chip", régua de colunas, tema escuro. Pré-processador nativo ganhou conversão `?`/`PRINT`, strip
  `THEN`/`GOTO`, tradução Unicode→MSX e maiusculização — agora lendo a configuração da tela de opções
  em vez de usar valores fixos.
- **2026-07-15** — Nova tela `Configurar → Editor...` (fonte, tema claro/escuro, estilo de abas,
  fontes customizadas, caminho de instalação). Diretório de instalação do Basic Dignified Suite
  configurável, com botão para baixar o toolchain direto do GitHub (`git clone` ou `.zip`). Botão de
  download de fontes Nerd Fonts direto de `nerdfonts.com` (lista ao vivo, seleção individual ou em
  lote). Script `build.ps1` para compilar via `pbcompiler.exe` (caminho configurável com `-C`/
  `--compiler`, `-R`/`--run` para executar após compilar, `-H`/`--help` para a lista de opções),
  embutindo versão (`5.1.3`) e build (data/hora UTC da compilação em hex) no executável, exibidas em
  `Ajuda → Sobre...`. Editor ganhou teclado estilo WordStar/JOE
  (`WordStarKeys.pbi` — movimento do cursor, apagar texto, bloco marcado com destaque persistente,
  salvar/abrir/fechar, desfazer/refazer; `Ctrl+S` deixou de ser "salvar" e virou "cursor para a
  esquerda", como no WordStar de verdade). Tela de ajuda embutida (`Ctrl+K H`, fecha com qualquer
  tecla) e barra de status no rodapé (modo/prefixo de comando pendente, nome do arquivo, linha e
  coluna). Novo `docs/MANUAL.md` com o guia de uso da IDE. Mais tarde no mesmo dia: `INCLUDE`
  recursivo e remtags (`##BB:...`) implementados no pré-processador nativo, fechando 100% do escopo
  do `badig.py` original — os menus e o código do caminho Python (`SaveTokenized()`,
  `BadigCfg_BuildCliArgs()`) foram removidos, o `.exe` do editor não invoca mais Python em nenhum
  fluxo.
- **2026-07-16** — Botões de busca de máquina/extensão do openMSX (aba "Emulador", listam
  `share/machines`/`share/extensions` a partir do caminho do executável configurado). Opção "Abrir o
  openMSX e rodar o código após gerar" ganhou implementação real: monta um disquete `.dsk` com o
  programa gerado mais um `AUTOEXEC.BAS` de autorun e abre o openMSX direto nele (rotinas de disco
  vendorizadas de `msxDiskUtil/MSXDisk.pbi`, compiladas no próprio executável). Menu **Arquivo → Novo
  Assembly** (`Ctrl+Shift+N`) cria abas `.asm` com syntax highlight do dialeto
  [N80/Nestor80](https://github.com/Konamiman/Nestor80) (mnemônicos, registradores, diretivas,
  literais numéricos em qualquer radix). Versão embutida no executável atualizada para `5.3.1`.

## Ferramentas e ambiente

Projeto desenvolvido com:

- **[PureBasic](https://www.purebasic.com/) 6.4** — linguagem/compilador da IDE (Windows e Linux).
- **Windows** e **Ubuntu** — desenvolvido e testado nos dois sistemas.
- **PowerShell** — automação, build e scripts no ambiente Windows.
- **[Helix](https://helix-editor.com/)** — editor de texto modal usado no dia a dia de edição de
  código.
- **[Claude](https://claude.com/claude-code)** (Anthropic) — par de programação via Claude Code,
  usado para boa parte da implementação, revisão e documentação do projeto.
- **[GitHub](https://github.com/)** — versionamento e hospedagem do repositório.

## Agradecimentos

Este projeto não existiria sem o trabalho de:

- **[Fred Rique (farique1)](https://github.com/farique1)**, autor do
  [**Basic Dignified Suite**](https://github.com/farique1/basic-dignified) — o dialeto Dignified, o
  motor de pré-processamento e o tokenizador MSX-BASIC originais (em Python) foram a especificação de
  comportamento e a maior fonte de inspiração para tudo que foi reescrito nativamente aqui. O código de
  teste de regressão do projeto (`sample/teste.dmx`, "Change Graph Kit") também é obra dele.
- **[Amaury Carvalho](https://github.com/amaurycarvalho)**, autor do
  [**msxbas2rom**](https://github.com/amaurycarvalho/msxbas2rom) — compilador MSX BASIC → ROM que
  inspira o back-end de geração de ROM planejado para esta IDE.

## Licença

[GNU GPL v3](LICENSE).
