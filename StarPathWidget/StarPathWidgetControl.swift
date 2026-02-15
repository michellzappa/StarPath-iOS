//
//  StarPathWidgetControl.swift
//  StarPathWidget
//
//  Control Center / Lock Screen control showing the current Sun sign.
//  Tapping opens the Starpath app.
//

import AppIntents
import SwiftUI
import WidgetKit

struct StarPathWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "AestheticHermetics.StarPath.StarPathControl"
        ) {
            ControlWidgetButton(action: OpenStarPathIntent()) {
                let state = geocentricLongitudes(for: Date())
                let sign = zodiacSign(fromLongitude: state.sun)

                Label {
                    Text("\(sign.glyph)\u{FE0E} \(sign.name)")
                } icon: {
                    Image(systemName: "sun.max.fill")
                }
            }
        }
        .displayName("Sun Sign")
        .description("Shows the current Sun sign. Tap to open Starpath.")
    }
}

// MARK: - Open App Intent

struct OpenStarPathIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Starpath"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
