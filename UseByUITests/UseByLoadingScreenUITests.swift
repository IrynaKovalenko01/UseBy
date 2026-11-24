//
//  UseByLoadingScreenUITests.swift
//  UseBy
//
//  Created by Mikkel Josael Ella Serrantes
import XCTest

final class LoadingScreenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private var loadingScreen: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "loadingScreen")
            .firstMatch
    }

    private var pantryScreen: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "pantryScreen")
            .firstMatch
    }

    func testLoadingScreenAppearsOnLaunch() {
        app.launch()

        let loadingScreen = app.descendants(matching: .any)
            .matching(identifier: "loadingScreen")
            .firstMatch

        XCTAssertTrue(
            loadingScreen.waitForExistence(timeout: 3),
            "Loading screen should appear on launch."
        )
    }

    func testLoadingScreenTransitionsToPantry() {
        app.launch()
        XCTAssertTrue(
            pantryScreen.waitForExistence(timeout: 15),
            "The pantry should become visible after startup finishes."
        )
        XCTAssertFalse(
            loadingScreen.exists,
            "The loading screen should no longer be visible once the pantry appears."
        )
    }

    func testLoadingScreenDoesNotReappearAfterStartup() {
        app.launch()
        XCTAssertTrue(pantryScreen.waitForExistence(timeout: 15))
        XCTAssertFalse(loadingScreen.exists)

        // A short observation period catches unexpected loading-screen resets.
        let reappeared = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: loadingScreen
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [reappeared], timeout: 2),
            .timedOut,
            "The loading screen should not reappear while the app remains on the pantry."
        )
    }
}

