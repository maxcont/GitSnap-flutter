# Windows app icon design

## Goal

Use `assets/ico/ico_white.png` as the Windows application icon so the executable and its Windows window use the supplied GitSnap artwork.

## Scope

- Replace the default Windows icon at `windows/runner/resources/app_icon.ico`.
- Keep `windows/runner/Runner.rc` pointing at that existing resource.
- Leave `assets/ico/ico_blue.png` and all non-Windows platforms unchanged.
- Do not add a runtime dependency or change the Flutter UI.

## Implementation

Generate a Windows ICO resource from the supplied PNG, including standard icon sizes so Windows can select an appropriate resolution. Store the result at the existing resource path referenced by `Runner.rc`. Preserve the PNG source in `assets/ico`.

## Validation

Verify that the generated ICO contains multiple usable resolutions and that the Windows desktop target builds with the existing resource reference. Run the narrowest available Flutter analysis/build checks without modifying unrelated files.
