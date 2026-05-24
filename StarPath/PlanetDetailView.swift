//
//  PlanetDetailView.swift
//  StarPath
//
//  Tappable planet info overlay.
//  Shows sign position, longitude, distance, daily motion, and retrograde status.
//

import SwiftUI

struct PlanetDetailView: View {
    let info: PlanetDetailInfo
    let aspectEvents: [SkyEvent]
    let realisticPlanets: Bool
    let onDismiss: () -> Void
    let onSelectAspect: ((SkyEvent) -> Void)?

    init(info: PlanetDetailInfo, aspectEvents: [SkyEvent] = [], realisticPlanets: Bool = false, onDismiss: @escaping () -> Void, onSelectAspect: ((SkyEvent) -> Void)? = nil) {
        self.info = info
        self.aspectEvents = aspectEvents
        self.realisticPlanets = realisticPlanets
        self.onDismiss = onDismiss
        self.onSelectAspect = onSelectAspect
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: large symbol + name
            headerSection

            Spacer().frame(height: 20)

            // Info rows in glass cards
            VStack(spacing: 2) {
                infoRow(label: "Position", value: info.formattedPosition, icon: "mappin.and.ellipse")
                infoRow(label: "Longitude", value: info.formattedLongitude, icon: "ruler")
                infoRow(label: "Distance", value: info.formattedDistance, icon: "arrow.left.and.right")
                infoRow(label: "Daily Motion", value: info.formattedSpeed, icon: info.isRetrograde ? "arrow.backward" : "arrow.forward")
                if info.id != "sun" {
                    infoRow(
                        label: "From Sun",
                        value: String(format: "%+.1f\u{00B0}", info.relativeDegrees),
                        icon: "sun.min"
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

            Spacer().frame(height: 24)

            // Status badges
            HStack(spacing: 10) {
                statusBadge(
                    text: "\(info.sign.glyph)\u{FE0E} \(info.sign.name)",
                    color: info.body.color
                )

                if info.isRetrograde {
                    statusBadge(text: "Retrograde", color: .red)
                } else if abs(info.dailyMotion) < 0.05 && info.id != "sun" {
                    statusBadge(text: "Stationary", color: .orange)
                }
            }

            // Aspects section
            if !aspectEvents.isEmpty {
                aspectsSection
            }

            Spacer()

            // Dismiss
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: .circle)
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            // Large planet symbol
            if info.body.isSun {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1, green: 0.973, blue: 0.851),
                                info.body.color,
                            ]),
                            center: .init(x: 0.36, y: 0.34),
                            startRadius: 0,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: info.body.color.opacity(0.6), radius: 24)
            } else if realisticPlanets {
                PlanetSphereView(planet: info.body, diameter: 76)
                    .frame(width: 88, height: 88)
            } else {
                ZStack {
                    Text("\(info.body.symbol)\u{FE0E}")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(info.body.color)
                        .shadow(color: info.body.color.opacity(0.5), radius: 12)
                }
                .frame(width: 88, height: 88)
                .background(info.body.color.opacity(0.15))
                .background(.ultraThinMaterial, in: .circle)
            }

            Text(info.body.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Info Row

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(info.body.color.opacity(0.8))
                .frame(width: 22)

            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Aspects Section

    private var aspectsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Aspects")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 4) {
                ForEach(aspectEvents.prefix(4)) { event in
                    aspectRow(event)
                }
            }
        }
        .padding(.top, 16)
    }

    private func aspectRow(_ event: SkyEvent) -> some View {
        let otherBodyId = (event.bodyA == info.id) ? event.bodyB : event.bodyA
        let otherBody = celestialBodies.first(where: { $0.id == otherBodyId })

        return HStack(spacing: 8) {
            // Aspect glyph
            Text(aspectGlyphFor(event.aspectAngle))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20)

            // Other planet symbol + name
            if let other = otherBody {
                Text("\(other.symbol)\u{FE0E}")
                    .font(.system(size: 15))
                    .foregroundStyle(other.color)
                Text(other.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Keywords
            if let bodyA = event.bodyA, let bodyB = event.bodyB, let angle = event.aspectAngle {
                Text(aspectKeywords(bodyA: bodyA, bodyB: bodyB, aspectAngle: angle))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 10))
                .foregroundStyle(event.tint.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectAspect?(event)
        }
    }

    private func aspectGlyphFor(_ angle: Double?) -> String {
        switch angle {
        case 0:   return "☌"
        case 180: return "☍"
        case 90:  return "□"
        case 120: return "△"
        case 60:  return "⚹"
        default:  return "●"
        }
    }

    // MARK: - Status Badge

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(color.opacity(0.3))
            .background(.ultraThinMaterial, in: .capsule)
    }
}
