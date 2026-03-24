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
    let onDismiss: () -> Void

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
