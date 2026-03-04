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

/// Resolve scale degree numbers (1-7) to solfege names for a given chord
func solfegeNotes(for chordKey: String, degrees: [Int]) -> [String] {
    guard let scale = chordScales[chordKey] else { return [] }
    return degrees.compactMap { degree in
        guard degree >= 1, degree <= 7 else { return nil }
        return scale[degree - 1]
    }
}
