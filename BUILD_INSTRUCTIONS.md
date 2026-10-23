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
build/windows/x64/runner/Release/gitsnap_flutter.exe
```

### Distribuzione Windows
Per distribuire l'app, copia l'intera cartella `Release` che contiene:
- `gitsnap_flutter.exe`
- DLL necessarie
- Cartella `data` (se presente)

### Release portabile

Dopo la build, `.\scripts\create_release.ps1` copia l'intera applicazione e il
manuale in `assets\release\output`. Non incrementa piu' la versione: modificarla
in `pubspec.yaml` **prima** della build. Lo script rifiuta build con versione
diversa e cartelle di destinazione gia' esistenti.

## Aggiornamenti Windows con GitHub Releases

### Architettura

- `auto_updater` integra WinSparkle; l'installer e' creato con Inno Setup.
- Installazione per utente in `%LOCALAPPDATA%\Programs\GitSnap`, senza richiesta
  di amministratore (salvo policy aziendali). Collegamento nel menu Start e
  collegamento desktop opzionale.
- Controllo in background all'avvio, controlli periodici e pulsante
  "Controlla aggiornamenti" nella barra superiore.
- L'utente conferma download/installazione nelle finestre native di WinSparkle.
  Solo la conferma d'installazione richiede la chiusura dell'app. Il setup
  sostituisce i file e riavvia GitSnap.
- Configurazioni e progetti rimangono nella cartella Documenti dell'utente,
  sotto `GitSnap\data`: non vengono rimossi dal setup o dalla disinstallazione.
- Le build normali (`flutter build windows --release`) e debug non avviano
  l'updater. Il packaging firmato passa `GITSNAP_ENABLE_UPDATES=true`,
  `GITSNAP_VERSION` e `GITSNAP_UPDATE_FEED_URL`.

### Configurazione iniziale della firma

Prerequisiti per il packaging locale: Flutter, Visual Studio, Inno Setup 6.3+
e OpenSSL (anche quello incluso in Git for Windows). Consultare le condizioni
di licenza Inno Setup per il proprio uso, incluso quello commerciale.
In GitHub Actions il compiler viene installato se assente.
Lo script include nel pacchetto il runtime Visual C++ x64 redistribuibile
app-local, cercandolo sotto `VC\Redist\MSVC` dell'installazione Visual Studio.
Questo evita di richiedere l'installazione amministrativa del redistributable
nei PC del team. Devono essere rispettate le condizioni Microsoft per la
redistribuzione; non copiare DLL dalla cartella System32.

Creare una coppia DSA con OpenSSL, in una cartella privata **fuori dal repository**.
Eseguire i comandi da PowerShell, controllando che ciascuno termini senza errori.
Se `openssl` non e' nel PATH, usare il percorso dell'eseguibile, ad esempio
`& 'C:\Program Files\Git\usr\bin\openssl.exe'`.

```powershell
$keyDir = Join-Path $env:USERPROFILE '.gitsnap-signing'
New-Item -ItemType Directory -Path $keyDir
openssl dsaparam -out "$keyDir\params.pem" 4096
openssl gendsa -out "$keyDir\dsa_priv.pem" "$keyDir\params.pem"
openssl dsa -in "$keyDir\dsa_priv.pem" -pubout -out "$keyDir\dsa_pub.pem"
```

Non rigenerare le chiavi per ogni release. Conservare un backup sicuro della
chiave privata: perderla o cambiarla impedisce agli utenti esistenti di verificare
gli aggiornamenti. La versione WinSparkle inclusa dal plugin richiede lo schema
DSA/SHA-1 del suo `sign_update.bat`; lo script segue esattamente quello schema e
verifica la firma dopo averla generata. Non sostituirlo con una semplice firma
del file o con una chiave RSA.

Su GitHub, in **Settings > Secrets and variables > Actions**, configurare:

| Tipo | Nome | Contenuto |
|---|---|---|
| Repository variable | `UPDATER_PUBLIC_KEY` | Intero PEM di `dsa_pub.pem` |
| Repository secret | `UPDATER_PRIVATE_KEY` | Intero PEM di `dsa_priv.pem` |

La pipeline incorpora solo la chiave pubblica nella risorsa `DSAPub` dell'app.
La privata viene scritta in un file temporaneo del runner, mai nei pacchetti, e
rimossa anche in caso di errore. Lo script controlla che le chiavi corrispondano.

La firma degli aggiornamenti **non e' Authenticode**: senza un certificato Windows
attendibile, SmartScreen o le policy aziendali possono comunque segnalare o
bloccare l'eseguibile. Non disattivare tali protezioni.

### Pubblicare una versione

La nuova distribuzione parte da `0.1.0+1`, con primo tag `v0.1.0`.
La numerazione delle precedenti copie portabili non viene riutilizzata.

1. Aggiornare `pubspec.yaml`, per esempio da `0.1.0+1` a `0.1.1+2`. Usare versioni
   stabili a tre componenti e incrementare anche BUILD; ogni componente deve
   essere al massimo 65535.
2. Committare le modifiche, integrarle nel branch di distribuzione e creare il
   tag corrispondente, ad esempio `git tag v0.1.1`, quindi `git push origin v0.1.1`.
   Il workflow rifiuta tag che non corrispondono a `pubspec.yaml`.
3. GitHub Actions esegue i test, compila e firma il setup. Carica come artifact:
   installer, `appcast.xml` e `SHA256SUMS.txt`, e crea una release **draft**.
4. Verificare i pacchetti dall'artifact; non considerare una bozza disponibile
   all'updater pubblico. Poi pubblicare la release come stabile e **latest**.
   Una nuova release pubblicata diventa disponibile a tutti i client configurati.

Il feed e' `https://github.com/maxcont/GitSnap-flutter/releases/latest/download/appcast.xml`;
il setup punta a un URL specifico del tag, non a un asset sovrascritto.
La pipeline usa automaticamente il repository di esecuzione, anche nei fork.
Non pubblicare altre release come latest senza includere il feed e il setup.
Le release sono pubbliche e i PC non richiedono PAT o altri token GitHub.

