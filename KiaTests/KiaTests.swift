//
//  KiaTests.swift
//  KiaTests
//
//  Created by Lukáš Foldýna on 21/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import XCTest

final class KiaTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testDateFormatterExample() throws {
        // Example test for the new MillisecondDateFormatter
        // Note: This is a documentation example - actual implementation 
        // would be tested in the main app target
        
        let testDateString = "2024-05-16 11:52:59.116"
        
        // This demonstrates the expected format
        XCTAssertTrue(testDateString.contains("2024-05-16"))
        XCTAssertTrue(testDateString.contains("11:52:59.116"))
        
        // Test basic date formatter setup pattern
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let date = formatter.date(from: testDateString)
        XCTAssertNotNil(date, "Date should be parseable with the correct format")
        
        if let parsedDate = date {
            let formattedBack = formatter.string(from: parsedDate)
            XCTAssertEqual(formattedBack, testDateString, "Round-trip should work")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}
