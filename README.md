# GitSnap Flutter - Confronto Ambienti Git

Versione Flutter dell'applicazione GitSnap per il confronto di ambienti SOURCE vs TARGET su repository Azure DevOps.

## Caratteristiche

- ✅ **Multi-piattaforma**: Windows, macOS, Linux
- 🔄 **Confronto ambienti**: Confronta branch, tag e commit tra SOURCE e TARGET
- 📊 **Dashboard risultati**: Visualizzazione dettagliata delle differenze
- 💾 **Gestione progetti**: Salva e ricarica configurazioni
- 🎨 **UI moderna**: Interfaccia Material Design 3
- 🌓 **Tema chiaro/scuro**: Adattamento automatico al tema di sistema

## Prerequisiti

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

## Installazione

1. Clona o estrai il progetto:
```bash
cd gitsnap_flutter
```

2. Installa le dipendenze:
```bash
flutter pub get
```

3. (Opzionale) Genera i file di serializzazione JSON:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Esecuzione

### Modalità debug
```bash
flutter run -d windows  # Per Windows
flutter run -d macos    # Per macOS
flutter run -d linux    # Per Linux
```

### Build release

#### Windows
```bash
flutter build windows --release
```
L'eseguibile si troverà in: `build/windows/runner/Release/gitsnap_flutter.exe`

#### macOS
```bash
flutter build macos --release
```
L'app si troverà in: `build/macos/Build/Products/Release/gitsnap_flutter.app`

#### Linux
```bash
flutter build linux --release
```
L'eseguibile si troverà in: `build/linux/x64/release/bundle/`

## Struttura del progetto

```
lib/
├── main.dart                 # Entry point
├── models/
│   ├── azure_models.dart     # Modelli dati
│   └── azure_models.g.dart   # Generazione JSON
├── services/
│   ├── azure_devops_client.dart  # Client API Azure DevOps
│   ├── ref_resolver.dart         # Risoluzione riferimenti
│   ├── diff_service.dart         # Calcolo differenze
│   └── storage_service.dart      # Persistenza dati
├── providers/
│   └── app_state.dart           # Gestione stato
├── screens/
│   └── home_screen.dart         # Schermata principale
└── widgets/
    ├── config_panel.dart        # Configurazione Azure DevOps
    ├── repository_selector.dart # Selezione repository
    ├── ref_config_panel.dart    # Configurazione SOURCE/TARGET
    ├── results_dashboard.dart   # Dashboard risultati
    └── projects_sidebar.dart    # Gestione progetti
```

## Utilizzo

### 1. Configurazione Azure DevOps
- Inserisci Organization e Project (obbligatori)
- Opzionale: Base URL per on-premises
- Inserisci il Personal Access Token (PAT)
- Clicca "Carica repository del progetto"

### 2. Selezione Repository
- Seleziona uno o più repository da confrontare
- Usa "Seleziona tutto" / "Deseleziona tutto" per velocizzare

### 3. Definizione Ambienti
- **SOURCE**: Ambiente di sviluppo (es. `develop`)
- **TARGET**: Ambiente di produzione (es. `master`)
- Scegli tipo: Branch, Tag pattern, o Commit SHA
- Inserisci il valore corrispondente

### 4. Esegui Confronto
- Clicca "Esegui confronto"
- Attendi l'elaborazione
- Visualizza i risultati nella dashboard

### 5. Dashboard Risultati
- **✅ ALLINEATO**: Nessuna differenza
- **⚠️ DIVERGENTE**: Ci sono commit non allineati
- **❌ ERRORE**: Errore durante il confronto
- Espandi ogni repository per vedere dettagli, commit e file modificati

### 6. Gestione Progetti
- Clicca sull'icona cartella in alto
- Aggiungi nuovi progetti per salvare configurazioni
- Carica progetti salvati con un click

## Dati Salvati

I dati vengono salvati in:
- **Windows**: `%APPDATA%/GitSnap/data/`
- **macOS**: `~/Library/Application Support/GitSnap/data/`
- **Linux**: `~/.local/share/GitSnap/data/`

File generati:
- `config.json`: Ultima configurazione usata
- `projects.json`: Lista progetti salvati

⚠️ **Nota**: Il PAT non viene mai salvato nel file `config.json` per motivi di sicurezza.

## Dipendenze principali

- `provider`: Gestione stato
- `http`: Client HTTP
- `json_annotation`: Serializzazione JSON
- `shared_preferences`: Preferenze locali
- `path_provider`: Accesso filesystem
- `uuid`: Generazione ID univoci
- `intl`: Formattazione date

## Differenze con la versione Streamlit

### Vantaggi Flutter
- ✅ App desktop nativa (non richiede browser)
- ✅ Performance migliori
- ✅ Offline-first (dati salvati localmente)
- ✅ Distribuzione standalone (exe/app singolo)
- ✅ UI più reattiva e moderna

### Funzionalità equivalenti
- Configurazione Azure DevOps
- Selezione repository multipli
- Confronto SOURCE vs TARGET
- Dashboard risultati dettagliata
- Gestione progetti

## Sviluppo

### Hot reload
Durante lo sviluppo, usa `flutter run` e premi `r` per hot reload o `R` per hot restart.

### Debug
```bash
flutter run --debug
```

### Generare codice JSON
Quando modifichi i modelli, rigenera il codice:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Troubleshooting

### Errore di connessione
- Verifica Organization, Project e PAT
- Controlla la connessione internet
- Per on-premises, verifica Base URL

### Repository non caricati
- Verifica i permessi del PAT
- Assicurati di avere accesso ai repository

### Build fallita
```bash
flutter clean
flutter pub get
flutter build <platform>
```

## Autore

**Massimo Contursi**

Convertito da Streamlit a Flutter per applicazione desktop nativa.

## Licenza

Stesso della versione Streamlit originale.
