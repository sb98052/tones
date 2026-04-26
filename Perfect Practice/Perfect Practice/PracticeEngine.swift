//
//  PracticeEngine.swift
//  Perfect Practice
//
//  Manages progression loop, exercise rotation, and metronome
//

import Foundation
import Combine
import AVFoundation

enum PlayerState {
    case stopped
    case playing
    case paused
}

class PracticeEngine: ObservableObject {
    // MARK: - Published Properties

    @Published var state: PlayerState = .stopped
    @Published var currentExercise: Exercise?
    @Published var nextExercise: Exercise?
    @Published var currentChordName: String = ""
    @Published var nextChordName: String = ""
    @Published var currentBeat: Int = 0
    @Published var currentRecordingExists: Bool = false
    @Published var nextRecordingExists: Bool = false

    // MARK: - Studio Mode State

    enum StudioEntry {
        case note(chordKey: String, solfege: String, hashKey: String)
        case exercise(exercise: Exercise, chordKey: String)

        var hashKey: String {
            switch self {
            case .note(_, _, let hk): return hk
            case .exercise(let ex, let ck): return ex.recordingHashKey(chordKey: ck)
            }
        }

        var chordKey: String {
            switch self {
            case .note(let ck, _, _): return ck
            case .exercise(_, let ck): return ck
            }
        }
    }

    @Published var studioIndex: Int = 0
    @Published var studioTotal: Int = 0
    @Published var studioRecordedCount: Int = 0
    @Published var studioNoteSolfege: String? = nil  // non-nil when showing a note entry
    private var studioEntries: [StudioEntry] = []
    private var prevRequested = false

    // MARK: - Settings

    var bpm: Double = 120
    var timeSignature: TimeSignature = .fourQuarter
    var enabledExercises: Set<String> = Set(ExerciseCatalog.shared.exercises.map { $0.id })
    var warmUp: Bool = false
    var rotate: Bool = false
    var debugMode: Bool = false
    var playMode: Bool = false
    var soundMode: Bool = false
    var studioMode: Bool = false
    var recordingKeyPitch: Int = 0  // pitch class for saving recordings

    // MARK: - Private Properties

    private var progression: Progression?
    private var playbackTask: Task<Void, Never>?
    private var metronomePlayer: AVAudioPlayer?
    private let catalog = ExerciseCatalog.shared
    private let audioManager = AudioManager.shared
    private let speechManager = SpeechManager.shared
    let recordingManager = RecordingManager()
    private var advanceRequested = false
    private var lastAdvanceTime: Date = .distantPast

    private var beatDuration: TimeInterval {
        60.0 / bpm
    }

    // MARK: - Public Methods

    func start(progressionKey: String) {
        guard let prog = progressions[progressionKey] else { return }

        progression = prog
        state = .playing

        configureAudioSession()
        prepareMetronome()

        // Set initial chord names
        currentChordName = prog.chords[0]
        nextChordName = prog.chords.count > 1 ? prog.chords[1] : prog.chords[0]

        // Generate first exercises based on the first chord
        currentExercise = catalog.generateForChord(currentChordName, enabled: enabledExercises, rotate: rotate)
        nextExercise = catalog.generateForChord(nextChordName, enabled: enabledExercises, rotate: rotate)

        startPlaybackLoop()
    }

    func stop() {
        state = .stopped
        playbackTask?.cancel()
        playbackTask = nil
        metronomePlayer?.stop()
        metronomePlayer = nil
        audioManager.stopAll()
        speechManager.stop()
        recordingManager.cancelRecording()
        recordingManager.stopPlayback()
        currentExercise = nil
        nextExercise = nil
        currentChordName = ""
        nextChordName = ""
        currentBeat = 0
        currentRecordingExists = false
        nextRecordingExists = false
        studioEntries = []
        studioIndex = 0
        studioTotal = 0
        studioRecordedCount = 0
    }

    func togglePause() {
        if state == .playing {
            state = .paused
        } else if state == .paused {
            state = .playing
        }
    }

