//
//  RecordingManager.swift
//  Perfect Practice
//
//  Records, saves, and plays back exercise audio samples with transposition
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class RecordingManager: ObservableObject {
    enum RecState {
        case idle
        case armed      // mic button tapped, waiting for pedal to start
        case recording
        case playing
    }

    @Published private(set) var state: RecState = .idle

    func arm() {
        guard state == .idle else { return }
        state = .armed
    }

    func disarm() {
        guard state == .armed else { return }
        state = .idle
    }

    // MARK: - Recording Engine (input capture)

    private let recordEngine = AVAudioEngine()
    private var recordedChunks: [AVAudioPCMBuffer] = []
    private var recordingFormat: AVAudioFormat?
    private var sessionConfigured = false
    private var currentHashKey: String?

    // MARK: - Playback Engine (transposed output)

    private let playEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var playbackConfigured = false

    // MARK: - File Management

    private var recordingsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("recordings")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    func fileURL(for hashKey: String) -> URL {
        recordingsDirectory.appendingPathComponent("\(hashKey).wav")
    }

    private func keyFileURL(for hashKey: String) -> URL {
        recordingsDirectory.appendingPathComponent("\(hashKey).key")
    }

    func recordingExists(for hashKey: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: hashKey).path)
    }

    func deleteRecording(hashKey: String) {
        try? FileManager.default.removeItem(at: fileURL(for: hashKey))
        try? FileManager.default.removeItem(at: keyFileURL(for: hashKey))
    }

    // MARK: - Source Key Metadata

    func saveSourceKey(_ pitchClass: Int, for hashKey: String) {
        let url = keyFileURL(for: hashKey)
        try? "\(pitchClass)".write(to: url, atomically: true, encoding: .utf8)
    }

    func loadSourceKey(for hashKey: String) -> Int? {
        let url = keyFileURL(for: hashKey)
        guard let str = try? String(contentsOf: url, encoding: .utf8),
              let pitch = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return pitch
    }

    // MARK: - Audio Session

    private func configureSession() {
        guard !sessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            print("RecordingManager: audio session error: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording(hashKey: String) {
        guard state == .armed else { return }
        configureSession()

        let input = recordEngine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            print("RecordingManager: no audio input available")
            return
        }

        recordingFormat = format
        recordedChunks.removeAll()
        currentHashKey = hashKey

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let copy = buffer.copy() as? AVAudioPCMBuffer else { return }
            Task { @MainActor [weak self] in
                self?.recordedChunks.append(copy)
            }
        }

        do {
            if !recordEngine.isRunning {
                try recordEngine.start()
            }
        } catch {
            input.removeTap(onBus: 0)
            print("RecordingManager: engine start failed: \(error)")
            return
        }

        state = .recording
    }

    func stopRecordingAndSave(sourceKeyPitch: Int) {
        guard state == .recording else { return }
        recordEngine.inputNode.removeTap(onBus: 0)
        if recordEngine.isRunning { recordEngine.stop() }

        guard let format = recordingFormat,
              let hashKey = currentHashKey,
              let buffer = Self.concatenate(chunks: recordedChunks, format: format),
              buffer.frameLength > 0 else {
            state = .idle
            return
        }

        let url = fileURL(for: hashKey)
        do {
            let file = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
            try file.write(from: buffer)
            saveSourceKey(sourceKeyPitch, for: hashKey)
            print("RecordingManager: saved \(hashKey).wav (\(buffer.frameLength) frames, key=\(sourceKeyPitch))")
        } catch {
            print("RecordingManager: save failed: \(error)")
        }

        recordedChunks.removeAll()
        currentHashKey = nil
        state = .idle
    }

    func cancelRecording() {
        if state == .recording {
            recordEngine.inputNode.removeTap(onBus: 0)
            if recordEngine.isRunning { recordEngine.stop() }
            recordedChunks.removeAll()
            currentHashKey = nil
        }
        state = .idle
    }

    // MARK: - Transposed Playback

    private func configurePlaybackEngine() {
        guard !playbackConfigured else { return }

        playEngine.attach(playerNode)
        playEngine.attach(timePitch)

        timePitch.rate = 1.0
        timePitch.pitch = 0

        playEngine.connect(playerNode, to: timePitch, format: nil)
        playEngine.connect(timePitch, to: playEngine.mainMixerNode, format: nil)

        playbackConfigured = true
    }

    /// Play a recording transposed to the target key.
    /// If no source key is stored, plays at original pitch.
    func playRecording(hashKey: String, targetKeyPitch: Int? = nil) {
        guard state == .idle else { return }
        let url = fileURL(for: hashKey)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        configureSession()
        configurePlaybackEngine()

        // Compute transposition
        var semitoneOffset = 0
        if let target = targetKeyPitch, let source = loadSourceKey(for: hashKey) {
            semitoneOffset = nearestTranspose(from: source, to: target)
        }

        timePitch.rate = 1.0
        timePitch.pitch = Float(semitoneOffset * 100)

        do {
            let file = try AVAudioFile(forReading: url)

            playerNode.stop()

            if !playEngine.isRunning {
                try playEngine.start()
            }

            state = .playing

            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    // Don't call playerNode.stop() here — let the timePitch
                    // processor flush its internal buffer naturally
                    self?.state = .idle
                }
            }
            playerNode.play()

            if semitoneOffset != 0 {
                print("RecordingManager: playing \(hashKey) transposed \(semitoneOffset) semitones")
            }
        } catch {
            print("RecordingManager: playback failed: \(error)")
        }
    }

    func stopPlayback() {
        playerNode.stop()
        if state == .playing { state = .idle }
    }

    // MARK: - Buffer Concatenation

    private static func concatenate(chunks: [AVAudioPCMBuffer], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let totalFrames = chunks.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalFrames > 0,
              let combined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return nil
        }

        let channelCount = Int(format.channelCount)
        var writeOffset: AVAudioFrameCount = 0

        for chunk in chunks {
            let frames = chunk.frameLength
            if let src = chunk.floatChannelData, let dst = combined.floatChannelData {
                for ch in 0..<channelCount {
                    memcpy(dst[ch].advanced(by: Int(writeOffset)),
                           src[ch],
                           Int(frames) * MemoryLayout<Float>.size)
                }
            } else if let src = chunk.int16ChannelData, let dst = combined.int16ChannelData {
                for ch in 0..<channelCount {
                    memcpy(dst[ch].advanced(by: Int(writeOffset)),
                           src[ch],
                           Int(frames) * MemoryLayout<Int16>.size)
                }
            }
            writeOffset += frames
        }

        combined.frameLength = totalFrames
        return combined
    }
}
