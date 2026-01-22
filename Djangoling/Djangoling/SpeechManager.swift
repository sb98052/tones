//
//  SpeechManager.swift
//  Djangoling
//
//  Handles text-to-speech using AVSpeechSynthesizer
//

import Foundation
import AVFoundation

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = SpeechManager()

    private let synthesizer = AVSpeechSynthesizer()
    private var onComplete: (() -> Void)?

    @Published var isSpeaking = false
    var volume: Float = 0.7

    override init() {
        super.init()
        synthesizer.delegate = self

        // Use audio session that doesn't duck other audio
        if #available(iOS 16.0, *) {
            synthesizer.usesApplicationAudioSession = true
        }
    }

    func speak(_ text: String, completion: (() -> Void)? = nil) {
        onComplete = completion

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = volume

        // Disable pre/post utterance delays for crisp speech
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false

        DispatchQueue.main.async {
            self.onComplete?()
            self.onComplete = nil
        }
    }
}