    func advance() {
        let now = Date()
        guard now.timeIntervalSince(lastAdvanceTime) >= 1.0 else { return }
        lastAdvanceTime = now
        advanceRequested = true
    }

    // MARK: - Private Methods

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            if soundMode {
                try session.setCategory(.playAndRecord, mode: .default,
                                        options: [.defaultToSpeaker, .allowBluetoothHFP])
            } else {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    private func prepareMetronome() {
        var url: URL?
        url = Bundle.main.url(forResource: "metronome", withExtension: "wav")
        if url == nil {
            url = Bundle.main.url(forResource: "metronome", withExtension: "mp3")
        }

        guard let validUrl = url else {
            print("Could not find metronome sound")
            return
        }

        do {
            metronomePlayer = try AVAudioPlayer(contentsOf: validUrl)
            metronomePlayer?.prepareToPlay()
            metronomePlayer?.volume = 0.5
        } catch {
            print("Error preparing metronome: \(error)")
        }
    }

    private func tick() {
        metronomePlayer?.currentTime = 0
        metronomePlayer?.play()
    }

    func studioPrev() {
        prevRequested = true
    }

    private func startPlaybackLoop() {
        if debugMode {
            startDebugLoop()
        } else if studioMode {
            startStudioMode()
        } else if soundMode {
            startSoundModeLoop()
        } else if playMode {
            startPlayLoop()
        } else if warmUp {
            startWarmUpLoop()
        } else {
            startMetronomeLoop()
        }
    }

    // MARK: - Sound Mode Recording Control

    func armRecording() {
        recordingManager.arm()
    }

    func startRecording() {
        if studioMode, let hashKey = currentStudioHashKey {
            recordingManager.startRecording(hashKey: hashKey)
        } else if let exercise = currentExercise {
            let hashKey = exercise.recordingHashKey(chordKey: currentChordName)
            recordingManager.startRecording(hashKey: hashKey)
        }
    }

    func stopRecording() {
        recordingManager.stopRecordingAndSave(sourceKeyPitch: recordingKeyPitch)
        if studioMode {
            updateStudioRecordedCount()
            advance()  // auto-advance after recording
        }
        updateRecordingFlags()
    }

    func playCurrentRecording() {
        let hashKey: String
        if studioMode, let studioKey = currentStudioHashKey {
            hashKey = studioKey
        } else if let exercise = currentExercise {
            hashKey = exercise.recordingHashKey(chordKey: currentChordName)
        } else {
            return
        }
        let targetKeyPitch = pitchClassForKey(keyOfTheDay().key)
        recordingManager.playRecording(hashKey: hashKey, targetKeyPitch: targetKeyPitch)
    }

    func reRecord() {
        guard let exercise = currentExercise else { return }
        let hashKey = exercise.recordingHashKey(chordKey: currentChordName)
        recordingManager.deleteRecording(hashKey: hashKey)
        currentRecordingExists = false
    }

    private func updateRecordingFlags() {
        if let ex = currentExercise {
            currentRecordingExists = recordingManager.recordingExists(
                for: ex.recordingHashKey(chordKey: currentChordName))
        }
        if let ex = nextExercise {
            nextRecordingExists = recordingManager.recordingExists(
                for: ex.recordingHashKey(chordKey: nextChordName))
        }
    }

    private func startSoundModeLoop() {
        playbackTask = Task { @MainActor in
            var isFirstChord = true
            while state != .stopped {
                guard let prog = progression else { break }

                for i in 0..<prog.chords.count {
                    guard state != .stopped else { return }

                    currentChordName = prog.chords[i]
                    let nextIndex = (i + 1) % prog.chords.count
                    nextChordName = prog.chords[nextIndex]

                    if isFirstChord {
                        isFirstChord = false
                    } else {
                        currentExercise = nextExercise
                        nextExercise = catalog.generateForChord(nextChordName, enabled: enabledExercises, rotate: rotate)
                    }

                    updateRecordingFlags()

                    // If recording exists, auto-play it (transposed to current key)
                    if let exercise = currentExercise, currentRecordingExists {
                        let hashKey = exercise.recordingHashKey(chordKey: currentChordName)
                        let targetKeyPitch = pitchClassForKey(keyOfTheDay().key)
                        recordingManager.playRecording(hashKey: hashKey, targetKeyPitch: targetKeyPitch)

                        // Wait for playback to finish
                        while recordingManager.state == .playing {
                            guard state != .stopped else { return }
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if Task.isCancelled { return }
                        }
                    }

                    // Wait for pedal press to advance
                    advanceRequested = false
                    while !advanceRequested {
                        guard state != .stopped else { return }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if Task.isCancelled { return }
                    }
                }
            }
        }
    }

    // MARK: - Studio Mode

    /// Hash key for the current studio entry (for recording)
    var currentStudioHashKey: String? {
        guard studioIndex >= 0 && studioIndex < studioEntries.count else { return nil }
        return studioEntries[studioIndex].hashKey
    }

    private func updateStudioRecordedCount() {
        studioRecordedCount = studioEntries.filter {
            recordingManager.recordingExists(for: $0.hashKey)
        }.count
    }

    private func startStudioMode() {
        guard let prog = progression else { return }

        var entries: [StudioEntry] = []
        let uniqueChords = Array(Set(prog.chords)).sorted()

        // Exercise recordings
        var seenAgnosticHashes: Set<String> = []
        for chord in uniqueChords {
            let specs = catalog.exercisesForChord(chord, enabled: enabledExercises)
            for spec in specs {
                let exercises = spec.generateAll(chordKey: chord, rotate: rotate)
                for ex in exercises {
                    // Deduplicate chord-agnostic exercises (same hash for any chord)
                    if ex.chordAgnostic {
                        let hash = ex.recordingHashKey(chordKey: chord)
                        if seenAgnosticHashes.contains(hash) { continue }
                        seenAgnosticHashes.insert(hash)
                    }
                    entries.append(.exercise(exercise: ex, chordKey: chord))
                }
            }
        }

        // Sort: unrecorded first, then notes before exercises, then by chord, then scale/name order
        let chordOrder = Dictionary(uniqueKeysWithValues: uniqueChords.enumerated().map { ($0.element, $0.offset) })
        let noteOrder: [String: Int] = [
            "do": 0, "di": 1, "ra": 1, "re": 2, "ri": 3, "me": 3, "mi": 4,
            "fa": 5, "fi": 6, "se": 6, "sol": 7, "si": 8, "le": 8,
            "la": 9, "li": 10, "te": 10, "ti": 11
        ]
        entries.sort { a, b in
            let aRec = recordingManager.recordingExists(for: a.hashKey)
            let bRec = recordingManager.recordingExists(for: b.hashKey)
            if aRec != bRec { return !aRec }
            let aIsNote = if case .note = a { true } else { false }
            let bIsNote = if case .note = b { true } else { false }
            if aIsNote != bIsNote { return aIsNote }
            // For notes: sort by chord then scale order
            if aIsNote && bIsNote {
                if case .note(let ac, let as_, _) = a, case .note(let bc, let bs, _) = b {
                    let aco = chordOrder[ac] ?? 99
                    let bco = chordOrder[bc] ?? 99
                    if aco != bco { return aco < bco }
                    return (noteOrder[as_] ?? 99) < (noteOrder[bs] ?? 99)
                }
            }
            let aChord = chordOrder[a.chordKey] ?? 0
            let bChord = chordOrder[b.chordKey] ?? 0
            if aChord != bChord { return aChord < bChord }
            return a.hashKey < b.hashKey
        }

        studioEntries = entries
        studioTotal = entries.count
        updateStudioRecordedCount()
        studioIndex = 0

        playbackTask = Task { @MainActor in
            while state != .stopped {
                guard studioIndex >= 0 && studioIndex < studioEntries.count else {
                    studioIndex = 0
                    continue
                }

                let entry = studioEntries[studioIndex]

                switch entry {
                case .note(let chord, let solfege, _):
                    studioNoteSolfege = solfege
                    currentExercise = nil
                    currentChordName = chord
                case .exercise(let ex, let chord):
                    studioNoteSolfege = nil
                    currentExercise = ex
                    currentChordName = chord
                }

                // Next preview
                if studioIndex + 1 < studioEntries.count {
                    let next = studioEntries[studioIndex + 1]
                    switch next {
                    case .note(let chord, _, _):
                        nextExercise = nil
                        nextChordName = chord
                    case .exercise(let ex, let chord):
                        nextExercise = ex
                        nextChordName = chord
                    }
                } else {
                    nextExercise = nil
                    nextChordName = ""
                }

                currentRecordingExists = recordingManager.recordingExists(for: entry.hashKey)

                // Auto-arm if not yet recorded
                if !currentRecordingExists {
                    recordingManager.arm()
                }

                // Wait for advance or prev
                advanceRequested = false
                prevRequested = false
                while !advanceRequested && !prevRequested {
                    guard state != .stopped else { return }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled { return }
                }

                if prevRequested && studioIndex > 0 {
                    studioIndex -= 1
                } else if advanceRequested {
                    studioIndex += 1
                }

                updateStudioRecordedCount()
            }
        }
    }

    /// Convert solfege notes to playable note filenames using the given key, with ascending octaves
    private func solfegeToNoteNames(_ solfegeNotes: [String], key: Key) -> [String] {
        guard !solfegeNotes.isEmpty else { return [] }

        var result: [String] = []
        var currentOctave = 3
        var lastAbsolute = -1

        for solfege in solfegeNotes {
            let note = key.solfegeToNote(solfege, octave: currentOctave)
            let absolute = Key.absoluteSemitone(note)

            // If this note isn't higher than the last, bump octave
            if absolute <= lastAbsolute {
                currentOctave += 1
                let bumped = key.solfegeToNote(solfege, octave: currentOctave)
                result.append(bumped)
                lastAbsolute = Key.absoluteSemitone(bumped)
            } else {
                result.append(note)
                lastAbsolute = absolute
            }
        }
        return result
    }

    private func startPlayLoop() {
        playbackTask = Task { @MainActor in
            guard let prog = progression else { return }

            let key = Key.random(for: prog.mode)
            print("Play mode — key: \(key.signature[0]) \(prog.mode.rawValue)")

            while state != .stopped {
                for i in 0..<prog.chords.count {
                    guard state != .stopped else { return }

                    // Update chord info
                    currentChordName = prog.chords[i]
                    let nextIndex = (i + 1) % prog.chords.count
                    nextChordName = prog.chords[nextIndex]

                    // Generate exercise (always with rotate for play mode)
                    currentExercise = catalog.generateForChord(
                        currentChordName, enabled: enabledExercises, rotate: true
                    )
                    nextExercise = catalog.generateForChord(
                        nextChordName, enabled: enabledExercises, rotate: true
                    )

                    guard let exercise = currentExercise,
                          !exercise.solfegeNotes.isEmpty else {
                        // Skip exercises without notes
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if Task.isCancelled { return }
                        continue
                    }

                    // Convert solfege to playable note names
                    let noteNames = solfegeToNoteNames(exercise.solfegeNotes, key: key)

                    // Play the notes
                    if exercise.playstyle == "chord" {
                        audioManager.playChord(notes: noteNames)
                        // Wait for chord to ring
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    } else {
                        audioManager.playArpeggio(notes: noteNames)
                        // Wait for arpeggio to complete
                        let duration = audioManager.arpeggioDuration(noteCount: noteNames.count)
                        let nanos = UInt64(duration * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanos)
                    }

                    guard state != .stopped else { return }
                    if Task.isCancelled { return }

                    // Brief pause before announcement
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard state != .stopped else { return }

                    // Announce solfege notes using pronunciation
                    let announcement = exercise.solfegeNotes.map {
                        solfegePronunciation[$0] ?? $0
                    }.joined(separator: ", ")

                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        speechManager.speak(announcement) {
                            continuation.resume()
                        }
                    }

                    guard state != .stopped else { return }
                    if Task.isCancelled { return }

                    // Pause before next exercise
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if Task.isCancelled { return }
                }
            }
        }
    }

