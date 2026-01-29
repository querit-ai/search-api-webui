; Inno Setup Script for Search API WebUI
; This script creates a professional Windows installer

#define MyAppName "Search API WebUI"
#define MyAppPublisher "QUERIT PRIVATE LIMITED"
#define MyAppPublisherURL "https://querit.ai"
#define MyAppURL "https://github.com/querit-ai/search-api-webui"
#define MyAppExeName "SearchAPIWebUI.exe"

; Version and architecture will be passed as command-line parameters
#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif

#ifndef MyAppArch
  #define MyAppArch "x64"
#endif

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{8C9F4E2D-1A3B-4F6E-9D8C-7E5F2A1B3C4D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=LICENSE
OutputDir=dist
OutputBaseFilename=SearchAPIWebUI-{#MyAppVersion}-Windows-{#MyAppArch}-Setup
SetupIconFile=frontend\public\AppIcon.ico
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}

; Architecture settings
#if MyAppArch == "x64"
  ArchitecturesAllowed=x64
  ArchitecturesInstallIn64BitMode=x64
#elif MyAppArch == "x86"
  ArchitecturesAllowed=x86
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 6.1; Check: not IsAdminInstallMode

[Files]
; Main application files
Source: "dist\SearchAPIWebUI\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
; Start Menu shortcuts
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Comment: "Launch Search API WebUI"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Desktop shortcut
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Comment: "Launch Search API WebUI"
; Quick Launch shortcut
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Launch app after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Custom installation code

// Check if .NET Framework is installed (required for pywebview on Windows)
function IsDotNetInstalled(): Boolean;
var
  success: Boolean;
  release: Cardinal;
begin
  success := RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', release);
  Result := success and (release >= 378389); // .NET 4.5 or higher
end;

function InitializeSetup(): Boolean;
begin
  Result := True;

  // Check for .NET Framework
  if not IsDotNetInstalled() then
  begin
    MsgBox('This application requires .NET Framework 4.5 or later.' + #13#10 +
           'Please install .NET Framework and try again.' + #13#10#13#10 +
           'You can download it from:' + #13#10 +
           'https://dotnet.microsoft.com/download/dotnet-framework',
           mbError, MB_OK);
    Result := False;
  end;
end;

// Cleanup function to remove old files if upgrading
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    if DirExists(ExpandConstant('{app}')) then
    begin
      DelTree(ExpandConstant('{app}\*'), True, True, True);
    end;
  end;
end;
