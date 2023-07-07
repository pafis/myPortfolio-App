//
//  CVEvent.swift
//  Portfolio-App
//
//  Created by Pascal Fischer on 07.07.23.
//
import Foundation


/// This is the CVEvent struct responsible for storing a CV event in a CVTimeLineView
struct CVEvent: Identifiable, Equatable {
    let id = UUID()
    let beginningYear: Int
    let endingYear: Int?
    let title: String
    let description: String
    let details: String
    
    /// This returns ending Year - beginning Year
    var YearRange:Int {
        if let endingYear = endingYear {
            return endingYear - beginningYear
        } else
        {
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
