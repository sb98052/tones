//
//  Exercises.swift
//  Perfect Practice
//
//  JSON-driven exercise system with pluggable atoms
//

import Foundation
import Combine

// MARK: - Exercise Display Types

struct ExerciseLine {
    let label: String
    let value: String
    let emphasis: Bool
}

struct Exercise {
    let typeName: String
    let symbol: String
    let titleSuffix: String
    let displayLines: [ExerciseLine]
    let solfegeNotes: [String]
    let startNoteIndex: Int?
    let playstyle: String  // "arpeggio" or "chord"
}

// MARK: - Atom Parameters

struct AtomParams {
    var maxPosition: Int = 5
    var multiselect: [[String]] = []
}

// MARK: - Atom Generators

// Each atom generates one or more ExerciseLines when invoked
enum Atom: String {
    case position
    case position2
    case permutations
    case updown
    case down
    case multiselect
    case notes

    private static let ordinals = ["First", "Second", "Third", "Fourth", "Fifth"]

    func generate(params: AtomParams = AtomParams(), used: inout Set<[String]>) -> [ExerciseLine] {
        switch self {
        case .position:
            let pos = Int.random(in: 1...params.maxPosition)
            return [ExerciseLine(label: "Position", value: "\(pos)", emphasis: true)]

        case .permutations:
            let threePerms = [
                [1, 2, 3], [1, 3, 2], [2, 1, 3],
                [2, 3, 1], [3, 1, 2], [3, 2, 1]
            ]
            let twoPerms = [[1, 2], [2, 1]]
            let fmt = { (a: [Int]) in a.map(String.init).joined(separator: " ") }

            let pattern = fmt(threePerms.randomElement()!) + ", " + fmt(twoPerms.randomElement()!)

            return [
                ExerciseLine(label: "Pattern", value: pattern, emphasis: false),
            ]

        case .updown:
            let patterns = ["Up Up", "Down Down", "Up Down", "Down Up"]
            return [ExerciseLine(label: "_suffix", value: patterns.randomElement()!, emphasis: false)]

        case .down:
            let direction = Bool.random() ? "Down" : "Up"
            return [ExerciseLine(label: "_suffix", value: direction, emphasis: false)]

        case .position2:
            let pos1 = Int.random(in: 1...params.maxPosition)
            var pos2 = Int.random(in: 1...params.maxPosition)
            while pos2 == pos1 && params.maxPosition > 1 {
                pos2 = Int.random(in: 1...params.maxPosition)
            }
            return [ExerciseLine(label: "Positions", value: "\(pos1), \(pos2)", emphasis: true)]

        case .multiselect:
            let lists = params.multiselect
            guard !lists.isEmpty else { return [] }

            let usedFirstElements = Set(used.compactMap { $0.first })

            // Pick one value from each list; ensure first element hasn't been used
            var combo: [String]
            var attempts = 0
            repeat {
                combo = lists.map { $0.randomElement()! }
                attempts += 1
            } while usedFirstElements.contains(combo[0]) && attempts < 100

            used.insert(combo)
            let label = Atom.ordinals[min(used.count - 1, Atom.ordinals.count - 1)]
            let value = combo.joined(separator: " ")
            return [ExerciseLine(label: label, value: value, emphasis: false)]

        case .notes:
            return []  // marker atom — rendering handled by ExerciseSpec.generate()
        }
    }
}

// MARK: - Exercise Spec (loaded from JSON)

struct ExerciseSpec: Identifiable {
    let id: String  // derived from name
    let name: String
    let symbol: String
    let atoms: [Atom]        // always active
    let simpleAtoms: [Atom]  // active when rotate is OFF
    let rotateAtoms: [Atom]  // active when rotate is ON
    let chords: Set<String>
    let params: AtomParams
    let notes: [String]  // "1"-"7" for diatonic, "#6" for raised, "b3" for lowered
    let playstyle: String  // "arpeggio" or "chord"
    let disabled: Bool

