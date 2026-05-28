import Foundation

class BuddyBriefing {
    struct Result {
        let headline: String
        let detail: String
    }

    private let aiKeywords = [
        "ai", "llm", "gpt", "claude", "gemini", "machine learning", "neural",
        "openai", "anthropic", "algorithm", "deep learning", "transformer",
        "mistral", "llama", "chatgpt", "copilot", "agent", "model", "diffusion"
    ]

    private let securityKeywords = [
        "exploit", "vulnerability", "cve", "zero-day", "ransomware", "breach",
        "malware", "hack", "phishing", "backdoor", "rce", "xss", "injection",
        "ddos", "attack", "cyber", "botnet", "credential", "leaked", "exposed",
        "patch", "critical", "pwn", "0day", "supply chain", "privilege escalation"
    ]

    func fetch(completion: @escaping (Result) -> Void) {
        let group = DispatchGroup()
        var aiStories: [String] = []
        var secStories: [String] = []
        var packages: [String] = []
        var cves: [CVE] = []
        var prs: [GitHubMonitor.PRSummary] = []

        group.enter()
        fetchHNStories { ai, sec in aiStories = ai; secStories = sec; group.leave() }

        group.enter()
        scanPackages { p in packages = p; group.leave() }

        group.enter()
        fetchCISAExploits { c in cves = c; group.leave() }

        group.enter()
        GitHubMonitor.shared.check { p in prs = p; group.leave() }

        group.notify(queue: .main) {
            completion(Result(
                headline: self.headline(ai: aiStories, sec: secStories, cves: cves, packages: packages, prs: prs),
                detail: self.detail(ai: aiStories, sec: secStories, cves: cves, packages: packages, prs: prs)
            ))
        }
    }

    // MARK: - Hacker News

