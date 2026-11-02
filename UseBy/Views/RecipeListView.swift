import SwiftUI
import SwiftData

struct RecipeListView: View {
    @Query private var pantryItems: [PantryItem]
    @State private var recipes: [SpoonacularRecipe] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Finding recipes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Recipes Unavailable",
                        systemImage: "fork.knife",
                        description: Text(error)
                    )
                } else if recipes.isEmpty {
                    ContentUnavailableView(
                        "Nothing to Cook",
                        systemImage: "cart",
                        description: Text("Add items to your pantry to get recipe suggestions.")
                    )
                } else {
                    List(recipes) { recipe in
                        NavigationLink(destination: RecipeDetailView(recipeID: recipe.id, title: recipe.title)) {
                            RecipeRowView(recipe: recipe)
                        }
                    }
                }
            }
            .navigationTitle("Cook")
            .task {
                await loadRecipes()
            }
            .refreshable {
                await loadRecipes()
            }
        }
    }

    private func loadRecipes() async {
        guard !pantryItems.isEmpty else { recipes = []; return }
        isLoading = true
        errorMessage = nil
        let names = pantryItems.map { $0.name }
        do {
            recipes = try await SpoonacularAPI().recipesByIngredients(names, number: 10)
        } catch {
            errorMessage = "Couldn't load recipes — make sure the Spoonacular API key is set."
        }
        isLoading = false
    }
}

struct RecipeRowView: View {
    let recipe: SpoonacularRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.title)
                .font(.headline)
            HStack(spacing: 12) {
                if let used = recipe.usedIngredientCount {
                    Label("\(used) you have", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if let missing = recipe.missedIngredientCount, missing > 0 {
                    Label("\(missing) missing", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
