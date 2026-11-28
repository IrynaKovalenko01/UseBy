import SwiftUI
import SwiftData

/// Vaibhav Paranji - 11/27/2026

/// Pairs a Spoonacular result with its per-serving calorie count so the UI can
/// display the nutrition value and log the same serving consistently.
private struct OnlineRecipeRecommendation: Identifiable {
    let recipe: SpoonacularRecipe
    let calories: Int

    var id: Int { recipe.id }
}

struct CaloriesView: View {
    /// The shared store for new meal logs and saved calorie preferences.
    @Environment(\.modelContext) private var modelContext
    /// Newest meals appear first; the view filters them to today's entries.
    @Query(sort: \CalorieMeal.consumedAt, order: .reverse)
    private var meals: [CalorieMeal]
    /// The profile is optional so a user can log meals before setting a goal.
    @Query private var profiles: [CalorieProfile]
    /// Pantry names are sent to the recipe service to guide suggestions.
    @Query private var pantryItems: [PantryItem]

    /// Controls the manual meal-entry and calorie-goal sheets.
    @State private var showingMealEntry = false
    @State private var showingProfileEditor = false
    /// Online results and request state for the recommendation section.
    @State private var recipes: [SpoonacularRecipe] = []
    @State private var isLoadingRecipes = false
    @State private var recipeError: String?

    /// Meals displayed in today's log; older entries remain saved for history.
    private var todayMeals: [CalorieMeal] {
        meals.filter { Calendar.current.isDateInToday($0.consumedAt) }
    }

    /// Total consumed today, independent of the current goal.
    private var caloriesConsumedToday: Int {
        CalorieMeal.totalCalories(in: meals, on: .now)
    }

    /// A manual goal overrides the estimated target stored on the profile.
    private var dailyTarget: Int? {
        profiles.first?.recommendedDailyTarget
    }

    /// Remaining calories can be negative when intake passes the goal.
    private var caloriesRemaining: Int? {
        dailyTarget.map { $0 - caloriesConsumedToday }
    }

    /// Discard online results with missing or over-budget nutrition values;
    /// only recipes that can be compared to today's remaining calories qualify.
    private var onlineRecipesWithCalories: [OnlineRecipeRecommendation] {
        recipes.compactMap { recipe -> OnlineRecipeRecommendation? in
            guard let calories = recipe.nutrition?.caloriesPerServing,
                  calories > 0,
                  caloriesRemaining.map({ $0 > 0 && calories <= $0 }) ?? false else {
                return nil
            }
            return OnlineRecipeRecommendation(recipe: recipe, calories: calories)
        }
    }

    /// Offline ideas provide a no-network fallback when the target is known.
    private var offlineRecipes: [OfflineCalorieRecipe] {
        guard let caloriesRemaining, caloriesRemaining > 0 else { return [] }
        return OfflineCalorieRecipe.suggestions(fitting: caloriesRemaining)
    }