    private func fetchHNStories(completion: @escaping ([String], [String]) -> Void) {
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json") else {
            completion([], []); return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let ids = try? JSONDecoder().decode([Int].self, from: data) else {
                completion([], []); return
            }
            self.fetchTitles(ids: Array(ids.prefix(60)), completion: completion)
        }.resume()
    }

    private func fetchTitles(ids: [Int], completion: @escaping ([String], [String]) -> Void) {
        var aiResults: [String] = []
        var secResults: [String] = []
        let lock = NSLock()
        let group = DispatchGroup()

        for id in ids {
            group.enter()
            guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json") else {
                group.leave(); continue
            }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                defer { group.leave() }
                guard let data,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let title = obj["title"] as? String else { return }
                let lower = title.lowercased()
                lock.lock()
                if self.aiKeywords.contains(where: { lower.contains($0) }) {
                    aiResults.append(title)
                } else if self.securityKeywords.contains(where: { lower.contains($0) }) {
                    secResults.append(title)
                }
                lock.unlock()
            }.resume()
        }

        group.notify(queue: .global()) {
            completion(Array(aiResults.prefix(5)), Array(secResults.prefix(5)))
        }
    }

    // MARK: - CISA Known Exploited Vulnerabilities

    struct CVE {
        let id: String
        let name: String
        let description: String
        let dateAdded: String
    }

    private func fetchCISAExploits(completion: @escaping ([CVE]) -> Void) {
        guard let url = URL(string: "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json") else {
            completion([]); return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let vulns = json["vulnerabilities"] as? [[String: Any]] else {
                completion([]); return
            }
            // Sort by dateAdded descending, take the 5 most recently added
            let sorted = vulns.sorted {
                ($0["dateAdded"] as? String ?? "") > ($1["dateAdded"] as? String ?? "")
            }
            let recent = sorted.prefix(5).compactMap { v -> CVE? in
                guard let id = v["cveID"] as? String,
                      let name = v["vulnerabilityName"] as? String,
                      let desc = v["shortDescription"] as? String,
                      let date = v["dateAdded"] as? String else { return nil }
                return CVE(id: id, name: name, description: desc, dateAdded: date)
            }
            completion(recent)
        }.resume()
    }

    // MARK: - Package Scanning

    private func scanPackages(completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var updates: [String] = []
            let home = FileManager.default.homeDirectoryForCurrentUser
            let docs = home.appendingPathComponent("Documents")

            guard let enumerator = FileManager.default.enumerator(
                at: docs,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { DispatchQueue.main.async { completion([]) }; return }

            for case let url as URL in enumerator {
                guard updates.count < 5 else { break }
                let depth = url.pathComponents.count - docs.pathComponents.count
                if depth > 4 { enumerator.skipDescendants(); continue }
                guard !url.path.contains("node_modules"),
                      !url.path.contains(".git") else { continue }

                if url.lastPathComponent == "package.json" {
                    let dir = url.deletingLastPathComponent()
                    if let out = self.run("npm outdated --json 2>/dev/null", in: dir.path),
                       let data = out.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       !json.isEmpty {
                        updates.append("\(dir.lastPathComponent): \(json.count) npm package(s) outdated")
                    }
                } else if url.lastPathComponent == "requirements.txt" {
                    let dir = url.deletingLastPathComponent()
                    if let out = self.run("pip list --outdated --format=json 2>/dev/null", in: dir.path),
                       let data = out.data(using: .utf8),
                       let arr = try? JSONDecoder().decode([[String: String]].self, from: data),
                       !arr.isEmpty {
                        updates.append("\(dir.lastPathComponent): \(arr.count) pip package(s) outdated")
                    }
                }
            }

            DispatchQueue.main.async { completion(updates) }
        }
    }

    private func run(_ cmd: String, in dir: String) -> String? {
        let p = Process()
        p.launchPath = "/bin/zsh"
        p.arguments = ["-l", "-c", "cd \"\(dir)\" && \(cmd)"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do {
            try p.run()
            p.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch { return nil }
    }

    // MARK: - Formatting

    private func headline(ai: [String], sec: [String], cves: [CVE], packages: [String], prs: [GitHubMonitor.PRSummary]) -> String {
        var parts: [String] = []
        if !ai.isEmpty { parts.append("\(ai.count) AI story\(ai.count == 1 ? "" : "s")") }
        if !sec.isEmpty || !cves.isEmpty {
            let total = sec.count + cves.count
            parts.append("\(total) security alert\(total == 1 ? "" : "s")")
        }
        if !prs.isEmpty { parts.append("\(prs.count) PR\(prs.count == 1 ? "" : "s")") }
        if !packages.isEmpty { parts.append("\(packages.count) pkg update\(packages.count == 1 ? "" : "s")") }
        return parts.isEmpty ? "all quiet today" : parts.joined(separator: " + ")
    }

    private func detail(ai: [String], sec: [String], cves: [CVE], packages: [String], prs: [GitHubMonitor.PRSummary]) -> String {
        var sections: [String] = []

        if !ai.isEmpty {
            var block = "AI & tech news:"
            ai.forEach { block += "\n  \u{2022} \($0)" }
            sections.append(block)
        }

        if !cves.isEmpty {
            var block = "actively exploited CVEs (CISA KEV):"
            cves.forEach { block += "\n  \u{2022} \($0.id) — \($0.name) [\($0.dateAdded)]" }
            sections.append(block)
        }

        if !sec.isEmpty {
            var block = "cyber & security news:"
            sec.forEach { block += "\n  \u{2022} \($0)" }
            sections.append(block)
        }

        if !prs.isEmpty {
            sections.append(GitHubMonitor.shared.formatDetail(prs))
        }

        if !packages.isEmpty {
            var block = "package updates:"
            packages.forEach { block += "\n  \u{2022} \($0)" }
            sections.append(block)
        }

        return sections.isEmpty ? "nothing new — you're all caught up!" : sections.joined(separator: "\n\n")
    }
}
