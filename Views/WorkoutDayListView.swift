//
//  WorkoutDayListView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI
import CoreData
// A view that displays a list of the workout days within a specific workout plan.
struct WorkoutDayListView: View {
    // The parent WorkoutPlan object, passed in from the previous view.
    let plan: WorkoutPlan

    // Safely unwraps and sorts the days from the plan by their specified order.
    private var sortedDays: [WorkoutDay] {
        let days = (plan.workoutDays?.allObjects as? [WorkoutDay] ?? [])
        return days.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            ForEach(sortedDays) { day in
                // Each row is a tappable link that navigates to the live workout view for that day.
                NavigationLink(destination: LiveWorkoutView(dayTemplate: day)) {
                    VStack(alignment: .leading) {
                        Text(day.dayName ?? "Unnamed Day")
                        Text("\(day.exercises?.count ?? 0) exercises")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .overlay {
            if sortedDays.isEmpty {
                ContentUnavailableView(
                    "No Workout Days",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("This plan doesn't contain any workouts. Try generating a new plan.")
                )
            }
        }
        .navigationTitle(plan.name ?? "Workout Plan")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// A functional preview provider for this view.
#Preview {
    // Creates sample data in memory for the preview to function correctly.
    let context = PersistenceController.preview.container.viewContext
    
    // Create a sample plan for the preview
    let samplePlan = WorkoutPlan(context: context)
    samplePlan.name = "Sample Preview Plan"
    
    // Create a sample day and link it to the plan
    let sampleDay = WorkoutDay(context: context)
    sampleDay.dayName = "Day 1: Preview Day"
    sampleDay.order = 1
    sampleDay.workoutPlan = samplePlan
    
    // Injects the preview context and wraps the view in a NavigationStack.
    return NavigationStack {
        WorkoutDayListView(plan: samplePlan)
            .environment(\.managedObjectContext, context)
    }
}
