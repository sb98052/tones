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

    // MARK: - Settings

    var bpm: Double = 120
    var timeSignature: TimeSignature = .fourQuarter
    var enabledExercises: Set<String> = Set(ExerciseCatalog.shared.exercises.map { $0.id })
    var warmUp: Bool = false
    var rotate: Bool = false
    var debugMode: Bool = false
    var playMode: Bool = false
    var soundMode: Bool = false

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

    private func startPlaybackLoop() {
        if debugMode {
            startDebugLoop()
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
        guard let exercise = currentExercise else { return }
        let hashKey = exercise.recordingHashKey(chordKey: currentChordName)
        recordingManager.startRecording(hashKey: hashKey)
    }

    func stopRecording() {
        let sourceKeyPitch = pitchClassForKey(keyOfTheDay().key)
        recordingManager.stopRecordingAndSave(sourceKeyPitch: sourceKeyPitch)
        if let exercise = currentExercise {
            currentRecordingExists = recordingManager.recordingExists(
                for: exercise.recordingHashKey(chordKey: currentChordName))
        }
    }

    func playCurrentRecording() {
        guard let exercise = currentExercise else { return }
        let hashKey = exercise.recordingHashKey(chordKey: currentChordName)
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
