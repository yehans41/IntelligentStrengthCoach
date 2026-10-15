//
//  LiveWorkoutView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/30/25.
//

import SwiftUI
import CoreData
// The main view for tracking a live workout session for a specific workout day.
struct LiveWorkoutView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let dayTemplate: WorkoutDay
    // Created when the screen appears (not in init), because SwiftUI may build this view
    // ahead of time for every row in the day list.
    @State private var session: WorkoutSession?

    // A single rest timer shared by all exercises in the workout.
    private static let restDuration = 90
    @State private var restTimeRemaining = 0
    @State private var restTask: Task<Void, Never>?

    init(dayTemplate: WorkoutDay) {
        self.dayTemplate = dayTemplate
    }
    // Safely unwraps and sorts the exercises from the day's template to be displayed.
    private var sortedExerciseTemplates: [WorkoutExerciseTemplate] {
        let templates = (dayTemplate.exercises?.allObjects as? [WorkoutExerciseTemplate] ?? [])
        return templates.sorted { $0.orderInDay < $1.orderInDay }
    }

    var body: some View {
        List {
            if let session {
                ForEach(sortedExerciseTemplates) { exerciseTemplate in
                    ExerciseLoggingView(exerciseTemplate: exerciseTemplate, session: session, onSetAdded: startRestTimer)
                }
            }
        }
        .navigationTitle(dayTemplate.dayName ?? "Live Workout")
        .navigationBarTitleDisplayMode(.inline)
        // Hide the tab bar so it doesn't cover the last exercise during a workout.
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Finish", action: finishWorkout)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if restTimeRemaining > 0 {
                restTimerBar
            }
        }
        .onAppear(perform: startSessionIfNeeded)
        .onDisappear(perform: cleanUpUnfinishedSession)
    }

    // The rest countdown shown at the bottom of the screen after each logged set.
    private var restTimerBar: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest: \(restTimeRemaining / 60):\(String(format: "%02d", restTimeRemaining % 60))")
                .font(.headline)
                .monospacedDigit()
            Spacer()
            Button("Skip", action: stopRestTimer)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func startSessionIfNeeded() {
        guard session == nil else { return }
        let newSession = WorkoutSession(context: viewContext)
        newSession.id = UUID()
        newSession.date = Date()
        newSession.isCompleted = false
        session = newSession
    }

    // Marks the session as complete, calculates its duration, saves, and dismisses the view.
    private func finishWorkout() {
        guard let session else { return }
        session.isCompleted = true
        session.durationMinutes = Int16(Date().timeIntervalSince(session.date ?? Date()) / 60)

        do {
            try viewContext.save()
            print("Workout session finished and saved!")
            dismiss() // Dismiss the view after finishing
        } catch {
            print("Failed to save finished workout: \(error.localizedDescription)")
        }
    }

    // If the user leaves without logging anything, discard the empty session.
    private func cleanUpUnfinishedSession() {
        stopRestTimer()
        guard let session, !session.isCompleted, (session.setLogs?.count ?? 0) == 0 else { return }
        viewContext.delete(session)
        try? viewContext.save()
        self.session = nil
    }

    // Starts (or restarts) the shared rest countdown.
    private func startRestTimer() {
        restTask?.cancel()
        restTimeRemaining = Self.restDuration
        restTask = Task {
            while restTimeRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                restTimeRemaining -= 1
            }
            // Play a haptic to tell the user rest is over.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func stopRestTimer() {
        restTask?.cancel()
        restTask = nil
        restTimeRemaining = 0
    }
}
// A view representing a single exercise within a live workout, handling set logging.
struct ExerciseLoggingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextFieldFocused: Bool

    let exerciseTemplate: WorkoutExerciseTemplate
    let session: WorkoutSession
    // Called after a set is saved so the parent can start the rest timer.
    let onSetAdded: () -> Void

    @State private var weight: String = ""
    @State private var reps: String = ""

    @FetchRequest var loggedSets: FetchedResults<SetLog>
    // Custom initializer to configure the FetchRequest's predicate dynamically.
    init(exerciseTemplate: WorkoutExerciseTemplate, session: WorkoutSession, onSetAdded: @escaping () -> Void) {
        self.exerciseTemplate = exerciseTemplate
        self.session = session
        self.onSetAdded = onSetAdded

        let exerciseName = exerciseTemplate.notes ?? ""
        self._loggedSets = FetchRequest<SetLog>(
            sortDescriptors: [NSSortDescriptor(keyPath: \SetLog.orderInExercise, ascending: true)],
            predicate: NSPredicate(format: "workoutSession == %@ AND exercise.name == %@", session, exerciseName)
        )
    }

    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text(exerciseTemplate.notes ?? "Exercise")
                    .font(.headline)
                Text(exerciseTemplate.plannedReps ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                // Display any sets that have already been logged for this exercise.
                ForEach(loggedSets) { set in
                    HStack {
                        Text("Set \(set.orderInExercise):")
                        Spacer()
                        Text("\(set.weight.formatted()) lbs x \(set.reps) reps")
                    }
                    .font(.subheadline)
                }

                HStack {
                    TextField("Weight", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Reps", text: $reps)
                        .keyboardType(.numberPad)
                    Button("Add", action: addSet)
                        .buttonStyle(.borderedProminent)
                }
                .focused($isTextFieldFocused)
            }
        }
    }
    // Validates input, creates a new SetLog object, and links it to the session and exercise.
    private func addSet() {
        guard let weightValue = Double(weight), let repsValue = Int16(reps) else { return }
        let exercise = findOrCreateExercise(named: exerciseTemplate.notes ?? "Unknown", in: viewContext)
        
        let newSet = SetLog(context: viewContext)
        newSet.id = UUID()
        newSet.weight = weightValue
        newSet.reps = repsValue
        newSet.orderInExercise = Int16(loggedSets.count + 1)
        newSet.workoutSession = session
        newSet.exercise = exercise

        do {
            try viewContext.save()
            weight = ""
            reps = ""
            isTextFieldFocused = false
            onSetAdded() // Start the rest timer after a successful save
        } catch {
            print("Failed to save set: \(error.localizedDescription)")
        }
    }
    // A helper to prevent duplicate Exercise objects.
    private func findOrCreateExercise(named name: String, in context: NSManagedObjectContext) -> Exercise {
        let request = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingExercise = try? context.fetch(request).first {
            return existingExercise
        } else {
            let newExercise = Exercise(context: context)
            newExercise.id = UUID()
            newExercise.name = name
            return newExercise
        }
    }
}
