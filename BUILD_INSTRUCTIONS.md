# Guida al Build di GitSnap Flutter

Questa guida spiega come compilare l'applicazione per ogni piattaforma.

## Preparazione

### 1. Installa Flutter
Scarica Flutter SDK da: https://docs.flutter.dev/get-started/install

Verifica l'installazione:
```bash
flutter doctor
```

### 2. Setup del progetto
```bash
cd gitsnap_flutter
flutter pub get
```

## Build per Windows

### Prerequisiti Windows
- Windows 10 o superiore
- Visual Studio 2022 con "Desktop development with C++"

### Build Windows
```bash
flutter build windows --release
```

### Output
L'eseguibile si trova in:
```
build/windows/runner/Release/gitsnap_flutter.exe
```

### Distribuzione Windows
Per distribuire l'app, copia l'intera cartella `Release` che contiene:
- `gitsnap_flutter.exe`
- DLL necessarie
- Cartella `data` (se presente)

### Creare installer Windows (opzionale)
Usa Inno Setup o NSIS per creare un installer:

**Esempio con Inno Setup:**
```iss
[Setup]
AppName=GitSnap
AppVersion=1.0.0
DefaultDirName={pf}\GitSnap
DefaultGroupName=GitSnap
OutputBaseFilename=GitSnap-Setup
Compression=lzma2
SolidCompression=yes

[Files]
Source: "build\windows\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\GitSnap"; Filename: "{app}\gitsnap_flutter.exe"
Name: "{commondesktop}\GitSnap"; Filename: "{app}\gitsnap_flutter.exe"
```

## Build per macOS

### Prerequisiti macOS
- macOS 10.14 o superiore
- Xcode 13 o superiore
- CocoaPods

### Build macOS
```bash
flutter build macos --release
```

### Output
L'app si trova in:
```
build/macos/Build/Products/Release/gitsnap_flutter.app
```

### Distribuzione macOS
Comprimi l'app in un file ZIP:
```bash
cd build/macos/Build/Products/Release
zip -r GitSnap.zip gitsnap_flutter.app
```

### Code signing (per distribuzione pubblica)
```bash
# Firma l'app
codesign --force --deep --sign "Developer ID Application: Your Name" gitsnap_flutter.app

# Verifica la firma
codesign --verify --verbose gitsnap_flutter.app

# Crea un DMG
hdiutil create -volname "GitSnap" -srcfolder gitsnap_flutter.app -ov -format UDZO GitSnap.dmg
```

## Build per Linux

### Prerequisiti Linux (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

### Prerequisiti Linux (Fedora)
```bash
sudo dnf install clang cmake ninja-build gtk3-devel
```

### Build Linux
```bash
flutter build linux --release
```

### Output
I file si trovano in:
```
build/linux/x64/release/bundle/
```

### Distribuzione Linux
Crea un archivio:
```bash
cd build/linux/x64/release
tar -czf GitSnap-Linux.tar.gz bundle/
```

### Creare AppImage (opzionale)
Usa `appimagetool` per creare un AppImage portable.

### Creare pacchetto .deb (Ubuntu/Debian)
Crea la struttura:
```bash
mkdir -p gitsnap-deb/DEBIAN
mkdir -p gitsnap-deb/usr/bin
mkdir -p gitsnap-deb/usr/share/applications
mkdir -p gitsnap-deb/usr/share/icons/hicolor/256x256/apps

# Copia i file
cp -r build/linux/x64/release/bundle/* gitsnap-deb/usr/bin/
```

Crea `gitsnap-deb/DEBIAN/control`:
```
Package: gitsnap
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Massimo Contursi <email@example.com>
Description: GitSnap - Confronto ambienti Git
 Confronta SOURCE vs TARGET su repository Azure DevOps
```

Build del pacchetto:
```bash
dpkg-deb --build gitsnap-deb
```

## Ottimizzazioni Build

### Ridurre dimensione eseguibile
```bash
flutter build <platform> --release --tree-shake-icons
```

### Split debug info (Linux/macOS)
```bash
flutter build <platform> --release --split-debug-info=debug-symbols/
```

### Obfuscation (per proteggere il codice)
```bash
flutter build <platform> --release --obfuscate --split-debug-info=debug-symbols/
```

## Testing prima del build

### Test su desktop
```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

### Profile mode (per analisi performance)
```bash
flutter run -d <platform> --profile
```

## Risoluzione problemi comuni

### Errore "No toolchain found"
Installa Visual Studio (Windows), Xcode (macOS), o build-essentials (Linux)

### Errore dipendenze mancanti
```bash
flutter pub get
flutter clean
flutter pub get
```

### Build lento
Aggiungi `--no-tree-shake-icons` se il tree-shaking rallenta troppo

### Crash al lancio
Verifica che tutte le DLL/librerie siano presenti nella cartella di output

## CI/CD

### GitHub Actions esempio
```yaml
name: Build

on: [push]

jobs:
  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - run: flutter pub get
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v3
        with:
          name: windows-build
          path: build/windows/runner/Release/
```

## Versionamento

Aggiorna la versione in `pubspec.yaml`:
```yaml
version: 1.0.1+2  # 1.0.1 = versione, 2 = build number
```

## Note finali

- Testa sempre su piattaforma target prima del rilascio
- Mantieni sincronizzate le versioni tra piattaforme
- Considera il code signing per distribuzione pubblica
- Documenta i requisiti di sistema per gli utenti
