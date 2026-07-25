;
; ------------------------------------------------------------
;  Criar -> Graphos III Screen 2...: primeiro editor da familia "Graphos
;  III" nesta IDE (ver graphos/graphos.txt, manual original do programa,
;  Renato Degiovani 1987 / A&L Software 1997) - reproduz o modulo EDITA
;  TELA do Graphos III original, focado em telas/shapes/layout. O editor de
;  alfabetos do Graphos III JA existe nesta IDE (CharsetEditorGui.pbi,
;  formato .ALF) - pedido explicito do usuario pra NAO duplicar essa parte
;  aqui, cada funcao do Graphos III vira uma opcao separada dentro de
;  "Criar", e esta e a primeira: a tela.
;
;  O Graphos III original usava as teclas F1-F5 pra abrir os menus DESENHO/
;  TEXTO/TELA/AJUSTE/MISCELANEA - aqui cada operacao vira um botao/icone, no
;  mesmo espirito do editor de sprites (SpriteEditorGui.pbi), em vez de
;  teclas de funcao.
;
;  FASE 1 cobriu so "a tela que representa a SCREEN 2": canvas com color
;  clash identico ao MSX (motor editor/Screen2Synth.pbi, 69 casos de teste),
;  paleta INK/PAPER, TRACO (Lapis/Borracha) e LIMPA TELA.
;
;  FASE 2 (esta sessao) completa o resto do menu DESENHO (F1) do Graphos III
;  original: BLOCO, LINHA, RETANGULO, RAIO, CIRCULO, PINTURA, SPRAY e FILL.
;  Nenhuma dessas operacoes precisou de motor novo - Scr2_DrawLine (reta),
;  Scr2_LineStatement (BoxMode=1, contorno de retangulo) e Scr2_DrawCircle ja
;  existiam prontos em Screen2Synth.pbi (usados pelo editor "Draw Screen
;  2..."), assim como Scr2_FloodFill (FILL). So PINTURA (altera so a cor de
;  FUNDO da faixa, sem tocar no bit do pixel nem na cor de FRENTE) e SPRAY
;  (borrifo aleatorio) sao logica nova, pequena, escrita abaixo.
;
;  Igual ao Graphos III original ("os atributos de todas as posicoes
;  alteradas recebem a cor de FRENTE selecionada, com excecao de PINTURA,
;  que so mexe no FUNDO"): TRACO/BLOCO/LINHA/RETANGULO/RAIO/CIRCULO/SPRAY/
;  FILL desenham com INK; so PINTURA usa PAPER. E, tambem fiel ao original
;  ("INSERT/DELETE funciona com TRACO, BLOCO, SPRAY e todo o menu de
;  TEXTO"), so essas tres ferramentas (mais o TEXTO, ainda nao implementado)
;  respeitam o alternador Lapis(INS)/Borracha(DEL) - LINHA/RETANGULO/RAIO/
;  CIRCULO/FILL sempre desenham (nunca apagam) e PINTURA sempre pinta com
;  PAPER, entao o alternador fica desabilitado quando uma dessas esta ativa.
;
;  LINHA/RETANGULO/RAIO/CIRCULO seguem o mesmo padrao de "ancora + previa
;  elastica + segundo clique confirma" do editor "Draw Screen 2..."
;  (reaproveita Scr2Ed_DrawLinePreview/DrawCirclePreview de
;  Screen2EditorGui.pbi, sem duplicar o desenho da previa), mas com uma
;  diferenca de semantica ditada pelo manual original: em LINHA o ponto
;  final vira automaticamente o ponto inicial do proximo segmento (encadeia,
;  poligono aberto); em RETANGULO/RAIO/CIRCULO a ancora (vertice fixo/origem
;  do raio/centro) permanece FIXA entre desenhos - o usuario clica varias
;  vezes e cada clique produz uma nova forma a partir da MESMA ancora, ate
;  cancelar com o botao direito (equivalente ao ESC do original) ou trocar
;  de ferramenta.
;
;  FASE 3 (esta sessao) implementa o menu TEXTO (F2): escreve na tela com um
;  alfabeto ja registrado no projeto (Criar -> Alfabeto Graphos III...,
;  ProjectDB::FetchAlphabet - mesmo formato 256x8 do modulo 4), nas 6
;  variacoes do manual original - NORMAL, ITALIC, BOLD, DUPLO (dupla
;  altura), DUPLO BOLD (dupla altura e largura) e LARGO (dupla largura).
;  ITALIC/BOLD reaproveitam as MESMAS transformacoes de bits ja escritas pro
;  editor de alfabetos (CharEd_ItalicEditGrid/BoldEditGrid,
;  CharsetEditorGui.pbi, modulo 4c) sem duplicar a formula - a diferenca e
;  que aqui a transformacao e' aplicada so na hora de desenhar (o alfabeto
;  guardado no banco nunca e' alterado). DUPLO/LARGO/DUPLO BOLD sao
;  duplicacao geometrica de linha/coluna no framebuffer (nao mexem no
;  formato do glifo), igual ao "dupla altura/largura" classico de impressora
;  matricial que da nome as opcoes. Mesmo padrao de "Posicionar -> previa
;  elastica segue o mouse -> clique fixa" ja usado pela ferramenta TEXTO do
;  editor "Draw Screen 2..." (Scr2Ed_DrawTextPreview original, aqui
;  reescrito como GraphosScr_DrawTextPreview pra suportar as 6 variacoes),
;  so que sem o grid de 8px/STEP (irrelevante aqui, ja que este editor nao
;  gera codigo BASIC ainda - so framebuffer).
;
;  Deliberadamente FORA desta fase (proximos cortes): menu TELA (F3 -
;  INVERTE VIDEO/ATRIBUTOS, RETIRA/REPOE, IMPRIME TELA); menu AJUSTE (F4 -
;  SCROLL/ROTACAO inteiro e 8x8); menu MISCELANEA (F5 - ZOOM, SHAPE, CORTE,
;  GRID) e CRIA/ARQUIVA/RECUPERA SHAPES; os formatos nativos DISPLAY (.SCR),
;  LAYOUT (.LAY) e COMPAC (.VTC+.ATC); integracao com o sistema de projeto
;  (ProjectDB.pbi) alem da leitura de alfabetos ja existente.
; ------------------------------------------------------------
;

Enumeration GraphosScrTool
  #GraphosScrTool_Traco
  #GraphosScrTool_Bloco
  #GraphosScrTool_Linha
  #GraphosScrTool_Retangulo
  #GraphosScrTool_Raio
  #GraphosScrTool_Circulo
  #GraphosScrTool_Pintura
  #GraphosScrTool_Spray
  #GraphosScrTool_Fill
EndEnumeration

; Alternador INS/DEL do Graphos III original (teclas INSERT/DELETE) -
; controla se TRACO/BLOCO/SPRAY setam (Lapis, com INK) ou resetam
; (Borracha, com PAPER) os pixels alterados.
Enumeration GraphosPenMode
  #GraphosPenMode_Insert
  #GraphosPenMode_Delete
EndEnumeration

; As 6 variacoes do menu TEXTO (F2) do Graphos III original, na mesma ordem
; do manual (graphos/graphos.txt, secao 3.2.2).
Enumeration GraphosTextStyle
  #GraphosTextStyle_Normal
  #GraphosTextStyle_Italic
  #GraphosTextStyle_Bold
  #GraphosTextStyle_Duplo
  #GraphosTextStyle_DuploBold
  #GraphosTextStyle_Largo
EndEnumeration

; Tamanho valido do cursor da ferramenta BLOCO (campos de texto livre, sem
; SpinGadget nesta base de codigo - validado na hora do uso).
Procedure.i GraphosScr_ClampBlockSize(V.i)
  If V < 1
    ProcedureReturn 1
  ElseIf V > 64
    ProcedureReturn 64
  Else
    ProcedureReturn V
  EndIf
EndProcedure

; Ferramentas que respeitam o alternador Lapis/Borracha - as demais
; (LINHA/RETANGULO/RAIO/CIRCULO/FILL sempre com INK, PINTURA sempre com
; PAPER) ignoram PenMode.
Procedure.b GraphosScr_ToolUsesPenMode(ToolMode.i)
  ProcedureReturn Bool(ToolMode = #GraphosScrTool_Traco Or ToolMode = #GraphosScrTool_Bloco Or ToolMode = #GraphosScrTool_Spray)
EndProcedure

; BLOCO do Graphos III original: TRACO com "altura e largura de cursor"
; ajustaveis - aqui um retangulo BlockW x BlockH de pixels centrado no ponto
; do cursor, cada pixel setado/resetado exatamente como TRACO (mesmo
; PenMode). Scr2_SetPixel ja faz o clip silencioso fora da tela.
Procedure GraphosScr_ApplyBlock(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), CenterX.i, CenterY.i, BlockW.i, BlockH.i, PenMode.i, InkColor.i, PaperColor.i)
  Protected StartX = CenterX - (BlockW / 2)
  Protected StartY = CenterY - (BlockH / 2)
  Protected X, Y
  For Y = StartY To StartY + BlockH - 1
    For X = StartX To StartX + BlockW - 1
      If PenMode = #GraphosPenMode_Insert
        Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, InkColor, #True)
      Else
        Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, PaperColor, #False)
      EndIf
    Next
  Next
EndProcedure

; PINTURA do Graphos III original: "altera a cor de fundo dos pontos
; indicados pelo cursor... sem alterar a cor de frente do desenho" - so
; grava RowBG da faixa de 8 pixels sob o cursor, nunca mexe em PatternBit
; nem em RowFG (diferente de Scr2_SetPixel, que sempre acende/apaga o bit).
Procedure GraphosScr_PaintBackground(Array RowBG.a(2), X.i, Y.i, PaperColor.i)
  If X < 0 Or X >= #Scr2_Width Or Y < 0 Or Y >= #Scr2_Height
    ProcedureReturn
  EndIf
  RowBG(Y, X / 8) = PaperColor & $F
EndProcedure

; SPRAY do Graphos III original: "imita o resultado de uma pintura com
; spray, padrao aleatorio, tende a formar um borrao compacto caso nao haja
; deslocamento do cursor" - a cada chamada (clique ou passo de arraste),
; borrifa alguns pixels em posicoes aleatorias dentro de um raio quadrado
; ao redor do cursor, respeitando o mesmo PenMode de TRACO/BLOCO.
#GraphosScr_SprayRadius = 5
#GraphosScr_SprayDabs   = 6

Procedure GraphosScr_ApplySpray(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), CenterX.i, CenterY.i, PenMode.i, InkColor.i, PaperColor.i)
  Protected i, PX, PY
  For i = 1 To #GraphosScr_SprayDabs
    PX = CenterX + Random(#GraphosScr_SprayRadius * 2) - #GraphosScr_SprayRadius
    PY = CenterY + Random(#GraphosScr_SprayRadius * 2) - #GraphosScr_SprayRadius
    If PenMode = #GraphosPenMode_Insert
      Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), PX, PY, InkColor, #True)
    Else
      Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), PX, PY, PaperColor, #False)
    EndIf
  Next
EndProcedure

; TRACO/BLOCO/PINTURA/SPRAY sao "ferramentas de arraste" - aplicadas tanto
; no clique quanto, continuamente, em cada novo pixel visitado durante o
; arraste (mesmo padrao de SpriteEd_ApplyTool do editor de sprites).
; LINHA/RETANGULO/RAIO/CIRCULO/FILL sao "de clique unico" e ficam fora
; daqui, tratadas direto no laco de eventos (precisam de ancora/previa ou
; disparam uma unica vez).
Procedure GraphosScr_ApplyDragTool(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), X.i, Y.i, ToolMode.i, PenMode.i, InkColor.i, PaperColor.i, BlockW.i, BlockH.i)
  Select ToolMode
    Case #GraphosScrTool_Traco
      If PenMode = #GraphosPenMode_Insert
        Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, InkColor, #True)
      Else
        Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, PaperColor, #False)
      EndIf

    Case #GraphosScrTool_Bloco
      GraphosScr_ApplyBlock(PatternBit(), RowFG(), RowBG(), X, Y, BlockW, BlockH, PenMode, InkColor, PaperColor)

    Case #GraphosScrTool_Pintura
      GraphosScr_PaintBackground(RowBG(), X, Y, PaperColor)

    Case #GraphosScrTool_Spray
      GraphosScr_ApplySpray(PatternBit(), RowFG(), RowBG(), X, Y, PenMode, InkColor, PaperColor)

  EndSelect
