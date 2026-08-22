; Inno Setup script for the UrActor Windows installer.
;
; Built by .github/workflows/release-desktop.yml, which passes the version in:
;
;     ISCC.exe /DAppVersion=3.16.0 windows\installer\uractor.iss
;
; Inno Setup rather than MSIX. MSIX would give auto-update through App
; Installer, but it cannot be sideloaded at all without a code signing
; certificate -- so until this is signed, MSIX would be undeliverable rather
; than merely warned about. Moving to MSIX later is a change to this file and
; the workflow, not to the app.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "UrActor"
#define AppPublisher "UrActor"
#define AppURL "https://uractor.com"
; Matches BINARY_NAME in windows/CMakeLists.txt.
#define AppExeName "uractor.exe"
; Stable across versions on purpose: it is how Windows recognises an install
; as an upgrade of what is already there rather than a second copy.
#define AppId "{{8F3B2A91-6D4E-4C7A-9E15-3B7D2C8A4F60}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Per-user by default, so the installer does not need administrator rights.
; Asking for elevation on an unsigned installer produces a second, scarier
; prompt stacked on top of the SmartScreen one.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\..\build\windows\installer
OutputBaseFilename=UrActor-{#AppVersion}-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; The whole Flutter release directory: the exe, flutter_windows.dll, the
; plugin DLLs and the data folder. Missing any one of them produces an app
; that launches to a blank window.
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
