//
//  ExerciseListView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI

struct ExerciseListView: View {
    let day: WorkoutDay

    // NEW: The complex logic is moved into its own computed property.
    private var sortedExercises: [WorkoutExerciseTemplate] {
        let exercises = (day.exercises?.allObjects as? [WorkoutExerciseTemplate] ?? [])
        return exercises.sorted { $0.orderInDay < $1.orderInDay }
    }

    var body: some View {
        // The body is now much simpler for the compiler to understand.
        List {
            ForEach(sortedExercises) { exercise in
                // TEMPORARILY change the destination to a simple Text view
                NavigationLink(destination: Text("Details for \(exercise.notes ?? "")")) {
                    VStack(alignment: .leading) {
                        Text(exercise.notes ?? "Unnamed Exercise")
                            .font(.headline)
                        
                        Text(exercise.plannedReps ?? "No sets/reps defined")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(day.dayName ?? "Exercises")
    }
}
