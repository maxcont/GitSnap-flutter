# Design: Rename the PR and commit tab

## Context

The app's top-level navigation currently calls this area "Pull request", while
its two nested views are "Panoramica PR" and "Ricerca commit". The top-level
name should describe both features.

## Decision

Rename the top-level tab to **PR e commit**. This is shorter than "Pull request
e commit" while clearly covering both nested views. Keep "Panoramica PR" and
"Ricerca commit" unchanged.

## Scope

- Change the top-level tab label in the home screen.
- Update README references to the tab name.
- Do not change icons, navigation behavior, nested view labels, or other
  category names.

## Validation

Run the repository's existing targeted Flutter analysis or tests for the
changed files, if available. Confirm that the top-level label is consistent
between the app and README.
