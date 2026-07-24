;
; ------------------------------------------------------------
;  ProjectDB.pbi - armazenamento de "projeto MSX" num arquivo SQLite unico.
;  Guarda hoje Sprites, Alfabetos, Sons (PSG) e Musicas (MML/PLAY) - ver
;  docs/SPEC.md / CLAUDE.md; outros tipos de conteudo do projeto (Basic,
;  Assembly, Telas, listagens LM) ganham tabela quando tiverem editor propio.
;
;  Ao iniciar sem nenhum parametro de linha de comando, BadigEditor.pb chama
;  EnsureOpen() logo de cara, que cria "noname.msxproject" dentro da pasta
;  temporaria (GetTemporaryDirectory()) - o projeto implicito onde tudo vai
;  sendo gravado ate o usuario criar um projeto explicito (Arquivo -> Novo
;  projeto...) ou salvar o "noname" num local definitivo (que o app oferece
;  ao sair, se houver conteudo registrado - ver OfferSaveProject() em
;  BadigEditor.pb). Mesmo padrao de rascunho-em-temp-ate-salvar ja usado no
;  gerenciador de disco (DiskManagerGui.pbi: DiskMgr_NewTempPath()/Salvar/
;  Salvar como).
;
;  A grade de pixels de cada sprite vira uma coluna TEXT: um digito
;  hexadecimal por bloco (0-F, cobre os indices de cor 0-15 da palheta),
;  grid_size*grid_size caracteres, linha a linha - evita depender da API de
;  bind de BLOB do driver SQLite do PureBasic (nao usada em nenhum exemplo
;  local, sem necessidade real aqui).
; ------------------------------------------------------------
;

UseSQLiteDatabase()

DeclareModule ProjectDB
  Declare.i EnsureOpen()
  Declare.i CreateNew(Path.s)
  Declare.i OpenExisting(Path.s)
  Declare.i SaveAs(NewPath.s)
  Declare.i IsTemp()
  Declare.s GetPath()
  Declare.i HasUnsavedContent()
  Declare Close()

  Declare SetWorkingDir(Dir.s)
  Declare.s GetWorkingDir()

  Declare.i StoreDocument(Path.s, Mode.s, Content.s)
  Declare.i FetchDocument(Path.s)
  Declare.s LastDocumentContent()
  Declare.s LastDocumentMode()

  Declare.i StoreSprite(Number.i, Tag.s, GridSize.i, SpriteMode.i, Array Grid.b(2))
  Declare.i FetchSprite(Number.i, Array Grid.b(2))
  Declare.i LastGridSize()
  Declare.i LastSpriteMode()
  Declare.s LastTag()
  Declare.i HasSprite(Number.i)
  Declare ListSpriteNumbers(List Numbers.i())

  Declare.i StoreAlphabet(Number.i, Tag.s, Array CharsetBytes.a(2))
  Declare.i FetchAlphabet(Number.i, Array CharsetBytes.a(2))
  Declare.s LastAlphabetTag()
  Declare.i HasAlphabet(Number.i)
  Declare ListAlphabetNumbers(List Numbers.i())

  ; Um "som" e uma sequencia de passos, cada um com os 14 registradores crus
  ; do PSG (SOUND 0-13) + duracao em quadros - ver editor/PsgSynth.pbi/
  ; PsgEditorGui.pbi. Regs() e 1D "achatado" (Regs(i*14+r), NumSteps*14
  ; elementos - nao uma matriz 2D, porque ReDim so redimensiona a ULTIMA
  ; dimensao de um array no PureBasic, e FetchSound precisa devolver um
  ; numero de passos variavel); Durations() tem NumSteps elementos. Arrays
  ; primitivos (nao a estrutura PsgStepData de PsgSynth.pbi) pra este modulo
  ; nao depender da ordem de XIncludeFile de PsgSynth.pbi - mesmo espirito de
  ; Array Grid.b(2)/CharsetBytes.a(2) acima.
  Declare.i StoreSound(Number.i, Tag.s, NumSteps.i, Array Regs.a(1), Array Durations.w(1))
  Declare.i FetchSound(Number.i, Array Regs.a(1), Array Durations.w(1))
  Declare.i LastSoundStepCount()
  Declare.s LastSoundTag()
  Declare.i HasSound(Number.i)
  Declare ListSoundNumbers(List Numbers.i())

  ; Uma "musica" MML/PLAY guarda as linhas de texto MML montadas em cada um
  ; dos 3 canais (A/B/C) - ver editor/MmlSynth.pbi/MmlEditorGui.pbi. Lines()
  ; e uma matriz 2D FIXA (canal 0-2, indice de linha) dimensionada pelo
  ; chamador (Dim Lines.s(2, N-1)) - nunca redimensionada aqui dentro
  ; (LineCount() controla quantas linhas de cada canal estao realmente em
  ; uso), entao nao esbarra na limitacao de ReDim documentada acima pra
  ; StoreSound/FetchSound.
  Declare.i StoreSong(Number.i, Tag.s, Array Lines.s(2), Array LineCount.i(1))
  Declare.i FetchSong(Number.i, Array Lines.s(2), Array LineCount.i(1))
  Declare.s LastSongTag()
  Declare.i HasSong(Number.i)
  Declare ListSongNumbers(List Numbers.i())

  ; Uma "tela" (editor grafico SCREEN 2, modulo 5) guarda a LISTA DE
  ; COMANDOS de desenho (nao o framebuffer resultante) como um unico TEXT
  ; opaco - um comando por linha, campos separados por "|". ProjectDB.pbi
  ; nao conhece a Structure Scr2_Command (definida em Screen2Synth.pbi,
  ; incluido DEPOIS deste arquivo em BadigEditor.pb) - o mesmo motivo que
  ; ja levou StoreSound/FetchSound a usar arrays primitivos em vez da
  ; Structure PsgStepData de PsgSynth.pbi. Quem serializa/desserializa e
  ; Screen2EditorGui.pbi; aqui e so um blob de texto guardado e devolvido.
  Declare.i StoreScreen(Number.i, Tag.s, CommandsText.s)
  Declare.i FetchScreen(Number.i)
  Declare.s LastScreenCommandsText()
  Declare.s LastScreenTag()
  Declare.i HasScreen(Number.i)
  Declare ListScreenNumbers(List Numbers.i())

  ; "Projeto 0": banco SQLite a parte, sempre em memoria (nunca em arquivo,
  ; nunca salvo), recriado do zero a cada vez que a IDE abre - fonte interna
  ; de conteudo padrao (hoje so o alfabeto 0 = msx.alf embutido no executavel
  ; via DefaultCharsetMsx.pbi; outros tipos de conteudo ganham entrada aqui
  ; conforme forem sendo desenvolvidos). So leitura pelo resto do app.
  Declare.i FetchDefaultAlphabet(Number.i, Array CharsetBytes.a(2))

  Declare.s GetLastError()
