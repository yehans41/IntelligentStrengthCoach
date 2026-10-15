//
//  WorkoutPlanView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI
import CoreData
// The main view for the "Workouts" tab, displaying all workout plans.
// This view handles fetching, sorting, renaming, deleting, and generating new plans.
struct WorkoutPlanView: View {
    @Environment(\.managedObjectContext) private var viewContext

    enum SortOption {
        case dateDescending, nameAscending
    }
    // MARK: - Data Fetching
    @FetchRequest(sortDescriptors: [], animation: .default)
    private var workoutPlans: FetchedResults<WorkoutPlan>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.updatedAt, ascending: false)])
    private var users: FetchedResults<User>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutSession.date, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == YES"))
    private var completedSessions: FetchedResults<WorkoutSession>
    // MARK: - View State
    @State private var planToRename: WorkoutPlan?
    @State private var newPlanName: String = ""
    @State private var isShowingRenameAlert = false
    // State for the loading indicator during AI plan generation.
    @State private var isGenerating = false
    // State to hold the current sort order for the list.
    @State private var currentSort: SortOption = .dateDescending
    // Title and message for the alert shown when an adjusted plan can't be generated.
    @State private var alertTitle = ""
    @State private var alertMessage: String?

    private let geminiService = GeminiService()
    private let planParser = WorkoutPlanParser()
    // MARK: - Computed Properties
    private var sortedPlans: [WorkoutPlan] {
        switch currentSort {
        case .dateDescending:
            return workoutPlans.sorted { $0.startDate ?? Date() > $1.startDate ?? Date() }
        case .nameAscending:
            return workoutPlans.sorted { $0.name ?? "" < $1.name ?? "" }
        }
    }
    // MARK: - Body
    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    // The ForEach now loops over the dynamically sorted `sortedPlans` array.
                    ForEach(sortedPlans) { plan in
                        NavigationLink(destination: WorkoutDayListView(plan: plan)) {
                            VStack(alignment: .leading) {
                                Text(plan.name ?? "Unnamed Plan").font(.headline)
                                Text("Created: \(plan.startDate ?? Date(), formatter: itemFormatter)").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deletePlan(plan: plan) } label: { Label("Delete", systemImage: "trash.fill") }
                                .tint(.red)
                            Button {
                                planToRename = plan
                                newPlanName = plan.name ?? ""
                                isShowingRenameAlert = true
                            } label: { Label("Rename", systemImage: "pencil") }.tint(Color("AccentColor"))
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color("BackgroundColor"))
                .overlay {
                    if workoutPlans.isEmpty {
                        ContentUnavailableView(
                            "No Workout Plans Yet",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Go to the Profile tab to generate your first AI plan.")
                        )
                    }
                }
                .navigationTitle("Your Workout Plans")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Generate New Plan", systemImage: "wand.and.stars") {
                            Task { await generateNewPlan() }
                        }
                        .disabled(isGenerating)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Button("Sort by Date (Newest First)") { currentSort = .dateDescending }
                            Button("Sort by Name (A-Z)") { currentSort = .nameAscending }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down.circle")
                        }
                    }
                }
            }
            .alert("Rename Plan", isPresented: $isShowingRenameAlert) {
                TextField("New plan name", text: $newPlanName)
                Button("Save", action: renamePlan)
                Button("Cancel", role: .cancel) { }
            } message: { Text("Enter a new name for this workout plan.") }
            .alert(alertTitle, isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: { Text(alertMessage ?? "") }
            // Loading indicator overlay for AI generation.
            if isGenerating {
                Color.black.opacity(0.4).edgesIgnoringSafeArea(.all)
                VStack(spacing: 20) {
                    ProgressView().scaleEffect(2)
                    Text("Generating adjusted plan...").foregroundColor(.white).font(.headline)
                }
                .padding(30).background(Color.black.opacity(0.8)).cornerRadius(15)
            }
        }
        .tint(Color("AccentColor"))
    }
    
    // MARK: - Functions
    private func renamePlan() {
        guard let plan = planToRename else { return }
        plan.name = newPlanName
        saveContext()
        planToRename = nil
        newPlanName = ""
    }
    
    private func deletePlan(plan: WorkoutPlan) {
        viewContext.delete(plan)
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func generateNewPlan() async {
        // The adaptive plan needs a profile and at least one finished workout to learn from.
        guard let user = users.first else {
            alertTitle = "Create a Profile First"
            alertMessage = "Go to the Profile tab to set your goal and experience level."
            return
        }
        guard let lastSession = completedSessions.first(where: { ($0.setLogs?.count ?? 0) > 0 }) else {
            alertTitle = "Finish a Workout First"
            alertMessage = "Log some sets in a workout and tap Finish. The AI uses your actual performance to build the adjusted plan."
            return
        }

        isGenerating = true

        do {
            let adjustedPlanText = try await geminiService.generateAdjustedPlan(basedOn: lastSession, for: user)

            let planName = "Adjusted Plan – \(Date().formatted(.dateTime.month(.abbreviated).day().hour().minute()))"
            let plan = try planParser.parse(planString: adjustedPlanText, planName: planName, in: viewContext)
            plan.user = user

            saveContext()
            print("Successfully generated and saved a new adjusted workout plan!")
        } catch {
            // Discard any partially created plan before reporting the error.
            viewContext.rollback()
            print("Failed to generate new plan: \(error)")
            alertTitle = "Couldn't Generate Plan"
            alertMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
// MARK: - Helpers
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    WorkoutPlanView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
