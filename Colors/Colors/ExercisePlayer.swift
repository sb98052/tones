//
//  ExercisePlayer.swift
//  Colors
//
//  Main exercise engine for harmonic colors ear training
//

import Foundation
import Combine

enum PlayerState {
    case stopped
    case playing
    case paused
}

class ExercisePlayer: ObservableObject {
    // MARK: - Published Properties

    @Published var state: PlayerState = .stopped
    @Published var currentKey: Key?
    @Published var currentDegree: String = ""
    @Published var currentChords: [String] = []
    @Published var announcement: String = ""

    // MARK: - Settings

    var mode: Mode = .major
    var enabledChords: Set<String> = Set(chordKeys)  // All chords enabled by default
    var chordOctaves: [Int] = [3, 4]
    var melodyOctave: Int = 5
    var delay: TimeInterval = 1.5  // Configurable delay between sounds
    var waitTimeAfterExercise: TimeInterval = 2.0
    var guitarMode: Bool = false

    // MARK: - Guitar Mode State

    @Published var canReveal: Bool = false
    private var pendingDegree: String = ""
    private var pendingChords: [String] = []
    private var skipToNext: Bool = false
    private var lastMelodyNote: String = ""
    private var lastChordVoicings: [[String]] = []  // Stores exact chord notes for each chord

    // MARK: - Private Properties

    private var playbackTask: Task<Void, Never>?
    private let audioManager = AudioManager.shared
    private let speechManager = SpeechManager.shared

    // MARK: - Public Methods

    func start() {
        currentKey = Key.random(for: mode)
        state = .playing

        // Play scale first to establish key
        playScale()

        // Start exercises after scale
        let scaleDuration = 0.4 * 8 + 0.5  // 8 notes * 0.4s + pause
        DispatchQueue.main.asyncAfter(deadline: .now() + scaleDuration) { [weak self] in
            self?.startExerciseLoop()
        }
    }

    func stop() {
        state = .stopped
        playbackTask?.cancel()
        playbackTask = nil
        audioManager.stopAll()
        speechManager.stop()
        currentDegree = ""
        currentChords = []
        announcement = ""
        canReveal = false
        pendingDegree = ""
        pendingChords = []
    }

    func togglePause() {
        if state == .playing {
            state = .paused
            audioManager.pause()
        } else if state == .paused {
            state = .playing
            audioManager.resume()
        }
    }

    // MARK: - Private Methods

    private func playScale() {
        guard let key = currentKey else { return }

        let scaleNotes: [String]
        if key.mode == .minor {
            // Natural minor scale: la ti do re mi fa sol la
            let degrees = ["la", "ti", "do", "re", "mi", "fa", "sol"]
            scaleNotes = degrees.map { key.solfegeToNote($0, octave: 4) }
                + [key.solfegeToNote("la", octave: 5)]
        } else {
            // Major scale: do re mi fa sol la ti do
            let degrees = ["do", "re", "mi", "fa", "sol", "la", "ti"]
            scaleNotes = degrees.map { key.solfegeToNote($0, octave: 4) }
                + [key.solfegeToNote("do", octave: 5)]
        }

        audioManager.playScale(notes: scaleNotes)
    }

    private func startExerciseLoop() {
        playbackTask = Task { @MainActor in
            while state != .stopped {
                // Wait while paused (unless skipToNext is triggered)
                while state == .paused && !skipToNext {
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 sec
                    if Task.isCancelled { return }
                }

                // Reset skip flag
                skipToNext = false

                await runExercise()

                if Task.isCancelled { return }

                // Wait between exercises (check for skip during wait)
                let waitIterations = Int(waitTimeAfterExercise * 10)
                for _ in 0..<waitIterations {
                    if skipToNext || Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 sec
                }
            }
        }
    }

