import SwiftUI

struct RecipeDetailView: View {
    let recipeID: Int
    let title: String

    @State private var recipe: SpoonacularRecipeInformation?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.secondary)
                        .padding()
                } else if let recipe {
                    HStack(spacing: 32) {
                        if let minutes = recipe.readyInMinutes {
                            statTile(value: "\(minutes)", label: "min")
                        }
                        if let servings = recipe.servings {
                            statTile(value: "\(servings)", label: "servings")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    Divider()

                    if let ingredients = recipe.extendedIngredients, !ingredients.isEmpty {
                        Text("Ingredients")
                            .font(.title3).bold()
                        ForEach(ingredients) { ing in
                            Text("• \(ing.original ?? ing.name)")
                        }
                    }

                    Divider()

                    if let instructions = recipe.instructions, !instructions.isEmpty {
                        Text("Instructions")
                            .font(.title3).bold()
                        Text(instructions)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            isLoading = true
            do {
                recipe = try await SpoonacularAPI().recipeInformation(id: recipeID)
            } catch {
                errorMessage = "Couldn't load recipe details."
            }
            isLoading = false
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2).bold()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}
