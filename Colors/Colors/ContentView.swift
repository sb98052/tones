//
//  ContentView.swift
//  Colors
//
//  Harmonic Colors Ear Training
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = ExercisePlayer()

    @State private var selectedMode: Mode = .major
    @State private var enabledChords: Set<String> = Set(chordKeys)
    @State private var voiceVolume: Double = 0.5
    @State private var delay: Double = 3.0
    @State private var guitarMode: Bool = false
    @State private var chordsOnly: Bool = true
    @State private var chordMode: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Colors")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Current Key Display
            if let key = player.currentKey {
                Text("Key: \(key.tonicNote) \(key.mode.rawValue)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Mode Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Mode", selection: $selectedMode) {
                    ForEach(Mode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(player.state != .stopped)
                .onChange(of: selectedMode) { _, newValue in
                    player.mode = newValue
                }
            }
            .padding(.horizontal)

            // Chord Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Enabled Chords")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(chordKeys, id: \.self) { chordKey in
                        ChordToggle(
                            chordKey: chordKey,
                            isEnabled: enabledChords.contains(chordKey),
                            isDisabled: player.state != .stopped
                        ) { enabled in
                            if enabled {
                                enabledChords.insert(chordKey)
                            } else {
                                enabledChords.remove(chordKey)
                            }
                            player.enabledChords = enabledChords
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Delay Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Delay: \(String(format: "%.1f", delay))s")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $delay, in: 0.5...5.0, step: 0.1)
                    .onChange(of: delay) { _, newValue in
                        player.delay = newValue
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
                        SpeechManager.shared.volume = Float(newValue) * 0.2
                    }
            }
            .padding(.horizontal)

            // Mode Toggles
            VStack(spacing: 12) {
                Toggle("Guitar", isOn: $guitarMode)
                    .onChange(of: guitarMode) { _, newValue in
                        player.guitarMode = newValue
                    }
                    .disabled(player.state != .stopped)

                Toggle("Chords Only", isOn: $chordsOnly)
                    .onChange(of: chordsOnly) { _, newValue in
                        player.skipNakedNote = newValue
                    }
                    .disabled(player.state != .stopped)

                Toggle("Chord Mode", isOn: $chordMode)
                    .onChange(of: chordMode) { _, newValue in
                        player.chordMode = newValue
                    }
                    .disabled(player.state != .stopped)
            }
            .padding(.horizontal)

            Spacer()

            // Current Status Display
            if player.state != .stopped {
                VStack(spacing: 8) {
                    if !player.currentDegree.isEmpty {
                        Text("Degree: \(player.currentDegree)")
                            .font(.title2)
                            .fontWeight(.medium)
                    }

                    if !player.announcement.isEmpty {
                        Text(player.announcement)
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
                .frame(height: 80)
            } else {
                Spacer()
                    .frame(height: 80)
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
                            player.repeatExercise()
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
                            player.nextExercise()
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
                        player.enabledChords = enabledChords
                        player.mode = selectedMode
                        player.delay = delay
                        player.guitarMode = guitarMode
                        player.skipNakedNote = chordsOnly
                        player.chordMode = chordMode
                        player.start()
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    }
                    .disabled(enabledChords.isEmpty)
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

// MARK: - Chord Toggle Button

struct ChordToggle: View {
    let chordKey: String
    let isEnabled: Bool
    let isDisabled: Bool
    let onToggle: (Bool) -> Void

    var displayName: String {
        chordDefinitions[chordKey]?.name ?? chordKey
    }

    var body: some View {
        Button(action: {
            onToggle(!isEnabled)
        }) {
            Text(displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isEnabled ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isEnabled ? .white : .primary)
                .cornerRadius(8)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

#Preview {
    ContentView()
}
