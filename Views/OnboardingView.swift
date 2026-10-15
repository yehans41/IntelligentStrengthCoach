//
//  OnboardingView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/23/25.
//

import SwiftUI
import CoreData

// Data models for the picker options.
enum ExperienceLevel: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    var id: Self { self }
}

enum FitnessGoal: String, CaseIterable, Identifiable {
    case muscleGain = "Build Muscle"
    case strength = "Increase Strength"
    case fatLoss = "Lose Fat"
    var id: Self { self }
}
// A view presented modally for new user profile creation and initial workout plan generation.
struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var username: String = ""
    @State private var experienceLevel: ExperienceLevel = .beginner
    @State private var fitnessGoal: FitnessGoal = .muscleGain
    @State private var isGeneratingPlan = false
    // Holds the message shown in an alert if saving or plan generation fails.
    @State private var errorMessage: String?

    // The existing profile (most recently updated), reused so each new plan doesn't create a duplicate user.
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.updatedAt, ascending: false)])
    private var users: FetchedResults<User>

    private let geminiService = GeminiService()
    private let planParser = WorkoutPlanParser()

    var body: some View {
        ZStack {
            NavigationStack {
                Form {
                    Section("Your Name") {
                        TextField("Enter your name...", text: $username)
                    }

                    Section("Experience Level") {
                        Picker("Select Level", selection: $experienceLevel) {
                            ForEach(ExperienceLevel.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Primary Goal") {
                        Picker("Select Goal", selection: $fitnessGoal) {
                            ForEach(FitnessGoal.allCases) { goal in
                                Text(goal.rawValue).tag(goal)
                            }
                        }
                    }
                }
                .navigationTitle(users.isEmpty ? "Create Profile" : "Update Profile")
                .onAppear(perform: loadExistingProfile)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss() // The action simply dismisses the view.
                        }
                    }
                    
                    // The existing ToolbarItem for the Save button.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            isGeneratingPlan = true
                            Task {
                                await saveUserAndGeneratePlan()
                            }
                        }
                        // Disable the save button while loading or if no name has been entered.
                        .disabled(isGeneratingPlan || username.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            // A semi-transparent overlay with a spinner that appears while the AI is working.
            if isGeneratingPlan {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Generating your plan...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding(30)
                .background(Color.black.opacity(0.8))
                .cornerRadius(15)
            }
        }
        .tint(Color("AccentColor"))
        .alert("Couldn't Generate Plan", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    // Pre-fills the form with the saved profile, if one exists.
    private func loadExistingProfile() {
        guard let user = users.first else { return }
        username = user.name ?? ""
        experienceLevel = ExperienceLevel(rawValue: user.experienceLevel ?? "") ?? .beginner
        fitnessGoal = FitnessGoal(rawValue: user.primaryGoal ?? "") ?? .muscleGain
    }
    // Handles the entire end-to-end process of saving the user and generating their first workout plan.
    private func saveUserAndGeneratePlan() async {
        // Update the existing profile, or create one if this is the first launch.
        let user = users.first ?? User(context: viewContext)
        if user.id == nil {
            user.id = UUID()
            user.createdAt = Date()
        }
        user.name = username.trimmingCharacters(in: .whitespaces)
        user.experienceLevel = experienceLevel.rawValue
        user.primaryGoal = fitnessGoal.rawValue
        user.updatedAt = Date()

        do {
            try viewContext.save()
            print("User saved successfully!")

            let workoutPlanText = try await geminiService.generateWorkoutPlan(for: user)

            let planName = "AI Plan – \(Date().formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
            let plan = try planParser.parse(planString: workoutPlanText, planName: planName, in: viewContext)
            plan.user = user

            try viewContext.save()
            print("Successfully parsed and saved the workout plan!")
            isGeneratingPlan = false
            dismiss()
        } catch {
            // Discard any partially created plan and keep the sheet open so the user can retry.
            viewContext.rollback()
            print("Error during save or plan generation: \(error)")
            isGeneratingPlan = false
            errorMessage = error.localizedDescription
        }
    }
}


#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
