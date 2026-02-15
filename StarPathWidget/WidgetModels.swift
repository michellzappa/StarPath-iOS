//
//  WidgetModels.swift
//  StarPathWidget
//
//  Minimal data models for the widget and control.
//  Mirrors the main app's Models.swift but only what the widget needs.
//

import SwiftUI

// MARK: - Zodiac Signs

struct ZodiacSign: Identifiable {
    let id: Int // 0–11
    let glyph: String
    let name: String

    var boundaryLongitude: Double { Double(id) * 30 }
    var centerLongitude: Double { Double(id) * 30 + 15 }
}

let zodiacSigns: [ZodiacSign] = [
    ZodiacSign(id: 0, glyph: "♈", name: "Aries"),
    ZodiacSign(id: 1, glyph: "♉", name: "Taurus"),
    ZodiacSign(id: 2, glyph: "♊", name: "Gemini"),
    ZodiacSign(id: 3, glyph: "♋", name: "Cancer"),
    ZodiacSign(id: 4, glyph: "♌", name: "Leo"),
    ZodiacSign(id: 5, glyph: "♍", name: "Virgo"),
    ZodiacSign(id: 6, glyph: "♎", name: "Libra"),
    ZodiacSign(id: 7, glyph: "♏", name: "Scorpio"),
    ZodiacSign(id: 8, glyph: "♐", name: "Sagittarius"),
    ZodiacSign(id: 9, glyph: "♑", name: "Capricorn"),
    ZodiacSign(id: 10, glyph: "♒", name: "Aquarius"),
    ZodiacSign(id: 11, glyph: "♓", name: "Pisces"),
]

func zodiacSign(fromLongitude lon: Double) -> ZodiacSign {
    let index = Int(normalizeAngle(lon) / 30) % 12
    return zodiacSigns[index]
}

// MARK: - Celestial Bodies

struct WidgetCelestialBody: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color

    var isSun: Bool { id == "sun" }
}

let widgetBodies: [WidgetCelestialBody] = [
    WidgetCelestialBody(id: "sun", name: "Sun", symbol: "☉", color: Color(red: 1.0, green: 0.851, blue: 0.553)),
    WidgetCelestialBody(id: "moon", name: "Moon", symbol: "☽", color: Color(red: 0.839, green: 0.871, blue: 1.0)),
    WidgetCelestialBody(id: "mercury", name: "Mercury", symbol: "☿", color: Color(red: 0.784, green: 0.961, blue: 1.0)),
    WidgetCelestialBody(id: "venus", name: "Venus", symbol: "♀", color: Color(red: 1.0, green: 0.839, blue: 0.918)),
    WidgetCelestialBody(id: "mars", name: "Mars", symbol: "♂", color: Color(red: 1.0, green: 0.714, blue: 0.635)),
    WidgetCelestialBody(id: "jupiter", name: "Jupiter", symbol: "♃", color: Color(red: 0.976, green: 0.843, blue: 0.694)),
    WidgetCelestialBody(id: "saturn", name: "Saturn", symbol: "♄", color: Color(red: 1.0, green: 0.910, blue: 0.655)),
    WidgetCelestialBody(id: "uranus", name: "Uranus", symbol: "♅", color: Color(red: 0.675, green: 0.953, blue: 1.0)),
    WidgetCelestialBody(id: "neptune", name: "Neptune", symbol: "♆", color: Color(red: 0.718, green: 0.718, blue: 1.0)),
]

// MARK: - Widget Positioned Body

struct WidgetPositionedBody: Identifiable {
    let id: String
    let body: WidgetCelestialBody
    let longitude: Double
    let relativeDegrees: Double

    /// Maps relative degrees to a 0...1 fraction along the horizontal axis
    var axisFraction: Double {
        (relativeDegrees + 180) / 360
    }
}

// MARK: - Widget Data Computation

func widgetPositionedBodies(for date: Date) -> [WidgetPositionedBody] {
    let state = geocentricLongitudes(for: date)
    let sunLon = state.sun

    return widgetBodies.map { body in
        let lon = state.longitude(for: body.id)
        let rel = signedDelta(lon, sunLon)
        return WidgetPositionedBody(id: body.id, body: body, longitude: lon, relativeDegrees: rel)
    }
}