    /// Refetch suggestions when the target, today's intake, or pantry changes.
    private var recommendationKey: String {
        let pantryNames = pantryItems.map(\.name).sorted().joined(separator: ",")
        return "\(dailyTarget ?? 0)-\(caloriesConsumedToday)-\(pantryNames)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    dailySummary
                    mealLog
                    recipeRecommendations
                }
                .padding(16)
            }
            .background(Color.cozyCream)
            .navigationTitle("Calories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingProfileEditor = true
                    } label: {
                        Image(systemName: "target")
                    }
                    .accessibilityLabel("Set calorie goal")
                }
            }
            .task(id: recommendationKey) {
                await loadRecommendations()
            }
            .refreshable {
                await loadRecommendations()
            }
            .sheet(isPresented: $showingMealEntry) {
                // Manual logging is available even before the user sets a goal.
                CalorieMealEntryView()
            }
            .sheet(isPresented: $showingProfileEditor) {
                // Pass the saved profile for editing, or nil to start setup.
                CalorieProfileEditor(profile: profiles.first)
            }
        }
        .tint(.cozyBrown)
        .preferredColorScheme(.light)
    }

    private var dailySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's intake")
                    .font(.title2.bold())
                Spacer()
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Without a goal the user can still log meals, but recommendations
            // need a calorie budget and therefore wait for goal setup.
            // Progress is capped visually at the target, while the text below
            // still reports an over-target amount when applicable.
            if let dailyTarget {
                ProgressView(
                    value: min(Double(caloriesConsumedToday), Double(dailyTarget)),
                    total: Double(dailyTarget)
                )
                .tint(Color.cozyBrown)

                Text("\(caloriesConsumedToday) / \(dailyTarget) kcal")
                    .font(.title3.bold())
                if let caloriesRemaining {
                    Text(caloriesRemaining >= 0
                         ? "\(caloriesRemaining) kcal remaining"
                         : "\(-caloriesRemaining) kcal over your target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Set a daily calorie goal to see your progress.")
                    .foregroundStyle(.secondary)
                Button("Set a Goal") {
                    showingProfileEditor = true
                }
                .buttonStyle(.borderedProminent)
            }

            Button {
                showingMealEntry = true
            } label: {
                Label("Log a Meal", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var mealLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meals today")
                .font(.title3.bold())

            // Empty state is distinct from a zero-calorie total: no meals have
            // been entered yet for the current day.
            if todayMeals.isEmpty {
                Text("Your meals will appear here after you log them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Deleting a log immediately changes the daily total and
                // recipe budget because both are derived from the query.
                ForEach(todayMeals) { meal in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(meal.name)
                                .font(.body.weight(.medium))
                            Text(meal.consumedAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(meal.calories) kcal")
                            .font(.subheadline.weight(.semibold))
                        Button(role: .destructive) {
                            modelContext.delete(meal)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(meal.name)")
                    }
                    .padding(.vertical, 4)
                    if meal.id != todayMeals.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var recipeRecommendations: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipes for your remaining calories")
                .font(.title3.bold())

            // Select a meaningful state before rendering suggestions: setup,
            // exhausted budget, loading, online results, or offline fallback.
            if dailyTarget == nil {
                Text("Set a daily goal to get calorie-aware recipe ideas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if (caloriesRemaining ?? 0) <= 0 {
                Text("You’ve reached today’s target. New recipe ideas will appear when there are calories remaining.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if isLoadingRecipes {
                ProgressView("Finding recipes…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if let recipeError {
                    Text("Online recommendations are unavailable: \(recipeError)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if onlineRecipesWithCalories.isEmpty {
                    Text("No online recipes with matching nutrition data were found. Showing offline ideas with approximate calories.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !onlineRecipesWithCalories.isEmpty {
                    ForEach(onlineRecipesWithCalories) { recommendation in
                        onlineRecipeRow(
                            recommendation.recipe,
                            calories: recommendation.calories
                        )
                    }
                } else if offlineRecipes.isEmpty {
                    Text("No offline ideas fit the remaining calorie budget.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(offlineRecipes) { recipe in
                        offlineRecipeRow(recipe)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cozyCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private func onlineRecipeRow(_ recipe: SpoonacularRecipe, calories: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.body.weight(.semibold))
            HStack {
                Text("\(calories) kcal per serving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                // Recipe details use the existing cookbook detail screen;
                // logging records one serving at the returned calorie value.
                NavigationLink {
                    RecipeDetailView(recipeID: recipe.id, title: recipe.title)
                } label: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                }
                Button("Log 1 serving") {
                    logMeal(name: recipe.title, calories: calories)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    private func offlineRecipeRow(_ recipe: OfflineCalorieRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.body.weight(.semibold))
            Text(recipe.ingredients)
                .font(.caption)
                .foregroundStyle(.secondary)
            // Offline values are estimates, so the UI explicitly labels them
            // approximate before letting the user add a serving to the log.
            HStack {
                Text("About \(recipe.caloriesPerServing) kcal per serving")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Log 1 serving") {
                    logMeal(name: recipe.title, calories: recipe.caloriesPerServing)
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }

    /// Stores a recipe serving as a meal so it contributes to today's total.
    private func logMeal(name: String, calories: Int) {
        modelContext.insert(CalorieMeal(name: name, calories: calories))
    }

    @MainActor
    private func loadRecommendations() async {
        // Avoid unnecessary network requests if the user has not set a target
        // or has already consumed their full daily budget.
        guard let remaining = caloriesRemaining, remaining > 0 else {
            recipes = []
            recipeError = nil
            isLoadingRecipes = false
            return
        }

        isLoadingRecipes = true
        recipeError = nil
        defer { isLoadingRecipes = false }

        do {
            // Use current pantry contents and today's remaining calories as
            // filters for nutrition-aware recipe suggestions.
            recipes = try await SpoonacularAPI().recipesForCalorieBudget(
                pantryIngredients: pantryItems.map(\.name),
                maxCalories: remaining
            )
        } catch {
            guard !Task.isCancelled else { return }
            recipes = []
            recipeError = error.localizedDescription
        }
    }
}

private struct CalorieMealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Draft values stay local until the user validates and saves the meal.
    @State private var name = ""
    @State private var caloriesText = ""

    /// Accept only realistic positive integer calorie values.
    private var calories: Int? {
        guard let calories = Int(caloriesText), (1...10_000).contains(calories) else {
            return nil
        }
        return calories
    }

    var body: some View {
        NavigationStack {
            Form {
                // Calories are entered as a number; validation controls when
                // Save becomes available.
                TextField("Meal or food", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("Calories", text: $caloriesText)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Log a Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories == nil)
                }
            }
        }
    }

    private func save() {
        // The Save button is disabled for invalid fields; keep this guard so
        // the persistence path remains safe if it is invoked another way.
        guard let calories else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(CalorieMeal(name: trimmedName, calories: calories))
        dismiss()
    }
}

private struct CalorieProfileEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Existing profile is edited in a draft; a missing profile is created
    /// only after the user saves valid settings.
    let profile: CalorieProfile?

    /// Text state allows numeric fields to be edited before parsing/validation.
    @State private var manualTargetText: String
    @State private var ageText: String
    @State private var heightText: String
    @State private var weightText: String
    @State private var calculationSexRaw: String
    @State private var activityLevelRaw: String
    @State private var goalRaw: String

    init(profile: CalorieProfile?) {
        self.profile = profile
        _manualTargetText = State(
            initialValue: profile?.manualDailyTarget.map { String($0) } ?? ""
        )
        _ageText = State(initialValue: profile?.age.map { String($0) } ?? "")
        _heightText = State(initialValue: profile?.heightCentimeters.map { String(format: "%.0f", $0) } ?? "")
        _weightText = State(initialValue: profile?.weightKilograms.map { String(format: "%.1f", $0) } ?? "")
        _calculationSexRaw = State(initialValue: profile?.calculationSexRaw ?? "")
        _activityLevelRaw = State(initialValue: profile?.activityLevelRaw ?? "")
        _goalRaw = State(initialValue: profile?.goalRaw ?? CalorieGoal.maintain.rawValue)
    }

    private var manualTarget: Int? {
        guard let manualTargetText = Int(manualTargetText),
              (500...10_000).contains(manualTargetText) else {
            return nil
        }
        return manualTargetText
    }

    /// True if the user started entering any personalized estimate fields.
    private var hasProfileInput: Bool {
        !ageText.isEmpty || !heightText.isEmpty || !weightText.isEmpty
            || !calculationSexRaw.isEmpty || !activityLevelRaw.isEmpty
    }

    /// All inputs used by the adult equation must be present and in range.
    private var validProfileInput: Bool {
        guard let age = Int(ageText), (18...100).contains(age),
              let height = Double(heightText), (100...250).contains(height),
              let weight = Double(weightText), (30...400).contains(weight),
              CalorieCalculationSex(rawValue: calculationSexRaw) != nil,
              CalorieActivityLevel(rawValue: activityLevelRaw) != nil,
              CalorieGoal(rawValue: goalRaw) != nil else {
            return false
        }
        return true
    }

    /// Accept either one valid mode: manual target, complete profile estimate,
    /// or both. Partial profile values cannot be saved as a valid estimate.
    private var canSave: Bool {
        let manualIsBlank = manualTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let manualIsValid = manualTarget != nil
        return (manualIsBlank || manualIsValid)
            && (validProfileInput || !hasProfileInput)
            && (manualIsValid || validProfileInput)
    }

    var body: some View {
        NavigationStack {
            Form {
                // A manual goal is optional when a complete adult profile is
                // entered, and takes precedence when both are supplied.
                Section("Daily calorie goal") {
                    TextField("Manual target (kcal)", text: $manualTargetText)
                        .keyboardType(.numberPad)
                    Text("A manual target takes priority over an estimated target.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Profile fields are optional as a group; partial data cannot
                // produce an estimate and is rejected on save.
                Section("Optional adult estimate") {
                    TextField("Age (18–100)", text: $ageText)
                        .keyboardType(.numberPad)
                    TextField("Height in cm", text: $heightText)
                        .keyboardType(.decimalPad)
                    TextField("Weight in kg", text: $weightText)
                        .keyboardType(.decimalPad)

                    Picker("Equation coefficient", selection: $calculationSexRaw) {
                        Text("Select").tag("")
                        ForEach(CalorieCalculationSex.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }

                    Picker("Activity level", selection: $activityLevelRaw) {
                        Text("Select").tag("")
                        ForEach(CalorieActivityLevel.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }

                    Picker("Goal", selection: $goalRaw) {
                        ForEach(CalorieGoal.allCases) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                } footer: {
                    // Explain the equation's scope and the local-only handling
                    // of sensitive profile values before collection.
                    Text("The Mifflin–St Jeor equation provides a rough estimate for adults only. This is not medical advice. Your profile is stored on this device. A manual target can be used without entering profile details.")
                }

                if !canSave {
                    Section {
                        Text("Enter a manual target from 500 to 10,000 kcal, or complete all adult profile fields with valid values.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        // Never persist an invalid or partial goal configuration.
        guard canSave else { return }
        let savedProfile = profile ?? CalorieProfile()
        savedProfile.manualDailyTarget = manualTarget

        // Save a complete personalized profile when supplied; otherwise clear
        // any old estimate fields while retaining a valid manual target.
        if validProfileInput,
           let age = Int(ageText),
           let height = Double(heightText),
           let weight = Double(weightText) {
            savedProfile.age = age
            savedProfile.heightCentimeters = height
            savedProfile.weightKilograms = weight
            savedProfile.calculationSexRaw = calculationSexRaw
            savedProfile.activityLevelRaw = activityLevelRaw
            savedProfile.goalRaw = goalRaw
        } else {
            savedProfile.age = nil
            savedProfile.heightCentimeters = nil
            savedProfile.weightKilograms = nil
            savedProfile.calculationSexRaw = nil
            savedProfile.activityLevelRaw = nil
            savedProfile.goalRaw = nil
        }

        if profile == nil {
            modelContext.insert(savedProfile)
        }
        dismiss()
    }
}

#Preview {
    CaloriesView()
        .modelContainer(for: [
            PantryItem.self,
            ShoppingItem.self,
            CalorieMeal.self,
            CalorieProfile.self
        ], inMemory: true)
}
