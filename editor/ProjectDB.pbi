;
; ------------------------------------------------------------
;  ProjectDB.pbi - armazenamento de "projeto MSX" num arquivo SQLite unico.
;  Guarda por enquanto so os Sprites (ver docs/SPEC.md / CLAUDE.md); outros
;  tipos de conteudo do projeto (Basic, Assembly, Telas, Sons, Musicas,
;  listagens LM, documentos) ganham tabela quando tiverem editor propio.
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

  Declare.i StoreSprite(Number.i, Tag.s, GridSize.i, SpriteMode.i, Array Grid.b(2))
  Declare.i FetchSprite(Number.i, Array Grid.b(2))
  Declare.i LastGridSize()
  Declare.i LastSpriteMode()
  Declare.s LastTag()
  Declare.i HasSprite(Number.i)
  Declare ListSpriteNumbers(List Numbers.i())

  Declare.s GetLastError()
EndDeclareModule

Module ProjectDB
  #DB = 0

  Global IsOpen.b = #False
  Global TempFlag.b = #False
  Global CurrentPath.s = ""
  Global LastError.s = ""
  Global FetchedGridSize.i = 0
  Global FetchedSpriteMode.i = 0
  Global FetchedTag.s = ""

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
  ; num local permanente) E ja tem pelo menos um sprite registrado - e o
  ; sinal usado pra avisar o usuario ao sair ou ao criar outro projeto.
  Procedure.i HasUnsavedContent()
    If Not IsOpen Or Not TempFlag
      ProcedureReturn #False
    EndIf

    Protected Count.i = 0
    If DatabaseQuery(#DB, "SELECT COUNT(*) FROM sprites")
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

  Procedure.s GetLastError()
    If DatabaseError() <> ""
      ProcedureReturn DatabaseError()
    EndIf
    ProcedureReturn LastError
  EndProcedure
EndModule
