# GitSnap Flutter - Guida Rapida

## 🚀 Avvio veloce

### Per utenti (senza Flutter installato)

**Scarica l'eseguibile pre-compilato** per il tuo sistema operativo e avvialo.

### Per sviluppatori (con Flutter)

1. **Windows**: Doppio click su `run.bat`
2. **macOS/Linux**: Esegui `./run.sh` nel terminale

Oppure manualmente:
```bash
flutter pub get
flutter run
```

## 📖 Guida all'uso in 5 passi

### Passo 1: Configura Azure DevOps
```
Organization: DefaultCollection  (obbligatorio)
Project: EACS                    (obbligatorio)
PAT: ghp_xxxxxxxxxxxxx          (obbligatorio)
Base URL: [vuoto per cloud]     (opzionale)
Username: [per on-premises]     (opzionale)
```

💡 Clicca **"Carica repository del progetto"**

### Passo 2: Seleziona Repository
- ☑️ Spunta i repository da confrontare
- Usa "Seleziona tutto" per velocizzare
- Minimo: 1 repository

### Passo 3: Definisci SOURCE
```
Tipo: Branch
Valore: develop
```

SOURCE = ambiente di sviluppo/staging

### Passo 4: Definisci TARGET
```
Tipo: Branch
Valore: master
```

TARGET = ambiente di produzione/release

### Passo 5: Esegui confronto
💡 Clicca **"Esegui confronto"**

Attendi alcuni secondi...

## 📊 Leggere i risultati

### ✅ ALLINEATO
- SOURCE e TARGET sono identici
- Nessun commit da allineare
- ✔️ Tutto OK!

### ⚠️ DIVERGENTE
- Ci sono commit in SOURCE non presenti in TARGET
- **#Commit diff**: Numero di commit da allineare
- **#File diff**: Numero di file modificati
- 👆 Espandi per vedere dettagli

### ❌ ERRORE
- Problema durante il confronto
- Verifica branch/tag esistano
- Controlla permessi PAT

## 💾 Salvare configurazioni (Progetti)

1. Clicca icona **📁 cartella** in alto
2. Clicca **"Aggiungi progetto"**
3. Compila:
   - Nome: "EACS Produzione"
   - Organization: DefaultCollection
   - Project: EACS
   - (opzionale) PAT: per caricamento veloce
4. Clicca **"Salva progetto"**

### Caricare un progetto salvato
1. Apri pannello progetti (icona cartella)
2. Clicca **🚀 Carica** accanto al progetto
3. ✔️ Configurazione caricata!

## 🎯 Casi d'uso comuni

### Caso 1: Confronto sviluppo → produzione
```
SOURCE: develop (Branch)
TARGET: master (Branch)
```

### Caso 2: Confronto con tag di release
```
SOURCE: develop (Branch)
TARGET: v1.2.* (Tag pattern)
```

### Caso 3: Confronto specifico commit
```
SOURCE: abc123def456 (Commit SHA)
TARGET: master (Branch)
```

### Caso 4: Confronto tra tag
```
SOURCE: v2.0.0 (Tag pattern)
TARGET: v1.9.* (Tag pattern)
```

## 🔧 Risoluzione problemi

### ❌ "Error loading repositories"
**Causa**: Credenziali errate
**Soluzione**: 
- Verifica Organization e Project
- Verifica PAT sia valido e non scaduto
- Per on-premises, verifica Base URL

### ❌ "Branch not found"
**Causa**: Branch inesistente
**Soluzione**: 
- Verifica nome branch (case-sensitive)
- Non serve "refs/heads/" (aggiunto automaticamente)

### ❌ "No tags match pattern"
**Causa**: Pattern tag non trova corrispondenze
**Soluzione**: 
- Usa `*` come wildcard (es: `prod*`, `v1.*`)
- Verifica esistano tag nel repository

### ⚠️ Risultati parziali
**Causa**: Alcuni repository hanno errori
**Soluzione**: 
- Espandi i repository con ❌
- Leggi il messaggio di errore specifico
- Verifica permessi sul repository

## 💡 Suggerimenti

### Performance
- Seleziona solo repository necessari
- Usa tag pattern quando possibile
- Salva progetti per riutilizzo veloce

### Sicurezza
- Il PAT NON viene salvato in `config.json`
- Salva PAT nei progetti solo se necessario
- Usa PAT con permessi minimi richiesti

### Organizzazione
- Crea progetti separati per ambienti diversi
- Usa nomi descrittivi: "EACS Prod", "EACS Dev"
- Salva configurazione dopo ogni confronto riuscito

## 📂 Dove sono salvati i dati?

- **Windows**: `C:\Users\[Username]\AppData\Roaming\GitSnap\data\`
- **macOS**: `~/Library/Application Support/GitSnap/data/`
- **Linux**: `~/.local/share/GitSnap/data/`

File:
- `config.json`: Ultima configurazione
- `projects.json`: Progetti salvati

## 🆘 Supporto

In caso di problemi:
1. Verifica prerequisiti (Organization, Project, PAT)
2. Controlla connessione internet
3. Verifica log errori nell'applicazione
4. Consulta README.md per dettagli tecnici

## ⚡ Scorciatoie

- **Ctrl/Cmd + S**: Salva configurazione
- Doppio click su progetto: Carica progetto
- Click destro su repository: Info dettagliate (se implementato)

## 📝 Note

- I confronti sono **read-only**: nessuna modifica ai repository
- I dati sono salvati **localmente**: nessun server esterno
- L'applicazione usa **API REST Azure DevOps**: nessun clone repository

---

**GitSnap** · by Massimo Contursi
