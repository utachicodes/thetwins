import Foundation
import Security

class GitHubMonitor {
    static let shared = GitHubMonitor()

    private let tokenKey = "GitHubPATToken"
    private let reposKey = "GitHubMonitorRepos"
    private let seenPRsKey = "GitHubSeenPRs"

    var token: String {
        get { keychainGet(tokenKey) ?? "" }
        set { if newValue.isEmpty { keychainDelete(tokenKey) } else { keychainSet(tokenKey, value: newValue) } }
    }
    var repos: [String] {
        get { UserDefaults.standard.stringArray(forKey: reposKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: reposKey) }
    }
    var isConfigured: Bool { !token.isEmpty && !repos.isEmpty }

    struct PRSummary {
        let repo: String
        let number: Int
        let title: String
        let reviewState: String  // "needs_review", "changes_requested", "approved", "new"
        let url: String
    }

    func check(completion: @escaping ([PRSummary]) -> Void) {
        guard isConfigured else { completion([]); return }

        let group = DispatchGroup()
        var results: [PRSummary] = []
        let lock = NSLock()

        for repo in repos {
            group.enter()
            fetchOpenPRs(repo: repo) { prs in
                lock.lock(); results.append(contentsOf: prs); lock.unlock()
                group.leave()
            }
        }
        group.notify(queue: .main) { completion(results) }
    }

    private func fetchOpenPRs(repo: String, completion: @escaping ([PRSummary]) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/pulls?state=open&per_page=10") else {
            completion([]); return
        }
        var req = request(url: url)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let prs = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                completion([]); return
            }
            let group = DispatchGroup()
            var summaries: [PRSummary] = []
            let lock = NSLock()
            for pr in prs {
                guard let number = pr["number"] as? Int,
                      let title = pr["title"] as? String,
                      let htmlURL = pr["html_url"] as? String else { continue }
                group.enter()
                self.fetchReviewState(repo: repo, number: number) { state in
                    let s = PRSummary(repo: repo, number: number, title: title,
                                      reviewState: state, url: htmlURL)
                    lock.lock(); summaries.append(s); lock.unlock()
                    group.leave()
                }
            }
            group.notify(queue: .global()) { completion(summaries) }
        }.resume()
    }

    private func fetchReviewState(repo: String, number: Int, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/pulls/\(number)/reviews") else {
            completion("unknown"); return
        }
        URLSession.shared.dataTask(with: request(url: url)) { data, _, _ in
            guard let data,
                  let reviews = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                completion("new"); return
            }
            let states = reviews.compactMap { $0["state"] as? String }
            if states.contains("CHANGES_REQUESTED") { completion("changes_requested") }
            else if states.contains("APPROVED") { completion("approved") }
            else if !states.isEmpty { completion("needs_review") }
            else { completion("new") }
        }.resume()
    }

    private func request(url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        r.setValue("lil-agents/1.0", forHTTPHeaderField: "User-Agent")
        return r
    }

    func formatDetail(_ prs: [PRSummary]) -> String {
        guard !prs.isEmpty else { return "" }
        let icon: (String) -> String = {
            switch $0 {
            case "changes_requested": return "⚠"
            case "approved": return "✓"
            case "needs_review": return "👀"
            default: return "•"
            }
        }
        var lines = ["open pull requests:"]
        for pr in prs {
            lines.append("  \(icon(pr.reviewState)) \(pr.repo)#\(pr.number): \(pr.title)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Keychain
    private func keychainSet(_ k: String, value: String) {
        guard let d = value.data(using: .utf8) else { return }
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: k]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q.merging([kSecValueData: d]) { $1 } as CFDictionary, nil)
    }
    private func keychainGet(_ k: String) -> String? {
        let q: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: k,
                                   kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne]
        var r: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &r) == errSecSuccess,
              let d = r as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    private func keychainDelete(_ k: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: k] as CFDictionary)
    }
}
