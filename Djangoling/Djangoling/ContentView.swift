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
                    .disabled(player.state != .stopped)

                Toggle("No Voice", isOn: $noVoice)
                    .onChange(of: noVoice) { _, newValue in
                        player.noVoice = newValue
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

            // Control Buttons
            HStack(spacing: 20) {
                if player.state == .stopped {
                    // Play button
                    Button(action: {
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
