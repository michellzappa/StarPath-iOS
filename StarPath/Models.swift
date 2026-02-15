//
//  Models.swift
//  StarPath
//
//  Data models for celestial bodies, zodiac signs, and display options.
//

import SwiftUI

// MARK: - Zodiac Signs

struct ZodiacSign: Identifiable {
    let id: Int // 0–11
    let glyph: String
    let name: String

    /// Ecliptic longitude at the start of this sign
    var boundaryLongitude: Double { Double(id) * 30 }

    /// Ecliptic longitude at the center of this sign
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

struct CelestialBody: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color

    var isSun: Bool { id == "sun" }
}

let celestialBodies: [CelestialBody] = [
    CelestialBody(id: "sun", name: "Sol", symbol: "☉", color: Color(red: 1.0, green: 0.851, blue: 0.553)),
    CelestialBody(id: "moon", name: "Moon", symbol: "☽", color: Color(red: 0.839, green: 0.871, blue: 1.0)),
    CelestialBody(id: "mercury", name: "Mercury", symbol: "☿", color: Color(red: 0.784, green: 0.961, blue: 1.0)),
    CelestialBody(id: "venus", name: "Venus", symbol: "♀", color: Color(red: 1.0, green: 0.839, blue: 0.918)),
    CelestialBody(id: "mars", name: "Mars", symbol: "♂", color: Color(red: 1.0, green: 0.714, blue: 0.635)),
    CelestialBody(id: "jupiter", name: "Jupiter", symbol: "♃", color: Color(red: 0.976, green: 0.843, blue: 0.694)),
    CelestialBody(id: "saturn", name: "Saturn", symbol: "♄", color: Color(red: 1.0, green: 0.910, blue: 0.655)),
    CelestialBody(id: "uranus", name: "Uranus", symbol: "♅", color: Color(red: 0.675, green: 0.953, blue: 1.0)),
    CelestialBody(id: "neptune", name: "Neptune", symbol: "♆", color: Color(red: 0.718, green: 0.718, blue: 1.0)),
]

// MARK: - View Options

struct ViewOptions {
    var showStars: Bool = true
    var showLabels: Bool = true
    var showDrift: Bool = true
    var showTime: Bool = true
    var showMoon: Bool = true
    var lockZodiac: Bool = false
    var centerSignIndex: Int = 0

    /// The reference longitude: either the Sun's position, or a locked sign center
    func referenceLongitude(sunLon: Double) -> Double {
        if lockZodiac {
            return normalizeAngle(Double(centerSignIndex) * 30 + 15)
        }
        return sunLon
    }
}

// MARK: - Positioned Body (for rendering)

struct PositionedBody: Identifiable {
    let id: String
    let body: CelestialBody
    let longitude: Double
    let relativeDegrees: Double // signed delta from reference, [-180, 180]
    let geocentricDistance: Double // AU

    /// Maps relative degrees to a 0...1 fraction along the axis
    var axisFraction: Double {
        (relativeDegrees + 180) / 360
    }

    /// Whether this body can ever transit in front of the Sun (interior bodies only)
    var canTransitSun: Bool {
        id == "mercury" || id == "venus" || id == "moon"
    }
}

// MARK: - Time Step

enum TimeStep: String, CaseIterable, Identifiable {
    case minute, hour, day, week, month, year

    var id: String { rawValue }

    var label: String {
        rawValue.capitalized
    }

    var shortLabel: String {
        switch self {
        case .minute: return "Min"
        case .hour: return "Hour"
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Planet Detail Info (for info sheet)

struct PlanetDetailInfo: Identifiable {
    let id: String
    let body: CelestialBody
    let longitude: Double           // absolute ecliptic longitude
    let sign: ZodiacSign            // which zodiac sign it's in
    let degreeInSign: Double        // 0–30 degrees within the sign
    let geocentricDistanceAU: Double
    let dailyMotion: Double         // degrees per day (positive = direct, negative = retrograde)
    let isRetrograde: Bool
    let relativeDegrees: Double     // signed delta from Sun (or reference)

    /// Formatted position like "14\u{00B0}32' Aries"
    var formattedPosition: String {
        let totalMinutes = Int(degreeInSign * 60)
        let deg = totalMinutes / 60
        let min = totalMinutes % 60
        return "\(deg)\u{00B0}\(String(format: "%02d", min))' \(sign.name)"
    }

    /// Formatted distance
    var formattedDistance: String {
        if id == "moon" {
            // Show in km for the Moon
            let km = geocentricDistanceAU * 149_597_870.7
            return String(format: "%.0f km", km)
        }
        return String(format: "%.4f AU", geocentricDistanceAU)
    }

    /// Formatted daily motion
    var formattedSpeed: String {
        let absSpeed = abs(dailyMotion)
        let dir = isRetrograde ? " R" : ""
        return String(format: "%.3f\u{00B0}/day%@", absSpeed, dir)
    }

    /// Formatted absolute longitude
    var formattedLongitude: String {
        String(format: "%.2f\u{00B0}", longitude)
    }
}

// MARK: - Trend Data

struct TrendData {
    let series: [String: [Double]] // body id -> array of relative longitudes
    let sampleCount: Int
    let centerIndex: Int
}
