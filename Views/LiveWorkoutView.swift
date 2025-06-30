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
    @State private var session: WorkoutSession
    // Creates a new, active WorkoutSession object as soon as the user starts the workout.
    init(dayTemplate: WorkoutDay) {
        self.dayTemplate = dayTemplate
        
        let context = PersistenceController.shared.container.viewContext
        let newSession = WorkoutSession(context: context)
        newSession.id = UUID()
        newSession.date = Date()
        newSession.isCompleted = false
        
        self._session = State(initialValue: newSession)
    }
    // Safely unwraps and sorts the exercises from the day's template to be displayed.
    private var sortedExerciseTemplates: [WorkoutExerciseTemplate] {
        let templates = (dayTemplate.exercises?.allObjects as? [WorkoutExerciseTemplate] ?? [])
        return templates.sorted { $0.orderInDay < $1.orderInDay }
    }

    var body: some View {
        List {
            ForEach(sortedExerciseTemplates) { exerciseTemplate in
                ExerciseLoggingView(exerciseTemplate: exerciseTemplate, session: session)
            }
        }
        .navigationTitle("Live Workout")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // The button is now simpler. It just calls finishWorkout.
                Button("Finish", action: finishWorkout)
            }
        }
    }
    // Marks the session as complete, calculates its duration, saves, and dismisses the view.
    private func finishWorkout() {
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
}
// A view representing a single exercise within a live workout, handling set logging and timers.
struct ExerciseLoggingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FocusState private var isTextFieldFocused: Bool

    let exerciseTemplate: WorkoutExerciseTemplate
    let session: WorkoutSession
    
    @State private var weight: String = ""
    @State private var reps: String = ""
    @State private var timer: Timer?
    @State private var timeRemaining: Int = 90 // Default 90-second rest
    @State private var isTimerActive = false
    
    @FetchRequest var loggedSets: FetchedResults<SetLog>
    // Custom initializer to configure the FetchRequest's predicate dynamically.
    init(exerciseTemplate: WorkoutExerciseTemplate, session: WorkoutSession) {
        self.exerciseTemplate = exerciseTemplate
        self.session = session
        
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
                        Text("\(set.weight, specifier: "%.1f") lbs x \(set.reps) reps")
                    }
                    .font(.subheadline)
                }
                
                // Show either the input fields or the timer
                if isTimerActive {
                    HStack {
                        Text("Rest: \(timeRemaining)s")
                            .font(.headline)
                            .fontWeight(.bold)
                        Spacer()
                        Button("Skip") {
                            stopTimer()
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
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
            startTimer() // Start the rest timer after a successful save
        } catch {
            print("Failed to save set: \(error.localizedDescription)")
        }
    }
    // Manages the start and stop logic for the rest timer.
    private func startTimer() {
        isTimerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                stopTimer()
                // Play a haptic feedback to notify the user
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timeRemaining = 90 // Reset for the next rest period
        isTimerActive = false
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
