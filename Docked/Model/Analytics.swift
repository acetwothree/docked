//
//  Analytics.swift
//  Docked
//
//  A free, no-backend analytics layer. Every event is:
//    • written to OSLog (visible in Console.app / Xcode, and in a sysdiagnose)
//    • rolled into persistent counters + a capped event log in UserDefaults
//      so you can inspect real usage on-device (Settings ▸ Developer ▸
//      Analytics) even before wiring a server
//
//  MetricKit (Apple, free, zero-config) is also subscribed here: it delivers
//  daily launch-time / hang-rate / memory / CPU / disk metrics and crash &
//  hang diagnostics, which are logged and summarised.
//
//  When you're ready for dashboards, funnels and retention cohorts, App Store
//  Connect already gives downloads / impressions / sessions / crashes /
//  retention for free once published — and this file is the single place to
//  add a Firebase Analytics / TelemetryDeck / PostHog call inside `emit()`.
//

import Foundation
import OSLog
import UIKit
#if canImport(MetricKit)
import MetricKit
#endif

enum AnalyticsEvent: String {
    // lifecycle
    case appLaunch, sessionStart, sessionEnd, appForeground, appBackground
    case onboardingShown, onboardingCompleted, onboardingSkipped
    // navigation / games
    case gameOpened, gameClosed, gameStarted, gameOver, gameReset
    case newHighScore, scoreMilestone
    // engagement
    case favoriteAdded, favoriteRemoved
    case tvStretched, tvThemeChanged, pipHelpOpened, videoDetected
    case shareTapped, reviewPromptShown
    case settingChanged
    // monetisation
    case paywallShown, paywallDismissed, purchaseStarted, purchaseCompleted, purchaseFailed, restoreTapped
    // performance (from MetricKit)
    case perfDailyMetrics, crashDiagnostic, hangDiagnostic
}

final class Analytics: NSObject {
    static let shared = Analytics()

    private let log = Logger(subsystem: "com.docked.app", category: "Analytics")
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.docked.analytics", qos: .utility)

    private let kCounters = "analytics.counters"
    private let kLog = "analytics.log"
    private let kFirstLaunch = "analytics.firstLaunchAt"
    private let kLastActive = "analytics.lastActiveDay"
    private let kSessionStart = "analytics.sessionStartAt"
    private let logCap = 600

    private var openGame: (name: String, at: Date)?

    // MARK: setup

    func start() {
        queue.async { [self] in
            if defaults.object(forKey: kFirstLaunch) == nil {
                defaults.set(Date().timeIntervalSince1970, forKey: kFirstLaunch)
            }
            bump("app.launches")
            markActiveDay()
        }
        track(.appLaunch, [
            "os": UIDevice.current.systemVersion,
            "model": Self.deviceModel,
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?",
            "day": daysSinceFirstLaunch,
        ])
        #if canImport(MetricKit)
        MXMetricManager.shared.add(self)
        #endif
    }

    // MARK: session

    func sessionBegan() {
        queue.async { [self] in
            defaults.set(Date().timeIntervalSince1970, forKey: kSessionStart)
            bump("sessions.count")
            markActiveDay()
        }
        track(.sessionStart, ["day": daysSinceFirstLaunch])
    }

    func sessionEnded() {
        let started = defaults.double(forKey: kSessionStart)
        let secs = started > 0 ? max(0, Date().timeIntervalSince1970 - started) : 0
        queue.async { [self] in addToTotal("sessions.totalSeconds", secs) }
        track(.sessionEnd, ["seconds": Int(secs)])
    }

    // MARK: game helpers

    func gameOpened(_ name: String) {
        openGame = (name, Date())
        queue.async { [self] in bump("game.\(name).opens") }
        track(.gameOpened, ["game": name])
    }

    func gameClosed(_ name: String) {
        let secs = openGame.map { Date().timeIntervalSince($0.at) } ?? 0
        openGame = nil
        queue.async { [self] in addToTotal("game.\(name).seconds", secs) }
        track(.gameClosed, ["game": name, "seconds": Int(secs)])
    }

    func gameOver(_ name: String, score: Int) {
        queue.async { [self] in
            bump("game.\(name).rounds")
            if score > highScore(name) { defaults.set(score, forKey: "analytics.high.\(name)") }
        }
        track(.gameOver, ["game": name, "score": score])
    }

    func highScore(_ name: String) -> Int { defaults.integer(forKey: "analytics.high.\(name)") }

    // MARK: core

    func track(_ event: AnalyticsEvent, _ props: [String: Any] = [:]) {
        let name = event.rawValue
        let ts = Date().timeIntervalSince1970
        log.info("▸ \(name, privacy: .public) \(Self.describe(props), privacy: .public)")
        queue.async { [self] in
            bump("event.\(name)")
            appendLog(["e": name, "t": ts, "p": props.mapValues { "\($0)" }])
            emit(name: name, props: props)   // <- plug a real backend in here
        }
    }

