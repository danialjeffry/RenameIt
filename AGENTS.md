# AGENTS.md

Concise reference for AI coding agents and contributors working with this repo.
For human-facing docs see [README.md](./README.md).

## What this is

**RenameIt** — a batch file-renamer with a live preview, available as a native
macOS menu bar app **and** a Windows GUI app (built separately from different
code). Full product docs: [README.md](./README.md).

- macOS: Swift (SwiftUI + AppKit), arm64, macOS 14.0+
- Windows: Python 3.9+ + CustomTkinter
- License: MIT

## Repository layout

```
Sources/                  # macOS Swift app
  RenameItApp.swift       # @main App entry point
  AppDelegate.swift       # Status item, popover, window management, apply/undo
  RenameModel.swift       # Naming engine (recompute), settings, presets
  RenameView.swift        # SwiftUI panel
Scripts/
  build.sh                # Builds macOS RenameIt.app (arm64)
windows/                  # Windows Python app (separate)
  RenameIt.py             # Main app (all features, CustomTkinter)
  build.bat               # Builds RenameIt.exe via PyInstaller
  requirements.txt        # customtkinter, tkinterdnd2
  README.md               # Windows-specific install/usage
.github/workflows/
  build-windows.yml       # Auto-builds .exe on GitHub release
TestFiles/                # Local sample files for manual renaming tests
```

## Build

### macOS (arm64, needs Xcode Command Line Tools)
```bash
./Scripts/build.sh
```
Output: `RenameIt.app` in the repo root. `swiftc -target arm64-apple-macosx14.0
-parse-as-library` over the 4 files in `Sources/`, writes an `Info.plist`,
ad-hoc codesigns.

### Windows (from the `windows/` directory)
```bash
pip install customtkinter tkinterdnd2
python RenameIt.py                 # run from source
build.bat                          # build a standalone .exe (PyInstaller)
```
`tkinterdnd2` is optional — the app builds/runs without drag-and-drop if absent
(the CI handles both cases). Requires Windows 10/11 + Python 3.9+.

## How the rename engine works

`RenameModel.recompute()` builds each new name by applying, in order:
find/replace → case/whitespace → numbering → prefix/suffix → extension.
Results are stored per-file so the UI shows a live preview. Nothing is written
until **Apply**, which uses `FileManager.moveItem` (macOS) / `os.rename`
(Windows). Recent versions also include collision detection, undo, regex
find/replace, date-based naming, and presets.

## CI

`.github/workflows/build-windows.yml` builds the `.exe` on GitHub release
creation (and `workflow_dispatch`) and attaches it to the release.

## Contribution notes

- Two separate apps share the name but have different code paths (Swift vs
  Python). Make changes in BOTH if you want parity.
- macOS: keep the 4-source-file `swiftc` build working; add new `Sources/*.swift`
  files to the `swiftc` line in `Scripts/build.sh`.
- Windows: keep `RenameIt.py` runnable as `python RenameIt.py` and buildable via
  `build.bat`.
- No formal test suite; validate by building and manually renaming files.
