//
//  PlanetSphereView.swift
//  StarPath
//
//  Procedural shaded-sphere rendering of a celestial planet. Used when the
//  "Realistic Planets" option is on, in place of the alchemical glyph.
//

import SwiftUI

struct PlanetSphereView: View {
    let planet: CelestialBody
    let diameter: CGFloat
    var lightDirection: UnitPoint = UnitPoint(x: 0.32, y: 0.30)

    var body: some View {
        Group {
            if planet.isSun {
                sunSphere
            } else {
                planetSphere
            }
        }
        .frame(width: outerWidth, height: outerHeight)
    }

    // MARK: - Outer frame (Saturn ring extends beyond the disc)

    private var outerWidth: CGFloat {
        planet.id == "saturn" ? diameter * 1.95 : diameter
    }

    private var outerHeight: CGFloat {
        planet.id == "saturn" ? diameter * 1.35 : diameter
    }

    // MARK: - Sun (kept consistent with existing sun rendering)

    private var sunSphere: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(red: 1, green: 0.973, blue: 0.851),
                        planet.color,
                    ]),
                    center: .init(x: 0.36, y: 0.34),
                    startRadius: 0,
                    endRadius: diameter * 0.55
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: planet.color.opacity(0.7), radius: diameter * 0.35)
            .overlay(
                Circle()
                    .stroke(planet.color.opacity(0.3), lineWidth: max(diameter * 0.04, 1))
            )
    }

    // MARK: - Generic planet

    private var planetSphere: some View {
        ZStack {
            if planet.id == "saturn" {
                // Back half of ring (behind planet)
                ringShape
                    .mask(ringBackMask)
            }

            shadedDisc
                .overlay(surfaceDetails.mask(Circle()))

            if planet.id == "saturn" {
                // Front half of ring (in front of planet)
                ringShape
                    .mask(ringFrontMask)
            }
        }
    }

    private var shadedDisc: some View {
        let highlight = planet.color.mix(with: .white, by: 0.30)
        let mid = planet.color
        let shadow = planet.color.mix(with: .black, by: 0.75)

        return Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: highlight, location: 0.0),
                        .init(color: mid, location: 0.45),
                        .init(color: shadow, location: 1.0),
                    ]),
                    center: lightDirection,
                    startRadius: 0,
                    endRadius: diameter * 0.78
                )
            )
            .frame(width: diameter, height: diameter)
            .overlay(
                // Terminator shading: extra darkness opposite the light
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.45),
                            ]),
                            center: UnitPoint(
                                x: 1.0 - lightDirection.x,
                                y: 1.0 - lightDirection.y
                            ),
                            startRadius: diameter * 0.25,
                            endRadius: diameter * 0.75
                        )
                    )
                    .frame(width: diameter, height: diameter)
            )
            .overlay(
                // Soft rim light for definition against dark backgrounds
                Circle()
                    .strokeBorder(planet.color.opacity(0.35), lineWidth: max(diameter * 0.025, 0.5))
                    .frame(width: diameter, height: diameter)
            )
            .shadow(color: planet.color.opacity(0.25), radius: diameter * 0.18)
    }

    // MARK: - Per-planet flourishes

    @ViewBuilder
    private var surfaceDetails: some View {
        switch planet.id {
        case "jupiter": jupiterBands
        case "mars":    marsPatch
        case "moon":    moonMaria
        case "neptune": neptuneBand
        case "earth":   earthContinents
        default:        EmptyView()
        }
    }

    private var jupiterBands: some View {
        let dark = planet.color.mix(with: .black, by: 0.35)
        let light = planet.color.mix(with: .white, by: 0.15)
        return VStack(spacing: diameter * 0.04) {
            Capsule().fill(dark.opacity(0.55)).frame(height: diameter * 0.10)
            Capsule().fill(light.opacity(0.45)).frame(height: diameter * 0.08)
            Capsule().fill(dark.opacity(0.45)).frame(height: diameter * 0.09)
        }
        .frame(width: diameter, height: diameter)
    }

    private var marsPatch: some View {
        Ellipse()
            .fill(planet.color.mix(with: .black, by: 0.55).opacity(0.55))
            .frame(width: diameter * 0.42, height: diameter * 0.28)
            .rotationEffect(.degrees(-22))
            .offset(x: -diameter * 0.08, y: diameter * 0.06)
    }

    private var moonMaria: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.18))
                .frame(width: diameter * 0.28, height: diameter * 0.28)
                .offset(x: -diameter * 0.10, y: -diameter * 0.05)
            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: diameter * 0.20, height: diameter * 0.20)
                .offset(x: diameter * 0.12, y: diameter * 0.10)
            Circle()
                .fill(Color.black.opacity(0.12))
                .frame(width: diameter * 0.14, height: diameter * 0.14)
                .offset(x: -diameter * 0.02, y: diameter * 0.18)
        }
    }

    private var earthContinents: some View {
        let land = Color(red: 0.36, green: 0.66, blue: 0.32)
        let landDark = Color(red: 0.26, green: 0.50, blue: 0.22)
        return ZStack {
            Ellipse()
                .fill(land)
                .frame(width: diameter * 0.50, height: diameter * 0.36)
                .rotationEffect(.degrees(-18))
                .offset(x: -diameter * 0.14, y: -diameter * 0.10)
            Ellipse()
                .fill(landDark)
                .frame(width: diameter * 0.30, height: diameter * 0.42)
                .rotationEffect(.degrees(22))
                .offset(x: diameter * 0.16, y: diameter * 0.02)
            Ellipse()
                .fill(land)
                .frame(width: diameter * 0.22, height: diameter * 0.20)
                .offset(x: -diameter * 0.02, y: diameter * 0.22)
        }
    }

    private var neptuneBand: some View {
        Capsule()
            .fill(planet.color.mix(with: .black, by: 0.30).opacity(0.4))
            .frame(width: diameter, height: diameter * 0.10)
            .offset(y: -diameter * 0.05)
    }

    // MARK: - Saturn ring

    private var ringShape: some View {
        let ringColor = planet.color.mix(with: .white, by: 0.15)
        return Ellipse()
            .strokeBorder(
                ringColor.opacity(0.85),
                lineWidth: max(diameter * 0.05, 1.0)
            )
            .frame(width: diameter * 1.85, height: diameter * 0.42)
            .rotationEffect(.degrees(-18))
    }

    // Back half is the upper portion (drawn behind the sphere disc)
    private var ringBackMask: some View {
        Rectangle()
            .frame(width: diameter * 2.0, height: diameter * 0.7)
            .offset(y: -diameter * 0.35)
    }

    // Front half is the lower portion (drawn in front of the sphere disc)
    private var ringFrontMask: some View {
        Rectangle()
            .frame(width: diameter * 2.0, height: diameter * 0.7)
            .offset(y: diameter * 0.35)
    }
}

#Preview("Realistic Planets") {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ForEach(celestialBodies) { body in
                    PlanetSphereView(planet: body, diameter: 36)
                }
            }
            HStack(spacing: 12) {
                ForEach(celestialBodies) { body in
                    PlanetSphereView(planet: body, diameter: 18)
                }
            }
            PlanetSphereView(planet: celestialBodies.first(where: { $0.id == "saturn" })!, diameter: 88)
            PlanetSphereView(planet: celestialBodies.first(where: { $0.id == "jupiter" })!, diameter: 88)
        }
    }
}
