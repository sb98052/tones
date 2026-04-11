//
//  AudioManager.swift
//  Perfect Practice
//
//  Handles audio playback of exercise notes
//

import Foundation
import Combine
import AVFoundation

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    private var audioPlayers: [AVAudioPlayer] = []
    var volume: Float = 1.0

    override init() {
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

    private func loadSound(note: String) -> AVAudioPlayer? {
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

    /// Play notes simultaneously (chord)
    func playChord(notes: [String]) {
        cleanupFinishedPlayers()
        for note in notes {
            if let player = loadSound(note: note) {
                player.volume = volume
                player.play()
                audioPlayers.append(player)
            }
        }
    }

    /// Play notes sequentially (arpeggio) with delay between each
    func playArpeggio(notes: [String], delay: TimeInterval = 0.4) {
        cleanupFinishedPlayers()
        var offset: TimeInterval = 0
        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + offset) { [weak self] in
                guard let self = self else { return }
                if let player = self.loadSound(note: note) {
                    player.volume = self.volume
                    player.play()
                    self.audioPlayers.append(player)
                }
            }
            offset += delay
        }
    }

    /// Duration of an arpeggio playback
    func arpeggioDuration(noteCount: Int, delay: TimeInterval = 0.4) -> TimeInterval {
        return Double(max(noteCount - 1, 0)) * delay + 0.5 // extra 0.5s for last note to ring
    }

    private func cleanupFinishedPlayers() {
        audioPlayers.removeAll { !$0.isPlaying }
    }

    func stopAll() {
        for player in audioPlayers {
            player.stop()
        }
        audioPlayers.removeAll()
    }
}
