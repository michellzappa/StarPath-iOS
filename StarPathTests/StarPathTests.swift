//
//  StarPathTests.swift
//  StarPathTests
//
//  Created by Michell Zappa on 14/02/2026.
//

import Foundation
import Testing
@testable import StarPath

struct StarPathTests {

    @Test func manualTimeTravelPausesLiveUpdatesUntilReset() async throws {
        let (vm, cleanup) = makeViewModel()
        defer { cleanup() }

        vm.resumeLiveUpdates(syncImmediately: false)
        #expect(vm.isLiveMode)

        let startingDate = vm.viewDate
        vm.shiftTime(amount: 1, unit: .day)

        #expect(!vm.isLiveMode)
        #expect(vm.viewDate > startingDate)

        vm.resetToNow()
        #expect(vm.isLiveMode)
    }

    @Test func eventsRefreshAnchorsToViewedDate() async throws {
        let anchorDate = Date(timeIntervalSince1970: 2_208_988_800) // 2040-01-01 00:00:00 UTC
        let (vm, cleanup) = makeViewModel(initialDate: anchorDate)
        defer { cleanup() }

        vm.jump(to: anchorDate)
        vm.refreshEvents(force: true)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        let startOfDay = utcCalendar.startOfDay(for: anchorDate)

        #expect(!vm.upcomingEvents.isEmpty)
        #expect(vm.upcomingEvents.allSatisfy { $0.date >= startOfDay })
    }

    private func makeViewModel(initialDate: Date = Date()) -> (StarPathViewModel, () -> Void) {
        let suiteName = "StarPathTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let viewModel = StarPathViewModel(
            initialDate: initialDate,
            userDefaults: defaults,
            startsLiveUpdates: false
        )

        return (viewModel, {
            defaults.removePersistentDomain(forName: suiteName)
        })
    }
}
