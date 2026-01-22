//
//  Models.swift
//  Colors
//
//  Harmonic Colors Ear Training - Data Models
//

import Foundation

// MARK: - Solfege Mappings

let solfegeToSemitone: [String: Int] = [
    "do": 0, "di": 1, "ra": 1, "re": 2, "ri": 3, "me": 3, "mi": 4, "fa": 5,
    "fi": 6, "se": 6, "sol": 7, "si": 8, "le": 8, "la": 9, "li": 10, "te": 10, "ti": 11
]

// Pronunciation for text-to-speech (consistent with Djangoling/progression.py)
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

// MARK: - Scale Degrees

// The 7 diatonic scale degrees
let diatonicDegrees = ["do", "re", "mi", "fa", "sol", "la", "ti"]

// MARK: - Chord Definition

struct ChordDefinition {
    let name: String           // Display name (e.g., "do", "mi dom")
    let root: String           // Root degree (e.g., "do", "mi")
    let degrees: [String]      // All degrees in the chord
    let isDiatonic: Bool       // Whether the chord is diatonic

    // The degree that this chord is named after for announcement
    var announcementName: String {
        solfegePronunciation[root] ?? root
    }
}

// MARK: - Chord Definitions

// All available chords - using solfege degrees
let chordDefinitions: [String: ChordDefinition] = [
    "do": ChordDefinition(
        name: "do",
        root: "do",
        degrees: ["do", "mi", "sol"],
        isDiatonic: true
    ),
    "re": ChordDefinition(
        name: "re",
        root: "re",
        degrees: ["re", "fa", "la"],
        isDiatonic: true
    ),
    "mi": ChordDefinition(
        name: "mi",
        root: "mi",
        degrees: ["mi", "sol", "ti"],
        isDiatonic: true
    ),
    "mi_dom": ChordDefinition(
        name: "mi dom",
        root: "mi",
        degrees: ["mi", "si", "ti", "re"],  // Contains non-diatonic "si" (raised sol)
        isDiatonic: false
    ),
    "fa": ChordDefinition(
        name: "fa",
        root: "fa",
        degrees: ["fa", "la", "do"],
        isDiatonic: true
    ),
    "sol": ChordDefinition(
        name: "sol",
        root: "sol",
        degrees: ["sol", "ti", "re"],
        isDiatonic: true
    ),
    "la": ChordDefinition(
        name: "la",
        root: "la",
        degrees: ["la", "do", "mi"],
        isDiatonic: true
    ),
    "ti": ChordDefinition(
        name: "ti",
        root: "ti",
        degrees: ["ti", "re", "fa"],
        isDiatonic: true
    )
]

// The chord keys in order for UI display
let chordKeys = ["do", "re", "mi", "mi_dom", "fa", "sol", "la", "ti"]

// MARK: - Degree to Chords Mapping

// For each scale degree, which chords contain it?
// This maps a melody note to the chords that can harmonize it
func chordsContainingDegree(_ degree: String, enabledChords: Set<String>) -> [String] {
    var result: [String] = []

    for chordKey in chordKeys {
        guard enabledChords.contains(chordKey),
              let chord = chordDefinitions[chordKey] else { continue }

        if chord.degrees.contains(degree) {
            result.append(chordKey)
        }
    }

    return result
}

// MARK: - Mode

enum Mode: String, CaseIterable {
    case major = "major"
    case minor = "minor"

    var displayName: String {
        rawValue.capitalized
    }
}

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

// MARK: - Exercise Result

struct Exercise {
    let melodyDegree: String
    let chords: [String]  // Chord keys in the order they were played
}
