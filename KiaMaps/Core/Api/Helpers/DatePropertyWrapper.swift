//
//  DatePropertyWrapper.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 06.06.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

protocol DecodeDateFormatter {
    static var formatter: DecodeDateFormatter { get }

    func string(from date: Date) -> String
    func date(from string: String?) -> Date?
}

struct TimeIntervalDateFormatter: DecodeDateFormatter {
    static let formatter: DecodeDateFormatter = TimeIntervalDateFormatter()

    init() {}

    func string(from date: Date) -> String {
        String(date.timeIntervalSince1970 * 1000)
    }

    func date(from string: String?) -> Date? {
        guard let string = string, let number = TimeInterval(string) else { return nil }
        return Date(timeIntervalSince1970: number / 1000)
    }
}

struct MillisecondDateFormatter: DecodeDateFormatter {
    static let formatter: DecodeDateFormatter = MillisecondDateFormatter()
    
    private let dateFormatter: DateFormatter
    
    init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    }
    
    func string(from date: Date) -> String {
        dateFormatter.string(from: date)
    }
    
    func date(from string: String?) -> Date? {
        guard let string = string else { return nil }
        return dateFormatter.date(from: string)
    }
}

@propertyWrapper
struct DateValue<Formatter: DecodeDateFormatter>: Codable {
    enum ParsingError: Error {
        case invalidString(String, [CodingKey])
    }

    var wrappedValue: Date

    init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            guard let value = Formatter.formatter.date(from: string) else {
                throw ParsingError.invalidString(string, decoder.codingPath)
            }
            wrappedValue = value
        } else {
            wrappedValue = try container.decode(Date.self)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let string = Formatter.formatter.string(from: wrappedValue)
        try container.encode(string)
    }
}

// MARK: - Convenience TypeAliases

/// DateValue for parsing timestamps in milliseconds since epoch
typealias TimestampDateValue = DateValue<TimeIntervalDateFormatter>

/// DateValue for parsing date strings in format "yyyy-MM-dd HH:mm:ss.SSS"
typealias MillisecondDateValue = DateValue<MillisecondDateFormatter>

// MARK: - Usage Examples
/*
 Usage examples:
 
 // For timestamps like "1716728779116" (milliseconds since epoch)
 @TimestampDateValue var registrationDate: Date
 
 // For date strings like "2024-05-16 11:52:59.116"
 @MillisecondDateValue var eventTime: Date
 
 // Original syntax still works
 @DateValue<TimeIntervalDateFormatter> var timestamp: Date
 @DateValue<MillisecondDateFormatter> var dateString: Date
 */
