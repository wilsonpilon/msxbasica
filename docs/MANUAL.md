# Manual da IDE — MSX BASIC + Z80

> Manual de uso da ferramenta em si (compilar, executar, editor de texto, telas de
> configuração). Para a linguagem **Basic Dignified** (o que você escreve dentro do
> editor), veja [`BADIG-USER.md`](BADIG-USER.md), [`DIGNIFIER-USER.md`](DIGNIFIER-USER.md)
> e [`BATOKEN-USER.md`](BATOKEN-USER.md). Para a especificação/arquitetura do projeto,
> veja [`SPEC.md`](SPEC.md).
>
> Documento vivo — cresce conforme novas partes da IDE (assembler Z80, editores visuais,
> etc.) forem ficando prontas. Hoje cobre o editor de texto e o processo de build.

---

## Índice

1. [Compilação](#compilação)
2. [Execução](#execução)
3. [O editor de texto](#o-editor-de-texto)
   - [Teclado estilo WordStar/JOE](#teclado-estilo-wordstarjoe)
   - [Movimento do cursor](#movimento-do-cursor)
   - [Apagar texto](#apagar-texto)
   - [Bloco marcado (selecionar/copiar/mover/apagar)](#bloco-marcado-selecionarcopiarmoverapagar)
   - [Arquivo](#arquivo)
   - [Desfazer / refazer](#desfazer--refazer)
   - [Ajuda embutida (Ctrl+K H)](#ajuda-embutida-ctrlk-h)
   - [Barra de status](#barra-de-status)
   - [O que ainda não está implementado](#o-que-ainda-não-está-implementado)
4. [Telas de configuração](#telas-de-configuração)
5. [Gerenciador de disco MSX](#gerenciador-de-disco-msx)
   - [Menu Criar → Disco... (gerenciador gráfico)](#menu-criar--disco-gerenciador-gráfico)
   - [Linha de comando (`--diskmanipulator`)](#linha-de-comando---diskmanipulator)

---

## Compilação

O executável é gerado pelo compilador do PureBasic (`pbcompiler.exe`) através do script
[`build.ps1`](../build.ps1), na raiz do projeto. Não é necessário abrir a IDE do
PureBasic — o script cuida de tudo pelo PowerShell.

```powershell
.\build.ps1
```

Isso compila `editor\BadigEditor.pb` e gera `editor\BadigEditor.exe`.

### Onde o script encontra o `pbcompiler.exe`

Nesta ordem de prioridade:

1. Opção `-C` / `--compiler` na linha de comando.
2. Valor salvo em `build.config.json` (criado automaticamente ao lado do script, na
   primeira vez que `-C`/`--compiler` é usado — não versionado no git, é específico de
   cada máquina).
3. Caminho padrão: `%PROGRAMFILES%\PureBasic\Compilers\pbcompiler.exe`.

```powershell
# Primeira vez numa maquina nova (caminho fica salvo para as proximas execucoes)
.\build.ps1 -C "C:\Basic\Compilers\pbcompiler.exe"

# Depois, basta:
.\build.ps1
```

### Parâmetros

`-H`/`--help`, `-C`/`--compiler` e `-R`/`--run` seguem o formato Unix (letra curta +
nome longo com `--`). Os demais ficam no estilo nativo do PowerShell (só forma longa,
um traço).

| Parâmetro | Descrição |
|---|---|
| `-C`, `--compiler <caminho>` | Caminho para o `pbcompiler.exe`. |
| `-R`, `--run` | Executa o programa automaticamente após uma compilação sem erros. |
| `-H`, `--help` | Mostra a lista de opções e sai. |
| `-Version` | Versão embutida no executável (padrão `5.3.1`). |
| `-SourceFile` | Arquivo fonte a compilar (padrão `editor\BadigEditor.pb`). |
| `-OutputExe` | Caminho do executável de saída (padrão `editor\BadigEditor.exe`). |

```powershell
# Compila e ja abre o programa
.\build.ps1 -R
.\build.ps1 --run

# Marca uma nova versao
.\build.ps1 -Version "5.2.0" -R

# Lista as opcoes
.\build.ps1 -H
```

### Versão e build

A cada compilação, o script grava no executável (via `/CONSTANT` do `pbcompiler.exe`):

- **Versão** — string livre (`-Version`, padrão `5.3.1`).
- **Build** — data/hora **UTC** do momento da compilação, convertida para **hexadecimal**
  (segundos desde a época Unix, ex.: `6A57EA80`). Cada build tem um identificador único e
  ordenável.

Essas informações aparecem dentro do programa em **Ajuda → Sobre...**.

---

## Execução

Depois de compilado, basta rodar o executável gerado:

```powershell
.\editor\BadigEditor.exe
```

ou usar `.\build.ps1 -Run` para compilar e abrir em um único passo.

Na primeira execução vale abrir **Configurar → Editor...** para escolher fonte e tema, e
**Configurar → Basic Dignified...** para apontar (ou baixar) o toolchain Python de
referência — ver [Telas de configuração](#telas-de-configuração).

---

## O editor de texto

### Teclado estilo WordStar/JOE

O editor é baseado no [**JOE** (Joe's Own Editor)](https://joe-editor.sourceforge.io/),
que por sua vez reproduz o teclado clássico do **WordStar** (modo `jstar` do JOE) — os
comandos usam `Ctrl` + uma letra, muitos deles em **duas teclas** (ex.: `Ctrl+K` seguido
de `B`), sem precisar do mouse nem das setas.

Esta primeira leva implementa o conjunto **básico** do JOE (a "Basic Help Screen" que ele
mesmo mostra com `Ctrl+J`): movimento do cursor, apagar texto, bloco marcado, arquivo e
desfazer/refazer. Mais comandos (busca, reformatar parágrafo, etc.) entram depois — ver
[O que ainda não está implementado](#o-que-ainda-não-está-implementado).

> **Importante:** como no WordStar de verdade, `Ctrl+S` **não salva** — move o cursor para
> a esquerda. Salvar é `Ctrl+K D` (ver [Arquivo](#arquivo)).

Nos comandos de duas teclas (`Ctrl+K x`, `Ctrl+Q x`), a segunda tecla pode ser digitada
**com ou sem** `Ctrl` — `Ctrl+K` depois `B` funciona igual a `Ctrl+K` depois `Ctrl+B`.

### Movimento do cursor

| Tecla | Ação |
|---|---|
| `Ctrl+S` | Um caractere para a esquerda |
| `Ctrl+D` | Um caractere para a direita |
| `Ctrl+E` | Uma linha para cima |
| `Ctrl+X` | Uma linha para baixo |
| `Ctrl+A` | Palavra anterior |
| `Ctrl+F` | Próxima palavra |
| `Ctrl+R` | Tela anterior (Page Up) |
| `Ctrl+C` | Próxima tela (Page Down) |
| `Ctrl+Q S` | Início da linha |
| `Ctrl+Q D` | Fim da linha |
| `Ctrl+Q R` | Início do arquivo |
| `Ctrl+Q C` | Fim do arquivo |

### Apagar texto

| Tecla | Ação |
|---|---|
| `Ctrl+G` | Apaga o caractere sob o cursor (para a frente) |
| `Ctrl+H` / `Backspace` | Apaga o caractere anterior |
| `Ctrl+T` | Apaga a palavra à direita |
| `Ctrl+Y` | Apaga a linha inteira |
| `Ctrl+Q Y` | Apaga até o fim da linha |

### Bloco marcado (selecionar/copiar/mover/apagar)

Diferente de uma seleção comum (arrastar o mouse ou Shift+setas), o bloco do
WordStar/JOE é marcado por **dois pontos fixos** no texto — `Ctrl+K B` (início) e
`Ctrl+K K` (fim) — e continua destacado mesmo depois que o cursor se move para outro
lugar (é assim que dá para marcar, navegar até o destino, e só então copiar/mover).

| Tecla | Ação |
|---|---|
| `Ctrl+K B` | Marca o **início** do bloco na posição do cursor |
| `Ctrl+K K` | Marca o **fim** do bloco na posição do cursor |
| `Ctrl+K C` | **Copia** o bloco para a posição atual do cursor (o bloco original continua marcado — dá para repetir `Ctrl+K C` em vários lugares) |
| `Ctrl+K V` | **Move** o bloco para a posição atual do cursor (cursor precisa estar fora do bloco) |
| `Ctrl+K Y` | **Apaga** o bloco marcado |

`Ctrl+K C` e `Ctrl+K V` também colocam o texto do bloco na área de transferência do
Windows, para colar em outros programas. Não há tecla dedicada para desmarcar — marcar de
novo (`Ctrl+K B` seguido de `Ctrl+K K` na mesma posição) produz uma marca de tamanho zero,
que fica sem destaque.

### Arquivo

| Tecla | Ação |
|---|---|
| `Ctrl+K D` | Salva o arquivo |
| `Ctrl+K E` | Abre um arquivo |
| `Ctrl+K X` | Salva e fecha a aba atual |
| `Ctrl+K Q` | Fecha a aba atual (avisa se há alterações não salvas) |

Esses comandos também estão disponíveis pelo menu **Arquivo**.

**Tipos de arquivo**: o menu **Arquivo** tem dois comandos de "criar novo" — **Novo** (`Ctrl+N`) cria
uma aba MSX-BASIC/Dignified (`.dmx`), **Novo Assembly** (`Ctrl+Shift+N`) cria uma aba Z80 Assembly
(`.asm`). Cada aba lembra seu próprio tipo (detectado automaticamente pela extensão ao abrir um
arquivo existente — `.asm`/`.z80`/`.mac` viram Assembly, o resto vira Dignified) e aplica o destaque
de sintaxe certo: o dialeto Dignified numa aba `.dmx`, ou o vocabulário do assembler
**N80/Nestor80** (mnemônicos, registradores, diretivas, literais numéricos em qualquer radix) numa
aba `.asm`. O motor que monta `.asm` em binário Z80 ainda não existe — por enquanto a aba `.asm` é só
edição com destaque de sintaxe, ver [`SPEC.md`](SPEC.md#2-assembler-z80).

### Desfazer / refazer

| Tecla | Ação |
|---|---|
| `Ctrl+U` | Desfazer |
| `Ctrl+Shift+6` (`Ctrl+^`) | Refazer |
| `Ctrl+V` | Alterna entre inserção e sobrescrita (Insert/Overtype) |

### Ajuda embutida (Ctrl+K H)

`Ctrl+K H` mostra, dentro da própria área do editor (como no JOE/WordStar), uma tela com
os atalhos acima organizados por seção (Cursor, Apagar, Bloco marcado, Arquivo, Outros).
**Qualquer tecla** (ou clique) fecha a ajuda e devolve o foco para o texto — não precisa
ser a mesma combinação que abriu.

### Barra de status

O rodapé da janela mostra, sempre atualizado:

| Campo | Conteúdo |
|---|---|
| Modo | `INS` (inserção) ou `SBR` (sobrescrita — `Ctrl+V`). Enquanto um comando de duas teclas está pendente (`Ctrl+K`/`Ctrl+Q` já apertado, esperando a segunda tecla), mostra `^K`/`^Q` no lugar. |
| Nome do arquivo | Nome da aba ativa, com `*` se houver alterações não salvas. |
| Linha/Coluna | Posição atual do cursor no documento ativo. |

### O que ainda não está implementado

Fica para uma próxima etapa (o JOE tem bem mais comandos que isso — veja a referência em
[joe-editor.sourceforge.io](https://joe-editor.sourceforge.io/)):

- Busca e substituição (`Ctrl+Q F`, `Ctrl+L`)
- Reformatar parágrafo (`Ctrl+B`)
- Salvar bloco marcado direto num arquivo (`Ctrl+K W`)
- Menu de opções do editor (`Ctrl+O`, no JOE — não confundir com o `Ctrl+O` de "Abrir" já
  usado pelo menu **Arquivo** desta IDE)

---

## Telas de configuração

- **Configurar → Editor...** — fonte (só monoespaçadas, com botão para baixar fontes
  [Nerd Fonts](https://www.nerdfonts.com/) direto de dentro da IDE), tema claro/escuro,
  estilo de abas, caminho de instalação do editor.
- **Configurar → Basic Dignified...** — três abas:
  - **Basic Dignified** — opções do pré-processador/tokenizador e diretório de instalação do
    toolchain Python de referência (com botão para baixar via `git clone` ou `.zip` do GitHub).
  - **MSX** — opções específicas do dialeto/tokenizador MSX.
  - **Emulador** — caminho do executável do openMSX, **Máquina** e **Extensão de disco** (cada
    campo tem um botão "..." que lista as máquinas/extensões disponíveis em `share/machines`/
    `share/extensions` a partir do caminho do openMSX configurado, sem precisar digitar o nome de
    cabeça), e a opção **"Abrir o openMSX e rodar o código após gerar"**: quando marcada, o menu
    **Arquivo → Dignified → tokenizado nativo (.bmx)...** passa a montar um disquete com o programa
    gerado (mais um `AUTOEXEC.BAS` para rodar automaticamente) e abrir o openMSX direto nele, já
    com a máquina/extensão escolhidas.
- **Ajuda → Sobre...** — versão, build e data de compilação (ver
  [Versão e build](#versão-e-build)).

---

## Gerenciador de disco MSX

### Menu Criar → Disco... (gerenciador gráfico)

O menu **Criar → Disco...** abre uma janela com dois painéis (estilo Norton/Total Commander) para
montar imagens de disco MSX (`.dsk`) sem sair do editor:

- **Campo "Arquivo do disco"** (topo) — o botão **"..."** abre o diálogo padrão do Windows para
  escolher um `.dsk` já existente (abre para edição) ou digitar um caminho novo (cria um disco em
  branco de 720 KB).
- **Painel esquerdo** — sistema de arquivos local, começando no diretório onde o `BadigEditor.exe`
  está rodando. Duplo-clique numa pasta entra nela; duplo-clique em `..` sobe um nível.
- **Painel direito** — conteúdo do disco aberto/em criação.
- **`Adicionar >>` / `<< Extrair`** — transferem os arquivos selecionados (seleção múltipla suportada)
  entre os dois painéis. **Sempre por cópia** — o arquivo de origem nunca é apagado.
- **`Remover local` / `Remover disco`** — excluem de verdade os arquivos selecionados (do sistema de
  arquivos do Windows ou de dentro do disco, respectivamente), pedindo confirmação antes por serem
  ações destrutivas. `Remover disco` fica desabilitado até que um disco esteja aberto.
- **Salvar / Salvar como... / Duplicar... / Excluir disco... / Cancelar** — todas as operações acima
  acontecem numa **cópia de rascunho temporária**; o arquivo `.dsk` escolhido no topo só é gravado de
  verdade num destes botões:
  - **Salvar** — grava no arquivo escolhido e fecha a janela.
  - **Salvar como...** — pergunta um caminho novo e grava lá (a janela continua fechando ao final).
  - **Duplicar...** — grava uma cópia extra num caminho escolhido **sem** fechar a sessão — o
    trabalho continua no disco original.
  - **Excluir disco...** — apaga o arquivo `.dsk` de destino (se já existir) e reinicia a janela do
    zero, pronta para outro disco.
  - **Cancelar** (ou fechar a janela) — descarta o rascunho sem tocar no arquivo escolhido no topo.

### Linha de comando (`--diskmanipulator`)

O mesmo motor de disco também está disponível como utilitário de linha de comando, sem abrir
nenhuma janela — útil em scripts:

```powershell
BadigEditor.exe --diskmanipulator create disco.dsk
BadigEditor.exe --diskmanipulator list disco.dsk -l
BadigEditor.exe --diskmanipulator add disco.dsk arquivo.bas *.txt
BadigEditor.exe --diskmanipulator extract disco.dsk -d pasta_saida *.bas
BadigEditor.exe --diskmanipulator delete disco.dsk arquivo.bas
```

| Comando | Descrição |
|---|---|
| `create <disco.dsk> [boot.bin]` | Cria uma imagem de disco MSX em branco (720 KB), com setor de boot customizado opcional. |
| `list <disco.dsk> [-l]` | Lista os arquivos do disco (`-l` mostra tamanho e data/hora). |
| `add <disco.dsk> <arquivo...>` | Adiciona um ou mais arquivos locais (aceita curingas como `*.BAS`). |
| `extract <disco.dsk> [-d pasta] [máscara...]` | Extrai arquivos do disco, opcionalmente filtrando por máscara. |
| `delete <disco.dsk> <arquivo>` | Remove um arquivo de dentro do disco. |

Diferente da versão gráfica, a CLI grava direto no arquivo informado (sem cópia de rascunho) — mesmo
comportamento do utilitário `msxdisk.exe` original.
