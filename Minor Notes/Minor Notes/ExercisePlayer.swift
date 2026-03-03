//
//  ExercisePlayer.swift
//  Minor Notes
//
//  Main playback engine for minor key ear training
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
    @Published var currentKey: MinorKey?
    @Published var currentDegree: String = ""
    @Published var announcement: String = ""

    // MARK: - Settings

    var delay: TimeInterval = 2.0
    var melodyOctave: Int = 4
    var droneVolume: Float = 0.6

    // MARK: - Private Properties

    private var playbackTask: Task<Void, Never>?
    private let audioManager = AudioManager.shared
    private let speechManager = SpeechManager.shared

    // MARK: - Public Methods

    func start() {
        // Pick a random minor key
        currentKey = MinorKey.random()

        guard let key = currentKey else { return }

        state = .playing
        currentDegree = ""
        announcement = ""

        // Start the drone
        audioManager.startDrone(noteName: key.rootNote)
        audioManager.setDroneVolume(droneVolume)

        // Wait a moment for drone to establish, then start exercises
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
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
        announcement = ""
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

    private func startExerciseLoop() {
        playbackTask = Task { @MainActor in
            while state != .stopped {
                // Wait while paused
                while state == .paused {
                    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 sec
                    if Task.isCancelled { return }
                }

                await runExercise()

                if Task.isCancelled { return }
            }
        }
    }

    private func runExercise() async {
        guard let key = currentKey else { return }

        // Pick a random scale degree
        let degree = minorScaleDegrees.randomElement()!
        currentDegree = degree
        announcement = ""

        // Get the actual note to play
        let noteToPlay = key.solfegeToNote(degree, octave: melodyOctave)

        // Play the melody note
        audioManager.playMelodyNote(note: noteToPlay)

        // Wait for the configured delay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if Task.isCancelled { return }

        // Check if still playing (not paused or stopped)
        while state == .paused {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
        }
        if state == .stopped { return }

        // Announce the solfege
        let pronunciation = solfegePronunciation[degree] ?? degree
        announcement = degree
        await speakText(pronunciation)

        // Brief pause before next exercise
        try? await Task.sleep(nanoseconds: UInt64(delay * 0.5 * 1_000_000_000))
    }

    private func speakText(_ text: String) async {
        await withCheckedContinuation { continuation in
            speechManager.speak(text) {
                continuation.resume()
            }
        }
    }
}
