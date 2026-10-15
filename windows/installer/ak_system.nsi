; Windows installer for AK System, built by the automatic build
; (.github/workflows/build.yml) with NSIS 3, which is free for any use:
;   makensis -DAPP_VERSION=11 windows\installer\ak_system.nsi
; Installs for the current user only, so installing and updating never ask
; for administrator rights. The app's data is kept in the user's AppData
; folder, never in the program folder, so updates and uninstalls keep it.
;
; Updates: the app downloads the new installer, runs it with /S and closes.
; The installer waits for the app to close, replaces the program files and
; opens the app again. Version 10 was built with Inno Setup and runs it with
; Inno's /SILENT, which is understood too; the Inno uninstaller is replaced.

Unicode true
ManifestDPIAware true
RequestExecutionLevel user
SetCompressor /SOLID lzma

!ifndef APP_VERSION
  !define APP_VERSION 0
!endif
!define APP_NAME "AK System"
!define APP_EXE "ak_system.exe"
!define PUBLISHER "AK Design and Construction"
!define UNINSTALLER "Uninstall AK System.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AKSystem"
; Where version 10 (Inno Setup) registered its uninstaller.
!define INNO_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\{DEDAA2FB-F2D1-42C5-9558-7FA502277E21}_is1"

!include MUI2.nsh
!include LogicLib.nsh
!include FileFunc.nsh
!include x64.nsh

Name "${APP_NAME}"
OutFile "..\..\dist\AK-System-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\AK System"
BrandingText "${PUBLISHER}"

VIProductVersion "${APP_VERSION}.0.0.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey "FileVersion" "${APP_VERSION}.0.0.0"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "${PUBLISHER}"

!define MUI_ICON "..\runner\resources\app_icon.ico"
!define MUI_UNICON "..\runner\resources\app_icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "wizard.bmp"

!define MUI_WELCOMEPAGE_TITLE "AK System ${APP_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This installs AK System for your Windows account. No administrator rights are needed.$\r$\n$\r$\nYour projects and documents are kept when a new version is installed.$\r$\n$\r$\nClick Install to continue."
!define MUI_PAGE_CUSTOMFUNCTION_SHOW WelcomeShow
!insertmacro MUI_PAGE_WELCOME

!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "AK System is installed"
!define MUI_FINISHPAGE_TEXT "It is in your Start menu. When a new version is ready, AK System shows it at the top and installs it with one click."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Open AK System now"
; The second tick box puts a shortcut on the desktop.
!define MUI_FINISHPAGE_SHOWREADME ""
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Put a shortcut on the desktop"
!define MUI_FINISHPAGE_SHOWREADME_FUNCTION DesktopShortcut
!insertmacro MUI_PAGE_FINISH

!define MUI_UNCONFIRMPAGE_TEXT_TOP "AK System will be removed from this computer. Your projects and documents stay in your Windows account and come back if you install AK System again."
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "AK System needs 64-bit Windows." /SD IDOK
    Abort
  ${EndIf}
  ; Version 10 of the app starts updates with Inno Setup's switches.
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/SILENT" $R1
  ${IfNot} ${Errors}
    SetSilent silent
  ${EndIf}
  ClearErrors
  ${GetOptions} $R0 "/VERYSILENT" $R1
  ${IfNot} ${Errors}
    SetSilent silent
  ${EndIf}
FunctionEnd

Function WelcomeShow
  GetDlgItem $0 $HWNDPARENT 1
  SendMessage $0 ${WM_SETTEXT} 0 "STR:$(^InstallBtn)"
FunctionEnd

Function DesktopShortcut
  SetShellVarContext current
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
FunctionEnd

; Waits until AK System is closed, so its files can be replaced. During an
; update the app closes itself; if it has not after 20 seconds it is stopped.
; Started by hand while the app is open, the installer asks to close it.
!macro WAIT_FOR_APP un
Function ${un}WaitForApp
  StrCpy $R9 0 ; half seconds waited
  StrCpy $R8 0 ; 1 once the app was stopped
  check:
    IfFileExists "$INSTDIR\${APP_EXE}" 0 free
    ClearErrors
    FileOpen $0 "$INSTDIR\${APP_EXE}" a
    IfErrors busy
    FileClose $0
    Goto free
  busy:
    IfSilent 0 ask
    IntOp $R9 $R9 + 1
    IntCmp $R9 40 0 wait 0
    StrCmp $R8 1 free ; still open: copying the files reports it
    nsExec::Exec '"$SYSDIR\taskkill.exe" /F /IM ${APP_EXE}'
    Pop $0
    StrCpy $R8 1
    StrCpy $R9 30 ; 5 more seconds
  wait:
    Sleep 500
    Goto check
  ask:
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "AK System is open. Close it, then click Retry." IDRETRY check
    Abort
  free:
FunctionEnd
!macroend
!insertmacro WAIT_FOR_APP ""
!insertmacro WAIT_FOR_APP "un."

Section "Install"
  SetShellVarContext current
  Call WaitForApp
  SetOutPath "$INSTDIR"
  ; Program files only; the data in AppData is never touched.
  RMDir /r "$INSTDIR\data"
  File /r "..\..\build\windows\x64\runner\Release\*.*"

  ; Take over from version 10's Inno Setup uninstaller.
  DeleteRegKey HKCU "${INNO_KEY}"
  Delete "$INSTDIR\unins000.exe"
  Delete "$INSTDIR\unins000.dat"
  Delete "$INSTDIR\unins000.msg"

  CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  WriteUninstaller "$INSTDIR\${UNINSTALLER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://www.ak-dac.com"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALLER}" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

; After an update the app opens again by itself.
Function .onInstSuccess
  ${If} ${Silent}
    Exec '"$INSTDIR\${APP_EXE}"'
  ${EndIf}
FunctionEnd

Function .onInstFailed
  ${If} ${Silent}
    MessageBox MB_ICONEXCLAMATION "AK System could not be updated. Open AK System from the Start menu; it will offer the update again."
  ${EndIf}
FunctionEnd

Section "Uninstall"
  SetShellVarContext current
  Call un.WaitForApp
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$INSTDIR\data"
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\${UNINSTALLER}"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
