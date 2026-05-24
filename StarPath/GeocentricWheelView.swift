//
//  GeocentricWheelView.swift
//  StarPath
//
//  Circular wheel view with two modes:
//
//  Geocentric (default): Earth at center, all bodies at geocentric
//  longitudes in Chaldean order. A line from center through any body
//  hits the zodiac sign it's "in" — matches the linear view exactly.
//
//  Heliocentric: Sun at center, planets at heliocentric longitudes
//  in orbital order. Optional sightlines from Earth through each
//  planet to the zodiac ring show the geocentric perspective.
//
//  Convention: 0° Aries at 9 o'clock, signs counter-clockwise.
//

import SwiftUI

/// Convert ecliptic longitude to screen angle (radians).
/// 0° Aries → 9 o'clock (π), signs counter-clockwise.
private func eclipticToScreenAngle(_ longitude: Double) -> Double {
    toRad(-(longitude) + 180)
}

/// Polar to cartesian with given center and radius.
private func polarPoint(cx: Double, cy: Double, r: Double, angle: Double) -> CGPoint {
    CGPoint(x: cx + r * cos(angle), y: cy + r * sin(angle))
}

struct GeocentricWheelView: View {
    let positionedBodies: [PositionedBody]
    let currentState: GeocentricState?
    let helioState: HeliocentricState?
    let options: ViewOptions
    var moonPhaseIcon: String = "moonphase.full.moon"
    var onTapBody: ((String) -> Void)?

    private var isHelio: Bool { options.heliocentricWheel }

    // Geocentric: Chaldean order (apparent speed)
    private static let geoRingFractions: [String: Double] = [
        "moon":    0.14,
        "mercury": 0.25,
        "venus":   0.36,
        "sun":     0.47,
        "mars":    0.58,
        "jupiter": 0.69,
        "saturn":  0.79,
        "uranus":  0.89,
        "neptune": 0.97,
    ]

    // Heliocentric: orbital distance order
    private static let helioRingFractions: [String: Double] = [
        "mercury": 0.14,
        "venus":   0.26,
        "earth":   0.38,
        "mars":    0.50,
        "jupiter": 0.62,
        "saturn":  0.74,
        "uranus":  0.86,
        "neptune": 0.96,
    ]

    private static let earthColor = Color(red: 0.4, green: 0.7, blue: 1.0)
    private static let earthBody = CelestialBody(
        id: "earth",
        name: "Earth",
        symbol: "\u{2295}",
        color: Color(red: 0.30, green: 0.55, blue: 0.90)
    )
    private static let sunColor = Color(red: 1, green: 0.851, blue: 0.553)

    private var ringFractions: [String: Double] {
        isHelio ? Self.helioRingFractions : Self.geoRingFractions
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let side = min(size.width, size.height)
            let cx = Double(size.width / 2)
            let cy = Double(size.height / 2)
            let outerR = Double(side / 2) - 4
            let zodiacWidth = 36.0
            let innerR = outerR - zodiacWidth
            let planetMaxR = innerR - 8

            ZStack {
                // Zodiac ring
                zodiacCanvas(cx: cx, cy: cy, innerR: innerR, outerR: outerR)

                // Zodiac glyphs
                let midR = (innerR + outerR) / 2
                ForEach(0..<12, id: \.self) { i in
                    let angle = eclipticToScreenAngle(Double(i) * 30 + 15)
                    let pt = polarPoint(cx: cx, cy: cy, r: midR, angle: angle)
                    Text("\(zodiacSigns[i].glyph)\u{FE0E}")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.85))
                        .position(pt)
                }

                // Orbital rings
                orbitalCanvas(cx: cx, cy: cy, maxR: planetMaxR, innerR: innerR)

