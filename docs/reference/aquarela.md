# Referência: formato de fonte do Aquarela (.FNT)

> Notas de engenharia reversa sobre o **Aquarela**, outro editor de fontes/alfabetos para MSX
> (alternativa ao Graphos III, que é o formato `.ALF` já suportado pelo editor de alfabetos —
> `editor/CharsetEditorGui.pbi`). Sem acesso à documentação oficial do Aquarela até o momento;
> tudo aqui vem de engenharia reversa dos bytes crus de 4 arquivos `.fnt` de exemplo (pasta
> `alfabetos/`), não de nenhuma especificação lida. Tratar como **hipótese bem testada, não como
> fato documentado** — releia esta nota inteira antes de codificar um importador em cima dela, e
> reforce a validação se aparecer um quinto arquivo de exemplo ou a documentação real do programa.

## Amostras analisadas

| Arquivo | Tamanho | Slots reais | Slots em branco | Valor de preenchimento em branco |
|---|---|---|---|---|
| `alfabetos/CHORO.FNT` | 2280 bytes | 71 | 0 | — |
| `alfabetos/data70.fnt` | 2280 bytes | 39 | 32 (posições 0–31) | `0x40` |
| `alfabetos/pacma1.fnt` | 2280 bytes | 0 | 71 (arquivo inteiro) | `0x40` |
| `alfabetos/pacma2.fnt` | 2280 bytes | 71 | 0 | — |

Os 4 arquivos têm **exatamente o mesmo tamanho** (2280 bytes) independente do conteúdo — forte
indício de que esse é um tamanho fixo do formato de exportação do Aquarela, não algo calculado a
partir de quantos caracteres o autor realmente desenhou.

## Formato do registro (confirmado, sem exceção nos 4 arquivos)

- **Sem cabeçalho** — o primeiro byte do arquivo já é o primeiro byte do primeiro glifo.
- **32 bytes por caractere**, dividido em duas metades de 16 bytes:
  - **Bytes 0–15**: o glifo real. Interpretado como 16 linhas de 1 byte (8 pixels de largura ×
    16 linhas de altura), MSB à esquerda. Nas amostras analisadas o desenho de fato só ocupa uma
    faixa central de ~6–7 linhas dentro dessas 16 — o resto fica em branco, sugerindo uma célula
    alta (16px) usada de forma conservadora pela maioria dos glifos.
  - **Bytes 16–31**: **sempre zero** — confirmado em 142 registros com conteúdo real (71 de
    `CHORO.FNT` + 71 de `pacma2.fnt`) mais os registros em branco de `data70.fnt`/`pacma1.fnt`,
    sem uma única exceção. Provavelmente reservado (talvez para uma variante de 16px de largura
    que este conjunto de amostras nunca usa, ou para dado de cor — ver seção "SCREEN 1 vs SCREEN 2"
    nos tópicos futuros abaixo).
- **Arquivo = 71 registros completos (2272 bytes) + 8 bytes finais** — sempre os primeiros 8 bytes
  de um 72º registro que nunca chega a ficar completo (em `CHORO.FNT` esses 8 bytes finais tinham
  conteúdo real de glifo; nos outros 3 arquivos são só mais preenchimento em branco). Não está claro
  se isso é um formato de exatos "71 caracteres mais uma fração" ou se o tamanho de 2280 bytes é só
  um limite fixo de exportação que não bate exatamente com N×32.
- **Valor de "posição vazia"**: varia entre amostras — `0x00` em `CHORO.FNT`, `0x40` em
  `data70.fnt`/`pacma1.fnt`. Não sabemos se isso é versão do Aquarela, modo de exportação, ou
  alguma outra variável — mais uma pergunta em aberto.

## Prova cruzada entre arquivos (o achado mais forte)

Comparando os 71 glifos de cada arquivo byte a byte (não por semelhança visual):

- **`CHORO.FNT` ≡ `pacma2.fnt`, deslocamento 0**: os índices 23–31 são **idênticos, byte a byte**,
  nos dois arquivos.
- **`data70.fnt`, deslocamento +16** dos outros dois: os mesmos 9 glifos aparecem nos índices
  39–47 de `data70.fnt` (39 = 23+16, 47 = 31+16, sem exceção).

São **3 arquivos independentes concordando exatamente** sobre o mesmo alinhamento relativo entre
posições. A explicação mais simples: o Aquarela vem com uma fonte padrão, e um autor de fonte só
substitui os caracteres que quer desenhar — esses 9 (prováveis códigos de caractere que nenhum dos
três autores customizou) guardam o desenho de fábrica do programa, sempre na mesma posição real.

## O que NÃO está confirmado

