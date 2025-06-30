//
//  SwiftUIView.swift
//  IntelligentStrengthCoach
//
//  Created by Yehan Subasinghe on 6/29/25.
//

import SwiftUI
import CoreData

struct WorkoutPlanView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Enums
    // We create an enum to represent our sorting options.
    enum SortOption {
        case dateDescending, nameAscending
    }

    // MARK: - Fetch Requests
    // The Fetch Request no longer needs to sort, as we'll do it in code.
    @FetchRequest(sortDescriptors: [], animation: .default)
    private var workoutPlans: FetchedResults<WorkoutPlan>

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \User.name, ascending: true)])
    private var users: FetchedResults<User>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkoutSession.date, ascending: false)],
        predicate: NSPredicate(format: "isCompleted == YES"))
    private var completedSessions: FetchedResults<WorkoutSession>

    // MARK: - State
    @State private var planToRename: WorkoutPlan?
    @State private var newPlanName: String = ""
    @State private var isShowingRenameAlert = false
    @State private var isGenerating = false
    // New state to hold the current sort order.
    @State private var currentSort: SortOption = .dateDescending

    // MARK: - Services
    private let geminiService = GeminiService()
    private let planParser = WorkoutPlanParser()
    
    // MARK: - Computed Properties
    // This property sorts the fetched plans based on the currentSort state.
    private var sortedPlans: [WorkoutPlan] {
        switch currentSort {
        case .dateDescending:
            return workoutPlans.sorted { $0.startDate ?? Date() > $1.startDate ?? Date() }
        case .nameAscending:
            return workoutPlans.sorted { $0.name ?? "" < $1.name ?? "" }
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                List {
                    // The ForEach now loops over our sortedPlans computed property.
                    ForEach(sortedPlans) { plan in
                        ZStack(alignment: .leading) {
                            NavigationLink(destination: WorkoutDayListView(plan: plan)) { EmptyView() }
                                .opacity(0)

                            VStack(alignment: .leading) {
                                Text(plan.name ?? "Unnamed Plan").font(.headline)
                                Text("Created: \(plan.startDate ?? Date(), formatter: itemFormatter)").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deletePlan(plan: plan) } label: { Label("Delete", systemImage: "trash.fill") }
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
                .navigationTitle("Your Workout Plans")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Generate New Plan", systemImage: "wand.and.stars") {
                            Task { await generateNewPlan() }
                        }
                        .disabled(isGenerating || completedSessions.isEmpty)
                    }
                    // The EditButton has been replaced with a Sort Menu.
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
    
    // In WorkoutPlanView.swift
    private func generateNewPlan() async {
        guard let user = users.first, let lastSession = completedSessions.first else {
            print("Cannot generate plan: No user or no completed sessions found.")
            return
        }
        
        isGenerating = true
        
        do {
            let adjustedPlanText = try await geminiService.generateAdjustedPlan(basedOn: lastSession, for: user)
            
            // We now define the correct name here before calling the parser
            let planName = "AI Adjusted Plan (\(Date().formatted(date: .numeric, time: .omitted)))"
            _ = try planParser.parse(planString: adjustedPlanText, planName: planName, in: viewContext)
            
            saveContext()
            print("Successfully generated and saved a new adjusted workout plan!")
        } catch {
            print("Failed to generate new plan: \(error.localizedDescription)")
        }
        
        isGenerating = false
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
}()

#Preview {
    WorkoutPlanView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
