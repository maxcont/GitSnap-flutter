# CAST Quality Rating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nel tab "Verifica build", aggiungere un pulsante "Verifica CAST" che recupera e mostra il Quality Rating (A/B/C/D/F) assegnato dal sistema interno CAST per ogni build trovata installata in un ambiente.

**Architecture:** Un `WebviewController` (Microsoft Edge WebView2, via `package:webview_windows`) naviga verso la pagina storico CAST del componente; WebView2 gestisce da solo l'autenticazione NTLM (incluso l'eventuale popup nativo di login di Windows). L'HTML caricato viene letto con `executeScript('document.documentElement.outerHTML')` e parsato con `RegExp` per estrarre le coppie (build, rating), isolate in un servizio puro e testabile (`CastClient.parseHistoryTable`/`findExactBuild`) separato dalla parte di navigazione WebView2 (non testabile in CI).

**Tech Stack:** Flutter/Dart, `package:webview_windows` (Windows-only, richiede WebView2 runtime), `flutter_test` per gli unit test della logica pura.

---

## Task 1: Aggiungere la dipendenza `webview_windows`

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Aggiungere la dipendenza**

In `pubspec.yaml`, aggiungi sotto la sezione `dependencies` (dopo `url_launcher: ^6.2.0`):

```yaml
  url_launcher: ^6.2.0
  webview_windows: ^0.4.0
```

- [ ] **Step 2: Installare i pacchetti**

Run: `flutter pub get`
Expected: `Got dependencies!` senza errori, `pubspec.lock` aggiornato con `webview_windows`.

- [ ] **Step 3: Verificare che il progetto compili ancora**

Run: `flutter analyze`
Expected: nessun nuovo errore rispetto alla baseline (solo gli stessi warning/info pre-esistenti già noti: `withOpacity`, `DropdownButtonFormField.value`, ecc.).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add webview_windows dependency for CAST integration

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 2: Modelli CAST (`CastBuildRating`, `CastClientError`)

**Files:**
- Create: `lib/models/cast_models.dart`

- [ ] **Step 1: Creare i modelli**

Crea `lib/models/cast_models.dart`:

```dart
/// A single row from the CAST component history table: a build/version
/// number and its assigned Quality Rating (A/B/C/D/F).
class CastBuildRating {
  final String build;
  final String rating;

  CastBuildRating({required this.build, required this.rating});
}

/// Raised when the CAST page cannot be loaded or read (network error,
/// timeout, or an unexpected page response).
class CastClientError implements Exception {
  final String message;
  CastClientError(this.message);

  @override
  String toString() => 'CastClientError: $message';
}
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/models/cast_models.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/models/cast_models.dart
git commit -m "feat: add CAST models

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 3: Logica pura `CastClient` — normalizzazione componente, parsing storico, ricerca build

**Files:**
- Create: `lib/services/cast_client.dart` (solo la parte statica/pura in questo task; la parte WebView2 arriva nel Task 4)
- Test: `test/cast_client_test.dart`

- [ ] **Step 1: Scrivere i test per `castComponentName`, `parseHistoryTable`, `findExactBuild`**

Crea `test/cast_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/models/cast_models.dart';
import 'package:gitsnap_flutter/services/cast_client.dart';

const _sampleHistoryHtml = '''
<table class="table table-condensed table-cast">
    <thead>
        <tr>
            <th scope="col" width="15%">Build</th>
            <th>Branch</th>
            <th scope="col" width="15%">Data</th>
            <th scope="col" width="15%">Quality Rating</th>
            <th scope="col" width="15%">Durata</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td class="text-center">2.0.25048.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2025/2/17">17/02/2025</a></td>
            <td class="text-center">A</td>
            <td class="text-center">--:--:--</td>
        </tr>
        <tr>
            <td class="text-center">2.0.24345.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2024/12/10">10/12/2024</a></td>
            <td class="text-center">F</td>
            <td class="text-center">--:--:--</td>
        </tr>
        <tr>
            <td class="text-center">2.0.24344.01</td>
            <td>master</td>
            <td class="text-center"><a title="Vai al dettaglio" class="btn-show-loading" href="/cast/scans/2024/12/9">09/12/2024</a></td>
            <td class="text-center">C</td>
            <td class="text-center">--:--:--</td>
        </tr>
    </tbody>
</table>
''';

