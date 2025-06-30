//
//  ContentView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/18/25.
//

import SwiftUI
// The main view of the app, which sets up the primary `TabView` navigation.
struct ContentView: View {
    var body: some View {
        // TabView is the container for the main tab bar interface.
        TabView {
            WorkoutPlanView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
            
            ProgressChartView()
                            .tabItem {
                                Label("Progress", systemImage: "chart.bar.xaxis")
                            }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        // Sets the global accent color for the entire application from the asset catalog.
        .tint(Color("AccentColor"))
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
