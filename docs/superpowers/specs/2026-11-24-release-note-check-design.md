# Design: Verifica Release Note

## Context

Users need to know **everything that entered a release branch** (every merged
feature) and compare it with a Release Note (RN). The requirement asks for:

1. **RN completeness**: every RN entry must be found in what entered the
   branch; entries not found are reported as **Mancanti**.
2. **Branch consistency**: content that entered the branch but is not covered
   by the RN must be highlighted as **Fuori perimetro**.
3. **Unclassifiable content**: items that cannot be attributed (merges,
   configuration, technical work) are listed separately as **Da verificare**,
   without being treated as errors.

The unit of analysis is the **completed pull request** targeting the branch
(one PR = one feature), plus **direct commits** that reached the branch without
a PR. This is not a SOURCE/TARGET comparison.

## Decisions

- **Placement**: a new nested tab **Verifica Release Note** in *PR e commit*,
  next to "Panoramica PR" and "Ricerca commit". Other tabs are unchanged.
- **Inputs**:
  - repositories: optional subset (empty = all loaded repositories);
  - reference branches: one or more names or a pattern (e.g. `release/*`);
  - start date (required) and end date (optional, default today), applied to
    the PR completion date and to direct commit dates;
  - RN entries: free strings, one per line. Lines are trimmed; blank lines and
    case-insensitive duplicates are removed. No extraction is performed.
- **Matching**: an entry matches a text when the text contains it
  case-insensitively and the match is not adjacent to a letter or digit on
  either side, so `INC376` matches `fix INC376:`, `[inc376]` and
  `feature/INC376-login`, but not `INC3761`. Entries are matched literally.
- **PR searchable text**: title, source branch name, description and messages
  of the PR commits.
- **Branch not present in a repository**: the repository is reported as
  "non coinvolto", not as an error.

## Data collection (per repository with a matching branch)

1. **Completed PRs**: PRs with status `completed`, target branch equal to the
   reference branch, `closedDate` within the period. Fetched with
   `searchCriteria.status=completed` and `searchCriteria.targetRefName`,
   paginated with `$top`/`$skip`; the period is filtered client-side.
2. **PR commits**: `pullRequests/{id}/commits` for each PR, paginated,
   with concurrency 5 and progress reporting.
3. **Direct commits**: branch commits in the period (`getCommitsForBranch`,
   paginated) excluding:
   - commits listed in any completed PR of that repository and branch;
   - PR merge commits (`lastMergeCommit`);
   - commits whose message and author equal a commit of one of those PRs
     (covers rebase merges, which rewrite SHAs).

## Classification

| List | Content | Assignment |
|---|---|---|
| **Mancanti** | RN entries matching no PR and no direct commit | automatic |
| **OK** | PRs or direct commits matching at least one entry | automatic |
| **Da verificare** | PRs and direct commits matching no entry | automatic |
| **Fuori perimetro** | Content that entered but is not expected | manual |

Since entries are free strings, the tool cannot infer that an item refers to
another release; **Fuori perimetro** is assigned by moving items manually.

## Manual reclassification

Each PR and direct-commit row has a "Sposta in…" menu to move it among **OK**,
**Fuori perimetro** and **Da verificare**. Rows whose current list differs from
the automatic one show an indicator. Moves are in memory only and are reset
when a new check runs. Summary counters reflect the current lists.

## UI

- Filters (repositories, branches, dates), RN text area with entry count and a
  "Verifica" button.
- Progress (phase and counter) while loading.
- Warnings: "Verifica incompleta per: …" for failed calls; "Repository non
  coinvolti: …" for missing branches.
- Summary chips: Mancanti / OK / Fuori perimetro / Da verificare.
- Mancanti: list of entries.
- OK, Fuori perimetro, Da verificare: expandable rows. A PR row shows
  repository, PR id and title, source → target branch, author, completion date,
  matched entries and a link; expanding it lists its commits. Direct commits
  are shown with a "Commit diretto" badge, repository, short SHA, message,
  author, date, matched entries and a link.

## Components

- `lib/models/release_note_models.dart`: `ReleaseNoteCategory`
  (`ok`, `outOfScope`, `toVerify`), `ReleaseNoteItem` (key, repository, kind
  PR or direct commit, PR summary or commit, PR commits, matched entries,
  automatic category) and `ReleaseNoteCheckResult` (items, missing entries,
  uninvolved repositories, warnings).
- `lib/services/release_note_check_service.dart`: pure Dart, no I/O.
  `parseEntries`, `matches(entry, text)`, `findDirectCommits(...)` and
  `classify(entries, items)`.
- `lib/services/release_note_data_loader.dart`: Azure calls per repository and
  branch (branches, completed PRs, PR commits, branch commits) with
  concurrency, progress and per-call error collection.
- `AzureDevOpsClient`: `getCompletedPullRequests(repoId, targetBranch)` and
  `getPullRequestCommits(repoId, prId)`, both paginated; `getCommitsForBranch`
  gains pagination. `PullRequestSummary` parses `description` and
  `lastMergeCommit` if not already available.
- `AppState`: `runReleaseNoteCheck(...)`, result, progress and error state, and
  `moveReleaseNoteItem(key, category)`.
- `lib/widgets/release_note_check_tab.dart`, mounted in `PullRequestsTab`.

## Out of scope

Report export, persistence of RN text and manual moves, automatic Fuori
perimetro detection, Azure DevOps work item links, SOURCE/TARGET mode.

## Testing

- `parseEntries`: trimming, blanks, duplicates.
- `matches`: boundaries (`INC376` vs `INC3761`), case, brackets, branch names,
  regex characters in entries.
- `classify`: OK / Da verificare, Mancanti, multiple repositories, entry
  matched only in a PR commit message.
- `findDirectCommits`: exclusion by PR commit id, merge commit, and same
  message and author.
- Client pagination for the new and updated methods, using an injectable HTTP
  client if available; otherwise test the page-merging helper.
- Widget test: run with stubbed data, move an item and check counters.
- Run `flutter analyze` and `flutter test`.

## Delivery

Branch `feature/release-note-check` from `main`. Update README with a short
description of the new view.
