//
//  ContentView.swift
//  Djangoling
//
//  Chord Progression Ear Training
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = ProgressionPlayer()

    @State private var selectedProgression = "minor_swing"
    @State private var audiateMode = false
    @State private var noVoice = false
    @State private var guitarMode = false
    @State private var chordMode = false
    @State private var voiceVolume: Double = 0.7
    @State private var delay: Double = 3.0

    private var progressionKeys: [String] {
        Array(progressions.keys).sorted()
    }

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Djangoling")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Current Key Display
            if let key = player.currentKey {
                Text("Key: \(key.tonicNote) \(key.mode.rawValue)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Progression Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Progression")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Progression", selection: $selectedProgression) {
                    ForEach(progressionKeys, id: \.self) { key in
                        Text(progressions[key]?.name ?? key)
                            .tag(key)
                    }
                }
                .pickerStyle(.menu)
                .disabled(player.state != .stopped)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Mode Toggles
            VStack(spacing: 12) {
                Toggle("Audiation Mode", isOn: $audiateMode)
                    .onChange(of: audiateMode) { _, newValue in
                        player.playbackMode = newValue ? .audiation : .recognition
                    }
                    .disabled(player.state != .stopped || guitarMode)

                Toggle("No Voice", isOn: $noVoice)
                    .onChange(of: noVoice) { _, newValue in
                        player.noVoice = newValue
                    }
                    .disabled(player.state != .stopped)

                Toggle("Guitar", isOn: $guitarMode)
                    .onChange(of: guitarMode) { _, newValue in
                        player.guitarMode = newValue
                        // Guitar mode uses recognition-style playback
                        if newValue {
                            audiateMode = false
                            player.playbackMode = .recognition
                        }
                    }
                    .disabled(player.state != .stopped)

                Toggle("Chord Mode", isOn: $chordMode)
                    .onChange(of: chordMode) { _, newValue in
                        player.chordMode = newValue
                    }
                    .disabled(player.state != .stopped)
            }
            .padding(.horizontal)

            // Voice Volume Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Voice Volume: \(Int(voiceVolume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $voiceVolume, in: 0...1)
                    .onChange(of: voiceVolume) { _, newValue in
                        SpeechManager.shared.volume = Float(newValue)
                    }
                    .disabled(noVoice)
            }
            .padding(.horizontal)

            // Delay Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Delay: \(String(format: "%.1f", delay))s")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $delay, in: 1.0...5.0, step: 0.5)
                    .onChange(of: delay) { _, newValue in
                        player.waitTime = newValue
                    }
                    .disabled(player.state != .stopped)
            }
            .padding(.horizontal)

            Spacer()

            // Current Status Display
            if player.state != .stopped {
                VStack(spacing: 8) {
                    Text("Chord: \(player.currentChordName)")
                        .font(.title2)
                        .fontWeight(.medium)

                    if !player.currentLabel.isEmpty {
                        Text(player.currentLabel)
                            .font(.title3)
                            .foregroundColor(.blue)
                    }

                    if player.state == .paused {
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .frame(height: 100)
            } else {
                Spacer()
                    .frame(height: 100)
            }

            Spacer()

            // Guitar mode buttons
            if guitarMode && player.state != .stopped {
                HStack(spacing: 16) {
                    if player.canReveal {
                        Button(action: {
                            player.revealAnswer()
                        }) {
                            Text("Reveal")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }

                    if player.state == .paused {
                        Button(action: {
                            player.repeatChord()
                        }) {
                            Text("Repeat")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            player.nextChord()
                        }) {
                            Text("Next")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
            }

            // Control Buttons
            HStack(spacing: 20) {
                if player.state == .stopped {
                    // Play button
                    Button(action: {
                        player.guitarMode = guitarMode
                        player.chordMode = chordMode
                        player.waitTime = delay
                        player.start(progressionKey: selectedProgression)
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    }
                } else {
                    // Pause/Resume button
                    Button(action: {
                        player.togglePause()
                    }) {
                        Image(systemName: player.state == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }

                    // Stop button
                    Button(action: {
                        player.stop()
                    }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
