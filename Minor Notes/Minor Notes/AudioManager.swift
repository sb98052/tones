//
//  AudioManager.swift
//  Minor Notes
//
//  Handles audio playback for drone and melody notes
//

import Foundation
import AVFoundation

class AudioManager: NSObject {
    static let shared = AudioManager()

    private var dronePlayer: AVAudioPlayer?
    private var melodyPlayer: AVAudioPlayer?

    private override init() {
        super.init()
        configureAudioSession()
    }

    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Drone Playback

    func startDrone(noteName: String) {
        // Stop any existing drone
        stopDrone()

        // Try multiple locations for the drone file
        var url: URL?

        // Try with subdirectory first (folder reference)
        url = Bundle.main.url(forResource: noteName, withExtension: "mp3", subdirectory: "cello")

        // Try without subdirectory (group/flat structure)
        if url == nil {
            url = Bundle.main.url(forResource: noteName, withExtension: "mp3")
        }

        // Try with "cello/" prefix in filename
        if url == nil {
            url = Bundle.main.url(forResource: "cello/\(noteName)", withExtension: "mp3")
        }

        guard let validUrl = url else {
            print("Could not find drone file: \(noteName).mp3")
            return
        }

        do {
            dronePlayer = try AVAudioPlayer(contentsOf: validUrl)
            dronePlayer?.delegate = self
            dronePlayer?.numberOfLoops = -1  // Loop indefinitely
            dronePlayer?.volume = 0.6 * 0.2  // Scale to 20% for balance
            dronePlayer?.prepareToPlay()
            dronePlayer?.play()
        } catch {
            print("Error playing drone: \(error)")
        }
    }

    func stopDrone() {
        dronePlayer?.stop()
        dronePlayer = nil
    }

    func setDroneVolume(_ volume: Float) {
        // Scale to 20% of the input value for better balance with melody
        dronePlayer?.volume = volume * 0.2
    }

    func pauseDrone() {
        dronePlayer?.pause()
    }

    func resumeDrone() {
        dronePlayer?.play()
    }

    // MARK: - Melody Playback

    func playMelodyNote(note: String) {
        // Stop any currently playing melody note
        melodyPlayer?.stop()

        // Try multiple locations for the note file
        var url: URL?

        // Try various subdirectory names (folder reference)
        for subdir in ["piano-mp3", "notes", "tones"] {
            url = Bundle.main.url(forResource: note, withExtension: "mp3", subdirectory: subdir)
            if url != nil { break }
        }

        // Try without subdirectory (group/flat structure)
        if url == nil {
            url = Bundle.main.url(forResource: note, withExtension: "mp3")
        }

        guard let validUrl = url else {
            print("Could not find note file: \(note).mp3")
            return
        }

        do {
            melodyPlayer = try AVAudioPlayer(contentsOf: validUrl)
            melodyPlayer?.volume = 0.8
            melodyPlayer?.prepareToPlay()
            melodyPlayer?.play()
        } catch {
            print("Error playing melody note: \(error)")
        }
    }

    // MARK: - Control

    func stopAll() {
        stopDrone()
        melodyPlayer?.stop()
        melodyPlayer = nil
    }

    func pause() {
        pauseDrone()
        melodyPlayer?.pause()
    }

    func resume() {
        resumeDrone()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // If drone finished (shouldn't happen with -1 loops, but just in case)
        if player == dronePlayer && flag {
            dronePlayer?.play()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
