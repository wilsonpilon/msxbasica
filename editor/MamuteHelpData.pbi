; Ajuda -> Mamute Assembler...: base de dados dos topicos, escrita a mao (nao
; convertida de nenhum manual externo - ao contrario de AsmsxHelpData.pbi/
; RedBookHelpData.pbi/etc.) porque o Mamute Assembler e uma ferramenta NOVA
; desta IDE, sem documento de origem. Cresce um Add() por comando novo, na
; mesma velocidade que MamuteAssemblerGui.pbi ganha o Case correspondente em
; MamuteGui_Dispatch() - os dois crescem juntos por sessao.
;
; Corpo.s renderizado por GenMdHelp_RenderMarkdown() (GenericMdHelpGui.pbi,
; mesmo motor do Ajuda -> asMSX...) - suporta **negrito**/`codigo`/blocos
; ``` sem precisar de parser proprio.

Structure MamuteHelpTopic
  Titulo.s
  Grupo.s
  Corpo.s
EndStructure

Global NewList MamuteHelp_Topics.MamuteHelpTopic()
Global MamuteHelp_DataBuilt.b = #False

Procedure MamuteHelp_Add(Titulo.s, Grupo.s, Corpo.s)
  AddElement(MamuteHelp_Topics())
  MamuteHelp_Topics()\Titulo = Titulo
  MamuteHelp_Topics()\Grupo = Grupo
  MamuteHelp_Topics()\Corpo = Corpo
EndProcedure

Procedure MamuteHelp_BuildData()
  If MamuteHelp_DataBuilt
    ProcedureReturn
  EndIf
  MamuteHelp_DataBuilt = #True

  MamuteHelp_Add("Introducao", "",
    "O **Mamute Assembler** (`Executar -> Mamute Assembler...`) e uma janela estilo " +
    Chr(34) + "monitor" + Chr(34) + " - inspirada nos montadores de linha de comando dos " +
    "computadores de 8 bits dos anos 80 (o **MegaAssembler** original foi a inspiracao direta) " +
    "- em vez de uma tela cheia de campos e botoes, um prompt `MON>` aceita comandos digitados, " +
    "um de cada vez." + #CRLF$ + #CRLF$ +
    "Fundo preto, texto monoespacado verde: visual deliberadamente diferente do resto da IDE " +
    "(que segue o tema claro escolhido em `Configurar -> Editor...`) - e pra lembrar um " +
    "terminal de verdade daquela epoca, nao um dialogo moderno." + #CRLF$ + #CRLF$ +
    "**Nao e o Editor Hexa nem os assemblers ja existentes** (nativo, N80, asMSX) - e uma " +
    "ferramenta a parte, com seu proprio pequeno conjunto de comandos, que vai crescer aos " +
    "poucos, sessao a sessao. Comandos disponiveis ate agora: **BA / QUIT**, **PAGE**, **DM** e " +
    "**ZAP**, ver ao lado. **Os enderecos/setores digitados em qualquer comando sao sempre em " +
    "hexadecimal** - o padrao de entrada do Mamute Assembler inteiro." + #CRLF$ + #CRLF$ +
    "O Mamute Assembler simula o **sistema de slots do MSX de verdade**: 4 slots (0-3), cada um " +
    "com 4 paginas de 16KB (`Pagina 0` = `0000-3FFF`, `Pagina 1` = `4000-7FFF`, `Pagina 2` = " +
    "`8000-BFFF`, `Pagina 3` = `C000-FFFF`) - 16 blocos de memoria ao todo. `Configurar -> " +
    "Mamute Assembler...` define o que existe FISICAMENTE em cada um desses 16 blocos (Vazio/" +
    "RAM/ROM/BASIC, e um arquivo pra carregar quando for ROM/BASIC - por enquanto a memoria " +
    "comeca sempre em branco, o carregamento de arquivo de verdade vem numa sessao futura).")

  MamuteHelp_Add("BA / QUIT", "Comandos",
    "Encerra a janela do Mamute Assembler - equivalente a fechar pelo X da janela. Sem " +
    "argumentos, funciona em qualquer um dos dois nomes (nao diferencia maiusculas de " +
    "minusculas)." + #CRLF$ + #CRLF$ +
    "**Sintaxe:**" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>BA" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "ou" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>QUIT" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "Qualquer outra entrada nao reconhecida ainda mostra `?COMANDO INVALIDO` - novos comandos " +
    "entram aqui aos poucos, ver `README.md`/`docs/RELEASE_NOTES.md` pro que ja foi " +
    "acrescentado desde esta versao.")

  MamuteHelp_Add("PAGE", "Comandos",
    "Mostra ou troca o **mapeamento ativo agora mesmo**: pra cada uma das 4 paginas que o Z80 " +
    "enxerga (0-3), qual dos 4 slots fisicos (`Configurar -> Mamute Assembler...`) esta " +
    "comutado ali - exatamente como o registrador de slot primario de um MSX de verdade. Isso " +
    "e diferente da configuracao fisica: um slot pode ter RAM/ROM/BASIC configurados nele, mas " +
    "so o slot MAPEADO numa pagina e o que os proximos comandos que mostram/inserem dados vao " +
    "realmente enxergar naquele endereco (comandos ainda nao portados - ver Introducao)." + #CRLF$ + #CRLF$ +
    "**`PAGE`** (sem argumentos) - coloca as 4 paginas no slot marcado como RAM (o primeiro " +
    "slot, varrendo 0 a 3, que tiver RAM configurada em alguma pagina). Mostra `?NENHUM SLOT " +
    "DE RAM CONFIGURADO` se nenhum slot tiver RAM ainda." + #CRLF$ + #CRLF$ +
    "**`PAGE ?`** - so mostra o mapeamento ativo, sem mudar nada:" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>PAGE ?" + #CRLF$ +
    "PAGE0(0000-3FFF) SLOT 0" + #CRLF$ +
    "PAGE1(4000-7FFF) SLOT 0" + #CRLF$ +
    "PAGE2(8000-BFFF) SLOT 3" + #CRLF$ +
    "PAGE3(C000-FFFF) SLOT 3" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "**`PAGE X, Y, Z, W`** - troca o mapeamento: pagina 0 passa pro slot `X`, pagina 1 pro " +
    "slot `Y`, pagina 2 pro slot `Z`, pagina 3 pro slot `W` (cada um de 0 a 3). Sempre os 4 de " +
    "uma vez - nao da pra trocar so uma pagina isolada. Exemplos:" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>PAGE 2, 2, 2, 2" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "coloca as 4 paginas no slot 2;" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>PAGE 0, 1, 3, 3" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "coloca a pagina 0 no slot 0, a pagina 1 no slot 1, e as paginas 2 e 3 no slot 3. Depois de " +
    "aplicar, o novo mapeamento e mostrado na hora (igual `PAGE ?`), pra confirmar visualmente " +
    "o que mudou. Argumento fora de 0-3, faltando ou sobrando (sempre precisa ser exatamente 4, " +
    "separados por virgula) mostra `?ERRO DE SINTAXE`.")

  MamuteHelp_Add("DM", "Comandos",
    "**Despejo de Memoria** - o primeiro comando que realmente le/escreve a memoria simulada. " +
    "Abre uma janela separada mostrando 128 bytes (16 linhas de 8 bytes) a partir do endereco " +
    "informado, em hexa e ASCII lado a lado, navegavel e editavel." + #CRLF$ + #CRLF$ +
    "**Sintaxe:**" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>DM <endereco>[,<deslocamento>]" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "`<endereco>` (obrigatorio) - onde comeca o despejo, em hexa (0000-FFFF). `<deslocamento>` " +
    "(opcional, tambem hexa, com sinal `+`/`-` opcional na frente) - de `-7F` a `80` - " + Chr(34) +
    "criptografa/descriptografa" + Chr(34) + " so a INTERPRETACAO ASCII exibida: cada byte mostrado " +
    "como texto e o valor cru mais o deslocamento (modulo 256) - o bloco hexa sempre mostra o " +
    "byte cru da memoria, sem nenhuma alteracao. Exemplo:" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>DM 4000,-20" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "**Layout de cada linha:** endereco na primeira coluna, 8 bytes em hexa nas colunas " +
    "seguintes, os 8 caracteres correspondentes como um bloco no final. Caractere que nao da pra " +
    "imprimir vira `.`. Abaixo da grade, duas linhas de status: `Endereco:` (o endereco base " +
    "atual) e `Desloc.:` (o deslocamento ativo)." + #CRLF$ + #CRLF$ +
    "**Navegacao do cursor** - move pela grade de 128 bytes (clique direto numa celula tambem " +
    "funciona):" + #CRLF$ +
    "- 4 setas pequenas na tela (clicaveis) - movem uma celula por vez; teclado (setas do " +
    "cursor) faz o mesmo." + #CRLF$ +
    "- `TAB` alterna se o cursor esta no bloco hexa ou no bloco de texto." + #CRLF$ +
    "- 2 setas maiores (`<<`/`>>`) pulam **-128**/**+128 bytes** no endereco base (PgUp/PgDn do " +
    "teclado fazem o mesmo)." + #CRLF$ +
    "- Botoes `+`/`-` (ou as teclas correspondentes do teclado numerico) ajustam o deslocamento " +
    "em 1, dentro da faixa `-7F` a `80`." + #CRLF$ + #CRLF$ +
    "**Editar um byte** - `RETURN` abre um campo de entrada pro bloco ativo (hex ou texto); " +
    "`RETURN` de novo confirma o que foi digitado; `ESC` cancela a edicao em andamento (ou, fora " +
    "de edicao, fecha a janela do DM). No bloco hexa, digite 1-2 digitos hexa pro byte sob o " +
    "cursor. No bloco de texto, digite um texto simples - cada caractere vira um byte cru " +
    "(revertendo o deslocamento ativo), escritos a partir do cursor, que avanca sozinho." + #CRLF$ + #CRLF$ +
    "Escrita **so tem efeito em celulas mapeadas como RAM agora** (`PAGE`/`Configurar -> Mamute " +
    "Assembler...`) - ROM, BASIC e Vazio sao somente-leitura, igual hardware real (nao ha o que " +
    "escrever fisicamente ali).")

  MamuteHelp_Add("ZAP", "Comandos",
    "**Editor de Setores de disco** - muito parecido com o `DM`, mas em vez de mostrar/editar a " +
    "memoria simulada do MSX, abre uma **imagem de disco (.dsk)** e mostra/edita os bytes crus " +
    "dela, setor a setor (512 bytes/setor). Prioridade pra disquetes de **720KB** (FAT12 padrao), " +
    "mas 360KB e 180KB tambem funcionam - qualquer combinacao de face simples/dupla e densidade " +
    "simples/dupla, 5" + Chr(34) + "1/4 ou 3" + Chr(34) + "1/2. O ZAP nao interpreta a estrutura " +
    "FAT12 (boot sector, FAT, diretorio) - so le/escreve bytes crus por posicao, igual um editor " +
    "de setor de verdade da epoca." + #CRLF$ + #CRLF$ +
    "**Sintaxe:**" + #CRLF$ + #CRLF$ +
    "```" + #CRLF$ +
    "MON>ZAP <setor inicial>[,<deslocamento>]" + #CRLF$ +
    "```" + #CRLF$ + #CRLF$ +
    "`<setor inicial>` (obrigatorio, hexa) - o setor onde a grade comeca (setor 0 = boot sector). " +
    "`<deslocamento>` (opcional, hexa com sinal, `-7F` a `80`) - identico ao do `DM`: " + Chr(34) +
    "criptografa/descriptografa" + Chr(34) + " so a interpretacao ASCII exibida/digitada, nunca o " +
    "byte cru." + #CRLF$ + #CRLF$ +
    "**Ao rodar, primeiro pede um arquivo .dsk** (janela normal de escolher arquivo do Windows). " +
    "Cancelar a escolha cancela o comando inteiro, sem abrir nada." + #CRLF$ + #CRLF$ +
    "**Layout e navegacao** identicos ao `DM` (mesmas setas/`TAB`/`PgUp`/`PgDn`/`+`/`-`/clique do " +
    "mouse - ver o topico `DM` ao lado pro detalhe completo) - a diferenca e o rotulo de cada " +
    "linha, que mostra o deslocamento DENTRO DO SETOR atual (`000` a `1F8`, ja que um setor tem " +
    "512 bytes = 4 telas de 128), e as linhas de status mostram `Setor:` + `Byte:` (endereco " +
    "absoluto dentro do arquivo) em vez de `Endereco:`." + #CRLF$ + #CRLF$ +
    "**Salvando alteracoes - a diferenca mais importante em relacao ao DM**: editar um byte no " +
    "ZAP muda so o que esta na MEMORIA (ainda nao grava no arquivo .dsk de verdade). Pra gravar o " +
    "setor onde o cursor esta agora de volta no disco, use:" + #CRLF$ + #CRLF$ +
    "- **`Ctrl+S`**, ou" + #CRLF$ +
    "- o botao amarelo **" + Chr(34) + "SALVAR SETOR" + Chr(34) + "** na tela (unico botao extra " +
    "que o ZAP tem alem dos mesmos do `DM`)." + #CRLF$ + #CRLF$ +
    "So o setor sob o cursor e gravado (gravacao cirurgica, nao o disco inteiro). O titulo da " +
    "janela ganha um `*` enquanto houver qualquer alteracao ainda nao salva; fechar a janela nesse " +
    "estado (`ESC` ou o X) pede confirmacao antes de descartar.")
EndProcedure
