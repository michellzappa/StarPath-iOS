//
//  ContentView.swift
//  StarPath
//
//  Main app view: starfield background, zodiac chart, drift overlay,
//  timestamp, settings gear, and time travel controls.
//  App is locked to portrait; labels/glyphs rotate to stay readable
//  when the device is physically tilted sideways.
//

import SwiftUI

struct ContentView: View {
    @State private var vm = StarPathViewModel()
    @State private var showSettings = false
    @State private var showDateInput = false
    @State private var selectedBodyId: String?

    // MARK: - Device orientation tracking (for text rotation only)
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

    /// Rotation angle to keep text readable when the device is tilted sideways.
    /// The app layout stays portrait; only labels/glyphs/timestamp rotate.
    private var textRotation: Angle {
        switch deviceOrientation {
        case .landscapeLeft:  return .degrees(90)
        case .landscapeRight: return .degrees(-90)
        default:              return .zero
        }
    }

    /// Whether the device is physically held in landscape
    private var isLandscape: Bool {
        deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight
    }

    // MARK: - Momentum scroll state
    @State private var dragAccumulator: CGFloat = 0
    @State private var lastDragTime: Date = .now
    @State private var lastDragDelta: CGFloat = 0
    @State private var momentumTimer: Timer?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Starfield
            if vm.options.showStars {
                StarfieldView(date: vm.viewDate)
                    .ignoresSafeArea()
            }

