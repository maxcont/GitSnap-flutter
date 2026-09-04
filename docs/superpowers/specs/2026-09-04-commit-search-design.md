# Commit Search Design

## Objective

Add a `Ricerca commit` sub-tab to the Pull request area. It finds a text such
as an RF or incident identifier in commit messages across selected repositories
and shows which repositories contain matching commits.

## User Experience

- Search runs only after the user selects **Cerca**.
- The initial date interval is the last 12 months and both dates are editable.
- Repositories use the existing multi-selection pattern; all repositories are
  included when no repository filter is selected.
- `develop` and `master` are selectable search branches by default.
- **Tutte le branch** scans every branch and overrides the selected branch
  names.
- Results show only repositories with matches, grouped by repository.
- A header shows repositories analysed, repositories with results, and total
  unique matching commits.
- The same commit is deduplicated by hash inside a repository and lists every
  analysed branch where it was found.

## Data and Reliability

The Azure DevOps Git commits endpoint is called per repository and branch,
using bounded parallelism and pagination. Matching is case-insensitive against
the commit message. Errors on a repository or branch stay visible while valid
results remain available. Commit rows display short hash, message, author,
date, matching branches, and a direct Azure DevOps commit link.
