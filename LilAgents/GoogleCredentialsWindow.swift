import AppKit

class GoogleCredentialsWindow: NSWindowController {
    static func show(anchor: NSWindow? = nil) {
        let wc = GoogleCredentialsWindow(anchor: nil)
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        wc.window?.makeKeyAndOrderFront(nil)
        // Retain until closed
        objc_setAssociatedObject(NSApp, Unmanaged.passUnretained(wc).toOpaque(), wc, .OBJC_ASSOCIATION_RETAIN)
    }

    private let clientIDField = NSTextField()
    private let clientSecretField = NSSecureTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let connectBtn = NSButton(title: "Connect with Google", target: nil, action: nil)
    private let anchor: NSWindow?

    init(anchor: NSWindow?) {
        self.anchor = anchor
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "Connect Boury to Google"
        w.center()
        super.init(window: w)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let w = window else { return }
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 360))

        let instructions = NSTextField(wrappingLabelWithString: """
        Boury can check your Gmail, Google Calendar, and Tasks daily.
        You need a Google Cloud OAuth 2.0 credential (free):

          1. Go to console.cloud.google.com → create a project
          2. APIs & Services → Enable: Gmail API, Calendar API, Tasks API
          3. APIs & Services → Credentials → Create OAuth Client ID
          4. Application type: Desktop app — copy the ID and Secret below
        """)
        instructions.font = NSFont.systemFont(ofSize: 12)
        instructions.frame = NSRect(x: 20, y: 210, width: 460, height: 130)
        v.addSubview(instructions)

        func label(_ s: String, x: CGFloat, y: CGFloat) -> NSTextField {
            let f = NSTextField(labelWithString: s)
            f.frame = NSRect(x: x, y: y, width: 100, height: 20)
            f.alignment = .right
            return f
        }

        v.addSubview(label("Client ID:", x: 20, y: 182))
        clientIDField.placeholderString = "xxxxxx.apps.googleusercontent.com"
        clientIDField.stringValue = GoogleAuth.shared.clientID
        clientIDField.frame = NSRect(x: 128, y: 179, width: 352, height: 24)
        v.addSubview(clientIDField)

        v.addSubview(label("Client Secret:", x: 20, y: 148))
        clientSecretField.placeholderString = "GOCSPX-…"
        clientSecretField.stringValue = GoogleAuth.shared.clientSecret
        clientSecretField.frame = NSRect(x: 128, y: 145, width: 352, height: 24)
        v.addSubview(clientSecretField)

        statusLabel.frame = NSRect(x: 20, y: 108, width: 460, height: 30)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        v.addSubview(statusLabel)

        if GoogleAuth.shared.isConnected {
            statusLabel.textColor = .systemGreen
            statusLabel.stringValue = "Connected! Boury is already linked to your Google account."
        }

        connectBtn.frame = NSRect(x: 20, y: 60, width: 220, height: 32)
        connectBtn.bezelStyle = .rounded
        connectBtn.target = self
        connectBtn.action = #selector(connect)
        v.addSubview(connectBtn)

        if GoogleAuth.shared.isConnected {
            let disconnectBtn = NSButton(title: "Disconnect", target: self, action: #selector(disconnect))
            disconnectBtn.frame = NSRect(x: 252, y: 60, width: 120, height: 32)
            disconnectBtn.bezelStyle = .rounded
            v.addSubview(disconnectBtn)
        }

        let cancelBtn = NSButton(title: "Done", target: self, action: #selector(done))
        cancelBtn.frame = NSRect(x: 390, y: 60, width: 90, height: 32)
        cancelBtn.bezelStyle = .rounded
        v.addSubview(cancelBtn)

        w.contentView = v
    }

    @objc private func connect() {
        let id = clientIDField.stringValue.trimmingCharacters(in: .whitespaces)
        let secret = clientSecretField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !secret.isEmpty else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "Please fill in both Client ID and Secret."
            return
        }
        GoogleAuth.shared.clientID = id
        GoogleAuth.shared.clientSecret = secret
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Opening Google sign-in in your browser…"
        connectBtn.isEnabled = false

        GoogleAuth.shared.signIn { [weak self] ok, error in
            guard let self else { return }
            self.connectBtn.isEnabled = true
            if ok {
                self.statusLabel.textColor = .systemGreen
                self.statusLabel.stringValue = "Connected! Boury will brief you every morning."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.close() }
            } else {
                self.statusLabel.textColor = .systemRed
                self.statusLabel.stringValue = error ?? "Sign-in failed. Check your credentials."
            }
        }
    }

    @objc private func disconnect() {
        GoogleAuth.shared.signOut()
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Disconnected."
    }

    @objc private func done() {
        close()
    }

    override func close() {
        super.close()
        objc_setAssociatedObject(NSApp, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
