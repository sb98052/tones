//
//  ContentView.swift
//  Permutations
//
//  Scale practice permutation generator
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var position: Int = 1
    @State private var threeNoteUp: [Int] = [1, 2, 3]
    @State private var threeNoteDown: [Int] = [1, 2, 3]
    @State private var twoNoteUp: [Int] = [1, 2]
    @State private var twoNoteDown: [Int] = [1, 2]

    var body: some View {
        VStack(spacing: 40) {
            Text("Permutations")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            // Position
            VStack(spacing: 8) {
                Text("Position")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("\(position)")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.blue)
            }

            // Up
            VStack(spacing: 12) {
                Text("Up")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 40) {
                    VStack {
                        Text("3 notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatPermutation(threeNoteUp))
                            .font(.title)
                            .fontWeight(.semibold)
                    }

                    VStack {
                        Text("2 notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatPermutation(twoNoteUp))
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
            }

            // Down
            VStack(spacing: 12) {
                Text("Down")
                    .font(.headline)
                    .foregroundColor(.secondary)

                HStack(spacing: 40) {
                    VStack {
                        Text("3 notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatPermutation(threeNoteDown))
                            .font(.title)
                            .fontWeight(.semibold)
                    }

                    VStack {
                        Text("2 notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatPermutation(twoNoteDown))
                            .font(.title)
                            .fontWeight(.semibold)
                    }
                }
            }

            Spacer()

            // Next button
            Button(action: {
                generateNew()
            }) {
                Text("Next")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear {
            // Prevent screen from dimming/locking
            UIApplication.shared.isIdleTimerDisabled = true
            generateNew()
        }
    }

    private func formatPermutation(_ perm: [Int]) -> String {
        perm.map { String($0) }.joined(separator: ", ")
    }

    private func generateNew() {
        // Random position 1-4
        position = Int.random(in: 1...4)

        // All permutations of [1, 2, 3]
        let threePerms = [
            [1, 2, 3], [1, 3, 2], [2, 1, 3],
            [2, 3, 1], [3, 1, 2], [3, 2, 1]
        ]

        // All permutations of [1, 2]
        let twoPerms = [[1, 2], [2, 1]]

        threeNoteUp = threePerms.randomElement()!
        threeNoteDown = threePerms.randomElement()!
        twoNoteUp = twoPerms.randomElement()!
        twoNoteDown = twoPerms.randomElement()!
    }
}

#Preview {
    ContentView()
}
