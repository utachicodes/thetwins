import Foundation

class BouryBriefing {
    struct Result {
        let headline: String
        let detail: String
    }

    func fetch(completion: @escaping (Result) -> Void) {
        GoogleAuth.shared.validToken { token in
            guard let token else {
                completion(Result(
                    headline: "connect Google",
                    detail: "type /connect in my terminal to link your Google account\n(Gmail, Calendar, and Tasks)"
                ))
                return
            }

            let group = DispatchGroup()
            var emailHeadline = ""; var emailDetail = ""
            var calHeadline = "";   var calDetail = ""
            var taskHeadline = "";  var taskDetail = ""
            var weather: String?

            group.enter()
            self.fetchEmails(token: token) { h, d in emailHeadline = h; emailDetail = d; group.leave() }

            group.enter()
            self.fetchCalendar(token: token) { h, d in calHeadline = h; calDetail = d; group.leave() }

            group.enter()
            self.fetchTasks(token: token) { h, d in taskHeadline = h; taskDetail = d; group.leave() }

            group.enter()
            WeatherService.fetch { w in weather = w; group.leave() }

            group.notify(queue: .main) {
                let parts = [emailHeadline, calHeadline, taskHeadline].filter { !$0.isEmpty }
                var headlineParts = parts.isEmpty ? ["all clear!"] : parts
                if let w = weather { headlineParts.insert(w, at: 0) }
                let headline = headlineParts.joined(separator: " · ")

                var sections: [String] = []
                if let w = weather { sections.append("weather: \(w)") }
                if !emailDetail.isEmpty { sections.append(emailDetail) }
                if !calDetail.isEmpty { sections.append(calDetail) }
                if !taskDetail.isEmpty { sections.append(taskDetail) }
                let detail = sections.isEmpty ? "inbox zero — nothing on the calendar!" : sections.joined(separator: "\n\n")
                completion(Result(headline: headline, detail: detail))
            }
        }
    }

    // MARK: - Gmail

    private func fetchEmails(token: String, completion: @escaping (String, String) -> Void) {
        var req = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=is:unread&maxResults=5")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion("", ""); return
            }
            let count = json["resultSizeEstimate"] as? Int ?? 0
            let messages = json["messages"] as? [[String: Any]] ?? []
            guard count > 0 else { completion("", ""); return }

            let group = DispatchGroup()
            var subjects: [String] = []
            let lock = NSLock()

            for msg in messages.prefix(5) {
                guard let id = msg["id"] as? String else { continue }
                group.enter()
                var r = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=metadata&metadataHeaders=Subject")!)
                r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: r) { data, _, _ in
                    defer { group.leave() }
                    guard let data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let payload = json["payload"] as? [String: Any],
                          let headers = payload["headers"] as? [[String: Any]],
                          let sub = headers.first(where: { $0["name"] as? String == "Subject" })?["value"] as? String
                    else { return }
                    lock.lock(); subjects.append(sub); lock.unlock()
                }.resume()
            }

            group.notify(queue: .global()) {
                let headline = "\(count) unread email\(count == 1 ? "" : "s")"
                var detail = "unread emails:"
                subjects.forEach { detail += "\n  \u{2022} \($0)" }
                if count > 5 { detail += "\n  \u{2022} … and \(count - 5) more" }
                completion(headline, detail)
            }
        }.resume()
    }

    // MARK: - Calendar

    private func fetchCalendar(token: String, completion: @escaping (String, String) -> Void) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        let fmt = ISO8601DateFormatter()

        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events"
            + "?timeMin=\(fmt.string(from: start))"
            + "&timeMax=\(fmt.string(from: end))"
            + "&singleEvents=true&orderBy=startTime") else {
            completion("", ""); return
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                completion("", ""); return
            }
            let titles = items.compactMap { $0["summary"] as? String }
            guard !titles.isEmpty else { completion("", ""); return }
            let headline = "\(titles.count) event\(titles.count == 1 ? "" : "s") today"
            var detail = "today's calendar:"
            titles.forEach { detail += "\n  \u{2022} \($0)" }
            completion(headline, detail)
        }.resume()
    }

    // MARK: - Tasks

    private func fetchTasks(token: String, completion: @escaping (String, String) -> Void) {
        var req = URLRequest(url: URL(string: "https://tasks.googleapis.com/tasks/v1/users/@me/lists?maxResults=1")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lists = json["items"] as? [[String: Any]],
                  let listID = lists.first?["id"] as? String else {
                completion("", ""); return
            }
            self.fetchTaskItems(listID: listID, token: token, completion: completion)
        }.resume()
    }

    private func fetchTaskItems(listID: String, token: String, completion: @escaping (String, String) -> Void) {
        var req = URLRequest(url: URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listID)/tasks?showCompleted=false&maxResults=10")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                completion("", ""); return
            }
            let titles = items.compactMap { $0["title"] as? String }.filter { !$0.isEmpty }
            guard !titles.isEmpty else { completion("", ""); return }
            let headline = "\(titles.count) task\(titles.count == 1 ? "" : "s") pending"
            var detail = "pending tasks:"
            titles.prefix(8).forEach { detail += "\n  \u{2022} \($0)" }
            completion(headline, detail)
        }.resume()
    }
}
