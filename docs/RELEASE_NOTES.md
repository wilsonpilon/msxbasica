# Release Notes

Notas de lançamento formais, uma entrada por versão com codinome — versão mais recente primeiro.
Para o histórico completo e detalhado sessão a sessão (incluindo versões sem codinome), ver o
"Changelog resumido" em `README.md`. Para a arquitetura/spec de cada módulo, ver `docs/SPEC.md`.

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
