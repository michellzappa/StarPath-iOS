//
//  StarfieldView.swift
//  StarPath
//
//  Celestial sphere of stars viewed from inside. The sphere rotates
//  around the vertical zodiac axis (pure X-axis rotation), driven by
//  the Sun's ecliptic longitude. Stars spin top-to-bottom like being
//  inside a giant hamster wheel as time moves.
//

import SwiftUI

struct StarfieldView: View {
    let date: Date

    // Star configuration
    private static let stars = StarCatalog.makeStars(count: 2400, seed: 42)

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let cx = w / 2
            let cy = h / 2

            // Sphere fills the full screen
            let radius = h

            // Rotation driven by Sun's ecliptic longitude
            let d = daysSinceJ2000(date)
            let sunLon = sunGeocentricLongitude(d: d).lon
            let rotAngle = -toRad(sunLon)

            let cosR = cos(rotAngle)
            let sinR = sin(rotAngle)

            for star in Self.stars {
                let x = star.x
                var y = star.y
                var z = star.z

                // Rotation around X axis — pure top-to-bottom hamster wheel
                let ry = y * cosR - z * sinR
                let rz = y * sinR + z * cosR
                y = ry
                z = rz

                // Only draw front hemisphere
                guard z > -0.05 else { continue }

                // Perspective projection — lower divisor = wider spread
                let perspective = 1.3 + z
                let sx = cx + (x / perspective) * radius
                let sy = cy - (y / perspective) * radius

                // Depth-based brightness: stars closer (z near 1) are brighter
                let depthFade = (z + 0.05) / 1.05  // 0...1
                let alpha = star.baseBrightness * depthFade

                let rect = CGRect(
                    x: sx - star.size / 2,
                    y: sy - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
    }
}

private struct StarSample {
    let x: Double
    let y: Double
    let z: Double
    let baseBrightness: Double
    let size: Double
}

private enum StarCatalog {
    static func makeStars(count: Int, seed: UInt32) -> [StarSample] {
        var rng = SeededRandom(seed: seed)
        var stars: [StarSample] = []
        stars.reserveCapacity(count)

        for _ in 0..<count {
            let u = rng.next() * 2.0 - 1.0
            let theta = rng.next() * .pi * 2.0
            let r = sqrt(1.0 - u * u)

            stars.append(
                StarSample(
                    x: r * cos(theta),
                    y: r * sin(theta),
                    z: u,
                    baseBrightness: 0.15 + rng.next() * 0.55,
                    size: 0.6 + rng.next() * 1.4
                )
            )
        }

        return stars
    }
}

// MARK: - Seeded PRNG

struct SeededRandom {
    private var t: UInt32

    init(seed: UInt32) {
        t = seed
    }

    mutating func next() -> Double {
        t &+= 0x6D2B79F5
        var n = (t ^ (t >> 15)) &* (1 | t)
        n ^= n &+ (n ^ (n >> 7)) &* (61 | n)
        return Double((n ^ (n >> 14)) &>> 0) / 4294967296.0
    }
}
