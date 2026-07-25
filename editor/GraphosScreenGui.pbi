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
;  ESTE PRIMEIRO CORTE cobre so "a tela que representa a SCREEN 2" pedida
;  explicitamente pelo usuario como ponto de partida - a limitacao de
;  hardware de 2 cores por faixa de 8 pixels (color clash) precisa ficar
;  IDENTICA ao MSX de verdade. Em vez de reescrever esse modelo, reaproveita
;  na integra o motor ja existente e validado por 69 casos de teste
;  (editor/Screen2Synth.pbi: Scr2_SetPixel/GetPixelColor/ClearFramebuffer -
;  mesmo PatternBit/RowFG/RowBG do editor "Criar -> Draw Screen 2...") e os
;  helpers de desenho de canvas/paleta ja escritos em
;  editor/Screen2EditorGui.pbi (Scr2Ed_RedrawCanvas/RedrawMiniPalette) -
;  nenhum dos dois precisou de nenhuma mudanca. Ferramentas cobertas nesta
;  fase: TRACO (Lapis = liga com INK, Borracha = apaga com PAPER, ambas com
;  arrastar continuo - mesmo padrao de SpriteEd_ApplyTool) e LIMPA TELA (menu
;  TELA do original). O restante do menu DESENHO (BLOCO/LINHA/RETANGULO/
;  RAIO/CIRCULO/PINTURA/SPRAY/FILL), TEXTO, AJUSTE, MISCELANEA (ZOOM/SHAPE/
;  CORTE/GRID), persistencia no projeto e os formatos de arquivo SCR/LAY/
;  VTC+ATC do Graphos III ficam para os proximos cortes.
; ------------------------------------------------------------
;

Enumeration GraphosScrTool
  #GraphosScrTool_Pencil
  #GraphosScrTool_Eraser
EndEnumeration

