//
//  ProgressionPlayer.swift
//  Djangoling
//
//  Main playback engine for chord progressions
//

import Foundation
import Combine

enum PlaybackMode {
    case recognition  // Play sound first, then announce
    case audiation    // Announce first, then play
}

enum PlayerState {
    case stopped
    case playing
    case paused
}

class ProgressionPlayer: ObservableObject {
    // MARK: - Published Properties

    @Published var state: PlayerState = .stopped
    @Published var currentChordName: String = ""
    @Published var currentLabel: String = ""
    @Published var currentKey: Key?

    // MARK: - Settings

    var playbackMode: PlaybackMode = .recognition
    var noVoice: Bool = false
    var guitarMode: Bool = false
    var chordOctaves: [Int] = [3, 4]
    var melodyOctaves: [Int] = [5, 6]
    var waitTime: TimeInterval = 3.0
    var chordDuration: TimeInterval = 2.0

    // MARK: - Guitar Mode State

    @Published var canReveal: Bool = false
    private var pendingLabel: String = ""
    private var pendingMelodyNote: String = ""
    private var skipToNext: Bool = false
    private var lastChordNotes: [String] = []
    private var lastMelodyNote: String = ""

    // MARK: - Private Properties

    private var progression: Progression?
    private var chordIndex: Int = 0
    private var playbackTask: Task<Void, Never>?
    private let audioManager = AudioManager.shared
    private let speechManager = SpeechManager.shared

    // MARK: - Public Methods