    func generate(chordKey: String = "", rotate: Bool = false) -> Exercise {
        let effectiveAtoms = atoms + (rotate ? rotateAtoms : simpleAtoms)

        var allLines: [ExerciseLine] = []
        var used: Set<[String]> = []
        for atom in effectiveAtoms where atom != .notes {
            allLines.append(contentsOf: atom.generate(params: params, used: &used))
        }

        // If only one multiselect, fold its value into the title suffix
        let multiselectCount = effectiveAtoms.filter { $0 == .multiselect }.count
        if multiselectCount == 1 {
            allLines = allLines.map { line in
                line.label == "First"
                    ? ExerciseLine(label: "_suffix", value: line.value, emphasis: line.emphasis)
                    : line
            }
        }

        // Extract _suffix lines and fold into title
        let suffixParts = allLines.filter { $0.label == "_suffix" }.map { $0.value }
        let displayLines = allLines.filter { $0.label != "_suffix" }
        let titleSuffix = suffixParts.joined(separator: " ")

        // Resolve notes to solfege only if .notes is in the effective atom list
        var solfege: [String] = []
        var startIndex: Int? = nil
        if effectiveAtoms.contains(.notes), !notes.isEmpty, !chordKey.isEmpty {
            // Convert to [Any]: plain numbers become Int, altered degrees stay String
            let degrees: [Any] = notes.map { s -> Any in
                if let n = Int(s) { return n }
                return s
            }
            solfege = solfegeNotes(for: chordKey, degrees: degrees)
            if rotate, !solfege.isEmpty {
                let unique = Array(Set(solfege))
                if let startNote = unique.randomElement() {
                    startIndex = solfege.firstIndex(of: startNote)
                }
            }
        }

        return Exercise(
            typeName: name,
            symbol: symbol,
            titleSuffix: titleSuffix,
            displayLines: displayLines,
            solfegeNotes: solfege,
            startNoteIndex: startIndex,
            playstyle: playstyle
        )
    }

    func matchesChord(_ chordKey: String) -> Bool {
        chords.isEmpty || chords.contains(chordKey)
    }
}

// MARK: - Exercise Catalog (loads from JSON with remote sync)

class ExerciseCatalog: ObservableObject {
    static let shared = ExerciseCatalog()

    private static let remoteURL = URL(string: "https://perfectpractice-488920.ue.r.appspot.com/perfectpractice.json")!

    @Published var exercises: [ExerciseSpec]
    @Published var parseError: String?