Per generare localmente lo stesso pacchetto, copiare la chiave pubblica nel file
ignorato da Git e passare il percorso della privata:

```powershell
Copy-Item "$keyDir\dsa_pub.pem" .\windows\runner\resources\updater_public_key.pem
.\scripts\build_windows_release.ps1 -PrivateKeyPath "$keyDir\dsa_priv.pem"
```

I file vengono generati in `build\release`. Lo script non pubblica nulla.
Se ISCC o OpenSSL sono in percorsi diversi, usare `-IsccPath` e `-OpenSslPath`.
Se il CRT non viene individuato, passare `-RuntimeDirectory` con il percorso
Visual Studio `VC\Redist\MSVC\<versione>\x64\Microsoft.VC143.CRT` (o quello
corrispondente al toolset usato).
Per un fork, passare anche `-Repository proprietario/repository`.

### Prima distribuzione e verifica

Le vecchie copie portabili non possono aggiornarsi da sole: inviare **una sola
volta** il nuovo setup e aggiornare i collegamenti dei colleghi alla copia
installata. Non eliminare la vecchia cartella finche' non e' verificato il
recupero dei progetti. Il vecchio eseguibile non viene modificato dal setup.

Prima della distribuzione generale provare su un profilo Windows/VM dedicato:

- installazione senza privilegi amministrativi e avvio con configurazioni
  esistenti;
- aggiornamento reale dalla versione A alla B, preferibilmente usando un
  repository di prova prima di pubblicare sul canale del team;
- rinvio/annullamento dell'aggiornamento e controllo manuale;
- rete assente, download interrotto e firma non valida: nessun pacchetto non
  verificato deve essere eseguito, l'app deve rimanere utilizzabile;
- chiusura, installazione, riavvio e conservazione dei progetti;
- disinstallazione senza cancellazione dei dati dell'utente.

Non viene promesso un rollback transazionale automatico: in caso di problemi
conservare i setup precedenti e reinstallare manualmente l'ultima versione
funzionante. Provare anche errori di installazione e file bloccati.

Verifiche automatiche locali:

```powershell
flutter test
.\test\release_scripts_test.ps1
.\test\update_signing_test.ps1
flutter analyze lib\services\update_service.dart lib\widgets\update_button.dart
flutter build windows --release
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
version: 0.1.1+2  # 0.1.1 = versione, 2 = build number
```

## Note finali

- Testa sempre su piattaforma target prima del rilascio
- Mantieni sincronizzate le versioni tra piattaforme
- Considera il code signing per distribuzione pubblica
- Documenta i requisiti di sistema per gli utenti
