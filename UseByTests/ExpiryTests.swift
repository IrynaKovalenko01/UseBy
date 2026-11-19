//
//  UseByTests.swift
//  UseByTests
//
//  Created by ikoval2 on 10/19/26.
//  Editing + Changes by Tyler 10/26/26
//

import Testing
import Foundation
@testable import UseBy

// ensures the code always runs from main, specifically it'll test the files these run on
@MainActor


struct UseByTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        // Swift Testing Documentation
        // https://developer.apple.com/documentation/testing
    }

    // By Tyler 10/26/26
    // we'll do one test, let's just do an apple that expires x days from now
    func item(expiringIn days: Int) -> PantryItem {
        // lets just say it expires today
        var expiration = Date.now
        // let's us add a random x number of days to get a expiration date,
        // (won't fail because we pick the date)
        if let date = Calendar.current.date(byAdding: .day, value: days, to: .now){
            expiration = date
        }
        return PantryItem(name: "Apple", category: "Produce", storage: .fridge,
       quantity: 1, expiryDate: expiration)
    }

    // 4 tests for each of our different urgencies (see PantryItem urgeny cases)

    // Apple is expired, should show up (Purple?)
    @Test func appleExpired(){
        #expect(item(expiringIn: -1).urgency == .expired)
    }

    // Apple has 2 days left, red/urgent 
    @Test func appleUrgent(){
        #expect(item(expiringIn: 2).urgency == .urgent)
    }

    // Apple has 7 days left, yellow/soon
    @Test func appleSoon(){
        #expect(item(expiringIn: 3).urgency == .soon)
        #expect(item(expiringIn: 7).urgency == .soon)
    }

    // Apple has more than 8 days, safe/green
    @Test func appleSafe(){
         #expect(item(expiringIn: 8).urgency == .safe)
    }
}
