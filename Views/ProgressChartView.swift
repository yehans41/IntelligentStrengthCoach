//
//  ProgressChartView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/30/25.
//

import SwiftUI
import CoreData
import Charts

struct ProgressChartView: View {
    // 1. Fetch all unique exercises that have been logged
    @FetchRequest(
        entity: Exercise.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]
    ) private var exercises: FetchedResults<Exercise>

    // 2. State to hold the selected exercise
    @State private var selectedExercise: Exercise?

    var body: some View {
        NavigationStack {
            VStack {
                // 3. Picker to choose which exercise to view
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

                // 4. The Chart view
                if let selectedExercise = selectedExercise,
                   // --- CORRECTION 1 ---
                   // We now sort the logs by the date of their parent workout session.
                   let setLogs = (selectedExercise.setLogs as? Set<SetLog>)?.sorted(by: {
                       $0.workoutSession?.date ?? Date() < $1.workoutSession?.date ?? Date()
                   }), !setLogs.isEmpty {
                    
                    Text("Max Weight Lifted for \(selectedExercise.name ?? "")")
                        .font(.headline)
                        .padding(.bottom)

                    Chart(setLogs) { log in
                        // --- CORRECTION 2 ---
                        // Plot the x-axis using the date from the session.
                        LineMark(
                            x: .value("Date", log.workoutSession?.date ?? Date()),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(Color("AccentColor"))
                        
                        // --- CORRECTION 3 ---
                        // Also use the session's date for the point mark.
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
                    Spacer()
                    Text("Select an exercise with logged sets to see your progress.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .navigationTitle("Progress")
            .onAppear {
                // Automatically select the first exercise when the view appears
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
