; Windows installer for AK System, built by the automatic build
; (.github/workflows/build.yml) with Inno Setup 6:
;   ISCC /DAppVersion=10 windows\installer\ak_system.iss
; Installs for the current user only, so installing and updating never ask
; for administrator rights. The app's data is kept in the user's AppData
; folder, never in the program folder, so updates and uninstalls keep it.

#ifndef AppVersion
  #define AppVersion "0"
#endif

[Setup]
; Never change AppId: it is how Windows knows a new version replaces the
; old one.
AppId={{DEDAA2FB-F2D1-42C5-9558-7FA502277E21}
AppName=AK System
AppVersion={#AppVersion}
AppVerName=AK System {#AppVersion}
AppPublisher=AK Design and Construction
AppPublisherURL=https://www.ak-dac.com
VersionInfoVersion={#AppVersion}.0.0.0
DefaultDirName={localappdata}\Programs\AK System
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=AK-System-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\ak_system.exe
UninstallDisplayName=AK System
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; If the app is still open, close it before replacing its files.
CloseApplications=force
RestartApplications=no
; Stopping half way would leave the app unable to start.
AllowCancelDuringInstall=no

[Tasks]
Name: "desktopicon"; Description: "Put a shortcut on the desktop"; GroupDescription: "Shortcuts:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AK System"; Filename: "{app}\ak_system.exe"
Name: "{autodesktop}\AK System"; Filename: "{app}\ak_system.exe"; Tasks: desktopicon

[Run]
; Also runs after a silent update, so the app opens again by itself.
Filename: "{app}\ak_system.exe"; Description: "Open AK System now"; Flags: nowait postinstall
