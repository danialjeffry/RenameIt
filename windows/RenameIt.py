import os
import re
import json
import shutil
import customtkinter as ctk
from tkinter import filedialog, messagebox
from datetime import datetime
from pathlib import Path

try:
    from tkinterdnd2 import DND_FILES, TkinterDnD
    HAS_DND = True
except ImportError:
    HAS_DND = False

ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

PRESETS_FILE = Path.home() / ".renameit_presets.json"


class FileEntry:
    def __init__(self, path: str):
        self.path = path
        self.new_name = ""
        self.will_change = True


class RenameItApp(ctk.CTk if HAS_DND else ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("RenameIt")
        self.geometry("600x820")
        self.minsize(500, 650)
        self.protocol("WM_DELETE_WINDOW", self.on_close)

        self.files: list[FileEntry] = []
        self.undo_history: list[list[tuple[str, str]]] = []
        self.presets: list[dict] = []
        self.collision_warnings: list[str] = []

        self.load_presets()
        self.build_ui()
        self.refresh_preview()

    def build_ui(self):
        main = ctk.CTkFrame(self, fg_color="transparent")
        main.pack(fill="both", expand=True, padx=12, pady=12)

        self.build_header(main)
        self.build_drop_zone(main)
        self.build_controls(main)
        self.build_preview(main)
        self.build_footer(main)

    def build_header(self, parent):
        frame = ctk.CTkFrame(parent, fg_color="transparent")
        frame.pack(fill="x", pady=(0, 8))

        ctk.CTkLabel(frame, text="✏ RenameIt", font=ctk.CTkFont(size=20, weight="bold")).pack(side="left")
        self.status_label = ctk.CTkLabel(frame, text="", font=ctk.CTkFont(size=12), text_color="gray")
        self.status_label.pack(side="right")

    def build_drop_zone(self, parent):
        self.drop_frame = ctk.CTkFrame(parent, fg_color=("gray90", "gray20"), border_width=2, border_color=("gray60", "gray40"))
        self.drop_frame.pack(fill="x", pady=(0, 8))

        self.drop_label = ctk.CTkLabel(self.drop_frame, text="📎 Drop files here or click to browse",
                                        font=ctk.CTkFont(size=13), text_color="gray50")
        self.drop_label.pack(pady=20)

        self.drop_frame.bind("<Button-1>", lambda e: self.browse_files())
        self.drop_label.bind("<Button-1>", lambda e: self.browse_files())

        if HAS_DND:
            self.drop_frame.drop_target_register(DND_FILES)
            self.drop_frame.dnd_bind("<<Drop>>", self.on_drop)

        btn_frame = ctk.CTkFrame(self.drop_frame, fg_color="transparent")
        btn_frame.pack(pady=(0, 10))
        ctk.CTkButton(btn_frame, text="+ Add Files", width=100, command=self.browse_files).pack(side="left", padx=4)
        ctk.CTkButton(btn_frame, text="🗑 Clear All", width=100, fg_color="#dc3545", hover_color="#c82333",
                       command=self.clear_all).pack(side="left", padx=4)

    def build_controls(self, parent):
        scroll = ctk.CTkScrollableFrame(parent, fg_color="transparent", height=380)
        scroll.pack(fill="x", pady=(0, 8))

        self.build_find_replace(scroll)
        self.build_prefix_suffix(scroll)
        self.build_numbering(scroll)
        self.build_case(scroll)
        self.build_extension(scroll)
        self.build_date(scroll)
        self.build_presets(scroll)

    def build_find_replace(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Find & Replace", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        row = ctk.CTkFrame(frame, fg_color="transparent")
        row.pack(fill="x", padx=8, pady=(0, 4))
        self.find_entry = ctk.CTkEntry(row, placeholder_text="Find", width=250)
        self.find_entry.pack(side="left", padx=(0, 4), expand=True, fill="x")
        self.replace_entry = ctk.CTkEntry(row, placeholder_text="Replace", width=250)
        self.replace_entry.pack(side="left", expand=True, fill="x")

        self.regex_var = ctk.BooleanVar(value=False)
        ctk.CTkCheckBox(frame, text="Use Regex", variable=self.regex_var, font=ctk.CTkFont(size=11)).pack(anchor="w", padx=8, pady=(0, 8))

        self.find_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())
        self.replace_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())
        self.regex_var.trace_add("write", lambda *a: self.refresh_preview())

    def build_prefix_suffix(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Prefix / Suffix", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        row = ctk.CTkFrame(frame, fg_color="transparent")
        row.pack(fill="x", padx=8, pady=(0, 8))
        self.prefix_entry = ctk.CTkEntry(row, placeholder_text="Prefix", width=250)
        self.prefix_entry.pack(side="left", padx=(0, 4), expand=True, fill="x")
        self.suffix_entry = ctk.CTkEntry(row, placeholder_text="Suffix", width=250)
        self.suffix_entry.pack(side="left", expand=True, fill="x")

        self.prefix_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())
        self.suffix_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())

    def build_numbering(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Auto-numbering", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        self.numbering_var = ctk.BooleanVar(value=False)
        ctk.CTkCheckBox(frame, text="Add sequence number", variable=self.numbering_var,
                        command=self.refresh_preview, font=ctk.CTkFont(size=11)).pack(anchor="w", padx=8, pady=(0, 4))

        opts = ctk.CTkFrame(frame, fg_color="transparent")
        opts.pack(fill="x", padx=8, pady=(0, 8))

        ctk.CTkLabel(opts, text="Start").pack(side="left")
        self.start_var = ctk.StringVar(value="1")
        self.start_entry = ctk.CTkEntry(opts, textvariable=self.start_var, width=50)
        self.start_entry.pack(side="left", padx=(4, 12))
        self.start_var.trace_add("write", lambda *a: self.refresh_preview())

        ctk.CTkLabel(opts, text="Pad").pack(side="left")
        self.pad_var = ctk.StringVar(value="3")
        self.pad_menu = ctk.CTkOptionMenu(opts, variable=self.pad_var, values=["1", "2", "3", "4"],
                                           width=60, command=lambda *a: self.refresh_preview())
        self.pad_menu.pack(side="left", padx=(4, 0))

        self.numbering_var.trace_add("write", lambda *a: self.refresh_preview())

    def build_case(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Case & Whitespace", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        self.case_var = ctk.StringVar(value="None")
        case_frame = ctk.CTkFrame(frame, fg_color="transparent")
        case_frame.pack(fill="x", padx=8, pady=(0, 4))
        for val in ["None", "Lowercase", "Uppercase"]:
            ctk.CTkRadioButton(case_frame, text=val, variable=self.case_var, value=val,
                               command=self.refresh_preview, font=ctk.CTkFont(size=11)).pack(side="left", padx=(0, 12))

        self.underscore_var = ctk.BooleanVar(value=False)
        ctk.CTkCheckBox(frame, text="Replace spaces with underscores", variable=self.underscore_var,
                        command=self.refresh_preview, font=ctk.CTkFont(size=11)).pack(anchor="w", padx=8, pady=(0, 8))

    def build_extension(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Extension", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))
        self.ext_entry = ctk.CTkEntry(frame, placeholder_text="New extension (optional)")
        self.ext_entry.pack(fill="x", padx=8, pady=(0, 8))
        self.ext_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())

    def build_date(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Date", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        self.date_var = ctk.BooleanVar(value=False)
        ctk.CTkCheckBox(frame, text="Append date", variable=self.date_var,
                        command=self.toggle_date_options, font=ctk.CTkFont(size=11)).pack(anchor="w", padx=8, pady=(0, 4))

        self.date_options_frame = ctk.CTkFrame(frame, fg_color="transparent")

        src_frame = ctk.CTkFrame(self.date_options_frame, fg_color="transparent")
        src_frame.pack(fill="x", padx=8, pady=(0, 4))
        ctk.CTkLabel(src_frame, text="Source:").pack(side="left")
        self.date_source_var = ctk.StringVar(value="File Modified")
        for val in ["File Modified", "Custom"]:
            ctk.CTkRadioButton(src_frame, text=val, variable=self.date_source_var, value=val,
                               command=self.toggle_date_options, font=ctk.CTkFont(size=11)).pack(side="left", padx=(8, 0))

        self.custom_date_frame = ctk.CTkFrame(self.date_options_frame, fg_color="transparent")
        ctk.CTkLabel(self.custom_date_frame, text="Pick date:").pack(side="left")
        self.custom_date_entry = ctk.CTkEntry(self.custom_date_frame, placeholder_text="YYYY-MM-DD", width=120)
        self.custom_date_entry.pack(side="left", padx=(4, 0))
        self.custom_date_entry.insert(0, datetime.now().strftime("%Y-%m-%d"))

        fmt_frame = ctk.CTkFrame(self.date_options_frame, fg_color="transparent")
        fmt_frame.pack(fill="x", padx=8, pady=(4, 4))
        ctk.CTkLabel(fmt_frame, text="Format:").pack(side="left")

        date_formats = [
            ("2026-08-30", "yyyy-MM-dd"),
            ("08-30-2026", "MM-dd-yyyy"),
            ("30-08-2026", "dd-MM-yyyy"),
            ("20260830", "yyyyMMdd"),
            ("Aug 30, 2026", "MMM d, yyyy"),
        ]
        self.fmt_var = ctk.StringVar(value="yyyy-MM-dd")
        for example, fmt in date_formats:
            ctk.CTkRadioButton(fmt_frame, text=example, variable=self.fmt_var, value=fmt,
                               command=self.refresh_preview, font=ctk.CTkFont(size=10)).pack(side="left", padx=(6, 0))

        self.fmt_entry = ctk.CTkEntry(self.date_options_frame, placeholder_text="Custom format", width=150)
        self.fmt_entry.pack(fill="x", padx=8, pady=(0, 8))
        self.fmt_entry.insert(0, "yyyy-MM-dd")
        self.fmt_entry.bind("<KeyRelease>", lambda e: self.refresh_preview())

        self.date_var.trace_add("write", lambda *a: self.toggle_date_options())
        self.date_source_var.trace_add("write", lambda *a: self.toggle_date_options())

    def toggle_date_options(self):
        if self.date_var.get():
            self.date_options_frame.pack(fill="x", padx=8, pady=(0, 8))
            if self.date_source_var.get() == "Custom":
                self.custom_date_frame.pack(fill="x", padx=8, pady=(0, 4))
            else:
                self.custom_date_frame.pack_forget()
        else:
            self.date_options_frame.pack_forget()
        self.refresh_preview()

    def build_presets(self, parent):
        frame = ctk.CTkFrame(parent)
        frame.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(frame, text="Presets", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", padx=8, pady=(8, 4))

        row = ctk.CTkFrame(frame, fg_color="transparent")
        row.pack(fill="x", padx=8, pady=(0, 8))

        preset_names = [p["name"] for p in self.presets] if self.presets else ["-- none --"]
        self.preset_var = ctk.StringVar(value=preset_names[0])
        self.preset_menu = ctk.CTkOptionMenu(row, variable=self.preset_var, values=preset_names,
                                              width=200, command=self.load_selected_preset)
        self.preset_menu.pack(side="left")

        ctk.CTkButton(row, text="💾 Save", width=70, command=self.save_preset_dialog).pack(side="left", padx=4)
        ctk.CTkButton(row, text="🗑 Delete", width=70, fg_color="#dc3545", hover_color="#c82333",
                       command=self.delete_selected_preset).pack(side="left", padx=4)

    def build_preview(self, parent):
        ctk.CTkLabel(parent, text="Preview", font=ctk.CTkFont(size=12, weight="bold")).pack(anchor="w", pady=(0, 4))

        self.preview_frame = ctk.CTkScrollableFrame(parent, fg_color=("gray95", "gray15"), height=150)
        self.preview_frame.pack(fill="both", expand=True, pady=(0, 8))

        self.collision_label = ctk.CTkLabel(parent, text="", font=ctk.CTkFont(size=11), text_color="orange")
        self.collision_label.pack(anchor="w", pady=(0, 4))

    def build_footer(self, parent):
        frame = ctk.CTkFrame(parent, fg_color="transparent")
        frame.pack(fill="x")

        ctk.CTkButton(frame, text="Undo", width=70, command=self.undo_last).pack(side="left")
        ctk.CTkButton(frame, text="Apply Rename", width=130, fg_color="#28a745", hover_color="#218838",
                       command=self.apply_rename).pack(side="right")

    # ─── Core Logic ───────────────────────────────────────────────

    def on_drop(self, event):
        paths = self.tk.splitlist(event.data)
        self.add_files(paths)

    def browse_files(self):
        paths = filedialog.askopenfilenames(title="Select files")
        if paths:
            self.add_files(paths)

    def add_files(self, paths):
        for p in paths:
            p = os.path.normpath(p)
            if os.path.isfile(p) and not any(f.path == p for f in self.files):
                self.files.append(FileEntry(p))
        self.refresh_preview()

    def clear_all(self):
        self.files.clear()
        self.refresh_preview()

    def remove_file(self, idx):
        if 0 <= idx < len(self.files):
            self.files.pop(idx)
            self.refresh_preview()

    def move_file(self, idx, direction):
        new_idx = idx + direction
        if 0 <= new_idx < len(self.files):
            self.files[idx], self.files[new_idx] = self.files[new_idx], self.files[idx]
            self.refresh_preview()

    def get_settings(self):
        fmt = self.fmt_entry.get().strip() or "yyyy-MM-dd"
        try:
            start = int(self.start_var.get())
        except ValueError:
            start = 1
        try:
            pad = int(self.pad_var.get())
        except ValueError:
            pad = 3

        return {
            "find": self.find_entry.get(),
            "replace": self.replace_entry.get(),
            "regex": self.regex_var.get(),
            "prefix": self.prefix_entry.get(),
            "suffix": self.suffix_entry.get(),
            "numbering": self.numbering_var.get(),
            "start": start,
            "pad": pad,
            "case": self.case_var.get(),
            "underscores": self.underscore_var.get(),
            "ext": self.ext_entry.get().strip(),
            "use_date": self.date_var.get(),
            "date_source": self.date_source_var.get(),
            "custom_date": self.custom_date_entry.get().strip(),
            "fmt": fmt,
        }

    def compute_new_name(self, entry: FileEntry, s: dict) -> str:
        p = Path(entry.path)
        name = p.stem
        ext = p.suffix.lstrip(".")

        if s["find"]:
            if s["regex"]:
                try:
                    name = re.sub(s["find"], s["replace"], name)
                except re.error:
                    pass
            else:
                name = name.replace(s["find"], s["replace"])

        if s["case"] == "Lowercase":
            name = name.lower()
        elif s["case"] == "Uppercase":
            name = name.upper()

        if s["underscores"]:
            name = name.replace(" ", "_")

        if s["use_date"]:
            fmt_py = self.swift_to_python_fmt(s["fmt"])
            if s["date_source"] == "Custom":
                try:
                    dt = datetime.strptime(s["custom_date"], "%Y-%m-%d")
                except ValueError:
                    dt = datetime.now()
            else:
                mtime = os.path.getmtime(entry.path)
                dt = datetime.fromtimestamp(mtime)
            name = name + "_" + dt.strftime(fmt_py)

        if s["numbering"]:
            idx = self.files.index(entry)
            num = s["start"] + idx
            name = f"{name}_{str(num).zfill(max(1, s['pad']))}"

        name = s["prefix"] + name + s["suffix"]

        final_ext = ext
        if s["ext"]:
            final_ext = s["ext"].lstrip(".")

        return f"{name}.{final_ext}" if final_ext else name

    def swift_to_python_fmt(self, swift_fmt: str) -> str:
        mapping = {
            "yyyy": "%Y", "yy": "%y",
            "MM": "%m", "dd": "%d",
            "HH": "%H", "mm": "%M", "ss": "%S",
            "MMM": "%b", "MMMM": "%B",
        }
        result = swift_fmt
        for k, v in sorted(mapping.items(), key=lambda x: -len(x[0])):
            result = result.replace(k, v)
        return result

    def refresh_preview(self):
        for w in self.preview_frame.winfo_children():
            w.destroy()

        s = self.get_settings()
        seen = set()
        self.collision_warnings.clear()

        for i, entry in enumerate(self.files):
            new_name = self.compute_new_name(entry, s)
            entry.new_name = new_name
            entry.will_change = new_name != Path(entry.path).name

            if new_name.lower() in seen:
                self.collision_warnings.append(new_name)
            seen.add(new_name.lower())

            row = ctk.CTkFrame(self.preview_frame, fg_color="transparent")
            row.pack(fill="x", pady=1)

            icon = self.get_icon(entry.path)
            ctk.CTkLabel(row, text=icon, width=24, font=ctk.CTkFont(size=14)).pack(side="left")

            names = ctk.CTkFrame(row, fg_color="transparent")
            names.pack(side="left", fill="x", expand=True)

            orig = Path(entry.path).name
            if entry.will_change:
                ctk.CTkLabel(names, text=orig, font=ctk.CTkFont(size=11),
                             text_color="gray60").pack(anchor="w")
                ctk.CTkLabel(names, text=new_name, font=ctk.CTkFont(size=11, weight="bold")).pack(anchor="w")
            else:
                ctk.CTkLabel(names, text=orig, font=ctk.CTkFont(size=11)).pack(anchor="w")

            btn_frame = ctk.CTkFrame(row, fg_color="transparent", width=60)
            btn_frame.pack(side="right")

            ctk.CTkButton(btn_frame, text="▲", width=24, height=20, font=ctk.CTkFont(size=10),
                           fg_color="transparent", hover_color=("gray80", "gray30"),
                           command=lambda idx=i: self.move_file(idx, -1)).pack(side="left", padx=1)
            ctk.CTkButton(btn_frame, text="▼", width=24, height=20, font=ctk.CTkFont(size=10),
                           fg_color="transparent", hover_color=("gray80", "gray30"),
                           command=lambda idx=i: self.move_file(idx, 1)).pack(side="left", padx=1)
            ctk.CTkButton(btn_frame, text="✕", width=24, height=20, font=ctk.CTkFont(size=10),
                           fg_color="transparent", hover_color="#dc3545",
                           command=lambda idx=i: self.remove_file(idx)).pack(side="left", padx=1)

        if self.collision_warnings:
            self.collision_label.configure(text=f"⚠ {len(self.collision_warnings)} duplicate name(s) detected")
        else:
            self.collision_label.configure(text="")

        count = sum(1 for f in self.files if f.will_change)
        self.status_label.configure(text=f"{len(self.files)} file(s), {count} to rename")

    def get_icon(self, path: str) -> str:
        ext = Path(path).suffix.lower()
        icons = {
            ".jpg": "🖼", ".jpeg": "🖼", ".png": "🖼", ".gif": "🖼", ".heic": "🖼", ".webp": "🖼",
            ".mp4": "🎬", ".mov": "🎬", ".avi": "🎬", ".mkv": "🎬",
            ".mp3": "🎵", ".wav": "🎵", ".m4a": "🎵", ".flac": "🎵",
            ".pdf": "📄", ".txt": "📝", ".md": "📝",
            ".xlsx": "📊", ".csv": "📊", ".pptx": "📊",
            ".zip": "📦", ".dmg": "📦", ".tar": "📦",
            ".swift": "💻", ".py": "💻", ".js": "💻", ".ts": "💻",
            ".app": "⚙", ".exe": "⚙",
        }
        return icons.get(ext, "📄")

    def apply_rename(self):
        to_rename = [f for f in self.files if f.will_change]
        if not to_rename:
            messagebox.showinfo("RenameIt", "No files to rename.")
            return

        if not messagebox.askyesno("Confirm Rename", f"Rename {len(to_rename)} file(s)?"):
            return

        undo_batch = []
        renamed = 0
        errors = 0

        for entry in to_rename:
            new_path = os.path.join(os.path.dirname(entry.path), entry.new_name)
            try:
                os.rename(entry.path, new_path)
                undo_batch.append((entry.path, new_path))
                renamed += 1
            except Exception:
                errors += 1

        if undo_batch:
            self.undo_history.append(undo_batch)

        self.files.clear()
        self.refresh_preview()

        if errors == 0:
            self.status_label.configure(text=f"Renamed {renamed} file(s).")
        else:
            self.status_label.configure(text=f"Renamed {renamed}, failed {errors}.")

    def undo_last(self):
        if not self.undo_history:
            return
        batch = self.undo_history.pop()
        restored = 0
        for old_path, new_path in reversed(batch):
            try:
                os.rename(new_path, old_path)
                restored += 1
            except Exception:
                pass
        self.status_label.configure(text=f"Undone {restored} rename(s).")

    # ─── Presets ──────────────────────────────────────────────────

    def load_presets(self):
        if PRESETS_FILE.exists():
            try:
                self.presets = json.loads(PRESETS_FILE.read_text())
            except Exception:
                self.presets = []

    def save_presets_to_file(self):
        PRESETS_FILE.write_text(json.dumps(self.presets, indent=2))

    def save_preset_dialog(self):
        name = ctk.CTkInputDialog(text="Enter preset name:", title="Save Preset").get_input()
        if not name:
            return
        s = self.get_settings()
        self.presets.append({"name": name, "settings": s})
        self.save_presets_to_file()
        self.preset_menu.configure(values=[p["name"] for p in self.presets])
        self.status_label.configure(text=f"Preset '{name}' saved.")

    def load_selected_preset(self, name):
        for p in self.presets:
            if p["name"] == name:
                s = p["settings"]
                self.find_entry.delete(0, "end")
                self.find_entry.insert(0, s.get("find", ""))
                self.replace_entry.delete(0, "end")
                self.replace_entry.insert(0, s.get("replace", ""))
                self.regex_var.set(s.get("regex", False))
                self.prefix_entry.delete(0, "end")
                self.prefix_entry.insert(0, s.get("prefix", ""))
                self.suffix_entry.delete(0, "end")
                self.suffix_entry.insert(0, s.get("suffix", ""))
                self.numbering_var.set(s.get("numbering", False))
                self.start_var.set(str(s.get("start", 1)))
                self.pad_var.set(str(s.get("pad", 3)))
                self.case_var.set(s.get("case", "None"))
                self.underscore_var.set(s.get("underscores", False))
                self.ext_entry.delete(0, "end")
                self.ext_entry.insert(0, s.get("ext", ""))
                self.date_var.set(s.get("use_date", False))
                self.date_source_var.set(s.get("date_source", "File Modified"))
                self.custom_date_entry.delete(0, "end")
                self.custom_date_entry.insert(0, s.get("custom_date", datetime.now().strftime("%Y-%m-%d")))
                self.fmt_entry.delete(0, "end")
                self.fmt_entry.insert(0, s.get("fmt", "yyyy-MM-dd"))
                self.fmt_var.set(s.get("fmt", "yyyy-MM-dd"))
                self.toggle_date_options()
                self.refresh_preview()
                break

    def delete_selected_preset(self):
        name = self.preset_var.get()
        if name == "-- none --":
            return
        self.presets = [p for p in self.presets if p["name"] != name]
        self.save_presets_to_file()
        names = [p["name"] for p in self.presets] if self.presets else ["-- none --"]
        self.preset_menu.configure(values=names)
        self.preset_var.set(names[0])
        self.status_label.configure(text=f"Preset '{name}' deleted.")

    def on_close(self):
        self.destroy()


if __name__ == "__main__":
    app = RenameItApp()
    app.mainloop()
