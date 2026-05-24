//
//  StarPathWidget.swift
//  StarPathWidget
//
//  Home screen widget showing a horizontal zodiac strip with planet positions.
//  Supports systemSmall, systemMedium, and systemLarge families.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct StarPathProvider: TimelineProvider {
    func placeholder(in context: Context) -> StarPathEntry {
        StarPathEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (StarPathEntry) -> Void) {
        completion(StarPathEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StarPathEntry>) -> Void) {
        var entries: [StarPathEntry] = []

        // Update every 15 minutes for 2 hours
        let currentDate = Date()
        for minuteOffset in stride(from: 0, to: 120, by: 15) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            entries.append(StarPathEntry(date: entryDate))
        }

        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct StarPathEntry: TimelineEntry {
    let date: Date
    let invertZodiacOrder = widgetInvertZodiacOrder()

    var positionedBodies: [WidgetPositionedBody] {
        widgetPositionedBodies(for: date)
    }

    var depthSortedBodies: [WidgetPositionedBody] {
        let bodies = positionedBodies
        let sunLon = bodies.first { $0.id == "sun" }?.longitude ?? 0
        return widgetDepthSortedBodies(bodies, sunLongitude: sunLon)
    }

    var sunSign: ZodiacSign {
        let state = geocentricLongitudes(for: date)
        return zodiacSign(fromLongitude: state.sun)
    }

    var moonPhaseIcon: String {
        moonPhaseSymbol(for: date)
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "UTC " + formatter.string(from: date)
    }
}

// MARK: - Widget View