void main() {
  group('castComponentName', () {
    test('removes hyphens', () {
      expect(CastClient.castComponentName('AppSorv-BE'), 'AppSorvBE');
    });

    test('removes multiple hyphens', () {
      expect(CastClient.castComponentName('ProgConf-FE-ZAC'), 'ProgConfFEZAC');
    });

    test('removes spaces', () {
      expect(CastClient.castComponentName('Api Gateway'), 'ApiGateway');
    });

    test('leaves already-clean names untouched', () {
      expect(CastClient.castComponentName('GISUtilBackend'), 'GISUtilBackend');
    });
  });

  group('parseHistoryTable', () {
    test('extracts build and rating pairs from the CAST history table', () {
      final rows = CastClient.parseHistoryTable(_sampleHistoryHtml);

      expect(rows, hasLength(3));
      expect(rows[0].build, '2.0.25048.01');
      expect(rows[0].rating, 'A');
      expect(rows[1].build, '2.0.24345.01');
      expect(rows[1].rating, 'F');
      expect(rows[2].build, '2.0.24344.01');
      expect(rows[2].rating, 'C');
    });

    test('returns an empty list when there is no history table', () {
      final rows = CastClient.parseHistoryTable('<html><body>Not found</body></html>');
      expect(rows, isEmpty);
    });
  });

  group('findExactBuild', () {
    final rows = [
      CastBuildRating(build: '2.0.25048.01', rating: 'A'),
      CastBuildRating(build: '2.0.24345.01', rating: 'F'),
    ];

    test('finds the row with an exact build match', () {
      final match = CastClient.findExactBuild(rows, '2.0.24345.01');
      expect(match?.rating, 'F');
    });

    test('trims whitespace before comparing', () {
      final match = CastClient.findExactBuild(rows, '  2.0.25048.01  ');
      expect(match?.rating, 'A');
    });

    test('returns null when the build is not present', () {
      final match = CastClient.findExactBuild(rows, '9.9.99999.99');
      expect(match, isNull);
    });
  });
}
```

- [ ] **Step 2: Eseguire il test e verificare che fallisca**

Run: `flutter test test/cast_client_test.dart`
Expected: FAIL — `lib/services/cast_client.dart` non esiste ancora.

- [ ] **Step 3: Implementare `CastClient` (parte pura)**

Crea `lib/services/cast_client.dart`:

```dart
import '../models/cast_models.dart';

/// Fetches and parses the CAST ("DevOps Reports") component quality
/// history for a repository, to check the Quality Rating of a specific
/// build.
///
/// Authentication against the CAST portal uses Windows Integrated Auth
/// (NTLM), which this class does not implement directly: navigation and
/// authentication are delegated to a WebView2-backed `WebviewController`
/// supplied by the caller (see `fetchComponentPage`). The parsing/matching
/// logic below has no network dependency and is unit-tested directly.
class CastClient {
  /// Derives the CAST component name from a GitSnap repository name by
  /// stripping hyphens and spaces (e.g. "AppSorv-BE" -> "AppSorvBE",
  /// "ProgConf-FE-ZAC" -> "ProgConfFEZAC").
  static String castComponentName(String repositoryName) =>
      repositoryName.replaceAll(RegExp(r'[-\s]'), '');

  /// Parses the CAST component history HTML table
  /// (`table.table-cast`/`table-condensed`) into a list of
  /// (build, rating) rows, in the order they appear in the page (most
  /// recent scan first, matching the CAST portal's own ordering).
  static List<CastBuildRating> parseHistoryTable(String html) {
    final rowPattern = RegExp(
      r'<tr>\s*<td[^>]*>([^<]*)</td>\s*<td[^>]*>[^<]*</td>\s*<td[^>]*>.*?</td>\s*<td[^>]*>([^<]*)</td>',
      dotAll: true,
    );
    return rowPattern.allMatches(html).map((m) {
      return CastBuildRating(
        build: m.group(1)!.trim(),
        rating: m.group(2)!.trim(),
      );
    }).toList();
  }

