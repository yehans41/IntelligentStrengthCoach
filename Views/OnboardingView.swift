//
//  OnboardingView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/23/25.
//

import SwiftUI
import CoreData

// Enums remain the same...
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


struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var username: String = ""
    @State private var experienceLevel: ExperienceLevel = .beginner
    @State private var fitnessGoal: FitnessGoal = .muscleGain
    @State private var isGeneratingPlan = false

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
                .navigationTitle("Create Profile")
                .toolbar {
                    // ADD THIS: A new ToolbarItem for the Cancel button.
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
                        // Disable the save button while loading.
                        .disabled(isGeneratingPlan)
                    }
                }
            }
            
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
    }

    private func saveUserAndGeneratePlan() async {
        // This function's logic remains the same
        let newUser = User(context: viewContext)
        
        newUser.id = UUID()
        newUser.name = username
        newUser.experienceLevel = experienceLevel.rawValue
        newUser.primaryGoal = fitnessGoal.rawValue
        newUser.createdAt = Date()
        newUser.updatedAt = Date()
        
        do {
            try viewContext.save()
            print("User saved successfully!")
            
            let workoutPlanText = try await geminiService.generateWorkoutPlan(for: newUser)
            print("--- Received Response from Gemini ---")
            
            let planName = "AI Generated Plan (\(Date().formatted(date: .numeric, time: .omitted)))"
            _ = try planParser.parse(planString: workoutPlanText, planName: planName, in: viewContext)
            
            try viewContext.save()
            print("Successfully parsed and saved the workout plan!")
            
        } catch {
            let nsError = error as NSError
            print("Error during save or plan generation: \(nsError), \(nsError.userInfo)")
        }
        
        isGeneratingPlan = false
        dismiss()
    }
}


#Preview {
    OnboardingView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
