//
//  IntelligentStrengthCoachApp.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/18/25.
//

import SwiftUI
import FirebaseCore

@main
struct IntelligentStrengthCoachApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
