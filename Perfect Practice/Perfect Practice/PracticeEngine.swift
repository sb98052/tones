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

    // MARK: - Settings

    var bpm: Double = 120
    var timeSignature: TimeSignature = .fourQuarter
    var enabledExercises: Set<String> = Set(ExerciseCatalog.shared.exercises.map { $0.id })
    var warmUp: Bool = false
    var rotate: Bool = false

    // MARK: - Private Properties

    private var progression: Progression?
    private var playbackTask: Task<Void, Never>?
    private var metronomePlayer: AVAudioPlayer?
    private let catalog = ExerciseCatalog.shared
    private var advanceRequested = false

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
        currentExercise = nil
        nextExercise = nil
        currentChordName = ""
        nextChordName = ""
        currentBeat = 0
    }

    func togglePause() {
        if state == .playing {
            state = .paused
        } else if state == .paused {
            state = .playing
        }
    }

    func advance() {
        advanceRequested = true
    }

    // MARK: - Private Methods

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
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
        if warmUp {
            startWarmUpLoop()
        } else {
            startMetronomeLoop()
        }
    }

    private func startWarmUpLoop() {
        playbackTask = Task { @MainActor in
            while state != .stopped {
                guard let prog = progression else { break }

                for i in 0..<prog.chords.count {
                    guard state != .stopped else { return }

                    // Update chord info
                    currentChordName = prog.chords[i]
                    let nextIndex = (i + 1) % prog.chords.count
                    nextChordName = prog.chords[nextIndex]

                    // Rotate exercises (skip on first chord - already set in start())
                    if i > 0 {
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

                    // Rotate exercises (skip on first chord - already set in start())
                    if i > 0 {
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
