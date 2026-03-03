//
//  Models.swift
//  Minor Notes
//
//  Data structures for minor key ear training
//

import Foundation

// All 12 chromatic notes
let allNotes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

// Minor scale degrees (in solfege)
// In minor, the tonic is "la"
// Includes "si" (raised sol) for harmonic minor leading tone
let minorScaleDegrees = ["la", "ti", "do", "re", "mi", "fa", "sol", "si"]

// Semitone intervals from the root (la) for minor scale
// la=0, ti=2, do=3, re=5, mi=7, fa=8, sol=10, si=11
let solfegeToSemitones: [String: Int] = [
    "la": 0,   // Root
    "ti": 2,   // Major 2nd
    "do": 3,   // Minor 3rd
    "re": 5,   // Perfect 4th
    "mi": 7,   // Perfect 5th
    "fa": 8,   // Minor 6th
    "sol": 10, // Minor 7th
    "si": 11   // Major 7th (raised sol, leading tone)
]

// Pronunciation for text-to-speech
let solfegePronunciation: [String: String] = [
    "la": "la",
    "ti": "tee",
    "do": "doe",
    "re": "ray",
    "mi": "mee",
    "fa": "fa",
    "sol": "soul",
    "si": "see"
]

// Represents a minor key
struct MinorKey {
    let rootNote: String  // e.g., "A" for A minor

    // Get the drone file name for this key
    var droneFileName: String {
        return rootNote  // e.g., "A" -> will load "A.mp3"
    }

    // Convert solfege degree to actual note name with octave
    func solfegeToNote(_ degree: String, octave: Int) -> String {
        guard let semitones = solfegeToSemitones[degree],
              let rootIndex = allNotes.firstIndex(of: rootNote.replacingOccurrences(of: "#", with: "#")) else {
            return "A\(octave)"
        }

        let noteIndex = (rootIndex + semitones) % 12
        let octaveAdjust = (rootIndex + semitones) / 12
        return "\(allNotes[noteIndex])\(octave + octaveAdjust)"
    }

    // Get the actual note name (without octave) for a solfege degree
    func solfegeToNoteName(_ degree: String) -> String {
        guard let semitones = solfegeToSemitones[degree],
              let rootIndex = allNotes.firstIndex(of: rootNote) else {
            return rootNote
        }

        let noteIndex = (rootIndex + semitones) % 12
        return allNotes[noteIndex]
    }

    // Create a random minor key
    static func random() -> MinorKey {
        let randomNote = allNotes.randomElement()!
        return MinorKey(rootNote: randomNote)
    }
}