    /// The single hook for a third-party SDK. Left empty on purpose.
    private func emit(name: String, props: [String: Any]) {
        // e.g. FirebaseAnalytics.Analytics.logEvent(name, parameters: props as? [String: Any])
        // e.g. TelemetryDeck.signal(name, parameters: props.mapValues { "\($0)" })
    }

    // MARK: persistence

    private func bump(_ key: String, _ by: Int = 1) {
        var c = counters
        c[key, default: 0] += Double(by)
        counters = c
    }
    private func addToTotal(_ key: String, _ v: Double) {
        var c = counters
        c[key, default: 0] += v
        counters = c
    }
    private var counters: [String: Double] {
        get { (defaults.dictionary(forKey: kCounters) as? [String: Double]) ?? [:] }
        set { defaults.set(newValue, forKey: kCounters) }
    }
    private func appendLog(_ entry: [String: Any]) {
        var arr = (defaults.array(forKey: kLog) as? [[String: Any]]) ?? []
        arr.append(entry)
        if arr.count > logCap { arr.removeFirst(arr.count - logCap) }
        defaults.set(arr, forKey: kLog)
    }
    private func markActiveDay() {
        let today = Self.dayKey(Date())
        let last = defaults.string(forKey: kLastActive)
        if last != today {
            bump("days.active")
            defaults.set(today, forKey: kLastActive)
        }
    }

    var daysSinceFirstLaunch: Int {
        let first = defaults.double(forKey: kFirstLaunch)
        guard first > 0 else { return 0 }
        return Int((Date().timeIntervalSince1970 - first) / 86_400)
    }

    // MARK: inspection (Settings ▸ Developer ▸ Analytics)

    func snapshot() -> String {
        var out = "DOCKED · on-device analytics\n"
        out += "first launch: \(Self.stamp(defaults.double(forKey: kFirstLaunch)))\n"
        out += "day \(daysSinceFirstLaunch)\n\n"
        out += "── counters ──\n"
        for (k, v) in counters.sorted(by: { $0.key < $1.key }) {
            let n = v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(format: "%.1f", v)
            out += "\(k): \(n)\n"
        }
        let highs = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("analytics.high.") }
        if !highs.isEmpty {
            out += "\n── high scores ──\n"
            for k in highs.sorted() { out += "\(k.replacingOccurrences(of: "analytics.high.", with: "")): \(defaults.integer(forKey: k))\n" }
        }
        let arr = (defaults.array(forKey: kLog) as? [[String: Any]]) ?? []
        out += "\n── last \(min(40, arr.count)) events ──\n"
        for e in arr.suffix(40) {
            let t = (e["t"] as? Double).map(Self.stamp) ?? "?"
            let p = (e["p"] as? [String: String]).map { $0.map { "\($0)=\($1)" }.joined(separator: " ") } ?? ""
            out += "\(t)  \(e["e"] as? String ?? "?")  \(p)\n"
        }
        return out
    }

    func exportJSON() -> String {
        let payload: [String: Any] = [
            "firstLaunchAt": defaults.double(forKey: kFirstLaunch),
            "daysSinceFirstLaunch": daysSinceFirstLaunch,
            "counters": counters,
            "events": (defaults.array(forKey: kLog) as? [[String: Any]]) ?? [],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func reset() {
        [kCounters, kLog, kLastActive, kSessionStart].forEach { defaults.removeObject(forKey: $0) }
        for k in defaults.dictionaryRepresentation().keys where k.hasPrefix("analytics.high.") {
            defaults.removeObject(forKey: k)
        }
    }

    // MARK: helpers

    private static func describe(_ p: [String: Any]) -> String {
        p.isEmpty ? "" : "{ " + p.map { "\($0)=\($1)" }.sorted().joined(separator: ", ") + " }"
    }
    private static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    private static func stamp(_ ts: Double) -> String {
        guard ts > 0 else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: Date(timeIntervalSince1970: ts))
    }
    static let deviceModel: String = {
        var s = utsname(); uname(&s)
        return withUnsafeBytes(of: &s.machine) { raw in
            raw.prefix { $0 != 0 }.map { Character(UnicodeScalar(UInt8($0))) }.reduce("") { $0 + String($1) }
        }
    }()
}

#if canImport(MetricKit)
extension Analytics: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads {
            let json = String(data: p.jsonRepresentation(), encoding: .utf8) ?? ""
            track(.perfDailyMetrics, ["bytes": json.count])
            queue.async { [self] in appendLog(["e": "perfPayload", "t": Date().timeIntervalSince1970, "p": ["json": json]]) }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            let crashes = p.crashDiagnostics?.count ?? 0
            let hangs = p.hangDiagnostics?.count ?? 0
            if crashes > 0 { track(.crashDiagnostic, ["count": crashes]) }
            if hangs > 0 { track(.hangDiagnostic, ["count": hangs]) }
            let json = String(data: p.jsonRepresentation(), encoding: .utf8) ?? ""
            queue.async { [self] in appendLog(["e": "diagnosticPayload", "t": Date().timeIntervalSince1970, "p": ["json": json]]) }
        }
    }
}
#endif