  /// Finds the row in [rows] whose build matches [exactBuildVersion]
  /// exactly (after trimming whitespace), or null if not present.
  static CastBuildRating? findExactBuild(
    List<CastBuildRating> rows,
    String exactBuildVersion,
  ) {
    final needle = exactBuildVersion.trim();
    for (final row in rows) {
      if (row.build == needle) return row;
    }
    return null;
  }
}
```

- [ ] **Step 4: Eseguire il test e verificare che passi**

Run: `flutter test test/cast_client_test.dart`
Expected: PASS (10 test).

- [ ] **Step 5: Commit**

```bash
git add lib/services/cast_client.dart test/cast_client_test.dart
git commit -m "feat: add CAST component name normalization and history parsing

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 4: `CastClient.fetchComponentPage` (navigazione WebView2)

**Files:**
- Modify: `lib/services/cast_client.dart`

- [ ] **Step 1: Aggiungere `fetchComponentPage` a `CastClient`**

Trasforma i metodi statici di `CastClient` in un mix di metodi statici
(già presenti) e istanza (nuovo), aggiungendo un costruttore e il metodo
`fetchComponentPage`. Sostituisci il contenuto di
`lib/services/cast_client.dart` con:

```dart
import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import '../models/cast_models.dart';

/// Fetches and parses the CAST ("DevOps Reports") component quality
/// history for a repository, to check the Quality Rating of a specific
/// build.
///
/// Authentication against the CAST portal uses Windows Integrated Auth
/// (NTLM). Rather than implementing NTLM by hand, this class delegates
/// navigation and authentication to an already-initialized WebView2
/// [WebviewController] (Microsoft Edge WebView2 handles the NTLM
/// handshake itself, showing a native Windows login prompt if needed,
/// the same way it would in a regular Edge browser tab).
class CastClient {
  final WebviewController controller;
  final String baseUrl;

  CastClient({required this.controller, required this.baseUrl});

  /// Loads `<baseUrl>/cast/EACS/<component>` in the WebView and returns
  /// the fully rendered HTML (after any client-side JavaScript has run)
  /// via `document.documentElement.outerHTML`.
  Future<String> fetchComponentPage(String component) async {
    final url = '${_trimTrailingSlash(baseUrl)}/cast/EACS/$component';
    final completer = Completer<void>();
    late final StreamSubscription<LoadingState> subscription;
    subscription = controller.loadingState.listen((state) {
      if (state == LoadingState.navigationCompleted &&
          !completer.isCompleted) {
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

    final result =
        await controller.executeScript('document.documentElement.outerHTML');
    if (result is! String) {
      throw CastClientError('Risposta CAST non valida');
    }
    return result;
  }

  static String _trimTrailingSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// Derives the CAST component name from a GitSnap repository name by
  /// stripping hyphens and spaces (e.g. "AppSorv-BE" -> "AppSorvBE",
  /// "ProgConf-FE-ZAC" -> "ProgConfFEZAC").
  static String castComponentName(String repositoryName) =>
      repositoryName.replaceAll(RegExp(r'[-\s]'), '');

  /// Parses the CAST component history HTML table
  /// (`table.table-cast`/`table-condensed`) into a list of
  /// (build, rating) rows, in the order they appear in the page (most
  /// recent scan first, matching the CAST portal's own ordering).
  static List<CastBuildRating> parseHistoryTable(String html) {
    final rowPattern = RegExp(
      r'<tr>\s*<td[^>]*>([^<]*)</td>\s*<td[^>]*>[^<]*</td>\s*<td[^>]*>.*?</td>\s*<td[^>]*>([^<]*)</td>',
      dotAll: true,
    );
    return rowPattern.allMatches(html).map((m) {
      return CastBuildRating(
        build: m.group(1)!.trim(),
        rating: m.group(2)!.trim(),
      );
    }).toList();
  }

  /// Finds the row in [rows] whose build matches [exactBuildVersion]
  /// exactly (after trimming whitespace), or null if not present.
  static CastBuildRating? findExactBuild(
    List<CastBuildRating> rows,
    String exactBuildVersion,
  ) {
    final needle = exactBuildVersion.trim();
    for (final row in rows) {
      if (row.build == needle) return row;
    }
    return null;
  }
}
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/services/cast_client.dart`
Expected: `No issues found!` (o solo eventuali info pre-esistenti non
correlate; nessun errore).

