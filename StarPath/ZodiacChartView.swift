//
//  ZodiacChartView.swift
//  StarPath
//
//  The main chart view: a vertical axis with zodiac sign boundaries,
//  sign glyphs, and positioned planet nodes.
//  The Sun is a glowing golden circle at center; planets are smaller
//  circles with Unicode glyphs. Labels use collision avoidance.
//

import SwiftUI

struct ZodiacChartView: View {
    let positionedBodies: [PositionedBody]
    let currentState: GeocentricState?
    let options: ViewOptions
    let isVertical: Bool
    var textRotation: Angle = .zero
    var moonPhaseIcon: String = "moonphase.full.moon"
    var onTapBody: ((String) -> Void)?

    /// Angular threshold (degrees) within which we check for Sun overlap
    private let overlapThresholdDeg: Double = 7

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let sortedBodies = depthSortedBodies
            let labelOffsets = options.showLabels ? computeLabelOffsets(size: size) : [:]

            ZStack {
                // Axis line
                axisLine(size: size)

                // Zodiac sign boundaries and glyphs
                zodiacLayer(size: size)

                // Planet nodes, rendered back-to-front by z-order
                ForEach(sortedBodies, id: \.id) { pb in
                    planetNode(pb: pb, size: size, labelYOffset: labelOffsets[pb.id] ?? 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Label Collision Avoidance

    /// Estimated label height along the axis.
    /// When rotated 90°, the label's width (~55pt for "MERCURY") becomes
    /// its vertical extent; unrotated it's ~16pt tall.
    private var labelAxisHeight: CGFloat {
        let isRotated = abs(textRotation.degrees) > 45
        return isRotated ? 52 : 18
    }

    /// Minimum gap between label centers along the Y axis
    private var labelMinSpacing: CGFloat {
        labelAxisHeight + 4
    }

    /// Compute per-body Y offsets for labels to avoid overlap.
    /// Returns [bodyId: additionalYOffset].
    private func computeLabelOffsets(size: CGSize) -> [String: CGFloat] {
        // Only non-Sun bodies get labels
        let labelBodies = positionedBodies.filter { !$0.body.isSun }
        guard !labelBodies.isEmpty else { return [:] }

        // Sort by Y position (axisFraction * height)
        let sorted = labelBodies.sorted {
            $0.axisFraction(inverted: options.invertZodiacOrder) < $1.axisFraction(inverted: options.invertZodiacOrder)
        }

        // Initial label Y = planet Y (center of label)
        var labelYs: [(id: String, y: CGFloat)] = sorted.map { pb in
            (pb.id, CGFloat(pb.axisFraction(inverted: options.invertZodiacOrder)) * size.height)
        }

        // Push overlapping labels apart (iterative relaxation)
        let minSpacing = labelMinSpacing
        for _ in 0..<8 {
            var moved = false
            for i in 1..<labelYs.count {
                let gap = labelYs[i].y - labelYs[i - 1].y
                if gap < minSpacing {
                    let push = (minSpacing - gap) / 2 + 0.5
                    labelYs[i - 1].y -= push
                    labelYs[i].y += push
                    moved = true
                }
            }
            if !moved { break }
        }

        // Compute offsets (delta from original position)
        var offsets: [String: CGFloat] = [:]
        for (idx, pb) in sorted.enumerated() {
            let originalY = CGFloat(pb.axisFraction(inverted: options.invertZodiacOrder)) * size.height
            let resolvedY = labelYs[idx].y
            let delta = resolvedY - originalY
            if abs(delta) > 0.5 {
                offsets[pb.id] = delta
            }
        }
        return offsets
    }

    // MARK: - Depth Sorting

    /// Determines render order: Sun at z=12 by default.
    /// Mercury/Venus/Moon go to z=14 (in front) when they are both
    /// near the Sun in longitude AND closer to Earth than the Sun.
    /// All other planets always render behind the Sun (z=9).
    private var depthSortedBodies: [PositionedBody] {
        guard let state = currentState else { return positionedBodies }

        let sunDist = positionedBodies.first { $0.id == "sun" }?.geocentricDistance ?? 1

        return positionedBodies
            .map { pb -> (body: PositionedBody, zOrder: Int) in
                if pb.body.isSun {
                    return (pb, 12)
                }

                let nearSun = abs(signedDelta(pb.longitude, state.sun)) <= overlapThresholdDeg

                if nearSun && pb.canTransitSun && pb.geocentricDistance < sunDist {
                    // Interior body transiting in front of Sun
                    return (pb, 14)
                }

                return (pb, 9)
            }
            .sorted { $0.zOrder < $1.zOrder }
            .map(\.body)
    }

    // MARK: - Axis Line

    @ViewBuilder
    private func axisLine(size: CGSize) -> some View {
        if isVertical {
            // Vertical center line
            let midX = size.width / 2
            Canvas { context, size in
                let path = Path { p in
                    p.move(to: CGPoint(x: midX, y: 0))
                    p.addLine(to: CGPoint(x: midX, y: size.height))
                }
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.clear, Color.white.opacity(0.64), .clear]),
                        startPoint: CGPoint(x: midX, y: 0),
                        endPoint: CGPoint(x: midX, y: size.height)
                    ),
                    lineWidth: 2
                )
            }
        } else {
            // Horizontal center line
            let midY = size.height / 2
            Canvas { context, size in
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: midY))
                    p.addLine(to: CGPoint(x: size.width, y: midY))
                }
                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [.clear, Color.white.opacity(0.64), .clear]),
                        startPoint: CGPoint(x: 0, y: midY),
                        endPoint: CGPoint(x: size.width, y: midY)
                    ),
                    lineWidth: 2
                )
            }
        }
    }

    // MARK: - Zodiac Layer

    @ViewBuilder
    private func zodiacLayer(size: CGSize) -> some View {
        let ref = referenceLon
        ForEach(0..<12, id: \.self) { k in
            let boundaryLon = Double(k) * 30
            let relBoundary = signedDelta(boundaryLon, ref)
            let frac = zodiacAxisFraction(relativeDegrees: relBoundary, inverted: options.invertZodiacOrder)

            let signCenterLon = boundaryLon + 15
            let relCenter = signedDelta(signCenterLon, ref)
            let fracCenter = zodiacAxisFraction(relativeDegrees: relCenter, inverted: options.invertZodiacOrder)

            // Tick mark
            zodiacTick(frac: frac, size: size)

            // Sign glyph
            zodiacGlyph(sign: zodiacSigns[k], frac: fracCenter, size: size)
        }
    }

    @ViewBuilder
    private func zodiacTick(frac: Double, size: CGSize) -> some View {
        if isVertical {
            let y = frac * size.height
            Rectangle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 28, height: 1)
                .position(x: size.width / 2, y: y)
        } else {
            let x = frac * size.width
            Rectangle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 1, height: 28)
                .position(x: x, y: size.height / 2)
        }
    }

    @ViewBuilder
    private func zodiacGlyph(sign: ZodiacSign, frac: Double, size: CGSize) -> some View {
        if isVertical {
            let y = frac * size.height
            Text("\(sign.glyph)\u{FE0E}")
                .font(.system(size: 22))
                .foregroundColor(Color.white.opacity(0.9))
                .rotationEffect(textRotation)
                .position(x: size.width / 2 - 42, y: y)
        } else {
            let x = frac * size.width
            Text("\(sign.glyph)\u{FE0E}")
                .font(.system(size: 22))
                .foregroundColor(Color.white.opacity(0.9))
                .rotationEffect(textRotation)
                .position(x: x, y: size.height / 2 - 44)
        }
    }

    // MARK: - Planet Nodes

    @ViewBuilder
    private func planetNode(pb: PositionedBody, size: CGSize, labelYOffset: CGFloat) -> some View {
        let frac = pb.axisFraction(inverted: options.invertZodiacOrder)

        if isVertical {
            let y = frac * size.height
            let x = size.width / 2
            planetCircle(pb: pb, labelYOffset: labelYOffset)
                .position(x: x, y: y)
        } else {
            let x = frac * size.width
            let y = size.height / 2
            planetCircle(pb: pb, labelYOffset: labelYOffset)
                .position(x: x, y: y)
        }
    }

    @ViewBuilder
    private func planetCircle(pb: PositionedBody, labelYOffset: CGFloat) -> some View {
        if pb.body.isSun {
            // Sun: golden radial gradient — tappable
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1, green: 0.973, blue: 0.851),
                            Color(red: 1, green: 0.851, blue: 0.553),
                        ]),
                        center: .init(x: 0.36, y: 0.34),
                        startRadius: 0,
                        endRadius: 20
                    )
                )
                .frame(width: 38, height: 38)
                .shadow(color: Color(red: 1, green: 0.808, blue: 0.459).opacity(0.75), radius: 12)
                .overlay(
                    Circle()
                        .stroke(Color(red: 1, green: 0.851, blue: 0.553).opacity(0.3), lineWidth: 2)
                )
                .onTapGesture { onTapBody?(pb.id) }
        } else {
            // Planet: opaque circle with darkened planet color background and glyph
            let planetColor = pb.body.color
            let fillColor = planetColor.mix(with: .black, by: 0.55)
            let isMoon = pb.id == "moon"
            ZStack {
                // Planet body — tappable
                Group {
                    if options.realisticPlanets {
                        PlanetSphereView(planet: pb.body, diameter: 26)
                            .rotationEffect(textRotation)
                    } else {
                        ZStack {
                            Circle()
                                .fill(fillColor)
                                .frame(width: 31, height: 31)
                                .overlay(
                                    Circle()
                                        .stroke(planetColor.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: planetColor.opacity(0.35), radius: 9)

                            if isMoon {
                                Image(systemName: moonPhaseIcon)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundColor(planetColor)
                                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                                    .rotationEffect(textRotation)
                                    .allowsHitTesting(false)
                            } else {
                                Text("\(pb.body.symbol)\u{FE0E}")
                                    .font(.system(size: symbolSize(for: pb.body.symbol), weight: .bold))
                                    .foregroundColor(planetColor)
                                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                                    .rotationEffect(textRotation)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
                .contentShape(Circle())
                .onTapGesture { onTapBody?(pb.id) }

                // Label — independently tappable
                if options.showLabels {
                    Text(pb.body.name)
                        .font(.system(size: 10, weight: .regular))
                        .tracking(0.3)
                        .textCase(.uppercase)
                        .foregroundColor(Color(red: 0.71, green: 0.737, blue: 0.804))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.72))
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture { onTapBody?(pb.id) }
                        .rotationEffect(textRotation)
                        .offset(
                            x: isVertical ? 46 : 0,
                            y: isVertical ? labelYOffset : 36
                        )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Normalize symbol sizes so all planet glyphs appear visually equal
    private func symbolSize(for symbol: String) -> CGFloat {
        switch symbol {
        case "☽": return 21    // Moon renders small
        case "☿": return 20    // Mercury renders small
        case "♀": return 19    // Venus
        case "♂": return 19    // Mars
        case "♃": return 19    // Jupiter
        case "♄": return 20    // Saturn renders slightly small
        case "♅": return 19    // Uranus
        case "♆": return 19    // Neptune
        default:  return 19
        }
    }

    private var referenceLon: Double {
        guard let state = currentState else { return 0 }
        return options.referenceLongitude(sunLon: state.sun)
    }
}
