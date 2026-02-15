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
    private let starCount = 2400
    private let seed: UInt32 = 42

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

            // Generate deterministic star positions on the unit sphere
            var rng = SeededRandom(seed: seed)

            for _ in 0..<starCount {
                // Uniform distribution on sphere using cylindrical method
                let u = rng.next() * 2.0 - 1.0  // [-1, 1]
                let theta = rng.next() * .pi * 2.0
                let r = sqrt(1.0 - u * u)

                let x = r * cos(theta)
                var y = r * sin(theta)
                var z = u

                // Base brightness variation
                let baseBrightness = 0.15 + rng.next() * 0.55
                // Size variation
                let starSize = 0.6 + rng.next() * 1.4

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
                let alpha = baseBrightness * depthFade

                let rect = CGRect(
                    x: sx - starSize / 2,
                    y: sy - starSize / 2,
                    width: starSize,
                    height: starSize
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(alpha))
                )
            }
        }
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
