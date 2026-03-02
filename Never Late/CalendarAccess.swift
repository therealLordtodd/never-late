import EventKit
import Foundation
import MapKit

enum CalendarEventAlarmKind: String {
    case calendar
    case timeToLeave
}

struct CalendarEventAlarm {
    let event: EKEvent
    let alarm: EKAlarm?
    let fireDate: Date
    let kind: CalendarEventAlarmKind
    let detail: String
}

final class CalendarAccess {
    private let eventStore = EKEventStore()
    private let maxTimeToLeaveCandidates = 12
    private let proximityFallbackLeadSeconds: TimeInterval = 5

    private struct AlarmCandidate {
        let alarm: EKAlarm?
        let fireDate: Date
        let detail: String
    }

    static func hasReadAccess(_ status: EKAuthorizationStatus) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    func requestAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                AppLog.app.error("Calendar access request failed: \(error.localizedDescription)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        AppLog.app.error("Calendar access request failed: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func calendars() -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }

    func events(from start: Date, to end: Date, in calendars: [EKCalendar]) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventStore.events(matching: predicate)
    }

    func alarms(
        for events: [EKEvent],
        now: Date,
        behavior: AlarmBehaviorSnapshot
    ) async -> [CalendarEventAlarm] {
        var results = calendarAlarms(for: events, now: now)
        if behavior.timeToLeaveEnabled {
            let leave = await timeToLeaveAlarms(for: events, now: now, behavior: behavior)
            results.append(contentsOf: leave)
        }
        return results
    }

    private func calendarAlarms(for events: [EKEvent], now: Date) -> [CalendarEventAlarm] {
        var results: [CalendarEventAlarm] = []
        for event in events {
            guard let alarms = event.alarms, !alarms.isEmpty else { continue }
            guard let selected = firstFutureAlarmCandidate(for: event, alarms: alarms, now: now) else { continue }
            results.append(
                CalendarEventAlarm(
                    event: event,
                    alarm: selected.alarm,
                    fireDate: selected.fireDate,
                    kind: .calendar,
                    detail: selected.detail
                )
            )
        }
        return results
    }

    private func firstFutureAlarmCandidate(
        for event: EKEvent,
        alarms: [EKAlarm],
        now: Date
    ) -> AlarmCandidate? {
        let nonProximityCandidates = alarms
            .filter { $0.proximity == .none }
            .compactMap { alarmCandidate(for: $0, event: event, now: now) }
        if let selected = nonProximityCandidates.min(by: { $0.fireDate < $1.fireDate }) {
            return selected
        }

        // Fall back to proximity alarms only when there is no timed alarm candidate.
        // This keeps time-based reminders reliable while still supporting geofence-only alarms.
        let proximityCandidates = alarms
            .filter { $0.proximity != .none }
            .compactMap { alarmCandidate(for: $0, event: event, now: now) }
        return proximityCandidates.min(by: { $0.fireDate < $1.fireDate })
    }

    private func alarmCandidate(
        for alarm: EKAlarm,
        event: EKEvent,
        now: Date
    ) -> AlarmCandidate? {
        if alarm.proximity != .none {
            guard let fireDate = proximityFallbackFireDate(for: event, now: now) else { return nil }
            return AlarmCandidate(
                alarm: alarm,
                fireDate: fireDate,
                detail: proximityDetail(alarm.proximity)
            )
        }

        if let absoluteDate = alarm.absoluteDate {
            guard absoluteDate > now else { return nil }
            return AlarmCandidate(alarm: alarm, fireDate: absoluteDate, detail: "calendar alarm")
        }

        let fireDate = event.startDate.addingTimeInterval(alarm.relativeOffset)
        guard fireDate > now else { return nil }
        return AlarmCandidate(alarm: alarm, fireDate: fireDate, detail: "calendar alarm")
    }

    private func proximityFallbackFireDate(for event: EKEvent, now: Date) -> Date? {
        if event.startDate > now {
            return event.startDate
        }
        if event.endDate > now {
            return now.addingTimeInterval(proximityFallbackLeadSeconds)
        }
        return nil
    }

    private func proximityDetail(_ proximity: EKAlarmProximity) -> String {
        switch proximity {
        case .enter:
            return "location alarm (arrive)"
        case .leave:
            return "location alarm (leave)"
        case .none:
            return "location alarm"
        @unknown default:
            return "location alarm"
        }
    }

    private func timeToLeaveAlarms(
        for events: [EKEvent],
        now: Date,
        behavior: AlarmBehaviorSnapshot
    ) async -> [CalendarEventAlarm] {
        let calendar = Calendar.current
        let maxEventStart = calendar.date(byAdding: .day, value: 2, to: now) ?? now
        let candidates = events
            .filter { event in
                event.isAllDay == false
                    && event.startDate > now
                    && event.startDate <= maxEventStart
                    && hasDestination(event)
            }
            .sorted { $0.startDate < $1.startDate }
        guard candidates.isEmpty == false else { return [] }

        var results: [CalendarEventAlarm] = []
        for event in candidates.prefix(maxTimeToLeaveCandidates) {
            if Task.isCancelled { break }
            guard let fireDate = await timeToLeaveFireDate(for: event, now: now, behavior: behavior) else { continue }
            if fireDate <= now { continue }
            let detail = "time to leave (\(behavior.timeToLeaveTransport.title.lowercased()))"
            results.append(
                CalendarEventAlarm(
                    event: event,
                    alarm: nil,
                    fireDate: fireDate,
                    kind: .timeToLeave,
                    detail: detail
                )
            )
        }
        return results
    }

    private func timeToLeaveFireDate(
        for event: EKEvent,
        now: Date,
        behavior: AlarmBehaviorSnapshot
    ) async -> Date? {
        let fallbackDate = event.startDate.addingTimeInterval(-Double(behavior.timeToLeaveFallbackMinutes * 60))
        guard fallbackDate > now else { return nil }
        guard let destination = await destinationMapItem(for: event) else {
            return fallbackDate
        }

        guard let departure = await expectedDepartureDate(
            destination: destination,
            arrivalDate: event.startDate,
            transport: behavior.timeToLeaveTransport
        ) else {
            return fallbackDate
        }

        let buffered = departure.addingTimeInterval(-Double(behavior.timeToLeavePrepMinutes * 60))
        return buffered > now ? buffered : nil
    }

    private func hasDestination(_ event: EKEvent) -> Bool {
        if let geo = event.structuredLocation?.geoLocation {
            return CLLocationCoordinate2DIsValid(geo.coordinate)
        }
        guard let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return location.isEmpty == false
    }

    private func destinationMapItem(for event: EKEvent) async -> MKMapItem? {
        if let geo = event.structuredLocation?.geoLocation, CLLocationCoordinate2DIsValid(geo.coordinate) {
            let placemark = MKPlacemark(coordinate: geo.coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = event.structuredLocation?.title ?? event.location ?? "Destination"
            return mapItem
        }

        guard let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
            location.isEmpty == false else {
            return nil
        }
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(location)
            guard let first = placemarks.first else { return nil }
            let mapItem = MKMapItem(placemark: MKPlacemark(placemark: first))
            mapItem.name = location
            return mapItem
        } catch {
            AppLog.app.warning("Failed to geocode event location: \(error.localizedDescription)")
            return nil
        }
    }

    private func expectedDepartureDate(
        destination: MKMapItem,
        arrivalDate: Date,
        transport: TimeToLeaveTransport
    ) async -> Date? {
        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = destination
        request.transportType = transport.mapKitTransportType
        request.arrivalDate = arrivalDate

        do {
            let eta = try await calculateETA(for: request)
            return eta.expectedDepartureDate
        } catch {
            AppLog.app.warning("Failed to estimate travel time: \(error.localizedDescription)")
            return nil
        }
    }

    private func calculateETA(for request: MKDirections.Request) async throws -> MKDirections.ETAResponse {
        let directions = MKDirections(request: request)
        return try await withCheckedThrowingContinuation { continuation in
            directions.calculateETA { response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "NeverLate",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Missing ETA response."]
                        )
                    )
                    return
                }
                continuation.resume(returning: response)
            }
        }
    }

}

private extension TimeToLeaveTransport {
    var mapKitTransportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}