    private func startDebugLoop() {
        playbackTask = Task { @MainActor in
            guard let prog = progression else { return }
            let chord = prog.chords[0]
            currentChordName = chord

            let specs = catalog.exercisesForChord(chord, enabled: enabledExercises)
            guard !specs.isEmpty else { return }

            for i in 0..<specs.count {
                guard state != .stopped else { return }

                let spec = specs[i]
                currentExercise = spec.generate(chordKey: chord, rotate: rotate)

                let nextSpec = specs[(i + 1) % specs.count]
                nextChordName = chord
                nextExercise = nextSpec.generate(chordKey: chord, rotate: rotate)

                // Wait for tap to advance
                advanceRequested = false
                while !advanceRequested {
                    guard state != .stopped else { return }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled { return }
                }
            }

            // Done — stop automatically
            stop()
        }
    }

    private func startWarmUpLoop() {
        playbackTask = Task { @MainActor in
            var isFirstChord = true
            while state != .stopped {
                guard let prog = progression else { break }

                for i in 0..<prog.chords.count {
                    guard state != .stopped else { return }

                    // Update chord info
                    currentChordName = prog.chords[i]
                    let nextIndex = (i + 1) % prog.chords.count
                    nextChordName = prog.chords[nextIndex]

                    // Rotate exercises (skip on very first chord - already set in start())
                    if isFirstChord {
                        isFirstChord = false
                    } else {
                        currentExercise = nextExercise
                        nextExercise = catalog.generateForChord(nextChordName, enabled: enabledExercises, rotate: rotate)
                    }

                    // Wait for pedal tap / screen tap
                    advanceRequested = false
                    while !advanceRequested {
                        guard state != .stopped else { return }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if Task.isCancelled { return }
                    }
                }
            }
        }
    }

