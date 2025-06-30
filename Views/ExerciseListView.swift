//
//  ExerciseListView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI

// A view that displays a list of exercises for a specific workout day.
struct ExerciseListView: View {
    // The WorkoutDay object containing the exercises to be displayed.
    let day: WorkoutDay

    // Safely unwraps and sorts the exercises from the day's template.
    private var sortedExercises: [WorkoutExerciseTemplate] {
        let exercises = (day.exercises?.allObjects as? [WorkoutExerciseTemplate] ?? [])
        return exercises.sorted { $0.orderInDay < $1.orderInDay }
    }

    var body: some View {
            List {
                ForEach(sortedExercises) { exercise in
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
