# Design: Verifica Release Note

## Context

Users need to attach a Release Note (RN) to a release branch and use its
entries as the expected release perimeter. The requirement asks for:

1. **RN completeness**: every RN entry must be found in at least one commit of
   the branch; entries without commits are reported as **Mancanti**.
2. **Branch consistency**: commits not covered by the RN must be highlighted
   as **Fuori perimetro**.
3. **Unclassifiable commits**: commits that cannot be attributed (merges,
   configuration, technical work) are listed separately as **Da verificare**,
   without being treated as errors.

Stakeholders want to know "everything that was merged" into the release
branch. This is not a SOURCE/TARGET comparison: the perimeter is every commit
on the reference branch (or branches) from a start date, across the selected
repositories.

The existing *PR e commit → Ricerca commit* view already reads branches and
commits per repository with concurrency, progress, date range, branch filters
(names, prefixes, pattern, all) and skipped-branch warnings. It searches one
string. This feature reuses that pipeline and searches N strings.

## Decisions

- **Placement**: a new nested tab **Verifica Release Note** in *PR e commit*,
  next to "Panoramica PR" and "Ricerca commit". The *Confronto ambienti* tab is
  unchanged.
- **Inputs**:
  - repositories: optional subset (empty = all loaded repositories);
  - branches: names, prefixes or pattern (e.g. `release/*`), like Ricerca
    commit;
  - start date (required) and end date (optional, default today);
  - RN entries: free strings, one per line. Lines are trimmed; blank lines and
    case-insensitive duplicates are removed. No code extraction is performed.
- **Matching**: an RN entry matches a commit when the commit message contains
  it case-insensitively and the match is not adjacent to a letter or digit on
  either side, so `INC376` matches `fix INC376:` and `[inc376]` but not
  `INC3761`. Entries are matched literally (regex characters escaped).
- **Automatic classification**: commits matching at least one entry are **OK**;
  all other commits are **Da verificare**. Since entries are free strings, the
  tool cannot infer that a commit refers to another release; **Fuori
  perimetro** is assigned manually.
- **Mancanti**: RN entries that matched no commit.

## Manual reclassification

Each commit row has a "Sposta in…" menu to move it among **OK**, **Fuori
perimetro** and **Da verificare**. Rows whose current list differs from the
automatic one show an indicator. Moves are kept in memory only and are reset
when a new check runs. Summary counters reflect the current lists.

## Date semantics

Azure DevOps filters commits by commit date, not by the time they reached the
branch. With squash or rebase merges, commits carry the merge time. With
classic merges, older commits merged after the start date are excluded, but the
merge commit ("Merged PR 123: <title>") is included, so entries present in PR
titles are still found. The view shows a short hint explaining this.

## Components

- `lib/services/branch_commit_collector.dart`: extracted from
  `AppState.searchCommits`. Given repositories, branch filters and a date range,
  returns commits de-duplicated per repository (with the branches containing
  them), skipped branches and errors. `searchCommits` is refactored to use it
  without behavior changes.
- `lib/models/release_note_models.dart`: `ReleaseNoteCategory`
  (`ok`, `outOfScope`, `toVerify`), `ReleaseNoteCommit` (repository, commit id,
  message, author, date, branches, web URL, matched entries, automatic
  category) and `ReleaseNoteCheckResult` (commits, missing entries, warnings).
- `lib/services/release_note_check_service.dart`: pure Dart.
  `parseEntries(String)` and `check(entries, collectedCommits)`.
- `AppState`: `runReleaseNoteCheck(...)`, result, progress and error state,
  plus `moveReleaseNoteCommit(key, category)`.
- `lib/widgets/release_note_check_tab.dart`: filters, RN text area with entry
  count, "Verifica" button, progress, warnings, summary chips
  (Mancanti / OK / Fuori perimetro / Da verificare), missing-entry list and
  three commit lists (repository, short SHA, message, author, date, branches,
  matched entries, "Sposta in…", link to the commit).

## Data completeness

`getCommitsForBranch` requests `$top=2000` without pagination, so large ranges
can be truncated and produce false **Mancanti**. It will paginate with `$skip`
until a page returns fewer items than `$top`. Branch-read and commit-read
errors and skipped branches are shown as warnings above the results
("Verifica incompleta per: …" for errors, "Branch non presenti" for skipped
branches, which mean the repository is not part of the release).

## Out of scope

Report export, persistence of RN text and manual moves, automatic Fuori
perimetro detection, Azure DevOps work item links, SOURCE/TARGET mode.

## Testing

- `parseEntries`: separators by line, trimming, blanks, duplicates.
- Matching: boundaries (`INC376` vs `INC3761`), case, brackets, regex
  characters in entries.
- `check`: OK / Da verificare, Mancanti, multiple repositories, a commit
  matching multiple entries.
- `getCommitsForBranch` pagination, if the client allows HTTP injection;
  otherwise the page-merging logic.
- Regression: existing Ricerca commit tests still pass after the extraction.
- Widget test: enter entries, run with stubbed data, move a commit and check
  counters.
- Run `flutter analyze` and `flutter test`.

## Delivery

Branch `feature/release-note-check` from `main`. Update README with a short
description of the new view.
