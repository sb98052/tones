//
//  ContentView.swift
//  Minor Notes
//
//  Minor key ear training with cello drone
//

import SwiftUI

struct ContentView: View {
    @StateObject private var player = ExercisePlayer()

    @State private var delay: Double = 2.0
    @State private var voiceVolume: Double = 0.7
    @State private var droneVolume: Double = 0.6

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Minor Notes")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Current Key Display
            if let key = player.currentKey {
                Text("Key: \(key.rootNote) minor")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            // Delay Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Delay: \(String(format: "%.1f", delay))s")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $delay, in: 0.5...5.0, step: 0.5)
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
                        SpeechManager.shared.volume = Float(newValue)
                    }
            }
            .padding(.horizontal)

            // Drone Volume Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("Drone Volume: \(Int(droneVolume * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $droneVolume, in: 0...1)
                    .onChange(of: droneVolume) { _, newValue in
                        AudioManager.shared.setDroneVolume(Float(newValue))
                    }
            }
            .padding(.horizontal)

            Spacer()

            // Current Status Display
            if player.state != .stopped {
                VStack(spacing: 12) {
                    if !player.currentDegree.isEmpty {
                        Text("Note Playing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !player.announcement.isEmpty {
                        Text(player.announcement)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.blue)
                    }

                    if player.state == .paused {
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .frame(height: 120)
            } else {
                Spacer()
                    .frame(height: 120)
            }

            Spacer()

            // Control Buttons
            HStack(spacing: 20) {
                if player.state == .stopped {
                    // Play button
                    Button(action: {
                        player.delay = delay
                        player.droneVolume = Float(droneVolume)
                        player.start()
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