            // Main content
            ZStack {
                // Chart area
                ZStack {
                    // Drift/trend overlay
                    if vm.options.showDrift {
                        TrendOverlayView(
                            trendData: vm.trendData,
                            positionedBodies: vm.positionedBodies,
                            isVertical: true
                        )
                    }

                    // Zodiac chart with planets
                    ZodiacChartView(
                        positionedBodies: vm.positionedBodies,
                        currentState: vm.currentState,
                        options: vm.options,
                        isVertical: true,
                        textRotation: textRotation,
                        moonPhaseIcon: vm.moonPhaseIcon,
                        onTapBody: { bodyId in
                            withAnimation(.spring(duration: 0.35)) {
                                selectedBodyId = bodyId
                            }
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(timeTravelDrag)

                // Timestamp — tappable, positioned at visual "bottom center" of rotated view
                if vm.options.showTime {
                    GeometryReader { geo in
                        let timestampView = Button {
                            showDateInput = true
                        } label: {
                            Text(vm.formattedTimestamp)
                                .font(.system(size: 14, weight: .regular, design: .monospaced))
                                .tracking(0.6)
                                .foregroundColor(Color(red: 0.71, green: 0.737, blue: 0.804))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .rotationEffect(textRotation)

                        switch deviceOrientation {
                        case .landscapeLeft:
                            timestampView
                                .position(x: geo.size.width - 24, y: geo.size.height / 2)
                        case .landscapeRight:
                            timestampView
                                .position(x: 24, y: geo.size.height / 2)
                        default:
                            timestampView
                                .position(x: geo.size.width / 2, y: geo.size.height - 20)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            // Settings gear
            VStack {
                HStack {
                    settingsButton
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.leading, 12)

            // Planet detail overlay (allowsHitTesting only on the card itself)
            if let bodyId = selectedBodyId,
               let detail = vm.detailInfo(for: bodyId) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedBodyId = nil
                        }
                    }
                    .allowsHitTesting(true)
                    .gesture(timeTravelDrag)

                PlanetDetailView(info: detail) {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedBodyId = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .allowsHitTesting(true)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            // Only update for meaningful orientations (ignore faceUp/faceDown/unknown)
            if orientation.isPortrait || orientation.isLandscape {
                withAnimation(.easeInOut(duration: 0.25)) {
                    deviceOrientation = orientation
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(vm: vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDateInput) {
            DateInputSheet(vm: vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.76))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
    }

    // MARK: - Drag Gesture for Time Travel (with momentum)

    private let stepThreshold: CGFloat = 22

    private var timeTravelDrag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Kill any existing momentum
                momentumTimer?.invalidate()
                momentumTimer = nil

                // Always vertical: drag up = forward in time
                let raw = -value.translation.height
                let consumed = dragAccumulator
                let unconsumed = raw - consumed

                let steps = Int(unconsumed / stepThreshold)
                if steps != 0 {
                    let direction = steps > 0 ? 1 : -1
                    for _ in 0..<abs(steps) {
                        vm.shiftTime(amount: direction, unit: vm.selectedStep)
                    }
                    dragAccumulator += CGFloat(steps) * stepThreshold
                }

                // Track velocity
                let now = Date()
                let dt = now.timeIntervalSince(lastDragTime)
                if dt > 0 {
                    lastDragDelta = unconsumed
                    lastDragTime = now
                }
            }
            .onEnded { value in
                dragAccumulator = 0

                // Compute velocity in points/sec
                let velocity = -value.predictedEndTranslation.height + value.translation.height
                let velocitySign: Int = velocity > 0 ? 1 : -1

                // Only momentum if swipe was fast enough
                guard abs(velocity) > 60 else { return }

                var currentVelocity = abs(velocity)
                let friction: Double = 0.92 // deceleration per tick

                momentumTimer?.invalidate()
                momentumTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
                    currentVelocity *= friction

                    if currentVelocity < 8 {
                        timer.invalidate()
                        momentumTimer = nil
                        return
                    }

                    // Steps proportional to current speed
                    let stepsPerTick = max(1, Int(currentVelocity / 80))
                    for _ in 0..<stepsPerTick {
                        vm.shiftTime(amount: velocitySign, unit: vm.selectedStep)
                    }
                }
            }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @Bindable var vm: StarPathViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    Toggle("Stars", isOn: $vm.options.showStars)
                    Toggle("Planet Labels", isOn: $vm.options.showLabels)
                    Toggle("Drift Curves", isOn: $vm.options.showDrift)
                    Toggle("Timestamp", isOn: $vm.options.showTime)
                    Toggle("Moon", isOn: $vm.options.showMoon)
                }

                Section("Zodiac") {
                    Toggle("Lock Zodiac", isOn: $vm.options.lockZodiac)
                    if vm.options.lockZodiac {
                        Picker("Center Sign", selection: $vm.options.centerSignIndex) {
                            ForEach(zodiacSigns) { sign in
                                Text("\(sign.glyph) \(sign.name)").tag(sign.id)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        if let url = URL(string: "https://www.aesthetichermetics.com") {
                            openURL(url)
                        }
                    } label: {
                        Text("Created by Aesthetic Hermetics")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let url = URL(string: "https://stjarnhimlen.se/comp/ppcomp.html") {
                            openURL(url)
                        }
                    } label: {
                        Text("Astronomy Data")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Starpath")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: vm.options.showStars) { _, _ in vm.saveSettings() }
        .onChange(of: vm.options.showLabels) { _, _ in vm.saveSettings() }
        .onChange(of: vm.options.showDrift) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.showTime) { _, _ in vm.saveSettings() }
        .onChange(of: vm.options.showMoon) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.lockZodiac) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.centerSignIndex) { _, _ in vm.update(); vm.saveSettings() }
    }
}

// MARK: - Date Input Sheet

struct DateInputSheet: View {
    @Bindable var vm: StarPathViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputDate: Date = Date()
    @State private var year: Int = Calendar.current.component(.year, from: Date())

    private var displayYear: Int {
        Calendar.current.component(.year, from: inputDate)
    }

    /// Rebuild inputDate with a new year, keeping month/day/time
    private func setYear(_ newYear: Int) {
        var cal = Calendar.current
        cal.timeZone = .current
        var comps = cal.dateComponents([.month, .day, .hour, .minute, .second], from: inputDate)
        comps.year = newYear
        if let d = cal.date(from: comps) {
            inputDate = d
            year = newYear
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Year selector
                HStack(spacing: 20) {
                    Button {
                        setYear(year - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(String(year))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(minWidth: 80)

                    Button {
                        setYear(year + 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.top, 8)

                // Month, day, time
                DatePicker(
                    "Date & Time",
                    selection: $inputDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: inputDate) { _, newVal in
                    // Keep year stepper in sync if wheel changes date
                    let newYear = Calendar.current.component(.year, from: newVal)
                    if newYear != year { year = newYear }
                }

                // "Now" reset button
                Button {
                    inputDate = Date()
                    year = Calendar.current.component(.year, from: Date())
                } label: {
                    Label("Reset to Now", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                }

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Set Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        vm.viewDate = inputDate
                        vm.update()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            inputDate = vm.viewDate
            year = Calendar.current.component(.year, from: vm.viewDate)
        }
    }
}

#Preview {
    ContentView()
}
