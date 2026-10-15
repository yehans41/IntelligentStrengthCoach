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
                // Only show the chart if an exercise is selected and it has completed sets.
                if let selectedExercise = selectedExercise,
                   case let points = dailyMaxWeights(for: selectedExercise), !points.isEmpty {

                    Text("Max Weight Lifted for \(selectedExercise.name ?? "")")
                        .font(.headline)
                        .padding(.bottom)
                    // Plots the heaviest set from each workout day for the selected exercise.
                    Chart(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color("AccentColor"))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.maxWeight)
                        )
                        .foregroundStyle(Color("AccentColor"))
                        .annotation(position: .top) {
                            Text("\(point.maxWeight.formatted()) lbs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned, values: points.map(\.date)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxisLabel("lbs")
                    .frame(maxHeight: 350)
                    .padding()
                    Spacer()

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
            .onChange(of: exercises.count) {
                // Pick an exercise automatically once the first sets are logged.
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
            .onAppear {
                // Automatically selects the first exercise in the list when the view initially appears.
                if selectedExercise == nil {
                    selectedExercise = exercises.first
                }
            }
        }
    }
}

// One chart point: the heaviest weight lifted for an exercise on a given day.
private struct DailyMax: Identifiable {
    let date: Date
    let maxWeight: Double
    var id: Date { date }
}

// Groups an exercise's sets from finished workouts by day and keeps the heaviest set from each day.
private func dailyMaxWeights(for exercise: Exercise) -> [DailyMax] {
    let setLogs = (exercise.setLogs as? Set<SetLog>) ?? []
    let completedSets = setLogs.filter { $0.workoutSession?.isCompleted == true }
    let byDay = Dictionary(grouping: completedSets) { log in
        Calendar.current.startOfDay(for: log.workoutSession?.date ?? Date())
    }
    return byDay
        .map { DailyMax(date: $0.key, maxWeight: $0.value.map(\.weight).max() ?? 0) }
        .sorted { $0.date < $1.date }
}

#Preview {
    ProgressChartView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
