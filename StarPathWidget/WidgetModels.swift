//
//  WidgetModels.swift
//  StarPathWidget
//
//  Minimal data models for the widget and control.
//  Mirrors the main app's Models.swift but only what the widget needs.
//

import SwiftUI

enum WidgetSharedDefaults {
    static let appGroupIdentifier = "group.AestheticHermetics.StarPath"
    static let invertZodiacOrderKey = "sp_invertZodiacOrder"

    static var shared: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}

func zodiacAxisFraction(relativeDegrees: Double, inverted: Bool) -> Double {
    let displayDegrees = inverted ? -relativeDegrees : relativeDegrees
    return (displayDegrees + 180) / 360
}

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
    WidgetCelestialBody(id: "sun", name: "Sun", symbol: "☉", color: Color(red: 1.00, green: 0.85, blue: 0.40)),
    WidgetCelestialBody(id: "moon", name: "Moon", symbol: "☽", color: Color(red: 0.78, green: 0.78, blue: 0.80)),
    WidgetCelestialBody(id: "mercury", name: "Mercury", symbol: "☿", color: Color(red: 0.72, green: 0.66, blue: 0.58)),
    WidgetCelestialBody(id: "venus", name: "Venus", symbol: "♀", color: Color(red: 0.96, green: 0.86, blue: 0.62)),
    WidgetCelestialBody(id: "mars", name: "Mars", symbol: "♂", color: Color(red: 0.82, green: 0.42, blue: 0.28)),
    WidgetCelestialBody(id: "jupiter", name: "Jupiter", symbol: "♃", color: Color(red: 0.86, green: 0.74, blue: 0.58)),
    WidgetCelestialBody(id: "saturn", name: "Saturn", symbol: "♄", color: Color(red: 0.92, green: 0.82, blue: 0.58)),
    WidgetCelestialBody(id: "uranus", name: "Uranus", symbol: "♅", color: Color(red: 0.62, green: 0.86, blue: 0.88)),
    WidgetCelestialBody(id: "neptune", name: "Neptune", symbol: "♆", color: Color(red: 0.32, green: 0.46, blue: 0.84)),
]

// MARK: - Widget Positioned Body

struct WidgetPositionedBody: Identifiable {
    let id: String
    let body: WidgetCelestialBody
    let longitude: Double
    let relativeDegrees: Double
    let geocentricDistance: Double

    /// Maps relative degrees to a 0...1 fraction along the horizontal axis
    var axisFraction: Double {
        zodiacAxisFraction(relativeDegrees: relativeDegrees, inverted: false)
    }

    func axisFraction(inverted: Bool) -> Double {
        zodiacAxisFraction(relativeDegrees: relativeDegrees, inverted: inverted)
    }

    /// Whether this body can ever transit in front of the Sun (interior bodies only)
    var canTransitSun: Bool {
        id == "mercury" || id == "venus" || id == "moon"
    }
}

// MARK: - Widget Data Computation

func widgetPositionedBodies(for date: Date) -> [WidgetPositionedBody] {
    let state = geocentricLongitudes(for: date)
    let depth = geocentricDepthContext(for: date)
    let sunLon = state.sun

    return widgetBodies.map { body in
        let lon = state.longitude(for: body.id)
        let rel = signedDelta(lon, sunLon)
        let dist = depth.distance(for: body.id)
        return WidgetPositionedBody(id: body.id, body: body, longitude: lon, relativeDegrees: rel, geocentricDistance: dist)
    }
}

/// Depth-sort bodies for rendering: Sun at z=12, interior transiting bodies at z=14,
/// all others at z=9. Matches the main app's ZodiacChartView.depthSortedBodies logic.
func widgetDepthSortedBodies(_ bodies: [WidgetPositionedBody], sunLongitude: Double) -> [WidgetPositionedBody] {
    let overlapThresholdDeg: Double = 7
    let sunDist = bodies.first { $0.id == "sun" }?.geocentricDistance ?? 1

    return bodies
        .map { pb -> (body: WidgetPositionedBody, zOrder: Int) in
            if pb.body.isSun {
                return (pb, 12)
            }
            let nearSun = abs(signedDelta(pb.longitude, sunLongitude)) <= overlapThresholdDeg
            if nearSun && pb.canTransitSun && pb.geocentricDistance < sunDist {
                return (pb, 14)
            }
            return (pb, 9)
        }
        .sorted { $0.zOrder < $1.zOrder }
        .map(\.body)
}

func widgetInvertZodiacOrder() -> Bool {
    WidgetSharedDefaults.shared.bool(forKey: WidgetSharedDefaults.invertZodiacOrderKey)
}
