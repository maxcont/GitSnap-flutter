# Release Note: riepilogo e filtri per repository

## Obiettivo

Dopo una verifica Release Note, distinguere visivamente i repository coinvolti,
mostrarne il numero di risultati e consentire di nasconderli o mostrarli senza
eseguire nuovamente la ricerca.

## Riepilogo generale

In cima ai risultati rimane sempre visibile un riepilogo dell'intera verifica,
indipendente dai filtri: repository coinvolti, numero totale di elementi
(PR e commit diretti), conteggi delle categorie e stringhe mancanti globali.
Gli spostamenti manuali aggiornano i conteggi delle categorie.

Un repository è coinvolto se almeno una sua branch corrisponde ai criteri,
anche se non contiene elementi nel periodo. I repository senza branch
corrispondenti rimangono nella sezione esistente dei repository non coinvolti.
Gli errori continuano a essere segnalati come verifica incompleta.

## Filtri e risultati

Sotto il riepilogo, ogni repository coinvolto ha un controllo selezionabile
con nome, colore e numero totale dei suoi elementi. I repository sono tutti
selezionati inizialmente, anche quelli con zero elementi. Colori e nomi
identificano gli stessi repository sia nei controlli sia negli elementi;
il colore non è l'unico indicatore e deve restare leggibile nei temi chiaro e
scuro. Le selezioni si riferiscono agli ID dei repository, non ai loro nomi.

Nascondere un repository filtra solo la visualizzazione: non modifica i dati,
gli spostamenti manuali o i conteggi del riepilogo generale e non richiede
chiamate Azure. I conteggi per categoria accanto ai risultati filtrati si
riferiscono ai soli repository selezionati. Un nuovo risultato ripristina la
selezione di tutti i repository coinvolti.

## Stringhe mancanti

Il riepilogo generale mantiene le stringhe mancanti nell'intera verifica.
Nella vista filtrata:

* **Mancanti nei repository selezionati**: stringhe senza corrispondenze negli
  elementi visibili.
* **Trovate solo negli altri repository**: sottoinsieme delle precedenti che
  compare almeno una volta negli elementi nascosti.

Sono mostrati sia i conteggi sia le stringhe, mantenendo l'ordine della Release
Note. Le stringhe nel primo gruppo ma non nel secondo sono mancanti ovunque.
Con nessun repository selezionato, tutte le stringhe sono mancanti nei
selezionati e quelle presenti nei risultati globali sono trovate negli altri.
La presenza di una corrispondenza non dipende dalla categoria manuale.

## Verifica

Aggiungere test mirati per repository senza elementi, selezione e deselezione,
conteggi globali e filtrati, stringhe trovate solo nei repository nascosti,
nessuna selezione, spostamenti manuali e ripristino alla nuova ricerca.
Verificare che gli avvisi esistenti restino visibili e che filtrare non
richieda nuove chiamate.
