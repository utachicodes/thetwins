import AppKit
import Network
import Security

class GoogleAuth {
    static let shared = GoogleAuth()

    private enum Key {
        static let clientID = "GoogleClientID"
        static let clientSecret = "GoogleClientSecret"
        static let tokenExpiry = "GoogleTokenExpiry"
        static let accessToken = "GoogleAccessToken"
        static let refreshToken = "GoogleRefreshToken"
    }

    var clientID: String {
        get { UserDefaults.standard.string(forKey: Key.clientID) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.clientID) }
    }
    var clientSecret: String {
        get { UserDefaults.standard.string(forKey: Key.clientSecret) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Key.clientSecret) }
    }

    var hasCredentials: Bool { !clientID.isEmpty && !clientSecret.isEmpty }
    var isConnected: Bool { keychainGet(Key.refreshToken) != nil }

    private let scopes = [
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/calendar.readonly",
        "https://www.googleapis.com/auth/tasks.readonly"
    ].joined(separator: " ")

    private var listener: NWListener?
    private let callbackPort: UInt16 = 8735

    // MARK: - Auth Flow

    func signIn(completion: @escaping (Bool, String?) -> Void) {
        guard hasCredentials else { completion(false, "Enter Client ID and Secret first."); return }

        let redirectURI = "http://localhost:\(callbackPort)"
        guard let scopeEnc = scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let redirectEnc = redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://accounts.google.com/o/oauth2/v2/auth"
                + "?client_id=\(clientID)"
                + "&redirect_uri=\(redirectEnc)"
                + "&response_type=code"
                + "&scope=\(scopeEnc)"
                + "&access_type=offline"
                + "&prompt=consent") else {
            completion(false, "Could not build auth URL."); return
        }

        startCallbackServer(redirectURI: redirectURI, completion: completion)
        NSWorkspace.shared.open(url)
    }

    private func startCallbackServer(redirectURI: String, completion: @escaping (Bool, String?) -> Void) {
        listener?.cancel()

        guard let port = NWEndpoint.Port(rawValue: callbackPort) else {
            completion(false, "Could not open local server."); return
        }

        let l = try? NWListener(using: .tcp, on: port)
        listener = l

        // Time out after 5 minutes if the user never completes sign-in
        let timeout = DispatchWorkItem { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            DispatchQueue.main.async { completion(false, "Sign-in timed out.") }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 300, execute: timeout)

        l?.newConnectionHandler = { [weak self] conn in
            guard let self else { return }
            timeout.cancel()
            conn.start(queue: .global())
            conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                let code = data.flatMap { self.parseCode(from: $0) }
                let html: String
                if code != nil {
                    html = "<html><body style='font-family:sans-serif;padding:40px'><h2>Connected!</h2><p>You can close this tab and return to Lil Agents.</p></body></html>"
                } else {
                    html = "<html><body style='font-family:sans-serif;padding:40px'><h2>Sign-in cancelled.</h2></body></html>"
                }
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n\(html)"
                conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })

                self.listener?.cancel()
                self.listener = nil

                guard let code else {
                    DispatchQueue.main.async { completion(false, "Sign-in was cancelled.") }
                    return
                }
                self.exchangeCode(code, redirectURI: redirectURI, completion: completion)
            }
        }

        l?.start(queue: .global())
    }

    private func parseCode(from data: Data) -> String? {
        guard let request = String(data: data, encoding: .utf8),
              let firstLine = request.components(separatedBy: "\r\n").first else { return nil }
        // First line: "GET /?code=4/0A...&scope=... HTTP/1.1"
        guard let pathStart = firstLine.range(of: " ")?.upperBound,
              let pathEnd = firstLine.range(of: " ", range: pathStart..<firstLine.endIndex)?.lowerBound else { return nil }
        let path = String(firstLine[pathStart..<pathEnd])
        guard let components = URLComponents(string: "http://localhost\(path)"),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else { return nil }
        return code
    }

    private func exchangeCode(_ code: String, redirectURI: String, completion: @escaping (Bool, String?) -> Void) {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ].map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
         .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            guard let self, let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String,
                  let refresh = json["refresh_token"] as? String,
                  let expiresIn = json["expires_in"] as? TimeInterval else {
                DispatchQueue.main.async { completion(false, "Token exchange failed. Check your Client ID and Secret.") }
                return
            }
            self.keychainSet(Key.accessToken, value: access)
            self.keychainSet(Key.refreshToken, value: refresh)
            UserDefaults.standard.set(Date().addingTimeInterval(expiresIn - 60), forKey: Key.tokenExpiry)
            DispatchQueue.main.async { completion(true, nil) }
        }.resume()
    }

    // MARK: - Token Management

    func validToken(completion: @escaping (String?) -> Void) {
        if let token = keychainGet(Key.accessToken),
           let expiry = UserDefaults.standard.object(forKey: Key.tokenExpiry) as? Date,
           Date() < expiry {
            completion(token)
        } else {
            refreshAccessToken(completion: completion)
        }
    }

    private func refreshAccessToken(completion: @escaping (String?) -> Void) {
        guard let refresh = keychainGet(Key.refreshToken), hasCredentials else {
            completion(nil); return
        }
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "refresh_token=\(refresh)&client_id=\(clientID)&client_secret=\(clientSecret)&grant_type=refresh_token".data(using: .utf8)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? TimeInterval else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.keychainSet(Key.accessToken, value: access)
            UserDefaults.standard.set(Date().addingTimeInterval(expiresIn - 60), forKey: Key.tokenExpiry)
            DispatchQueue.main.async { completion(access) }
        }.resume()
    }

    func signOut() {
        keychainDelete(Key.accessToken)
        keychainDelete(Key.refreshToken)
        UserDefaults.standard.removeObject(forKey: Key.tokenExpiry)
    }

    // MARK: - Keychain

    private func keychainSet(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query.merging([kSecValueData: data]) { $1 } as CFDictionary, nil)
    }

    private func keychainGet(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword, kSecAttrAccount: key,
            kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func keychainDelete(_ key: String) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: key] as CFDictionary)
    }
}