    private static var cachedFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("exercises.json")
    }

    private init() {
        let (specs, error) = ExerciseCatalog.loadLocal()
        exercises = specs
        parseError = error
    }

    /// Load from whichever local source (cache or bundle) has the higher version
    private static func loadLocal() -> ([ExerciseSpec], String?) {
        let bundleURL = Bundle.main.url(forResource: "exercises", withExtension: "json")

        let cachedData = FileManager.default.fileExists(atPath: cachedFileURL.path)
            ? try? Data(contentsOf: cachedFileURL) : nil
        let bundleData = bundleURL.flatMap { try? Data(contentsOf: $0) }

        let cachedVersion = cachedData.map { parseVersion($0) } ?? -1
        let bundleVersion = bundleData.map { parseVersion($0) } ?? -1

        print("Local versions — cache: \(cachedVersion), bundle: \(bundleVersion)")

        // Check if bundle is broken (has data but fails to parse or returns version 0)
        let bundleBroken = bundleData != nil && (bundleVersion <= 0 || parseData(bundleData!) == nil)
        let bundleWarning: String? = bundleBroken
            ? "Bundle JSON broken: \(parseErrorMessage(bundleData!))"
            : nil

        // Bundle wins on ties (new build = fresh content); cache only wins if strictly newer (remote update)
        if let data = bundleData, bundleVersion >= cachedVersion,
           let specs = parseData(data), !specs.isEmpty {
            try? data.write(to: cachedFileURL)
            print("Loaded exercises from bundle (v\(bundleVersion)), updated cache")
            return (specs, nil)
        }

        if let data = cachedData, let specs = parseData(data), !specs.isEmpty {
            print("Loaded exercises from cache (v\(cachedVersion))")
            if let warning = bundleWarning {
                print(warning)
            }
            return (specs, bundleWarning)
        }

        // Both failed — report which ones had parse errors
        var errors: [String] = []
        if let data = bundleData {
            errors.append("Bundle JSON parse failed: \(parseErrorMessage(data))")
        } else {
            errors.append("No bundle exercises.json found")
        }
        if let data = cachedData {
            errors.append("Cached JSON parse failed: \(parseErrorMessage(data))")
            try? FileManager.default.removeItem(at: cachedFileURL)
        }

        let msg = errors.joined(separator: "\n")
        print(msg)
        return ([], msg)
    }

    private static func parseErrorMessage(_ data: Data) -> String {
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            if let dict = json as? [String: Any], dict["exercises"] != nil {
                return "JSON valid but exercises array could not be parsed"
            }
            return "JSON valid but missing 'exercises' key"
        } catch {
            return error.localizedDescription
        }
    }

    /// Check remote for updates and reload if version is newer
    func refresh() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: ExerciseCatalog.remoteURL)

                let remoteVersion = ExerciseCatalog.parseVersion(data)
                let currentVersion: Int
                if let cachedData = try? Data(contentsOf: ExerciseCatalog.cachedFileURL) {
                    currentVersion = ExerciseCatalog.parseVersion(cachedData)
                } else {
                    currentVersion = -1
                }

                print("Remote version: \(remoteVersion), current version: \(currentVersion)")

                guard remoteVersion > currentVersion else {
                    print("Remote not newer, skipping update")
                    return
                }

                // Validate before saving
                guard let specs = ExerciseCatalog.parseData(data), !specs.isEmpty else {
                    print("Remote exercises.json invalid, keeping current")
                    return
                }

                // Save to cache and update
                try data.write(to: ExerciseCatalog.cachedFileURL)
                print("Updated exercises from remote (v\(remoteVersion), \(specs.count) exercises)")
                await MainActor.run {
                    self.exercises = specs
                }
            } catch {
                print("Could not fetch remote exercises: \(error)")
            }
        }
    }

    /// Get exercises that match the given chord and are enabled (excluding disabled)
    func exercisesForChord(_ chordKey: String, enabled: Set<String>) -> [ExerciseSpec] {
        exercises.filter { !$0.disabled && enabled.contains($0.id) && $0.matchesChord(chordKey) }
    }

    /// Generate a random exercise for the given chord
    func generateForChord(_ chordKey: String, enabled: Set<String>, rotate: Bool = false) -> Exercise? {
        let matching = exercisesForChord(chordKey, enabled: enabled)
        guard let spec = matching.randomElement() else { return nil }
        return spec.generate(chordKey: chordKey, rotate: rotate)
    }

    // MARK: - JSON Parsing

    private static func parseFile(at url: URL) -> [ExerciseSpec]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseData(data)
    }

    private static func parseVersion(_ data: Data) -> Int {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 0 }
        return json["version"] as? Int ?? 0
    }

    private static func parseData(_ data: Data) -> [ExerciseSpec]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exerciseArray = json["exercises"] as? [[String: Any]] else {
            return nil
        }
        var nameCounts: [String: Int] = [:]
        return exerciseArray.compactMap { dict -> ExerciseSpec? in
            guard let spec = parseExercise(dict, nameCounts: &nameCounts) else { return nil }
            return spec
        }
    }

    private static func parseExercise(_ dict: [String: Any], nameCounts: inout [String: Int]) -> ExerciseSpec? {
        guard let name = dict["name"] as? String else {
            return nil
        }

        let atomStrings = dict["atoms"] as? [String] ?? []
        let simpleAtomStrings = dict["simpleatoms"] as? [String] ?? []
        let rotateAtomStrings = dict["rotateatoms"] as? [String] ?? []
        let chordStrings = dict["chords"] as? [String] ?? []
        let atoms = atomStrings.compactMap { Atom(rawValue: $0) }
        let simpleAtoms = simpleAtomStrings.compactMap { Atom(rawValue: $0) }
        let rotateAtoms = rotateAtomStrings.compactMap { Atom(rawValue: $0) }

        let base = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let count = nameCounts[base, default: 0]
        nameCounts[base] = count + 1
        let id = count == 0 ? base : "\(base)_\(count + 1)"

        var params = AtomParams()
        if let maxPos = dict["max_position"] as? Int {
            params.maxPosition = maxPos
        }
        if let ms = dict["multiselect"] as? [[Any]] {
            params.multiselect = ms.map { list in
                list.map { item in
                    if let n = item as? Int { return "\(n)" }
                    return "\(item)"
                }
            }
        }

        // Notes can be ints or strings (e.g. [1, 3, 5, "#6"])
        let notes: [String]
        if let rawNotes = dict["notes"] as? [Any] {
            notes = rawNotes.map { item in
                if let n = item as? Int { return "\(n)" }
                return "\(item)"
            }
        } else {
            notes = []
        }
        let symbol = dict["symbol"] as? String ?? "●"
        let playstyle = dict["playstyle"] as? String ?? "arpeggio"
        let disabled = dict["disabled"] as? Bool ?? false

        return ExerciseSpec(
            id: id,
            name: name,
            symbol: symbol,
            atoms: atoms,
            simpleAtoms: simpleAtoms,
            rotateAtoms: rotateAtoms,
            chords: Set(chordStrings),
            params: params,
            notes: notes,
            playstyle: playstyle,
            disabled: disabled
        )
    }
}
