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
    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = StarPathViewModel()
    @State private var activeSheet: ActiveSheet?
    @State private var showOnboarding = false
    @State private var selectedBodyId: String?
    @State private var selectedAspectFromDetail: SkyEvent?

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

    // MARK: - Momentum scroll state
    @State private var dragAccumulator: CGFloat = 0
    @State private var momentumTimer: Timer?

    private enum ActiveSheet: String, Identifiable {
        case settings
        case events
        case dateInput

        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Starfield
            if vm.options.showStars {
                StarfieldView(date: vm.viewDate, topDown: vm.options.showWheel)
                    .ignoresSafeArea()
            }

            // Main content
            ZStack {
                // Chart area
                ZStack {
                    if vm.options.showWheel {
                        // Heliocentric wheel view
                        GeocentricWheelView(
                            positionedBodies: vm.positionedBodies,
                            currentState: vm.currentState,
                            helioState: vm.helioState,
                            options: vm.options,
                            moonPhaseIcon: vm.moonPhaseIcon,
                            onTapBody: { bodyId in
                                showBodyDetail(bodyId)
                            }
                        )
                    } else {
                        // Drift/trend overlay
                        if vm.options.showDrift {
                            TrendOverlayView(
                                trendData: vm.trendData,
                                positionedBodies: vm.positionedBodies,
                                isVertical: true,
                                invertZodiacOrder: vm.options.invertZodiacOrder
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
                                showBodyDetail(bodyId)
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(timeTravelDrag)

                // Timestamp — tappable, positioned at visual "bottom center" of rotated view
                if vm.options.showTime {
                    GeometryReader { geo in
                        let timestampView = Button {
                            activeSheet = .dateInput
                        } label: {
                            Text(vm.formattedTimestamp)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 34)
                                .background(controlBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(controlStroke)
                        }
                        .buttonStyle(.plain)
                        .rotationEffect(textRotation)

                        switch deviceOrientation {
                        case .landscapeLeft:
                            timestampView
                                .position(x: geo.size.width - 27, y: geo.size.height / 2)
                        case .landscapeRight:
                            timestampView
                                .position(x: 27, y: geo.size.height / 2)
                        default:
                            timestampView
                                .position(x: geo.size.width / 2, y: geo.size.height - 27)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)

            // Corner controls
            VStack {
                HStack {
                    settingsButton
                    Spacer()
                    wheelToggleButton
                    eventsButton
                }
                Spacer()
                HStack(alignment: .bottom) {
                    stepButton
                    Spacer()
                    nowButton
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Planet detail overlay (allowsHitTesting only on the card itself)
            if let bodyId = selectedBodyId,
               let detail = vm.detailInfo(for: bodyId) {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissBodyDetail()
                    }
                    .allowsHitTesting(true)
                    .gesture(timeTravelDrag)

                PlanetDetailView(
                    info: detail,
                    aspectEvents: aspectEvents(for: bodyId),
                    realisticPlanets: vm.options.realisticPlanets,
                    onDismiss: {
                        dismissBodyDetail()
                    },
                    onSelectAspect: { event in
                        selectedAspectFromDetail = event
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                .allowsHitTesting(true)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                showOnboarding = true
            }
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
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
        .onChange(of: scenePhase, initial: true) { _, phase in
            vm.handleScenePhase(phase)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsSheet(vm: vm)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            case .events:
                EventsSheet(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .dateInput:
                DateInputSheet(vm: vm)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $selectedAspectFromDetail) { event in
            AspectOrbSheet(vm: vm, event: event) {
                selectedAspectFromDetail = nil
                vm.jump(to: event.date)
                dismissBodyDetail()
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                showOnboarding = false
            }
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Button {
            activeSheet = .settings
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(controlStroke)
        .contentShape(.interaction, Rectangle().inset(by: -8))
    }

    /// Cycles: linear → geocentric wheel → heliocentric wheel → linear
    private var wheelToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                if !vm.options.showWheel {
                    // linear → geocentric
                    vm.options.showWheel = true
                    vm.options.heliocentricWheel = false
                } else if !vm.options.heliocentricWheel {
                    // geocentric → heliocentric
                    vm.options.heliocentricWheel = true
                } else {
                    // heliocentric → linear
                    vm.options.showWheel = false
                    vm.options.heliocentricWheel = false
                }
                vm.update()
                vm.saveSettings()
            }
        } label: {
            Image(systemName: wheelIcon)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(controlStroke)
        .contentShape(.interaction, Rectangle().inset(by: -8))
    }

    private var eventsButton: some View {
        Button {
            vm.refreshEvents()
            activeSheet = .events
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(controlStroke)
        .contentShape(.interaction, Rectangle().inset(by: -8))
    }

    private var stepButton: some View {
        Button {
            vm.cycleSelectedStep()
        } label: {
            Text(vm.selectedStep.shortLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(minWidth: 46, minHeight: 34)
                .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(controlStroke)
        .contentShape(.interaction, Rectangle().inset(by: -8))
    }

    private var nowButton: some View {
        Button {
            vm.resetToNow()
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(controlBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(controlStroke)
        .contentShape(.interaction, Rectangle().inset(by: -8))
    }

    private var wheelIcon: String {
        if !vm.options.showWheel {
            return "circle.circle"           // linear → tap to go geocentric
        } else if !vm.options.heliocentricWheel {
            return "sun.max"                 // geocentric → tap to go heliocentric
        } else {
            return "line.horizontal.3"       // heliocentric → tap to go linear
        }
    }

    private func showBodyDetail(_ bodyId: String) {
        withAnimation(.spring(duration: 0.35)) {
            selectedBodyId = bodyId
        }
    }

    private func dismissBodyDetail() {
        withAnimation(.spring(duration: 0.3)) {
            selectedBodyId = nil
        }
    }

    private func aspectEvents(for bodyId: String) -> [SkyEvent] {
        vm.upcomingEvents.filter { event in
            event.hasAspectData && (event.bodyA == bodyId || event.bodyB == bodyId)
        }
    }

    private var controlBackground: some View {
        Color.black.opacity(0.76)
    }

    private var controlStroke: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(0.28), lineWidth: 1)
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
    @State private var showWidgetGuide = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Display") {
                    Toggle("Stars", isOn: $vm.options.showStars)
                    Toggle("Planet Labels", isOn: $vm.options.showLabels)
                    Toggle("Drift Curves", isOn: $vm.options.showDrift)
                    Toggle("Timestamp", isOn: $vm.options.showTime)
                    Toggle("Moon", isOn: $vm.options.showMoon)
                    Toggle("Realistic Planets", isOn: $vm.options.realisticPlanets)
                    Toggle("Wheel View", isOn: $vm.options.showWheel)
                }

                Section("Zodiac") {
                    Toggle("Lock Zodiac", isOn: $vm.options.lockZodiac)
                    Toggle("Invert Zodiac Order", isOn: $vm.options.invertZodiacOrder)
                    if vm.options.lockZodiac {
                        Picker("Center Sign", selection: $vm.options.centerSignIndex) {
                            ForEach(zodiacSigns) { sign in
                                Text("\(sign.glyph) \(sign.name)").tag(sign.id)
                            }
                        }
                    }
                    Text("Flips the strip perspective so the left/right zodiac order matches the iOS Dynamic wallpaper view.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Widgets") {
                    Button("Widget Guide") {
                        showWidgetGuide = true
                    }
                    Text("Add Starpath widgets for passive home and lock screen updates.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Welcome Guide", systemImage: "sparkles")
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
        .onChange(of: vm.options.showWheel) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.heliocentricWheel) { _, _ in vm.saveSettings() }
        .onChange(of: vm.options.realisticPlanets) { _, _ in vm.saveSettings() }
        .onChange(of: vm.options.lockZodiac) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.centerSignIndex) { _, _ in vm.update(); vm.saveSettings() }
        .onChange(of: vm.options.invertZodiacOrder) { _, _ in vm.update(); vm.saveSettings() }
        .sheet(isPresented: $showWidgetGuide) {
            WidgetGuideSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
    }
}

// MARK: - Date Input Sheet

struct DateInputSheet: View {
    @Bindable var vm: StarPathViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inputDate: Date = Date()
    @State private var year: Int = Calendar.current.component(.year, from: Date())

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
            ScrollView {
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

                Button {
                    vm.addBookmark(date: inputDate)
                } label: {
                    Label("Save This Date", systemImage: "bookmark")
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

                if !vm.savedDates.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Saved Dates")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))

                        LazyVStack(spacing: 8) {
                            ForEach(vm.savedDates) { bookmark in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(savedDateLabel(bookmark.date))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                        Text(savedTimeLabel(bookmark.date))
                                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    Spacer()
                                    Button {
                                        vm.removeBookmark(bookmark)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    inputDate = bookmark.date
                                    year = Calendar.current.component(.year, from: bookmark.date)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Set Date & Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        vm.jump(to: inputDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            }
        }
        .onAppear {
            inputDate = vm.viewDate
            year = Calendar.current.component(.year, from: vm.viewDate)
        }
    }

    private func savedDateLabel(_ date: Date) -> String {
        StarPathDateFormats.savedDate.string(from: date)
    }

    private func savedTimeLabel(_ date: Date) -> String {
        StarPathDateFormats.savedTime.string(from: date)
    }
}

#Preview {
    ContentView()
}
