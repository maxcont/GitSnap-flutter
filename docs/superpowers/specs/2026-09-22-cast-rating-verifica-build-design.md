# Design: Verifica rating CAST per build (integrazione con "Verifica build")

Data: 2026-09-22

## Contesto

Oltre a sapere in quali ambienti una build è stata rilasciata (tab
"Verifica build"), l'utente vuole verificare — per le build effettivamente
trovate installate — il "Quality Rating" (A/B/C/D/F) assegnato dal sistema
interno CAST (`DevOps Reports`), dato che solo le build con rating **A**
possono essere rilasciate in produzione secondo le policy interne.

Il portale CAST espone, per ogni componente, una pagina HTML (non API
JSON) all'indirizzo:

```
https://<host CAST>/cast/EACS/<Componente>
```

con una tabella storica delle scansioni: colonne `Build`, `Branch`,
`Data`, `Quality Rating`, `Durata`. Esiste anche una pagina di riepilogo
`/cast/EACS` con l'ultimo rating per ogni componente, ma non serve per
questa feature (serve lo storico per trovare la build esatta cercata).

### Vincolo tecnico: autenticazione NTLM

Il server richiede **Windows Integrated Authentication (NTLM)** — non un
form HTML, non Basic Auth (verificato: risponde 401 a Basic Auth), non un
cookie di sessione applicativo (verificato: nessun cookie viene impostato
dal browser dopo il login). L'utente si autentica con `dominio\utente` +
password (es. `ternaren\xt1374`).

Il pacchetto `http` di Flutter/Dart non supporta NTLM nativamente, e
`package:win32` (verificato tramite la documentazione ufficiale) **non
espone le API WinHTTP**, quindi l'approccio FFI diretto richiederebbe
dichiarazioni manuali verso `winhttp.dll` — codice a basso livello che non
è possibile validare in questo ambiente di sviluppo (nessun accesso di
rete all'host intranet).

La soluzione scelta è invece incorporare un **browser reale** nell'app
tramite `package:webview_windows` (basato su Microsoft Edge WebView2):
quando l'app naviga verso l'URL CAST, è WebView2 stesso — lo stesso
motore di Edge che l'utente già usa per accedere a CAST manualmente — a
gestire l'intero handshake NTLM, incluso il popup nativo "Sicurezza di
Windows" per inserire `dominio\utente` e password la prima volta. L'app
poi legge l'HTML della pagina caricata tramite `executeScript()` (che
esegue JavaScript nel contesto della pagina e restituisce il risultato,
es. `document.documentElement.outerHTML`).

