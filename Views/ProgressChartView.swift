//
//  ProgressChartView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/30/25.
//

import SwiftUI
import CoreData
import Charts
// A view that displays a user's strength progress for a selected exercise over time.
struct ProgressChartView: View {
    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
    ) private var exercises: FetchedResults<Exercise>
    // State to keep track of the exercise currently selected by the user.
    @State private var selectedExercise: Exercise?

    var body: some View {
        NavigationStack {
            VStack {
                // A dropdown menu for the user to select which exercise's progress to view.
                if !exercises.isEmpty {
                    Picker("Select Exercise", selection: $selectedExercise) {
                        Text("Select an Exercise").tag(nil as Exercise?)
                        ForEach(exercises) { exercise in
                            Text(exercise.name ?? "N/A").tag(exercise as Exercise?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                }
                // Only show the chart if an exercise is selected and it has logs.
                if let selectedExercise = selectedExercise,
                   let setLogs = (selectedExercise.setLogs as? Set<SetLog>)?.sorted(by: {
                       $0.workoutSession?.date ?? Date() < $1.workoutSession?.date ?? Date()
                   }), !setLogs.isEmpty {
                    
                    Text("Max Weight Lifted for \(selectedExercise.name ?? "")")
                        .font(.headline)
                        .padding(.bottom)
                    // The main chart view that plots weight over time for the selected exercise.
                    Chart(setLogs) { log in
                        LineMark(
                            x: .value("Date", log.workoutSession?.date ?? Date()),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color("AccentColor"))
                
                        PointMark(
                            x: .value("Date", log.workoutSession?.date ?? Date()),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color("AccentColor"))
                        .annotation(position: .top) {
                            Text("\(log.weight, specifier: "%.0f") lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    
                } else {
                    // A placeholder view shown when no exercise is selected or there's no data.
                    Spacer()
                    Text("Select an exercise with logged sets to see your progress.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                // Automatically selects the first exercise in the list when the view initially appears.
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
        }
    }
}

#Preview {
    ProgressChartView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
