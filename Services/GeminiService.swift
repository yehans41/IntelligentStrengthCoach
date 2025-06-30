//
//  GeminiService.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/24/25.
//

import Foundation
import FirebaseVertexAI

// A service class responsible for all communication with the Gemini AI model.
final class GeminiService {
    
    // Configures the connection to the specific Gemini model we want to use.
    private let model = VertexAI.vertexAI(location: "us-central1").generativeModel(
        modelName: "gemini-2.5-flash"
    )

    // Generates an initial workout plan based on the user's profile.
    func generateWorkoutPlan(for user: User) async throws -> String {
        
        
        guard let goal = user.primaryGoal, let experience = user.experienceLevel else {
            throw NSError(domain: "GeminiServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User goal or experience is missing."])
        }

        // Construct a detailed prompt to send to the AI for an initial plan.
        let prompt = """
        You are an expert strength and conditioning coach.
        A new client has come to you with the following details:
        - Primary Goal: \(goal)
        - Experience Level: \(experience)

        Based on these details, generate a 4-day workout split for their first week.
        The response should be structured simply. For each day, provide the day's name (e.g., "Day 1: Upper Body Strength") and a list of 5-6 exercises with sets and reps (e.g., "Bench Press: 3 sets of 5 reps").
        Do not include any other conversational text or introductions. Just provide the workout plan.
        """
        
        print("--- Sending Prompt to Gemini ---")
        print(prompt)
        print("-----------------------------")

        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw NSError(domain: "GeminiServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text response from Gemini."])
        }
        
        print("--- Received Response from Gemini ---")
        print(text)
        print("---------------------------------")
        
        return text
    }
    // Generates an adjusted workout plan based on a user's performance in a previous workout session.
        func generateAdjustedPlan(basedOn lastSession: WorkoutSession, for user: User) async throws -> String {
            
            guard let goal = user.primaryGoal, let experience = user.experienceLevel else {
                throw NSError(domain: "GeminiServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "User goal or experience is missing."])
            }
            // Build a string summarizing the user's performance from the completed session.
            var performanceSummary = ""
            if let setLogs = lastSession.setLogs as? Set<SetLog> {
                // Group logs by exercise name
                let groupedLogs = Dictionary(grouping: setLogs) { $0.exercise?.name ?? "Unknown Exercise" }
                
                for (exerciseName, logs) in groupedLogs {
                    performanceSummary += "- \(exerciseName):\n"
                    let sortedLogs = logs.sorted { $0.orderInExercise < $1.orderInExercise }
                    for log in sortedLogs {
                        performanceSummary += "  - Set \(log.orderInExercise): \(log.weight) lbs for \(log.reps) reps\n"
                    }
                }
            }
            
            // Construct a new, more advanced prompt including the user's recent performance.
            let prompt = """
            You are an expert strength and conditioning coach designing a program based on progressive overload.

            A client's profile is:
            - Primary Goal: \(goal)
            - Experience Level: \(experience)

            They just completed the following workout:
            \(performanceSummary)

            Based on this specific performance, generate a new, adjusted 4-day workout split for their upcoming week.
            The new plan should apply the principles of progressive overload. For example, slightly increase the weight or reps for exercises they completed successfully.
            
            The response should be structured simply. For each day, provide the day's name and a list of 5-6 exercises with sets and reps.
            Do not include any other conversational text. Just provide the new workout plan.
            """
            
            print("--- Sending ADJUSTED Prompt to Gemini ---")
            print(prompt)
            print("---------------------------------------")

            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw NSError(domain: "GeminiServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No text response from Gemini."])
            }
            
            print("--- Received ADJUSTED Response from Gemini ---")
            print(text)
            print("------------------------------------------")
            
            return text
        }
}
