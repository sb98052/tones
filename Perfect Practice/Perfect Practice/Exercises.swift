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
    let displayLines: [ExerciseLine]
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
            return [ExerciseLine(label: "Pattern", value: patterns.randomElement()!, emphasis: false)]

        case .down:
            let direction = Bool.random() ? "Down" : "Up"
            return [ExerciseLine(label: "Direction", value: direction, emphasis: false)]

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
        }
    }
}

// MARK: - Exercise Spec (loaded from JSON)

struct ExerciseSpec: Identifiable {
    let id: String  // derived from name
    let name: String
    let atoms: [Atom]
    let chords: Set<String>
    let params: AtomParams
    let notes: [Int]

    func generate(chordKey: String = "", rotate: Bool = false) -> Exercise {
        var lines: [ExerciseLine] = []
        var used: Set<[String]> = []
        for atom in atoms {
            lines.append(contentsOf: atom.generate(params: params, used: &used))
        }

        // Resolve notes to solfege if specified
        if !notes.isEmpty, !chordKey.isEmpty {
            let solfege = solfegeNotes(for: chordKey, degrees: notes)
            if !solfege.isEmpty {
                lines.append(ExerciseLine(label: "Notes", value: solfege.joined(separator: " "), emphasis: false))

                // Rotate: pick a random start note from unique notes
                if rotate {
                    let unique = Array(Set(solfege))
                    if let startNote = unique.randomElement() {
                        lines.append(ExerciseLine(label: "Start", value: startNote, emphasis: true))
                    }
                }
            }
        }

        return Exercise(typeName: name, displayLines: lines)
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

    private static var cachedFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("exercises.json")
    }

    private init() {
        exercises = ExerciseCatalog.loadLocal()
    }

    /// Load from local cache, falling back to bundled file (firmware fallback)
    private static func loadLocal() -> [ExerciseSpec] {
        // Try cached file first
        if FileManager.default.fileExists(atPath: cachedFileURL.path) {
            if let specs = parseFile(at: cachedFileURL), !specs.isEmpty {
                print("Loaded exercises from cache")
                return specs
            }
            // Cache exists but is invalid — delete it
            print("Cached exercises.json invalid, deleting")
            try? FileManager.default.removeItem(at: cachedFileURL)
        }

        // Fallback: copy bundle file to cache and load
        if let bundleURL = Bundle.main.url(forResource: "exercises", withExtension: "json") {
            try? FileManager.default.copyItem(at: bundleURL, to: cachedFileURL)
            if let specs = parseFile(at: bundleURL), !specs.isEmpty {
                print("Loaded exercises from bundle (firmware fallback)")
                return specs
            }
        }

        print("Could not load exercises locally, will try remote")
        return []
    }

    /// Check remote for updates and reload if changed
    func refresh() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: ExerciseCatalog.remoteURL)

                // Compare with current cached file only if we already have exercises
                if !exercises.isEmpty {
                    let cachedData = try? Data(contentsOf: ExerciseCatalog.cachedFileURL)
                    if cachedData == data {
                        print("Exercises unchanged, skipping update")
                        return
                    }
                }

                // Validate before saving
                guard let specs = ExerciseCatalog.parseData(data), !specs.isEmpty else {
                    print("Remote exercises.json invalid, keeping current")
                    return
                }

                // Save to cache and update
                try data.write(to: ExerciseCatalog.cachedFileURL)
                print("Updated exercises from remote (\(specs.count) exercises)")
                await MainActor.run {
                    self.exercises = specs
                }
            } catch {
                print("Could not fetch remote exercises: \(error)")
            }
        }
    }

    /// Get exercises that match the given chord and are enabled
    func exercisesForChord(_ chordKey: String, enabled: Set<String>) -> [ExerciseSpec] {
        exercises.filter { enabled.contains($0.id) && $0.matchesChord(chordKey) }
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

    private static func parseData(_ data: Data) -> [ExerciseSpec]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exerciseArray = json["exercises"] as? [[String: Any]] else {
            return nil
        }
        return exerciseArray.compactMap { parseExercise($0) }
    }

    private static func parseExercise(_ dict: [String: Any]) -> ExerciseSpec? {
        guard let name = dict["name"] as? String else {
            return nil
        }

        let atomStrings = dict["atoms"] as? [String] ?? []
        let chordStrings = dict["chords"] as? [String] ?? []
        let atoms = atomStrings.compactMap { Atom(rawValue: $0) }

        let id = name.lowercased().replacingOccurrences(of: " ", with: "_")

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

        let notes = dict["notes"] as? [Int] ?? []

        return ExerciseSpec(
            id: id,
            name: name,
            atoms: atoms,
            chords: Set(chordStrings),
            params: params,
            notes: notes
        )
    }
}
