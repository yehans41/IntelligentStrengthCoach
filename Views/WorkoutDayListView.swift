//
//  WorkoutDayListView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI
import CoreData

struct WorkoutDayListView: View {
    // This view receives the specific WorkoutPlan to display.
    let plan: WorkoutPlan

    // A computed property to safely get and sort the days.
    private var sortedDays: [WorkoutDay] {
        let days = (plan.workoutDays?.allObjects as? [WorkoutDay] ?? [])
        return days.sorted { $0.order < $1.order }
    }

    var body: some View {
        List {
            ForEach(sortedDays) { day in
                // This NavigationLink is what enables the next layer of navigation.
                NavigationLink(destination: LiveWorkoutView(dayTemplate: day)) {
                    Text(day.dayName ?? "Unnamed Day")
                }
            }
        }
        .navigationTitle(plan.name ?? "Workout Plan")
    }
}

// A functional preview provider for this view.
#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Create a sample plan for the preview
    let samplePlan = WorkoutPlan(context: context)
    samplePlan.name = "Sample Preview Plan"
    
    // Create a sample day and link it to the plan
    let sampleDay = WorkoutDay(context: context)
    sampleDay.dayName = "Day 1: Preview Day"
    sampleDay.order = 1
    sampleDay.workoutPlan = samplePlan
    
    // Wrap the preview in a NavigationStack so the title is visible.
    return NavigationStack {
        WorkoutDayListView(plan: samplePlan)
            .environment(\.managedObjectContext, context)
    }
}