    func start(progressionKey: String) {
        guard let prog = progressions[progressionKey] else {
            print("Progression not found: \(progressionKey)")
            return
        }

        progression = prog
        currentKey = Key.random(for: prog.mode)
        chordIndex = 0
        state = .playing

        // Play scale first to establish key
        playScale()

        // Start the main loop after scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
            self?.startPlaybackLoop()
        }
    }

    func stop() {
        state = .stopped
        playbackTask?.cancel()
        playbackTask = nil
        audioManager.stopAll()
        speechManager.stop()
        currentChordName = ""
        currentLabel = ""
        canReveal = false
        pendingLabel = ""
        pendingMelodyNote = ""
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

    func revealAnswer() {
        guard canReveal, !pendingLabel.isEmpty else { return }

        canReveal = false
        let label = pendingLabel
        let melodyNote = pendingMelodyNote

        currentLabel = label

        Task { @MainActor in
            // Say the label
            if !noVoice {
                await speakLabel(label)
            }

            // Wait briefly
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 0.5 * 1_000_000_000))

            // Play melody only to confirm the note
            audioManager.playMelodyOnly(note: melodyNote)

            pendingLabel = ""
            pendingMelodyNote = ""
        }
    }

    func nextChord() {
        guard let prog = progression, let key = currentKey else { return }

        // Clear pending reveal state
        canReveal = false
        pendingLabel = ""
        pendingMelodyNote = ""
        currentLabel = ""

        // Move to next chord in progression
        chordIndex = (chordIndex + 1) % prog.chords.count
        let chordName = prog.chords[chordIndex]
        currentChordName = chordName

        // Play it immediately (staying paused)
        Task { @MainActor in
            await playChord(chordName: chordName, key: key)
        }
    }

    func repeatChord() {
        guard !lastChordNotes.isEmpty, !lastMelodyNote.isEmpty else { return }

        // Re-enable reveal
        canReveal = true

        // Replay the exact same chord + melody
        audioManager.playChordAndMelody(chordNotes: lastChordNotes, melodyNote: lastMelodyNote)
    }

    // MARK: - Private Methods

    private func playScale() {
        guard let key = currentKey else { return }

        let scaleNotes: [String]
        if key.mode == .minor {
            // Natural minor scale starting from La
            let degrees = ["la", "ti", "do", "re", "mi", "fa", "sol"]
            scaleNotes = degrees.map { key.solfegeToNote($0, octave: 4) }
                + [key.solfegeToNote("la", octave: 5)]
        } else {
            // Major scale starting from Do
            let degrees = ["do", "re", "mi", "fa", "sol", "la", "ti"]
            scaleNotes = degrees.map { key.solfegeToNote($0, octave: 4) }
                + [key.solfegeToNote("do", octave: 5)]
        }

        audioManager.playScale(notes: scaleNotes)
    }

    private func startPlaybackLoop() {
        playbackTask = Task { @MainActor in
            while state != .stopped {
                guard let prog = progression, let key = currentKey else { break }

                // Loop through progression
                for i in 0..<prog.chords.count {
                    guard state != .stopped else { break }

                    // Wait while paused (unless skipToNext is triggered)
                    while state == .paused && !skipToNext {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
                        if Task.isCancelled { return }
                    }

                    // Reset skip flag
                    skipToNext = false

                    let chordName = prog.chords[i]
                    chordIndex = i
                    currentChordName = chordName

                    await playChord(chordName: chordName, key: key)

                    if Task.isCancelled { return }
                }
            }
        }
    }

    private func playChord(chordName: String, key: Key) async {
        guard let chordDef = chordDefinitions[chordName] else { return }

        // Get chord notes
        let chordNotes = getChordNotes(chordDef: chordDef, key: key)

        // Get random melody note
        let melody = getRandomMelodyNote(chordDef: chordDef, key: key)
        currentLabel = guitarMode ? "" : melody.label  // Hide label in guitar mode until reveal

        let chordMelodyDur = chordDuration * 0.35
        let melodyOnlyDur = chordDuration * 0.25

        if guitarMode {
            // Guitar mode: play sounds but don't reveal the answer
            // Store pending reveal data
            pendingLabel = melody.label
            pendingMelodyNote = melody.noteName
            canReveal = true
            // Store for repeat
            lastChordNotes = chordNotes
            lastMelodyNote = melody.noteName

            // 1. Play chord + melody (the question)
            audioManager.playChordAndMelody(chordNotes: chordNotes, melodyNote: melody.noteName)
            try? await Task.sleep(nanoseconds: UInt64(chordMelodyDur * 1_000_000_000))
            if Task.isCancelled { return }

            // 2. Wait for user to process/guess
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            if Task.isCancelled { return }

            // In guitar mode, we stop here and wait for next chord
            // User can press Reveal at any time to hear the answer

        } else if playbackMode == .audiation {
            // Audiation mode: announce first, then play melody alone, then with chord

            // 1. Say/show label FIRST
            if !noVoice {
                await speakLabel(melody.label)
            }

            // 2. Wait (time for anticipation/audiation)
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            if Task.isCancelled { return }

            // 3. Play melody only FIRST
            audioManager.playMelodyOnly(note: melody.noteName)
            try? await Task.sleep(nanoseconds: UInt64(melodyOnlyDur * 1_000_000_000))
            if Task.isCancelled { return }

            // 4. Wait
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            if Task.isCancelled { return }

            // 5. Play chord + melody together
            audioManager.playChordAndMelody(chordNotes: chordNotes, melodyNote: melody.noteName)
            try? await Task.sleep(nanoseconds: UInt64(chordMelodyDur * 1_000_000_000))
            if Task.isCancelled { return }

            // 6. Wait after chord+melody
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        } else {
            // Standard recognition mode: play first, then announce

            // 1. Play chord + melody
            audioManager.playChordAndMelody(chordNotes: chordNotes, melodyNote: melody.noteName)
            try? await Task.sleep(nanoseconds: UInt64(chordMelodyDur * 1_000_000_000))
            if Task.isCancelled { return }

            // 2. Wait
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            if Task.isCancelled { return }

            // 3. Say label
            if !noVoice {
                await speakLabel(melody.label)
            }

            // 4. Wait
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            if Task.isCancelled { return }

            // 5. Play melody only
            audioManager.playMelodyOnly(note: melody.noteName)
            try? await Task.sleep(nanoseconds: UInt64(melodyOnlyDur * 1_000_000_000))
            if Task.isCancelled { return }

            // 6. Wait after melody
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }

        // Let sounds decay naturally - don't stop abruptly
    }

    private func getChordNotes(chordDef: ChordDefinition, key: Key) -> [String] {
        var notes: [String] = []
        for deg in chordDef.degrees.prefix(3) { // Take first 3 for triad
            let octave = chordOctaves.randomElement() ?? 3
            notes.append(key.solfegeToNote(deg, octave: octave))
        }
        return notes
    }

    private func getRandomMelodyNote(chordDef: ChordDefinition, key: Key) -> MelodyNote {
        let degrees = chordDef.degrees
        let quality = chordDef.quality

        // Pick random chord tone
        let degreeIndex = Int.random(in: 0..<degrees.count)
        let chosenDegree = degrees[degreeIndex]

        let octave = melodyOctaves.randomElement() ?? 5
        let noteName = key.solfegeToNote(chosenDegree, octave: octave)

        // Get root of the chord (first degree)
        let rootDegree = degrees[0]

        // Create label with pronunciation - "note, over root, quality"
        // Commas create natural pauses in text-to-speech
        let pronunciation = solfegePronunciation[chosenDegree] ?? chosenDegree
        let rootPronunciation = solfegePronunciation[rootDegree] ?? rootDegree
        let label = "\(pronunciation), over \(rootPronunciation), \(quality.rawValue)"

        return MelodyNote(
            noteName: noteName,
            label: label,
            degree: chosenDegree,
            position: rootDegree,  // Now stores root instead of position
            quality: quality
        )
    }

    private func speakLabel(_ label: String) async {
        await withCheckedContinuation { continuation in
            speechManager.speak(label) {
                continuation.resume()
            }
        }
    }
}
