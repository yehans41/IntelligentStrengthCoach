//
//  ProfileView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//


import SwiftUI
// A view that displays user profile information and provides actions like generating a new workout plan.
struct ProfileView: View {
    // Controls the presentation of the OnboardingView as a modal sheet.
    @State private var isShowingOnboarding = false

    var body: some View {
        NavigationStack {
            VStack {
                // This button triggers the presentation of the onboarding sheet.
                Button("Generate New Workout Plan") {
                    isShowingOnboarding = true
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Profile")
            // Presents the OnboardingView modally when the @State variable becomes true.
            .sheet(isPresented: $isShowingOnboarding) {
                OnboardingView()
            }
        }
    }
}

#Preview {
    ProfileView()
}
