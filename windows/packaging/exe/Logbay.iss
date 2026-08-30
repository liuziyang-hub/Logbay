; Logbay Windows installer (Inno Setup 6)
; Packages the Flutter Release build for colleague handoff.
; Falls back to D:\Eagly\App when Release\eagly.exe is missing.

#define MyAppName "Logbay"
#define MyAppVersion "1.2.4"
#define MyAppPublisher "Logbay"
#define MyAppURL "https://github.com/liuziyang-hub/Logbay"
#define MyAppExeName "eagly.exe"

#ifexist "D:\Eagly\src\eagly-main\build\windows\x64\runner\Release\eagly.exe"
  #define MyAppSource "D:\Eagly\src\eagly-main\build\windows\x64\runner\Release\*"
#else
  #define MyAppSource "D:\Eagly\dist\_stage\*"
#endif

[Setup]
AppId={{A7C3E9F1-4B2D-4E8A-9C1F-6D5B8A0E2F33}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf64}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=D:\Eagly\dist
OutputBaseFilename=Logbay-{#MyAppVersion}-windows-setup
SetupIconFile=D:\Eagly\src\eagly-main\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce

[Files]
Source: "{#MyAppSource}"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
