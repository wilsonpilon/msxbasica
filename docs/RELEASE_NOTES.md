# Release Notes

Notas de lançamento formais, uma entrada por versão com codinome — versão mais recente primeiro.
Para o histórico completo e detalhado sessão a sessão (incluindo versões sem codinome), ver o
"Changelog resumido" em `README.md`. Para a arquitetura/spec de cada módulo, ver `docs/SPEC.md`.

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
