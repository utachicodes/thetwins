import Foundation

class BriefingHistory {
    static let shared = BriefingHistory()
    private let key = "BriefingHistoryV1"
    private let max = 7

    struct Entry: Codable {
        let character: String
        let date: Date
        let headline: String
        let detail: String
    }

    func save(character: String, headline: String, detail: String) {
        var entries = all()
        entries.insert(Entry(character: character, date: Date(), headline: headline, detail: detail), at: 0)
        if entries.count > max { entries = Array(entries.prefix(max)) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func all() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries
    }

    func formatted(for character: String) -> String {
        let entries = all().filter { $0.character == character }
        guard !entries.isEmpty else { return "no briefing history yet." }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium; fmt.timeStyle = .none
        return entries.map { "[\(fmt.string(from: $0.date))] \($0.headline)\n\($0.detail)" }
            .joined(separator: "\n\n---\n\n")
    }
}
