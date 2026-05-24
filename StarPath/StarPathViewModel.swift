//
//  StarPathViewModel.swift
//  StarPath
//
//  Observable view model that drives the chart. Computes geocentric
//  longitudes, positioned bodies, trend data, and manages time travel.
//

import SwiftUI
import UIKit
import Observation
import WidgetKit

@Observable
final class StarPathViewModel {
    // MARK: - Published State

    var viewDate: Date = Date()
    var options: ViewOptions = ViewOptions()
    var positionedBodies: [PositionedBody] = []
    var currentState: GeocentricState?
    var helioState: HeliocentricState?
    var depthContext: DepthContext?
    var trendData: TrendData?
    var helioTrendData: HelioTrendData?
    var selectedStep: TimeStep = .day
    var moonPhaseIcon: String = "moonphase.full.moon"
    var upcomingEvents: [SkyEvent] = []
    var savedDates: [DateBookmark] = []
    private(set) var isLiveMode: Bool = true

    // MARK: - Timer

    private var timer: Timer?
    private let userDefaults: UserDefaults

    // MARK: - Haptic: zodiac boundary crossing

    private var lastSunSignIndex: Int?
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Constants

    private let trendWindowDays: Int = 30
    private let trendStepHours: Int = 12
    private let eventWindowDays: Int = 365
    private let bookmarkLimit: Int = 10
    private let stationEpsilon: Double = 0.0002
    private let trendRefreshInterval: TimeInterval = 60

    private var eventsAnchorDay: Int?
    private var trendCacheKey: TrendCacheKey?

    // MARK: - Settings Persistence Keys

    private enum SettingsKey {
        static let showStars = "sp_showStars"
        static let showLabels = "sp_showLabels"
        static let showDrift = "sp_showDrift"
        static let showTime = "sp_showTime"
        static let showMoon = "sp_showMoon"
        static let showWheel = "sp_showWheel"
        static let heliocentricWheel = "sp_heliocentricWheel"
        static let realisticPlanets = "sp_realisticPlanets"
        static let lockZodiac = "sp_lockZodiac"
        static let centerSignIndex = "sp_centerSignIndex"
        static let invertZodiacOrder = StarPathSharedDefaults.invertZodiacOrderKey
        static let selectedStep = "sp_selectedStep"
        static let savedDates = "sp_savedDates"
    }

    private struct TrendCacheKey: Equatable {
        let minuteBucket: Int
        let lockZodiac: Bool
        let centerSignIndex: Int
        let showWheel: Bool
    }

    // MARK: - Init

    init(
        initialDate: Date = Date(),
        userDefaults: UserDefaults = StarPathSharedDefaults.appDefaults,
        startsLiveUpdates: Bool = true
    ) {
        self.viewDate = initialDate
        self.userDefaults = userDefaults
        loadSettings()
        update()
        if startsLiveUpdates {
            resumeLiveUpdates(syncImmediately: true)
        } else {
            isLiveMode = false
        }
    }

    deinit {
        invalidateTimer()
    }

    // MARK: - Timer

    func resumeLiveUpdates(syncImmediately: Bool = true) {
        isLiveMode = true
        if syncImmediately {
            viewDate = Date()
            update()
        }
        startTimer()
    }

