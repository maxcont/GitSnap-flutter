#ifndef AppVersion
  #error AppVersion is required
#endif
#ifndef WindowsVersion
  #error WindowsVersion is required
#endif
#ifndef BuildSource
  #error BuildSource is required
#endif
#ifndef OutputDirectory
  #error OutputDirectory is required
#endif

[Setup]
AppId={{AC18D517-564E-47A0-B426-4D7EAB1F86F1}
AppName=GitSnap
AppVersion={#AppVersion}
AppPublisher=GitSnap
AppPublisherURL=https://github.com/maxcont/GitSnap-flutter
VersionInfoVersion={#WindowsVersion}
DefaultDirName={localappdata}\Programs\GitSnap
DefaultGroupName=GitSnap
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDirectory}
OutputBaseFilename=GitSnap-{#AppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
DisableProgramGroupPage=yes
CloseApplications=yes
CloseApplicationsFilter=gitsnap_flutter.exe
RestartApplications=no
SetupLogging=yes
UninstallDisplayIcon={app}\gitsnap_flutter.exe

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\assets\release\Manuale Utente GitSnap.pdf"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\GitSnap"; Filename: "{app}\gitsnap_flutter.exe"
Name: "{autodesktop}\GitSnap"; Filename: "{app}\gitsnap_flutter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\gitsnap_flutter.exe"; Description: "{cm:LaunchProgram,GitSnap}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\gitsnap_flutter.exe"; Flags: nowait; Check: WizardSilent