EndProcedure

; LIMPA TELA (menu TELA do Graphos III original): apaga todos os pixels e
; grava INK/PAPER atuais em toda faixa - diferente de Scr2_ClearFramebuffer
; (que sempre usa os defaults #Scr2_DefaultFG/BG), aqui usa as cores que o
; usuario tem selecionadas no momento, igual ao "ATRIBUTOS" do original.
Procedure GraphosScr_ClearWithColors(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), InkColor.i, PaperColor.i)
  Protected Y, X, Cx
  For Y = 0 To #Scr2_Height - 1
    For X = 0 To #Scr2_Width - 1
      PatternBit(Y, X) = 0
    Next
    For Cx = 0 To #Scr2_Cols - 1
      RowFG(Y, Cx) = InkColor
      RowBG(Y, Cx) = PaperColor
    Next
  Next
EndProcedure

; --- TEXTO (fase 3): imprime uma string usando um alfabeto do projeto
; (ProjectDB::FetchAlphabet, formato CharsetBytes(255,7) do modulo 4) -----
;
; NORMAL/ITALIC/BOLD sao transformacao de FORMA do glifo (reaproveita
; CharEd_UnpackChar/ItalicEditGrid/BoldEditGrid de CharsetEditorGui.pbi, sem
; duplicar a formula de bits) - continuam 8x8; DUPLO/LARGO/DUPLO BOLD sao
; duplicacao geometrica de linha/coluna no framebuffer, sem mexer na forma.
; ScaleX/ScaleY resolvem as 6 combinacoes com um so par de loops.
Procedure GraphosScr_TextScaleX(Style.i)
  ProcedureReturn Bool(Style = #GraphosTextStyle_Largo Or Style = #GraphosTextStyle_DuploBold) + 1
EndProcedure

Procedure GraphosScr_TextScaleY(Style.i)
  ProcedureReturn Bool(Style = #GraphosTextStyle_Duplo Or Style = #GraphosTextStyle_DuploBold) + 1
EndProcedure

; StartX/StartY = pixel bruto do canto superior esquerdo do 1o caractere,
; igual a Scr2Ed_BlitText - cada caractere seguinte desloca (8*ScaleX)px.
Procedure GraphosScr_BlitTextStyled(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), Array CharsetBytes.a(2), TextStr.s, StartX.i, StartY.i, InkColor.i, PaperColor.i, Style.i)
  Protected ScaleX = GraphosScr_TextScaleX(Style)
  Protected ScaleY = GraphosScr_TextScaleY(Style)
  Protected i, Code, Row, Col, DupRow, DupCol, BaseX, BaseY, PixelOn.b
  Dim Grid.a(7, 7)
  BaseX = StartX
  For i = 1 To Len(TextStr)
    Code = Asc(Mid(TextStr, i, 1))
    If Code >= 0 And Code <= 255
      CharEd_UnpackChar(CharsetBytes(), Code, Grid())
      Select Style
        Case #GraphosTextStyle_Italic
          CharEd_ItalicEditGrid(Grid())
        Case #GraphosTextStyle_Bold
          CharEd_BoldEditGrid(Grid())
      EndSelect
      BaseY = StartY
      For Row = 0 To 7
        For Col = 0 To 7
          PixelOn = Bool(Grid(Row, Col))
          For DupRow = 0 To ScaleY - 1
            For DupCol = 0 To ScaleX - 1
              If PixelOn
                Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), BaseX + Col * ScaleX + DupCol, BaseY + Row * ScaleY + DupRow, InkColor, #True)
              Else
                Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), BaseX + Col * ScaleX + DupCol, BaseY + Row * ScaleY + DupRow, PaperColor, #False)
              EndIf
            Next
          Next
        Next
      Next
    EndIf
    BaseX + 8 * ScaleX
  Next
