//
//  TrendOverlayView.swift
//  StarPath
//
//  Canvas-based 30-day drift curves overlay.
//  Each planet gets a sinusoidal-wave path showing its motion trend,
//  with a dot at its current position.
//

import SwiftUI

struct TrendOverlayView: View {
    let trendData: TrendData?
    let positionedBodies: [PositionedBody]
    let isVertical: Bool
    let invertZodiacOrder: Bool

    private let waveSpanPx: Double = 132

    var body: some View {
        Canvas { context, size in
            guard let trend = trendData else { return }

            let sampleCount = trend.sampleCount
            let centerIndex = trend.centerIndex

            if isVertical {
                drawVerticalTrend(context: context, size: size, trend: trend,
                                  sampleCount: sampleCount, centerIndex: centerIndex)
            } else {
                drawHorizontalTrend(context: context, size: size, trend: trend,
                                    sampleCount: sampleCount, centerIndex: centerIndex)
            }
        }
        // Fade edges
        .mask(
            isVertical
                ? AnyView(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85), .black.opacity(0.85), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                : AnyView(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.85), .black.opacity(0.85), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .opacity(0.86)
        .allowsHitTesting(false)
    }

    // MARK: - Vertical Trend (for vertical/portrait mode)

    private func drawVerticalTrend(context: GraphicsContext, size: CGSize, trend: TrendData,
                                   sampleCount: Int, centerIndex: Int)
    {
        let w = size.width
        let h = size.height
        let padX: Double = 16

        func xAt(_ i: Int) -> Double {
            padX + (Double(i) / Double(sampleCount - 1)) * (w - padX * 2)
        }

        func yAtRel(_ rel: Double) -> Double {
            zodiacAxisFraction(relativeDegrees: rel, inverted: invertZodiacOrder) * h
        }

        let centerX = xAt(centerIndex)
        let waveDirection = invertZodiacOrder ? 1.0 : -1.0

        // Vertical time axis
        drawLine(context: context,
                 from: CGPoint(x: centerX, y: 0),
                 to: CGPoint(x: centerX, y: h),
                 color: Color.white.opacity(0.22), width: 1)

        // Horizontal center line
        drawLine(context: context,
                 from: CGPoint(x: padX, y: h / 2),
                 to: CGPoint(x: w - padX, y: h / 2),
                 color: Color.white.opacity(0.1), width: 1)

        // Body paths — only draw for bodies present in positionedBodies
        let visibleIds = Set(positionedBodies.map(\.id))
        for body in celestialBodies {
            guard visibleIds.contains(body.id) else { continue }
            guard let values = trend.series[body.id] else { continue }
            let pb = positionedBodies.first { $0.id == body.id }
            let relNow = pb?.relativeDegrees ?? 0
            let anchorY = yAtRel(relNow)
            let anchorWave = waveFromRel(relNow)

            let color = body.color
            let lineOpacity: Double = body.isSun ? 0.42 : 0.3
            let lineWidth: Double = body.isSun ? 2.2 : (body.id == "moon" ? 2.0 : 1.6)

            var path = Path()
            for (i, rel) in values.enumerated() {
                let waveY = anchorY + waveDirection * ((waveFromRel(rel) - anchorWave) / 100) * waveSpanPx
                let point = CGPoint(x: xAt(i), y: waveY)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(color.opacity(lineOpacity)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Current position dot
            let dotRadius: Double = body.isSun ? 3.8 : 2.8
            let dotRect = CGRect(
                x: centerX - dotRadius,
                y: yAtRel(relNow) - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.75)))
        }
    }

    // MARK: - Horizontal Trend (for horizontal/landscape mode)

    private func drawHorizontalTrend(context: GraphicsContext, size: CGSize, trend: TrendData,
                                     sampleCount: Int, centerIndex: Int)
    {
        let w = size.width
        let h = size.height
        let padY: Double = 16

        func yAt(_ i: Int) -> Double {
            padY + (Double(i) / Double(sampleCount - 1)) * (h - padY * 2)
        }

        func xAtRel(_ rel: Double) -> Double {
            zodiacAxisFraction(relativeDegrees: rel, inverted: invertZodiacOrder) * w
        }

        let centerY = yAt(centerIndex)
        let waveDirection = invertZodiacOrder ? -1.0 : 1.0

        // Horizontal time axis
        drawLine(context: context,
                 from: CGPoint(x: 0, y: centerY),
                 to: CGPoint(x: w, y: centerY),
                 color: Color.white.opacity(0.22), width: 1)

        // Vertical center line
        drawLine(context: context,
                 from: CGPoint(x: w / 2, y: padY),
                 to: CGPoint(x: w / 2, y: h - padY),
                 color: Color.white.opacity(0.1), width: 1)

        let visibleIds = Set(positionedBodies.map(\.id))
        for body in celestialBodies {
            guard visibleIds.contains(body.id) else { continue }
            guard let values = trend.series[body.id] else { continue }
            let pb = positionedBodies.first { $0.id == body.id }
            let relNow = pb?.relativeDegrees ?? 0
            let anchorX = xAtRel(relNow)
            let anchorWave = waveFromRel(relNow)

            let color = body.color
            let lineOpacity: Double = body.isSun ? 0.42 : 0.3
            let lineWidth: Double = body.isSun ? 2.2 : (body.id == "moon" ? 2.0 : 1.6)

            var path = Path()
            for (i, rel) in values.enumerated() {
                let waveX = anchorX + waveDirection * ((waveFromRel(rel) - anchorWave) / 100) * waveSpanPx
                let point = CGPoint(x: waveX, y: yAt(i))
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            context.stroke(path, with: .color(color.opacity(lineOpacity)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            let dotRadius: Double = body.isSun ? 3.8 : 2.8
            let dotRect = CGRect(
                x: xAtRel(relNow) - dotRadius,
                y: centerY - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.75)))
        }
    }

    // MARK: - Helpers

    private func waveFromRel(_ rel: Double) -> Double {
        sin(toRad(rel)) * 100
    }

    private func drawLine(context: GraphicsContext, from: CGPoint, to: CGPoint,
                           color: Color, width: Double)
    {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: width)
    }
}