EndDeclareModule

Module ProjectDB
  ; Incluido de dentro do proprio Module (nao no topo de BadigEditor.pb como
  ; os demais XIncludeFile) porque um Module do PureBasic nao enxerga
  ; procedures/DataSection definidas fora dele, mesmo com forward
  ; declaration - so funciona se a inclusao acontecer aqui dentro.
  XIncludeFile "DefaultCharsetMsx.pbi"

  #DB = 0
  #DefaultsDB = 1   ; "projeto 0" - conexao SQLite separada, sempre :memory:

  Global IsOpen.b = #False
  Global TempFlag.b = #False
  Global CurrentPath.s = ""
  Global LastError.s = ""
  Global FetchedGridSize.i = 0
  Global FetchedSpriteMode.i = 0
  Global FetchedTag.s = ""
  Global FetchedDocContent.s = ""
  Global FetchedDocMode.s = ""
  Global FetchedAlphabetTag.s = ""
  Global FetchedSoundTag.s = ""
  Global FetchedStepCount.i = 0
  Global FetchedSongTag.s = ""
  Global FetchedScreenTag.s = ""
  Global FetchedScreenCommandsText.s = ""
  Global DefaultsOpen.b = #False

  Procedure.s NewTempPath()
    ProcedureReturn GetTemporaryDirectory() + "noname.msxproject"
  EndProcedure

  Procedure RunSchema()
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS project_info (key TEXT PRIMARY KEY, value TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS sprites (" +
                         "sprite_number INTEGER PRIMARY KEY, " +
                         "tag TEXT, " +
                         "grid_size INTEGER NOT NULL, " +
                         "sprite_mode INTEGER NOT NULL, " +
                         "pixel_data TEXT NOT NULL, " +
                         "updated_at TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS documents (" +
                         "path TEXT PRIMARY KEY, " +
                         "mode TEXT NOT NULL, " +
                         "content TEXT NOT NULL, " +
                         "updated_at TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS alphabets (" +
                         "alphabet_number INTEGER PRIMARY KEY, " +
                         "tag TEXT, " +
                         "charset_data TEXT NOT NULL, " +
                         "updated_at TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS psg_sounds (" +
                         "sound_number INTEGER PRIMARY KEY, " +
                         "tag TEXT, " +
                         "step_count INTEGER NOT NULL, " +
                         "steps_data TEXT NOT NULL, " +
                         "updated_at TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS mml_songs (" +
                         "song_number INTEGER PRIMARY KEY, " +
                         "tag TEXT, " +
                         "lines_a TEXT NOT NULL, " +
                         "lines_b TEXT NOT NULL, " +
                         "lines_c TEXT NOT NULL, " +
                         "updated_at TEXT)")
    DatabaseUpdate(#DB, "CREATE TABLE IF NOT EXISTS screens (" +
                         "screen_number INTEGER PRIMARY KEY, " +
                         "tag TEXT, " +
                         "commands_data TEXT NOT NULL, " +
                         "updated_at TEXT)")
  EndProcedure

  ; Fecha o banco atual (se houver) e abre em Path, criando o arquivo antes
  ; se preciso (SQLite/OpenDatabase espera que o arquivo ja exista).
  Procedure.i OpenAt(Path.s, CreateFileFirst.b)
    If IsOpen
      CloseDatabase(#DB)
      IsOpen = #False
    EndIf

    If CreateFileFirst
      Protected FileNum = CreateFile(#PB_Any, Path)
      If Not FileNum
        LastError = "Nao foi possivel criar o arquivo: " + Path
        ProcedureReturn #False
      EndIf
      CloseFile(FileNum)
    EndIf

    If Not OpenDatabase(#DB, Path, "", "")
      LastError = "Nao foi possivel abrir o banco: " + Path
      ProcedureReturn #False
    EndIf

    IsOpen = #True
    CurrentPath = Path
    ProcedureReturn #True
  EndProcedure

  Procedure.i EnsureOpen()
    If IsOpen
      ProcedureReturn #True
    EndIf
    If Not OpenAt(NewTempPath(), #True)
      ProcedureReturn #False
    EndIf
    RunSchema()
    TempFlag = #True
    SetWorkingDir(GetCurrentDirectory())
    ProcedureReturn #True
  EndProcedure

  ; Cria um projeto novo e vazio em Path e passa a usa-lo. Se o projeto
  ; anterior era o temporario implicito, apaga o arquivo temporario (quem
  ; chama e responsavel por ja ter oferecido salvar o conteudo antigo antes).
  Procedure.i CreateNew(Path.s)
    Protected OldPath.s = CurrentPath
    Protected WasTemp.b = TempFlag

    If Not OpenAt(Path, #True)
      ProcedureReturn #False
    EndIf
    RunSchema()
    TempFlag = #False
    SetWorkingDir(GetCurrentDirectory())

    If WasTemp And OldPath <> "" And OldPath <> Path
      DeleteFile(OldPath)
    EndIf
    ProcedureReturn #True
  EndProcedure

  ; Abre um projeto ja existente em Path (Arquivo -> Abrir projeto...) e
  ; passa a usa-lo - nao cria nada, o arquivo precisa existir. RunSchema()
  ; roda mesmo assim (CREATE TABLE IF NOT EXISTS, nunca mexe em dado
  ; existente) pra cobrir um projeto mais antigo/parcial que ainda nao tenha
  ; alguma tabela. Se o projeto anterior era o temporario implicito, apaga o
  ; arquivo temporario (quem chama e responsavel por ja ter oferecido salvar
  ; o conteudo antigo antes - ver OfferSaveProject() em BadigEditor.pb).
  Procedure.i OpenExisting(Path.s)
    If FileSize(Path) < 0
      LastError = "Arquivo nao encontrado: " + Path
      ProcedureReturn #False
    EndIf

    Protected OldPath.s = CurrentPath
    Protected WasTemp.b = TempFlag

    If Not OpenAt(Path, #False)
      ProcedureReturn #False
    EndIf
    RunSchema()
    TempFlag = #False

    If WasTemp And OldPath <> "" And OldPath <> Path
      DeleteFile(OldPath)
    EndIf
    ProcedureReturn #True
  EndProcedure

  ; Promove o projeto atual (normalmente o temporario) para NewPath, como um
  ; "Salvar como": copia o arquivo, reabre no novo local, e so entao apaga o
  ; antigo se ele era o temporario.
  Procedure.i SaveAs(NewPath.s)
    If Not IsOpen
      ProcedureReturn #False
    EndIf

    Protected OldPath.s = CurrentPath
    Protected WasTemp.b = TempFlag

    CloseDatabase(#DB)
    IsOpen = #False

    If Not CopyFile(OldPath, NewPath)
      LastError = "Nao foi possivel copiar para: " + NewPath
      OpenDatabase(#DB, OldPath, "", "")
      IsOpen = #True
      ProcedureReturn #False
    EndIf

    If Not OpenDatabase(#DB, NewPath, "", "")
      LastError = "Nao foi possivel reabrir: " + NewPath
      ProcedureReturn #False
    EndIf

    IsOpen = #True
    CurrentPath = NewPath
    TempFlag = #False

    If WasTemp And OldPath <> ""
      DeleteFile(OldPath)
    EndIf
    ProcedureReturn #True
  EndProcedure

  Procedure.i IsTemp()
    ProcedureReturn TempFlag
  EndProcedure

  Procedure.s GetPath()
    ProcedureReturn CurrentPath
  EndProcedure

  ; True quando o projeto ainda e o temporario implicito (nunca foi salvo
  ; num local permanente) E ja tem pelo menos um registro num dos tipos de
  ; conteudo que so existem dentro do banco do projeto (sprites, alfabetos,
  ; sons PSG, musicas MML, telas SCREEN 2) - e o sinal usado pra avisar o
  ; usuario ao sair ou ao criar outro projeto. Documentos (.dmx/.asm/
  ; tokenizado) ficam de fora de proposito: sao copia de um arquivo que ja
  ; existe em disco por conta propria, entao perder a copia do banco
  ; temporario nao perde trabalho de verdade (diferente de sprite/
  ; alfabeto/som/musica/tela, que so vivem aqui).
  Procedure.i HasUnsavedContent()
    If Not IsOpen Or Not TempFlag
      ProcedureReturn #False
    EndIf

    Protected Count.i = 0
    If DatabaseQuery(#DB, "SELECT " +
                           "(SELECT COUNT(*) FROM sprites) + " +
                           "(SELECT COUNT(*) FROM alphabets) + " +
                           "(SELECT COUNT(*) FROM psg_sounds) + " +
                           "(SELECT COUNT(*) FROM mml_songs) + " +
                           "(SELECT COUNT(*) FROM screens)")
      If NextDatabaseRow(#DB)
        Count = Val(GetDatabaseString(#DB, 0))
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Bool(Count > 0)
  EndProcedure

  ; Fecha o banco; se ainda era o temporario implicito (nunca promovido a um
  ; arquivo permanente), apaga o arquivo - quem decide salvar antes e quem
  ; chama (ver fluxo de saida/"Novo projeto" em BadigEditor.pb).
  Procedure Close()
    If IsOpen
      CloseDatabase(#DB)
      IsOpen = #False
    EndIf
    If TempFlag And CurrentPath <> ""
      DeleteFile(CurrentPath)
    EndIf
    CurrentPath = ""
  EndProcedure

  ; Diretorio "de trabalho" do projeto: pasta onde os arquivos-fonte (abas de
  ; texto) estao sendo salvos - atualizado a cada SaveDocument() bem-sucedido
  ; em BadigEditor.pb (GetPathPart do caminho salvo). Chave/valor avulsa em
  ; project_info, inicializada com GetCurrentDirectory() quando o projeto e
  ; criado (implicito "noname" ou "Novo projeto..."), antes de qualquer
  ; arquivo ter sido salvo - "o diretorio corrente se o usuario usou o
  ; padrao".
  Procedure SetWorkingDir(Dir.s)
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    Protected SafeDir.s = ReplaceString(Dir, "'", "''")
    DatabaseUpdate(#DB, "DELETE FROM project_info WHERE key='working_dir'")
    DatabaseUpdate(#DB, "INSERT INTO project_info (key, value) VALUES ('working_dir', '" + SafeDir + "')")
  EndProcedure

  Procedure.s GetWorkingDir()
    If Not EnsureOpen()
      ProcedureReturn ""
    EndIf

    Protected Result.s = ""
    If DatabaseQuery(#DB, "SELECT value FROM project_info WHERE key='working_dir'")
      If NextDatabaseRow(#DB)
        Result = GetDatabaseString(#DB, 0)
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Result
  EndProcedure

  ; Guarda uma copia atualizada do conteudo de uma aba de texto ja salva em
  ; disco (Path sempre um caminho absoluto real, nunca aba "noname" ainda nao
  ; salva) - chamado por SaveDocument() em BadigEditor.pb logo apos escrever
  ; o arquivo .dmx/.amx/.asm, mantendo o projeto com uma copia em sincronia
  ; com o que esta no disco. DELETE + INSERT (mesmo padrao de StoreSprite)
  ; chaveado por path, entao salvar a mesma aba de novo so atualiza a linha.
  Procedure.i StoreDocument(Path.s, Mode.s, Content.s)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected SafePath.s = ReplaceString(Path, "'", "''")
    Protected SafeMode.s = ReplaceString(Mode, "'", "''")
    Protected SafeContent.s = ReplaceString(Content, "'", "''")

    DatabaseUpdate(#DB, "DELETE FROM documents WHERE path='" + SafePath + "'")
    Protected SQL.s = "INSERT INTO documents (path, mode, content, updated_at) VALUES ('" +
                       SafePath + "', '" + SafeMode + "', '" + SafeContent + "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(#DB, SQL)
  EndProcedure

  ; Le de volta a copia de uma aba guardada por StoreDocument(); mesmo padrao
  ; de FetchSprite() (campos extras via LastDocumentContent()/LastDocumentMode()
  ; em vez de parametro de saida por ponteiro de string).
  Procedure.i FetchDocument(Path.s)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected SafePath.s = ReplaceString(Path, "'", "''")
    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT mode, content FROM documents WHERE path='" + SafePath + "'")
      If NextDatabaseRow(#DB)
        FetchedDocMode = GetDatabaseString(#DB, 0)
        FetchedDocContent = GetDatabaseString(#DB, 1)
        Found = #True
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.s LastDocumentContent()
    ProcedureReturn FetchedDocContent
  EndProcedure

  Procedure.s LastDocumentMode()
    ProcedureReturn FetchedDocMode
  EndProcedure

  Procedure.i StoreSprite(Number.i, Tag.s, GridSize.i, SpriteMode.i, Array Grid.b(2))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Row, Col
    Protected HexData.s = ""
    For Row = 0 To GridSize - 1
      For Col = 0 To GridSize - 1
        HexData = HexData + Hex(Grid(Row, Col))
      Next
    Next

    Protected SafeTag.s = Left(ReplaceString(Tag, "'", "''"), 16)

    ; DELETE + INSERT em vez de "ON CONFLICT DO UPDATE" pra nao depender de
    ; uma versao especifica do SQLite.
    DatabaseUpdate(#DB, "DELETE FROM sprites WHERE sprite_number=" + Str(Number))
    Protected SQL.s = "INSERT INTO sprites (sprite_number, tag, grid_size, sprite_mode, pixel_data, updated_at) VALUES (" +
                       Str(Number) + ", '" + SafeTag + "', " + Str(GridSize) + ", " + Str(SpriteMode) +
                       ", '" + HexData + "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(#DB, SQL)
  EndProcedure

  ; Le o sprite Number pra dentro de Grid() e devolve #True/#False; os demais
  ; campos (tag/tamanho/modo) ficam disponiveis logo em seguida via
  ; LastTag()/LastGridSize()/LastSpriteMode() (evita parametros de saida por
  ; ponteiro pra string, que nao sobrevivem ao retorno da procedure).
  Procedure.i FetchSprite(Number.i, Array Grid.b(2))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT tag, grid_size, sprite_mode, pixel_data FROM sprites WHERE sprite_number=" + Str(Number))
      If NextDatabaseRow(#DB)
        FetchedTag = GetDatabaseString(#DB, 0)
        FetchedGridSize = Val(GetDatabaseString(#DB, 1))
        FetchedSpriteMode = Val(GetDatabaseString(#DB, 2))
        Protected PixelData.s = GetDatabaseString(#DB, 3)

        Protected Row, Col, Idx = 0
        For Row = 0 To FetchedGridSize - 1
          For Col = 0 To FetchedGridSize - 1
            If Idx < Len(PixelData)
              Grid(Row, Col) = Val("$" + Mid(PixelData, Idx + 1, 1))
            EndIf
            Idx + 1
          Next
        Next
        Found = #True
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.i LastGridSize()
    ProcedureReturn FetchedGridSize
  EndProcedure

  Procedure.i LastSpriteMode()
    ProcedureReturn FetchedSpriteMode
  EndProcedure

  Procedure.s LastTag()
    ProcedureReturn FetchedTag
  EndProcedure

  Procedure.i HasSprite(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT 1 FROM sprites WHERE sprite_number=" + Str(Number))
      Found = NextDatabaseRow(#DB)
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure ListSpriteNumbers(List Numbers.i())
    ClearList(Numbers())
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    If DatabaseQuery(#DB, "SELECT sprite_number FROM sprites ORDER BY sprite_number ASC")
      While NextDatabaseRow(#DB)
        AddElement(Numbers())
        Numbers() = Val(GetDatabaseString(#DB, 0))
      Wend
      FinishDatabaseQuery(#DB)
    EndIf
  EndProcedure

  ; Empacota CharsetBytes (256x8) num unico TEXT hex (2 digitos por byte,
  ; 4096 caracteres) e grava (DELETE+INSERT, mesmo padrao de StoreSprite) na
  ; tabela alphabets de DBNum - interna, usada tanto pelo projeto ativo
  ; (#DB) quanto pelo projeto de defaults (#DefaultsDB, so na semeadura do
  ; alfabeto 0).
  Procedure.i StoreAlphabetInto(DBNum.i, Number.i, Tag.s, Array CharsetBytes.a(2))
    Protected Row, Col
    Protected HexData.s = ""
    For Row = 0 To 255
      For Col = 0 To 7
        HexData = HexData + RSet(Hex(CharsetBytes(Row, Col)), 2, "0")
      Next
    Next

    Protected SafeTag.s = Left(ReplaceString(Tag, "'", "''"), 16)

    DatabaseUpdate(DBNum, "DELETE FROM alphabets WHERE alphabet_number=" + Str(Number))
    Protected SQL.s = "INSERT INTO alphabets (alphabet_number, tag, charset_data, updated_at) VALUES (" +
                       Str(Number) + ", '" + SafeTag + "', '" + HexData + "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(DBNum, SQL)
  EndProcedure

  ; Le de volta um alfabeto de DBNum pra dentro de CharsetBytes (256x8) -
  ; tag extra via LastAlphabetTag() (mesmo padrao de FetchSprite/FetchDocument).
  Procedure.i FetchAlphabetFrom(DBNum.i, Number.i, Array CharsetBytes.a(2))
    Protected Found.b = #False
    If DatabaseQuery(DBNum, "SELECT tag, charset_data FROM alphabets WHERE alphabet_number=" + Str(Number))
      If NextDatabaseRow(DBNum)
        FetchedAlphabetTag = GetDatabaseString(DBNum, 0)
        Protected HexData.s = GetDatabaseString(DBNum, 1)
        Protected Row, Col, Idx = 0
        For Row = 0 To 255
          For Col = 0 To 7
            CharsetBytes(Row, Col) = Val("$" + Mid(HexData, Idx * 2 + 1, 2))
            Idx + 1
          Next
        Next
        Found = #True
      EndIf
      FinishDatabaseQuery(DBNum)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.i StoreAlphabet(Number.i, Tag.s, Array CharsetBytes.a(2))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf
    ProcedureReturn StoreAlphabetInto(#DB, Number, Tag, CharsetBytes())
  EndProcedure

  Procedure.i FetchAlphabet(Number.i, Array CharsetBytes.a(2))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf
    ProcedureReturn FetchAlphabetFrom(#DB, Number, CharsetBytes())
  EndProcedure

  Procedure.s LastAlphabetTag()
    ProcedureReturn FetchedAlphabetTag
  EndProcedure

  Procedure.i HasAlphabet(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT 1 FROM alphabets WHERE alphabet_number=" + Str(Number))
      Found = NextDatabaseRow(#DB)
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure ListAlphabetNumbers(List Numbers.i())
    ClearList(Numbers())
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    If DatabaseQuery(#DB, "SELECT alphabet_number FROM alphabets ORDER BY alphabet_number ASC")
      While NextDatabaseRow(#DB)
        AddElement(Numbers())
        Numbers() = Val(GetDatabaseString(#DB, 0))
      Wend
      FinishDatabaseQuery(#DB)
    EndIf
  EndProcedure

  ; Empacota Regs()/Durations() (Regs "achatado" em 1D, NumSteps*14
  ; elementos - Regs(i*14+r) - e nao uma matriz 2D, porque ReDim so
  ; redimensiona a ULTIMA dimensao de um array no PureBasic; um array 1D e a
  ; unica forma segura de FetchSound devolver um numero de passos variavel)
  ; num unico TEXT hex de largura fixa (32 digitos por passo: 28 dos 14
  ; registradores de 1 byte + 4 da duracao de 2 bytes) e grava (DELETE+INSERT,
  ; mesmo padrao de StoreSprite/StoreAlphabet).
  Procedure.i StoreSound(Number.i, Tag.s, NumSteps.i, Array Regs.a(1), Array Durations.w(1))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected i, r
    Protected HexData.s = ""
    For i = 0 To NumSteps - 1
      For r = 0 To 13
        HexData = HexData + RSet(Hex(Regs(i * 14 + r)), 2, "0")
      Next
      HexData = HexData + RSet(Hex(Durations(i)), 4, "0")
    Next

    Protected SafeTag.s = Left(ReplaceString(Tag, "'", "''"), 16)

    DatabaseUpdate(#DB, "DELETE FROM psg_sounds WHERE sound_number=" + Str(Number))
    Protected SQL.s = "INSERT INTO psg_sounds (sound_number, tag, step_count, steps_data, updated_at) VALUES (" +
                       Str(Number) + ", '" + SafeTag + "', " + Str(NumSteps) + ", '" + HexData + "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(#DB, SQL)
  EndProcedure

  ; Le de volta um som pra dentro de Regs()/Durations() (redimensionados aqui
  ; dentro pro tamanho certo - Array passado por referencia, ReDim afeta o
  ; array do chamador; Regs e 1D "achatado", ver comentario de StoreSound);
  ; tag/numero de passos extras via LastSoundTag()/LastSoundStepCount()
  ; (mesmo padrao de FetchSprite/FetchAlphabet).
  Procedure.i FetchSound(Number.i, Array Regs.a(1), Array Durations.w(1))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT tag, step_count, steps_data FROM psg_sounds WHERE sound_number=" + Str(Number))
      If NextDatabaseRow(#DB)
        FetchedSoundTag = GetDatabaseString(#DB, 0)
        FetchedStepCount = Val(GetDatabaseString(#DB, 1))
        Protected HexData.s = GetDatabaseString(#DB, 2)

        If FetchedStepCount > 0
          ReDim Regs(FetchedStepCount * 14 - 1)
          ReDim Durations(FetchedStepCount - 1)
          Protected i, r, Pos = 1
          For i = 0 To FetchedStepCount - 1
            For r = 0 To 13
              Regs(i * 14 + r) = Val("$" + Mid(HexData, Pos, 2))
              Pos + 2
            Next
            Durations(i) = Val("$" + Mid(HexData, Pos, 4))
            Pos + 4
          Next
        EndIf
        Found = #True
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.i LastSoundStepCount()
    ProcedureReturn FetchedStepCount
  EndProcedure

  Procedure.s LastSoundTag()
    ProcedureReturn FetchedSoundTag
  EndProcedure

  Procedure.i HasSound(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT 1 FROM psg_sounds WHERE sound_number=" + Str(Number))
      Found = NextDatabaseRow(#DB)
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure ListSoundNumbers(List Numbers.i())
    ClearList(Numbers())
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    If DatabaseQuery(#DB, "SELECT sound_number FROM psg_sounds ORDER BY sound_number ASC")
      While NextDatabaseRow(#DB)
        AddElement(Numbers())
        Numbers() = Val(GetDatabaseString(#DB, 0))
      Wend
      FinishDatabaseQuery(#DB)
    EndIf
  EndProcedure

  ; Grava as linhas MML dos 3 canais (Lines(canal, indice), LineCount(canal)
  ; linhas validas por canal) como 3 colunas TEXT, cada uma com as linhas
  ; daquele canal unidas por Chr(10) (DELETE+INSERT, mesmo padrao dos demais).
  Procedure.i StoreSong(Number.i, Tag.s, Array Lines.s(2), Array LineCount.i(1))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected c, i
    Dim Joined.s(2)
    For c = 0 To 2
      Joined(c) = ""
      For i = 0 To LineCount(c) - 1
        If i > 0
          Joined(c) = Joined(c) + Chr(10)
        EndIf
        Joined(c) = Joined(c) + Lines(c, i)
      Next
      Joined(c) = ReplaceString(Joined(c), "'", "''")
    Next

    Protected SafeTag.s = Left(ReplaceString(Tag, "'", "''"), 16)

    DatabaseUpdate(#DB, "DELETE FROM mml_songs WHERE song_number=" + Str(Number))
    Protected SQL.s = "INSERT INTO mml_songs (song_number, tag, lines_a, lines_b, lines_c, updated_at) VALUES (" +
                       Str(Number) + ", '" + SafeTag + "', '" + Joined(0) + "', '" + Joined(1) + "', '" + Joined(2) +
                       "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(#DB, SQL)
  EndProcedure

  ; Le de volta uma musica pra dentro de Lines()/LineCount() (arrays fixos,
  ; dimensionados pelo chamador - so preenche ate a capacidade, nunca
  ; redimensiona); tag extra via LastSongTag().
  Procedure.i FetchSong(Number.i, Array Lines.s(2), Array LineCount.i(1))
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT tag, lines_a, lines_b, lines_c FROM mml_songs WHERE song_number=" + Str(Number))
      If NextDatabaseRow(#DB)
        FetchedSongTag = GetDatabaseString(#DB, 0)
        Protected c, p, Parts
        Protected RawText.s
        Protected MaxIdx = ArraySize(Lines(), 2)
        For c = 0 To 2
          RawText = GetDatabaseString(#DB, 1 + c)
          LineCount(c) = 0
          If RawText <> ""
            Parts = CountString(RawText, Chr(10)) + 1
            For p = 1 To Parts
              If LineCount(c) <= MaxIdx
                Lines(c, LineCount(c)) = StringField(RawText, p, Chr(10))
                LineCount(c) + 1
              EndIf
            Next
          EndIf
        Next
        Found = #True
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.s LastSongTag()
    ProcedureReturn FetchedSongTag
  EndProcedure

  Procedure.i HasSong(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT 1 FROM mml_songs WHERE song_number=" + Str(Number))
      Found = NextDatabaseRow(#DB)
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure ListSongNumbers(List Numbers.i())
    ClearList(Numbers())
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    If DatabaseQuery(#DB, "SELECT song_number FROM mml_songs ORDER BY song_number ASC")
      While NextDatabaseRow(#DB)
        AddElement(Numbers())
        Numbers() = Val(GetDatabaseString(#DB, 0))
      Wend
      FinishDatabaseQuery(#DB)
    EndIf
  EndProcedure

  ; CommandsText e um blob opaco (um comando por linha, ja serializado por
  ; Screen2EditorGui.pbi) - so escapa aspas simples pra SQL, igual
  ; StoreDocument() faz com Content; sem hex-encoding, sem conhecer a
  ; Structure Scr2_Command.
  Procedure.i StoreScreen(Number.i, Tag.s, CommandsText.s)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected SafeTag.s = Left(ReplaceString(Tag, "'", "''"), 16)
    Protected SafeCommands.s = ReplaceString(CommandsText, "'", "''")

    DatabaseUpdate(#DB, "DELETE FROM screens WHERE screen_number=" + Str(Number))
    Protected SQL.s = "INSERT INTO screens (screen_number, tag, commands_data, updated_at) VALUES (" +
                       Str(Number) + ", '" + SafeTag + "', '" + SafeCommands + "', datetime('now'))"
    ProcedureReturn DatabaseUpdate(#DB, SQL)
  EndProcedure

  ; Sem parametro de Array de saida (nao ha estrutura pra preencher aqui) -
  ; tag e texto dos comandos saem via LastScreenTag()/LastScreenCommandsText(),
  ; mesmo padrao "out-param" de FetchDocument()/FetchAlphabet().
  Procedure.i FetchScreen(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT tag, commands_data FROM screens WHERE screen_number=" + Str(Number))
      If NextDatabaseRow(#DB)
        FetchedScreenTag = GetDatabaseString(#DB, 0)
        FetchedScreenCommandsText = GetDatabaseString(#DB, 1)
        Found = #True
      EndIf
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure.s LastScreenCommandsText()
    ProcedureReturn FetchedScreenCommandsText
  EndProcedure

  Procedure.s LastScreenTag()
    ProcedureReturn FetchedScreenTag
  EndProcedure

  Procedure.i HasScreen(Number.i)
    If Not EnsureOpen()
      ProcedureReturn #False
    EndIf

    Protected Found.b = #False
    If DatabaseQuery(#DB, "SELECT 1 FROM screens WHERE screen_number=" + Str(Number))
      Found = NextDatabaseRow(#DB)
      FinishDatabaseQuery(#DB)
    EndIf
    ProcedureReturn Found
  EndProcedure

  Procedure ListScreenNumbers(List Numbers.i())
    ClearList(Numbers())
    If Not EnsureOpen()
      ProcedureReturn
    EndIf

    If DatabaseQuery(#DB, "SELECT screen_number FROM screens ORDER BY screen_number ASC")
      While NextDatabaseRow(#DB)
        AddElement(Numbers())
        Numbers() = Val(GetDatabaseString(#DB, 0))
      Wend
      FinishDatabaseQuery(#DB)
    EndIf
  EndProcedure

  ; Abre (uma unica vez por sessao) o banco SQLite ":memory:" do "projeto 0"
  ; e semeia o alfabeto 0 com o charset padrao do MSX embutido no executavel
  ; (FillDefaultMsxCharset(), de DefaultCharsetMsx.pbi) - nunca toca em
  ; disco, nunca e salvo, nao interfere no projeto ativo (#DB e #DefaultsDB
  ; sao conexoes separadas).
  Procedure.i EnsureDefaultsOpen()
    If DefaultsOpen
      ProcedureReturn #True
    EndIf

    If Not OpenDatabase(#DefaultsDB, ":memory:", "", "")
      LastError = "Nao foi possivel abrir o projeto de defaults em memoria."
      ProcedureReturn #False
    EndIf

    DatabaseUpdate(#DefaultsDB, "CREATE TABLE IF NOT EXISTS alphabets (" +
                                 "alphabet_number INTEGER PRIMARY KEY, " +
                                 "tag TEXT, " +
                                 "charset_data TEXT NOT NULL, " +
                                 "updated_at TEXT)")

    Dim SeedBytes.a(255, 7)
    FillDefaultMsxCharset(SeedBytes())
    StoreAlphabetInto(#DefaultsDB, 0, "msx", SeedBytes())

    DefaultsOpen = #True
    ProcedureReturn #True
  EndProcedure

  Procedure.i FetchDefaultAlphabet(Number.i, Array CharsetBytes.a(2))
    If Not EnsureDefaultsOpen()
      ProcedureReturn #False
    EndIf
    ProcedureReturn FetchAlphabetFrom(#DefaultsDB, Number, CharsetBytes())
  EndProcedure

  Procedure.s GetLastError()
    If DatabaseError() <> ""
      ProcedureReturn DatabaseError()
    EndIf
    ProcedureReturn LastError
  EndProcedure
EndModule
