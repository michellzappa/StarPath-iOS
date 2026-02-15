//
//  StarPathViewModel.swift
//  StarPath
//
//  Observable view model that drives the chart. Computes geocentric
//  longitudes, positioned bodies, trend data, and manages time travel.
//

import SwiftUI
import Observation

@Observable
final class StarPathViewModel {
    // MARK: - Published State

    var viewDate: Date = Date()
    var options: ViewOptions = ViewOptions()
    var positionedBodies: [PositionedBody] = []
    var currentState: GeocentricState?
    var depthContext: DepthContext?
    var trendData: TrendData?
    var selectedStep: TimeStep = .day
    var moonPhaseIcon: String = "moonphase.full.moon"

    // MARK: - Timer

    private var timer: Timer?

    // MARK: - Constants

    private let trendWindowDays: Int = 30
    private let trendStepHours: Int = 12

    // MARK: - Settings Persistence Keys

    private enum SettingsKey {
        static let showStars = "sp_showStars"
        static let showLabels = "sp_showLabels"
        static let showDrift = "sp_showDrift"
        static let showTime = "sp_showTime"
        static let showMoon = "sp_showMoon"
        static let lockZodiac = "sp_lockZodiac"
        static let centerSignIndex = "sp_centerSignIndex"
        static let selectedStep = "sp_selectedStep"
    }

    // MARK: - Init

    init() {
        loadSettings()
        update()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Timer

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.viewDate = Date(timeInterval: 1, since: self.viewDate)
            self.update()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Update

    func update() {
        let state = geocentricLongitudes(for: viewDate)
        currentState = state
        let depth = geocentricDepthContext(for: viewDate)
        depthContext = depth
        let ref = options.referenceLongitude(sunLon: state.sun)

        let bodiesToShow = options.showMoon ? celestialBodies : celestialBodies.filter { $0.id != "moon" }

        positionedBodies = bodiesToShow.map { body in
            let lon = state.longitude(for: body.id)
            let rel = signedDelta(lon, ref)
            let dist = depth.distance(for: body.id)
            return PositionedBody(id: body.id, body: body, longitude: lon, relativeDegrees: rel, geocentricDistance: dist)
        }

        // Update moon phase icon
        moonPhaseIcon = moonPhaseSymbol(for: viewDate)

        if options.showDrift {
            trendData = buildTrendData(baseDate: viewDate)
        } else {
            trendData = nil
        }
    }

    // MARK: - Time Travel

    func shiftTime(amount: Int, unit: TimeStep) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let component: Calendar.Component
        let value: Int

        switch unit {
        case .minute:
            component = .minute
            value = amount
        case .hour:
            component = .hour
            value = amount
        case .day:
            component = .day
            value = amount
        case .week:
            component = .day
            value = amount * 7
        case .month:
            component = .month
            value = amount
        case .year:
            component = .year
            value = amount
        }

        if let newDate = calendar.date(byAdding: component, value: value, to: viewDate) {
            viewDate = newDate
            update()
        }
    }

    func resetToNow() {
        viewDate = Date()
        update()
    }

    // MARK: - Trend Data

    private func buildTrendData(baseDate: Date) -> TrendData {
        let stepMs = Double(trendStepHours) * 3600
        let halfWindowMs = Double(trendWindowDays) * 86400
        let sampleCount = Int((halfWindowMs * 2) / stepMs) + 1
        let centerIndex = sampleCount / 2

        var series: [String: [Double]] = [:]
        for body in celestialBodies {
            series[body.id] = []
        }

        let locked = options.lockZodiac
        let lockedRef = normalizeAngle(Double(options.centerSignIndex) * 30 + 15)

        for i in 0..<sampleCount {
            let dt = baseDate.addingTimeInterval(Double(i - centerIndex) * stepMs)
            let state = geocentricLongitudes(for: dt)
            let ref = locked ? lockedRef : state.sun

            for body in celestialBodies {
                let lon = state.longitude(for: body.id)
                let rel = signedDelta(lon, ref)
                series[body.id]?.append(rel)
            }
        }

        return TrendData(series: series, sampleCount: sampleCount, centerIndex: centerIndex)
    }

    // MARK: - Planet Detail

    func detailInfo(for bodyId: String) -> PlanetDetailInfo? {
        guard let pb = positionedBodies.first(where: { $0.id == bodyId }),
              let state = currentState,
              let depth = depthContext else { return nil }

        let lon = pb.longitude
        let sign = zodiacSign(fromLongitude: lon)
        let degInSign = normalizeAngle(lon).truncatingRemainder(dividingBy: 30)
        let dist = depth.distance(for: bodyId)

        // Compute daily motion: compare longitude 6 hours ahead
        let deltaHours: Double = 6
        let futureDate = viewDate.addingTimeInterval(deltaHours * 3600)
        let futureState = geocentricLongitudes(for: futureDate)
        let futureLon = futureState.longitude(for: bodyId)
        let deltaLon = signedDelta(futureLon, lon)
        let dailyMotion = deltaLon / (deltaHours / 24)
        let isRetrograde = dailyMotion < -0.005

        let ref = options.referenceLongitude(sunLon: state.sun)
        let rel = signedDelta(lon, ref)

        return PlanetDetailInfo(
            id: bodyId,
            body: pb.body,
            longitude: lon,
            sign: sign,
            degreeInSign: degInSign,
            geocentricDistanceAU: dist,
            dailyMotion: dailyMotion,
            isRetrograde: isRetrograde,
            relativeDegrees: rel
        )
    }

    // MARK: - Formatted Timestamp

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: viewDate)
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        let ud = UserDefaults.standard
        ud.set(options.showStars, forKey: SettingsKey.showStars)
        ud.set(options.showLabels, forKey: SettingsKey.showLabels)
        ud.set(options.showDrift, forKey: SettingsKey.showDrift)
        ud.set(options.showTime, forKey: SettingsKey.showTime)
        ud.set(options.showMoon, forKey: SettingsKey.showMoon)
        ud.set(options.lockZodiac, forKey: SettingsKey.lockZodiac)
        ud.set(options.centerSignIndex, forKey: SettingsKey.centerSignIndex)
        ud.set(selectedStep.rawValue, forKey: SettingsKey.selectedStep)
    }

    private func loadSettings() {
        let ud = UserDefaults.standard
        // Only load if keys exist (first launch uses defaults)
        if ud.object(forKey: SettingsKey.showStars) != nil {
            options.showStars = ud.bool(forKey: SettingsKey.showStars)
        }
        if ud.object(forKey: SettingsKey.showLabels) != nil {
            options.showLabels = ud.bool(forKey: SettingsKey.showLabels)
        }
        if ud.object(forKey: SettingsKey.showDrift) != nil {
            options.showDrift = ud.bool(forKey: SettingsKey.showDrift)
        }
        if ud.object(forKey: SettingsKey.showTime) != nil {
            options.showTime = ud.bool(forKey: SettingsKey.showTime)
        }
        if ud.object(forKey: SettingsKey.showMoon) != nil {
            options.showMoon = ud.bool(forKey: SettingsKey.showMoon)
        }
        if ud.object(forKey: SettingsKey.lockZodiac) != nil {
            options.lockZodiac = ud.bool(forKey: SettingsKey.lockZodiac)
        }
        if ud.object(forKey: SettingsKey.centerSignIndex) != nil {
            options.centerSignIndex = ud.integer(forKey: SettingsKey.centerSignIndex)
        }
        if let stepRaw = ud.string(forKey: SettingsKey.selectedStep),
           let step = TimeStep(rawValue: stepRaw) {
            selectedStep = step
        }
    }
}
