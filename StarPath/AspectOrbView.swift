//
//  AspectOrbView.swift
//  StarPath
//
//  Renders aspect orb curves — mountain shapes showing how planetary
//  aspects build and decay over time. Peaks at exact aspect.
//

import SwiftUI

struct AspectOrbView: View {
    let samples: [OrbSample]
    let event: SkyEvent
    let maxOrb: Double = 15
    var realisticPlanets: Bool = false
    let onJump: () -> Void

    private let zodiacColors: [Color] = [
        Color(red: 1.0, green: 0.45, blue: 0.42),  // Aries — red/fire
        Color(red: 0.55, green: 0.82, blue: 0.55),  // Taurus — green/earth
        Color(red: 1.0, green: 0.88, blue: 0.42),   // Gemini — yellow/air
        Color(red: 0.55, green: 0.72, blue: 1.0),   // Cancer — blue/water
        Color(red: 1.0, green: 0.55, blue: 0.42),   // Leo — orange/fire
        Color(red: 0.65, green: 0.85, blue: 0.55),  // Virgo — sage/earth
        Color(red: 1.0, green: 0.82, blue: 0.55),   // Libra — peach/air
        Color(red: 0.55, green: 0.62, blue: 1.0),   // Scorpio — indigo/water
        Color(red: 1.0, green: 0.62, blue: 0.45),   // Sagittarius — coral/fire
        Color(red: 0.62, green: 0.78, blue: 0.62),  // Capricorn — muted green/earth
        Color(red: 0.88, green: 0.82, blue: 0.55),  // Aquarius — gold/air
        Color(red: 0.62, green: 0.68, blue: 1.0),   // Pisces — periwinkle/water
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            curveCanvas
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .padding(.horizontal, 16)
            legend
            jumpButton
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if let a = celestialBodies.first(where: { $0.id == event.bodyA }),
                   let b = celestialBodies.first(where: { $0.id == event.bodyB }) {
                    if realisticPlanets {
                        PlanetSphereView(planet: a, diameter: 28)
                    } else {
                        Text(a.symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(a.color)
                    }
                    Text(aspectGlyph)
                        .font(.system(size: 22))
                        .foregroundStyle(.white.opacity(0.7))
                    if realisticPlanets {
                        PlanetSphereView(planet: b, diameter: 28)
                    } else {
                        Text(b.symbol)
                            .font(.system(size: 28))
                            .foregroundStyle(b.color)
                    }
                }
            }
            .padding(.top, 20)

            Text(event.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            if let bodyA = event.bodyA, let bodyB = event.bodyB, let angle = event.aspectAngle {
                Text(aspectKeywords(bodyA: bodyA, bodyB: bodyB, aspectAngle: angle))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(event.tint.opacity(0.8))

                HStack(spacing: 8) {
                    Text(exactDateLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)

                    Text(aspectPhase(bodyA: bodyA, bodyB: bodyB, aspectAngle: angle, at: Date()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(phaseColor)
                }
            } else {
                Text(exactDateLabel)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 16)
    }

    private var phaseColor: Color {
        guard let bodyA = event.bodyA, let bodyB = event.bodyB, let angle = event.aspectAngle else {
            return .secondary
        }
        let phase = aspectPhase(bodyA: bodyA, bodyB: bodyB, aspectAngle: angle, at: Date())
        switch phase {
        case "Applying":   return .orange
        case "Exact":      return .white
        case "Separating": return Color(red: 0.6, green: 0.8, blue: 1.0)
        default:           return .secondary
        }
    }

    private var aspectGlyph: String {
        switch event.aspectAngle {
        case 0: return "☌"
        case 180: return "☍"
        case 90: return "□"
        case 120: return "△"
        case 60: return "⚹"
        default: return "●"
        }
    }

    private var exactDateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f.string(from: event.date)
    }

    // MARK: - Canvas

    private var curveCanvas: some View {
        GeometryReader { geometry in
            if let layout = chartLayout(for: geometry.size) {
                ZStack {
                    mountainFill(layout: layout)

                    Canvas { context, _ in
                        drawChartChrome(context: context, layout: layout)
                    }
                }
                .compositingGroup()
            } else {
                emptyState
            }
        }
    }

    private struct ChartLayout {
        let size: CGSize
        let padX: Double
        let padTop: Double
        let padBottom: Double
        let chartWidth: Double
        let chartHeight: Double
        let baseY: Double
        let firstDate: Date
        let lastDate: Date
        let totalSeconds: Double

        func xAt(_ date: Date) -> Double {
            padX + (date.timeIntervalSince(firstDate) / totalSeconds) * chartWidth
        }

        func yAt(_ orb: Double, maxOrb: Double) -> Double {
            padTop + (orb / maxOrb) * chartHeight
        }
    }

    private func chartLayout(for size: CGSize) -> ChartLayout? {
        guard let firstDate = samples.first?.date,
              let lastDate = samples.last?.date else { return nil }

        let totalSeconds = lastDate.timeIntervalSince(firstDate)
        guard totalSeconds > 0 else { return nil }

        let padX: Double = 40
        let padBottom: Double = 28
        let padTop: Double = 12
        let chartWidth = size.width - padX * 2
        let chartHeight = size.height - padTop - padBottom

        return ChartLayout(
            size: size,
            padX: padX,
            padTop: padTop,
            padBottom: padBottom,
            chartWidth: chartWidth,
            chartHeight: chartHeight,
            baseY: padTop + chartHeight,
            firstDate: firstDate,
            lastDate: lastDate,
            totalSeconds: totalSeconds
        )
    }

    @ViewBuilder
    private func mountainFill(layout: ChartLayout) -> some View {
        let areaPath = mountainPath(layout: layout)

        ZStack {
            areaPath.fill(
                LinearGradient(
                    colors: [
                        event.tint.opacity(0.55),
                        event.tint.opacity(0.18),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            signBandOverlay(layout: layout)
                .mask(
                    areaPath.fill(.white)
                )
        }
    }

    @ViewBuilder
    private func signBandOverlay(layout: ChartLayout) -> some View {
        let segments = signSegments(layout: layout)

        ZStack(alignment: .topLeading) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Rectangle()
                    .fill(zodiacColors[segment.signIndex].opacity(0.42))
                    .frame(width: segment.width, height: layout.chartHeight)
                    .offset(x: segment.startX, y: layout.padTop)
            }
        }
    }

    private func signSegments(layout: ChartLayout) -> [(startX: CGFloat, width: CGFloat, signIndex: Int)] {
        var segments: [(startX: CGFloat, width: CGFloat, signIndex: Int)] = []
        var segStart = 0

        for si in 1...samples.count {
            let newSign = (si == samples.count) || (samples[si].signIndex != samples[segStart].signIndex)
            if newSign {
                let startX = layout.xAt(samples[segStart].date)
                let endX = layout.xAt(samples[si - 1].date)
                segments.append((
                    startX: startX,
                    width: max(endX - startX, 1),
                    signIndex: samples[segStart].signIndex
                ))

                if si < samples.count {
                    segStart = si
                }
            }
        }

        return segments
    }

    private func drawChartChrome(context: GraphicsContext, layout: ChartLayout) {
        // Orb guide lines
        for orbLine in [1.0, 5.0, 10.0] {
            if orbLine < maxOrb {
                let y = layout.yAt(orbLine, maxOrb: maxOrb)
                var path = Path()
                path.move(to: CGPoint(x: layout.padX, y: y))
                path.addLine(to: CGPoint(x: layout.padX + layout.chartWidth, y: y))
                context.stroke(path, with: .color(.white.opacity(0.12)),
                               style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

                let label = "\(Int(orbLine))°"
                context.draw(Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35)),
                    at: CGPoint(x: layout.padX - 14, y: y))
            }
        }

        // Exact line (0° orb)
        let exactY = layout.yAt(0, maxOrb: maxOrb)
        var exactPath = Path()
        exactPath.move(to: CGPoint(x: layout.padX, y: exactY))
        exactPath.addLine(to: CGPoint(x: layout.padX + layout.chartWidth, y: exactY))
        context.stroke(exactPath, with: .color(.white.opacity(0.2)), lineWidth: 0.5)

        // Baseline
        var basePath = Path()
        basePath.move(to: CGPoint(x: layout.padX, y: layout.baseY))
        basePath.addLine(to: CGPoint(x: layout.padX + layout.chartWidth, y: layout.baseY))
        context.stroke(basePath, with: .color(.white.opacity(0.15)), lineWidth: 0.5)

        // Stroke the curve outline
        var strokePath = Path()
        for (index, sample) in samples.enumerated() {
            let point = CGPoint(x: layout.xAt(sample.date), y: layout.yAt(sample.orb, maxOrb: maxOrb))
            if index == 0 {
                strokePath.move(to: point)
            } else {
                strokePath.addLine(to: point)
            }
        }
        context.stroke(strokePath, with: .color(.white.opacity(0.82)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

        // Peak marker (exact date)
        let exactX = layout.xAt(event.date)
        var peakLine = Path()
        peakLine.move(to: CGPoint(x: exactX, y: exactY))
        peakLine.addLine(to: CGPoint(x: exactX, y: layout.baseY))
        context.stroke(peakLine, with: .color(.white.opacity(0.25)),
                       style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))

        let dotRadius: Double = 4
        let dotRect = CGRect(
            x: exactX - dotRadius,
            y: exactY - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
        context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.9)))

        drawMonthTicks(
            context: context,
            firstDate: layout.firstDate,
            lastDate: layout.lastDate,
            xAt: layout.xAt,
            baseY: layout.baseY
        )
    }


    private func drawMonthTicks(context: GraphicsContext,
                                 firstDate: Date, lastDate: Date,
                                 xAt: (Date) -> Double, baseY: Double) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: firstDate)
        components.day = 1
        components.hour = 0

