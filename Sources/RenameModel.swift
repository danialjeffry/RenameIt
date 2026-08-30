import Foundation
import Combine
import SwiftUI
import AppKit

struct FileEntry: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    var newName: String = ""
    var willChange: Bool = true

    static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.id == rhs.id
    }
}

enum CaseMode: String, Equatable, CaseIterable, Codable {
    case none = "None"
    case lowercase = "Lowercase"
    case uppercase = "Uppercase"
}

enum DateSource: String, Equatable, CaseIterable, Codable {
    case fileModified = "File Modified"
    case custom = "Custom"
}

struct RenameSettings: Equatable {
    var findText = ""
    var replaceText = ""
    var useRegex = false
    var prefix = ""
    var suffix = ""
    var enableNumbering = false
    var numberingStart = 1
    var numberingPad = 3
    var caseMode: CaseMode = .none
    var spacesToUnderscores = false
    var newExtension = ""
    var useDate = false
    var dateFormat = "yyyy-MM-dd"
    var dateSource: DateSource = .fileModified
    var customDate = Date()
}

struct RenamePreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var settings: RenameSettings
}

struct UndoEntry: Identifiable {
    let id = UUID()
    let renames: [(from: URL, to: URL)]
    let timestamp: Date
}

@MainActor
final class RenameModel: ObservableObject {
    @Published var files: [FileEntry] = []
    @Published var settings = RenameSettings()
    @Published var lastMessage: String?
    @Published var collisionWarning: [String] = []
    @Published var undoHistory: [UndoEntry] = []
    @Published var presets: [RenamePreset] = []
    @Published var selectedPresetName: String = ""
    @Published var showPresetSaved = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        $settings
            .receive(on: RunLoop.main)
            .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
            .store(in: &cancellables)
        loadPresets()
    }

    func addFiles(_ urls: [URL]) {
        let mainURLs = urls.compactMap { url -> URL? in
            let standardized = url.standardizedFileURL
            guard !files.contains(where: { $0.url == standardized }) else { return nil }
            return standardized
        }
        let newEntries = mainURLs.map { FileEntry(url: $0) }
        files.append(contentsOf: newEntries)
        recompute()
    }

    func removeFile(id: UUID) {
        files.removeAll { $0.id == id }
        recompute()
    }

    func removeFiles(at offsets: IndexSet) {
        files.remove(atOffsets: offsets)
        recompute()
    }

    func moveFile(from source: IndexSet, to destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
        recompute()
    }

    func clearAll() {
        files.removeAll()
        lastMessage = nil
        collisionWarning.removeAll()
        recompute()
    }

    func applyRename() {
        guard !files.isEmpty else { return }
        let toRename = files.filter { $0.willChange }
        guard !toRename.isEmpty else {
            lastMessage = "No files to rename."
            return
        }

        var renamed = 0
        var errors = 0
        var successfulMoves: [(from: URL, to: URL)] = []

        for entry in toRename {
            let newURL = entry.url.deletingLastPathComponent()
                .appendingPathComponent(entry.newName)
            do {
                try FileManager.default.moveItem(at: entry.url, to: newURL)
                successfulMoves.append((from: entry.url, to: newURL))
                renamed += 1
            } catch {
                errors += 1
            }
        }

        if !successfulMoves.isEmpty {
            undoHistory.append(UndoEntry(renames: successfulMoves, timestamp: Date()))
        }

        clearAll()
        if errors == 0 {
            lastMessage = "Renamed \(renamed) file\(renamed == 1 ? "" : "s")."
        } else {
            lastMessage = "Renamed \(renamed), failed \(errors). Check name conflicts."
        }
    }

    func undoLastRename() {
        guard let entry = undoHistory.popLast() else { return }
        var restored = 0
        for (from, to) in entry.renames.reversed() {
            do {
                try FileManager.default.moveItem(at: to, to: from)
                restored += 1
            } catch { }
        }
        lastMessage = "Undone \(restored) rename\(restored == 1 ? "" : "s")."
    }

    func recompute() {
        var newEntries = files
        var seenNames: Set<String> = []
        var index = 0
        var warnings: [String] = []

        for i in newEntries.indices {
            let entry = newEntries[i]
            var name = entry.url.deletingPathExtension().lastPathComponent
            let ext = entry.url.pathExtension
            let s = settings

            if !s.findText.isEmpty {
                if s.useRegex {
                    if let regex = try? NSRegularExpression(pattern: s.findText, options: []) {
                        let range = NSRange(name.startIndex..<name.endIndex, in: name)
                        name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: s.replaceText)
                    }
                } else {
                    name = name.replacingOccurrences(of: s.findText, with: s.replaceText)
                }
            }

            if s.caseMode == .lowercase { name = name.lowercased() }
            if s.caseMode == .uppercase { name = name.uppercased() }
            if s.spacesToUnderscores { name = name.replacingOccurrences(of: " ", with: "_") }

            if s.useDate {
                let formatter = DateFormatter()
                formatter.dateFormat = s.dateFormat
                let sourceDate: Date
                switch s.dateSource {
                case .fileModified:
                    sourceDate = entry.url.modificationDate ?? Date()
                case .custom:
                    sourceDate = s.customDate
                }
                let dateStr = formatter.string(from: sourceDate)
                name = name + "_" + dateStr
            }

            if s.enableNumbering {
                let num = s.numberingStart + index
                let formatted = String(format: "%0*d", max(1, s.numberingPad), num)
                name = name + "_" + formatted
            }

            name = s.prefix + name + s.suffix

            var finalExt = ext
            if !s.newExtension.isEmpty {
                finalExt = s.newExtension.hasPrefix(".") ? String(s.newExtension.dropFirst()) : s.newExtension
            }

            let candidate = finalExt.isEmpty ? name : "\(name).\(finalExt)"
            newEntries[i].newName = candidate
            newEntries[i].willChange = candidate != entry.url.lastPathComponent

            if seenNames.contains(candidate.lowercased()) {
                warnings.append(candidate)
            }
            seenNames.insert(candidate.lowercased())

            index += 1
        }

        files = newEntries
        collisionWarning = warnings
    }

    func savePreset(name: String) {
        let preset = RenamePreset(name: name, settings: settings)
        presets.append(preset)
        savePresets()
        showPresetSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.showPresetSaved = false
        }
    }

    func loadPreset(_ preset: RenamePreset) {
        settings = preset.settings
        selectedPresetName = preset.name
    }

    func deletePreset(_ preset: RenamePreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "RenameIt.presets")
        }
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: "RenameIt.presets"),
              let decoded = try? JSONDecoder().decode([RenamePreset].self, from: data) else { return }
        presets = decoded
    }

    func saveSettingsToDefaults() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "RenameIt.lastSettings")
        }
    }

    func loadSettingsFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: "RenameIt.lastSettings"),
              let decoded = try? JSONDecoder().decode(RenameSettings.self, from: data) else { return }
        settings = decoded
    }
}

extension RenameSettings: Codable {}

extension URL {
    var modificationDate: Date? {
        (try? resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
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

    func binding(_ keyPath: WritableKeyPath<RenameSettings, CaseMode>) -> Binding<CaseMode> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? .none },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }

    func binding(_ keyPath: WritableKeyPath<RenameSettings, DateSource>) -> Binding<DateSource> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? .fileModified },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }

    func binding(_ keyPath: WritableKeyPath<RenameSettings, Date>) -> Binding<Date> {
        Binding(get: { [weak self] in self?.settings[keyPath: keyPath] ?? Date() },
                set: { [weak self] in self?.settings[keyPath: keyPath] = $0 })
    }
}