- **Âncora absoluta**: qual código de caractere (ASCII? tabela nativa do MSX?) a posição 0 do
  arquivo representa de fato. A hipótese mais forte hoje — **posição no arquivo = código do
  caractere, começando em 0** — vem de `data70.fnt` ter exatamente 32 posições em branco no
  início (o número exato de códigos de controle ASCII 0–31, antes do primeiro código imprimível,
  32 = espaço). Mas isso não foi verificado contra uma fonte com rótulos conhecidos.
- **Identidade letra a letra de cada posição**: uma primeira tentativa de ler os primeiros 21
  glifos de `CHORO.FNT` como "C D E F G H I J K L M N O P Q R S T U V W" (só por semelhança visual
  de forma) **foi errada** — não tinha nenhuma base além de "parece com" — e foi retirada depois
  que `data70.fnt` mostrou que o arquivo provavelmente nem começa no código de um "C". Tentativas
  seguintes de confirmar letras específicas (ex.: checar se a posição correspondente a "A" parece
  um A) também não bateram. **Não confiar em leitura visual de glifo isolado neste formato** — é
  uma fonte decorativa, com formas estilizadas que enganam fácil.
- Por que `CHORO.FNT` usa `0x00` como preenchimento de posição vazia enquanto `data70.fnt`/
  `pacma1.fnt` usam `0x40`.
- Os 8 bytes finais do arquivo (72º registro incompleto) — sobra de exportação ou trecho
  significativo?

## Comparação com Graphos III (`.ALF`, já suportado)

| | Graphos III (`.ALF`) | Aquarela (`.FNT`) |
|---|---|---|
| Cabeçalho | 7 bytes (tipo `0xFE` + endereços inicial/final/execução) | nenhum encontrado |
| Células | 256 fixas, sempre presentes | só as usadas — 71 nas amostras, resto nem existe no arquivo |
| Glifo | 8×8, 8 bytes | 8×16, 16 bytes (desenho real só usa ~7 linhas nas amostras) |
| Por registro | 8 bytes | 32 bytes (16 reais + 16 sempre zero) |
| Tamanho total | 2055 bytes (7 + 256×8) fixo pelo formato | 2280 bytes fixo, aparentemente independente do conteúdo |

## Próximos passos / tópicos futuros

1. **Suporte a importação `.FNT` do Aquarela no editor de alfabetos** (`CharsetEditorGui.pbi`),
   ao lado do já existente "Carregar do Graphos III...". Viável com o que já sabemos do formato
   (parser dos 71 registros de 32 bytes é simples), mas **antes de codificar o mapeamento de
   código de caractere**, considerar uma UI que deixe o "código inicial" ajustável na hora da
   importação (sugestão inicial: 0), já que a âncora absoluta ainda não está 100% confirmada — evita
   cravar no código um palpite que pode estar errado. Ideal: validar contra mais amostras, contra a
   documentação real do Aquarela (se aparecer), ou rodando o próprio Aquarela num emulador se uma
   cópia executável existir.
2. **Suporte a SCREEN 2 além de SCREEN 1** no editor de alfabetos (ligado, mas não exclusivo, ao
   trabalho acima) — hoje o editor (e o `.ALF` do Graphos III) modela exatamente a Pattern
   Generator Table de **SCREEN 1**: uma única tabela de 256 padrões × 8 bytes (2048 bytes), com cor
   definida grosseiramente por grupo de 8 códigos de caractere (Color Table de 32 bytes, fora do
   escopo atual do editor — ele só lida com o desenho monocromático). **SCREEN 2** (resolução mais
   alta) usa uma Pattern Generator Table **3× maior**: três "terços" de 256 padrões × 8 bytes cada
   (6144 bytes no total, cobrindo posições de caractere 0–255/256–511/512–767, um terço por terço
   da tela) — e uma Color Table do **mesmo tamanho** (6144 bytes), porque em SCREEN 2 cada uma das
   8 linhas de pixel de um glifo pode ter seu próprio par de cores FG/BG, em vez de um par só para
   o caractere inteiro como em SCREEN 1. Suportar SCREEN 2 de verdade significa: (a) o editor lidar
   com os 3 bancos/terços de padrão em vez de só 1, e (b) adicionar suporte a cor de verdade (hoje
   inexistente no editor — só desenho monocromático) — mudança de modelo de dados bem maior que só
   trocar o formato de arquivo importado, vale tratar como item separado ao planejar.
3. Investigar se os 16 bytes sempre-zero de cada registro do Aquarela guardam alguma relação com
   esse suporte a cor por linha do SCREEN 2 (2 metades de 16 bytes por caractere é sugestivo, mas
   isso é especulação, não hipótese testada — nenhuma amostra até agora teve dado real na segunda
   metade pra confirmar ou refutar).
