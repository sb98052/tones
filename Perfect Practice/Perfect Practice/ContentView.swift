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
    @StateObject private var voiceCommands = VoiceCommandManager()
    @ObservedObject private var recordingMgr: RecordingManager

    init() {
        let eng = PracticeEngine()
        _engine = StateObject(wrappedValue: eng)
        _voiceCommands = StateObject(wrappedValue: VoiceCommandManager())
        _recordingMgr = ObservedObject(wrappedValue: eng.recordingManager)
    }

    @State private var selectedProgression = "minor_swing"
    @State private var bpm: Double = 120
    @State private var selectedTimeSignature: TimeSignature = .fourQuarter
    @State private var enabledExercises: Set<String> = Set(ExerciseCatalog.shared.exercises.filter { !$0.disabled }.map { $0.id })
    @State private var warmUp = true
    @State private var rotate = true
    @State private var playMode = false
    @State private var soundMode = true
    @State private var showRelativeMinor = false
    @ObservedObject private var catalog = ExerciseCatalog.shared

    private var progressionKeys: [String] {
        Array(progressions.keys).sorted()
    }

    private var chordStyles: [String: ChordStyle] {
        guard let prog = progressions[selectedProgression] else { return [:] }
        return chordStyleMap(for: prog)
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
        .alert("Exercise Parse Error", isPresented: Binding(
            get: { catalog.parseError != nil },
            set: { if !$0 { catalog.parseError = nil } }
        )) {
            Button("OK") { catalog.parseError = nil }
        } message: {
            Text(catalog.parseError ?? "")
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            catalog.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            catalog.refresh()
        }
        .onReceive(catalog.$exercises) { newExercises in
            // Enable new non-disabled exercises by default
            let newIds = Set(newExercises.filter { !$0.disabled }.map { $0.id })
            let disabledIds = Set(newExercises.filter { $0.disabled }.map { $0.id })
            enabledExercises = enabledExercises.union(newIds.subtracting(enabledExercises)).subtracting(disabledIds)
        }
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 20) {
            Text("Perfect Practice")
                .font(.largeTitle)
                .fontWeight(.bold)
                .onLongPressGesture(minimumDuration: 2) {
                    engine.bpm = bpm
                    engine.timeSignature = selectedTimeSignature
                    engine.enabledExercises = enabledExercises
                    engine.warmUp = true
                    engine.rotate = rotate
                    engine.playMode = false
                    engine.debugMode = true
                    engine.start(progressionKey: selectedProgression)
                    voiceCommands.onCommand = { engine.advance() }
                    voiceCommands.startListening()
                }

            // Key of the day (tap to flip major/relative minor)
            let kotd = keyOfTheDay()
            let sig = kotd.key.signature
            let majorName = "\(sig[0])maj"
            let minorName = "\(sig[5])m"
            Text(showRelativeMinor ? minorName : majorName)
                .font(.title3)
                .foregroundColor(.secondary)
                .onTapGesture { showRelativeMinor.toggle() }

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

            // Play (ear training) toggle
            Toggle("Play", isOn: $playMode)
                .padding(.horizontal)

            // Sound (recording-based) toggle
            Toggle("Sound", isOn: $soundMode)
                .padding(.horizontal)

            Spacer()

            // Play button
            Button(action: {
                engine.bpm = bpm
                engine.timeSignature = selectedTimeSignature
                engine.enabledExercises = enabledExercises
                engine.warmUp = warmUp
                engine.rotate = rotate
                engine.playMode = playMode
                engine.soundMode = soundMode
                engine.debugMode = false
                engine.start(progressionKey: selectedProgression)
                if !soundMode {
                    voiceCommands.onCommand = { engine.advance() }
                    voiceCommands.startListening()
                }
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
            ForEach(catalog.exercises.filter { !$0.disabled }) { spec in
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

    @State private var showCurrentLabel = false
    @State private var showNextLabel = false

    private var practiceView: some View {
        VStack(spacing: 0) {
            // Top half: current
            exerciseGraphicCard(
                exercise: engine.currentExercise,
                chordKey: engine.currentChordName,
                showLabel: $showCurrentLabel,
                recordingExists: engine.soundMode ? engine.currentRecordingExists : false,
                isSoundMode: engine.soundMode
            )
            .frame(maxHeight: .infinity)

            Divider()

            // Bottom half: next
            exerciseGraphicCard(
                exercise: engine.nextExercise,
                chordKey: engine.nextChordName,
                showLabel: $showNextLabel,
                recordingExists: engine.soundMode ? engine.nextRecordingExists : false,
                isSoundMode: engine.soundMode
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

                Button(action: {
                    voiceCommands.stopListening()
                    engine.stop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
            }
            .padding(.bottom, 40)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if engine.soundMode {
                // In sound mode, tap reveals the exercise or advances
                if engine.currentRecordingExists {
                    showCurrentLabel = true
                } else {
                    engine.advance()
                }
            } else if engine.warmUp || engine.debugMode {
                engine.advance()
            }
        }
        .background(
            KeyPressView { press in
                let isLeftPedal = press.key?.keyCode == .keyboardUpArrow
                let isRightPedal = press.key?.keyCode == .keyboardDownArrow

                if engine.soundMode {
                    if isLeftPedal {
                        // Left pedal: start/stop recording when armed
                        if recordingMgr.state == .armed {
                            engine.startRecording()
                        } else if recordingMgr.state == .recording {
                            engine.stopRecording()
                        } else {
                            engine.advance()
                        }
                    } else {
                        // Right pedal or any other key: advance
                        engine.advance()
                    }
                } else if engine.warmUp || engine.debugMode {
                    engine.advance()
                }
            }
        )
    }

    // MARK: - Graphic Card

    private func exerciseGraphicCard(
        exercise: Exercise?,
        chordKey: String,
        showLabel: Binding<Bool>,
        recordingExists: Bool = false,
        isSoundMode: Bool = false
    ) -> some View {
        Group {
            if let exercise = exercise {
                let style = chordStyles[chordKey] ?? ChordStyle(color: .gray, dashed: false)
                let graphic = parseGraphic(exercise: exercise, chordKey: chordKey, style: style)

                if isSoundMode && recordingExists && !showLabel.wrappedValue {
                    // Sound mode with recording: hidden graphic, show chord key + speaker
                    VStack(spacing: 12) {
                        Image(systemName: recordingMgr.state == .playing ? "speaker.wave.2.fill" : "speaker.fill")
                            .font(.system(size: 40))
                            .foregroundColor(style.color)
                        Text(displayName(for: chordKey))
                            .font(.title2)
                            .foregroundColor(style.color)
                    }
                    .onTapGesture {
                        showLabel.wrappedValue = true
                    }
                } else {
                    // Normal mode, or sound mode without recording, or revealed
                    ExerciseGraphicView(graphic: graphic)
                        .overlay(alignment: .topTrailing) {
                            if isSoundMode {
                                HStack(spacing: 8) {
                                    // Play button (if recording exists)
                                    if recordingExists {
                                        Button(action: { engine.playCurrentRecording() }) {
                                            Image(systemName: recordingMgr.state == .playing
                                                  ? "speaker.wave.2.fill" : "play.circle")
                                                .font(.system(size: 24))
                                                .foregroundColor(.green.opacity(0.7))
                                        }
                                    }

                                    // Record button
                                    Button(action: {
                                        if recordingMgr.state == .recording {
                                            engine.stopRecording()
                                        } else if recordingMgr.state == .armed {
                                            recordingMgr.disarm()
                                        } else {
                                            engine.armRecording()
                                        }
                                    }) {
                                        if recordingMgr.state == .recording {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 20, height: 20)
                                        } else if recordingMgr.state == .armed {
                                            Image(systemName: "mic.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(.red)
                                        } else {
                                            Image(systemName: "mic.circle")
                                                .font(.system(size: 28))
                                                .foregroundColor(.red.opacity(0.5))
                                        }
                                    }
                                }
                                .padding(12)
                            }
                        }
                    .onTapGesture {
                        if isSoundMode && recordingExists {
                            // Revealed state: tap again to hide
                            showLabel.wrappedValue = false
                        } else {
                            showLabel.wrappedValue = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showLabel.wrappedValue = false
                            }
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if showLabel.wrappedValue {
                            VStack(spacing: 4) {
                                Text(graphic.exerciseLabel)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                if let degree = graphic.chordDegree {
                                    chordDegreeOverlay(degree: degree, color: graphic.chordColor)
                                }
                                if isSoundMode && recordingExists {
                                    Button(action: { engine.reRecord() }) {
                                        Label("Re-record", systemImage: "mic.badge.xmark")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 4)
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showLabel.wrappedValue)
                }
            }
        }
        .padding(12)
    }

    private func chordDegreeOverlay(degree: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            ForEach(1...7, id: \.self) { d in
                RoundedRectangle(cornerRadius: 2)
                    .fill(d == degree ? color : Color.clear)
                    .frame(width: 14, height: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(d == degree ? color : Color.gray.opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Parse Exercise → Graphic

    private func parseGraphic(exercise: Exercise, chordKey: String, style: ChordStyle) -> ExerciseGraphicData {
        // Direction from titleSuffix or multiselect lines
        let direction = parseDirection(exercise: exercise)

        // Position rows
        let positionRows = parsePositionRows(exercise: exercise)

        // Start note (chord tone)
        let startNote = exercise.startNote?.uppercased()

        // Chord degree
        let root = chordRoot(chordKey)
        let degree = solfegeToDegree[root]

        // Permutation
        let permutation = parsePermutation(exercise: exercise)

        // Label for tap
        let label = [exercise.symbol, exercise.typeName, exercise.titleSuffix]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return ExerciseGraphicData(
            direction: direction,
            positionRows: positionRows,
            startNote: startNote,
            symbol: exercise.symbol,
            category: exercise.category,
            chordDegree: degree,
            chordColor: style.color,
            dashed: style.dashed,
            permutation: permutation,
            exerciseLabel: label
        )
    }

    private func parseDirection(exercise: Exercise) -> SignDirection {
        let suffix = exercise.titleSuffix.lowercased()
        if !suffix.isEmpty {
            if suffix == "up" { return .up }
            if suffix == "down" { return .down }
            if suffix.contains("up") && suffix.contains("down") {
                return suffix.hasPrefix("up") ? .upDown : .downUp
            }
            // Single multiselect folded into suffix: "2 up"
            if suffix.hasSuffix("up") { return .up }
            if suffix.hasSuffix("down") { return .down }
        }
        // Check multiselect display lines for direction
        for line in exercise.displayLines {
            let val = line.value.lowercased()
            if val.contains("up") { return .up }
            if val.contains("down") { return .down }
        }
        return .none
    }

    private func parsePositionRows(exercise: Exercise) -> [[PositionDot]] {
        var rows: [[PositionDot]] = []
        let maxPos = exercise.maxPosition

        for line in exercise.displayLines {
            switch line.label {
            case "Position":
                if let pos = Int(line.value.trimmingCharacters(in: .whitespaces)) {
                    rows.append(makeDotRow(selected: [pos], maxPos: maxPos, colors: [.green]))
                }
            case "Positions":
                let parts = line.value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if parts.count >= 2 {
                    rows.append(makeDotRow(selected: parts, maxPos: maxPos, colors: [.green, .red]))
                } else if let p = parts.first {
                    rows.append(makeDotRow(selected: [p], maxPos: maxPos, colors: [.green]))
                }
            case "First", "Second", "Third", "Fourth", "Fifth":
                // Multiselect: "2 up" → position 2
                let parts = line.value.split(separator: " ")
                if let posStr = parts.first, let pos = Int(posStr) {
                    let color: Color = line.label == "First" ? .green : .red
                    rows.append(makeDotRow(selected: [pos], maxPos: maxPos, colors: [color]))
                }
            default:
                break
            }
        }

        // Also check titleSuffix for folded single multiselect: "2 up"
        if rows.isEmpty && !exercise.titleSuffix.isEmpty {
            let parts = exercise.titleSuffix.split(separator: " ")
            if let posStr = parts.first, let pos = Int(posStr) {
                rows.append(makeDotRow(selected: [pos], maxPos: maxPos, colors: [.green]))
            }
        }

        return rows
    }

    private func makeDotRow(selected: [Int], maxPos: Int, colors: [Color]) -> [PositionDot] {
        (1...maxPos).map { pos in
            if let idx = selected.firstIndex(of: pos) {
                let color = idx < colors.count ? colors[idx] : colors.last ?? .green
                return PositionDot(position: pos, filled: true, color: color)
            }
            return PositionDot(position: pos, filled: false, color: .gray)
        }
    }

    private func parsePermutation(exercise: Exercise) -> PermutationData? {
        guard let line = exercise.displayLines.first(where: { $0.label == "Pattern" }) else {
            return nil
        }
        // "2 3 1, 1 2"
        let groups = line.value.split(separator: ",")
        guard groups.count == 2 else { return nil }

        let three = groups[0].split(separator: " ").compactMap { Int($0) }
        let two = groups[1].split(separator: " ").compactMap { Int($0) }
        guard three.count == 3, two.count == 2 else { return nil }

        let orderColors: [Color] = [.green, .yellow, .red]

        // For the 3-group: each position gets colored by when it's played
        // "2 3 1" means position 2 played 1st (green), 3 played 2nd (yellow), 1 played 3rd (red)
        var threeBoxes: [Color] = Array(repeating: .gray, count: 3)
        for (order, pos) in three.enumerated() {
            if pos >= 1 && pos <= 3 {
                threeBoxes[pos - 1] = orderColors[min(order, orderColors.count - 1)]
            }
        }

        var twoBoxes: [Color] = Array(repeating: .gray, count: 2)
        for (order, pos) in two.enumerated() {
            if pos >= 1 && pos <= 2 {
                twoBoxes[pos - 1] = order == 0 ? .green : .red
            }
        }

        return PermutationData(threeGroup: threeBoxes, twoGroup: twoBoxes)
    }
}

// MARK: - Graphic Data Types

enum SignDirection {
    case up, down, upDown, downUp, none
}

struct PositionDot {
    let position: Int
    let filled: Bool
    let color: Color
}

struct PermutationData {
    let threeGroup: [Color]  // 3 box colors
    let twoGroup: [Color]    // 2 box colors
}

struct ExerciseGraphicData {
    let direction: SignDirection
    let positionRows: [[PositionDot]]
    let startNote: String?
    let symbol: String            // unicode symbol inside badge
    let category: String          // "chord", "arpeggio", or "scalar"
    let chordDegree: Int?         // 1-7
    let chordColor: Color
    let dashed: Bool
    let permutation: PermutationData?
    let exerciseLabel: String
}

// MARK: - Sign Shape

struct SignShape: Shape {
    let direction: SignDirection
    private let peakRatio: CGFloat = 0.15
    private let cornerRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let peak = h * peakRatio
        let r = cornerRadius
        var p = Path()

        switch direction {
        case .up:
            // Triangle top, flat bottom
            p.move(to: CGPoint(x: w / 2, y: 0))
            p.addLine(to: CGPoint(x: w, y: peak))
            p.addLine(to: CGPoint(x: w, y: h - r))
            p.addArc(center: CGPoint(x: w - r, y: h - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: CGPoint(x: r, y: h))
            p.addArc(center: CGPoint(x: r, y: h - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            p.addLine(to: CGPoint(x: 0, y: peak))
            p.closeSubpath()

        case .down:
            // Flat top, triangle bottom
            p.move(to: CGPoint(x: r, y: 0))
            p.addLine(to: CGPoint(x: w - r, y: 0))
            p.addArc(center: CGPoint(x: w - r, y: r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: w, y: h - peak))
            p.addLine(to: CGPoint(x: w / 2, y: h))
            p.addLine(to: CGPoint(x: 0, y: h - peak))
            p.addLine(to: CGPoint(x: 0, y: r))
            p.addArc(center: CGPoint(x: r, y: r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.closeSubpath()

        case .upDown:
            // Triangle top and bottom (diamond-like)
            p.move(to: CGPoint(x: w / 2, y: 0))
            p.addLine(to: CGPoint(x: w, y: peak))
            p.addLine(to: CGPoint(x: w, y: h - peak))
            p.addLine(to: CGPoint(x: w / 2, y: h))
            p.addLine(to: CGPoint(x: 0, y: h - peak))
            p.addLine(to: CGPoint(x: 0, y: peak))
            p.closeSubpath()

        case .downUp:
            // Same as upDown visually (both pointed)
            p.move(to: CGPoint(x: w / 2, y: 0))
            p.addLine(to: CGPoint(x: w, y: peak))
            p.addLine(to: CGPoint(x: w, y: h - peak))
            p.addLine(to: CGPoint(x: w / 2, y: h))
            p.addLine(to: CGPoint(x: 0, y: h - peak))
            p.addLine(to: CGPoint(x: 0, y: peak))
            p.closeSubpath()

        case .none:
            // Rounded rectangle
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        }

        return p
    }
}

// MARK: - Exercise Graphic View

struct ExerciseGraphicView: View {
    let graphic: ExerciseGraphicData
    private let dotSize: CGFloat = 20
    private let boxSize: CGFloat = 18

    var body: some View {
        ZStack {
            SignShape(direction: graphic.direction)
                .stroke(graphic.chordColor, style: StrokeStyle(
                    lineWidth: 3,
                    dash: graphic.dashed ? [8, 6] : []
                ))
                .background(
                    SignShape(direction: graphic.direction)
                        .fill(graphic.chordColor.opacity(0.08))
                )

            VStack(spacing: 12) {
                // Exercise badge: shape determined by category, symbol inside
                exerciseBadge

                // Position dots
                ForEach(Array(graphic.positionRows.enumerated()), id: \.offset) { _, row in
                    positionDotsView(row)
                }

                // Start note box
                if let note = graphic.startNote {
                    Text(note)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(minWidth: 70, minHeight: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary, lineWidth: 2)
                        )
                }

                // Permutation boxes
                if let perm = graphic.permutation {
                    permutationView(perm)
                }
            }
            .padding(.vertical, graphic.direction == .up || graphic.direction == .upDown ? 30 : 16)
            .padding(.horizontal, 16)
        }
    }

    private let badgeSize: CGFloat = 44

    /// Category badge: filled circle (chord), outline circle (arpeggio), rectangle (scalar)
    @ViewBuilder
    private var exerciseBadge: some View {
        let symbolText = Text(graphic.symbol)
            .font(.system(size: 20))
            .foregroundColor(graphic.category == "chord" ? .white : graphic.chordColor.opacity(0.8))

        switch graphic.category {
        case "chord":
            // Filled circle with symbol
            ZStack {
                Circle()
                    .fill(graphic.chordColor.opacity(0.6))
                    .frame(width: badgeSize, height: badgeSize)
                symbolText
            }
        case "arpeggio":
            // Outline circle with symbol
            ZStack {
                Circle()
                    .stroke(graphic.chordColor.opacity(0.6), lineWidth: 2)
                    .frame(width: badgeSize, height: badgeSize)
                symbolText
            }
        default:
            // Scalar: rectangle with symbol
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(graphic.chordColor.opacity(0.6), lineWidth: 2)
                    .frame(width: badgeSize, height: badgeSize * 0.7)
                symbolText
            }
        }
    }

    private func positionDotsView(_ dots: [PositionDot]) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(dots.enumerated()), id: \.offset) { _, dot in
                Circle()
                    .fill(dot.filled ? dot.color : Color.clear)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(dot.filled ? dot.color : Color.gray, lineWidth: 2))
            }
        }
    }

    private func permutationView(_ perm: PermutationData) -> some View {
        HStack(spacing: 4) {
            // 3-group
            ForEach(Array(perm.threeGroup.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: boxSize, height: boxSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(color, lineWidth: 1.5)
                    )
            }

            Spacer().frame(width: 10)

            // 2-group
            ForEach(Array(perm.twoGroup.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: boxSize, height: boxSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(color, lineWidth: 1.5)
                    )
            }
        }
    }
}

#Preview {
    ContentView()
}

#Preview {
    ContentView()
}