    private func runExercise() async {
        guard let key = currentKey else { return }

        // Pick a random scale degree
        let degree = diatonicDegrees.randomElement()!
        currentDegree = degree

        // Find chords that contain this degree
        let chords = chordsContainingDegree(degree, enabledChords: enabledChords)

        // If no chords contain this degree, skip
        guard !chords.isEmpty else {
            return
        }

        // Shuffle the chords
        let shuffledChords = chords.shuffled()
        currentChords = shuffledChords

        // 1. Play the melody note alone first
        let melodyNote = key.solfegeToNote(degree, octave: melodyOctave)
        lastMelodyNote = melodyNote
        audioManager.playMelodyOnly(note: melodyNote)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if Task.isCancelled { return }

        // 2. Build and store all chord voicings first
        var allChordVoicings: [[String]] = []
        for chordKey in shuffledChords {
            guard let chord = chordDefinitions[chordKey] else {
                allChordVoicings.append([])
                continue
            }

            var chordNotes: [String] = []
            for chordDegree in chord.degrees {
                if chordDegree != degree {
                    let octave = chordOctaves.randomElement() ?? 3
                    chordNotes.append(key.solfegeToNote(chordDegree, octave: octave))
                }
            }
            allChordVoicings.append(chordNotes)
        }
        lastChordVoicings = allChordVoicings

        // 3. Play each chord with the melody note
        for (index, chordNotes) in allChordVoicings.enumerated() {
            guard state != .stopped else { return }

            // Wait while paused
            while state == .paused {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
            }

            // Play chord with melody
            audioManager.playChordWithMelody(chordNotes: chordNotes, melodyNote: melodyNote)

            // Wait between chords
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
        }

        // 3. Announce and play the answer (or wait for reveal in guitar mode)
        if guitarMode {
            // Store pending reveal data
            pendingDegree = degree
            pendingChords = shuffledChords
            canReveal = true
        } else {
            await announceResults(degree: degree, chords: shuffledChords)
        }
    }

    func revealAnswer() {
        guard canReveal, !pendingDegree.isEmpty else { return }

        canReveal = false
        let degree = pendingDegree
        let chords = pendingChords

        Task { @MainActor in
            await announceResults(degree: degree, chords: chords)
            pendingDegree = ""
            pendingChords = []
        }
    }

    func nextExercise() {
        guard let key = currentKey else { return }

        // Clear pending reveal state
        canReveal = false
        pendingDegree = ""
        pendingChords = []

        // Run the next exercise immediately (staying paused)
        Task { @MainActor in
            await runExercise()
        }
    }

    func repeatExercise() {
        guard !lastMelodyNote.isEmpty, !lastChordVoicings.isEmpty else { return }

        let melodyNote = lastMelodyNote
        let chordVoicings = lastChordVoicings

        Task { @MainActor in
            // Play the melody note alone first
            audioManager.playMelodyOnly(note: melodyNote)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }

            // Play each chord with the exact same voicing
            for chordNotes in chordVoicings {
                audioManager.playChordWithMelody(chordNotes: chordNotes, melodyNote: melodyNote)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
            }

            // Re-enable reveal after repeat
            if guitarMode {
                canReveal = true
            }
        }
    }

    private func announceResults(degree: String, chords: [String]) async {
        guard let key = currentKey else { return }

        let degreePronunciation = solfegePronunciation[degree] ?? degree
        let melodyNote = key.solfegeToNote(degree, octave: melodyOctave)
        let answerDelay = delay / 2  // Half delay for answer section

        // 1. Say the degree
        announcement = degreePronunciation
        await speakText(degreePronunciation)
        try? await Task.sleep(nanoseconds: UInt64(answerDelay * 1_000_000_000))
        if Task.isCancelled { return }

        // 2. Play the degree
        audioManager.playMelodyOnly(note: melodyNote)
        try? await Task.sleep(nanoseconds: UInt64(answerDelay * 1_000_000_000))
        if Task.isCancelled { return }

        // 3. For each chord: say "degree over chord" then play it
        for chordKey in chords {
            guard state != .stopped else { return }

            // Wait while paused
            while state == .paused {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if Task.isCancelled { return }
            }

            guard let chord = chordDefinitions[chordKey] else { continue }

            // Build the announcement text
            let rootPronunciation = solfegePronunciation[chord.root] ?? chord.root
            let chordName: String
            if chordKey == "mi_dom" {
                chordName = "\(rootPronunciation) dominant"
            } else {
                chordName = rootPronunciation
            }

            let text = "\(degreePronunciation), over \(chordName)"
            announcement = text

            // Say "degree over chord"
            await speakText(text)
            try? await Task.sleep(nanoseconds: UInt64(answerDelay * 1_000_000_000))
            if Task.isCancelled { return }

            // Build chord notes (excluding the melody degree to avoid doubling)
            var chordNotes: [String] = []
            for chordDegree in chord.degrees {
                if chordDegree != degree {
                    let octave = chordOctaves.randomElement() ?? 3
                    chordNotes.append(key.solfegeToNote(chordDegree, octave: octave))
                }
            }

            // Play the chord with melody
            audioManager.playChordWithMelody(chordNotes: chordNotes, melodyNote: melodyNote)
            try? await Task.sleep(nanoseconds: UInt64(answerDelay * 1_000_000_000))
            if Task.isCancelled { return }
        }
    }

    private func speakText(_ text: String) async {
        await withCheckedContinuation { continuation in
            speechManager.speak(text) {
                continuation.resume()
            }
        }
    }
}
