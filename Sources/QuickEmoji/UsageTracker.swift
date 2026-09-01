import Foundation

@MainActor
@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    private let storageKey: String
    private let defaults: UserDefaults
    private let maxEntriesPerApp = 100
    private let maxApps = 50

    private var data: [String: [UsageRecord]] = [:]
    private var pendingSave: Task<Void, Never>?

    struct UsageRecord: Codable {
        let character: String
        var count: Int
        var lastUsed: Date
    }

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "QuickEmoji.usageData"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    func recordUsage(_ character: String, bundleID: String) {
        var appRecords = data[bundleID] ?? []

        if let idx = appRecords.firstIndex(where: { $0.character == character }) {
            appRecords[idx].count += 1
            appRecords[idx].lastUsed = Date()
        } else {
            appRecords.append(UsageRecord(character: character, count: 1, lastUsed: Date()))
        }

        if appRecords.count > maxEntriesPerApp {
            appRecords.sort { score($0) > score($1) }
            appRecords = Array(appRecords.prefix(maxEntriesPerApp))
        }

        data[bundleID] = appRecords
        scheduleSave()
    }

    func rankedCharacters(for bundleID: String = "", limit: Int = 30) -> [String] {
        if !bundleID.isEmpty, let records = data[bundleID] {
            return
                records
                .sorted { score($0) > score($1) }
                .prefix(limit)
                .map(\.character)
        }
        return globalRanked(limit: limit)
    }

    func recentCharacters(limit: Int = 30) -> [String] {
        var latest: [String: Date] = [:]
        for records in data.values {
            for record in records {
                if let existing = latest[record.character] {
                    if record.lastUsed > existing { latest[record.character] = record.lastUsed }
                } else {
                    latest[record.character] = record.lastUsed
                }
            }
        }
        return
            latest
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)
    }

    func remove(character: String) {
        var newData: [String: [UsageRecord]] = [:]
        var changed = false
        for (bundleID, records) in data {
            let filtered = records.filter { $0.character != character }
            if filtered.count != records.count { changed = true }
            if !filtered.isEmpty { newData[bundleID] = filtered }
        }
        guard changed else { return }
        data = newData
        scheduleSave()
    }

    func clear() {
        guard !data.isEmpty else { return }
        data = [:]
        scheduleSave()
    }

    func contains(character: String) -> Bool {
        data.values.contains { records in records.contains { $0.character == character } }
    }

    func flushPendingSaves() {
        pendingSave?.cancel()
        pendingSave = nil
        save(data)
    }

    private func globalRanked(limit: Int) -> [String] {
        var merged: [String: UsageRecord] = [:]

        for (_, records) in data {
            for record in records {
                if var existing = merged[record.character] {
                    existing.count += record.count
                    if record.lastUsed > existing.lastUsed {
                        existing.lastUsed = record.lastUsed
                    }
                    merged[record.character] = existing
                } else {
                    merged[record.character] = record
                }
            }
        }

        return merged.values
            .sorted { score($0) > score($1) }
            .prefix(limit)
            .map(\.character)
    }

    private func score(_ record: UsageRecord) -> Double {
        let daysSinceUse = max(0, Date().timeIntervalSince(record.lastUsed) / 86400)
        let recencyWeight = 1.0 / (1.0 + daysSinceUse * 0.1)
        return Double(record.count) * recencyWeight
    }

    private func load() {
        guard let raw = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([String: [UsageRecord]].self, from: raw)
        else { return }
        data = decoded
    }

    private func scheduleSave() {
        pruneDataIfNeeded()

        pendingSave?.cancel()
        let snapshot = data
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save(snapshot)
        }
    }

    private func save(_ snapshot: [String: [UsageRecord]]) {
        if let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: storageKey)
        }
    }

    private func pruneDataIfNeeded() {
        if data.count > maxApps {
            let sorted = data.sorted { lhs, rhs in
                let lhsLatest = lhs.value.map(\.lastUsed).max() ?? .distantPast
                let rhsLatest = rhs.value.map(\.lastUsed).max() ?? .distantPast
                return lhsLatest > rhsLatest
            }
            data = Dictionary(uniqueKeysWithValues: sorted.prefix(maxApps).map { ($0.key, $0.value) })
        }
    }
}
