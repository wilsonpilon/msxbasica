;
; ------------------------------------------------------------
;  Apelido interno: Mamute (tema pre-historico do projeto, ver README.md -
;  este ja era o nome oficial do modulo antes da troca de nomes do projeto)
;  Executar -> Mamute Assembler...: janela "monitor" inspirada nos antigos
;  montadores de linha de comando dos computadores de 8 bits dos anos 80 -
;  pedido explicito do usuario, referencia direta o MegaAssembler dele (tem
;  o manual original, mas so quer portar um subconjunto pequeno de comandos,
;  aos poucos). Nada de telas com campo/botao pra cada opcao: um prompt
;  "MON>" aceita comandos digitados, um de cada vez - ver Ajuda -> Mamute
;  Assembler... (MamuteHelpData.pbi/MamuteHelpGui.pbi, cresce junto com
;  MamuteGui_Dispatch() abaixo, um comando novo por sessao).
;
;  Primeira leva: BA/QUIT (fecha a janela). Segunda leva: PAGE (mostra/troca
;  qual SLOT fisico esta comutado em cada uma das 4 paginas visiveis pelo
;  Z80 agora mesmo - MamutePageMap(), MamuteSupport.pbi, XIncludeFile'd
;  antes deste arquivo, tambem tem o modelo de memoria 4x4x16KB e a tela
;  "Configurar -> Mamute Assembler..."). Terceira leva: DM (Despejo de
;  Memoria) - abre MamuteDumpGui.pbi (tambem XIncludeFile'd antes deste
;  arquivo), primeiro comando que realmente le/escreve a memoria simulada.
;  Quarta leva: ZAP - "muito parecido com o DM", so que edita SETORES de uma
;  imagem de disco (.dsk) em vez da memoria do MSX - abre MamuteZapGui.pbi.
;  Quinta leva: SCR - display grafico da memoria numa tela fixa 256x192,
;  modo horizontal/vertical - abre MamuteScrGui.pbi (tambem XIncludeFile'd
;  antes deste arquivo). Sexta leva: SH - busca de bytes/texto na memoria
;  (curinga entre virgulas vazias no modo bytes, deslocamento automatico no
;  modo texto) - so mostra o resultado no log, nao abre janela. Setima
;  leva: MS - grava uma string na memoria com deslocamento opcional, mesma
;  formula do bloco de texto do DM - tambem sem janela, so confirma no log.
;  Oitava leva: LOAD - carrega um arquivo escolhido numa janela (sem digitar
;  nome/CAS:/A:, diferente do manual original) pra dentro de um slot
;  escolhido pelo usuario - .ROM vai pros enderecos certos por tamanho
;  (4000 e/ou 8000), .BIN com cabecalho BLOAD vai pro endereco do
;  cabecalho, sem cabecalho pergunta o endereco (LOAD <nome> so sugere
;  nome/filtro na janela, nunca carrega direto). Nona leva: SAVE - o
;  inverso do LOAD, tambem com janela propria (MamuteSaveGui.pbi) - grava
;  um bloco de MamuteMem(Slot,...) num arquivo, com cabecalho BIN (FE+3
;  enderecos) ou ROM (AB+3 enderecos) opcional, ou sem cabecalho nenhum.
;  Decima/decima-primeira leva: M e S - mesmo esquema grafico do DM
;  (MamuteMGui.pbi), mas hexa digitado tecla-a-tecla direto (sem campo de
;  edicao); M usa 0-9/A-F fixos, S usa 16 teclas configuraveis em
;  "Configurar -> Mamute Assembler..." (MamuteSKeyMap(), MamuteSupport.pbi).
;  Decima-segunda leva: C - so guarda o modo de exibicao (0-3) que os
;  comandos D/P/V vao usar - sem janela, so confirma no log. Decima-terceira
;  leva: D/P/V - despejo formatado de memoria (mesmo Mamute_BuildDumpLines()
;  pros tres, formato conforme State\DisplayMode); D manda direto pro log
;  (video), P e V geram um PDF A4 simples (Mamute_SavePdfListing(),
;  MamutePdf.pbi, XIncludeFile'd antes deste arquivo - "impressora" de
;  verdade, driver Epson FX-80, fica pra uma sessao futura) e abrem "Salvar
;  como" no final; D/P leem a RAM/ROM (Mamute_ReadByte, resolve PAGE ativo),
;  V le a VRAM simulada nova (MamuteVRAM(), MamuteSupport.pbi - endereco
;  plano ate MamuteVramSize-1, sem banco/PAGE, porque VRAM de verdade nunca
;  foi mapeada no espaco de enderecos do Z80). Tamanho de VRAM (16/128/192KB)
;  configuravel em "Configurar -> Mamute Assembler...". Decima-quarta leva:
;  T/F - T <inic>,<fim>,<dest> transfere um bloco de RAM/ROM pra outro
;  endereco (copia de tras pra frente quando origem/destino se sobrepoe e o
;  destino vem depois da origem, mesmo algoritmo de um memmove seguro); F
;  <inic>,<fim>,<byte> preenche um bloco inteiro com o mesmo byte. Os dois
;  sem janela, so confirmam no log; sem wraparound (mesma regra do D/P/V) -
;  <dest> passar de FFFF e ?ERRO DE SINTAXE. Decima-quinta leva: G/X/R - G
;  <endinic>[,<brk1>[,<brk2>]] so VALIDA a sintaxe e confirma no log, sem
;  executar nada de verdade - execucao de programas fica pra uma fase futura
;  (pedido explicito do usuario). X [<reg>] mostra/edita os registradores Z80
;  simulados (MamuteGui_State\Reg*, novos campos) - sem argumento mostra os 7
;  pares (AF/BC/DE/HL/IX/IY/SP); com argumento (par OU byte isolado - A/F/B/
;  C/D/E/H/L - extensao sobre o manual original) caminha em sequencia
;  perguntando o novo valor de cada um via InputRequester(), valor atual
;  pre-preenchido (ENTER sem editar = mantem e continua, campo vazio/Cancelar
;  = para a caminhada). R [<offset>] so confirma no log que carregamento de
;  programa assemblado fica pra depois do assemblador embutido existir -
;  ignora os argumentos de proposito (pedido explicito do usuario). Decima-
;  setima leva: L/LP - disassembler Z80 de verdade (Mamute_DisasmOne()/
;  Mamute_DisasmBuildLines(), MamuteSupport.pbi - tabela de opcodes escrita
;  do zero via decomposicao x/y/z/p/q classica, ja que o assemblador Z80Asm.
;  pbi deste projeto codifica proceduralmente, sem tabela bytes->mnemonico
;  reaproveitavel). L manda a listagem pro log, LP gera PDF (mesma infra do
;  P/V); os dois aceitam [<endinic>[,<endfim>]] - sem <endfim>, 10
;  instrucoes; sem nada, continua do ultimo L/LP (*State\LastLAddr).
;  Ajuste de usabilidade (2026-08-12): usuario reportou "L 0,100 disassembla
;  poucas instrucoes" - investigado a fundo (harness de teste real contra o
;  ROM de verdade do usuario, repetido, batendo exatamente com o texto que
;  ele colou) e NAO era bug nenhum - a listagem inteira (115 linhas) estava
;  correta, so nao cabia na janela (720x480 antigo) sem rolar, e o usuario
;  nao tinha percebido a barra de rolagem. Aumentado WinW/WinH pra 960x640
;  (todos os gadgets ja eram parametrizados por WinW/WinH, so mudar aqui
;  redimensiona tudo) e o tamanho padrao da fonte de 14 pra 16
;  (MamuteFontSize, MamuteSupport.pbi - negrito ja era #True por padrao) -
;  fonte/tamanho/negrito continuam configuraveis em "Configurar -> Mamute
;  Assembler..." (ja existia antes desta sessao, so nao era do conhecimento
;  do usuario).
;  Decima-nona leva: EDIT - abre uma janela separada (MamuteEditGui.pbi,
;  XIncludeFile'd antes deste arquivo) pra digitar o programa-fonte Z80 no
;  formato de linhas numeradas do manual original ("NN Label: instrucao
;  operando ;comentario"). Passou por 2 reescritas na mesma sessao a partir
;  de feedback direto do usuario: 1a versao (clone do MON>, REPL) e 2a
;  versao (ListIconGadget) foram rejeitadas; a 3a e final reproduz o editor
;  de BASIC do ZX-81 de verdade (pedido explicito: "um editor exatamente
;  identico ao do ZX-81... exceto as teclas tokenizadas") - a listagem E' a
;  tela (CanvasGadget desenhado a mao), cursor ">" entre NN e o corpo da
;  linha, setas Cima/Baixo movem o cursor, ENTER com campo vazio puxa a
;  linha do cursor pra editar, tela cheia rola meia-tela sozinha, comando
;  LIST pagina tela-cheia-por-tela-cheia com pergunta S/N. Ver comentario
;  de topo de MamuteEditGui.pbi pro detalhe completo. Numeros sem sufixo
;  passam a ser hexadecimal por padrao (mudanca pedida em relacao ao manual
;  original, que usava decimal). So aceita/edita/lista o programa por hora
;  (Mamute_ParseAsmLine/Mamute_StoreAsmLine, MamuteSupport.pbi) - NEW/AUTO/
;  DELETE/RENUM e o assemblador de verdade (comando A) ficam pra sessoes
;  futuras.
;  Mais comandos entram aos poucos, sessao a sessao.
;
;  Historico de comandos (mesma sessao do SCR, pedido explicito do usuario):
;  Setas Cima/Baixo no campo MON> navegam pelo historico (MamuteGui_History(),
;  abaixo), persistido no arquivo de projeto atual via
;  ProjectDB::SetInfoValue/GetInfoValue (ProjectDB.pbi, XIncludeFile'd antes
;  deste arquivo) - ver MamuteGui_HistorySave()/Load().
;
;  Visual "terminal": fundo preto, texto monoespacado verde, ignorando o
;  tema da IDE de proposito (SetGadgetColor()/SetGadgetFont() explicitos,
;  nao SetWindowColor(..., Color_AppBg) do resto da IDE) - e pra lembrar um
;  terminal de verdade, nao mais um dialogo comum. Unico cuidado real:
;  App_StyleChildCallback (BadigEditor.pb) forca a fonte Segoe UI em TODO
;  controle nativo de QUALQUER janela no primeiro WM_PAINT dela (nao tem
;  como desligar isso por janela) - MamuteGui_ApplyRetroFont() e chamada de
;  novo logo antes do loop de eventos pra garantir que a fonte monoespacada
;  vence essa corrida.
; ------------------------------------------------------------
;

#MamuteGui_EnterShortcut = 9101
#MamuteGui_UpShortcut    = 9102
#MamuteGui_DownShortcut  = 9103

; MamuteGui_Font agora e' declarado em MamuteSupport.pbi (hoisted pra la -
; MamuteEditGui.pbi, incluido antes deste arquivo, tambem precisa dele).

; Historico de comandos digitados no MON> - navegavel com Setas Cima/Baixo
; (pedido explicito do usuario), persistido entre sessoes (ver
; MamuteGui_HistoryLoad()/Save() mais abaixo). Global (nao dentro de
; MamuteGui_State) porque sobrevive a varias aberturas/fechamentos da
; janela dentro da mesma sessao do editor, nao so enquanto a janela esta
; aberta.
Global NewList MamuteGui_History.s()
#MamuteGui_HistoryMax = 200 ; limite defensivo - nao deixa crescer sem fim

; Recarrega a fonte a partir de MamuteFontName/Size/Bold (MamuteSupport.pbi,
; "Configurar -> Mamute Assembler...") toda vez que a janela abre - nao
; reaproveita entre aberturas (ao contrario da versao anterior) porque o
; usuario pode ter trocado a configuracao desde a ultima vez; libera a fonte
; anterior antes pra nao vazar um HFONT a cada abertura.
Procedure MamuteGui_EnsureFont()
  If MamuteGui_Font <> -1
    FreeFont(MamuteGui_Font)
  EndIf
  Protected Style.i = 0
  If MamuteFontBold : Style = #PB_Font_Bold : EndIf
  MamuteGui_Font = LoadFont(#PB_Any, MamuteFontName, MamuteFontSize, Style)
EndProcedure

; Acrescenta Text ao log (Accum recebido/devolvido explicitamente, mesmo
; motivo de OMSXGui_AppendLog() em OpenMSXConsoleGui.pbi - nao confiar no
; EditorGadget "lembrar" o proprio conteudo) e rola pro fim.
Procedure.s MamuteGui_AppendLog(G_Log, Accum.s, Text.s)
  If Accum <> ""
    Accum + Chr(13) + Chr(10)
  EndIf
  Accum + Text
  SetGadgetText(G_Log, Accum)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    SendMessage_(GadgetID(G_Log), #EM_LINESCROLL, 0, 999999)
  CompilerEndIf
  ProcedureReturn Accum
EndProcedure

Structure MamuteGui_State
  LogAccum.s
  ShouldQuit.b
  HasLastSh.b   ; #True depois do 1o SH bem-sucedido nesta sessao da janela
  LastShAddr.i  ; endereco onde o ultimo SH achou algo - SH sem <end> continua daqui+1
  HasLastM.b    ; #True depois que a janela do M ja abriu ao menos uma vez
  LastMAddr.i   ; onde a janela do M ficou da ultima vez - M sem <endereco> reabre ali
  HasLastS.b    ; mesma ideia do M, mas rastreado separado (S tem "memoria" propria)
  LastSAddr.i
  DisplayMode.b ; comando C - modo de exibicao (0-3) que D/P/V vao usar; zero-inicializado = modo 0
  ; Registradores Z80 simulados (comando X, e agora tambem o motor de execucao real do
  ; comando G - MamuteZ80Cpu.pbi/MamuteDebuggerGui.pbi) - zero-inicializados (boot "limpo"),
  ; duram so a sessao da janela (mesmo espirito volatil do PAGE/DisplayMode).
  RegA.a : RegF.a : RegB.a : RegC.a : RegD.a : RegE.a : RegH.a : RegL.a
  RegIX.u : RegIY.u : RegSP.u
  HasLastL.b   ; #True depois do 1o L/LP bem-sucedido nesta sessao da janela
  LastLAddr.i  ; endereco logo apos a ultima instrucao mostrada - L/LP sem <endinic> continua dali
  ; Campos adicionados pro debugger visual (modulo 32 do SPEC, Fase 1) - PC nao existia antes
  ; (comando X nunca precisou dele), par alternado/I/R/IFF1/IFF2/IM idem. Ate 2 breakpoints,
  ; mesmo limite que a sintaxe do G ja aceitava desde o stub original.
  RegPC.u
  RegA2.a : RegF2.a : RegB2.a : RegC2.a : RegD2.a : RegE2.a : RegH2.a : RegL2.a
  RegI.a : RegR.a
  IFF1.b : IFF2.b : IM.a
  Halted.b
  HasBreak1.b : Break1Addr.u
  HasBreak2.b : Break2Addr.u
EndStructure

; Persistencia do historico - pedido explicito do usuario ("guarde inclusive
; entre secoes no arquivo de projeto"). Reaproveita ProjectDB::SetInfoValue/
; GetInfoValue (tabela generica "project_info", ProjectDB.pbi, XIncludeFile'd
; antes deste arquivo em BadigEditor.pb) - mesma chave/valor ja usada por
; "Configurar -> Projeto..." pros 3 booleans de override. Nao existe conceito
; separado de "projeto padrao" no codigo - ProjectDB::EnsureOpen() (chamado
; internamente por SetInfoValue/GetInfoValue) ja abre um projeto temporario
; implicito (noname.msxproject) sozinho na primeira vez que algo e gravado,
; se o usuario ainda nao tiver criado/aberto um projeto de verdade - "salve
; silenciosamente no projeto padrao" pedido pelo usuario ja e o comportamento
; padrao do ProjectDB, nada extra precisa ser feito aqui. Lista codificada
; como uma unica string separada por Chr(10), mesmo idioma de
; StoreAsmSubProject()/FetchAsmSubProject() (ProjectDB.pbi).
Procedure MamuteGui_HistorySave()
  Protected Joined.s = ""
  ForEach MamuteGui_History()
    If Joined <> ""
      Joined + Chr(10)
    EndIf
    Joined + MamuteGui_History()
  Next
  ProjectDB::SetInfoValue("mamute_mon_history", Joined)
EndProcedure

Procedure MamuteGui_HistoryLoad()
  ClearList(MamuteGui_History())
  Protected Raw.s = ProjectDB::GetInfoValue("mamute_mon_history")
  If Raw = ""
    ProcedureReturn
  EndIf
  Protected i.i, n.i = CountString(Raw, Chr(10)) + 1
  For i = 1 To n
    AddElement(MamuteGui_History())
    MamuteGui_History() = StringField(Raw, i, Chr(10))
  Next
EndProcedure

; Acrescenta Cmd ao historico (MamuteGui_History(), topo do arquivo) -
; ignora repeticao consecutiva do mesmo comando (nao faz sentido acumular
; "BA" dez vezes seguidas so porque o usuario apertou fleche-cima-Enter
; varias vezes) e derruba a entrada mais antiga quando passa do limite.
Procedure MamuteGui_HistoryAdd(Cmd.s)
  If ListSize(MamuteGui_History()) > 0
    LastElement(MamuteGui_History())
    If MamuteGui_History() = Cmd
      ProcedureReturn
    EndIf
  EndIf
  LastElement(MamuteGui_History())
  AddElement(MamuteGui_History())
  MamuteGui_History() = Cmd
  If ListSize(MamuteGui_History()) > #MamuteGui_HistoryMax
    FirstElement(MamuteGui_History())
    DeleteElement(MamuteGui_History())
  EndIf
EndProcedure

; Mostra o mapeamento ATIVO agora (MamutePageMap(), MamuteSupport.pbi) - uma
; linha por pagina, endereco real + slot comutado ali. Usado tanto por
; "PAGE ?" quanto logo apos qualquer "PAGE"/"PAGE X,Y,Z,W" bem-sucedido
; (feedback imediato, mesmo espirito de monitores de verdade ecoarem o
; estado apos um SET).
Procedure.s MamuteGui_ShowPageMap(G_Log, Accum.s)
  Protected Pagina.i
  For Pagina = 0 To 3
    Accum = MamuteGui_AppendLog(G_Log, Accum, "PAGE" + Str(Pagina) + "(" + Mamute_PageRangeText(Pagina) +
                                              ") SLOT " + Str(MamutePageMap(Pagina)))
  Next
  ProcedureReturn Accum
EndProcedure

; Token.s precisa ser 1+ digitos representando um numero de slot valido
; (0-3) - usado pra validar cada um dos 4 argumentos de "PAGE X,Y,Z,W".
Procedure.b MamuteGui_IsValidSlotToken(Token.s)
  If Token = ""
    ProcedureReturn #False
  EndIf
  Protected i
  For i = 1 To Len(Token)
    If Mid(Token, i, 1) < "0" Or Mid(Token, i, 1) > "9"
      ProcedureReturn #False
    EndIf
  Next
  ProcedureReturn Bool(Val(Token) >= 0 And Val(Token) <= 3)
EndProcedure

; PAGE (Args=""): coloca todas as 4 paginas no slot marcado como RAM.
; PAGE ? (Args="?"): so mostra o mapeamento ativo, sem mexer em nada.
; PAGE X,Y,Z,W (Args="X,Y,Z,W"): troca o mapeamento ativo pros 4 slots
; informados (pagina 0=X, 1=Y, 2=Z, 3=W). Qualquer outra forma = erro.
Procedure MamuteGui_CmdPage(G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    Protected RamSlot.i = Mamute_FindRamSlot()
    If RamSlot = -1
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?NENHUM SLOT DE RAM CONFIGURADO")
      ProcedureReturn
    EndIf
    Protected P.i
    For P = 0 To 3
      MamutePageMap(P) = RamSlot
    Next
    *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
    ProcedureReturn
  EndIf

  If Args = "?"
    *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
    ProcedureReturn
  EndIf

  If CountString(Args, ",") <> 3
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Dim ParsedSlots.i(3)
  Protected Idx.i, Token.s
  For Idx = 0 To 3
    Token = Trim(StringField(Args, Idx + 1, ","))
    If Not MamuteGui_IsValidSlotToken(Token)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    ParsedSlots(Idx) = Val(Token)
  Next

  For Idx = 0 To 3
    MamutePageMap(Idx) = ParsedSlots(Idx)
  Next
  *State\LogAccum = MamuteGui_ShowPageMap(G_Log, *State\LogAccum)
EndProcedure

; DM <endereco>[,<deslocamento>] - abre a janela de despejo/edicao de
; memoria (MamuteDumpGui.pbi, XIncludeFile'd antes deste arquivo) no
; endereco (hexa - "os enderecos em hexa sao o padrao de entrada de todos
; os comandos", pedido explicito do usuario) informado, com o deslocamento
; ASCII opcional (tambem hexa, com sinal, -7Fh a 80h). Vazio = sintaxe
; invalida (endereco e obrigatorio); deslocamento ausente = 0.
Procedure MamuteGui_CmdDm(Win, G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected AddrToken.s, OffsetToken.s
  Protected CommaPos.i = FindString(Args, ",")
  If CommaPos > 0
    AddrToken = Trim(Left(Args, CommaPos - 1))
    OffsetToken = Trim(Mid(Args, CommaPos + 1))
  Else
    AddrToken = Trim(Args)
    OffsetToken = ""
  EndIf

  Protected Addr.i
  If Not Mamute_ParseHexAddr(AddrToken, @Addr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected DmOffset.i = 0
  If OffsetToken <> ""
    If Not Mamute_ParseHexOffset(OffsetToken, @DmOffset)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  MamuteDump_Open(Win, Addr, DmOffset)
EndProcedure

; ZAP <setor inicial>[,<deslocamento>] - "muito parecido com o DM", pedido
; explicito do usuario, so que edita SETORES de uma imagem de disco (.dsk)
; em vez da memoria simulada do MSX - pede o arquivo (MamuteZapGui.pbi,
; XIncludeFile'd antes deste arquivo) antes de abrir a grade. <setor
; inicial> tambem em hexa (mesma regra do DM); <deslocamento> identico ao
; do DM (opcional, hexa com sinal, -7Fh a 80h).
Procedure MamuteGui_CmdZap(Win, G_Log, *State.MamuteGui_State, Args.s)
  If Args = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected SectorToken.s, OffsetToken.s
  Protected CommaPos.i = FindString(Args, ",")
  If CommaPos > 0
    SectorToken = Trim(Left(Args, CommaPos - 1))
    OffsetToken = Trim(Mid(Args, CommaPos + 1))
  Else
    SectorToken = Trim(Args)
    OffsetToken = ""
  EndIf

  Protected Sector.i
  If Not Mamute_ParseHexAddr(SectorToken, @Sector)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected ZapOffset.i = 0
  If OffsetToken <> ""
    If Not Mamute_ParseHexOffset(OffsetToken, @ZapOffset)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  MamuteZap_Open(Win, Sector, ZapOffset)
EndProcedure

; SCR <endinic>,<dx>,<dy>[,<modo>] - abre a janela de display grafico
; (MamuteScrGui.pbi, XIncludeFile'd antes deste arquivo). Todos os numeros
; sao hexa ("os enderecos em hexa sao o padrao de entrada de todos os
; comandos") - <endinic> 1-4 digitos, <dx>/<dy> 1-2 digitos (>=1, uma grade
; vazia nao faz sentido), <modo> opcional 1 digito (0 ou 1, default 0).
; Qualquer coisa fora disso (numero de campos errado, dx/dy zero, modo fora
; de 0-1) mostra ?ERRO DE SINTAXE, mesmo padrao do PAGE/DM/ZAP.
Procedure MamuteGui_CmdScr(Win, G_Log, *State.MamuteGui_State, Args.s)
  Protected FieldCount.i = CountString(Args, ",") + 1
  If Args = "" Or (FieldCount <> 3 And FieldCount <> 4)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected AddrToken.s = Trim(StringField(Args, 1, ","))
  Protected DxToken.s = Trim(StringField(Args, 2, ","))
  Protected DyToken.s = Trim(StringField(Args, 3, ","))
  Protected ModoToken.s = ""
  If FieldCount = 4
    ModoToken = Trim(StringField(Args, 4, ","))
  EndIf

  Protected Addr.i
  If Not Mamute_ParseHexAddr(AddrToken, @Addr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Dx.i, Dy.i
  If Not Mamute_IsHexString(DxToken, 2) Or Not Mamute_IsHexString(DyToken, 2)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  Dx = Val("$" + DxToken)
  Dy = Val("$" + DyToken)
  If Dx < 1 Or Dy < 1
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Modo.i = 0
  If ModoToken <> ""
    If Not Mamute_IsHexString(ModoToken, 1)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    Modo = Val("$" + ModoToken)
    If Modo <> 0 And Modo <> 1
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  MamuteScr_Open(Win, Addr, Dx, Dy, Modo)
EndProcedure

; SH [<end>],<bt>[,[<bt>]...] busca uma sequencia de bytes em hexa pela
; memoria simulada; SH [<end>],'<string> busca um TEXTO, testando todos os
; deslocamentos possiveis (-7F a 80, mesma faixa do DM/ZAP) - acha tanto
; texto puro (deslocamento 0) quanto texto "cifrado" por deslocamento fixo
; (truque comum de jogos antigos pra nao deixar dialogo legivel num editor
; de disco cru). <end> omitido continua a busca a partir do ultimo endereco
; ACHADO + 1 (State\LastShAddr) - so faz sentido depois de um SH bem
; sucedido nesta mesma sessao da janela (State\HasLastSh). Vazio entre
; virgulas no modo bytes = curinga ("aquele byte pode ser qualquer um").
; Nao abre janela nenhuma - so mostra o resultado no log do MON>, comando de
; resposta rapida como PAGE.
Procedure MamuteGui_CmdSh(G_Log, *State.MamuteGui_State, Args.s)
  Protected CommaPos.i = FindString(Args, ",")
  If Args = "" Or CommaPos = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected AddrToken.s = Trim(Left(Args, CommaPos - 1))
  Protected Rest.s = Mid(Args, CommaPos + 1)

  Protected StartAddr.i
  If AddrToken = ""
    If Not *State\HasLastSh
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    StartAddr = (*State\LastShAddr + 1) & $FFFF
  Else
    If Not Mamute_ParseHexAddr(AddrToken, @StartAddr)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  Protected TrimmedRest.s = Trim(Rest)
  Protected Found.b = #False, FoundAddr.i, FoundOffset.i
  Protected Try.i, CandAddr.i, j.i, Ok.b

  If Left(TrimmedRest, 1) = "'"
    ; Modo texto - "no minimo, duas letras" (pedido do manual original).
    Protected Target.s = Mid(TrimmedRest, 2)
    If Right(Target, 1) = "'"
      Target = Left(Target, Len(Target) - 1)
    EndIf
    If Len(Target) < 2
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf

    Protected TargetLen.i = Len(Target)
    Protected FirstRaw.a, RawDiff.i, NormOff.i, Rb.a
    For Try = 0 To 65535
      CandAddr = (StartAddr + Try) & $FFFF
      FirstRaw = Mamute_ReadByte(CandAddr)
      RawDiff = Asc(Left(Target, 1)) - FirstRaw
      NormOff = ((RawDiff + 127) % 256 + 256) % 256 - 127
      Ok = #True
      For j = 0 To TargetLen - 1
        Rb = Mamute_ReadByte((CandAddr + j) & $FFFF)
        If ((Rb + NormOff) & $FF) <> Asc(Mid(Target, j + 1, 1))
          Ok = #False
          Break
        EndIf
      Next
      If Ok
        Found = #True : FoundAddr = CandAddr : FoundOffset = NormOff
        Break
      EndIf
    Next

    If Found
      Protected Sign.s = "+"
      Protected AbsOff.i = FoundOffset
      If AbsOff < 0
        Sign = "-"
        AbsOff = -AbsOff
      EndIf
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
        "ACHADO EM " + Mamute_Hex4(FoundAddr) + " DESLOC " + Sign + Mamute_Hex2(AbsOff))
    Else
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "NAO ENCONTRADO")
    EndIf

  Else
    ; Modo bytes - pelo menos 1 byte, os demais (e o proprio primeiro) podem
    ; ser vazios (curinga).
    Protected FieldCount.i = CountString(Rest, ",") + 1
    Protected Dim Pattern.i(FieldCount - 1) ; -1 = curinga
    Protected i.i, Token.s
    For i = 1 To FieldCount
      Token = Trim(StringField(Rest, i, ","))
      If Token = ""
        Pattern(i - 1) = -1
      Else
        If Not Mamute_IsHexString(Token, 2)
          *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
          ProcedureReturn
        EndIf
        Pattern(i - 1) = Val("$" + Token)
      EndIf
    Next

    For Try = 0 To 65535
      CandAddr = (StartAddr + Try) & $FFFF
      Ok = #True
      For j = 0 To FieldCount - 1
        If Pattern(j) <> -1
          If Mamute_ReadByte((CandAddr + j) & $FFFF) <> Pattern(j)
            Ok = #False
            Break
          EndIf
        EndIf
      Next
      If Ok
        Found = #True : FoundAddr = CandAddr
        Break
      EndIf
    Next

    If Found
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "ACHADO EM " + Mamute_Hex4(FoundAddr))
    Else
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "NAO ENCONTRADO")
    EndIf
  EndIf

  If Found
    *State\LastShAddr = FoundAddr
    *State\HasLastSh = #True
  EndIf
EndProcedure

; MS <end>,[<dslc>],'<string> grava uma STRING crua na memoria simulada a
; partir de <end> - <dslc> opcional (hexa com sinal, -7F a 80, mesma faixa
; do DM/ZAP; 0 se omitido) "cifra" cada caractere igual o bloco de texto do
; DM: RawByte = (CodigoDoChar - Deslocamento) & FF - o mesmo texto reaparece
; legivel se depois for lido (DM) ou procurado (SH) com o MESMO
; deslocamento. Sem janela - so confirma no log do MON>. Escrita silenciosa
; em celulas que nao sejam RAM (Mamute_WriteByte ja recusa, mesma regra do
; DM) - nao ha como distinguir isso no resultado, mesmo espirito do DM.
Procedure MamuteGui_CmdMs(G_Log, *State.MamuteGui_State, Args.s)
  Protected CommaPos1.i = FindString(Args, ",")
  If Args = "" Or CommaPos1 = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected AddrToken.s = Trim(Left(Args, CommaPos1 - 1))
  Protected Addr.i
  If Not Mamute_ParseHexAddr(AddrToken, @Addr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Rest.s = Mid(Args, CommaPos1 + 1)
  Protected TrimmedRest.s = Trim(Rest)
  Protected DslcToken.s, StringPart.s

  If Left(TrimmedRest, 1) = "'"
    DslcToken = ""
    StringPart = Mid(TrimmedRest, 2)
  Else
    Protected CommaPos2.i = FindString(Rest, ",")
    If CommaPos2 = 0
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    DslcToken = Trim(Left(Rest, CommaPos2 - 1))
    Protected AfterDslc.s = Trim(Mid(Rest, CommaPos2 + 1))
    If Left(AfterDslc, 1) <> "'"
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    StringPart = Mid(AfterDslc, 2)
  EndIf

  If Right(StringPart, 1) = "'"
    StringPart = Left(StringPart, Len(StringPart) - 1)
  EndIf
  If StringPart = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Dslc.i = 0
  If DslcToken <> ""
    If Not Mamute_ParseHexOffset(DslcToken, @Dslc)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  Protected i.i
  For i = 1 To Len(StringPart)
    Mamute_WriteByte((Addr + i - 1) & $FFFF, (Asc(Mid(StringPart, i, 1)) - Dslc) & $FF)
  Next

  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "GRAVADO EM " + Mamute_Hex4(Addr))
EndProcedure

; LOAD - carrega um arquivo (janela de escolha, sem digitar nome/CAS:/A: -
; pedido explicito do usuario, diferente do "LOAD <arquivo>,B" do manual
; original) pra dentro de um SLOT escolhido pelo usuario (sempre perguntado,
; sugerindo o slot com RAM configurada - Mamute_FindRamSlot()). Sem
; argumentos - tudo interativo, por isso nao recebe Win (OpenFileRequester/
; InputRequester sao sempre modais da aplicacao inteira no PureBasic, nao
; precisam de handle de janela pai). Grava DIRETO em MamuteMem(Slot,...) -
; nao passa por Mamute_WriteByte()/PAGE, porque aqui o usuario esta
; escolhendo o slot fisico explicitamente (simula inserir um cartucho/
; carregar dado naquele slot), independente do mapeamento ativo agora.
; Tambem ajusta MamuteCfgCell() das paginas tocadas (RAM ou ROM, conforme o
; tipo de arquivo) - SO em memoria, nunca chama MamuteCfg_Save() - efeito
; dura so esta sessao da janela do Mamute Assembler, igual "inserir um
; cartucho" nao reescreve a configuracao salva do usuario. `.CAS` avisado
; como nao suportado ainda (pedido explicito) em vez de tentar interpretar
; errado.
; Args.s (opcional) - pedido explicito do usuario, "vamos permitir nome no
; LOAD, mas ele nao carrega, apenas sugere o nome na caixa de dialogo" - so
; pre-preenche o campo de nome do OpenFileRequester e, se a extensao do
; nome sugerido nao for .bin/.rom, acrescenta ela ao filtro (ex.: "LOAD
; alfabeto.alf" mostra "*.alf;*.bin;*.rom" no filtro padrao) - nunca pula o
; dialogo nem carrega direto.
Procedure MamuteGui_CmdLoad(G_Log, *State.MamuteGui_State, Win, Args.s)
  Protected SuggestedName.s = Trim(Args)
  Protected FilterPattern.s = "*.bin;*.rom"
  If SuggestedName <> ""
    Protected SuggestedExt.s = LCase(GetExtensionPart(SuggestedName))
    If SuggestedExt <> "" And SuggestedExt <> "bin" And SuggestedExt <> "rom"
      FilterPattern = "*." + SuggestedExt + ";" + FilterPattern
    EndIf
  EndIf
  Protected Filter.s = "Arquivos (" + FilterPattern + ")|" + FilterPattern + "|Todos os arquivos (*.*)|*.*"
  Protected FilePath.s = OpenFileRequester("Carregar arquivo - LOAD", SuggestedName, Filter, 0)
  If FilePath = ""
    ProcedureReturn ; cancelado - aborta sem log, mesmo espirito do ZAP
  EndIf

  Protected Ext.s = LCase(GetExtensionPart(FilePath))
  If Ext = "cas"
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ARQUIVOS .CAS NAO SUPORTADOS AINDA")
    ProcedureReturn
  EndIf

  Protected FSize.i = FileSize(FilePath)
  If FSize <= 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ARQUIVO INVALIDO")
    ProcedureReturn
  EndIf

  Protected RamSlot.i = Mamute_FindRamSlot()
  Protected SuggestSlot.s = "0"
  If RamSlot >= 0
    SuggestSlot = Str(RamSlot)
  EndIf
  Protected SlotAnswer.s = Trim(InputRequester("Carregar arquivo - LOAD",
    "Slot (0-3) para carregar - RAM sugerida: Slot " + SuggestSlot, SuggestSlot, 0, WindowID(Win)))
  If SlotAnswer = ""
    ProcedureReturn ; cancelado
  EndIf
  If Len(SlotAnswer) <> 1 Or SlotAnswer < "0" Or SlotAnswer > "3"
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?SLOT INVALIDO")
    ProcedureReturn
  EndIf
  Protected ChosenSlot.i = Val(SlotAnswer)

  Protected Fh = ReadFile(#PB_Any, FilePath)
  If Not Fh
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ARQUIVO INVALIDO")
    ProcedureReturn
  EndIf
  Protected Dim Buf.a(FSize - 1)
  ReadData(Fh, @Buf(0), FSize)
  CloseFile(Fh)

  Protected LoadAddr.i, DataOffset.i, DataLen.i, i.i, Addr.i, Pagina.i, Offset.i
  Protected Dim TouchedPage.b(3)
  Protected CellType.b

  If Ext = "rom"
    ; Cartucho ROM - endereco sempre 4000 (Pagina 1); ate 32KB tambem ocupa
    ; 8000 (Pagina 2). Mais que isso precisaria de mapper/bank switching,
    ; que este simulador nao faz.
    If FSize > 32768
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ROM MAIOR QUE 32KB NAO SUPORTADA")
      ProcedureReturn
    EndIf
    LoadAddr = $4000
    DataOffset = 0
    DataLen = FSize
    CellType = #MamuteMem_ROM
  Else
    ; Binario - com header BLOAD (0xFE + inicio/fim/exec, 2 bytes cada,
    ; little-endian - formato real do BSAVE do MSX-BASIC) carrega no
    ; endereco do header; sem header, pergunta o endereco ao usuario.
    If FSize >= 7 And Buf(0) = $FE
      LoadAddr = Buf(1) | (Buf(2) << 8)
      DataOffset = 7
      DataLen = FSize - 7
    Else
      Protected AddrAnswer.s = Trim(InputRequester("Carregar arquivo - LOAD",
        "Arquivo sem cabecalho BLOAD - endereco inicial (hexa, 0000-FFFF):", "0000", 0, WindowID(Win)))
      If AddrAnswer = ""
        ProcedureReturn ; cancelado
      EndIf
      If Not Mamute_ParseHexAddr(AddrAnswer, @LoadAddr)
        *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
        ProcedureReturn
      EndIf
      DataOffset = 0
      DataLen = FSize
    EndIf
    CellType = #MamuteMem_RAM
  EndIf

  For i = 0 To DataLen - 1
    Addr = (LoadAddr + i) & $FFFF
    Pagina = (Addr >> 14) & 3
    Offset = Addr & 16383
    MamuteMem(ChosenSlot, Pagina, Offset) = Buf(DataOffset + i)
    TouchedPage(Pagina) = #True
  Next
  For Pagina = 0 To 3
    If TouchedPage(Pagina)
      MamuteCfgCell(ChosenSlot, Pagina)\Tipo = CellType
    EndIf
  Next

  Protected FinalAddr.i = (LoadAddr + DataLen - 1) & $FFFF
  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
    "CARREGADO NO SLOT " + Str(ChosenSlot) + " EM " + Mamute_Hex4(LoadAddr) +
    " - TAMANHO " + Mamute_Hex4(DataLen) + " - FIM " + Mamute_Hex4(FinalAddr))
EndProcedure

; SAVE [<nome>][,<endinic>,<endfim>[,<endexec>]] - abre a janela do SAVE
; (MamuteSaveGui.pbi, XIncludeFile'd antes deste arquivo), que faz todo o
; trabalho de verdade (escolher arquivo, slot, formato, gravar) e devolve
; uma linha de resultado pro log do MON> (ou "" se cancelado). <nome> e os
; enderecos sao so SUGESTOES pra pre-preencher a janela - nunca salvam
; nada sozinhos, pedido explicito do usuario ("mas ao abrir o dialogo...
; permita que o usuario edite"). Campo de nome vazio (`,4000,7FFF`) e
; aceito, mesma convencao do SH/MS.
Procedure MamuteGui_CmdSave(Win, G_Log, *State.MamuteGui_State, Args.s)
  Protected SuggestedName.s = ""
  Protected HasAddrs.b = #False
  Protected InStart.i = 0, InEnd.i = 0, InExec.i = 0

  If Args <> ""
    Protected FieldCount.i = CountString(Args, ",") + 1
    SuggestedName = Trim(StringField(Args, 1, ","))
    Select FieldCount
      Case 1
        ; so o nome, sem enderecos - janela pede o resto
      Case 3, 4
        Protected StartToken.s = Trim(StringField(Args, 2, ","))
        Protected EndToken.s = Trim(StringField(Args, 3, ","))
        If Not Mamute_ParseHexAddr(StartToken, @InStart) Or Not Mamute_ParseHexAddr(EndToken, @InEnd)
          *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
          ProcedureReturn
        EndIf
        If FieldCount = 4
          Protected ExecToken.s = Trim(StringField(Args, 4, ","))
          If Not Mamute_ParseHexAddr(ExecToken, @InExec)
            *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
            ProcedureReturn
          EndIf
        Else
          InExec = InStart
        EndIf
        HasAddrs = #True
      Default
        *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
        ProcedureReturn
    EndSelect
  EndIf

  Protected Dim NoExplicitBuf.a(0)
  Protected ResultMsg.s = MamuteSave_Open(Win, SuggestedName, HasAddrs, InStart, InEnd, InExec, #False, NoExplicitBuf())
  If ResultMsg <> ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, ResultMsg)
  EndIf
EndProcedure

; M [<endereco>] - edicao rapida (MamuteMGui.pbi, mesmo esquema do DM: setas/
; PgUp/PgDn/TAB/+-/botoes, mas hexa digitado tecla-a-tecla direto, sem campo
; de edicao - ver comentario de topo de MamuteMGui.pbi). <endereco> omitido
; continua de onde a janela do M ficou da ultima vez (State\LastMAddr) - so
; funciona depois que o M ja abriu ao menos uma vez nesta sessao da janela.
Procedure MamuteGui_CmdM(Win, G_Log, *State.MamuteGui_State, Args.s)
  Protected Addr.i
  Protected Trimmed.s = Trim(Args)
  If Trimmed = ""
    If Not *State\HasLastM
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    Addr = *State\LastMAddr
  Else
    If Not Mamute_ParseHexAddr(Trimmed, @Addr)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  *State\LastMAddr = MamuteM_Open(Win, Addr, 0, #False)
  *State\HasLastM = #True
EndProcedure

; S [<endereco>] - "so como curiosidade", pedido do usuario: funciona igual
; ao M, mas escreve os nibbles usando as 16 teclas CONFIGURAVEIS em
; "Configurar -> Mamute Assembler..." (MamuteSKeyMap(), MamuteSupport.pbi)
; em vez de 0-9/A-F fixos. "Memoria" de ultimo endereco separada da do M
; (State\LastSAddr), mesmo espirito do comando S original ser uma variacao
; do M, nao o mesmo estado.
Procedure MamuteGui_CmdS(Win, G_Log, *State.MamuteGui_State, Args.s)
  Protected Addr.i
  Protected Trimmed.s = Trim(Args)
  If Trimmed = ""
    If Not *State\HasLastS
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
    Addr = *State\LastSAddr
  Else
    If Not Mamute_ParseHexAddr(Trimmed, @Addr)
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
      ProcedureReturn
    EndIf
  EndIf

  *State\LastSAddr = MamuteM_Open(Win, Addr, 0, #True)
  *State\HasLastS = #True
EndProcedure

; C <modo> - define o modo de exibicao (0-3) que os comandos D/P/V (ainda
; nao implementados) vao usar pra formatar a saida. So guarda o estado
; (State\DisplayMode, dura so esta sessao da janela - nao persiste em
; mamute_settings.json, mesmo espirito volatil do PAGE) e confirma no log,
; mesmo idioma do PAGE ecoando o estado apos uma mudanca. Precisa de espaco
; entre o verbo e o numero ("C 1") - o "C1" colado do manual original nao e
; reconhecido, porque MamuteGui_Dispatch() sempre separa verbo/argumentos
; pelo primeiro espaco.
Procedure MamuteGui_CmdC(G_Log, *State.MamuteGui_State, Args.s)
  Protected Trimmed.s = Trim(Args)
  If Not Mamute_IsHexString(Trimmed, 1)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  Protected Mode.i = Val(Trimmed)
  If Mode < 0 Or Mode > 3
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  *State\DisplayMode = Mode
  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "MODO " + Str(Mode) + ": " + Mamute_DisplayModeText(Mode))
EndProcedure

; Parser comum de "<endinic>[,<endfim>]" usado por D/P/V - IsVram escolhe
; entre Mamute_ParseHexAddr (RAM/ROM, 4 digitos, mapeamento PAGE ativo) e
; Mamute_ParseVramAddr (VRAM plana, 1-5 digitos, validada contra
; MamuteVramSize). Sem <endfim>, mostra so 16 bytes (pedido explicito do
; manual original), limitado ao teto do espaco de enderecos (sem
; wraparound, ao contrario do SH/M) - passar do teto e erro de sintaxe.
Procedure.b MamuteGui_ParseDpvArgs(Args.s, IsVram.b, *OutStart.Integer, *OutEnd.Integer)
  Protected CommaPos.i = FindString(Args, ",")
  Protected StartToken.s, EndToken.s
  If CommaPos > 0
    StartToken = Trim(Left(Args, CommaPos - 1))
    EndToken = Trim(Mid(Args, CommaPos + 1))
  Else
    StartToken = Trim(Args)
    EndToken = ""
  EndIf

  If StartToken = ""
    ProcedureReturn #False
  EndIf

  Protected StartAddr.i, EndAddr.i, MaxAddr.i
  If IsVram
    If Not Mamute_ParseVramAddr(StartToken, @StartAddr)
      ProcedureReturn #False
    EndIf
    MaxAddr = MamuteVramSize - 1
  Else
    If Not Mamute_ParseHexAddr(StartToken, @StartAddr)
      ProcedureReturn #False
    EndIf
    MaxAddr = $FFFF
  EndIf

  If EndToken = ""
    EndAddr = StartAddr + 15
    If EndAddr > MaxAddr : EndAddr = MaxAddr : EndIf
  Else
    If IsVram
      If Not Mamute_ParseVramAddr(EndToken, @EndAddr)
        ProcedureReturn #False
      EndIf
    Else
      If Not Mamute_ParseHexAddr(EndToken, @EndAddr)
        ProcedureReturn #False
      EndIf
    EndIf
    If EndAddr < StartAddr
      ProcedureReturn #False
    EndIf
  EndIf

  *OutStart\i = StartAddr
  *OutEnd\i = EndAddr
  ProcedureReturn #True
EndProcedure

; D <endinic>[,<endfim>] - despejo formatado da RAM/ROM direto no log do
; MON>, no formato definido pelo comando C (State\DisplayMode). Le via
; Mamute_ReadByte() - resolve pelo mapeamento PAGE ativo agora, mesma regra
; de leitura do DM.
Procedure MamuteGui_CmdD(G_Log, *State.MamuteGui_State, Args.s)
  Protected StartAddr.i, EndAddr.i
  If Not MamuteGui_ParseDpvArgs(Args, #False, @StartAddr, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Mamute_BuildDumpLines(Lines(), StartAddr, EndAddr, *State\DisplayMode, #False)
  ForEach Lines()
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, Lines())
  Next
EndProcedure

; P <endinic>[,<endfim>] - mesmo despejo do D, mas "na impressora": ainda
; nao existe driver de impressora de verdade (Epson FX-80 fica pra uma
; sessao futura, pedido explicito do usuario), entao por hora gera um PDF A4
; simples (Mamute_SavePdfListing(), MamutePdf.pbi, XIncludeFile'd antes
; deste arquivo) e abre "Salvar como" no final.
Procedure MamuteGui_CmdP(G_Log, *State.MamuteGui_State, Args.s)
  Protected StartAddr.i, EndAddr.i
  If Not MamuteGui_ParseDpvArgs(Args, #False, @StartAddr, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Mamute_BuildDumpLines(Lines(), StartAddr, EndAddr, *State\DisplayMode, #False)

  Protected FilePath.s = SaveFileRequester("Salvar listagem (P) como PDF", "listagem.pdf", "PDF (*.pdf)|*.pdf", 0)
  If FilePath = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "CANCELADO")
    ProcedureReturn
  EndIf
  If LCase(Right(FilePath, 4)) <> ".pdf"
    FilePath + ".pdf"
  EndIf

  Protected Header.s = "P " + Mamute_Hex4(StartAddr) + "-" + Mamute_Hex4(EndAddr) + " MODO " + Str(*State\DisplayMode)
  If Mamute_SavePdfListing(FilePath, Lines(), Header)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "PDF GRAVADO: " + FilePath)
  Else
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO AO GRAVAR PDF")
  EndIf
EndProcedure

; V <endinic>[,<endfim>] - igual ao P, mas le da VRAM simulada (MamuteVRAM(),
; endereco plano ate MamuteVramSize-1, sem PAGE nem banco algum - VRAM nunca
; foi mapeada no espaco de enderecos do Z80 de verdade, entao a mesma regra
; nao se aplica aqui) em vez da RAM/ROM.
Procedure MamuteGui_CmdV(G_Log, *State.MamuteGui_State, Args.s)
  Protected StartAddr.i, EndAddr.i
  If Not MamuteGui_ParseDpvArgs(Args, #True, @StartAddr, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Mamute_BuildDumpLines(Lines(), StartAddr, EndAddr, *State\DisplayMode, #True)

  Protected FilePath.s = SaveFileRequester("Salvar listagem (V) como PDF", "listagem_vram.pdf", "PDF (*.pdf)|*.pdf", 0)
  If FilePath = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "CANCELADO")
    ProcedureReturn
  EndIf
  If LCase(Right(FilePath, 4)) <> ".pdf"
    FilePath + ".pdf"
  EndIf

  Protected Header.s = "V " + Mamute_HexPad(StartAddr, 5) + "-" + Mamute_HexPad(EndAddr, 5) + " MODO " + Str(*State\DisplayMode)
  If Mamute_SavePdfListing(FilePath, Lines(), Header)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "PDF GRAVADO: " + FilePath)
  Else
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO AO GRAVAR PDF")
  EndIf
EndProcedure

; T <endinic>,<endfim>,<enddest> - transfere o bloco [endinic,endfim] (RAM/ROM,
; mapeamento PAGE ativo agora) pra um novo bloco iniciado em <enddest>. Sem
; wraparound (mesma regra do D/P/V) - se <enddest> + tamanho do bloco passar
; de FFFF, e ?ERRO DE SINTAXE, nao da a volta pro 0000. Suporta origem/destino
; sobrepostos: copia de tras pra frente quando <enddest> > <endinic> (senao a
; copia sobrescreveria bytes de origem ainda nao lidos), de frente pra tras
; caso contrario - mesmo algoritmo de um memmove seguro.
Procedure MamuteGui_CmdT(G_Log, *State.MamuteGui_State, Args.s)
  Protected CommaPos1.i = FindString(Args, ",")
  If CommaPos1 = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  Protected Rest1.s = Mid(Args, CommaPos1 + 1)
  Protected CommaPos2.i = FindString(Rest1, ",")
  If CommaPos2 = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected StartToken.s = Trim(Left(Args, CommaPos1 - 1))
  Protected EndToken.s = Trim(Left(Rest1, CommaPos2 - 1))
  Protected DestToken.s = Trim(Mid(Rest1, CommaPos2 + 1))

  Protected StartAddr.i, EndAddr.i, DestAddr.i
  If Not Mamute_ParseHexAddr(StartToken, @StartAddr) Or Not Mamute_ParseHexAddr(EndToken, @EndAddr) Or
     Not Mamute_ParseHexAddr(DestToken, @DestAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  If EndAddr < StartAddr
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Length.i = EndAddr - StartAddr + 1
  If DestAddr + Length - 1 > $FFFF
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected i.i
  If DestAddr > StartAddr
    For i = Length - 1 To 0 Step -1
      Mamute_WriteByte(DestAddr + i, Mamute_ReadByte(StartAddr + i))
    Next
  Else
    For i = 0 To Length - 1
      Mamute_WriteByte(DestAddr + i, Mamute_ReadByte(StartAddr + i))
    Next
  EndIf

  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
    "TRANSFERIDO " + Mamute_Hex4(StartAddr) + "-" + Mamute_Hex4(EndAddr) + " PARA " + Mamute_Hex4(DestAddr))
EndProcedure

; F <endinic>,<endfim>,<byte> - preenche o bloco [endinic,endfim] (RAM/ROM,
; mapeamento PAGE ativo agora) inteiro com <byte> (1-2 digitos hexa).
; Escrita silenciosa em celulas que nao sejam RAM (Mamute_WriteByte ja
; recusa, mesma regra do DM/MS/T).
Procedure MamuteGui_CmdF(G_Log, *State.MamuteGui_State, Args.s)
  Protected CommaPos1.i = FindString(Args, ",")
  If CommaPos1 = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  Protected Rest1.s = Mid(Args, CommaPos1 + 1)
  Protected CommaPos2.i = FindString(Rest1, ",")
  If CommaPos2 = 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected StartToken.s = Trim(Left(Args, CommaPos1 - 1))
  Protected EndToken.s = Trim(Left(Rest1, CommaPos2 - 1))
  Protected ByteToken.s = Trim(Mid(Rest1, CommaPos2 + 1))

  Protected StartAddr.i, EndAddr.i
  If Not Mamute_ParseHexAddr(StartToken, @StartAddr) Or Not Mamute_ParseHexAddr(EndToken, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  If EndAddr < StartAddr
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  If Not Mamute_IsHexString(ByteToken, 2)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  Protected FillByte.i = Val("$" + ByteToken)

  Protected Addr.i
  For Addr = StartAddr To EndAddr
    Mamute_WriteByte(Addr, FillByte)
  Next

  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
    "PREENCHIDO " + Mamute_Hex4(StartAddr) + "-" + Mamute_Hex4(EndAddr) + " COM " + Mamute_Hex2(FillByte))
EndProcedure

; G <endinic>[,<brkpnt1>[,<brkpnt2>]] - abre o debugger visual (MamuteDebuggerGui.pbi) no
; endereco informado, com ate 2 breakpoints opcionais ja armados (modulo 32 do SPEC.md, Fase 1
; do debugger visual - "simulador Z80 puro", sem VDP/PSG/FDC/BIOS - chamadas de sistema real
; nao sao simuladas, o usuario pula/ajusta registradores manualmente na janela e segue).
Procedure MamuteGui_CmdG(G_Log, *State.MamuteGui_State, Win, Args.s)
  Protected Trimmed.s = Trim(Args)
  If Trimmed = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected StartToken.s, Brk1Token.s = "", Brk2Token.s = ""
  Protected CommaPos1.i = FindString(Trimmed, ",")
  If CommaPos1 = 0
    StartToken = Trimmed
  Else
    StartToken = Trim(Left(Trimmed, CommaPos1 - 1))
    Protected Rest1.s = Mid(Trimmed, CommaPos1 + 1)
    Protected CommaPos2.i = FindString(Rest1, ",")
    If CommaPos2 = 0
      Brk1Token = Trim(Rest1)
    Else
      Brk1Token = Trim(Left(Rest1, CommaPos2 - 1))
      Brk2Token = Trim(Mid(Rest1, CommaPos2 + 1))
    EndIf
  EndIf

  Protected StartAddr.i, Brk1.i, Brk2.i
  If Not Mamute_ParseHexAddr(StartToken, @StartAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  If Brk1Token <> "" And Not Mamute_ParseHexAddr(Brk1Token, @Brk1)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf
  If Brk2Token <> "" And Not Mamute_ParseHexAddr(Brk2Token, @Brk2)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  *State\HasBreak1 = Bool(Brk1Token <> "")
  If *State\HasBreak1 : *State\Break1Addr = Brk1 : EndIf
  *State\HasBreak2 = Bool(Brk2Token <> "")
  If *State\HasBreak2 : *State\Break2Addr = Brk2 : EndIf

  Protected Msg.s = "G " + Mamute_Hex4(StartAddr)
  If Brk1Token <> "" : Msg + "," + Mamute_Hex4(Brk1) : EndIf
  If Brk2Token <> "" : Msg + "," + Mamute_Hex4(Brk2) : EndIf
  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, Msg)

  MamuteDebugger_Open(Win, *State, StartAddr)
EndProcedure

; R [<offset>] - carregamento de programa assemblado (gravado pela opcao 'I'
; do comando A original) depende do assemblador embutido, que tambem fica
; pra uma fase futura - pedido explicito do usuario: "apenas de a informacao
; na tela que vai ser implementado e mais nada". Sem parsing/validacao
; nenhuma - ignora Args de proposito, so confirma a informacao.
Procedure MamuteGui_CmdR(G_Log, *State.MamuteGui_State, Args.s)
  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
    "R - CARREGAMENTO DE PROGRAMA ASSEMBLADO AINDA NAO IMPLEMENTADO, FICA PRA UMA FASE FUTURA")
EndProcedure

; FOSSAURO - comando NOVO, fora do vocabulario do MegaAssembler original de
; proposito (nao existe um "envie pra outro emulador rodando de verdade" no
; manual de 1986) - pedido explicito do usuario, primeira ponta-a-ponta do
; protocolo de controle remoto (ver docs/SPEC.md modulo 32u). Reenvia o
; MESMO intervalo [MamuteAsmLastStartAddr, MamuteAsmLastByteCount) que "A O"
; (tela EDIT) acabou de gravar em MamuteMem, lido de volta byte a byte via
; Mamute_ReadByte() (respeita o mapeamento PAGE ativo, igual DM/qualquer
; outro comando de memoria) - depois manda "RUN" pro mesmo endereco inicial.
; Exige MamuteAsmLastWroteToRam (so' fica #True depois de um "A ...O..."
; bem-sucedido - "A" sozinho, sem "O", NAO escreve nada em MamuteMem, entao
; enviar seria so' lixo/zeros).
Procedure MamuteGui_CmdFossauro(G_Log, *State.MamuteGui_State)
  If Not MamuteAsmHasResult Or Not MamuteAsmLastWroteToRam
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
      "?NADA MONTADO COM 'O' AINDA (monte com 'A O' na tela EDIT antes de FOSSAURO)")
    ProcedureReturn
  EndIf
  If MamuteAsmLastByteCount <= 0
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?NADA GERADO (0 BYTES)")
    ProcedureReturn
  EndIf

  *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
    "FOSSAURO: ENVIANDO " + Str(MamuteAsmLastByteCount) + " BYTES PARA " + Mamute_Hex4(MamuteAsmLastStartAddr) + "H...")

  Protected *Payload = AllocateMemory(MamuteAsmLastByteCount)
  Protected I.i
  For I = 0 To MamuteAsmLastByteCount - 1
    PokeA(*Payload + I, Mamute_ReadByte((MamuteAsmLastStartAddr + I) & $FFFF))
  Next I

  Protected ErrMsg.s = Fossauro_SendAndRun(MamuteAsmLastStartAddr, *Payload, MamuteAsmLastByteCount)
  FreeMemory(*Payload)

  If ErrMsg = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum,
      "OK - RODANDO NO FOSSAURO A PARTIR DE " + Mamute_Hex4(MamuteAsmLastStartAddr) + "H")
  Else
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?" + UCase(ErrMsg))
  EndIf
EndProcedure

; Valor de 16 bits do par PairName (AF/BC/DE/HL a partir dos bytes, IX/IY/SP
; direto) - usado pelo modo "par" do X (ver comentario da Procedure abaixo).
Procedure.i MamuteGui_RegPairValue(*State.MamuteGui_State, PairName.s)
  Select PairName
    Case "AF" : ProcedureReturn (*State\RegA << 8) | *State\RegF
    Case "BC" : ProcedureReturn (*State\RegB << 8) | *State\RegC
    Case "DE" : ProcedureReturn (*State\RegD << 8) | *State\RegE
    Case "HL" : ProcedureReturn (*State\RegH << 8) | *State\RegL
    Case "IX" : ProcedureReturn *State\RegIX
    Case "IY" : ProcedureReturn *State\RegIY
    Case "SP" : ProcedureReturn *State\RegSP
  EndSelect
  ProcedureReturn 0
EndProcedure

Procedure MamuteGui_SetRegPair(*State.MamuteGui_State, PairName.s, Value.i)
  Select PairName
    Case "AF" : *State\RegA = (Value >> 8) & $FF : *State\RegF = Value & $FF
    Case "BC" : *State\RegB = (Value >> 8) & $FF : *State\RegC = Value & $FF
    Case "DE" : *State\RegD = (Value >> 8) & $FF : *State\RegE = Value & $FF
    Case "HL" : *State\RegH = (Value >> 8) & $FF : *State\RegL = Value & $FF
    Case "IX" : *State\RegIX = Value & $FFFF
    Case "IY" : *State\RegIY = Value & $FFFF
    Case "SP" : *State\RegSP = Value & $FFFF
  EndSelect
EndProcedure

Procedure.i MamuteGui_RegByteValue(*State.MamuteGui_State, RegName.s)
  Select RegName
    Case "A" : ProcedureReturn *State\RegA
    Case "F" : ProcedureReturn *State\RegF
    Case "B" : ProcedureReturn *State\RegB
    Case "C" : ProcedureReturn *State\RegC
    Case "D" : ProcedureReturn *State\RegD
    Case "E" : ProcedureReturn *State\RegE
    Case "H" : ProcedureReturn *State\RegH
    Case "L" : ProcedureReturn *State\RegL
  EndSelect
  ProcedureReturn 0
EndProcedure

Procedure MamuteGui_SetRegByte(*State.MamuteGui_State, RegName.s, Value.i)
  Select RegName
    Case "A" : *State\RegA = Value & $FF
    Case "F" : *State\RegF = Value & $FF
    Case "B" : *State\RegB = Value & $FF
    Case "C" : *State\RegC = Value & $FF
    Case "D" : *State\RegD = Value & $FF
    Case "E" : *State\RegE = Value & $FF
    Case "H" : *State\RegH = Value & $FF
    Case "L" : *State\RegL = Value & $FF
  EndSelect
EndProcedure

; Mostra os 7 pares (AF/BC/DE/HL/IX/IY/SP) em 2 linhas compactas no log.
Procedure.s MamuteGui_ShowRegs(G_Log, Accum.s, *State.MamuteGui_State)
  Accum = MamuteGui_AppendLog(G_Log, Accum,
    "AF=" + Mamute_Hex4(MamuteGui_RegPairValue(*State, "AF")) +
    " BC=" + Mamute_Hex4(MamuteGui_RegPairValue(*State, "BC")) +
    " DE=" + Mamute_Hex4(MamuteGui_RegPairValue(*State, "DE")) +
    " HL=" + Mamute_Hex4(MamuteGui_RegPairValue(*State, "HL")))
  Accum = MamuteGui_AppendLog(G_Log, Accum,
    "IX=" + Mamute_Hex4(*State\RegIX) + " IY=" + Mamute_Hex4(*State\RegIY) + " SP=" + Mamute_Hex4(*State\RegSP))
  ProcedureReturn Accum
EndProcedure

; X [<reg>] - sem argumento, mostra os 7 pares de registrador (AF/BC/DE/HL/
; IX/IY/SP). Com argumento, entra no modo de edicao a partir de <reg> -
; aceita tanto um PAR (AF/BC/DE/HL/IX/IY/SP, editado como um valor de 16
; bits/4 digitos hexa de uma vez) quanto um registrador de 1 BYTE isolado
; (A/F/B/C/D/E/H/L, 2 digitos hexa) - extensao pedida explicitamente pelo
; usuario sobre o manual original (que so tem os bytes A-L mais X/Y/S como
; abreviacao de IX/IY/SP, sem nomes de par diretos). Caminha em sequencia a
; partir do registrador escolhido (AF->BC->DE->HL->IX->IY->SP no modo par,
; A->F->B->C->D->E->H->L no modo byte), perguntando o novo valor de cada um
; via InputRequester() - o valor ATUAL vem pre-preenchido na caixa, entao
; <ENTER> sem editar "mantem o que esta" (reescreve o mesmo valor, sem
; mudanca real) e continua pro proximo; apagar o campo e confirmar (ou
; Cancelar/Esc - PureBasic nao distingue os dois, os dois retornam string
; vazia) para a caminhada inteira, mesmo espirito do "tecle RETURN pra
; parar" do manual original.
Procedure MamuteGui_CmdX(G_Log, *State.MamuteGui_State, Args.s)
  Protected Trimmed.s = UCase(Trim(Args))
  If Trimmed = ""
    *State\LogAccum = MamuteGui_ShowRegs(G_Log, *State\LogAccum, *State)
    ProcedureReturn
  EndIf

  Protected Dim PairSeq.s(6)
  PairSeq(0) = "AF" : PairSeq(1) = "BC" : PairSeq(2) = "DE" : PairSeq(3) = "HL"
  PairSeq(4) = "IX" : PairSeq(5) = "IY" : PairSeq(6) = "SP"

  Protected Dim ByteSeq.s(7)
  ByteSeq(0) = "A" : ByteSeq(1) = "F" : ByteSeq(2) = "B" : ByteSeq(3) = "C"
  ByteSeq(4) = "D" : ByteSeq(5) = "E" : ByteSeq(6) = "H" : ByteSeq(7) = "L"

  Protected Mode.b, StartIdx.i = -1, i.i
  For i = 0 To 6
    If PairSeq(i) = Trimmed
      StartIdx = i : Mode = 0
      Break
    EndIf
  Next
  If StartIdx = -1
    For i = 0 To 7
      If ByteSeq(i) = Trimmed
        StartIdx = i : Mode = 1
        Break
      EndIf
    Next
  EndIf

  If StartIdx = -1
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected Walking.b = #True, RegName.s, CurStr.s, NewStr.s, Digits.i, CurVal.i
  If Mode = 0
    Digits = 4
    For i = StartIdx To 6
      If Not Walking : Break : EndIf
      RegName = PairSeq(i)
      CurVal = MamuteGui_RegPairValue(*State, RegName)
      CurStr = Mamute_Hex4(CurVal)
      NewStr = Trim(InputRequester("X - " + RegName, "Novo valor de " + RegName + " (4 digitos hexa - ENTER mantem, vazio/Cancelar interrompe):", CurStr))
      If NewStr = ""
        Walking = #False
      ElseIf Mamute_IsHexString(NewStr, Digits)
        MamuteGui_SetRegPair(*State, RegName, Val("$" + NewStr))
      Else
        *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
        Walking = #False
      EndIf
    Next
  Else
    Digits = 2
    For i = StartIdx To 7
      If Not Walking : Break : EndIf
      RegName = ByteSeq(i)
      CurVal = MamuteGui_RegByteValue(*State, RegName)
      CurStr = Mamute_Hex2(CurVal)
      NewStr = Trim(InputRequester("X - " + RegName, "Novo valor de " + RegName + " (2 digitos hexa - ENTER mantem, vazio/Cancelar interrompe):", CurStr))
      If NewStr = ""
        Walking = #False
      ElseIf Mamute_IsHexString(NewStr, Digits)
        MamuteGui_SetRegByte(*State, RegName, Val("$" + NewStr))
      Else
        *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
        Walking = #False
      EndIf
    Next
  EndIf

  *State\LogAccum = MamuteGui_ShowRegs(G_Log, *State\LogAccum, *State)
EndProcedure

; Parser comum de "[<endinic>[,<endfim>]]" pro L/LP - os tres jeitos do
; manual original: nenhum argumento (continua do ultimo L/LP - *State\
; LastLAddr), so <endinic> (10 instrucoes a partir dali) ou os dois
; (decodifica ate ultrapassar <endfim>, mesma regra de Mamute_
; DisasmBuildLines em MamuteSupport.pbi). *OutHasEnd\i vira #True/#False.
Procedure.b MamuteGui_ParseLArgs(Args.s, *State.MamuteGui_State, *OutStart.Integer, *OutHasEnd.Integer, *OutEnd.Integer)
  Protected Trimmed.s = Trim(Args)
  Protected StartToken.s, EndToken.s = ""
  Protected CommaPos.i = FindString(Trimmed, ",")
  If CommaPos > 0
    StartToken = Trim(Left(Trimmed, CommaPos - 1))
    EndToken = Trim(Mid(Trimmed, CommaPos + 1))
  Else
    StartToken = Trimmed
  EndIf

  Protected StartAddr.i
  If StartToken = ""
    If Not *State\HasLastL
      ProcedureReturn #False
    EndIf
    StartAddr = *State\LastLAddr
  Else
    If Not Mamute_ParseHexAddr(StartToken, @StartAddr)
      ProcedureReturn #False
    EndIf
  EndIf

  Protected HasEnd.b = #False
  Protected EndAddr.i = 0
  If EndToken <> ""
    If Not Mamute_ParseHexAddr(EndToken, @EndAddr)
      ProcedureReturn #False
    EndIf
    If EndAddr < StartAddr
      ProcedureReturn #False
    EndIf
    HasEnd = #True
  EndIf

  *OutStart\i = StartAddr
  *OutHasEnd\i = HasEnd
  *OutEnd\i = EndAddr
  ProcedureReturn #True
EndProcedure

; L [<endinic>[,<endfim>]] - disassembla a RAM/ROM (mapeamento PAGE ativo
; agora) direto no log do MON>. Sem janela, mesmo espirito do D. <CTRL+STOP>
; do manual original pra interromper NAO se aplica aqui - a desmontagem
; inteira e calculada de uma vez, nao ha nada "rodando" em tempo real pra
; interromper.
Procedure MamuteGui_CmdL(G_Log, *State.MamuteGui_State, Args.s)
  Protected StartAddr.i, HasEndI.i, EndAddr.i
  If Not MamuteGui_ParseLArgs(Args, *State, @StartAddr, @HasEndI, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Protected NextAddr.i
  Mamute_DisasmBuildLines(Lines(), StartAddr, Bool(HasEndI), EndAddr, @NextAddr)
  ForEach Lines()
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, Lines())
  Next

  *State\LastLAddr = NextAddr
  *State\HasLastL = #True
EndProcedure

; LP [<endinic>[,<endfim>]] - mesma desmontagem do L, mas "na impressora":
; gera um PDF A4 simples (mesma infra do P/V - Mamute_SavePdfListing(),
; MamutePdf.pbi) e abre "Salvar como" no final, em vez de mandar pro log.
Procedure MamuteGui_CmdLp(G_Log, *State.MamuteGui_State, Args.s)
  Protected StartAddr.i, HasEndI.i, EndAddr.i
  If Not MamuteGui_ParseLArgs(Args, *State, @StartAddr, @HasEndI, @EndAddr)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO DE SINTAXE")
    ProcedureReturn
  EndIf

  Protected NewList Lines.s()
  Protected NextAddr.i
  Mamute_DisasmBuildLines(Lines(), StartAddr, Bool(HasEndI), EndAddr, @NextAddr)

  Protected FilePath.s = SaveFileRequester("Salvar listagem (LP) como PDF", "listagem_disasm.pdf", "PDF (*.pdf)|*.pdf", 0)
  If FilePath = ""
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "CANCELADO")
    ProcedureReturn
  EndIf
  If LCase(Right(FilePath, 4)) <> ".pdf"
    FilePath + ".pdf"
  EndIf

  Protected Header.s = "L " + Mamute_Hex4(StartAddr)
  If HasEndI
    Header + "-" + Mamute_Hex4(EndAddr)
  EndIf
  If Mamute_SavePdfListing(FilePath, Lines(), Header)
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "PDF GRAVADO: " + FilePath)
  Else
    *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?ERRO AO GRAVAR PDF")
  EndIf

  *State\LastLAddr = NextAddr
  *State\HasLastL = #True
EndProcedure

; Um comando digitado por chamada - primeiro token (ate o espaco) e o verbo,
; o resto (se houver) sao os argumentos crus, cada comando decide sozinho
; como interpretar os proprios argumentos. Select isolado de proposito -
; cada comando novo (ver Ajuda -> Mamute Assembler...) vira so mais um Case
; aqui, sem mexer no resto da janela.
Procedure MamuteGui_Dispatch(Win, G_Log, *State.MamuteGui_State, Cmd.s)
  Protected Trimmed.s = Trim(Cmd)
  Protected SpacePos.i = FindString(Trimmed, " ")
  Protected Verb.s, Args.s
  If SpacePos > 0
    Verb = UCase(Left(Trimmed, SpacePos - 1))
    Args = Trim(Mid(Trimmed, SpacePos + 1))
  Else
    Verb = UCase(Trimmed)
    Args = ""
  EndIf

  Select Verb
    Case "BA", "QUIT"
      *State\ShouldQuit = #True

    Case "PAGE"
      MamuteGui_CmdPage(G_Log, *State, Args)

    Case "DM"
      MamuteGui_CmdDm(Win, G_Log, *State, Args)

    Case "ZAP"
      MamuteGui_CmdZap(Win, G_Log, *State, Args)

    Case "SCR"
      MamuteGui_CmdScr(Win, G_Log, *State, Args)

    Case "SH"
      MamuteGui_CmdSh(G_Log, *State, Args)

    Case "MS"
      MamuteGui_CmdMs(G_Log, *State, Args)

    Case "LOAD"
      MamuteGui_CmdLoad(G_Log, *State, Win, Args)

    Case "SAVE"
      MamuteGui_CmdSave(Win, G_Log, *State, Args)

    Case "M"
      MamuteGui_CmdM(Win, G_Log, *State, Args)

    Case "S"
      MamuteGui_CmdS(Win, G_Log, *State, Args)

    Case "C"
      MamuteGui_CmdC(G_Log, *State, Args)

    Case "D"
      MamuteGui_CmdD(G_Log, *State, Args)

    Case "P"
      MamuteGui_CmdP(G_Log, *State, Args)

    Case "V"
      MamuteGui_CmdV(G_Log, *State, Args)

    Case "T"
      MamuteGui_CmdT(G_Log, *State, Args)

    Case "F"
      MamuteGui_CmdF(G_Log, *State, Args)

    Case "G"
      MamuteGui_CmdG(G_Log, *State, Win, Args)

    Case "X"
      MamuteGui_CmdX(G_Log, *State, Args)

    Case "R"
      MamuteGui_CmdR(G_Log, *State, Args)

    Case "FOSSAURO"
      MamuteGui_CmdFossauro(G_Log, *State)

    Case "L"
      MamuteGui_CmdL(G_Log, *State, Args)

    Case "LP"
      MamuteGui_CmdLp(G_Log, *State, Args)

    Case "EDIT"
      MamuteEdit_Open(Win)

    Default
      *State\LogAccum = MamuteGui_AppendLog(G_Log, *State\LogAccum, "?COMANDO INVALIDO")
  EndSelect
EndProcedure

Procedure MamuteAssembler_OpenWindow(ParentWindow)
  MamuteCfg_Load()
  MamuteGui_EnsureFont() ; depende de MamuteFontName/Size/Bold, ja carregados acima
  Mamute_ResetPageMapToDefault() ; "estado de boot" - ver MamuteSupport.pbi
  Mamute_LoadPhysicalMemory() ; le os arquivos ROM/BASIC configurados pra MamuteMem() de verdade
  MamuteGui_HistoryLoad() ; historico do MON> gravado no projeto (ou projeto padrao) - recarrega
                          ; toda vez que a janela abre, o projeto pode ter mudado desde a ultima vez

  Protected WinW = 960, WinH = 640
  Protected Win = OpenModelessChildWindow(ParentWindow, 0, 0, WinW, WinH, "Mamute Assembler",
                                          #PB_Window_SystemMenu | #PB_Window_ScreenCentered, #True, #False)
  If Not Win
    ProcedureReturn
  EndIf

  Protected ColFront = RGB(60, 220, 90), ColBack = RGB(0, 0, 0)
  SetWindowColor(Win, ColBack)

  Protected G_Log = EditorGadget(#PB_Any, 16, 16, WinW - 32, WinH - 72, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
  SetGadgetColor(G_Log, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Log, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Log, FontID(MamuteGui_Font))

  Protected G_Prompt = TextGadget(#PB_Any, 16, WinH - 46, 64, 24, "MON>")
  SetGadgetColor(G_Prompt, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Prompt, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Prompt, FontID(MamuteGui_Font))

  Protected G_Input = StringGadget(#PB_Any, 80, WinH - 48, WinW - 96, 26, "")
  SetGadgetColor(G_Input, #PB_Gadget_FrontColor, ColFront)
  SetGadgetColor(G_Input, #PB_Gadget_BackColor, ColBack)
  SetGadgetFont(G_Input, FontID(MamuteGui_Font))

  ; Reaplica a fonte - ver nota no topo do arquivo sobre App_StyleChildCallback.
  SetGadgetFont(G_Log, FontID(MamuteGui_Font))
  SetGadgetFont(G_Prompt, FontID(MamuteGui_Font))
  SetGadgetFont(G_Input, FontID(MamuteGui_Font))

  Protected State.MamuteGui_State
  State\LogAccum = MamuteGui_AppendLog(G_Log, "", "MAMUTE ASSEMBLER")
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "Digite BA ou QUIT para encerrar.")
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "")
  State\LogAccum = MamuteGui_ShowPageMap(G_Log, State\LogAccum)
  State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "")

  SetActiveGadget(G_Input)
  AddKeyboardShortcut(Win, #PB_Shortcut_Return, #MamuteGui_EnterShortcut)
  AddKeyboardShortcut(Win, #PB_Shortcut_Up, #MamuteGui_UpShortcut)
  AddKeyboardShortcut(Win, #PB_Shortcut_Down, #MamuteGui_DownShortcut)

  ; Posicao de navegacao no historico - -1 = "fora" dele (campo livre, o
  ; usuario esta digitando algo novo); 0..ListSize-1 = indice do comando
  ; sendo revisitado agora. Cima anda pro passado (indice menor), Baixo pro
  ; presente (indice maior, ate sair de volta pra -1 = campo vazio).
  Protected HistPos.i = -1
  Protected InputEndPos.i ; usado so pelos handlers de Cima/Baixo abaixo, pra por o cursor no fim do texto

  Protected Event, Quit = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Menu
        If EventMenu() = #MamuteGui_EnterShortcut
          Protected Cmd.s = Trim(GetGadgetText(G_Input))
          If Cmd <> ""
            State\LogAccum = MamuteGui_AppendLog(G_Log, State\LogAccum, "MON>" + Cmd)
            SetGadgetText(G_Input, "")
            HistPos = -1
            MamuteGui_HistoryAdd(Cmd)
            MamuteGui_HistorySave()
            MamuteGui_Dispatch(Win, G_Log, @State, Cmd)
            If State\ShouldQuit
              Quit = #True
            EndIf
          EndIf

        ElseIf EventMenu() = #MamuteGui_UpShortcut
          Protected HistCount.i = ListSize(MamuteGui_History())
          If HistCount > 0
            If HistPos = -1
              HistPos = HistCount - 1
            ElseIf HistPos > 0
              HistPos - 1
            EndIf
            SelectElement(MamuteGui_History(), HistPos)
            SetGadgetText(G_Input, MamuteGui_History())
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              InputEndPos = Len(GetGadgetText(G_Input))
              SendMessage_(GadgetID(G_Input), #EM_SETSEL, InputEndPos, InputEndPos)
            CompilerEndIf
          EndIf

        ElseIf EventMenu() = #MamuteGui_DownShortcut
          If HistPos <> -1
            If HistPos < ListSize(MamuteGui_History()) - 1
              HistPos + 1
              SelectElement(MamuteGui_History(), HistPos)
              SetGadgetText(G_Input, MamuteGui_History())
            Else
              HistPos = -1
              SetGadgetText(G_Input, "")
            EndIf
            CompilerIf #PB_Compiler_OS = #PB_OS_Windows
              InputEndPos = Len(GetGadgetText(G_Input))
              SendMessage_(GadgetID(G_Input), #EM_SETSEL, InputEndPos, InputEndPos)
            CompilerEndIf
          EndIf
        EndIf

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  CloseModelessChildWindow(ParentWindow, Win)
EndProcedure