Questo elimina completamente la necessità di implementare NTLM a mano
(niente FFI, niente crittografia custom, niente dialog di credenziali
gestito dall'app: se necessario, è Windows/WebView2 a mostrarlo).

Questo introduce una dipendenza platform-specific: la funzionalità CAST è
disponibile **solo su Windows** (l'app è comunque distribuita come
`GitSnap_..._windows_x64`, coerente con l'target attuale), e richiede il
**runtime WebView2** installato sulla macchina (preinstallato di default
su Windows 10/11 aggiornati).

## Obiettivo

Nel tab "Verifica build", aggiungere un pulsante globale "Verifica CAST"
che, per tutte le combinazioni cercate con successo (almeno un ambiente
con build trovata), recupera il Quality Rating CAST della build
esattamente installata e lo mostra accanto all'informazione di ambiente
già presente.

## UI

### Nuovo pulsante e area WebView nascosta

- Accanto al pulsante esistente "Cerca tutto", nuovo pulsante "Verifica
  CAST" (icona `Icons.verified_outlined`), abilitato solo se `_results`
  non è vuoto e se l'host CAST è configurato (vedi sotto).
- La navigazione avviene tramite un `WebviewController`
  (`package:webview_windows`) creato/inizializzato all'avvio del tab, con
  il relativo widget `Webview` **non mostrato nell'albero UI visibile**
  (es. dimensioni 0×0 o in una `Offstage`), dato che serve solo per
  eseguire l'autenticazione e leggere l'HTML, non per mostrare la pagina
  all'utente.
- Se il popup nativo "Sicurezza di Windows" appare (prima navigazione
  della sessione, o credenziali scadute), lo gestisce Windows stesso: non
  serve alcun dialog custom nell'app. Per farlo apparire in primo piano
  serve però che il controllo `Webview` sia effettivamente presente e
  visibile in quel momento nell'albero UI (i popup di autenticazione
  nativi di WebView2 sono ancorati alla finestra del controllo) — per
  questo, al primo utilizzo nella sessione, il widget `Webview` viene
  mostrato temporaneamente in un piccolo riquadro (es. 400×300) dentro un
  `AlertDialog` con testo esplicativo ("Accedi a CAST se richiesto"),
  chiudibile manualmente una volta effettuato il login; alle chiamate
  successive (sessione NTLM già autenticata da Windows) il riquadro non è
  necessario e la richiesta avviene "in background" (`Offstage`).

### Configurazione host CAST

- Nuovo campo in `ConfigPanel`, sezione "Configurazione Azure DevOps"
  (aggiunta una nuova riga sotto), etichetta "CAST Base URL (opzionale)",
  hint "es. https://gswvatfsat19.ternaren.prv:9091". Persistito in
  `AppState`/`StorageService` come gli altri campi di configurazione
  (`base_url`, `organization`, ...).
- Se il campo è vuoto, il pulsante "Verifica CAST" è disabilitato con
  tooltip "Configura l'indirizzo CAST nelle impostazioni".

### Visualizzazione del rating

- Il rating CAST viene mostrato **dentro** la tile ambiente già esistente
  (quella con stato "Installata"), come riga aggiuntiva sotto il nome
  release, visibile solo dopo che l'utente ha premuto "Verifica CAST":
  - Durante il fetch: piccolo spinner inline + testo "CAST: verifica…"
  - Se trovato un rating "A": chip verde "CAST: A"
  - Se trovato un rating diverso da "A" (B/C/D/F o altro valore): chip
    rosso/arancio "CAST: <lettera>"
  - Se la build non è presente nello storico CAST di quel componente (o
    il componente stesso non esiste su CAST — `parseHistoryTable`
    restituisce una lista vuota in entrambi i casi, non essendoci un
    codice di stato HTTP esplicito da distinguere con WebView2): chip
    grigio "CAST: non trovato".
  - Se la richiesta fallisce per altri motivi (errore di rete, timeout,
    pagina inaccessibile): chip rosso "CAST: errore" con tooltip
    contenente il dettaglio (`CastClientError.message`).
- Le tile ambiente con stato "Non trovata" o "Pipeline non trovata" non
  mostrano alcuna informazione CAST (non ha senso: non c'è una build
  installata da verificare).

## Logica applicativa

### Nuovo servizio `CastClient`

Nuovo file `lib/services/cast_client.dart` (import necessari: `dart:async`
per `Completer`/`StreamSubscription`/`TimeoutException`, e
`package:webview_windows/webview_windows.dart` per `WebviewController` e
`LoadingState`), responsabile di orchestrare la navigazione WebView2 e
restituire l'HTML della pagina caricata:

```dart
class CastClientError implements Exception {
  final String message;
  CastClientError(this.message);
}

/// Uses an existing, already-initialized [WebviewController] to load the
/// CAST component history page and return its rendered HTML.
///
/// Authentication (NTLM) is handled transparently by the WebView2 runtime;
/// if a login prompt is required, it appears as a native Windows dialog
/// anchored to the [WebviewController]'s visible surface.
class CastClient {
  final WebviewController controller;
  final String baseUrl; // es. https://gswvatfsat19.ternaren.prv:9091

  CastClient({required this.controller, required this.baseUrl});

  /// Loads `/cast/EACS/<component>` and returns the fully rendered HTML
  /// (after JavaScript execution) via `document.documentElement.outerHTML`.
  Future<String> fetchComponentPage(String component) async {
    final url = '$baseUrl/cast/EACS/$component';
    final completer = Completer<void>();
    late final StreamSubscription<LoadingState> subscription;
    subscription = controller.loadingState.listen((state) {
      if (state == LoadingState.navigationCompleted && !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      await controller.loadUrl(url);
      await completer.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw CastClientError('Timeout durante il caricamento di CAST');
    } finally {
      await subscription.cancel();
    }
    final result = await controller.executeScript(
      'document.documentElement.outerHTML',
    );
    if (result is! String) {
      throw CastClientError('Risposta CAST non valida');
    }
    return result;
  }
}
```

Nota: `executeScript` restituisce un valore già deserializzato da JSON
(vedi implementazione del pacchetto: `jsonDecode(data)`), quindi una
stringa HTML arriva come `String` Dart nativa.

### Normalizzazione nome componente CAST

Verificato con la lista reale dei componenti CAST (es. `AppSorv-BE` →
`AppSorvBE`, `ApiGateway-ZAC` → `ApiGatewayZAC`, `ProgConf-FE-ZAC` →
`ProgConfFEZAC`, `RedCat-BE` → `RedCatBE`): il nome componente CAST si
ottiene rimuovendo tutti i trattini (`-`) e gli spazi dal nome del
repository GitSnap. Il "progetto" CAST è fisso: `EACS` (hardcoded per ora,
come da conferma utente — nessun altro progetto CAST in uso).

```dart
static String castComponentName(String repositoryName) =>
    repositoryName.replaceAll(RegExp(r'[-\s]'), '');
```

### Parsing della tabella storico e ricerca build

Nuovo metodo statico (facilmente testabile senza rete, isolato dalla
parte WebView2):

```dart
class CastBuildRating {
  final String build;
  final String rating; // 'A', 'B', 'C', ...
  CastBuildRating({required this.build, required this.rating});
}

/// Parses the CAST component history HTML table (`table.table-cast`)
/// into a list of (build, rating) rows.
static List<CastBuildRating> parseHistoryTable(String html) { ... }
```

Implementazione: parsing testuale mirato (senza dipendenza da un parser
HTML completo) tramite `RegExp` che estrae le righe `<tr>` della tabella
con classe `table-cast`, e per ciascuna riga cattura il 1° `<td>` (Build)
e il 4° `<td>` (Quality Rating), ignorando tag HTML annidati (es. il link
nella colonna Data). Esempio di regex per riga:

```dart
final rowPattern = RegExp(
  r'<tr>\s*<td[^>]*>([^<]*)</td>\s*<td[^>]*>[^<]*</td>\s*<td[^>]*>.*?</td>\s*<td[^>]*>([^<]*)</td>',
  dotAll: true,
);
```

(la regex esatta viene validata nel Task di implementazione con un test
dedicato che usa come fixture l'HTML reale della tabella CAST fornito
dall'utente, non solo un frammento inventato.)

Poi, dato l'elenco `List<CastBuildRating>` e la build esatta cercata
(`release.artifactVersion`, il valore preciso trovato da
`BuildSearchService`, non il testo digitato dall'utente che può essere
parziale):

```dart
static CastBuildRating? findExactBuild(
  List<CastBuildRating> rows,
  String exactBuildVersion,
) =>
    rows.cast<CastBuildRating?>().firstWhere(
      (r) => r!.build.trim() == exactBuildVersion.trim(),
      orElse: () => null,
    );
```

Match **esatto** (non "contiene"), come da conferma utente, perché qui si
verifica una build specifica già identificata con certezza in un
ambiente, non una ricerca approssimata.

### Orchestrazione nel widget

In `BuildEnvironmentTab`:
1. `initState`: crea un `WebviewController`, chiama
   `await controller.initialize()`.
2. Al click su "Verifica CAST": mostra temporaneamente il riquadro
   `Webview` visibile (per consentire l'eventuale popup di login nativo),
   poi per ogni combo in `_results`, per ogni ambiente con
   `BuildEnvironmentStatus.found`, chiama in **sequenza** (non in
   parallelo: un solo `WebviewController` non può navigare più URL
   contemporaneamente) `CastClient(...).fetchComponentPage(componente)`,
   fa il parsing con `parseHistoryTable`, cerca
   `findExactBuild(rows, result.release!.artifactVersion)`, e aggiorna lo
   stato (`setState`) con il rating trovato per quella combinazione prima
   di passare alla successiva. Al termine, nasconde di nuovo il riquadro
   `Webview` (`Offstage`).
3. Ogni tile ambiente mostra lo stato CAST corrente per quella
   combinazione (in attesa / trovato / errore), aggiornato man mano che
   l'elaborazione sequenziale procede (non serve `FutureBuilder`: è uno
   stato scritto progressivamente in una mappa e letto direttamente nel
   `build()`).
4. `dispose`: `controller.dispose()`.

## File coinvolti

- Nuovo: `lib/services/cast_client.dart` — client WebView2/NTLM + parsing
  storico.
- Nuovo: `lib/models/cast_models.dart` — `CastBuildRating`,
  `CastClientError`.
- Modificato: `lib/widgets/build_environment_tab.dart` — pulsante
  "Verifica CAST", `WebviewController`, riquadro di login temporaneo,
  visualizzazione rating per ambiente.
- Modificato: `lib/providers/app_state.dart` — nuovo campo persistito
  `castBaseUrl` (getter/setter, incluso in `saveConfiguration`/caricamento
  configurazione, seguendo lo stesso pattern di `baseUrl`).
- Modificato: `lib/widgets/config_panel.dart` — nuovo campo testo "CAST
  Base URL (opzionale)".
- Modificato: `pubspec.yaml` — nuova dipendenza `webview_windows`.

## Testing

- Unit test per `castComponentName` (rimozione trattini/spazi) con i nomi
  reali osservati (`AppSorv-BE`, `ApiGateway-ZAC`, `ProgConf-FE-ZAC`,
  `RedCat-BE`, ecc.).
- Unit test per `parseHistoryTable` usando come fixture l'HTML reale
  della tabella CAST fornito dall'utente (troncato all'essenziale),
  verificando che estragga correttamente coppie (build, rating) incluse
  righe con rating diverso da "A".
- Unit test per `findExactBuild` (match esatto, build assente → null).
- Il livello WebView2 (`fetchComponentPage`) **non è testabile in CI**
  (richiede rete verso un host intranet, Windows con WebView2 runtime, e
  login NTLM interattivo) — resta verificato solo manualmente.

## Fuori scope

- Supporto per progetti CAST diversi da `EACS` (hardcoded per ora).
- Gestione custom delle credenziali CAST (l'autenticazione NTLM e
  l'eventuale prompt di login restano interamente delegati a
  Windows/WebView2, l'app non le vede né le gestisce).
- Rating CAST per build cercate ma non trovate in nessun ambiente.
- Supporto macOS/Linux per la funzionalità CAST (resta Windows-only,
  dato il vincolo WebView2/WinHTTP e il pacchetto `webview_windows`).
- Retry automatico o refresh periodico del rating (l'utente rilancia
  manualmente "Verifica CAST" se necessario).
