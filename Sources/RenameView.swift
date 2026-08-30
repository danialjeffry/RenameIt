import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RenameView: View {
    @ObservedObject var model: RenameModel
    let closeAction: () -> Void

    @State private var showConfirm = false
    @State private var showPresetSave = false
    @State private var presetName = ""
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 10) {
            header
            dropZone
            controls
            if !model.collisionWarning.isEmpty {
                collisionBanner
            }
            previewList
            footer
        }
        .padding(14)
        .frame(width: 540, height: 900)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadFiles(from: providers)
            return true
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                model.addFiles([url])
            }
        }
        .confirmationDialog(
            "Rename \(model.files.filter { $0.willChange }.count) file\(model.files.filter { $0.willChange }.count == 1 ? "" : "s")?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Rename", role: .destructive) { model.applyRename() }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "character.cursor.ibeam")
                .font(.title2)
            Text("RenameIt")
                .font(.title3.bold())
            Spacer()
            if let msg = model.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            if model.showPresetSaved {
                Text("Preset saved!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            Button(role: .destructive, action: closeAction) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .animation(.easeInOut(duration: 0.3), value: model.lastMessage)
    }

    private var dropZone: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundColor(.secondary)
                .frame(height: 50)
                .overlay(
                    HStack {
                        Image(systemName: "arrow.down.doc")
                            .foregroundColor(.secondary)
                        Text(model.files.isEmpty ? "Drop files here" : "\(model.files.count) file\(model.files.count == 1 ? "" : "s")")
                            .foregroundColor(.secondary)
                    }
                )
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    loadFiles(from: providers)
                    return true
                }

            Button {
                showFilePicker = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .help("Open file picker")
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                groupBox("Find & Replace") {
                    VStack(spacing: 6) {
                        HStack {
                            TextField("Find", text: model.binding(\.findText))
                            TextField("Replace", text: model.binding(\.replaceText))
                        }
                        Toggle("Use Regex", isOn: model.binding(\.useRegex))
                            .font(.caption)
                    }
                }

                groupBox("Prefix / Suffix") {
                    HStack {
                        TextField("Prefix", text: model.binding(\.prefix))
                        TextField("Suffix", text: model.binding(\.suffix))
                    }
                }

                groupBox("Auto-numbering") {
                    Toggle("Add sequence number", isOn: model.binding(\.enableNumbering))
                    if model.settings.enableNumbering {
                        HStack {
                            Text("Start")
                            TextField("1", value: model.binding(\.numberingStart), format: .number)
                                .frame(width: 50)
                            Text("Pad")
                            Picker("", selection: model.binding(\.numberingPad)) {
                                ForEach([1, 2, 3, 4], id: \.self) { Text("\($0)") }
                            }
                            .frame(width: 70)
                        }
                    }
                }

                groupBox("Case & Whitespace") {
                    Picker("Case", selection: model.binding(\.caseMode)) {
                        ForEach(CaseMode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Replace spaces with underscores", isOn: model.binding(\.spacesToUnderscores))
                }

                groupBox("Extension") {
                    TextField("New extension (optional)", text: model.binding(\.newExtension))
                }

                groupBox("Date") {
                    Toggle("Append date", isOn: model.binding(\.useDate))
                    if model.settings.useDate {
                        Picker("Date source", selection: model.binding(\.dateSource)) {
                            ForEach(DateSource.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        .pickerStyle(.segmented)

                        if model.settings.dateSource == .custom {
                            DatePicker("Pick date", selection: model.binding(\.customDate), displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        let dateFormats: [(String, String)] = [
                            ("2026-08-30", "yyyy-MM-dd"),
                            ("08-30-2026", "MM-dd-yyyy"),
                            ("30-08-2026", "dd-MM-yyyy"),
                            ("20260830", "yyyyMMdd"),
                            ("Aug 30, 2026", "MMM d, yyyy"),
                            ("2026-08-30 14-30", "yyyy-MM-dd HH-mm"),
                        ]
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(dateFormats, id: \.1) { example, format in
                                    Button {
                                        model.settings.dateFormat = format
                                    } label: {
                                        VStack(spacing: 2) {
                                            Text(example)
                                                .font(.caption2)
                                                .foregroundColor(model.settings.dateFormat == format ? .white : .primary)
                                            Text(format)
                                                .font(.system(size: 9))
                                                .foregroundColor(model.settings.dateFormat == format ? .white : .secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(model.settings.dateFormat == format ? Color.accentColor : Color.gray.opacity(0.15))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        TextField("Custom format (yyyy-MM-dd)", text: model.binding(\.dateFormat))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }

                presetsSection
            }
            .padding(.vertical, 4)
        }
        .frame(height: 500)
    }

    private var presetsSection: some View {
        groupBox("Presets") {
            VStack(spacing: 6) {
                HStack {
                    Picker("Load preset", selection: $model.selectedPresetName) {
                        Text("-- none --").tag("")
                        ForEach(model.presets) { preset in
                            Text(preset.name).tag(preset.name)
                        }
                    }
                    .onChange(of: model.selectedPresetName) { _, newVal in
                        if let preset = model.presets.first(where: { $0.name == newVal }) {
                            model.loadPreset(preset)
                        }
                    }

                    Button {
                        showPresetSave = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .help("Save current settings as preset")
                    .sheet(isPresented: $showPresetSave) {
                        VStack(spacing: 12) {
                            Text("Save Preset").font(.headline)
                            TextField("Preset name", text: $presetName)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                Button("Cancel") { showPresetSave = false; presetName = "" }
                                Button("Save") {
                                    guard !presetName.isEmpty else { return }
                                    model.savePreset(name: presetName)
                                    showPresetSave = false
                                    presetName = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(presetName.isEmpty)
                            }
                        }
                        .padding(20)
                        .frame(width: 300)
                    }

                    if !model.presets.isEmpty {
                        Menu {
                            ForEach(model.presets) { preset in
                                Button(role: .destructive) {
                                    model.deletePreset(preset)
                                    if model.selectedPresetName == preset.name {
                                        model.selectedPresetName = ""
                                    }
                                } label: {
                                    Label("Delete \(preset.name)", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Delete a preset")
                    }
                }
            }
        }
    }

    private var collisionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("\(model.collisionWarning.count) duplicate name\(model.collisionWarning.count == 1 ? "" : "s") detected")
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }

    private var previewList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(model.files.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 6) {
                        Image(systemName: iconForExtension(entry.url.pathExtension))
                            .foregroundColor(.secondary)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .strikethrough(entry.willChange)
                            if entry.willChange {
                                Text(entry.newName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                            }
                        }

                        Spacer()

                        if index > 0 {
                            Button {
                                if let idx = model.files.firstIndex(where: { $0.id == entry.id }) {
                                    model.moveFile(from: IndexSet(integer: idx), to: idx - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                        }
                        if index < model.files.count - 1 {
                            Button {
                                if let idx = model.files.firstIndex(where: { $0.id == entry.id }) {
                                    model.moveFile(from: IndexSet(integer: idx), to: idx + 2)
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderless)
                        }

                        Button {
                            model.removeFile(id: entry.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.6))
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(entry.willChange ? Color.yellow.opacity(0.12) : Color.clear)
                    .cornerRadius(4)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Clear") { model.clearAll() }
                .disabled(model.files.isEmpty)

            Spacer()

            if !model.undoHistory.isEmpty {
                Button {
                    model.undoLastRename()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .help("Undo last rename")
                }
                .buttonStyle(.borderless)
            }

            Button("Apply Rename") { showConfirm = true }
                .buttonStyle(.borderedProminent)
                .disabled(model.files.isEmpty || model.files.allSatisfy { !$0.willChange })
        }
    }

    private func iconForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "film"
        case "mp3", "wav", "m4a", "flac", "aac":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "zip", "tar", "gz":
            return "archivebox"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        case "xlsx", "csv":
            return "tablecells"
        case "pptx", "key":
            return "chart.bar"
        case "doc", "docx", "pages":
            return "doc.text"
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "m":
            return "chevron.left.forwardslash.chevron.right"
        case "app", "dmg":
            return "app.fill"
        default:
            return "doc"
        }
    }

    private func loadFiles(from providers: [NSItemProvider]) {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) {
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    } else if let url = item as? URL {
                        urls.append(url)
                    }
                }
            }
            model.addFiles(urls)
        }
    }

    private func groupBox<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            content()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
    }
}
