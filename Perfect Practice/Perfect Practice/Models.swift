//
//  Models.swift
//  Perfect Practice
//
//  Progression data (from Djangoling)
//

import Foundation

// MARK: - Mode

enum Mode: String {
    case minor = "minor"
    case major = "major"
}

// MARK: - Time Signature

enum TimeSignature: String, CaseIterable {
    case threeQuarter = "3/4"
    case fourQuarter = "4/4"

    var beatsPerMeasure: Int {
        switch self {
        case .threeQuarter: return 3
        case .fourQuarter: return 4
        }
    }
}

// MARK: - Progression

struct Progression {
    let name: String
    let chords: [String]
    let mode: Mode
}

// MARK: - All Progressions

let progressions: [String: Progression] = [
    "dark_eyes": Progression(
        name: "Dark Eyes",
        chords: ["mi7_dominant", "la_minor_dm", "mi7_dominant", "fa_major_bb",
                 "re_minor_gm", "la_minor_dm", "mi7_dominant", "la_minor_dm"],
        mode: .minor
    ),
    "minor_swing": Progression(
        name: "Minor Swing",
        chords: ["la_minor", "la_minor", "re_minor", "re_minor",
                 "mi_dominant", "mi_dominant", "la_minor", "la_minor",
                 "re_minor", "re_minor", "la_minor", "la_minor",
                 "mi_dominant", "mi_dominant", "la_minor", "mi_dominant"],
        mode: .minor
    ),
    "superpop": Progression(
        name: "Super Pop",
        chords: ["do_major", "sol_major", "la_minor", "fa_major"],
        mode: .major
    ),
    "primary": Progression(
        name: "Primary",
        chords: ["do_major", "fa_major", "la_minor", "re_minor", "sol_major", "do_major"],
        mode: .major
    ),
    "primary_minor": Progression(
        name: "Primary Minor",
        chords: ["la_minor", "re_minor", "sol_major", "do_major", "mi_dominant", "la_minor"],
        mode: .minor
    ),
    "all_of_me": Progression(
        name: "All of Me",
        chords: ["do_major", "do_major", "mi7_dominant", "mi7_dominant",
                 "la7_dominant", "la7_dominant", "re_minor", "re_minor",
                 "mi7_dominant", "mi7_dominant", "la_minor", "la_minor",
                 "re7_dominant", "re7_dominant", "sol7_dominant", "sol7_dominant",
                 "do_major", "do_major", "mi7_dominant", "mi7_dominant",
                 "la7_dominant", "la7_dominant", "re_minor", "re_minor",
                 "fa_major", "fa_minor", "do_major", "la7_dominant",
                 "re_minor", "sol7_dominant", "do_major", "sol7_dominant"],
        mode: .major
    ),
    "autumn_leaves_start": Progression(
        name: "Autumn Leaves (Start)",
        chords: ["re_minor7", "sol7_dominant", "do_major7", "fa_major7",
                 "re_minor7", "sol7_dominant", "do_major7", "fa_major7"],
        mode: .major
    )
]

// Solfege chord names for display
let chordDisplayNames: [String: String] = [
    "la_minor": "La minor", "re_minor": "Re minor", "mi_minor": "Mi minor",
    "do_major": "Do major", "fa_major": "Fa major", "sol_major": "Sol major",
    "mi_dominant": "Mi dom", "re_dominant": "Re dom",
    "mi7_dominant": "Mi7 dom", "la_minor_dm": "La minor", "re_minor_gm": "Re minor", "fa_major_bb": "Fa major",
    "la7_dominant": "La7 dom", "re7_dominant": "Re7 dom", "sol7_dominant": "Sol7 dom",
    "fa_minor": "Fa minor",
    "re_minor7": "Re min7", "do_major7": "Do maj7", "fa_major7": "Fa maj7",
]

func displayName(for chord: String) -> String {
    chordDisplayNames[chord] ?? chord
}

// MARK: - Solfege-to-Semitone Mapping (for audio playback)

let solfegeToSemitone: [String: Int] = [
    "do": 0, "di": 1, "ra": 1, "re": 2, "ri": 3, "me": 3, "mi": 4, "fa": 5,
    "fi": 6, "se": 6, "sol": 7, "si": 8, "le": 8, "la": 9, "li": 10, "te": 10, "ti": 11
]

let noteToSemitone: [String: Int] = [
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "Fb": 4, "E#": 5,
    "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10,
    "B": 11, "Cb": 11
]

// Canonical note names matching our MP3 file naming (uses flats, not sharps)
private let semitoneToFileName: [Int: String] = [
    0: "C", 1: "Db", 2: "D", 3: "Eb", 4: "E", 5: "F",
    6: "Gb", 7: "G", 8: "Ab", 9: "A", 10: "Bb", 11: "B"
]

let solfegePronunciation: [String: String] = [
    "do": "doe", "re": "ray", "mi": "me", "fa": "far", "sol": "so", "la": "la", "ti": "tea",
    "di": "dee", "ra": "rah", "ri": "ree", "me": "may", "fi": "fee", "se": "say",
    "si": "see", "le": "lay", "li": "lee", "te": "tay"
]

// MARK: - Key Signatures

