//
//  UseByApp.swift
//  UseBy
//
//  Created by ikoval2 on 10/19/26.
//

import SwiftUI
import SwiftData

@main
struct UseByApp: App {
    var sharedModelContainer: ModelContainer = {
        // Register each persisted feature model in the app's single store so
        // meal logs and calorie preferences survive relaunches.
        let schema = Schema([
            PantryItem.self,
            ShoppingItem.self,
            CalorieMeal.self,
            CalorieProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            LaunchContainerView()
        }
        .modelContainer(sharedModelContainer)
    }
}
