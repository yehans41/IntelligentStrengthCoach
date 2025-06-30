//
//  ProfileView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//


import SwiftUI

struct ProfileView: View {
    // This state variable will control whether we show the OnboardingView as a pop-up sheet.
    @State private var isShowingOnboarding = false

    var body: some View {
        NavigationStack {
            VStack {
                Button("Generate New Workout Plan") {
                    // When the button is tapped, we'll set our state variable to true.
                    isShowingOnboarding = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Profile")
            // This modifier listens to the $isShowingOnboarding variable.
            // When it becomes true, it presents the OnboardingView as a sheet.
            .sheet(isPresented: $isShowingOnboarding) {
                // We pass the OnboardingView here. When it's dismissed,
                // isShowingOnboarding will automatically be set back to false.
                OnboardingView()
            }
        }
    }
}

#Preview {
    ProfileView()
}