struct StarPathWidgetEntryView: View {
    var entry: StarPathEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryInline:
            accessoryInlineWidget
        case .accessoryCircular:
            accessoryCircularWidget
        case .accessoryRectangular:
            accessoryRectangularWidget
        default:
            mediumWidget
        }
    }

    // MARK: - Small Widget (Sun sign focus)

    private var smallWidget: some View {
        let sunBody = entry.positionedBodies.first { $0.id == "sun" }
        let sign = entry.sunSign

        return VStack(spacing: 6) {
            // Sun glyph
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1, green: 0.973, blue: 0.851),
                                Color(red: 1, green: 0.851, blue: 0.553),
                            ]),
                            center: .init(x: 0.36, y: 0.34),
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(red: 1, green: 0.808, blue: 0.459).opacity(0.5), radius: 10)
            }

            // Sign info
            Text("\(sign.glyph)\u{FE0E}")
                .font(.system(size: 24))
                .foregroundStyle(.white)

            Text(sign.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            if let sun = sunBody {
                let degInSign = normalizeAngle(sun.longitude).truncatingRemainder(dividingBy: 30)
                Text(String(format: "%.0f°", degInSign))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Medium Widget (horizontal strip)

    private var mediumWidget: some View {
        VStack(spacing: 0) {
            // Zodiac strip
            GeometryReader { geo in
                let size = geo.size

                ZStack {
                    // Axis line
                    let midY = size.height / 2
                    Canvas { context, canvasSize in
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: midY))
                            p.addLine(to: CGPoint(x: canvasSize.width, y: midY))
                        }
                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [.clear, Color.white.opacity(0.5), .clear]),
                                startPoint: CGPoint(x: 0, y: midY),
                                endPoint: CGPoint(x: canvasSize.width, y: midY)
                            ),
                            lineWidth: 1.5
                        )
                    }

                    // Zodiac ticks and glyphs
                    let sunLon = entry.positionedBodies.first { $0.id == "sun" }?.longitude ?? 0
                    ForEach(0..<12, id: \.self) { k in
                        let boundaryLon = Double(k) * 30
                        let relBoundary = signedDelta(boundaryLon, sunLon)
                        let frac = zodiacAxisFraction(relativeDegrees: relBoundary, inverted: entry.invertZodiacOrder)
                        let x = frac * size.width

                        // Tick
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 18)
                            .position(x: x, y: size.height / 2)

                        // Sign glyph
                        let signCenterLon = boundaryLon + 15
                        let relCenter = signedDelta(signCenterLon, sunLon)
                        let fracCenter = zodiacAxisFraction(relativeDegrees: relCenter, inverted: entry.invertZodiacOrder)
                        let xCenter = fracCenter * size.width

                        Text("\(zodiacSigns[k].glyph)\u{FE0E}")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.6))
                            .position(x: xCenter, y: size.height / 2 - 22)
                    }

                    // Planet nodes (depth-sorted: back-to-front)
                    ForEach(entry.depthSortedBodies) { pb in
                        let x = pb.axisFraction(inverted: entry.invertZodiacOrder) * size.width
                        let y = size.height / 2

                        widgetPlanetNode(pb: pb)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

        }
    }

    // MARK: - Large Widget (strip + planet list)

    private var largeWidget: some View {
        VStack(spacing: 8) {
            // Title
            HStack {
                Text("Starpath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 4)

            // Zodiac strip (same as medium)
            GeometryReader { geo in
                let size = geo.size

                ZStack {
                    let midY = size.height / 2
                    Canvas { context, canvasSize in
                        let path = Path { p in
                            p.move(to: CGPoint(x: 0, y: midY))
                            p.addLine(to: CGPoint(x: canvasSize.width, y: midY))
                        }
                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [.clear, Color.white.opacity(0.5), .clear]),
                                startPoint: CGPoint(x: 0, y: midY),
                                endPoint: CGPoint(x: canvasSize.width, y: midY)
                            ),
                            lineWidth: 1.5
                        )
                    }

                    let sunLon = entry.positionedBodies.first { $0.id == "sun" }?.longitude ?? 0
                    ForEach(0..<12, id: \.self) { k in
                        let boundaryLon = Double(k) * 30
                        let relBoundary = signedDelta(boundaryLon, sunLon)
                        let frac = zodiacAxisFraction(relativeDegrees: relBoundary, inverted: entry.invertZodiacOrder)
                        let x = frac * size.width

                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 18)
                            .position(x: x, y: size.height / 2)

                        let signCenterLon = boundaryLon + 15
                        let relCenter = signedDelta(signCenterLon, sunLon)
                        let fracCenter = zodiacAxisFraction(relativeDegrees: relCenter, inverted: entry.invertZodiacOrder)
                        let xCenter = fracCenter * size.width

                        Text("\(zodiacSigns[k].glyph)\u{FE0E}")
                            .font(.system(size: 16))
                            .foregroundColor(Color.white.opacity(0.6))
                            .position(x: xCenter, y: size.height / 2 - 26)
                    }

                    ForEach(entry.depthSortedBodies) { pb in
                        let x = pb.axisFraction(inverted: entry.invertZodiacOrder) * size.width
                        let y = size.height / 2

                        widgetPlanetNode(pb: pb)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 80)

            // Planet list
            VStack(spacing: 3) {
                ForEach(entry.positionedBodies) { pb in
                    let sign = zodiacSign(fromLongitude: pb.longitude)
                    let degInSign = normalizeAngle(pb.longitude).truncatingRemainder(dividingBy: 30)

                    HStack(spacing: 8) {
                        WidgetPlanetSphereView(planet: pb.body, diameter: 14)
                            .frame(width: 20)

                        Text(pb.body.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 60, alignment: .leading)

                        Text("\(sign.glyph)\u{FE0E}")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))

                        Text(sign.name)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))

                        Spacer()

                        Text(String(format: "%.0f°", degInSign))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 4)
                }
            }

            Spacer()
        }
    }

    // MARK: - Lock Screen Widgets

    private var accessoryInlineWidget: some View {
        let sign = entry.sunSign
        let sunLon = entry.positionedBodies.first { $0.id == "sun" }?.longitude ?? 0
        let degInSign = normalizeAngle(sunLon).truncatingRemainder(dividingBy: 30)
        return Text("☉ \(sign.glyph)\u{FE0E} \(Int(degInSign.rounded()))°")
    }

    private var accessoryCircularWidget: some View {
        let sign = entry.sunSign
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
            Text("\(sign.glyph)\u{FE0E}")
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
    }

    private var accessoryRectangularWidget: some View {
        let sign = entry.sunSign
        let sunLon = entry.positionedBodies.first { $0.id == "sun" }?.longitude ?? 0
        let degInSign = normalizeAngle(sunLon).truncatingRemainder(dividingBy: 30)

        return VStack(alignment: .leading, spacing: 2) {
            Text("Starpath")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                Text("\(sign.glyph)\u{FE0E} \(sign.name)")
                Spacer()
                Text("\(Int(degInSign.rounded()))°")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .font(.system(size: 13, weight: .medium))
        }
    }

    // MARK: - Widget Planet Node

    @ViewBuilder
    private func widgetPlanetNode(pb: WidgetPositionedBody) -> some View {
        if pb.body.isSun {
            WidgetPlanetSphereView(planet: pb.body, diameter: 22)
        } else {
            WidgetPlanetSphereView(planet: pb.body, diameter: 14)
        }
    }

}

// MARK: - Widget Configuration

struct StarPathWidget: Widget {
    let kind: String = "StarPathWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StarPathProvider()) { entry in
            StarPathWidgetEntryView(entry: entry)
                .containerBackground(Color.black, for: .widget)
        }
        .configurationDisplayName("Starpath")
        .description("Live zodiac chart showing planetary positions.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Previews

#if DEBUG
struct StarPathWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StarPathWidgetEntryView(entry: .init(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            StarPathWidgetEntryView(entry: .init(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemMedium))

            StarPathWidgetEntryView(entry: .init(date: .now))
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
#endif
