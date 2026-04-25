//
//  AudioManager.swift
//  Djangoling
//
//  Handles audio playback using AVFoundation
//

import Foundation
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    private var audioPlayers: [AVAudioPlayer] = []
    private var chordVolume: Float = 0.15
    private var melodyVolume: Float = 1.0

    override init() {
        super.init()
        configureAudioSession()
    }

    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use .playback for background audio, no mixing/ducking options for crisp sound
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func setVolumes(chord: Float, melody: Float) {
        chordVolume = chord
        melodyVolume = melody
    }

    private func loadSound(note: String) -> AVAudioPlayer? {
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: note, withExtension: "mp3") else {
            print("Could not find audio file: \(note).mp3")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Could not load audio file \(note): \(error)")
            return nil
        }
    }

    func playChordAndMelody(chordNotes: [String], melodyNote: String) {
        print("[AudioManager] playChordAndMelody chord=\(chordNotes) melody='\(melodyNote)'")
        // Clean up finished players without stopping active ones
        cleanupFinishedPlayers()

        // Play chord notes
        for note in chordNotes {
            if let player = loadSound(note: note) {
                player.volume = chordVolume
                player.play()
                audioPlayers.append(player)
            } else {
                print("[AudioManager] missing sound for chord note: '\(note)'")
            }
        }

        // Play melody note (skip if empty — caller asking for chord alone)
        if !melodyNote.isEmpty {
            if let player = loadSound(note: melodyNote) {
                player.volume = melodyVolume
                player.play()
                audioPlayers.append(player)
            } else {
                print("[AudioManager] missing sound for melody: '\(melodyNote)'")
            }
        }
    }

    func playMelodyOnly(note: String) {
        print("[AudioManager] playMelodyOnly note='\(note)'")
        // Clean up finished players without stopping active ones
        cleanupFinishedPlayers()

        if let player = loadSound(note: note) {
            player.volume = melodyVolume
            player.play()
            audioPlayers.append(player)
        } else {
            print("[AudioManager] missing sound for melody: '\(note)'")
        }
    }

    private func cleanupFinishedPlayers() {
        audioPlayers.removeAll { !$0.isPlaying }
    }

    func playScale(notes: [String]) {
        stopAll()

        // Play scale notes sequentially
        var delay: TimeInterval = 0
        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                if let player = self?.loadSound(note: note) {
                    player.volume = self?.melodyVolume ?? 1.0
                    player.play()
                    self?.audioPlayers.append(player)
                }
            }
            delay += 0.4
        }
    }

    func stopAll() {
        for player in audioPlayers {
            player.stop()
        }
        audioPlayers.removeAll()
    }

    func pause() {
        for player in audioPlayers {
            player.pause()
        }
    }

    func resume() {
        for player in audioPlayers {
            player.play()
        }
    }
}
