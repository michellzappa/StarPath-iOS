//
//  EventsSheet.swift
//  StarPath
//
//  Event timeline and widget guidance sheets.
//

import SwiftUI

struct EventsSheet: View {
    @Bindable var vm: StarPathViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAspectEvent: SkyEvent?

    var body: some View {
        NavigationStack {
            Group {
                if groupedEvents.isEmpty {
                    ContentUnavailableView(
                        "No Upcoming Events",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Pull to refresh or adjust the viewed date.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(groupedEvents.indices, id: \.self) { index in
                                let group = groupedEvents[index]
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(dayTitle(group.day))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    VStack(spacing: 8) {
                                        ForEach(group.events) { event in
                                            eventRow(event)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Sky Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vm.refreshEvents(force: true)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(item: $selectedAspectEvent) { event in
                AspectOrbSheet(vm: vm, event: event) {
                    selectedAspectEvent = nil
                    vm.jump(to: event.date)
                    dismiss()
                }
            }
        }
        .onAppear {
            vm.refreshEvents()
        }
    }

    private var groupedEvents: [(day: Date, events: [SkyEvent])] {
        let groups = Dictionary(grouping: vm.upcomingEvents) { event in
            Calendar.current.startOfDay(for: event.date)
        }
        return groups.keys.sorted().map { key in
            (day: key, events: groups[key]!.sorted { $0.date < $1.date })
        }
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow" }
        return StarPathDateFormats.eventDay.string(from: day)
    }

    private func timeLabel(_ date: Date) -> String {
        StarPathDateFormats.eventTime.string(from: date)
    }

    @ViewBuilder
    private func eventRow(_ event: SkyEvent) -> some View {
        HStack(spacing: 12) {
            Image(systemName: event.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(event.tint)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    if let bodyA = event.bodyA, let bodyB = event.bodyB {
                        if let label = significanceLabel(aspectSignificance(bodyA: bodyA, bodyB: bodyB)) {
                            Text(label)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(event.tint.opacity(0.5))
                                .clipShape(Capsule())
                        }
                    }
                }
                Text(event.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if event.hasAspectData {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 12))
                    .foregroundStyle(event.tint.opacity(0.6))
            }

            Text(timeLabel(event.date))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if event.hasAspectData {
                selectedAspectEvent = event
            } else {
                vm.jump(to: event.date)
                dismiss()
            }
        }
    }
}

// MARK: - Aspect Orb Sheet Wrapper

struct AspectOrbSheet: View {
    let vm: StarPathViewModel
    let event: SkyEvent
    let onJump: () -> Void

    var body: some View {
        let samples = vm.orbCurveSamples(
            bodyA: event.bodyA ?? "",
            bodyB: event.bodyB ?? "",
            aspectAngle: event.aspectAngle ?? 0,
            centerDate: event.date
        )
        AspectOrbView(samples: samples, event: event, realisticPlanets: vm.options.realisticPlanets, onJump: onJump)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}

struct WidgetGuideSheet: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Widget Previews") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            widgetPreviewCard(
                                title: "Home (Small)",
                                width: 126
                            ) {
                                homePreview
                            }
                            widgetPreviewCard(
                                title: "Lock (Circular)",
                                width: 102
                            ) {
                                lockCircularPreview
                            }
                            widgetPreviewCard(
                                title: "Lock (Rectangular)",
                                width: 172
                            ) {
                                lockRectPreview
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("What You Get") {
                    Label("Home Screen strip widget", systemImage: "rectangle.grid.1x2")
                    Label("Lock Screen compact widgets", systemImage: "lock.rectangle")
                    Label("Control Center quick Sun sign", systemImage: "switch.2")
                }

                Section("How to Add") {
                    Text("1. Press and hold the Home or Lock Screen.")
                    Text("2. Tap Edit or Customize.")
                    Text("3. Select Starpath widgets and place them.")
                }

                Section("Tip") {
                    Text("Use the app for deep exploration, and keep widgets for passive real-time sky context.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func widgetPreviewCard<Content: View>(
        title: String,
        width: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
                .frame(width: width, height: 76)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var homePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.black)
            HStack(spacing: 8) {
                PlanetSphereView(planet: celestialBodies.first { $0.id == "sun" }!, diameter: 16)
                PlanetSphereView(planet: celestialBodies.first { $0.id == "moon" }!, diameter: 12)
                PlanetSphereView(planet: celestialBodies.first { $0.id == "mercury" }!, diameter: 12)
                PlanetSphereView(planet: celestialBodies.first { $0.id == "mars" }!, diameter: 12)
                PlanetSphereView(planet: celestialBodies.first { $0.id == "neptune" }!, diameter: 12)
            }
        }
    }

    private var lockCircularPreview: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 50, height: 50)
            Text("♓\u{FE0E}")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lockRectPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 1) {
                Text("Sun in Pisces")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text("♓ 29°")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
