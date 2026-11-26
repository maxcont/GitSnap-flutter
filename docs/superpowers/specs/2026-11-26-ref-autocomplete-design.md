# Autocomplete branch/tag nel confronto repository — Design

## Obiettivo

Nel pannello SOURCE/TARGET (`lib/widgets/ref_config_panel.dart`) offrire, solo su richiesta, suggerimenti mentre si digita il valore del ref, caricando branch o tag dei repository selezionati solo quando servono.

## UI

- Switch **"Suggerimenti branch/tag"** sopra SOURCE/TARGET, spento di default. Lo stato vive in `AppState` per la sessione corrente: oggi l'app non ha persistenza delle preferenze e non viene aggiunta.
- Con switch attivo, il campo Valore diventa un `DropdownMenu<String>` modificabile con filtro quando il tipo è **Branch** o **Tag pattern**. Si usa `DropdownMenu` invece di `RawAutocomplete`, che ricalcola le opzioni solo al cambio del testo e quindi non le mostrerebbe a fine caricamento. Il testo resta libero: si può sempre inserire un valore non suggerito.
- Tipo **Commit SHA**: nessun autocomplete, campo invariato.
- Icona ⟳ come suffisso del campo: forza il ricaricamento; durante il caricamento mostra uno spinner.
- Ogni opzione mostra il nome e il badge `N/M repo`, cioè in quanti repository selezionati esiste.
- Filtro: `contains` case-insensitive sul testo digitato. Ordine: prima i ref presenti in tutti i repo, poi per numero di repo decrescente, poi alfabetico. Massimo 50 opzioni visibili.
- **Tag pattern**: sotto il campo, anteprima "Il pattern trova X tag in Y/M repo", calcolata con la stessa logica di matching usata da `RefResolver`. L'anteprima compare solo quando ci sono suggerimenti caricati e il campo non è vuoto.
- Errori parziali: se alcuni repo falliscono, il testo d'aiuto indica "K repo non letti" e mostra comunque i suggerimenti degli altri. Se falliscono tutti, viene mostrato l'errore nel testo d'aiuto.

## Dati

- Nuovo `RefSuggestionService` (`lib/services/ref_suggestion_service.dart`):
  - `Future<RefSuggestions> load(AzureDevOpsClient client, List<Repository> repos, RefType type)`: chiama `getBranches` o `getTags` con concorrenza massima 5, rimuove i prefissi `refs/heads/` / `refs/tags/` e aggrega `nome -> numero repo`. Registra i repo falliti.
  - Funzione pura `List<RefSuggestion> filter(RefSuggestions, String query, {int limit = 50})`: filtro e ordinamento.
  - Funzione pura per l'anteprima del pattern tag, che riusa il matching di `RefResolver` estratto o esposto come funzione statica senza cambiarne il comportamento.
- `AppState`: cache `Map<RefType, RefSuggestions>` legata all'insieme degli id dei repo selezionati. Viene invalidata quando cambia la selezione o con ⟳. Il metodo `ensureRefSuggestions(RefType, {bool force = false})` evita caricamenti concorrenti duplicati.
- Trigger: il caricamento parte quando lo switch è attivo **e** il campo prende il focus (o con ⟳). Senza client o senza repo selezionati non si carica nulla e il testo d'aiuto lo indica.

## Test

Unit test di `RefSuggestionService`:

- aggregazione e conteggi tra più repository, con rimozione dei prefissi;
- gestione dei repo falliti;
- filtro case-insensitive, ordinamento e limite;
- anteprima del pattern tag coerente con `RefResolver`.

## Fuori ambito

Autocomplete per Commit SHA e suggerimenti in altre schermate.
