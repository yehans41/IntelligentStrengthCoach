//
//  WorkoutPlanParser.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/28/25.
//

import Foundation
import CoreData

struct WorkoutPlanParser {
    
    enum ParserError: Error {
        case invalidFormat
    }

    func parse(planString: String, planName: String, in context: NSManagedObjectContext) throws -> WorkoutPlan {
        
        let workoutPlan = WorkoutPlan(context: context)
        workoutPlan.id = UUID()
        workoutPlan.name = planName
        workoutPlan.startDate = Date()
        
        var currentWorkoutDay: WorkoutDay? = nil
        var exerciseOrder: Int16 = 0
        var dayOrder: Int16 = 0
        
        let lines = planString.split(whereSeparator: \.isNewline)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.starts(with: "Day ") || trimmedLine.starts(with: "**Day") {
                dayOrder += 1
                exerciseOrder = 0
                
                let day = WorkoutDay(context: context)
                day.id = UUID()
                day.dayName = trimmedLine.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                day.order = dayOrder
                day.workoutPlan = workoutPlan
                currentWorkoutDay = day
                
            } else if !trimmedLine.isEmpty && trimmedLine.contains(":") {
                guard let currentDay = currentWorkoutDay else { continue }
                
                exerciseOrder += 1
                
                var exerciseText = trimmedLine
                // --- THE FINAL FIX ---
                // If the line starts with a bullet point, remove it, then trim any extra space.
                if exerciseText.starts(with: "*") || exerciseText.starts(with: "-") {
                    exerciseText = String(exerciseText.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                
                let components = exerciseText.split(separator: ":", maxSplits: 1)
                guard components.count == 2 else { continue }

                let exerciseName = String(components[0]).trimmingCharacters(in: .whitespaces)
                let setsAndReps = String(components[1]).trimmingCharacters(in: .whitespaces)
                
                let exerciseTemplate = WorkoutExerciseTemplate(context: context)
                exerciseTemplate.id = UUID()
                exerciseTemplate.notes = exerciseName
                exerciseTemplate.plannedReps = setsAndReps
                exerciseTemplate.orderInDay = exerciseOrder
                exerciseTemplate.workoutDay = currentDay
            }
        }
        return workoutPlan
    }
}