let keySignatures: [[String]] = [
    ["C", "D", "E", "F", "G", "A", "B"],
    ["G", "A", "B", "C", "D", "E", "F#"],
    ["F", "G", "A", "Bb", "C", "D", "E"],
    ["D", "E", "F#", "G", "A", "B", "C#"],
    ["A", "B", "C#", "D", "E", "F#", "G#"],
    ["E", "F#", "G#", "A", "B", "C#", "D#"],
    ["B", "C#", "D#", "E", "F#", "G#", "A#"],
    ["F#", "G#", "A#", "B", "C#", "D#", "E#"],
    ["Bb", "C", "D", "Eb", "F", "G", "A"],
    ["Eb", "F", "G", "Ab", "Bb", "C", "D"],
    ["Ab", "Bb", "C", "Db", "Eb", "F", "G"],
    ["Db", "Eb", "F", "Gb", "Ab", "Bb", "C"],
    ["Gb", "Ab", "Bb", "Cb", "Db", "Eb", "F"],
]

// MARK: - Key

struct Key {
    let signature: [String]
    let mode: Mode

    /// Convert solfege to a playable note filename (e.g. "A3", "Eb4")
    func solfegeToNote(_ solfege: String, octave: Int) -> String {
        let semiOffset = solfegeToSemitone[solfege] ?? 0
        let baseNote = mode == .minor ? signature[5] : signature[0]
        let baseSemi = noteToSemitone[baseNote] ?? 0

        let targetSemi: Int
        if mode == .minor {
            targetSemi = (baseSemi + semiOffset - 9 + 12) % 12
        } else {
            targetSemi = (baseSemi + semiOffset) % 12
        }

        let noteName = semitoneToFileName[targetSemi] ?? "C"
        return "\(noteName)\(octave)"
    }

    /// Absolute semitone value for a note (note name + octave)
    static func absoluteSemitone(_ noteFile: String) -> Int {
        // Parse "Eb4" → note="Eb", octave=4
        var note = ""
        var octaveStr = ""
        for ch in noteFile {
            if ch.isNumber || (ch == "-" && octaveStr.isEmpty) {
                octaveStr.append(ch)
            } else {
                note.append(ch)
            }
        }
        let octave = Int(octaveStr) ?? 4
        let semi = noteToSemitone[note] ?? 0
        return octave * 12 + semi
    }

    static func random(for mode: Mode) -> Key {
        let sig = keySignatures.randomElement()!
        return Key(signature: sig, mode: mode)
    }
}

// MARK: - Chord Scales (degree 1-7 as solfege for each chord key)

let chordScales: [String: [String]] = [
    "la_minor":      ["la", "ti", "do", "re", "mi", "fa", "sol"],
    "re_minor":      ["re", "mi", "fa", "sol", "la", "ti", "do"],
    "mi_minor":      ["mi", "fi", "sol", "la", "ti", "do", "re"],
    "do_major":      ["do", "re", "mi", "fa", "sol", "la", "ti"],
    "fa_major":      ["fa", "sol", "la", "ti", "do", "re", "mi"],
    "sol_major":     ["sol", "la", "ti", "do", "re", "mi", "fi"],
    "mi_dominant":   ["mi", "fi", "si", "la", "ti", "do", "re"],
    "re_dominant":   ["re", "mi", "fi", "sol", "la", "ti", "do"],
    "mi7_dominant":  ["mi", "fi", "si", "la", "ti", "do", "re"],
    "la_minor_dm":   ["la", "ti", "do", "re", "mi", "fa", "sol"],
    "re_minor_gm":   ["re", "mi", "fa", "sol", "la", "ti", "do"],
    "fa_major_bb":   ["fa", "sol", "la", "ti", "do", "re", "mi"],
    "la7_dominant":  ["la", "ti", "di", "re", "mi", "fi", "sol"],
    "re7_dominant":  ["re", "mi", "fi", "sol", "la", "ti", "do"],
    "sol7_dominant": ["sol", "la", "ti", "do", "re", "mi", "fa"],
    "fa_minor":      ["fa", "sol", "le", "ti", "do", "re", "mi"],
    "re_minor7":     ["re", "mi", "fa", "sol", "la", "ti", "do"],
    "do_major7":     ["do", "re", "mi", "fa", "sol", "la", "ti"],
    "fa_major7":     ["fa", "sol", "la", "ti", "do", "re", "mi"],
]

// Chromatic alterations: raised and lowered solfege names
private let raisedSolfege: [String: String] = [
    "do": "di", "re": "ri", "mi": "fi", "fa": "fi",
    "sol": "si", "la": "li", "ti": "di",
    "le": "la", "te": "ti", "me": "mi", "ra": "re", "se": "sol",
]

private let loweredSolfege: [String: String] = [
    "do": "ti", "re": "ra", "mi": "me", "fa": "mi",
    "sol": "se", "la": "le", "ti": "te",
    "di": "do", "ri": "re", "fi": "fa", "si": "sol", "li": "la",
]

/// Resolve scale degree specs to solfege names for a given chord.
/// Accepts: integers (1-7), or strings like "#6" (raised) / "b3" (lowered).
func solfegeNotes(for chordKey: String, degrees: [Any]) -> [String] {
    guard let scale = chordScales[chordKey] else { return [] }
    return degrees.compactMap { degree -> String? in
        if let n = degree as? Int {
            guard n >= 1, n <= 7 else { return nil }
            return scale[n - 1]
        }
        if let s = degree as? String {
            if s.hasPrefix("#"), let n = Int(s.dropFirst(1)), n >= 1, n <= 7 {
                let base = scale[n - 1]
                return raisedSolfege[base] ?? base
            }
            if s.hasPrefix("b"), let n = Int(s.dropFirst(1)), n >= 1, n <= 7 {
                let base = scale[n - 1]
                return loweredSolfege[base] ?? base
            }
            // Plain number as string
            if let n = Int(s), n >= 1, n <= 7 {
                return scale[n - 1]
            }
        }
        return nil
    }
}
