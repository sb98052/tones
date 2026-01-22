//
//  Models.swift
//  Djangoling
//
//  Chord Progression Ear Training - Data Models
//

import Foundation

// MARK: - Solfege Mappings

let solfegeToSemitone: [String: Int] = [
    "do": 0, "di": 1, "ra": 1, "re": 2, "ri": 3, "me": 3, "mi": 4, "fa": 5,
    "fi": 6, "se": 6, "sol": 7, "si": 8, "le": 8, "la": 9, "li": 10, "te": 10, "ti": 11
]

let solfegePronunciation: [String: String] = [
    "do": "doe", "re": "ray", "mi": "me", "fa": "far", "sol": "so", "la": "la", "ti": "tea",
    "di": "dee", "ra": "rah", "ri": "ree", "me": "may", "fi": "fee", "se": "say",
    "si": "see", "le": "lay", "li": "lee", "te": "tay"
]

let noteToSemitone: [String: Int] = [
    "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "Fb": 4, "E#": 5,
    "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10,
    "B": 11, "Cb": 11
]

// MARK: - Chord Quality

enum ChordQuality: String {
    case minor = "minor"
    case major = "major"
    case dominant = "dominant"
    case minor7 = "minor7"
    case major7 = "major7"
}

// MARK: - Chord Definition

struct ChordDefinition {
    let degrees: [String]
    let quality: ChordQuality
}

// MARK: - Chord Definitions

let chordDefinitions: [String: ChordDefinition] = [
    // Minor chords
    "la_minor": ChordDefinition(degrees: ["la", "do", "mi"], quality: .minor),
    "re_minor": ChordDefinition(degrees: ["re", "fa", "la"], quality: .minor),
    "mi_minor": ChordDefinition(degrees: ["mi", "sol", "ti"], quality: .minor),

    // Major chords
    "do_major": ChordDefinition(degrees: ["do", "mi", "sol"], quality: .major),
    "fa_major": ChordDefinition(degrees: ["fa", "la", "do"], quality: .major),
    "sol_major": ChordDefinition(degrees: ["sol", "ti", "re"], quality: .major),

    // Dominant chords (7th chords)
    "mi_dominant": ChordDefinition(degrees: ["mi", "si", "ti", "re"], quality: .dominant),
    "re_dominant": ChordDefinition(degrees: ["re", "fi", "la", "do"], quality: .dominant),

    // For Dark Eyes - Gypsy jazz chords
    "mi7_dominant": ChordDefinition(degrees: ["mi", "si", "ti", "re"], quality: .dominant),
    "la_minor_dm": ChordDefinition(degrees: ["la", "do", "mi"], quality: .minor),
    "re_minor_gm": ChordDefinition(degrees: ["re", "fa", "la"], quality: .minor),
    "fa_major_bb": ChordDefinition(degrees: ["fa", "la", "do"], quality: .major),

    // Additional dominant 7th chords for All of Me
    "la7_dominant": ChordDefinition(degrees: ["la", "di", "mi", "sol"], quality: .dominant),
    "re7_dominant": ChordDefinition(degrees: ["re", "fi", "la", "do"], quality: .dominant),
    "sol7_dominant": ChordDefinition(degrees: ["sol", "ti", "re", "fa"], quality: .dominant),

    // Additional minor chord
    "fa_minor": ChordDefinition(degrees: ["fa", "le", "do"], quality: .minor),

    // Chords for Autumn Leaves
    "re_minor7": ChordDefinition(degrees: ["re", "fa", "la", "do"], quality: .minor7),
    "do_major7": ChordDefinition(degrees: ["do", "mi", "sol", "ti"], quality: .major7),
    "fa_major7": ChordDefinition(degrees: ["fa", "la", "do", "mi"], quality: .major7),
]

// MARK: - Mode

enum Mode: String {
    case minor = "minor"
    case major = "major"
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

    var tonicNote: String {
        if mode == .minor {
            return signature[5] // La is tonic in minor
        } else {
            return signature[0] // Do is tonic in major
        }
    }

    func solfegeToNote(_ solfege: String, octave: Int) -> String {
        let semiOffset = solfegeToSemitone[solfege] ?? 0
        let baseNote = mode == .minor ? signature[5] : signature[0]
        let baseSemi = noteToSemitone[baseNote] ?? 0

        let targetSemi: Int
        if mode == .minor {
            // Adjust for minor mode - La is tonic (offset by 9 semitones from Do)
            targetSemi = (baseSemi + semiOffset - 9 + 12) % 12
        } else {
            targetSemi = (baseSemi + semiOffset) % 12
        }

        // Find the note name that matches this semitone
        // Prefer natural notes
        for (note, semi) in noteToSemitone {
            if semi == targetSemi && !note.contains("#") && !note.contains("b") {
                return "\(note)\(octave)"
            }
        }

        // Fallback to sharp/flat notes
        for (note, semi) in noteToSemitone {
            if semi == targetSemi {
                return "\(note)\(octave)"
            }
        }

        return "C\(octave)" // Default fallback
    }

    static func random(for mode: Mode) -> Key {
        let sig = keySignatures.randomElement()!
        return Key(signature: sig, mode: mode)
    }
}

// MARK: - Melody Note Result

struct MelodyNote {
    let noteName: String
    let label: String
    let degree: String
    let position: String
    let quality: ChordQuality
}
