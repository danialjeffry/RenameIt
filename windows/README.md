# RenameIt — Windows

A **batch file renamer** for Windows with a modern GUI. Drag in files, set
renaming rules, preview live results, and apply with one click.

Same features as the macOS version, built with Python + CustomTkinter.

---

## Features

- **Drag-and-drop** — drop files into the window (requires `tkinterdnd2`)
- **Browse button** — or click to open a file picker
- **Find & Replace** — with optional regex support
- **Prefix / Suffix** — add text to start or end of every name
- **Auto-numbering** — sequence numbers with configurable start and padding
- **Case & whitespace** — Lowercase, Uppercase, replace spaces with `_`
- **Extension rename** — change all file extensions at once
- **Date append** — file modification date or custom date, with preset formats
- **Live preview** — see every new name before committing
- **Collision detection** — warns if any files would get the same name
- **Confirmation dialog** — "Are you sure?" before renaming
- **Per-file remove** — remove individual files from the list
- **Reorder** — move files up/down to control numbering sequence
- **Undo** — reverse the last rename batch
- **Presets** — save/load/delete naming configurations

---

## Requirements

- **Windows 10/11**
- **Python 3.9+**
- pip packages: `customtkinter`, `tkinterdnd2`

---

## Install & Run

### Option A: Run as Python script

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Run the app
python RenameIt.py
```

### Option B: Build to .exe (standalone, no Python needed)

Double-click `build.bat`, or run it in Command Prompt:

```
build.bat
```

This creates `dist/RenameIt.exe` — a single file you can give to anyone.
No Python required on the target machine.

### Option C: Manual PyInstaller build

```bash
pip install customtkinter pyinstaller
pyinstaller --noconfirm --onefile --windowed --name "RenameIt" RenameIt.py
```

If `tkinterdnd2` fails to install, the app still works — just use the
**Browse** button instead of drag-and-drop.

---

## Usage

1. Launch `python RenameIt.py`
2. **Drop files** into the window, or click **+ Add Files** to browse
3. Configure your rules in the panels
4. Review the **live preview** — old names grayed out, new names in bold
5. Click **Apply Rename** — confirm in the dialog
6. Use **Undo** to reverse if needed

---

## Presets

- Click **💾 Save** to save current settings as a named preset
- Use the dropdown to load a saved preset
- Click **🗑 Delete** to remove a preset

Presets are saved to `~/.renameit_presets.json`.

---

## Notes

- **Ad-hoc quality** — built for personal use, not a polished product
- **No undo for individual files** — undo reverses the entire last batch
- Drag-and-drop requires `tkinterdnd2`; if unavailable, use the Browse button