        // Move to next month
        if let d = calendar.date(from: components) {
            if d <= firstDate {
                components.month! += 1
            }
        }

        while let tickDate = calendar.date(from: components), tickDate <= lastDate {
            let x = xAt(tickDate)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: tickDate)

            // Tick line
            var tick = Path()
            tick.move(to: CGPoint(x: x, y: baseY))
            tick.addLine(to: CGPoint(x: x, y: baseY + 4))
            context.stroke(tick, with: .color(.white.opacity(0.3)), lineWidth: 0.5)

            // Month label
            context.draw(Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5)),
                at: CGPoint(x: x, y: baseY + 14))

            components.month! += 1
        }
    }

    private func mountainPath(layout: ChartLayout) -> Path {
        var path = Path()
        guard let firstSample = samples.first, let lastSample = samples.last else {
            return path
        }

        path.move(to: CGPoint(x: layout.xAt(firstSample.date), y: layout.baseY))
        for sample in samples {
            path.addLine(to: CGPoint(
                x: layout.xAt(sample.date),
                y: layout.yAt(sample.orb, maxOrb: maxOrb)
            ))
        }
        path.addLine(to: CGPoint(x: layout.xAt(lastSample.date), y: layout.baseY))
        path.closeSubpath()
        return path
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 12) {
            if let signIndices = uniqueSignIndices {
                ForEach(signIndices, id: \.self) { idx in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(zodiacColors[idx].opacity(0.7))
                            .frame(width: 8, height: 8)
                        Text("\(zodiacSigns[idx].glyph)\u{FE0E}")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(zodiacSigns[idx].name)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private var uniqueSignIndices: [Int]? {
        let indices = Set(samples.filter { $0.orb < maxOrb }.map(\.signIndex)).sorted()
        return indices.isEmpty ? nil : indices
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No orb data available")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
    }

    // MARK: - Jump button

    private var jumpButton: some View {
        Button {
            onJump()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                Text("Jump to date")
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.6))
        }
        .padding(.top, 16)
    }
}
