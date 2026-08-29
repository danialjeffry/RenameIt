import Foundation
import Combine
import SwiftUI

struct FileEntry: Identifiable {
    let id = UUID()
    let url: URL
    var newName: String = ""
    var willChange: Bool = true
}

struct RenameSettings: Equatable {
    var findText = ""
    var replaceText = ""
    var prefix = ""
    var suffix = ""
    var enableNumbering = false
    var numberingStart = 1
    var numberingPad = 3
    var lowercase = false
    var uppercase = false
    var spacesToUnderscores = false
    var newExtension = ""
}

@MainActor
final class RenameModel: ObservableObject {
    @Published var files: [FileEntry] = []
    @Published var settings = RenameSettings()
    @Published var lastMessage: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        $settings
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        $files
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
    }

    func addFiles(_ urls: [URL]) {
        for url in urls {
            guard let url = standardized(url) else { continue }
            guard !files.contains(where: { $0.url == url }) else { continue }
            files.append(FileEntry(url: url))
        }
        recompute()
    }

    func removeFiles(at offsets: IndexSet) {
        files.remove(atOffsets: offsets)
        recompute()
    }

    func clearAll() {
        files.removeAll()
        lastMessage = nil
        recompute()
    }

    func applyRename() {
        guard !files.isEmpty else { return }
        var renamed = 0
        var errors = 0
        for entry in files {
            guard entry.willChange else { continue }
            let newURL = entry.url.deletingLastPathComponent()
                .appendingPathComponent(entry.newName)
            do {
                try FileManager.default.moveItem(at: entry.url, to: newURL)
                renamed += 1
            } catch {
                errors += 1
            }
        }
        clearAll()
        if errors == 0 {
            lastMessage = "Renamed \(renamed) file\(renamed == 1 ? "" : "s")."
        } else {
            lastMessage = "Renamed \(renamed), failed \(errors). Check for name conflicts."
        }
    }

    func recompute() {
        var index = 0
        for i in files.indices {
            let entry = files[i]
            var name = entry.url.deletingPathExtension().lastPathComponent
            let ext = entry.url.pathExtension
            let s = settings

            if !s.findText.isEmpty {
                name = name.replacingOccurrences(of: s.findText, with: s.replaceText)
            }

            if s.lowercase { name = name.lowercased() }
            if s.uppercase { name = name.uppercased() }
            if s.spacesToUnderscores { name = name.replacingOccurrences(of: " ", with: "_") }

            if s.enableNumbering {
                let num = s.numberingStart + index
                let formatted = String(format: "%0\(max(1, s.numberingPad))d", num)
                name = name + String(format: "_%@", formatted)
            }

            name = s.prefix + name + s.suffix

            var finalExt = ext
            if !s.newExtension.isEmpty {
                finalExt = s.newExtension.hasPrefix(".") ? String(s.newExtension.dropFirst()) : s.newExtension
            }

            let candidate = finalExt.isEmpty ? name : "\(name).\(finalExt)"
            files[i].newName = candidate
            files[i].willChange = candidate != entry.url.lastPathComponent
            index += 1
        }
    }

    private func standardized(_ url: URL) -> URL? {
        url.standardizedFileURL
    }
}

extension RenameModel {
    func binding(_ keyPath: WritableKeyPath<RenameSettings, String>) -> Binding<String> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? "" },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }

    func binding(_ keyPath: WritableKeyPath<RenameSettings, Bool>) -> Binding<Bool> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? false },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }

    func binding(_ keyPath: WritableKeyPath<RenameSettings, Int>) -> Binding<Int> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? 0 },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }
}
