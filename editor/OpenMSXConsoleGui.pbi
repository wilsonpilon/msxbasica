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

; Acrescenta Text (uma ou mais linhas separadas por Chr(10), "" ignorado) ao
; final do log, convertendo pra CRLF (EditorGadget nativo) e rolando pro
; fim.
Procedure OMSXGui_AppendLog(G_Log, Text.s)
  If Text = ""
    ProcedureReturn
  EndIf
  Protected Cur.s = GetGadgetText(G_Log)
  Protected Add.s = ReplaceString(RTrim(Text, Chr(10)), Chr(10), Chr(13) + Chr(10))
  If Add = ""
    ProcedureReturn
  EndIf
  If Cur <> ""
    Cur + Chr(13) + Chr(10)
  EndIf
  Cur + Add
  SetGadgetText(G_Log, Cur)
  CompilerIf #PB_Compiler_OS = #PB_OS_Windows
    SendMessage_(GadgetID(G_Log), #EM_LINESCROLL, 0, 999999)
  CompilerEndIf
EndProcedure

; Le o texto do campo de comando, manda pro openMSX e ecoa no log - usado
; tanto pelo botao "Enviar" quanto pelo atalho Enter (#OMSXGui_EnterShortcut).
Procedure OMSXGui_Send(G_Log, G_Input)
  Protected Cmd.s = Trim(GetGadgetText(G_Input))
  If Cmd = ""
    ProcedureReturn
  EndIf
  OMSXGui_AppendLog(G_Log, "> " + Cmd)
  OMSX_SendCommand(Cmd)
  SetGadgetText(G_Input, "")
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

  Protected Win = OpenWindow(#PB_Any, 0, 0, 900, 420, "openMSX - console de comandos",
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

  Protected G_Log        = EditorGadget(#PB_Any, 10, 10, 880, 300, #PB_Editor_ReadOnly | #PB_Editor_WordWrap)
  Protected G_Input      = StringGadget(#PB_Any, 10, 322, 770, 24, "")
  Protected G_Send       = ButtonGadget(#PB_Any, 788, 322, 102, 24, "Enviar" + Chr(9) + "Enter")
  Protected G_Reset      = ButtonGadget(#PB_Any, 10, 356, 95, 28, "Reset")
  Protected G_Pause      = ButtonGadget(#PB_Any, 112, 356, 95, 28, "Pausar")
  Protected G_Resume     = ButtonGadget(#PB_Any, 214, 356, 95, 28, "Continuar")
  Protected G_PowerOn    = ButtonGadget(#PB_Any, 316, 356, 85, 28, "Ligar")
  Protected G_PowerOff   = ButtonGadget(#PB_Any, 408, 356, 85, 28, "Desligar")
  Protected G_ShowWindow = ButtonGadget(#PB_Any, 500, 356, 130, 28, "Mostrar janela")
  Protected G_Help       = ButtonGadget(#PB_Any, 637, 356, 90, 28, "Ajuda")
  Protected G_Close      = ButtonGadget(#PB_Any, 734, 356, 120, 28, "Fechar janela")
  GadgetToolTip(G_ShowWindow, "Envia " + Chr(34) + "unset renderer" + Chr(34) + " - o openMSX sobe com -control em modo sem janela (renderer none) ate isso ser enviado")
  GadgetToolTip(G_Help, "Abre a Ajuda -> openMSX (consulta de comandos/configuracoes)")

  SetActiveGadget(G_Input)
  AddWindowTimer(Win, #OMSXGui_PollTimer, 150)
  AddKeyboardShortcut(Win, #PB_Shortcut_Return, #OMSXGui_EnterShortcut)

  If AlreadyRunning
    OMSXGui_AppendLog(G_Log, "--- reconectado ao openMSX ja aberto (" + BadigCfg\EmulatorPath + ") ---")
  Else
    OMSXGui_AppendLog(G_Log, "--- iniciando openMSX (" + BadigCfg\EmulatorPath + ") ---")
  EndIf

  Protected Event, Quit.b = #False
  Repeat
    Event = WaitWindowEvent()
    Select Event
      Case #PB_Event_Menu
        If EventMenu() = #OMSXGui_EnterShortcut
          OMSXGui_Send(G_Log, G_Input)
        EndIf

      Case #PB_Event_Gadget
        Select EventGadget()
          Case G_Send
            OMSXGui_Send(G_Log, G_Input)

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
            OMSXGui_AppendLog(G_Log, "> unset renderer")
            OMSX_ShowWindow()

          Case G_Help
            OpenMsxHelp_OpenWindow(Win)

          Case G_Close
            Quit = #True
        EndSelect

      Case #PB_Event_Timer
        If EventTimer() = #OMSXGui_PollTimer
          If OMSX_IsRunning()
            OMSXGui_AppendLog(G_Log, OMSX_Poll())
          Else
            OMSXGui_AppendLog(G_Log, "--- openMSX foi encerrado ---")
            DisableGadget(G_Input, #True)
            DisableGadget(G_Send, #True)
            DisableGadget(G_Reset, #True)
            DisableGadget(G_Pause, #True)
            DisableGadget(G_Resume, #True)
            DisableGadget(G_PowerOn, #True)
            DisableGadget(G_PowerOff, #True)
            DisableGadget(G_ShowWindow, #True)
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
