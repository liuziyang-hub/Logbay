; Logbay Windows installer (Inno Setup 6)
; Prefer the staged full payload (exe + data + dlls). Release/ alone often
; only contains eagly.exe after a partial Flutter output layout.
;
; Upgrade / overwrite: same AppId + UsePrevious* so reinstall replaces the
; previous copy in place. Before creating the desktop icon, all leftover
; Logbay shortcuts on Public + every Users\*\Desktop are deleted so upgrades
; never leave two icons.

#define MyAppName "Logbay"
#define MyAppVersion "1.5.7"
#define MyAppPublisher "Logbay"
#define MyAppURL "https://github.com/liuziyang-hub/Logbay"
#define MyAppExeName "eagly.exe"
#define MyAppSource "D:\Eagly\dist\_stage\*"

[Setup]
AppId={{A7C3E9F1-4B2D-4E8A-9C1F-6D5B8A0E2F33}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf64}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
DisableDirPage=auto
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
UsePreviousSetupType=yes
UsePreviousLanguage=yes
CloseApplications=force
CloseApplicationsFilter=eagly.exe,lzy.exe,Logbay.exe
RestartApplications=no
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
UninstallDisplayName={#MyAppName}
VersionInfoVersion={#MyAppVersion}.0
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式："; Flags: checkedonce

[Files]
Source: "{#MyAppSource}"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs restartreplace uninsrestartdelete

[InstallDelete]
Type: files; Name: "{commondesktop}\{#MyAppName}.lnk"
Type: files; Name: "{commondesktop}\eagly.lnk"
Type: files; Name: "{commondesktop}\刘子阳.lnk"
Type: files; Name: "{group}\{#MyAppName}.lnk"
Type: files; Name: "{group}\eagly.lnk"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
; Only the Public/common desktop — never {userdesktop}/{autodesktop}, which
; previously created a second icon alongside an older per-user shortcut.
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]
procedure DeleteShortcutIfExists(const FilePath: string);
begin
  if FileExists(FilePath) then
    DeleteFile(FilePath);
end;

procedure RemoveNamedDesktopShortcuts(const DesktopDir: string);
begin
  if DesktopDir = '' then
    Exit;
  DeleteShortcutIfExists(AddBackslash(DesktopDir) + '{#MyAppName}.lnk');
  DeleteShortcutIfExists(AddBackslash(DesktopDir) + 'eagly.lnk');
  DeleteShortcutIfExists(AddBackslash(DesktopDir) + '刘子阳.lnk');
  DeleteShortcutIfExists(AddBackslash(DesktopDir) + 'Eagly.lnk');
end;

{ Wipe Logbay shortcuts from Public desktop and every Users\*\Desktop so
  older per-user icons cannot sit next to the new common-desktop icon. }
procedure RemoveAllLogbayDesktopShortcuts;
var
  FindRec: TFindRec;
  UsersDir, ProfileName, DesktopDir: string;
begin
  RemoveNamedDesktopShortcuts(ExpandConstant('{commondesktop}'));
  RemoveNamedDesktopShortcuts(ExpandConstant('{userdesktop}'));

  UsersDir := AddBackslash(ExtractFileDrive(ExpandConstant('{win}'))) + 'Users';
  if not DirExists(UsersDir) then
    Exit;

  if FindFirst(AddBackslash(UsersDir) + '*', FindRec) then
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      begin
        ProfileName := FindRec.Name;
        if (ProfileName <> '.') and (ProfileName <> '..') and
           (CompareText(ProfileName, 'Public') <> 0) and
           (CompareText(ProfileName, 'Default') <> 0) and
           (CompareText(ProfileName, 'Default User') <> 0) and
           (CompareText(ProfileName, 'All Users') <> 0) then
        begin
          DesktopDir := AddBackslash(UsersDir) + ProfileName + '\Desktop';
          RemoveNamedDesktopShortcuts(DesktopDir);
          { OneDrive redirected desktops }
          DesktopDir := AddBackslash(UsersDir) + ProfileName + '\OneDrive\Desktop';
          RemoveNamedDesktopShortcuts(DesktopDir);
        end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

procedure RemovePerUserLogbayDesktopShortcuts;
var
  FindRec: TFindRec;
  UsersDir, ProfileName, DesktopDir: string;
begin
  RemoveNamedDesktopShortcuts(ExpandConstant('{userdesktop}'));

  UsersDir := AddBackslash(ExtractFileDrive(ExpandConstant('{win}'))) + 'Users';
  if not DirExists(UsersDir) then
    Exit;

  if FindFirst(AddBackslash(UsersDir) + '*', FindRec) then
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      begin
        ProfileName := FindRec.Name;
        if (ProfileName <> '.') and (ProfileName <> '..') and
           (CompareText(ProfileName, 'Public') <> 0) and
           (CompareText(ProfileName, 'Default') <> 0) and
           (CompareText(ProfileName, 'Default User') <> 0) and
           (CompareText(ProfileName, 'All Users') <> 0) then
        begin
          DesktopDir := AddBackslash(UsersDir) + ProfileName + '\Desktop';
          RemoveNamedDesktopShortcuts(DesktopDir);
          DesktopDir := AddBackslash(UsersDir) + ProfileName + '\OneDrive\Desktop';
          RemoveNamedDesktopShortcuts(DesktopDir);
        end;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
    { Before Icons: wipe Public + every user desktop. }
    RemoveAllLogbayDesktopShortcuts
  else if CurStep = ssPostInstall then
    { After Icons: keep the new Public shortcut, drop any per-user leftovers. }
    RemovePerUserLogbayDesktopShortcuts;
end;

function InitializeUninstall(): Boolean;
begin
  RemoveAllLogbayDesktopShortcuts;
  Result := True;
end;
