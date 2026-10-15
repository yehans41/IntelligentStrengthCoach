//
//  WorkoutPlanParser.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/28/25.
//

import Foundation
import CoreData

struct WorkoutPlanParser {

    enum ParserError: LocalizedError {
        case invalidFormat

        var errorDescription: String? {
            "The AI response couldn't be turned into a workout plan. Please try again."
        }
    }

    // This function iterates through a raw text string from the AI, building a
    // structured WorkoutPlan object with its associated days and exercises.
    // Throws `invalidFormat` (and creates nothing) if no days with exercises are found.
    func parse(planString: String, planName: String, in context: NSManagedObjectContext) throws -> WorkoutPlan {

        // First pass: extract plain (day, exercises) data from the text so nothing is
        // inserted into Core Data unless the response is actually usable.
        var parsedDays: [(name: String, exercises: [(name: String, setsAndReps: String)])] = []

        let lines = planString.split(whereSeparator: \.isNewline)

        for line in lines {
            let cleanedLine = clean(String(line))
            guard !cleanedLine.isEmpty else { continue }

            // A day title, e.g. "Day 1: Upper Body Strength".
            if cleanedLine.lowercased().hasPrefix("day ") {
                parsedDays.append((name: cleanedLine, exercises: []))
            // Otherwise, an exercise line in the form "Exercise Name: sets and reps".
            } else if !parsedDays.isEmpty, cleanedLine.contains(":") {
                let components = cleanedLine.split(separator: ":", maxSplits: 1)
                guard components.count == 2 else { continue }

                let exerciseName = clean(String(components[0]))
                let setsAndReps = clean(String(components[1]))
                guard !exerciseName.isEmpty, !setsAndReps.isEmpty else { continue }

                parsedDays[parsedDays.count - 1].exercises.append((name: exerciseName, setsAndReps: setsAndReps))
            }
        }

        // Drop any day titles that had no exercises under them.
        parsedDays.removeAll { $0.exercises.isEmpty }
        guard !parsedDays.isEmpty else { throw ParserError.invalidFormat }

        // Second pass: build the Core Data objects.
        let workoutPlan = WorkoutPlan(context: context)
        workoutPlan.id = UUID()
        workoutPlan.name = planName
        workoutPlan.startDate = Date()
        workoutPlan.generatedByAI = true

        for (dayIndex, parsedDay) in parsedDays.enumerated() {
            let day = WorkoutDay(context: context)
            day.id = UUID()
            day.dayName = parsedDay.name
            day.order = Int16(dayIndex + 1)
            day.workoutPlan = workoutPlan

            for (exerciseIndex, parsedExercise) in parsedDay.exercises.enumerated() {
                let exerciseTemplate = WorkoutExerciseTemplate(context: context)
                exerciseTemplate.id = UUID()
                exerciseTemplate.notes = parsedExercise.name
                exerciseTemplate.plannedReps = parsedExercise.setsAndReps
                exerciseTemplate.orderInDay = Int16(exerciseIndex + 1)
                exerciseTemplate.workoutDay = day
            }
        }
        return workoutPlan
    }

    // Strips the Markdown the AI sometimes adds (headings, bullets, numbering, bold/italics)
    // so "### **Day 1:** Upper" becomes "Day 1: Upper" and "1. **Squat**: 3x5" becomes "Squat: 3x5".
    private func clean(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)

        // Remove leading heading markers and list bullets.
        while let first = result.first, "#-•+>".contains(first) || (first == "*" && result.dropFirst().first == " ") {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        // Remove leading numbering such as "1." or "2)".
        if let match = result.firstMatch(of: /^\d+[.)]\s+/) {
            result = String(result[match.range.upperBound...])
        }

        // Remove bold/italic markers anywhere in the line.
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "* ").union(.whitespaces))

        return result
    }
}