- [ ] **Step 3: Rieseguire i test esistenti del Task 3 per assicurarsi che il refactor non abbia rotto nulla**

Run: `flutter test test/cast_client_test.dart`
Expected: PASS (10 test) — `fetchComponentPage` non è testato qui (richiede
un `WebviewController` reale, verificato manualmente nel Task 7).

- [ ] **Step 4: Commit**

```bash
git add lib/services/cast_client.dart
git commit -m "feat: add WebView2-based CAST page fetching

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 5: Campo di configurazione "CAST Base URL" in `AppState` e `ConfigPanel`

**Files:**
- Modify: `lib/providers/app_state.dart`
- Modify: `lib/widgets/config_panel.dart`

- [ ] **Step 1: Aggiungere il campo `_castBaseUrl` ad `AppState`**

In `lib/providers/app_state.dart`, trova il campo `_baseUrl` (riga 15) e
aggiungi subito dopo:

```dart
  String _baseUrl = '';
  String _castBaseUrl = '';
```

- [ ] **Step 2: Aggiungere getter e setter**

Trova il getter `baseUrl` (riga 53) e aggiungi subito dopo:

```dart
  String get baseUrl => _baseUrl;
  String get castBaseUrl => _castBaseUrl;
```

Trova il setter `setBaseUrl` (riga 126) e aggiungi subito dopo:

```dart
  void setBaseUrl(String value) {
    _baseUrl = value;
    notifyListeners();
  }

  void setCastBaseUrl(String value) {
    _castBaseUrl = value;
    notifyListeners();
  }
```

- [ ] **Step 3: Includere il campo nel caricamento della configurazione**

In `_loadInitialData`, trova:

```dart
      _baseUrl = config['base_url'] ?? '';
      _organization = config['organization'] ?? '';
```

Sostituisci con:

```dart
      _baseUrl = config['base_url'] ?? '';
      _castBaseUrl = config['cast_base_url'] ?? '';
      _organization = config['organization'] ?? '';