                if isHelio {
                    heliocentricBodies(cx: cx, cy: cy, planetMaxR: planetMaxR, outerR: outerR)
                } else {
                    geocentricBodies(cx: cx, cy: cy, planetMaxR: planetMaxR)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Geocentric Layout

    @ViewBuilder
    private func geocentricBodies(cx: Double, cy: Double, planetMaxR: Double) -> some View {
        // All bodies at geocentric longitudes
        ForEach(positionedBodies, id: \.id) { pb in
            let frac = Self.geoRingFractions[pb.id] ?? 0.5
            let r = frac * planetMaxR
            let angle = eclipticToScreenAngle(pb.longitude)
            let pt = polarPoint(cx: cx, cy: cy, r: r, angle: angle)

            if pb.body.isSun {
                sunNode(pb: pb).position(pt)
            } else if pb.id == "moon" {
                moonNode(pb: pb).position(pt)
            } else {
                planetNode(pb: pb).position(pt)
            }
        }

        // Earth at center
        earthNode()
            .position(x: cx, y: cy)
    }

    // MARK: - Heliocentric Layout

    @ViewBuilder
    private func heliocentricBodies(cx: Double, cy: Double, planetMaxR: Double, outerR: Double) -> some View {
        if let helio = helioState {
            // Sightlines from Earth to each planet's geocentric zodiac position
            sightlineCanvas(cx: cx, cy: cy, planetMaxR: planetMaxR, outerR: outerR, helio: helio)

            // Planets at heliocentric longitudes
            ForEach(positionedBodies.filter { !$0.body.isSun && $0.id != "moon" }, id: \.id) { pb in
                let frac = Self.helioRingFractions[pb.id] ?? 0.5
                let r = frac * planetMaxR
                let helioLon = helio.longitude(for: pb.id)
                let angle = eclipticToScreenAngle(helioLon)
                let pt = polarPoint(cx: cx, cy: cy, r: r, angle: angle)

                planetNode(pb: pb).position(pt)
            }

            // Earth on its ring
            let earthFrac = Self.helioRingFractions["earth"]!
            let earthR = earthFrac * planetMaxR
            let earthAngle = eclipticToScreenAngle(helio.earth)
            let earthPt = polarPoint(cx: cx, cy: cy, r: earthR, angle: earthAngle)

            earthNode().position(earthPt)

            // Moon companion near Earth
            if options.showMoon, let moonBody = positionedBodies.first(where: { $0.id == "moon" }) {
                let moonOffset = 20.0
                let moonAngle = eclipticToScreenAngle(moonBody.longitude)
                let moonPt = CGPoint(
                    x: Double(earthPt.x) + moonOffset * cos(moonAngle),
                    y: Double(earthPt.y) + moonOffset * sin(moonAngle)
                )
                miniMoonNode(pb: moonBody).position(moonPt)
            }
        }

        // Sun at center
        if let sunBody = positionedBodies.first(where: { $0.body.isSun }) {
            sunNode(pb: sunBody).position(x: cx, y: cy)
        }
    }

    // MARK: - Sightlines (Heliocentric mode)
    // Lines from Earth through each planet to the zodiac ring,
    // showing which zodiac sign each planet appears in from Earth.

    @ViewBuilder
    private func sightlineCanvas(cx: Double, cy: Double, planetMaxR: Double, outerR: Double, helio: HeliocentricState) -> some View {
        Canvas { context, _ in
            let earthFrac = Self.helioRingFractions["earth"]!
            let earthR = earthFrac * planetMaxR
            let earthAngle = eclipticToScreenAngle(helio.earth)
            let earthPt = polarPoint(cx: cx, cy: cy, r: earthR, angle: earthAngle)
            let ex = Double(earthPt.x)
            let ey = Double(earthPt.y)

            for pb in positionedBodies where !pb.body.isSun && pb.id != "moon" {
                // Geocentric longitude = where planet appears from Earth
                let geoAngle = eclipticToScreenAngle(pb.longitude)
                // Extend line from Earth in the geocentric direction to the zodiac ring
                let zodiacPt = polarPoint(cx: ex, cy: ey, r: outerR, angle: geoAngle)

                var line = Path()
                line.move(to: earthPt)
                line.addLine(to: zodiacPt)

                let color = celestialBodies.first { $0.id == pb.id }?.color ?? .white
                context.stroke(line, with: .color(color.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [3, 5]))
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Zodiac Ring (Canvas)

    @ViewBuilder
    private func zodiacCanvas(cx: Double, cy: Double, innerR: Double, outerR: Double) -> some View {
        Canvas { context, _ in
            let center = CGPoint(x: cx, y: cy)

            for i in 0..<12 {
                let startLon = Double(i) * 30
                let endLon = startLon + 30
                let sa = Angle(radians: eclipticToScreenAngle(startLon))
                let ea = Angle(radians: eclipticToScreenAngle(endLon))

                var seg = Path()
                seg.addArc(center: center, radius: outerR, startAngle: ea, endAngle: sa, clockwise: false)
                seg.addArc(center: center, radius: innerR, startAngle: sa, endAngle: ea, clockwise: true)
                seg.closeSubpath()

                let opacity = i.isMultiple(of: 2) ? 0.06 : 0.03
                context.fill(seg, with: .color(.white.opacity(opacity)))

                let bAngle = eclipticToScreenAngle(startLon)
                let p1 = polarPoint(cx: cx, cy: cy, r: innerR, angle: bAngle)
                let p2 = polarPoint(cx: cx, cy: cy, r: outerR, angle: bAngle)
                var line = Path()
                line.move(to: p1)
                line.addLine(to: p2)
                context.stroke(line, with: .color(.white.opacity(0.2)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Orbital Guides (Canvas)

    @ViewBuilder
    private func orbitalCanvas(cx: Double, cy: Double, maxR: Double, innerR: Double) -> some View {
        let fracs = ringFractions
        Canvas { context, _ in
            for (bodyId, frac) in fracs {
                let r = frac * maxR
                var path = Path()
                path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))

                let color: Color
                if bodyId == "sun" {
                    color = Self.sunColor
                } else if bodyId == "earth" {
                    color = Self.earthColor
                } else {
                    color = celestialBodies.first { $0.id == bodyId }?.color ?? .white
                }
                context.stroke(path, with: .color(color.opacity(0.35)), lineWidth: 1)
            }

            // Inner ring edge
            var edge = Path()
            edge.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
            context.stroke(edge, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
        }
    }

    // MARK: - Earth Node

    @ViewBuilder
    private func earthNode() -> some View {
        if options.realisticPlanets {
            PlanetSphereView(planet: Self.earthBody, diameter: 16)
        } else {
            let fillColor = Self.earthColor.mix(with: .black, by: 0.45)

            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Self.earthColor.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: Self.earthColor.opacity(0.4), radius: 8)

                Text("\u{2295}\u{FE0E}")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Self.earthColor)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
        }
    }

    // MARK: - Sun Node

    @ViewBuilder
    private func sunNode(pb: PositionedBody) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1, green: 0.973, blue: 0.851),
                        Color(red: 1, green: 0.851, blue: 0.553),
                    ]),
                    center: .init(x: 0.36, y: 0.34),
                    startRadius: 0,
                    endRadius: 18
                )
            )
            .frame(width: 36, height: 36)
            .shadow(color: Color(red: 1, green: 0.808, blue: 0.459).opacity(0.75), radius: 12)
            .overlay(
                Circle()
                    .stroke(Self.sunColor.opacity(0.3), lineWidth: 1.5)
            )
            .onTapGesture { onTapBody?(pb.id) }
    }

