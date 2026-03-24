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

        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Text(event.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
            vm.jump(to: event.date)
            dismiss()
        }
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
                                width: 126,
                                content: AnyView(homePreview)
                            )
                            widgetPreviewCard(
                                title: "Lock (Circular)",
                                width: 102,
                                content: AnyView(lockCircularPreview)
                            )
                            widgetPreviewCard(
                                title: "Lock (Rectangular)",
                                width: 172,
                                content: AnyView(lockRectPreview)
                            )
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

    private func widgetPreviewCard(title: String, width: CGFloat, content: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content
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
                Circle().fill(Color(red: 1, green: 0.85, blue: 0.55)).frame(width: 16, height: 16)
                Circle().fill(Color(red: 0.84, green: 0.87, blue: 1.0)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.78, green: 0.96, blue: 1.0)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 1.0, green: 0.71, blue: 0.63)).frame(width: 12, height: 12)
                Circle().fill(Color(red: 0.72, green: 0.72, blue: 1.0)).frame(width: 12, height: 12)
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
