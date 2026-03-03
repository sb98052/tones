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
