//
//  ContentView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/18/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // TabView is the container for the main tab bar interface.
        TabView {
            // First Tab: The workout plans list.
            WorkoutPlanView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
            
            ProgressChartView()
                            .tabItem {
                                Label("Progress", systemImage: "chart.bar.xaxis")
                            }

            // Second Tab: The new profile view.
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .tint(Color("AccentColor"))
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
