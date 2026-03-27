//
//  StarPathDateFormats.swift
//  StarPath
//
//  Shared formatters reused across frequently updated views.
//

import Foundation

enum StarPathDateFormats {
    static let timestamp: DateFormatter = makeFormatter(dateStyle: .medium, timeStyle: .short)
    static let eventDay: DateFormatter = makeFormatter(dateStyle: .full, timeStyle: .none)
    static let eventTime: DateFormatter = makeFormatter(dateStyle: .none, timeStyle: .short)
    static let savedDate: DateFormatter = makeFormatter(dateStyle: .medium, timeStyle: .none)
    static let savedTime: DateFormatter = makeFormatter(dateStyle: .none, timeStyle: .short)

    private static func makeFormatter(
        dateStyle: DateFormatter.Style,
        timeStyle: DateFormatter.Style
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.timeZone = .current
        return formatter
    }
}