; TRACO do Graphos III: Lapis = INS (seta o pixel com a cor de INK, ver
; Scr2_SetPixel TurnOn=#True); Borracha = DEL (reseta o pixel, gravando a
; cor de PAPER na faixa, ver Scr2_SetPixel TurnOn=#False) - mesma semantica
; do PSET/PRESET ja usados por Scr2EditorGui.pbi.
Procedure GraphosScr_ApplyTool(Array PatternBit.a(2), Array RowFG.a(2), Array RowBG.a(2), X.i, Y.i, ToolMode.i, InkColor.i, PaperColor.i)
  Select ToolMode
    Case #GraphosScrTool_Pencil
      Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, InkColor, #True)
    Case #GraphosScrTool_Eraser
      Scr2_SetPixel(PatternBit(), RowFG(), RowBG(), X, Y, PaperColor, #False)
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

Procedure GraphosScreenGui_OpenWindow(ParentWindow)
  Protected Zoom = 2
  Protected CanvasW = #Scr2_Width * Zoom, CanvasH = #Scr2_Height * Zoom
  Protected CanvasX = 15, CanvasY = 50
  Protected RightX = CanvasX + CanvasW + 20
  Protected RightW = 160
  Protected WinW = RightX + RightW + 15
  Protected WinH = CanvasY + CanvasH + 55

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
  Protected PaletteSize = #Scr2Ed_PaletteSize
  TextGadget(#PB_Any, RightX, CanvasY, RightW, 18, "Tinta (INK):")
  Protected G_PaletteInk = CanvasGadget(#PB_Any, RightX, CanvasY + 18, PaletteSize, PaletteSize)
  Protected PaperY = CanvasY + 18 + PaletteSize + 14
  TextGadget(#PB_Any, RightX, PaperY, RightW, 18, "Fundo (PAPER):")
  Protected G_PalettePaper = CanvasGadget(#PB_Any, RightX, PaperY + 18, PaletteSize, PaletteSize)

  ; --- Ferramentas (TRACO do menu DESENHO/F1 - Lapis/Borracha, mesmos
  ; icones/toggle do editor de sprites) ---
  Protected ToolsY = PaperY + 18 + PaletteSize + 16
  Protected PencilIcon = SpriteEd_CreatePencilIcon(22)
  Protected G_Pencil = ButtonImageGadget(#PB_Any, RightX, ToolsY, 34, 30, ImageID(PencilIcon), #PB_Button_Toggle)
  GadgetToolTip(G_Pencil, "Lapis (TRACO/INS): liga o pixel com a cor de Tinta - arraste pra riscar")
  Protected EraserIcon = SpriteEd_CreateEraserIcon(22)
  Protected G_Eraser = ButtonImageGadget(#PB_Any, RightX + 34 + 6, ToolsY, 34, 30, ImageID(EraserIcon), #PB_Button_Toggle)
  GadgetToolTip(G_Eraser, "Borracha (TRACO/DEL): apaga o pixel usando a cor de Fundo - arraste pra apagar")
  Dim ToolGadgets.i(1)
  ToolGadgets(0) = G_Pencil
  ToolGadgets(1) = G_Eraser

  Protected ClearY = ToolsY + 30 + 16
  Protected G_ClearScreen = ButtonGadget(#PB_Any, RightX, ClearY, RightW, 28, "Limpar tela")
  GadgetToolTip(G_ClearScreen, "LIMPA TELA (menu TELA): apaga tudo com as cores Tinta/Fundo atuais")

  Protected StatusY = ClearY + 28 + 14
  Protected G_Status = TextGadget(#PB_Any, RightX, StatusY, RightW, 90, "")

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
  Protected ToolMode.i = #GraphosScrTool_Pencil
  Protected LastPaintX.i = -1, LastPaintY.i = -1

  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
  Scr2Ed_RedrawMiniPalette(G_PaletteInk, InkColor, Palette())
  Scr2Ed_RedrawMiniPalette(G_PalettePaper, PaperColor, Palette())
  SetGadgetState(G_Pencil, #True)

  Protected Event, Quit = #False
  Protected MouseX, MouseY, PX, PY, Idx
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

          Case G_Pencil
            ToolMode = #GraphosScrTool_Pencil
            SpriteEd_UnpressOtherTools(ToolGadgets(), G_Pencil)
            SetGadgetState(G_Pencil, #True)

          Case G_Eraser
            ToolMode = #GraphosScrTool_Eraser
            SpriteEd_UnpressOtherTools(ToolGadgets(), G_Eraser)
            SetGadgetState(G_Eraser, #True)

          Case G_ClearScreen
            GraphosScr_ClearWithColors(PatternBit(), RowFG(), RowBG(), InkColor, PaperColor)
            Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
            SetGadgetText(G_Status, "Tela limpa (Tinta " + Str(InkColor) + ", Fundo " + Str(PaperColor) + ").")

          Case G_Canvas
            Select EventType()
              Case #PB_EventType_LeftButtonDown
                MouseX = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseX)
                MouseY = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseY)
                PX = MouseX / Zoom
                PY = MouseY / Zoom
                If PX >= 0 And PX < #Scr2_Width And PY >= 0 And PY < #Scr2_Height
                  GraphosScr_ApplyTool(PatternBit(), RowFG(), RowBG(), PX, PY, ToolMode, InkColor, PaperColor)
                  Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                  LastPaintX = PX : LastPaintY = PY
                  SetGadgetText(G_Status, "Pixel (" + Str(PX) + "," + Str(PY) + ")")
                EndIf

              Case #PB_EventType_MouseMove
                If GetGadgetAttribute(G_Canvas, #PB_Canvas_Buttons) & #PB_Canvas_LeftButton
                  MouseX = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseX)
                  MouseY = GetGadgetAttribute(G_Canvas, #PB_Canvas_MouseY)
                  PX = MouseX / Zoom
                  PY = MouseY / Zoom
                  If PX >= 0 And PX < #Scr2_Width And PY >= 0 And PY < #Scr2_Height And (PX <> LastPaintX Or PY <> LastPaintY)
                    GraphosScr_ApplyTool(PatternBit(), RowFG(), RowBG(), PX, PY, ToolMode, InkColor, PaperColor)
                    Scr2Ed_RedrawCanvas(G_Canvas, PatternBit(), RowFG(), RowBG(), Palette())
                    LastPaintX = PX : LastPaintY = PY
                  EndIf
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
