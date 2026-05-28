import AppKit

class GitHubSetupWindow: NSWindowController {
    static func show() {
        let wc = GitHubSetupWindow()
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        wc.window?.makeKeyAndOrderFront(nil)
        objc_setAssociatedObject(NSApp, Unmanaged.passUnretained(wc).toOpaque(), wc, .OBJC_ASSOCIATION_RETAIN)
    }

    private let tokenField = NSSecureTextField()
    private let reposField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")

    convenience init() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 290),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        w.title = "Connect Buddy to GitHub"
        w.center()
        self.init(window: w)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let w = window else { return }
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 290))

        let info = NSTextField(wrappingLabelWithString: """
        Buddy monitors your GitHub PRs for review requests and CI failures.

          1. Go to github.com → Settings → Developer settings → Personal access tokens
          2. Generate a token (classic) with repo scope
          3. Paste it below, and list repos as "owner/repo" (comma-separated)
        """)
        info.font = NSFont.systemFont(ofSize: 12)
        info.frame = NSRect(x: 20, y: 195, width: 460, height: 90)
        v.addSubview(info)

        func lbl(_ s: String, y: CGFloat) -> NSTextField {
            let f = NSTextField(labelWithString: s)
            f.frame = NSRect(x: 20, y: y, width: 90, height: 20)
            f.alignment = .right; return f
        }

        v.addSubview(lbl("Token:", y: 170))
        tokenField.placeholderString = "ghp_xxxxxxxxxxxx"
        tokenField.stringValue = GitHubMonitor.shared.token
        tokenField.frame = NSRect(x: 118, y: 167, width: 362, height: 24)
        v.addSubview(tokenField)

        v.addSubview(lbl("Repos:", y: 138))
        reposField.placeholderString = "owner/repo1, owner/repo2"
        reposField.stringValue = GitHubMonitor.shared.repos.joined(separator: ", ")
        reposField.frame = NSRect(x: 118, y: 135, width: 362, height: 24)
        v.addSubview(reposField)

        statusLabel.frame = NSRect(x: 20, y: 105, width: 460, height: 20)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        if GitHubMonitor.shared.isConfigured {
            statusLabel.textColor = .systemGreen
            statusLabel.stringValue = "Connected — \(GitHubMonitor.shared.repos.count) repo(s) monitored."
        }
        v.addSubview(statusLabel)

        let save = NSButton(title: "Save & Test", target: self, action: #selector(saveAndTest))
        save.frame = NSRect(x: 20, y: 20, width: 140, height: 32); save.bezelStyle = .rounded
        v.addSubview(save)

        let done = NSButton(title: "Done", target: self, action: #selector(done))
        done.frame = NSRect(x: 390, y: 20, width: 90, height: 32); done.bezelStyle = .rounded
        v.addSubview(done)

        w.contentView = v
    }

    @objc private func saveAndTest() {
        let t = tokenField.stringValue.trimmingCharacters(in: .whitespaces)
        let repos = reposField.stringValue
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("/") }
        guard !t.isEmpty, !repos.isEmpty else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = "Please enter a token and at least one repo."
            return
        }
        GitHubMonitor.shared.token = t
        GitHubMonitor.shared.repos = repos
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Testing connection…"
        GitHubMonitor.shared.check { [weak self] prs in
            self?.statusLabel.textColor = .systemGreen
            self?.statusLabel.stringValue = "Connected! \(prs.count) open PR(s) found."
        }
    }

    @objc private func done() { close() }

    override func close() {
        super.close()
        objc_setAssociatedObject(NSApp, Unmanaged.passUnretained(self).toOpaque(), nil, .OBJC_ASSOCIATION_RETAIN)
    }
}
