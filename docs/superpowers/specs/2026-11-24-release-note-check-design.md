# Design: Verifica Release Note

## Context

Users need to attach a Release Note (RN) to the branch under verification and
use the codes listed in the RN (e.g. `INC376`) as the expected release
perimeter. The check must work in both directions:

1. **RN completeness**: every RN code must appear in at least one branch commit;
   codes without commits are reported as **Mancanti**.
2. **Branch consistency**: branch commits referring to codes not in the RN are
   reported as **Fuori perimetro**.
3. **Unclassifiable commits**: commits without any recognizable code (merges,
   configuration, technical work) are listed separately as **Da verificare**,
   without being treated as errors.

The "branch under verification" is SOURCE and the baseline is TARGET in the
existing *Confronto ambienti* tab. The release perimeter is the set of commits
in SOURCE and not in TARGET (`DiffResult.commits`) across all compared
repositories.

## Decisions

- **Placement**: an expandable "Verifica Release Note" panel in the
  *Confronto ambienti* tab, below `ResultsDashboard`, shown only when diff
  results exist. It reuses the already computed SOURCE→TARGET commits; no new
  ref configuration and no extra API calls for the check itself.
- **RN input**: free text pasted into a text area. Codes are separated by new
  lines, `,`, `;` or whitespace, trimmed, upper-cased and de-duplicated.
- **Matching**: an RN code matches a commit when it appears in the commit
  message case-insensitively and is not adjacent to letters or digits
  (`INC376` matches `fix INC376:` and `[inc376]`, but not `INC3761`).
- **Code prefix**: the leading alphabetic part of each RN code (`INC376` →
  `INC`). A commit "looks like it has a code" when it contains a token made of
  one of these prefixes followed by digits (optional `-` or `_` separator),
  with the same boundary rules.

## Classification

For each commit in SOURCE→TARGET of every repository:

| Condition | Category |
|---|---|
| At least one RN code matches | **OK** |
| No RN code matches, but a prefixed code token is present | **Fuori perimetro** |
| Neither | **Da verificare** |

A commit with both RN and non-RN codes is **OK**; the extra codes are shown on
the row. **Mancanti** lists the RN codes that matched no commit.

## Manual reclassification

Each commit row has a "Sposta in…" menu to move it to another of the three
commit lists. Moved rows show an indicator when the current category differs
from the automatic one. Moves are in-memory only and are reset by a new
comparison or a new check. The pasted RN text is kept while the app is open.

## Components

- `lib/models/release_note_models.dart`: `ReleaseNoteCategory`
  (`ok`, `outOfScope`, `toVerify`), `ClassifiedCommit` (repo id/name, `Commit`,
  matched RN codes, other codes, automatic category) and
  `ReleaseNoteCheckResult` (classified commits, `missingCodes`, list of repos
  with incomplete data).
- `lib/services/release_note_check_service.dart`: pure Dart, no I/O.
  `parseCodes(String)` and `check(List<String> codes, List<DiffResult>)`.
- `lib/widgets/release_note_check_panel.dart`: text area, "Verifica" button,
  recognized-code count, summary chips (Mancanti / OK / Fuori perimetro /
  Da verificare), missing-code list and three commit tables (repo, short SHA,
  message, author, date, codes, "Sposta in…").
- `lib/screens/home_screen.dart`: mounts the panel in `_ComparisonTab`.

## Data completeness

`AzureDevOpsClient.getCommitsBetween` currently fetches at most 250 commits and
`DiffService` silently ignores fetch errors. A truncated list would produce
false **Mancanti**. Therefore:

- `getCommitsBetween` paginates with `$skip` until a page returns fewer
  items than `$top`.
- `DiffResult` gains a nullable `commitsError` set when the commit list
  fetch fails. Repositories with `status == error` or `commitsError` are listed
  in a warning ("Verifica incompleta per: …") at the top of the panel.

## Out of scope

Export of the report, persistence of manual moves, configurable regex
patterns, reading Azure DevOps work item links, and TARGET→SOURCE commits.

## Testing

- Unit tests for `parseCodes` (separators, case, duplicates, blanks).
- Unit tests for matching boundaries (`INC376` vs `INC3761`, brackets,
  lower case) and for the three categories plus **Mancanti**, across multiple
  repositories.
- Unit test for `getCommitsBetween` pagination with a mocked HTTP client, if
  the existing client tests allow injection; otherwise test the page-merging
  helper.
- A focused widget test: paste codes, run the check, move a commit to another
  list and verify the counters.
- Run `flutter analyze` and `flutter test`.

## Delivery

Work on branch `feature/release-note-check` from `main`. Update README with a
short description of the feature.
