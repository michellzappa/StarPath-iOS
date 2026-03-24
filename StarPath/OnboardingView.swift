//
//  OnboardingView.swift
//  StarPath
//
//  First-run onboarding with three quick interaction steps.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var selectedIndex = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Scroll Through Time",
            description: "Swipe up or down on the chart to move forward and backward. Haptics mark key transitions."
        ),
        OnboardingStep(
            title: "Tap Planets for Details",
            description: "Tap any body to see sign position, longitude, distance, and retrograde motion."
        ),
        OnboardingStep(
            title: "Passive Widgets",
            description: "Add Home and Lock Screen widgets for live sky data without opening the app."
        ),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.07, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Welcome to Starpath")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 24)

                TabView(selection: $selectedIndex) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        VStack(spacing: 18) {
                            OnboardingGraphicView(stepIndex: index)
                                .frame(height: 190)
                                .padding(.horizontal, 20)

                            Text(step.title)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(step.description)
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(selectedIndex == steps.count - 1 ? "Start" : "Next") {
                    if selectedIndex < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedIndex += 1
                        }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct OnboardingStep {
    let title: String
    let description: String
}

private struct OnboardingGraphicView: View {
    let stepIndex: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.09), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            switch stepIndex {
            case 0:
                timeTravelGraphic
            case 1:
                detailTapGraphic
            default:
                widgetGraphic
            }
        }
    }

    private var timeTravelGraphic: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.2))
                .frame(width: 2, height: 130)

            VStack(spacing: 16) {
                Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.55)).frame(width: 22, height: 22)
                Circle().fill(Color(red: 0.78, green: 0.96, blue: 1.0)).frame(width: 14, height: 14)
                Circle().fill(Color(red: 1.0, green: 0.71, blue: 0.63)).frame(width: 16, height: 16)
                Circle().fill(Color(red: 0.72, green: 0.72, blue: 1.0)).frame(width: 12, height: 12)
            }
            .offset(x: -28)

            VStack(spacing: 20) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "hand.draw")
                    .font(.system(size: 26, weight: .medium))
                Image(systemName: "arrow.down")
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.8))
            .offset(x: 36)
        }
    }

    private var detailTapGraphic: some View {
        HStack(spacing: 16) {
            VStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.78, green: 0.96, blue: 1.0))
                    .frame(width: 34, height: 34)
                Image(systemName: "hand.tap")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Position", systemImage: "mappin.and.ellipse")
                Label("Distance", systemImage: "arrow.left.and.right")
                Label("Daily Motion", systemImage: "arrow.forward")
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var widgetGraphic: some View {
        HStack(spacing: 10) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 92, height: 64)
                    .overlay(
                        HStack(spacing: 6) {
                            Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.55)).frame(width: 12, height: 12)
                            Circle().fill(Color(red: 0.78, green: 0.96, blue: 1.0)).frame(width: 10, height: 10)
                            Circle().fill(Color(red: 1.0, green: 0.71, blue: 0.63)).frame(width: 10, height: 10)
                        }
                    )
                Text("Home")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text("♓\u{FE0E}")
                            .font(.system(size: 18))
                            .foregroundStyle(.white.opacity(0.9))
                    )
                Text("Lock")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 76, height: 36)
                    .overlay(
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                            Text("Pisces")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    )
                Text("Inline")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
