;
; ------------------------------------------------------------
;  OpenMsxSettingsGui.pbi - janela "Configurar -> openMSX...": versao
;  standalone dos MESMOS campos da aba "Emulador" de
;  "Configurar -> Basic Dignified..." (BadigCfg_OpenSettingsWindow, em
;  BadigSettings.pbi). Usa os procedimentos compartilhados de la
;  (BadigCfg_CreateEmulatorGadgets/ApplyEmulatorDefaults/
;  HandleEmulatorGadgetEvent/ApplyEmulatorGadgetsToConfig) pra nunca divergir:
;  as duas telas leem/gravam os mesmos campos BadigCfg\Em*, persistidos no
;  mesmo badig_settings.json (BadigCfg_Save()) e sincronizados de volta no
;  mesmo emulator_interface.ini (BadigCfg_SyncEmulatorIni()). Mantida
;  separada a pedido do usuario (quer as duas telas, nao substituir uma pela
;  outra) - ver o cabecalho de BadigSettings.pbi pro motivo de nao duplicar
;  os campos em vez de compartilhar.
; ------------------------------------------------------------
;

Procedure OpenMsxCfg_OpenSettingsWindow(ParentWindow)
  ; Mesma grade de layout das outras janelas de configuracao (24px de margem
  ; externa). WinW = 680 pra caber os mesmos campos da aba "Emulador"
  ; (512 + 8 + 64 = 584 de conteudo util, mais as margens de 24 dos dois
  ; lados) sem quebrar layout - identico ao WinW de BadigCfg_OpenSettingsWindow().
  Protected WinW = 680, WinH = 592
  Protected Win = OpenWindow(#PB_Any, 0, 0, WinW, WinH, "Configuracoes do openMSX",
                             #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  If Not Win
    ProcedureReturn
  EndIf
  App_ApplyWindowIcon(Win)
  DisableWindow(ParentWindow, #True)

  Protected EmuG.BadigCfg_EmuGadgets
  BadigCfg_CreateEmulatorGadgets(0, @EmuG)
  BadigCfg_ApplyEmulatorDefaults(@EmuG)

  Protected G_Save = ButtonGadget(#PB_Any, WinW - 256, WinH - 56, 110, 32, "Salvar")
  Protected G_Cancel = ButtonGadget(#PB_Any, WinW - 134, WinH - 56, 110, 32, "Cancelar")

  Protected Event, Quit = #False, Saved = #False

  Repeat
    Event = WaitWindowEvent()

    Select Event
      Case #PB_Event_Gadget
        Select EventGadget()
          Case EmuG\G_EmSettingBrowse, EmuG\G_EmulatorPathBrowse, EmuG\G_EmMachineBrowse, EmuG\G_EmExtensionBrowse
            BadigCfg_HandleEmulatorGadgetEvent(Win, EventGadget(), @EmuG)

          Case G_Save
            Saved = #True
            Quit = #True

          Case G_Cancel
            Quit = #True
        EndSelect

      Case #PB_Event_CloseWindow
        Quit = #True
    EndSelect
  Until Quit

  If Saved
    BadigCfg_ApplyEmulatorGadgetsToConfig(@EmuG)
    BadigCfg_Save()
    BadigCfg_SyncEmulatorIni()
  EndIf

  DisableWindow(ParentWindow, #False)
  CloseWindow(Win)
EndProcedure