    private func startMetronomeLoop() {
        playbackTask = Task { @MainActor in
            // Preparation bar: one empty measure of metronome ticks
            let prepBeats = timeSignature.beatsPerMeasure
            for beat in 0..<prepBeats {
                guard state != .stopped else { return }
                while state == .paused {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled { return }
                }
                currentBeat = beat + 1
                tick()
                let beatNanos = UInt64(beatDuration * 1_000_000_000)
                try? await Task.sleep(nanoseconds: beatNanos)
                if Task.isCancelled { return }
            }

            var isFirstChord = true
            while state != .stopped {
                guard let prog = progression else { break }

                for i in 0..<prog.chords.count {
                    guard state != .stopped else { return }

                    // Wait while paused
                    while state == .paused {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if Task.isCancelled { return }
                    }

                    // Update chord info
                    currentChordName = prog.chords[i]
                    let nextIndex = (i + 1) % prog.chords.count
                    nextChordName = prog.chords[nextIndex]

                    // Rotate exercises (skip on very first chord - already set in start())
                    if isFirstChord {
                        isFirstChord = false
                    } else {
                        currentExercise = nextExercise
                        nextExercise = catalog.generateForChord(nextChordName, enabled: enabledExercises, rotate: rotate)
                    }

                    // Play one measure: beat by beat
                    let beatsPerMeasure = timeSignature.beatsPerMeasure
                    for beat in 0..<beatsPerMeasure {
                        guard state != .stopped else { return }

                        while state == .paused {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if Task.isCancelled { return }
                        }

                        currentBeat = beat + 1
                        tick()

                        let beatNanos = UInt64(beatDuration * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: beatNanos)
                        if Task.isCancelled { return }
                    }
                }
            }
        }
    }
}