    // MARK: - Moon Node

    @ViewBuilder
    private func moonNode(pb: PositionedBody) -> some View {
        let moonColor = pb.body.color
        let fillColor = moonColor.mix(with: .black, by: 0.55)

        Group {
            if options.realisticPlanets {
                PlanetSphereView(planet: pb.body, diameter: 18)
            } else {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 29, height: 29)
                        .overlay(Circle().stroke(moonColor.opacity(0.5), lineWidth: 1))
                        .shadow(color: moonColor.opacity(0.35), radius: 8)

                    Image(systemName: moonPhaseIcon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(moonColor)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .allowsHitTesting(false)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture { onTapBody?(pb.id) }
    }

    // MARK: - Mini Moon (heliocentric companion)

    @ViewBuilder
    private func miniMoonNode(pb: PositionedBody) -> some View {
        let moonColor = pb.body.color
        let fillColor = moonColor.mix(with: .black, by: 0.55)

        Group {
            if options.realisticPlanets {
                PlanetSphereView(planet: pb.body, diameter: 12)
            } else {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(moonColor.opacity(0.5), lineWidth: 0.5))
                        .shadow(color: moonColor.opacity(0.3), radius: 4)

                    Image(systemName: moonPhaseIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(moonColor)
                        .allowsHitTesting(false)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture { onTapBody?(pb.id) }
    }

    // MARK: - Planet Node

    @ViewBuilder
    private func planetNode(pb: PositionedBody) -> some View {
        let planetColor = pb.body.color
        let fillColor = planetColor.mix(with: .black, by: 0.55)

        Group {
            if options.realisticPlanets {
                PlanetSphereView(planet: pb.body, diameter: 18)
            } else {
                ZStack {
                    Circle()
                        .fill(fillColor)
                        .frame(width: 29, height: 29)
                        .overlay(Circle().stroke(planetColor.opacity(0.5), lineWidth: 1))
                        .shadow(color: planetColor.opacity(0.35), radius: 8)

                    Text("\(pb.body.symbol)\u{FE0E}")
                        .font(.system(size: symbolSize(for: pb.body.symbol), weight: .bold))
                        .foregroundColor(planetColor)
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        .allowsHitTesting(false)
                }
            }
        }
        .contentShape(Circle())
        .onTapGesture { onTapBody?(pb.id) }
    }

    // MARK: - Helpers

    private func symbolSize(for symbol: String) -> CGFloat {
        switch symbol {
        case "☿": return 18
        case "♀": return 17
        case "♂": return 17
        case "♃": return 17
        case "♄": return 18
        case "♅": return 17
        case "♆": return 17
        default:  return 17
        }
    }
}
