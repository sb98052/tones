//
//  ContentView.swift
//  Perfect Practice
//
//  Split-screen practice with chord progressions and exercises
//

import SwiftUI
import UIKit

// MARK: - UIKit Key Press Catcher

class KeyPressViewController: UIViewController {
    var onKeyPress: ((UIPress) -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            onKeyPress?(press)
        }
    }
}

struct KeyPressView: UIViewControllerRepresentable {
    var onKeyPress: (UIPress) -> Void

    func makeUIViewController(context: Context) -> KeyPressViewController {
        let vc = KeyPressViewController()
        vc.onKeyPress = onKeyPress
        return vc
    }

    func updateUIViewController(_ vc: KeyPressViewController, context: Context) {
        vc.onKeyPress = onKeyPress
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var engine = PracticeEngine()

    @State private var selectedProgression = "minor_swing"
    @State private var bpm: Double = 120
    @State private var selectedTimeSignature: TimeSignature = .fourQuarter
    @State private var enabledExercises: Set<String> = Set(ExerciseCatalog.shared.exercises.map { $0.id })
    @State private var warmUp = true
    @State private var rotate = false
    @ObservedObject private var catalog = ExerciseCatalog.shared

    private var progressionKeys: [String] {
        Array(progressions.keys).sorted()
    }

    var body: some View {
        Group {
            if engine.state == .stopped {
                TabView {
                    settingsView
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                    exercisesView
                        .tabItem {
                            Label("Exercises", systemImage: "list.bullet")
                        }
                }
            } else {
                practiceView
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            catalog.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            catalog.refresh()
        }
        .onReceive(catalog.$exercises) { newExercises in
            // Enable new exercises by default
            let newIds = Set(newExercises.map { $0.id })
            enabledExercises = enabledExercises.union(newIds.subtracting(enabledExercises))
        }
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 20) {
            Text("Perfect Practice")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Progression Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Progression")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Progression", selection: $selectedProgression) {
                    ForEach(progressionKeys, id: \.self) { key in
                        Text(progressions[key]?.name ?? key).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // Time Signature Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Signature")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Time Signature", selection: $selectedTimeSignature) {
                    ForEach(TimeSignature.allCases, id: \.self) { sig in
                        Text(sig.rawValue).tag(sig)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)

            // BPM Slider
            VStack(alignment: .leading, spacing: 8) {
                Text("BPM: \(Int(bpm))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Slider(value: $bpm, in: 40...200, step: 5)
            }
            .padding(.horizontal)

            // Warm Up toggle
            Toggle("Warm Up", isOn: $warmUp)
                .padding(.horizontal)

            // Rotate toggle
            Toggle("Rotate", isOn: $rotate)
                .padding(.horizontal)

            Spacer()

            // Play button
            Button(action: {
                engine.bpm = bpm
                engine.timeSignature = selectedTimeSignature
                engine.enabledExercises = enabledExercises
                engine.warmUp = warmUp
                engine.rotate = rotate
                engine.start(progressionKey: selectedProgression)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            .disabled(enabledExercises.isEmpty)
            .padding(.bottom, 40)
        }
        .padding()
    }

    // MARK: - Exercises View

    private var exercisesView: some View {
        List {
            ForEach(catalog.exercises) { spec in
                Toggle(spec.name, isOn: Binding(
                    get: { enabledExercises.contains(spec.id) },
                    set: { enabled in
                        if enabled {
                            enabledExercises.insert(spec.id)
                        } else {
                            enabledExercises.remove(spec.id)
                        }
                    }
                ))
            }
        }
        .navigationTitle("Exercises")
    }

    // MARK: - Practice View

    private var practiceView: some View {
        VStack(spacing: 0) {
            // Top half: current
            exerciseCard(
                exercise: engine.currentExercise,
                chordName: displayName(for: engine.currentChordName),
                color: .blue,
                isLarge: true
            )
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom half: next
            exerciseCard(
                exercise: engine.nextExercise,
                chordName: displayName(for: engine.nextChordName),
                color: .gray,
                isLarge: false
            )
            .frame(maxHeight: .infinity)

            if engine.state == .paused {
                Text("PAUSED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }

            // Control Buttons
            HStack(spacing: 20) {
                Button(action: { engine.togglePause() }) {
                    Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }

                Button(action: { engine.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if engine.warmUp {
                engine.advance()
            }
        }
        .background(
            KeyPressView { _ in
                if engine.warmUp {
                    engine.advance()
                }
            }
        )
    }

    // MARK: - Exercise Card

    private func exerciseCard(
        exercise: Exercise?,
        chordName: String,
        color: Color,
        isLarge: Bool
    ) -> some View {
        VStack(spacing: isLarge ? 10 : 6) {
            // Chord name
            Text(chordName)
                .font(isLarge ? .title2 : .callout)
                .fontWeight(.bold)
                .foregroundColor(color)

            if let exercise = exercise {
                // Symbol + Name + Direction on one line
                let title = [exercise.symbol, exercise.typeName, exercise.titleSuffix]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                Text(title)
                    .font(isLarge ? .title3 : .subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                // Remaining atom lines (position, pattern, multiselect)
                ForEach(Array(exercise.displayLines.enumerated()), id: \.offset) { _, line in
                    HStack {
                        Text(line.label)
                            .font(isLarge ? .body : .caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(line.value)
                            .font(isLarge ?
                                  (line.emphasis ? .system(size: 48, weight: .bold) : .title3) :
                                  (line.emphasis ? .system(size: 32, weight: .bold) : .body))
                            .foregroundColor(line.emphasis ? color : .primary)
                    }
                }

                // Solfege notes with inline start note highlighting
                if !exercise.solfegeNotes.isEmpty {
                    solfegeNotesView(
                        notes: exercise.solfegeNotes,
                        startIndex: exercise.startNoteIndex,
                        color: color,
                        isLarge: isLarge
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func solfegeNotesView(
        notes: [String],
        startIndex: Int?,
        color: Color,
        isLarge: Bool
    ) -> some View {
        // Wrap notes in a flowing layout
        let noteFont: Font = isLarge ? .title3 : .caption
        let highlightFont: Font = isLarge ? .system(size: 28, weight: .bold) : .system(size: 16, weight: .bold)

        return HStack(spacing: isLarge ? 8 : 4) {
            ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                if index == startIndex {
                    Text(note.uppercased())
                        .font(highlightFont)
                        .foregroundColor(color)
                } else {
                    Text(note)
                        .font(noteFont)
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
