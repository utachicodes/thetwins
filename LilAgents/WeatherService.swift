import Foundation

class WeatherService {
    static func fetch(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://wttr.in/?format=%C,+%t,+feels+like+%f") else {
            completion(nil); return
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("curl/7.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let text = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                completion(nil); return
            }
            completion(text)
        }.resume()
    }
}
