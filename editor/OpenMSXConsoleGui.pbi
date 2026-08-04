;
; ------------------------------------------------------------
;  OpenMSXConsoleGui.pbi - janela do menu "Executar -> openMSX": abre o
;  openMSX com o pipe de comandos ligado (ver OpenMSXBridge.pbi) e da uma
;  caixa de log + campo de comando pra digitar qualquer comando que o
;  openMSX aceita via "-control stdio" (comandos TCL do proprio emulador:
;  "reset", "set pause on", "screenshot", etc. - ver documentacao "External
;  control protocol" do openMSX).
;
;  Fechar esta janela NAO fecha o openMSX - o processo continua rodando
;  (guardado em OMSX_Prog, ver OpenMSXBridge.pbi). Abrir "Executar ->
;  openMSX" de novo so reconecta uma nova janela de console ao MESMO
;  processo, pra dar pra alternar entre editar codigo e mandar comando sem
;  perder a sessao do emulador. Se o usuario fechar o openMSX por fora (ou
;  ele cair), o poll detecta isso e desativa os controles da janela.
; ------------------------------------------------------------
;

#OMSXGui_PollTimer = 9000
#OMSXGui_EnterShortcut = 9001

; Acrescenta Text (uma ou mais linhas separadas por Chr(10), "" ignorado) ao final do log,
; convertendo pra CRLF (EditorGadget nativo) e rolando pro fim. Recebe/devolve o texto
; acumulado (Accum) explicitamente, em vez de reler o conteudo atual via GetGadgetText() -
; relato real de uso (2026-07-30): depois de alguns comandos (ex. consultar "set renderer"),
; o log "esvaziava" sozinho e so o texto mais novo continuava aparecendo dali pra frente,
; mesmo o openMSX continuando a responder normalmente por baixo (confirmado nao ser
; travamento do openMSX nem do pipe/protocolo - ver OpenMSXBridge.pbi). Causa exata dentro
; do controle nativo nao identificada, mas manter o acumulado so do nosso lado (nunca
; dependendo do widget "lembrar" o que ja escrevemos) elimina essa classe inteira de bug,
; nao so o sintoma pontual.
Procedure.s OMSXGui_AppendLog(G_Log, Accum.s, Text.s)
  If Text = ""
    ProcedureReturn Accum
  EndIf
  Protected Add.s = ReplaceString(RTrim(Text, Chr(10)), Chr(10), Chr(13) + Chr(10))
  If Add = ""
    ProcedureReturn Accum
  EndIf
  If Accum <> ""
    Accum + Chr(13) + Chr(10)
  EndIf
  Accum + Add
  SetGadgetText(G_Log, Accum)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    SendMessage_(GadgetID(G_Log), #EM_LINESCROLL, 0, 999999)
  CompilerEndIf
  ProcedureReturn Accum
EndProcedure

; Le o texto do campo de comando, manda pro openMSX e ecoa no log - usado
; tanto pelo botao "Enviar" quanto pelo atalho Enter (#OMSXGui_EnterShortcut).
; Mesmo motivo de OMSXGui_AppendLog() acima: recebe/devolve o acumulado.
Procedure.s OMSXGui_Send(G_Log, G_Input, Accum.s)
  Protected Cmd.s = Trim(GetGadgetText(G_Input))
  If Cmd = ""
    ProcedureReturn Accum
  EndIf
  Accum = OMSXGui_AppendLog(G_Log, Accum, "> " + Cmd)
  OMSX_SendCommand(Cmd)
  SetGadgetText(G_Input, "")
  ProcedureReturn Accum
EndProcedure

Procedure OMSXGui_OpenWindow(ParentWindow)
  If BadigCfg\EmulatorPath = ""
    MessageRequester("openMSX nao configurado",
                     "Configure o caminho do executavel do openMSX em" + Chr(10) +
                     "Configurar -> Basic Dignified... -> aba Emulador.",
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected AlreadyRunning.b = OMSX_IsRunning()
  If Not OMSX_Start()
    MessageRequester("Erro", "Nao foi possivel executar o openMSX:" + Chr(10) + BadigCfg\EmulatorPath,
                     #PB_MessageRequester_Ok | #PB_MessageRequester_Error)
    ProcedureReturn
  EndIf

  Protected WinW = 940, WinH = 556
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "openMSX - console de comandos",
                              #PB_Window_SystemMenu | #PB_Window_ScreenCentered | #PB_Window_SizeGadget)
  If Not Win
    ProcedureReturn
  EndIf
  App_ApplyWindowIcon(Win)
  ; Mesmo motivo de toda outra janela secundaria deste app (ver
  ; DiskManagerGui.pbi, HexEditorGui.pbi, etc.): o loop de eventos e
  ; compartilhado (WaitWindowEvent() pega evento de QUALQUER janela aberta),
  ; entao sem desabilitar a janela principal os cliques/teclas nela ficariam
  ; "perdidos" (chegam neste loop, que nao sabe tratar os gadgets dela) em
  ; vez de irem pro loop principal - a janela ficaria parecendo travada. O
  ; openMSX (processo a parte) continua rodando normalmente enquanto isso;
  ; so a EDICAO fica bloqueada ate fechar este console.
  DisableWindow(ParentWindow, #True)

  ; Indicador de estado (Ligado/Desligado, Rodando/Pausado) - ver OMSX_StatusText() em
  ; OpenMSXBridge.pbi. Alimentado por "<update type="setting" ...>" (assinado no boot,
  ; OMSX_PipeConnectThread()), entao reflete o estado real mesmo se ele mudar por outro
  ; caminho que nao um comando mandado por esta janela (ex. o usuario pausando pela
  ; propria janela do openMSX).
  Protected G_Status     = TextGadget(#PB_Any, 24, 24, WinW - 48, 20, "Estado: ?  |  ?", #PB_Text_Center)
  Protected G_Log        = EditorGadget(#PB_Any, 24, 60, WinW - 48, 190, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)

  ; Area de colar/editar texto pra "digitar" no MSX de verdade (mesmo mecanismo do
  ; Catapult - InputPage.cpp/OnTypeText() - ver OMSX_TypeText() em OpenMSXBridge.pbi).
  ; EditorGadget sem #PB_Editor_ReadOnly ja aceita colar (Ctrl+V) nativamente, sem
  ; codigo extra nenhum.
  Protected G_PasteLabel = TextGadget(#PB_Any, 24, 266, WinW - 48, 18,
                                       "Colar/editar texto abaixo e clicar em " + Chr(34) + "Inserir no openMSX" + Chr(34) + " pra digitar no MSX:")
  Protected G_PasteInput = EditorGadget(#PB_Any, 24, 292, WinW - 48, 110, #PB_Editor_WordWrap)
  Protected G_InsertText = ButtonGadget(#PB_Any, 24, 418, 220, 28, "Inserir no openMSX")
  Protected G_ClearPaste = ButtonGadget(#PB_Any, 256, 418, 100, 28, "Limpar")
  GadgetToolTip(G_InsertText, "Digita o texto acima no MSX como se fosse teclado (comando " + Chr(34) + "type" + Chr(34) + " do openMSX - mesmo mecanismo do Catapult). Quebras de linha viram Enter.")

  Protected G_Input      = StringGadget(#PB_Any, 24, 462, 782, 24, "")
  Protected G_Send       = ButtonGadget(#PB_Any, 814, 462, 102, 24, "Enviar" + Chr(9) + "Enter")
  Protected G_Reset      = ButtonGadget(#PB_Any, 24, 502, 95, 28, "Reset")
  Protected G_Pause      = ButtonGadget(#PB_Any, 133, 502, 95, 28, "Pausar")
  Protected G_Resume     = ButtonGadget(#PB_Any, 242, 502, 95, 28, "Continuar")
  Protected G_PowerOn    = ButtonGadget(#PB_Any, 351, 502, 85, 28, "Ligar")
  Protected G_PowerOff   = ButtonGadget(#PB_Any, 450, 502, 85, 28, "Desligar")
  Protected G_ShowWindow = ButtonGadget(#PB_Any, 549, 502, 130, 28, "Mostrar janela")
  Protected G_Help       = ButtonGadget(#PB_Any, 693, 502, 90, 28, "Ajuda")
  Protected G_Close      = ButtonGadget(#PB_Any, 797, 502, 119, 28, "Fechar janela")
  GadgetToolTip(G_ShowWindow, "Envia " + Chr(34) + "unset renderer" + Chr(34) + " - o openMSX sobe com -control em modo sem janela (renderer none) ate isso ser enviado")
  GadgetToolTip(G_Help, "Abre a Ajuda -> openMSX (consulta de comandos/configuracoes)")

  SetActiveGadget(G_Input)
  AddWindowTimer(Win, #OMSXGui_PollTimer, 150)
  AddKeyboardShortcut(Win, #PB_Shortcut_Return, #OMSXGui_EnterShortcut)

  If OMSX_IsRunning()
    SetGadgetText(G_Status, "Estado: " + OMSX_StatusText())
  EndIf

  Protected LogAccum.s = ""
  If AlreadyRunning
    LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, "--- reconectado ao openMSX ja aberto (" + BadigCfg\EmulatorPath + ") ---")
  Else
    LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, "--- iniciando openMSX (" + BadigCfg\EmulatorPath + ") ---")
  EndIf

  Protected Event, Quit.b = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Menu
        If EventMenu() = #OMSXGui_EnterShortcut
          LogAccum = OMSXGui_Send(G_Log, G_Input, LogAccum)
        EndIf

      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_Send
            LogAccum = OMSXGui_Send(G_Log, G_Input, LogAccum)

          Case G_Reset
            OMSX_SendCommand("reset")
          Case G_Pause
            OMSX_SendCommand("set pause on")
          Case G_Resume
            OMSX_SendCommand("set pause off")
          Case G_PowerOn
            OMSX_SendCommand("set power on")
          Case G_PowerOff
            OMSX_SendCommand("set power off")
          Case G_ShowWindow
            LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, "> unset renderer")
            OMSX_ShowWindow()

          Case G_InsertText
            Protected PasteText.s = GetGadgetText(G_PasteInput)
            If Trim(PasteText) <> ""
              LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, "> [digitando " + Str(Len(PasteText)) + " caracteres no MSX]")
              OMSX_TypeText(PasteText)
            EndIf

          Case G_ClearPaste
            SetGadgetText(G_PasteInput, "")

          Case G_Help
            OpenMsxHelp_OpenWindow(Win)

          Case G_Close
            Quit = #True
        EndSelect

      Case #PB_Event_Timer
        If EventTimer() = #OMSXGui_PollTimer
          If OMSX_IsRunning()
            LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, OMSX_Poll())
            SetGadgetText(G_Status, "Estado: " + OMSX_StatusText())
          Else
            LogAccum = OMSXGui_AppendLog(G_Log, LogAccum, "--- openMSX foi encerrado ---")
            SetGadgetText(G_Status, "Estado: openMSX encerrado")
            DisableGadget(G_Input, #True)
            DisableGadget(G_Send, #True)
            DisableGadget(G_Reset, #True)
            DisableGadget(G_Pause, #True)
            DisableGadget(G_Resume, #True)
            DisableGadget(G_PowerOn, #True)
            DisableGadget(G_PowerOff, #True)
            DisableGadget(G_ShowWindow, #True)
            DisableGadget(G_InsertText, #True)
            RemoveWindowTimer(Win, #OMSXGui_PollTimer)
          EndIf
        EndIf

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  If OMSX_IsRunning()
    RemoveWindowTimer(Win, #OMSXGui_PollTimer)
  EndIf
  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
EndProcedure
