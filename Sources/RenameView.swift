import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct RenameView: View {
    @ObservedObject var model: RenameModel
    let closeAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header
            dropZone
            controls
            previewList
            footer
        }
        .padding(14)
        .frame(width: 520, height: 620)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            loadFiles(from: providers)
            return true
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
            }
            Button(role: .destructive, action: closeAction) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            .foregroundColor(.secondary)
            .frame(height: 60)
            .overlay(
                Text(model.files.isEmpty ? "Drop files here to add" : "\(model.files.count) file\(model.files.count == 1 ? "" : "s") added")
                    .foregroundColor(.secondary)
            )
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadFiles(from: providers)
                return true
            }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                groupBox("Find & Replace") {
                    HStack {
                        TextField("Find", text: model.binding(\.findText))
                        TextField("Replace", text: model.binding(\.replaceText))
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
                            TextField("Start", value: model.binding(\.numberingStart), format: .number)
                                .frame(width: 60)
                            Text("Pad")
                            Picker("", selection: model.binding(\.numberingPad)) {
                                ForEach([1, 2, 3, 4], id: \.self) { Text("\($0)") }
                            }
                            .frame(width: 70)
                        }
                    }
                }

                groupBox("Case & Whitespace") {
                    Toggle("Lowercase", isOn: model.binding(\.lowercase))
                    Toggle("Uppercase", isOn: model.binding(\.uppercase))
                    Toggle("Replace spaces with underscores", isOn: model.binding(\.spacesToUnderscores))
                }

                groupBox("Extension") {
                    TextField("New extension (optional)", text: model.binding(\.newExtension))
                }
            }
        }
        .frame(height: 220)
    }

    private func groupBox<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(.secondary)
            content()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
    }

    private var previewList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(Array(model.files.enumerated()), id: \.element.id) { _, entry in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(.secondary)
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
            Button("Apply Rename") { model.applyRename() }
                .buttonStyle(.borderedProminent)
                .disabled(model.files.isEmpty)
        }
    }

    private func loadFiles(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            Task { @MainActor in
                self.model.addFiles(urls)
            }
        }
    }
}
