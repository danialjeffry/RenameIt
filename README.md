# RenameIt 🏷️

A tiny macOS **menu bar** app for batch-renaming files right from the top-right
of your screen. Drag in files, set your renaming rules, watch a live preview
of every new filename, then apply with one click.

No Dock icon, no setup — it lives quietly in your menu bar until you need it.

---

## Features

- **Drag-and-drop** — drop any files into the window to add them (folders, too).
- **Find & Replace** — swap any text inside filenames.
- **Prefix / Suffix** — add text to the start or end of every name.
- **Auto-numbering** — append an ordered sequence number (001, 002, …) with
  configurable start value and padding.
- **Case & whitespace** — lowercase, uppercase, and replace spaces with `_`.
- **Extension rename** — change the file extension of everything at once.
- **Live preview** — every prospective new name is shown before you commit,
  with the old name struck through. Changes are highlighted.
- **Safe by default** — nothing is renamed until you click **Apply Rename**;
  preview is purely visual.

---

## Requirements

### macOS
- macOS **14.0 (Sonoma)** or later
- An **Apple Silicon** Mac (M1/M2/M3/M4...) — build script targets arm64.
- Xcode Command Line Tools (to build from source):
  ```bash
  xcode-select --install
  ```

### Windows
- Windows 10/11
- Python 3.9+ (for running from source)
- Or download the `.exe` from [Releases](https://github.com/danialjeffry/RenameIt/releases) (no Python needed)

---

## Install (pre-built app)

1. Extract `RenameIt.app` from the zip and drag it into your **Applications** folder.
2. First launch: right-click (or Ctrl-click) the app → **Open** → **Open** again.
   (It's ad-hoc signed, so macOS shows an "unverified developer" warning once.)
3. (Optional) Auto-start at login: **System Settings → General → Login Items**.

---

## Build from source

```bash
cd RenameIt
./Scripts/build.sh
```

This compiles the Swift sources and outputs `RenameIt.app` in the project root.

---

## Usage

1. Launch the app — you'll see the ✎ (text cursor) icon in the top-right menu bar.
2. Click it to open RenameIt.
3. **Drop files** into the window.
4. Configure your rules in the panels (find/replace, prefix/suffix, numbering,
   case/whitespace, extension).
5. Review the **live preview** of new names below.
6. Click **Apply Rename** — done. Use **Clear** to empty the list first if needed.

### Example

Drop in `IMG_001.jpg`, `IMG_002.jpg`, `IMG_003.jpg` with:
- Prefix: `holiday-`
- Auto-numbering: on, starting at 1, padding 3

Preview shows `holiday-IMG_001_001.jpg`, `holiday-IMG_002_002.jpg`, … exactly
as they would be written. Apply when you're happy.

---

## Project structure

```
RenameIt/
├── Sources/             # macOS Swift source files
│   ├── RenameItApp.swift
│   ├── AppDelegate.swift
│   ├── RenameModel.swift
│   └── RenameView.swift
├── Scripts/
│   └── build.sh              # Build macOS .app
├── windows/             # Windows Python version
│   ├── RenameIt.py           # Main app (all features)
│   ├── build.bat             # Build to .exe
│   ├── requirements.txt
│   └── README.md
├── .github/workflows/
│   └── build-windows.yml     # Auto-builds .exe on release
└── README.md
```

---

## How it works

The engine (`RenameModel.recompute()`) reads your settings and, for every file,
builds the new name by applying: find/replace → case/whitespace → numbering →
prefix/suffix → extension. Each result is stored on the file entry, so the view
can render a live preview with zero risk — files are only moved on **Apply**,
which uses `FileManager.moveItem`.

---

## Notes

- **Ad-hoc signed** — fine for personal use and sharing with friends; not
  notarized for the Mac App Store.
- There is **no undo** in v1. Preview carefully before applying, and consider a
  quick backup if renaming important files.