```

- [ ] **Step 4: Includere il campo nel salvataggio della configurazione**

In `saveConfiguration`, trova:

```dart
    await _storage.saveConfig({
      'base_url': _baseUrl,
      'organization': _organization,
```

Sostituisci con:

```dart
    await _storage.saveConfig({
      'base_url': _baseUrl,
      'cast_base_url': _castBaseUrl,
      'organization': _organization,
```

- [ ] **Step 5: Aggiungere il campo testo in `ConfigPanel`**

In `lib/widgets/config_panel.dart`, trova la dichiarazione dei
controller (riga 13-17):

```dart
  late TextEditingController _baseUrlController;
  late TextEditingController _orgController;
```

Sostituisci con:

```dart
  late TextEditingController _baseUrlController;
  late TextEditingController _castBaseUrlController;
  late TextEditingController _orgController;
```

Trova l'inizializzazione (riga ~34-35):

```dart
    _baseUrlController = TextEditingController(text: appState.baseUrl);
    _orgController = TextEditingController(text: appState.organization);
```

Sostituisci con:

```dart
    _baseUrlController = TextEditingController(text: appState.baseUrl);
    _castBaseUrlController =
        TextEditingController(text: appState.castBaseUrl);
    _orgController = TextEditingController(text: appState.organization);
```

Trova il `dispose` (riga ~44):

```dart
    _baseUrlController.dispose();
```

Sostituisci con:

```dart
    _baseUrlController.dispose();
    _castBaseUrlController.dispose();
```

Trova il blocco `Row` che contiene i campi Base URL/Organization (righe
68-98) e aggiungi una nuova `Row` subito dopo la sua chiusura (dopo la
riga con `const SizedBox(height: 16),` che segue quel `Row`):

```dart
            const SizedBox(height: 16),
            TextField(
              controller: _castBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'CAST Base URL (opzionale)',
                hintText: 'es. https://gswvatfsat19.ternaren.prv:9091',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<AppState>().setCastBaseUrl(value);
              },
            ),
```

- [ ] **Step 2: Verificare che il progetto compili**

Run: `flutter analyze lib/providers/app_state.dart lib/widgets/config_panel.dart`
Expected: `No issues found!` (o solo info pre-esistenti non correlate).

- [ ] **Step 3: Eseguire la suite di test completa**

Run: `flutter test`
Expected: tutti i test passano (nessuna regressione).

- [ ] **Step 4: Commit**

```bash
git add lib/providers/app_state.dart lib/widgets/config_panel.dart
git commit -m "feat: add configurable CAST base URL setting

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 6: Integrare "Verifica CAST" in `BuildEnvironmentTab`

**Files:**
- Modify: `lib/widgets/build_environment_tab.dart`

- [ ] **Step 1: Aggiungere import e stato CAST**

In `lib/widgets/build_environment_tab.dart`, aggiungi in cima al file
(dopo gli import esistenti):

```dart
import 'dart:async';

import 'package:webview_windows/webview_windows.dart';

import '../models/cast_models.dart';
import '../services/cast_client.dart';
```

Nella classe `_ComboSearch`, aggiungi un campo mutabile per il rating
CAST per ambiente. Sostituisci:

```dart
class _ComboSearch {
  final Repository repository;
  final String buildQuery;
  final Map<String, Future<BuildEnvironmentResult>> environmentFutures;

  _ComboSearch({
    required this.repository,
    required this.buildQuery,
    required this.environmentFutures,
  });
}
```

con:

```dart
enum _CastCheckStatus { idle, checking, found, notFound, error }

class _CastCheckState {
  _CastCheckStatus status;
  CastBuildRating? rating;
  String? errorMessage;

  _CastCheckState({this.status = _CastCheckStatus.idle, this.rating, this.errorMessage});
}

class _ComboSearch {
  final Repository repository;
  final String buildQuery;
  final Map<String, Future<BuildEnvironmentResult>> environmentFutures;
  final Map<String, _CastCheckState> castStates = {};

  _ComboSearch({
    required this.repository,
    required this.buildQuery,
    required this.environmentFutures,
  });
}
```

- [ ] **Step 2: Aggiungere il `WebviewController` e stato del riquadro di login allo State**

Nella classe `_BuildEnvironmentTabState`, trova:

```dart
  final List<_QueryRow> _rows = [_QueryRow()];
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_ComboSearch> _results = [];
  String? _error;
```

Sostituisci con:

```dart
  final List<_QueryRow> _rows = [_QueryRow()];
  DateTime? _fromDate;
  DateTime? _toDate;
  List<_ComboSearch> _results = [];
  String? _error;

  final WebviewController _castWebviewController = WebviewController();
  bool _castWebviewInitialized = false;
  bool _isCheckingCast = false;
```

- [ ] **Step 3: Inizializzare e disporre il `WebviewController`**

Trova il metodo `dispose`:

```dart
  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }
```

Sostituisci con:

```dart
  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _castWebviewController.dispose();
    super.dispose();
  }

  Future<void> _ensureCastWebviewInitialized() async {
    if (_castWebviewInitialized) return;
    await _castWebviewController.initialize();
    _castWebviewInitialized = true;
  }
```

- [ ] **Step 4: Aggiungere il metodo `_checkCast`**

Aggiungi un nuovo metodo subito dopo `_search`:

```dart
  Future<void> _checkCast(AppState appState) async {
    if (appState.castBaseUrl.trim().isEmpty) {
      setState(() =>
          _error = 'Configura l\'indirizzo CAST nelle impostazioni.');
      return;
    }
    if (_results.isEmpty) return;

    setState(() {
      _error = null;
      _isCheckingCast = true;
      for (final combo in _results) {
        combo.castStates.clear();
      }
    });

    try {
      await _ensureCastWebviewInitialized();
      final client = CastClient(
        controller: _castWebviewController,
        baseUrl: appState.castBaseUrl.trim(),
      );

      for (final combo in _results) {
        for (final entry in combo.environmentFutures.entries) {
          final environmentLabel = entry.key;
          final result = await entry.value;
          if (result.status != BuildEnvironmentStatus.found) continue;

          setState(() {
            combo.castStates[environmentLabel] =
                _CastCheckState(status: _CastCheckStatus.checking);
          });

          try {
            final component =
                CastClient.castComponentName(combo.repository.name);
            final html = await client.fetchComponentPage(component);
            final rows = CastClient.parseHistoryTable(html);
            final match = CastClient.findExactBuild(
                rows, result.release!.artifactVersion);
            setState(() {
              combo.castStates[environmentLabel] = _CastCheckState(
                status: match == null
                    ? _CastCheckStatus.notFound
                    : _CastCheckStatus.found,
                rating: match,
              );
            });
          } on CastClientError catch (e) {
            setState(() {
              combo.castStates[environmentLabel] = _CastCheckState(
                status: _CastCheckStatus.error,
                errorMessage: e.message,
              );
            });
          }
        }
      }
    } finally {
      setState(() => _isCheckingCast = false);
    }
  }
```

- [ ] **Step 5: Aggiungere il pulsante "Verifica CAST" e il riquadro WebView**

Trova il blocco `Wrap` con i pulsanti data/ricerca (contiene
`FilledButton.icon(onPressed: () => _search(appState), ...)`) e aggiungi
un nuovo pulsante subito dopo la chiusura di quel `FilledButton.icon`:

```dart
                      FilledButton.icon(
                        onPressed: () => _search(appState),
                        icon: const Icon(Icons.search),
                        label: const Text('Cerca tutto'),
                      ),
                      FilledButton.icon(
                        onPressed: (_results.isEmpty ||
                                appState.castBaseUrl.trim().isEmpty ||
                                _isCheckingCast)
                            ? null
                            : () => _checkCast(appState),
                        icon: const Icon(Icons.verified_outlined),
                        label: const Text('Verifica CAST'),
                      ),
```

Poi, nel `build()`, dopo il blocco `if (_results.isNotEmpty) ...` (prima
della chiusura di `Column`), aggiungi il riquadro WebView (visibile solo
mentre una verifica CAST è in corso, per permettere l'eventuale login
NTLM):

```dart
          if (_isCheckingCast) ...[
            const SizedBox(height: 16),
            const Text(
              'Se richiesto, effettua l\'accesso a CAST nella finestra sottostante.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 400,
              height: 300,
              child: _castWebviewInitialized
                  ? Webview(_castWebviewController)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
```

- [ ] **Step 6: Mostrare il rating CAST nella tile ambiente**

Trova il metodo `_environmentTile` e, nel branch
`case BuildEnvironmentStatus.found:`, aggiungi il rating CAST sotto il
testo esistente. Sostituisci:

```dart
            case BuildEnvironmentStatus.found:
              final release = result.release!;
              final dateText = release.createdOn == null
                  ? ''
                  : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(release.createdOn!.toLocal())}';
              return _tileCard(
                label: label,
                color: Colors.green.shade100,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                text: 'Installata · ${release.name}$dateText',
              );
```

con:

```dart
            case BuildEnvironmentStatus.found:
              final release = result.release!;
              final dateText = release.createdOn == null
                  ? ''
                  : ' · ${DateFormat('dd/MM/yyyy HH:mm').format(release.createdOn!.toLocal())}';
              return _tileCard(
                label: label,
                color: Colors.green.shade100,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                text: 'Installata · ${release.name}$dateText',
                extra: _castStatusWidget(combo.castStates[label]),
              );
```

`combo` è già disponibile in questo scope: `_environmentTile(String
label, _ComboSearch combo)` riceve `combo` come parametro e
`_buildResultCard` lo passa già correttamente — non serve modificare
quelle firme.

Il file `lib/widgets/build_environment_tab.dart` termina attualmente
(dal metodo `_tileCard` in poi) con questo blocco esatto:

```dart
  Widget _tileCard({
    required String label,
    required Color color,
    required Widget icon,
    required String text,
  }) {
    // Tile backgrounds are always light (green/amber/grey/red shade100-200),
    // so text/icon colors are fixed to dark regardless of the app theme to
    // guarantee readable contrast (see dark theme readability fix).
    const textColor = Colors.black87;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: textColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

Sostituisci **esattamente questo blocco** (dalla firma di `_tileCard`
fino all'ultima riga del file) con:

```dart
  Widget _tileCard({
    required String label,
    required Color color,
    required Widget icon,
    required String text,
    Widget? extra,
  }) {
    // Tile backgrounds are always light (green/amber/grey/red shade100-200),
    // so text/icon colors are fixed to dark regardless of the app theme to
    // guarantee readable contrast (see dark theme readability fix).
    const textColor = Colors.black87;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 12, color: textColor),
                ),
              ),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: 8),
            extra,
          ],
        ],
      ),
    );
  }

  Widget? _castStatusWidget(_CastCheckState? state) {
    if (state == null) return null;
    switch (state.status) {
      case _CastCheckStatus.idle:
        return null;
      case _CastCheckStatus.checking:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 6),
            Text('CAST: verifica…', style: TextStyle(fontSize: 11)),
          ],
        );
      case _CastCheckStatus.found:
        final rating = state.rating!.rating;
        final isA = rating.toUpperCase() == 'A';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isA ? Colors.green.shade300 : Colors.red.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('CAST: $rating',
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
        );
      case _CastCheckStatus.notFound:
        return const Text('CAST: non trovato',
            style: TextStyle(fontSize: 11, color: Colors.black54));
      case _CastCheckStatus.error:
        return Tooltip(
          message: state.errorMessage ?? '',
          child: const Text('CAST: errore',
              style: TextStyle(fontSize: 11, color: Colors.red)),
        );
    }
  }
}
```

- [ ] **Step 7: Verificare che il progetto compili**

Run: `flutter analyze lib/widgets/build_environment_tab.dart`
Expected: nessun errore di compilazione (solo eventuali info
pre-esistenti come `withOpacity`/`DropdownButtonFormField.value`).

- [ ] **Step 8: Eseguire la suite di test completa**

Run: `flutter test`
Expected: tutti i test passano (nessuna regressione; questo widget non ha
test dedicati, si verifica solo che l'app compili e gli altri test non
siano stati impattati).

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/build_environment_tab.dart
git commit -m "feat: add Verifica CAST button and rating display

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 7: Build e verifica manuale finale

- [ ] **Step 1: Compilare l'app Windows**

Run: `flutter build windows --debug`
Expected: `Built build\windows\x64\runner\Debug\gitsnap_flutter.exe` senza
errori.

- [ ] **Step 2: Avviare l'app**

Run: `Start-Process build\windows\x64\runner\Debug\gitsnap_flutter.exe`

- [ ] **Step 3: Configurare l'host CAST**

Nell'app: apri il tab "Confronto repository", nella sezione di
configurazione compila il nuovo campo "CAST Base URL (opzionale)" con
l'indirizzo reale del portale CAST (es.
`https://gswvatfsat19.ternaren.prv:9091`), poi salva la configurazione.

- [ ] **Step 4: Verificare il pulsante "Verifica CAST"**

Vai sul tab "Verifica build", cerca una combinazione repository+build
reale che risulti installata in almeno un ambiente (come nel Task 6 del
piano "Verifica build" già completato), poi premi "Verifica CAST".
Se appare il popup nativo "Sicurezza di Windows", inserisci le
credenziali di dominio (es. `ternaren\xt1374` + password) nel riquadro
WebView mostrato nell'app. Verifica che, al termine, la tile
dell'ambiente mostri il rating CAST corretto (confronta con il valore
visibile manualmente sul portale CAST per quella stessa build).

- [ ] **Step 5: Verificare il caso "non trovato"**

Ripeti la ricerca con una build che sai NON essere presente nello storico
CAST del componente (es. una versione inventata) e verifica che la tile
mostri "CAST: non trovato" invece di un errore.

- [ ] **Step 6: Verificare la persistenza della configurazione**

Chiudi e riapri l'app, verifica che il campo "CAST Base URL" sia ancora
compilato con il valore salvato in precedenza (letto da
`AppState.castBaseUrl` all'avvio).
