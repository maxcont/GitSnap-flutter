# Design: Tab "Verifica build" (build → ambienti di rilascio)

Data: 2026-09-22

## Contesto

Ogni repository/componente ha 4 release definition distinte in Azure DevOps,
una per cartella ambiente: `\Sviluppo`, `\Collaudo`, `\Pre-Esercizio`,
`\Esercizio`. Ogni release ha un artifact con un numero di build/versione
(es. `2.0.26261.02`, visibile nella colonna "Versioni" della UI Release di
Azure DevOps).

L'utente vuole sapere, dato un repository e un numero di build, in quali
ambienti quella build è stata rilasciata con successo — e vuole poterlo
verificare per più combinazioni repo+build contemporaneamente, in un'unica
schermata.

## Obiettivo

Aggiungere un quarto tab "Verifica build" all'app, accanto a "Confronto
repository", "Utility pipeline" e "Pull request".

## UI

### Form di ricerca (combinazioni multiple)

- Lista di righe "combinazione da verificare", ciascuna con:
  - Dropdown repository (stessa fonte dati di `RepositorySelector`,
    `appState.repositories`).
  - Campo testo libero "Numero build/versione" (es. `2.0.26261.02`).
  - Icona cestino per rimuovere la riga (disabilitata se è l'unica riga).
- Bottone "+ Aggiungi combinazione" che aggiunge una nuova riga vuota in
  fondo alla lista.
- Filtro data opzionale "Da" / "A" (stesso componente/stile già usato in
  `pull_requests_tab.dart`), applicato a tutte le righe della ricerca
  corrente. Se non impostato, si usa il default "ultimi 50 rilasci per
  ambiente" (nessun filtro data, solo `$top`).
- Bottone "Cerca tutto": lancia la ricerca per ogni riga con repository e
  build valorizzati (le righe vuote/incomplete vengono ignorate).
- Nessuna persistenza: alla riapertura dell'app/tab si riparte sempre da
  una singola riga vuota. Le righe restano modificabili anche dopo aver
  premuto "Cerca tutto", per permettere di correggere e rilanciare.

### Area risultati

Una card per ciascuna combinazione cercata, con intestazione
`"<nome repo> · <build cercata>"`, contenente 4 sotto-card (una per
ambiente, ordine fisso: Sviluppo, Collaudo, Pre-Esercizio, Esercizio):

- ✅ verde **Installata**: nome release (es. `Release-160`), data di
  creazione/deploy, versione artifact esatta trovata. Mostrata quando
  esiste almeno una release il cui artifact version **contiene**
  (case-insensitive) il testo cercato e che ha almeno un ambiente con
  stato `succeeded`. Se più release corrispondono, si mostra la più
  recente.
- ⚪ grigio **Non trovata**: nessuna release nel range/quantità cercata
  soddisfa il criterio.
- ⚠️ giallo **Pipeline non trovata**: non esiste una release definition
  riconducibile a quel repository in quella cartella ambiente (naming
  mismatch o pipeline non creata in quell'ambiente).

Stato di caricamento per-combinazione (spinner sulla card mentre le 4
richieste ambiente sono in corso) dato che le ricerche partono in
parallelo.

## Logica applicativa

### Match release definition ↔ repository

Per ciascuna delle 4 cartelle, riuso di
`AzureDevOpsClient.getReleaseDefinitions(path: folder)` (già esistente),
poi filtro le definition il cui `name` contiene (case-insensitive) il
`repo.name` selezionato — stesso approccio già usato per il pattern match
in `pipeline_variables_tab.dart` (`_matchesNamePattern`, semplificato al
solo `contains`). Se più di una definition matcha in una cartella, si
sceglie quella con il nome più corto (match più stretto) e si prosegue;
non è un caso bloccante.

### Recupero release e verifica build

Nuovo metodo in `AzureDevOpsClient`:

```dart
Future<List<ReleaseSummary>> getReleases(
  int definitionId, {
  DateTime? minCreatedTime,
  DateTime? maxCreatedTime,
  int top = 50,
})
```

Chiama:
```
GET {_releaseBase}/releases
    ?definitionId={id}
    &$expand=artifacts,environments
    &queryOrder=descending
    &$top={top}
    [&minCreatedTime=...&maxCreatedTime=...]
    &api-version=7.1
```

Per ogni release nella risposta, estrae:
- `id`, `name` (es. `Release-160`)
- `createdOn`
- versione artifact: `artifacts[0].definitionReference['version']['name']`
  (fallback stringa vuota se assente)
- stato complessivo: `succeeded` se **almeno un** elemento in
  `environments[]` ha `status == 'succeeded'`, altrimenti l'esito peggiore
  disponibile (non mostrato in UI, ma utile per eventuale debug futuro).

Nuovo modello in `release_models.dart`:

```dart
class ReleaseSummary {
  final int id;
  final String name;
  final DateTime? createdOn;
  final String artifactVersion;
  final bool succeeded;
}
```

### Algoritmo di verifica per una combinazione (repo, build)

Per ciascuno dei 4 ambienti, in parallelo:
1. Trova la release definition del repo in quell'ambiente (o `null` →
   esito ⚠️ "Pipeline non trovata").
2. Chiama `getReleases(definitionId, minCreatedTime:, maxCreatedTime:, top: 50)`.
3. Filtra le release il cui `artifactVersion` contiene (case-insensitive)
   il testo build cercato **e** `succeeded == true`.
4. Se il set filtrato non è vuoto → ✅ con la più recente (per
   `createdOn`); altrimenti ⚪ "Non trovata".

## File coinvolti

- Nuovo: `lib/widgets/build_environment_tab.dart` — UI form multi-riga +
  area risultati.
- Nuovo modello: `ReleaseSummary` in `lib/models/release_models.dart`.
- Modificato: `lib/services/azure_devops_client.dart` — nuovo metodo
  `getReleases`.
- Modificato: `lib/screens/home_screen.dart` — `DefaultTabController`
  `length: 4`, nuova voce in `TabBar`/`TabBarView`.

## Testing

- Unit test per il parsing di `ReleaseSummary` da JSON di esempio
  (`artifacts`/`environments` con vari stati).
- Unit test per la logica di match "contiene" case-insensitive sul
  numero di build.
- Unit test per la selezione della release definition più stretta quando
  più di una matcha nello stesso ambiente.

## Fuori scope

- Persistenza delle combinazioni ricercate tra riavvii dell'app.
- Gestione di ambienti extra oltre alle 4 cartelle standard (nomi
  cartella hardcoded come nel tab "Utility pipeline").
- Ricerca automatica di release definition quando il nome repository non
  ha alcuna corrispondenza testuale nella pipeline (in quel caso resta
  ⚠️ "Pipeline non trovata", nessun fallback euristico ulteriore).
