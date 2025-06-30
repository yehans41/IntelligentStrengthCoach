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

    //Add an init method to configure Firebase
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