    func pauseLiveUpdates() {
        isLiveMode = false
        invalidateTimer()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard isLiveMode else { return }
            if timer == nil {
                startTimer()
            }
            viewDate = Date()
            update()
        case .inactive, .background:
            invalidateTimer()
        @unknown default:
            invalidateTimer()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.viewDate = Date()
            self.update()
        }
    }

    func stopTimer() {
        pauseLiveUpdates()
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Update

    func update() {
        let state = geocentricLongitudes(for: viewDate)
        currentState = state
        helioState = heliocentricLongitudes(for: viewDate)
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

        // Haptic blip when Sun crosses a zodiac boundary
        let sunSignIndex = Int(normalizeAngle(state.sun) / 30) % 12
        if let prev = lastSunSignIndex, prev != sunSignIndex {
            haptic.impactOccurred()
        }
        lastSunSignIndex = sunSignIndex

        // Update moon phase icon
        moonPhaseIcon = moonPhaseSymbol(for: viewDate)

        updateTrendDataIfNeeded()
    }

    // MARK: - Time Travel

    func shiftTime(amount: Int, unit: TimeStep) {
        pauseLiveUpdates()

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
        resumeLiveUpdates()
    }

    func jump(to date: Date) {
        pauseLiveUpdates()
        viewDate = date
        update()
    }

    func cycleSelectedStep() {
        let allSteps = TimeStep.allCases
        guard let index = allSteps.firstIndex(of: selectedStep) else { return }
        let nextIndex = (index + 1) % allSteps.count
        selectedStep = allSteps[nextIndex]
        saveSettings()
    }

    // MARK: - Trend Data

    private func updateTrendDataIfNeeded() {
        guard options.showDrift else {
            trendData = nil
            helioTrendData = nil
            trendCacheKey = nil
            return
        }

        let cacheKey = makeTrendCacheKey(for: viewDate)
        guard trendCacheKey != cacheKey || trendData == nil else { return }

        trendData = buildTrendData(baseDate: viewDate)
        if options.showWheel {
            helioTrendData = buildHelioTrendData(baseDate: viewDate)
        } else {
            helioTrendData = nil
        }
        trendCacheKey = cacheKey
    }

    private func makeTrendCacheKey(for date: Date) -> TrendCacheKey {
        TrendCacheKey(
            minuteBucket: Int(date.timeIntervalSince1970 / trendRefreshInterval),
            lockZodiac: options.lockZodiac,
            centerSignIndex: options.centerSignIndex,
            showWheel: options.showWheel
        )
    }

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

    private func buildHelioTrendData(baseDate: Date) -> HelioTrendData {
        let stepMs = Double(trendStepHours) * 3600
        let halfWindowMs = Double(trendWindowDays) * 86400
        let sampleCount = Int((halfWindowMs * 2) / stepMs) + 1
        let centerIndex = sampleCount / 2

        let bodyIds = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
        var series: [String: [Double]] = [:]
        for id in bodyIds {
            series[id] = []
        }

        for i in 0..<sampleCount {
            let dt = baseDate.addingTimeInterval(Double(i - centerIndex) * stepMs)
            let helio = heliocentricLongitudes(for: dt)

            for id in bodyIds {
                series[id]?.append(helio.longitude(for: id))
            }
        }

        return HelioTrendData(series: series, sampleCount: sampleCount, centerIndex: centerIndex)
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

    // MARK: - Events

    func refreshEvents(force: Bool = false, around anchorDate: Date? = nil) {
        let anchorDate = anchorDate ?? viewDate
        let anchorDay = utcDayOrdinal(for: anchorDate)
        guard force || anchorDay != eventsAnchorDay else { return }

        eventsAnchorDay = anchorDay
        let start = utcStartOfDay(anchorDate)
        let end = start.addingTimeInterval(Double(eventWindowDays) * 86_400)

        var events: [SkyEvent] = []
        events.append(contentsOf: ingressEvents(start: start, end: end))
        events.append(contentsOf: stationEvents(start: start, end: end))
        events.append(contentsOf: conjunctionEvents(start: start, end: end))
        events.append(contentsOf: oppositionEvents(start: start, end: end))
        events.append(contentsOf: moonPhaseEvents(start: start, end: end))

        upcomingEvents = dedupeEvents(events.sorted { $0.date < $1.date })
            .filter { $0.date >= start }
    }

    private func ingressEvents(start: Date, end: Date) -> [SkyEvent] {
        let bodyIDs = ["sun", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let step = TimeInterval(6 * 3600)
        var events: [SkyEvent] = []

        for bodyID in bodyIDs {
            guard let body = celestialBodies.first(where: { $0.id == bodyID }) else { continue }

            var previousDate = start
            var previousSign = zodiacSignIndex(for: longitude(of: bodyID, at: start))
            var cursor = start.addingTimeInterval(step)

            while cursor <= end {
                let currentSign = zodiacSignIndex(for: longitude(of: bodyID, at: cursor))
                if currentSign != previousSign {
                    let ingressDate = refineIngressDate(
                        bodyID: bodyID,
                        fromSign: previousSign,
                        low: previousDate,
                        high: cursor
                    )
                    let sign = zodiacSigns[currentSign]
                    events.append(
                        SkyEvent(
                            date: ingressDate,
                            kind: .ingress,
                            title: "\(body.name) enters \(sign.name)",
                            subtitle: ingressKeywords(body: bodyID, signIndex: currentSign),
                            symbol: "sparkles",
                            tint: body.color
                        )
                    )
                }

                previousDate = cursor
                previousSign = currentSign
                cursor = cursor.addingTimeInterval(step)
            }
        }

        return events
    }

    private func stationEvents(start: Date, end: Date) -> [SkyEvent] {
        let bodyIDs = ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let step = TimeInterval(6 * 3600)
        var events: [SkyEvent] = []

        for bodyID in bodyIDs {
            guard let body = celestialBodies.first(where: { $0.id == bodyID }) else { continue }

            var previousDate = start
            var previousSign = motionSign(for: bodyID, at: previousDate)
            var lastEventDate: Date?
            var cursor = start.addingTimeInterval(step)

            while cursor <= end {
                let currentSign = motionSign(for: bodyID, at: cursor)
                let changed = previousSign != currentSign && !(previousSign == 0 && currentSign == 0)
                if changed {
                    let stationDate = refineStationDate(bodyID: bodyID, low: previousDate, high: cursor)
                    let tooClose = lastEventDate.map { abs($0.timeIntervalSince(stationDate)) < 3 * 86_400 } ?? false
                    if !tooClose {
                        let afterMotion = dailyMotion(for: bodyID, at: stationDate.addingTimeInterval(24 * 3600))
                        let isRetrogradeAfterStation = afterMotion < 0
                        events.append(
                            SkyEvent(
                                date: stationDate,
                                kind: isRetrogradeAfterStation ? .stationRetrograde : .stationDirect,
                                title: isRetrogradeAfterStation ? "\(body.name) stations retrograde" : "\(body.name) stations direct",
                                subtitle: stationKeywords(body: bodyID, isRetrograde: isRetrogradeAfterStation),
                                symbol: isRetrogradeAfterStation ? "arrow.uturn.backward.circle" : "arrow.uturn.forward.circle",
                                tint: body.color
                            )
                        )
                        lastEventDate = stationDate
                    }
                }

                previousDate = cursor
                previousSign = currentSign
                cursor = cursor.addingTimeInterval(step)
            }
        }

        return events
    }

    private func conjunctionEvents(start: Date, end: Date) -> [SkyEvent] {
        let bodies = ["sun", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let step = TimeInterval(12 * 3600)
        var events: [SkyEvent] = []

        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                guard let bodyA = celestialBodies.first(where: { $0.id == a }),
                      let bodyB = celestialBodies.first(where: { $0.id == b }) else { continue }

                var previousDate = start
                var previousValue = conjunctionMetric(a: a, b: b, at: previousDate)
                var cursor = start.addingTimeInterval(step)
                var lastEventDate: Date?

                while cursor <= end {
                    let currentValue = conjunctionMetric(a: a, b: b, at: cursor)
                    let crossed = (previousValue < 0 && currentValue >= 0) || (previousValue > 0 && currentValue <= 0)

                    if crossed {
                        let eventDate = refineConjunctionDate(a: a, b: b, low: previousDate, high: cursor)
                        let tooClose = lastEventDate.map { abs($0.timeIntervalSince(eventDate)) < 5 * 86_400 } ?? false
                        if !tooClose {
                            let tint = bodyA.color.mix(with: bodyB.color, by: 0.5)
                            events.append(
                                SkyEvent(
                                    date: eventDate,
                                    kind: .conjunction,
                                    title: "\(bodyA.name) conjunct \(bodyB.name)",
                                    subtitle: "\(aspectKeywords(bodyA: a, bodyB: b, aspectAngle: 0)) · \(signContext(bodyA: a, bodyB: b, at: eventDate))",
                                    symbol: "circle.hexagongrid",
                                    tint: tint,
                                    bodyA: a,
                                    bodyB: b,
                                    aspectAngle: 0
                                )
                            )
                            lastEventDate = eventDate
                        }
                    }

                    previousDate = cursor
                    previousValue = currentValue
                    cursor = cursor.addingTimeInterval(step)
                }
            }
        }

        return events
    }

    private func oppositionEvents(start: Date, end: Date) -> [SkyEvent] {
        let bodies = ["sun", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let step = TimeInterval(12 * 3600)
        var events: [SkyEvent] = []

        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let a = bodies[i]
                let b = bodies[j]
                guard let bodyA = celestialBodies.first(where: { $0.id == a }),
                      let bodyB = celestialBodies.first(where: { $0.id == b }) else { continue }

                var previousDate = start
                var previousValue = oppositionMetric(a: a, b: b, at: previousDate)
                var cursor = start.addingTimeInterval(step)
                var lastEventDate: Date?

                while cursor <= end {
                    let currentValue = oppositionMetric(a: a, b: b, at: cursor)
                    let crossed = (previousValue < 0 && currentValue >= 0) || (previousValue > 0 && currentValue <= 0)

                    if crossed {
                        let eventDate = refineOppositionDate(a: a, b: b, low: previousDate, high: cursor)
                        let tooClose = lastEventDate.map { abs($0.timeIntervalSince(eventDate)) < 5 * 86_400 } ?? false
                        if !tooClose {
                            let tint = bodyA.color.mix(with: bodyB.color, by: 0.5)
                            events.append(
                                SkyEvent(
                                    date: eventDate,
                                    kind: .opposition,
                                    title: "\(bodyA.name) opposite \(bodyB.name)",
                                    subtitle: "\(aspectKeywords(bodyA: a, bodyB: b, aspectAngle: 180)) · \(signContext(bodyA: a, bodyB: b, at: eventDate))",
                                    symbol: "arrow.left.and.right.circle",
                                    tint: tint,
                                    bodyA: a,
                                    bodyB: b,
                                    aspectAngle: 180
                                )
                            )
                            lastEventDate = eventDate
                        }
                    }

                    previousDate = cursor
                    previousValue = currentValue
                    cursor = cursor.addingTimeInterval(step)
                }
            }
        }

        return events
    }

    private func moonPhaseEvents(start: Date, end: Date) -> [SkyEvent] {
        let step = TimeInterval(3 * 3600)
        var events: [SkyEvent] = []

        var previousDate = start
        var previousUnwrapped = moonElongation(at: start)
        var cycleCount = 0.0
        var nextTarget = floor(previousUnwrapped / 90) * 90 + 90
        var cursor = start.addingTimeInterval(step)

        while cursor <= end.addingTimeInterval(step) {
            let raw = moonElongation(at: cursor)
            var unwrapped = raw + cycleCount * 360
            if unwrapped < previousUnwrapped - 180 {
                cycleCount += 1
                unwrapped = raw + cycleCount * 360
            }

            while nextTarget <= unwrapped {
                let span = unwrapped - previousUnwrapped
                guard span > 0 else { break }

                let fraction = (nextTarget - previousUnwrapped) / span
                let seconds = cursor.timeIntervalSince(previousDate)
                let eventDate = previousDate.addingTimeInterval(seconds * fraction)

                if let event = moonPhaseEvent(at: eventDate, angle: Int(nextTarget.rounded()) % 360) {
                    events.append(event)
                }
                nextTarget += 90
            }

            previousDate = cursor
            previousUnwrapped = unwrapped
            cursor = cursor.addingTimeInterval(step)
        }

        return events
    }

    private func moonPhaseEvent(at date: Date, angle: Int) -> SkyEvent? {
        switch ((angle % 360) + 360) % 360 {
        case 0:
            return SkyEvent(
                date: date,
                kind: .moonPhase,
                title: "New Moon",
                subtitle: "Sun and Moon align",
                symbol: "moonphase.new.moon",
                tint: .white
            )
        case 90:
            return SkyEvent(
                date: date,
                kind: .moonPhase,
                title: "First Quarter Moon",
                subtitle: "Waxing half moon",
                symbol: "moonphase.first.quarter",
                tint: .white
            )
        case 180:
            return SkyEvent(
                date: date,
                kind: .moonPhase,
                title: "Full Moon",
                subtitle: "Moon opposite the Sun",
                symbol: "moonphase.full.moon",
                tint: .white
            )
        case 270:
            return SkyEvent(
                date: date,
                kind: .moonPhase,
                title: "Last Quarter Moon",
                subtitle: "Waning half moon",
                symbol: "moonphase.last.quarter",
                tint: .white
            )
        default:
            return nil
        }
    }

    private func refineIngressDate(bodyID: String, fromSign: Int, low: Date, high: Date) -> Date {
        var lo = low
        var hi = high

        for _ in 0..<18 {
            let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            let midSign = zodiacSignIndex(for: longitude(of: bodyID, at: mid))
            if midSign == fromSign {
                lo = mid
            } else {
                hi = mid
            }
        }

        return hi
    }

    private func refineStationDate(bodyID: String, low: Date, high: Date) -> Date {
        var lo = low
        var hi = high
        var fLo = dailyMotion(for: bodyID, at: lo)
        var fHi = dailyMotion(for: bodyID, at: hi)

        if abs(fLo) <= stationEpsilon { return lo }
        if abs(fHi) <= stationEpsilon { return hi }

        // If no strict sign change in this bracket, pick the local minimum |motion|.
        if fLo * fHi > 0 {
            var bestDate = lo
            var bestAbs = abs(fLo)
            for k in 1...24 {
                let t = lo.timeIntervalSince1970 + (hi.timeIntervalSince1970 - lo.timeIntervalSince1970) * Double(k) / 24
                let candidate = Date(timeIntervalSince1970: t)
                let absMotion = abs(dailyMotion(for: bodyID, at: candidate))
                if absMotion < bestAbs {
                    bestAbs = absMotion
                    bestDate = candidate
                }
            }
            return bestDate
        }

        for _ in 0..<24 {
            let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            let fMid = dailyMotion(for: bodyID, at: mid)

            if abs(fMid) <= stationEpsilon {
                return mid
            }

            if fLo * fMid <= 0 {
                hi = mid
                fHi = fMid
            } else {
                lo = mid
                fLo = fMid
            }
        }

        return abs(fLo) < abs(fHi) ? lo : hi
    }

    private func refineConjunctionDate(a: String, b: String, low: Date, high: Date) -> Date {
        var lo = low
        var hi = high
        var fLo = conjunctionMetric(a: a, b: b, at: lo)
        var fHi = conjunctionMetric(a: a, b: b, at: hi)

        for _ in 0..<22 {
            let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            let fMid = conjunctionMetric(a: a, b: b, at: mid)

            if abs(fMid) < 0.02 {
                return mid
            }

            if fLo == 0 { return lo }
            if fHi == 0 { return hi }

            if fLo * fMid <= 0 {
                hi = mid
                fHi = fMid
            } else {
                lo = mid
                fLo = fMid
            }
        }

        return Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
    }

    private func conjunctionMetric(a: String, b: String, at date: Date) -> Double {
        let lonA = longitude(of: a, at: date)
        let lonB = longitude(of: b, at: date)
        return signedDelta(lonA, lonB)
    }

    private func refineOppositionDate(a: String, b: String, low: Date, high: Date) -> Date {
        var lo = low
        var hi = high
        var fLo = oppositionMetric(a: a, b: b, at: lo)
        var fHi = oppositionMetric(a: a, b: b, at: hi)

        for _ in 0..<22 {
            let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            let fMid = oppositionMetric(a: a, b: b, at: mid)

            if abs(fMid) < 0.02 {
                return mid
            }

            if fLo == 0 { return lo }
            if fHi == 0 { return hi }

            if fLo * fMid <= 0 {
                hi = mid
                fHi = fMid
            } else {
                lo = mid
                fLo = fMid
            }
        }

        return Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
    }

    private func oppositionMetric(a: String, b: String, at date: Date) -> Double {
        let lonA = longitude(of: a, at: date)
        let lonB = longitude(of: b, at: date)
        let separation = abs(signedDelta(lonA, lonB))
        return separation - 180
    }

    private func dedupeEvents(_ events: [SkyEvent]) -> [SkyEvent] {
        var deduped: [SkyEvent] = []
        for event in events {
            if let last = deduped.last,
               last.title == event.title,
               abs(last.date.timeIntervalSince(event.date)) < 1_800 {
                continue
            }
            deduped.append(event)
        }
        return deduped
    }

    // MARK: - Orb Curve Sampling

    func orbCurveSamples(bodyA: String, bodyB: String, aspectAngle: Double,
                         centerDate: Date, windowDays: Int = 60, maxOrb: Double = 15) -> [OrbSample] {
        let stepSeconds = TimeInterval(12 * 3600)
        let totalSamples = windowDays * 2 * 2 // 12-hour steps across ±windowDays
        let startDate = centerDate.addingTimeInterval(-Double(windowDays) * 86_400)

        var samples: [OrbSample] = []
        for i in 0...totalSamples {
            let date = startDate.addingTimeInterval(Double(i) * stepSeconds)
            let lonA = longitude(of: bodyA, at: date)
            let lonB = longitude(of: bodyB, at: date)

            let rawOrb: Double
            if aspectAngle == 0 {
                rawOrb = abs(signedDelta(lonA, lonB))
            } else {
                rawOrb = abs(abs(signedDelta(lonA, lonB)) - aspectAngle)
            }

            // Clamp to maxOrb so curve meets baseline at edges
            let orb = min(rawOrb, maxOrb)

            // Use the slower body's sign for coloring
            let slowerBody = isSlowerBody(bodyB, than: bodyA) ? bodyB : bodyA
            let slowerLon = slowerBody == bodyA ? lonA : lonB
            let signIdx = Int(normalizeAngle(slowerLon) / 30) % 12

            samples.append(OrbSample(date: date, orb: orb, signIndex: signIdx))
        }
        return samples
    }

    private func isSlowerBody(_ a: String, than b: String) -> Bool {
        let order = ["moon", "sun", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"]
        let idxA = order.firstIndex(of: a) ?? 0
        let idxB = order.firstIndex(of: b) ?? 0
        return idxA > idxB
    }

    private func longitude(of bodyID: String, at date: Date) -> Double {
        geocentricLongitudes(for: date).longitude(for: bodyID)
    }

    private func zodiacSignIndex(for longitude: Double) -> Int {
        Int(normalizeAngle(longitude) / 30) % 12
    }

    private func dailyMotion(for bodyID: String, at date: Date) -> Double {
        let before = date.addingTimeInterval(-6 * 3600)
        let after = date.addingTimeInterval(6 * 3600)
        let lonBefore = longitude(of: bodyID, at: before)
        let lonAfter = longitude(of: bodyID, at: after)
        return signedDelta(lonAfter, lonBefore) * 2
    }

    private func motionSign(for bodyID: String, at date: Date) -> Int {
        let motion = dailyMotion(for: bodyID, at: date)
        if motion > stationEpsilon { return 1 }
        if motion < -stationEpsilon { return -1 }
        return 0
    }

    private func moonElongation(at date: Date) -> Double {
        let state = geocentricLongitudes(for: date)
        return normalizeAngle(state.moon - state.sun)
    }

    private func utcDayOrdinal(for date: Date) -> Int {
        Int(floor(date.timeIntervalSince1970 / 86_400))
    }

    private func utcStartOfDay(_ date: Date) -> Date {
        Date(timeIntervalSince1970: TimeInterval(utcDayOrdinal(for: date) * 86_400))
    }

    // MARK: - Date Bookmarks

    func addBookmark(date: Date) {
        let isDuplicate = savedDates.contains { abs($0.date.timeIntervalSince(date)) < 60 }
        guard !isDuplicate else { return }

        savedDates.insert(DateBookmark(date: date), at: 0)
        if savedDates.count > bookmarkLimit {
            savedDates = Array(savedDates.prefix(bookmarkLimit))
        }
        saveSettings()
    }

    func removeBookmark(_ bookmark: DateBookmark) {
        savedDates.removeAll { $0.id == bookmark.id }
        saveSettings()
    }

    // MARK: - Formatted Timestamp

    var formattedTimestamp: String {
        StarPathDateFormats.timestamp.string(from: viewDate)
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        let ud = userDefaults
        ud.set(options.showStars, forKey: SettingsKey.showStars)
        ud.set(options.showLabels, forKey: SettingsKey.showLabels)
        ud.set(options.showDrift, forKey: SettingsKey.showDrift)
        ud.set(options.showTime, forKey: SettingsKey.showTime)
        ud.set(options.showMoon, forKey: SettingsKey.showMoon)
        ud.set(options.showWheel, forKey: SettingsKey.showWheel)
        ud.set(options.heliocentricWheel, forKey: SettingsKey.heliocentricWheel)
        ud.set(options.realisticPlanets, forKey: SettingsKey.realisticPlanets)
        ud.set(options.lockZodiac, forKey: SettingsKey.lockZodiac)
        ud.set(options.centerSignIndex, forKey: SettingsKey.centerSignIndex)
        ud.set(options.invertZodiacOrder, forKey: SettingsKey.invertZodiacOrder)
        ud.set(selectedStep.rawValue, forKey: SettingsKey.selectedStep)
        if let data = try? JSONEncoder().encode(savedDates) {
            ud.set(data, forKey: SettingsKey.savedDates)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadSettings() {
        let ud = userDefaults
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
        if ud.object(forKey: SettingsKey.showWheel) != nil {
            options.showWheel = ud.bool(forKey: SettingsKey.showWheel)
        }
        if ud.object(forKey: SettingsKey.heliocentricWheel) != nil {
            options.heliocentricWheel = ud.bool(forKey: SettingsKey.heliocentricWheel)
        }
        if ud.object(forKey: SettingsKey.realisticPlanets) != nil {
            options.realisticPlanets = ud.bool(forKey: SettingsKey.realisticPlanets)
        }
        if ud.object(forKey: SettingsKey.lockZodiac) != nil {
            options.lockZodiac = ud.bool(forKey: SettingsKey.lockZodiac)
        }
        if ud.object(forKey: SettingsKey.centerSignIndex) != nil {
            options.centerSignIndex = ud.integer(forKey: SettingsKey.centerSignIndex)
        }
        if ud.object(forKey: SettingsKey.invertZodiacOrder) != nil {
            options.invertZodiacOrder = ud.bool(forKey: SettingsKey.invertZodiacOrder)
        }
        if let stepRaw = ud.string(forKey: SettingsKey.selectedStep),
           let step = TimeStep(rawValue: stepRaw) {
            selectedStep = step
        }
        if let data = ud.data(forKey: SettingsKey.savedDates),
           let decoded = try? JSONDecoder().decode([DateBookmark].self, from: data) {
            savedDates = decoded.sorted { $0.date > $1.date }
        }
    }
}