EndProcedure

; "Quadro elastico" da ferramenta TEXTO - mesmo espirito de
; Scr2Ed_DrawTextPreview (editor "Draw Screen 2..."), mas desenhando por
; cima do canvas ja redesenhado (nao toca no framebuffer real) e suportando
; as 6 variacoes via GraphosScr_TextScaleX/Y, igual ao blit de verdade.
Procedure GraphosScr_DrawTextPreview(Canvas, Array CharsetBytes.a(2), TextStr.s, BaseX.i, BaseY.i, InkColor.l, PaperColor.l, Style.i)
  If Not StartDrawing(CanvasOutput(Canvas))
    ProcedureReturn
  EndIf
  Protected ScaleX = GraphosScr_TextScaleX(Style)
  Protected ScaleY = GraphosScr_TextScaleY(Style)
  Protected i, Code, Row, Col, CX, CY, CurX
  Dim Grid.a(7, 7)
  CurX = BaseX
  For i = 1 To Len(TextStr)
    Code = Asc(Mid(TextStr, i, 1))
    If Code >= 0 And Code <= 255
      CharEd_UnpackChar(CharsetBytes(), Code, Grid())
      Select Style
        Case #GraphosTextStyle_Italic
          CharEd_ItalicEditGrid(Grid())
        Case #GraphosTextStyle_Bold
          CharEd_BoldEditGrid(Grid())
      EndSelect
      For Row = 0 To 7
        For Col = 0 To 7
          CX = (CurX + Col * ScaleX) * #Scr2Ed_Zoom
          CY = (BaseY + Row * ScaleY) * #Scr2Ed_Zoom
          If Grid(Row, Col)
            Box(CX, CY, ScaleX * #Scr2Ed_Zoom, ScaleY * #Scr2Ed_Zoom, InkColor)
          Else
            Box(CX, CY, ScaleX * #Scr2Ed_Zoom, ScaleY * #Scr2Ed_Zoom, PaperColor)
          EndIf
        Next
      Next
    EndIf
    CurX + 8 * ScaleX
  Next
  Protected TextW = (CurX - BaseX) * #Scr2Ed_Zoom, TextH = 8 * ScaleY * #Scr2Ed_Zoom
  DrawingMode(#PB_2DDrawing_Outlined)
  Box(BaseX * #Scr2Ed_Zoom, BaseY * #Scr2Ed_Zoom, TextW, TextH, Scr2Ed_AnchorColor)
  DrawingMode(#PB_2DDrawing_Default)
  StopDrawing()
EndProcedure

; --- Icones novos (fase 2) - mesmo estilo monocromatico/24bpp dos icones ja
; usados pelo editor de sprites (SpriteEditorGui.pbi), so que especificos
; de operacoes que nao existem em nenhum outro editor desta IDE. BLOCO,
; LINHA, RETANGULO, CIRCULO e FILL reaproveitam icones ja existentes do
; editor de sprites (Brush/LineTool/RectOutline/EllipseOutline/Fill) -
; encaixam conceitualmente sem precisar de desenho novo.

; Icone do botao "Traco": um unico pixel ampliado dentro de uma moldura -
; simboliza a edicao pixel a pixel (em oposicao ao BLOCO, que mexe em varios
; de uma vez).
Procedure GraphosScr_CreatePixelIcon(Size.i)
  Protected Img = CreateImage(#PB_Any, Size, Size, 24, RGB(255, 255, 255))
  If StartDrawing(ImageOutput(Img))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, Size, Size, RGB(255, 255, 255))
    DrawingMode(#PB_2DDrawing_Outlined)
    Box(2, 2, Size - 4, Size - 4, RGB(170, 170, 170))
    DrawingMode(#PB_2DDrawing_Default)
    Box(Size / 2 - 3, Size / 2 - 3, 6, 6, RGB(20, 20, 20))
    StopDrawing()
  EndIf
  ProcedureReturn Img
EndProcedure

; Icone do botao "Raio": varios segmentos de reta partindo de uma unica
; origem fixa (bolinha azul), lembrando o leque de linhas que a operacao RAIO
; traca a partir do ponto marcado como referencia.
Procedure GraphosScr_CreateRayIcon(Size.i)
  Protected Img = CreateImage(#PB_Any, Size, Size, 24, RGB(255, 255, 255))
  If StartDrawing(ImageOutput(Img))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, Size, Size, RGB(255, 255, 255))
    Protected OX = 3, OY = Size - 4
    LineXY(OX, OY, Size - 4, 3, RGB(20, 20, 20))
    LineXY(OX, OY, Size - 3, Size / 2, RGB(20, 20, 20))
    LineXY(OX, OY, Size / 2, 3, RGB(20, 20, 20))
    Circle(OX, OY, 3, RGB(30, 110, 220))
    StopDrawing()
  EndIf
  ProcedureReturn Img
EndProcedure

; Icone do botao "Pintura": quadrado dividido - metade de cima (o "desenho"/
; tinta) fica intocada, metade de baixo (o "fundo") aparece recolorida de
; laranja, comunicando que so o FUNDO muda.
Procedure GraphosScr_CreatePaintIcon(Size.i)
  Protected Img = CreateImage(#PB_Any, Size, Size, 24, RGB(255, 255, 255))
  If StartDrawing(ImageOutput(Img))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, Size, Size, RGB(255, 255, 255))
    LineXY(3, 4, Size - 4, 4, RGB(20, 20, 20))
    LineXY(3, 8, Size - 7, 8, RGB(20, 20, 20))
    Box(2, Size / 2, Size - 4, Size / 2 - 2, RGB(235, 150, 40))
    DrawingMode(#PB_2DDrawing_Outlined)
    Box(2, Size / 2, Size - 4, Size / 2 - 2, RGB(150, 90, 20))
    DrawingMode(#PB_2DDrawing_Default)
    StopDrawing()
  EndIf
  ProcedureReturn Img
EndProcedure

; Icone do botao "Spray": nuvem de pontinhos, lembrando o borrifo aleatorio
; que a operacao produz (posicoes fixas no icone - so o desenho de dentro da
; ferramenta e' aleatorio de verdade).
Procedure GraphosScr_CreateSprayIcon(Size.i)
  Protected Img = CreateImage(#PB_Any, Size, Size, 24, RGB(255, 255, 255))
  If StartDrawing(ImageOutput(Img))
    DrawingMode(#PB_2DDrawing_Default)
    Box(0, 0, Size, Size, RGB(255, 255, 255))
    Circle(4, Size - 4, 1, RGB(30, 130, 200))
    Circle(8, Size - 7, 1, RGB(30, 130, 200))
    Circle(6, Size - 11, 1, RGB(30, 130, 200))
    Circle(11, Size - 3, 1, RGB(30, 130, 200))
    Circle(13, Size - 9, 1, RGB(30, 130, 200))
    Circle(16, Size - 5, 1, RGB(30, 130, 200))
    Circle(9, Size - 14, 1, RGB(30, 130, 200))
    Circle(17, Size - 12, 1, RGB(30, 130, 200))
    Circle(2, Size - 9, 1, RGB(30, 130, 200))
    StopDrawing()
  EndIf
  ProcedureReturn Img
EndProcedure

Procedure GraphosScreenGui_OpenWindow(ParentWindow)
  Protected Zoom = 2
  Protected CanvasW = #Scr2_Width * Zoom, CanvasH = #Scr2_Height * Zoom
  Protected CanvasX = 15, CanvasY = 50
  Protected RightX = CanvasX + CanvasW + 20
  Protected RightW = 160

  ; --- Layout da coluna direita pre-calculado (precisa existir antes do
  ; OpenWindow pra dimensionar a janela) - paleta INK/PAPER (fase 1),
  ; ferramentas de DESENHO em 3 linhas de 3 botoes (fase 2), alternador
  ; Lapis/Borracha, campos de tamanho do BLOCO, Limpar tela e status.
  Protected PaletteSize = #Scr2Ed_PaletteSize
  Protected PaperY = CanvasY + 18 + PaletteSize + 14

  Protected ToolsLabelY = PaperY + 18 + PaletteSize + 16
  Protected ToolsRow1Y = ToolsLabelY + 18
  Protected ToolsRow2Y = ToolsRow1Y + 36
  Protected ToolsRow3Y = ToolsRow2Y + 36
  Protected ToolsBottom = ToolsRow3Y + 30

  Protected PenLabelY = ToolsBottom + 16
  Protected PenY = PenLabelY + 18
  Protected PenBottom = PenY + 30

  Protected BlockLabelY = PenBottom + 16
  Protected BlockFieldY = BlockLabelY + 18
  Protected BlockBottom = BlockFieldY + 22

  Protected TextLabelY = BlockBottom + 16
  Protected TextAlphaY = TextLabelY + 18
  Protected TextStyleY = TextAlphaY + 26
  Protected TextStrY = TextStyleY + 26
  Protected TextBtnY = TextStrY + 26
  Protected TextBottom = TextBtnY + 26

  Protected ClearY = TextBottom + 16
  Protected ClearBottom = ClearY + 28

  Protected StatusY = ClearBottom + 14
  Protected StatusH = 100
  Protected StatusBottom = StatusY + StatusH

  Protected WinW = RightX + RightW + 15
  Protected WinH = CanvasY + CanvasH + 55
  If StatusBottom + 20 > WinH
    WinH = StatusBottom + 20
  EndIf

  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Graphos III - Tela (SCREEN 2)",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf
  App_ApplyWindowIcon(Win)
  DisableWindow(ParentWindow, #True)

  TextGadget(#PB_Any, CanvasX, 16, CanvasW, 20,
             "SCREEN 2 (256x192) - color clash identico ao MSX: 2 cores por faixa de 8 pixels")
  Protected G_Canvas = CanvasGadget(#PB_Any, CanvasX, CanvasY, CanvasW, CanvasH)

  ; --- Paleta INK/PAPER (mesma paleta MSX1 e mesmo desenho de swatch ja
  ; usados por "Criar -> Draw Screen 2...", reaproveitados sem mudanca) ---
  TextGadget(#PB_Any, RightX, CanvasY, RightW, 18, "Tinta (INK):")
  Protected G_PaletteInk = CanvasGadget(#PB_Any, RightX, CanvasY + 18, PaletteSize, PaletteSize)
  TextGadget(#PB_Any, RightX, PaperY, RightW, 18, "Fundo (PAPER):")
  Protected G_PalettePaper = CanvasGadget(#PB_Any, RightX, PaperY + 18, PaletteSize, PaletteSize)

  ; --- Ferramentas do menu DESENHO (F1): TRACO (fase 1) + BLOCO/LINHA/
  ; RETANGULO/RAIO/CIRCULO/PINTURA/SPRAY/FILL (fase 2), 3 por linha ---
  TextGadget(#PB_Any, RightX, ToolsLabelY, RightW, 16, "Ferramenta (DESENHO):")

  Protected TracoIcon = GraphosScr_CreatePixelIcon(22)
  Protected G_ToolTraco = ButtonImageGadget(#PB_Any, RightX, ToolsRow1Y, 34, 30, ImageID(TracoIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolTraco, "TRACO: liga/apaga um pixel por vez - arraste pra riscar")

  Protected BlocoIcon = SpriteEd_CreateBrushIcon(22)
  Protected G_ToolBloco = ButtonImageGadget(#PB_Any, RightX + 40, ToolsRow1Y, 34, 30, ImageID(BlocoIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolBloco, "BLOCO: como o TRACO, mas altera um bloco Largura x Altura de pixels de uma vez")

  Protected LinhaIcon = SpriteEd_CreateLineToolIcon(22)
  Protected G_ToolLinha = ButtonImageGadget(#PB_Any, RightX + 80, ToolsRow1Y, 34, 30, ImageID(LinhaIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolLinha, "LINHA: marque o ponto inicial e o final - o final vira o inicio do proximo segmento")

  Protected RetanguloIcon = SpriteEd_CreateRectOutlineIcon(22)
  Protected G_ToolRetangulo = ButtonImageGadget(#PB_Any, RightX, ToolsRow2Y, 34, 30, ImageID(RetanguloIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolRetangulo, "RETANGULO: marque um vertice fixo e depois o vertice oposto - clique direito cancela")

  Protected RaioIcon = GraphosScr_CreateRayIcon(22)
  Protected G_ToolRaio = ButtonImageGadget(#PB_Any, RightX + 40, ToolsRow2Y, 34, 30, ImageID(RaioIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolRaio, "RAIO: marque a origem fixa e depois cada ponto final - clique direito cancela")

  Protected CirculoIcon = SpriteEd_CreateEllipseOutlineIcon(22)
  Protected G_ToolCirculo = ButtonImageGadget(#PB_Any, RightX + 80, ToolsRow2Y, 34, 30, ImageID(CirculoIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolCirculo, "CIRCULO: marque o centro fixo e depois um ponto por onde o circulo deve passar")

  Protected PinturaIcon = GraphosScr_CreatePaintIcon(22)
  Protected G_ToolPintura = ButtonImageGadget(#PB_Any, RightX, ToolsRow3Y, 34, 30, ImageID(PinturaIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolPintura, "PINTURA: muda so a cor de Fundo sob o cursor, sem alterar o desenho (Tinta)")

  Protected SprayIcon = GraphosScr_CreateSprayIcon(22)
  Protected G_ToolSpray = ButtonImageGadget(#PB_Any, RightX + 40, ToolsRow3Y, 34, 30, ImageID(SprayIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolSpray, "SPRAY: borrifo aleatorio de pixels ao redor do cursor")

  Protected FillIcon = SpriteEd_CreateFillIcon(22)
  Protected G_ToolFill = ButtonImageGadget(#PB_Any, RightX + 80, ToolsRow3Y, 34, 30, ImageID(FillIcon), #PB_Button_Toggle)
  GadgetToolTip(G_ToolFill, "FILL: preenche com Tinta a area conectada ao ponto clicado")

  Dim ToolGadgets.i(8)
  ToolGadgets(0) = G_ToolTraco
  ToolGadgets(1) = G_ToolBloco
  ToolGadgets(2) = G_ToolLinha
  ToolGadgets(3) = G_ToolRetangulo
  ToolGadgets(4) = G_ToolRaio
  ToolGadgets(5) = G_ToolCirculo
  ToolGadgets(6) = G_ToolPintura
  ToolGadgets(7) = G_ToolSpray
  ToolGadgets(8) = G_ToolFill

  ; --- Alternador Lapis(INS)/Borracha(DEL) - so importa pra TRACO/BLOCO/
  ; SPRAY (ver GraphosScr_ToolUsesPenMode); fica desabilitado nas demais ---
  TextGadget(#PB_Any, RightX, PenLabelY, RightW, 16, "Modo (INS/DEL):")
  Protected PencilIcon = SpriteEd_CreatePencilIcon(22)
  Protected G_Pencil = ButtonImageGadget(#PB_Any, RightX, PenY, 34, 30, ImageID(PencilIcon), #PB_Button_Toggle)
  GadgetToolTip(G_Pencil, "Lapis (INSERT): TRACO/BLOCO/SPRAY setam pixels com a cor de Tinta")
  Protected EraserIcon = SpriteEd_CreateEraserIcon(22)
  Protected G_Eraser = ButtonImageGadget(#PB_Any, RightX + 40, PenY, 34, 30, ImageID(EraserIcon), #PB_Button_Toggle)
  GadgetToolTip(G_Eraser, "Borracha (DELETE): TRACO/BLOCO/SPRAY apagam pixels usando a cor de Fundo")
  Dim PenGadgets.i(1)
  PenGadgets(0) = G_Pencil
  PenGadgets(1) = G_Eraser

  ; --- Tamanho do cursor da ferramenta BLOCO ---
  TextGadget(#PB_Any, RightX, BlockLabelY, RightW, 16, "Bloco - Largura x Altura:")
  Protected G_BlockW = StringGadget(#PB_Any, RightX, BlockFieldY, 45, 22, "2")
  TextGadget(#PB_Any, RightX + 48, BlockFieldY + 3, 12, 16, "x")
  Protected G_BlockH = StringGadget(#PB_Any, RightX + 62, BlockFieldY, 45, 22, "2")
  GadgetToolTip(G_BlockW, "Largura do bloco em pixels (1-64)")
  GadgetToolTip(G_BlockH, "Altura do bloco em pixels (1-64)")

  ; --- TEXTO (F2): alfabeto do projeto + variacao + string, "Posicionar"
  ; arma o modo de colocacao (previa elastica segue o mouse ate o clique) ---
  TextGadget(#PB_Any, RightX, TextLabelY, RightW, 16, "Texto (alfabeto do projeto):")
  Protected G_TextAlpha = ComboBoxGadget(#PB_Any, RightX, TextAlphaY, RightW, 22)
  Protected G_TextStyle = ComboBoxGadget(#PB_Any, RightX, TextStyleY, RightW, 22)
  AddGadgetItem(G_TextStyle, -1, "NORMAL")
  AddGadgetItem(G_TextStyle, -1, "ITALIC")
  AddGadgetItem(G_TextStyle, -1, "BOLD")
  AddGadgetItem(G_TextStyle, -1, "DUPLO")
  AddGadgetItem(G_TextStyle, -1, "DUPLO BOLD")
  AddGadgetItem(G_TextStyle, -1, "LARGO")
  SetGadgetState(G_TextStyle, #GraphosTextStyle_Normal)
  Protected G_TextStr = StringGadget(#PB_Any, RightX, TextStrY, RightW, 22, "")
  GadgetToolTip(G_TextStr, "Texto a imprimir")
  Protected G_TextPlace = ButtonGadget(#PB_Any, RightX, TextBtnY, RightW, 26, "Posicionar TEXTO...")
  GadgetToolTip(G_TextPlace, "Arma o modo de posicionamento - mova o mouse ate o lugar certo e clique no canvas (direito cancela)")

  Protected G_ClearScreen = ButtonGadget(#PB_Any, RightX, ClearY, RightW, 28, "Limpar tela")
  GadgetToolTip(G_ClearScreen, "LIMPA TELA (menu TELA): apaga tudo com as cores Tinta/Fundo atuais")

  Protected G_Status = TextGadget(#PB_Any, RightX, StatusY, RightW, StatusH, "")

  Protected G_Close = ButtonGadget(#PB_Any, CanvasX, CanvasY + CanvasH + 12, 100, 30, "Fechar")

  ; --- Estado ---
  Dim PatternBit.a(#Scr2_Height - 1, #Scr2_Width - 1)
  Dim RowFG.a(#Scr2_Height - 1, #Scr2_Cols - 1)
  Dim RowBG.a(#Scr2_Height - 1, #Scr2_Cols - 1)
  Scr2_ClearFramebuffer(PatternBit(), RowFG(), RowBG())

  Dim Palette.l(15)
  Dim PaletteNames.s(15)
  SpriteEd_FillPalette(Palette(), PaletteNames())

  Protected InkColor.i = #Scr2_DefaultFG
  Protected PaperColor.i = #Scr2_DefaultBG
  Protected ToolMode.i = #GraphosScrTool_Traco
  Protected PenMode.i = #GraphosPenMode_Insert
  Protected LastPaintX.i = -1, LastPaintY.i = -1

  ; Ancora das ferramentas de 2 cliques (LINHA/RETANGULO/RAIO/CIRCULO) -
  ; PendingActive marca que o 1o ponto ja foi marcado e a previa elastica
  ; deve seguir o mouse ate o 2o clique (ou o cancelamento via botao direito).
  Protected PendingActive.b = #False
  Protected AnchorX.i, AnchorY.i

  ; TEXTO (F2) - mesmo padrao de PendingActive acima, mas com o alfabeto/
  ; texto/cores/estilo congelados no momento de "Posicionar..." (pra nao
  ; mudar no meio do posicionamento se o usuario mexer nos campos).
  Protected TextPlacementActive.b = #False
  Protected TextPendingStr.s, TextPendingAlpha.i, TextPendingInk.i, TextPendingPaper.i, TextPendingStyle.i
  Dim TextPendingCharset.a(255, 7)

  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
  Scr2Ed_RedrawMiniPalette(G_PaletteInk, InkColor, Palette())
  Scr2Ed_RedrawMiniPalette(G_PalettePaper, PaperColor, Palette())
  SetGadgetState(G_ToolTraco, #True)
  SetGadgetState(G_Pencil, #True)

  ; Popula o combo de alfabetos do projeto - ProjectDB::FetchAlphabet e
  ; chamado de verdade so em G_TextPlace, ao entrar no modo de colocacao.
  ProjectDB::EnsureOpen()
  NewList TextAlphaNums.i()
  ProjectDB::ListAlphabetNumbers(TextAlphaNums())
  ForEach TextAlphaNums()
    AddGadgetItem(G_TextAlpha, -1, "#" + Str(TextAlphaNums()))
  Next
  If ListSize(TextAlphaNums()) > 0
    SetGadgetState(G_TextAlpha, 0)
  EndIf

  Protected Event, Quit = #False
  Protected MouseX, MouseY, PX, PY, Idx
  Protected DX.f, DY.f, Radius.i
  Protected BW.i, BH.i
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()

          Case G_PaletteInk
            If EventType() = #PB_EventType_LeftButtonDown
              MouseX = GetGadgetAttribute(G_PaletteInk, #PB_Canvas_MouseX)
              MouseY = GetGadgetAttribute(G_PaletteInk, #PB_Canvas_MouseY)
              If MouseX >= 0 And MouseY >= 0
                Idx = (MouseY / #Scr2Ed_PaletteSwatch) * #Scr2Ed_PaletteCols + (MouseX / #Scr2Ed_PaletteSwatch)
                If Idx >= 0 And Idx <= 15
                  InkColor = Idx
                  Scr2Ed_RedrawMiniPalette(G_PaletteInk, InkColor, Palette())
                EndIf
              EndIf
            EndIf

          Case G_PalettePaper
            If EventType() = #PB_EventType_LeftButtonDown
              MouseX = GetGadgetAttribute(G_PalettePaper, #PB_Canvas_MouseX)
              MouseY = GetGadgetAttribute(G_PalettePaper, #PB_Canvas_MouseY)
              If MouseX >= 0 And MouseY >= 0
                Idx = (MouseY / #Scr2Ed_PaletteSwatch) * #Scr2Ed_PaletteCols + (MouseX / #Scr2Ed_PaletteSwatch)
                If Idx >= 0 And Idx <= 15
                  PaperColor = Idx
                  Scr2Ed_RedrawMiniPalette(G_PalettePaper, PaperColor, Palette())
                EndIf
              EndIf
            EndIf

          Case G_ToolTraco, G_ToolBloco, G_ToolLinha, G_ToolRetangulo, G_ToolRaio, G_ToolCirculo, G_ToolPintura, G_ToolSpray, G_ToolFill
            Select EventGadget()
              Case G_ToolTraco     : ToolMode = #GraphosScrTool_Traco
              Case G_ToolBloco     : ToolMode = #GraphosScrTool_Bloco
              Case G_ToolLinha     : ToolMode = #GraphosScrTool_Linha
              Case G_ToolRetangulo : ToolMode = #GraphosScrTool_Retangulo
              Case G_ToolRaio      : ToolMode = #GraphosScrTool_Raio
              Case G_ToolCirculo   : ToolMode = #GraphosScrTool_Circulo
              Case G_ToolPintura   : ToolMode = #GraphosScrTool_Pintura
              Case G_ToolSpray     : ToolMode = #GraphosScrTool_Spray
              Case G_ToolFill      : ToolMode = #GraphosScrTool_Fill
            EndSelect
            SpriteEd_UnpressOtherTools(ToolGadgets(), EventGadget())
            SetGadgetState(EventGadget(), #True)
            DisableGadget(G_Pencil, Bool(Not GraphosScr_ToolUsesPenMode(ToolMode)))
            DisableGadget(G_Eraser, Bool(Not GraphosScr_ToolUsesPenMode(ToolMode)))
            If PendingActive Or TextPlacementActive
              PendingActive = #False
              TextPlacementActive = #False
              Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
            EndIf

          Case G_Pencil
            PenMode = #GraphosPenMode_Insert
            SpriteEd_UnpressOtherTools(PenGadgets(), G_Pencil)
            SetGadgetState(G_Pencil, #True)

          Case G_Eraser
            PenMode = #GraphosPenMode_Delete
            SpriteEd_UnpressOtherTools(PenGadgets(), G_Eraser)
            SetGadgetState(G_Eraser, #True)

          Case G_ClearScreen
            GraphosScr_ClearWithColors(PatternBit(), RowFG(), RowBG(), InkColor, PaperColor)
            PendingActive = #False
            TextPlacementActive = #False
            Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
            SetGadgetText(G_Status, "Tela limpa (Tinta " + Str(InkColor) + ", Fundo " + Str(PaperColor) + ").")

          Case G_TextPlace
            If GetGadgetState(G_TextAlpha) < 0
              MessageRequester("Posicionar TEXTO", "Nenhum alfabeto registrado no projeto - use 'Criar -> Alfabeto Graphos III...' primeiro.",
                                #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
            ElseIf Trim(GetGadgetText(G_TextStr)) = ""
              MessageRequester("Posicionar TEXTO", "Digite um texto antes de posicionar.",
                                #PB_MessageRequester_Ok | #PB_MessageRequester_Info)
            Else
              TextPendingAlpha = Val(Mid(GetGadgetText(G_TextAlpha), 2))
              If ProjectDB::FetchAlphabet(TextPendingAlpha, TextPendingCharset())
                TextPendingStr = GetGadgetText(G_TextStr)
                TextPendingInk = InkColor
                TextPendingPaper = PaperColor
                TextPendingStyle = GetGadgetState(G_TextStyle)
                PendingActive = #False
                TextPlacementActive = #True
                SpriteEd_UnpressOtherTools(ToolGadgets(), -1)
                SetGadgetText(G_Status, "TEXTO: mova o mouse ate o lugar certo e clique no canvas (direito cancela)")
              Else
                MessageRequester("Posicionar TEXTO", "Nao foi possivel carregar o alfabeto #" + Str(TextPendingAlpha) + " do projeto.",
                                  #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
              EndIf
            EndIf

          Case G_Canvas
            Select EventType()
              Case #PB_EventType_LeftButtonDown
                MouseX = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseX)
                MouseY = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseY)
                PX = MouseX / Zoom
                PY = MouseY / Zoom
                If TextPlacementActive
                  GraphosScr_BlitTextStyled(PatternBit(), RowFG(), RowBG(), TextPendingCharset(), TextPendingStr, PX, PY, TextPendingInk, TextPendingPaper, TextPendingStyle)
                  TextPlacementActive = #False
                  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                  SetGadgetText(G_Status, "TEXTO impresso em (" + Str(PX) + "," + Str(PY) + ")")
                ElseIf PX >= 0 And PX < #Scr2_Width And PY >= 0 And PY < #Scr2_Height
                  Select ToolMode

                    Case #GraphosScrTool_Traco, #GraphosScrTool_Pintura, #GraphosScrTool_Spray
                      GraphosScr_ApplyDragTool(PatternBit(), RowFG(), RowBG(), PX, PY, ToolMode, PenMode, InkColor, PaperColor, 1, 1)
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      LastPaintX = PX : LastPaintY = PY
                      SetGadgetText(G_Status, "Pixel (" + Str(PX) + "," + Str(PY) + ")")

                    Case #GraphosScrTool_Bloco
                      BW = GraphosScr_ClampBlockSize(Val(GetGadgetText(G_BlockW)))
                      BH = GraphosScr_ClampBlockSize(Val(GetGadgetText(G_BlockH)))
                      GraphosScr_ApplyDragTool(PatternBit(), RowFG(), RowBG(), PX, PY, ToolMode, PenMode, InkColor, PaperColor, BW, BH)
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      LastPaintX = PX : LastPaintY = PY
                      SetGadgetText(G_Status, "Bloco " + Str(BW) + "x" + Str(BH) + " em (" + Str(PX) + "," + Str(PY) + ")")

                    Case #GraphosScrTool_Fill
                      Scr2_FloodFill(PatternBit(), RowFG(), RowBG(), PX, PY, InkColor, -1)
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      SetGadgetText(G_Status, "FILL a partir de (" + Str(PX) + "," + Str(PY) + ")")

                    Case #GraphosScrTool_Linha
                      If Not PendingActive
                        AnchorX = PX : AnchorY = PY : PendingActive = #True
                        SetGadgetText(G_Status, "LINHA: ponto inicial marcado - clique no ponto final (direito cancela)")
                      Else
                        Scr2_DrawLine(PatternBit(), RowFG(), RowBG(), AnchorX, AnchorY, PX, PY, InkColor)
                        Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                        AnchorX = PX : AnchorY = PY
                        SetGadgetText(G_Status, "LINHA tracada - proximo segmento comeca em (" + Str(PX) + "," + Str(PY) + ")")
                      EndIf

                    Case #GraphosScrTool_Retangulo
                      If Not PendingActive
                        AnchorX = PX : AnchorY = PY : PendingActive = #True
                        SetGadgetText(G_Status, "RETANGULO: vertice fixo marcado - clique no vertice oposto (direito cancela)")
                      Else
                        Scr2_LineStatement(PatternBit(), RowFG(), RowBG(), AnchorX, AnchorY, PX, PY, InkColor, 1)
                        Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                        SetGadgetText(G_Status, "RETANGULO tracado - vertice fixo continua em (" + Str(AnchorX) + "," + Str(AnchorY) + ")")
                      EndIf

                    Case #GraphosScrTool_Raio
                      If Not PendingActive
                        AnchorX = PX : AnchorY = PY : PendingActive = #True
                        SetGadgetText(G_Status, "RAIO: origem fixa marcada - clique no ponto final (direito cancela)")
                      Else
                        Scr2_DrawLine(PatternBit(), RowFG(), RowBG(), AnchorX, AnchorY, PX, PY, InkColor)
                        Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                        SetGadgetText(G_Status, "RAIO tracado - origem continua em (" + Str(AnchorX) + "," + Str(AnchorY) + ")")
                      EndIf

                    Case #GraphosScrTool_Circulo
                      If Not PendingActive
                        AnchorX = PX : AnchorY = PY : PendingActive = #True
                        SetGadgetText(G_Status, "CIRCULO: centro marcado - clique no ponto de passagem (direito cancela)")
                      Else
                        DX = PX - AnchorX : DY = PY - AnchorY
                        Radius = Scr2_RoundF(Sqr(DX * DX + DY * DY))
                        If Radius < 1 : Radius = 1 : EndIf
                        Scr2_DrawCircle(PatternBit(), RowFG(), RowBG(), AnchorX, AnchorY, Radius, InkColor, 0, 0, 0)
                        Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                        SetGadgetText(G_Status, "CIRCULO tracado (raio " + Str(Radius) + ") - centro continua em (" + Str(AnchorX) + "," + Str(AnchorY) + ")")
                      EndIf

                  EndSelect
                EndIf

              Case #PB_EventType_RightButtonDown
                If PendingActive Or TextPlacementActive
                  PendingActive = #False
                  TextPlacementActive = #False
                  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                  SetGadgetText(G_Status, "Operacao cancelada.")
                EndIf

              Case #PB_EventType_MouseMove
                MouseX = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseX)
                MouseY = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseY)
                PX = MouseX / Zoom
                PY = MouseY / Zoom
                If TextPlacementActive
                  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                  GraphosScr_DrawTextPreview(G_Canvas, TextPendingCharset(), TextPendingStr, PX, PY, Palette(TextPendingInk), Palette(TextPendingPaper), TextPendingStyle)
                Else
                Select ToolMode
                  Case #GraphosScrTool_Traco, #GraphosScrTool_Bloco, #GraphosScrTool_Pintura, #GraphosScrTool_Spray
                    If GetGadgetAttribute(G_Canvas, #PB_Canvas_Buttons) & #PB_Canvas_LeftButton
                      If PX >= 0 And PX < #Scr2_Width And PY >= 0 And PY < #Scr2_Height And (PX <> LastPaintX Or PY <> LastPaintY)
                        If ToolMode = #GraphosScrTool_Bloco
                          BW = GraphosScr_ClampBlockSize(Val(GetGadgetText(G_BlockW)))
                          BH = GraphosScr_ClampBlockSize(Val(GetGadgetText(G_BlockH)))
                        Else
                          BW = 1 : BH = 1
                        EndIf
                        GraphosScr_ApplyDragTool(PatternBit(), RowFG(), RowBG(), PX, PY, ToolMode, PenMode, InkColor, PaperColor, BW, BH)
                        Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                        LastPaintX = PX : LastPaintY = PY
                      EndIf
                    EndIf

                  Case #GraphosScrTool_Linha, #GraphosScrTool_Raio
                    If PendingActive
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      Scr2Ed_DrawLinePreview(G_Canvas, AnchorX, AnchorY, PX, PY, 0)
                    EndIf

                  Case #GraphosScrTool_Retangulo
                    If PendingActive
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      Scr2Ed_DrawLinePreview(G_Canvas, AnchorX, AnchorY, PX, PY, 1)
                    EndIf

                  Case #GraphosScrTool_Circulo
                    If PendingActive
                      Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                      Scr2Ed_DrawCirclePreview(G_Canvas, AnchorX, AnchorY, PX, PY, #False)
                    EndIf

                EndSelect
                EndIf
            EndSelect

          Case G_Close
            Quit = #True

        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True

    EndSelect
  Until Quit

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
EndProcedure
