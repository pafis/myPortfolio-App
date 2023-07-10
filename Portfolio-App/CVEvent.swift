//
//  CVEvent.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//
import Foundation

/// This is the CVEvent struct responsible for storing a CV event in a CVTimeLineView
struct CVEvent: Identifiable, Equatable {
    let id = UUID() // A unique identifier for the event
    let beginningYear: Int // The beginning year of the event
    let endingYear: Int? // The ending year of the event (optional)
    let title: String // The title of the event
    let description: String // A brief description of the event
    let details: String // Additional details about the event

    /// This returns ending Year - beginning Year
    var YearRange: Int {
        if let endingYear = endingYear {
            return endingYear - beginningYear
        } else {
            return 1
        }
    }

    /// This is a helper for CVTimeLineView returning the String with the timespan of a CVEvent
    var dateRange: String {
        if let endingYear = endingYear {
            return "\(beginningYear) - \(endingYear)"
        } else {
            return "\(beginningYear) - Present"
        }
    }
}