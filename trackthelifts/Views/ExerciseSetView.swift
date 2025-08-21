//
//  ExerciseSetView.swift
//  TrackTheLifts
//
//  Created by Ashkan Sotoudeh on 2025-07-14.
//

import SwiftUI

struct ExerciseSetView: View {
    let workout: Workout
    let exercise: Exercise
    let setNumber: Int
    @State var weight: Double = 0.0
    @State var reps: Int = 0
    @State var isCompleted: Bool = false

    var body: some View {
        GridRow {
            // Column 1: Set number
            Text("\(setNumber)")
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(5)

            // Column 2 & 3: Previous summary
            Text("6 x 135lbs")
                .gridCellColumns(2)
                .frame(maxWidth: .infinity, alignment: .center)

            // Column 4: lbs
            TextField(
                "135",
                text: Binding(
                    get: { String(weight) },
                    set: { newValue in
                        if let value = Double(newValue) {
                            weight = value
                        }
                    }
                )
            )
            .frame(width: 50, height: 30)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(5)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)

            // Column 5: reps
            TextField(
                "6",
                text: Binding(
                    get: { String(reps) },
                    set: { newValue in
                        if let value = Int(newValue) {
                            reps = value
                        }
                    }
                )
            )
            .frame(width: 50, height: 30)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(5)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)

            // Column 6: checkmark
            Button {
                print("Set completed!")
            } label: {
                Image(systemName: "checkmark")
                    .frame(width: 20, height: 20)
            }
            .padding(6)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(5)
        }
    }
}

#Preview {
    let workout = Workout(title: "New Workout", date: .now)
    let exercise = Exercise(name: "Bench Press")
    ExerciseSetView(workout: workout, exercise: exercise, setNumber: 10)
}
