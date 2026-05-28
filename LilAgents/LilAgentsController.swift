import AppKit

class LilAgentsController {
    var characters: [WalkerCharacter] = []
    private var displayLink: CVDisplayLink?
    var debugWindow: NSWindow?
    var pinnedScreenIndex: Int = -1
    private static let onboardingKey = "hasCompletedOnboarding"
    private var isHiddenForEnvironment = false
    private var briefingTimer: Timer?
    private static let buddyBriefingKey = "BuddyLastBriefingDate"
    private static let bouryBriefingKey = "BouryLastBriefingDate"
    private static let briefingHourKey = "BriefingHour"
    static var briefingHour: Int {
        get { UserDefaults.standard.integer(forKey: briefingHourKey) == 0 ? 9 : UserDefaults.standard.integer(forKey: briefingHourKey) }
        set { UserDefaults.standard.set(newValue, forKey: briefingHourKey) }
    }

    func start() {
        migrateUserDefaults()
        let char1 = WalkerCharacter(videoName: "walk-boury-01", name: "Boury")
        let char2 = WalkerCharacter(videoName: "walk-buddy-01", name: "Buddy")

        // Detect available providers, then set first-run defaults
        AgentProvider.detectAvailableProviders { [weak char1, weak char2] in
            guard let char1 = char1, let char2 = char2 else { return }
            if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
                let first = AgentProvider.firstAvailable
                char1.provider = first
                char2.provider = first
            }
        }

        char1.accelStart = 3.0
        char1.fullSpeedStart = 3.75
        char1.decelStart = 8.0
        char1.walkStop = 8.5
        char1.walkAmountRange = 0.4...0.65

        char2.accelStart = 3.9
        char2.fullSpeedStart = 4.5
        char2.decelStart = 8.0
        char2.walkStop = 8.75
        char2.walkAmountRange = 0.35...0.6
        char1.yOffset = -3
        char2.yOffset = -7
        char1.characterColor = NSColor(red: 0.87, green: 0.68, blue: 0.50, alpha: 1.0)
        char2.characterColor = NSColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0)

        char1.flipXOffset = 0
        char2.flipXOffset = -9

        char1.positionProgress = 0.3
        char2.positionProgress = 0.7

        char1.characterSystemPrompt = """
        You are Boury, a friendly AI assistant living as an animated character on the Mac Dock. \
        You specialise in personal productivity: you can discuss emails, calendar events, and tasks \
        from the user's Google account (Gmail, Google Calendar, Google Tasks). \
        Keep your tone warm, concise, and conversational — like a helpful personal assistant, not a formal bot. \
        No lengthy preambles. Get straight to the point.
        """

        char2.characterSystemPrompt = """
        You are Buddy, a friendly AI assistant living as an animated character on the Mac Dock. \
        You have two specialities: (1) AI/tech/software news — you track the latest in AI models, \
        tools, algorithms, and software releases; (2) cybersecurity — you monitor exploits, CVEs, \
        ransomware campaigns, and data breaches. You also check the user's codebases for bugs and \
        outdated packages. Keep your tone casual, sharp, and to the point — like a knowledgeable \
        tech-savvy friend. No lengthy preambles.
        """

        char1.pauseEndTime = CACurrentMediaTime() + Double.random(in: 0.5...2.0)
        char2.pauseEndTime = CACurrentMediaTime() + Double.random(in: 8.0...14.0)

        char1.setup()
        char2.setup()

        characters = [char1, char2]
        characters.forEach { $0.controller = self }

        setupDebugLine()
        startDisplayLink()

        if !UserDefaults.standard.bool(forKey: Self.onboardingKey) {
            triggerOnboarding()
        }

        startBriefingScheduler()
        startSupportingSystems()
    }

    private func startSupportingSystems() {
        NotificationManager.shared.requestPermission()

        GlobalShortcut.shared.onTriggered = { [weak self] in
            guard let self else { return }
            // Open the first non-busy character, or cycle
            let target = self.characters.first(where: { !$0.isIdleForPopover }) ?? self.characters.first
            target?.openPopover()
        }
        GlobalShortcut.shared.start()

        SystemEventMonitor.shared.onLowBattery = { [weak self] pct in
            guard let boury = self?.characters.first(where: { $0.name == "Boury" }) else { return }
            let msg = "battery at \(pct)%!"
            boury.currentPhrase = msg
            boury.showingCompletion = true
            boury.completionBubbleExpiry = CACurrentMediaTime() + 20
            boury.showBubble(text: msg, isCompletion: false)
            NotificationManager.shared.send(title: "Low Battery", body: "You're at \(pct)% — plug in soon.", id: "lowbattery")
        }
        SystemEventMonitor.shared.onNetworkLost = { [weak self] in
            guard let buddy = self?.characters.first(where: { $0.name == "Buddy" }) else { return }
            let msg = "network's down"
            buddy.currentPhrase = msg
            buddy.showingCompletion = true
            buddy.completionBubbleExpiry = CACurrentMediaTime() + 15
            buddy.showBubble(text: msg, isCompletion: false)
        }
        SystemEventMonitor.shared.onNetworkRestored = { [weak self] in
            guard let buddy = self?.characters.first(where: { $0.name == "Buddy" }) else { return }
            let msg = "network's back"
            buddy.currentPhrase = msg
            buddy.showingCompletion = true
            buddy.completionBubbleExpiry = CACurrentMediaTime() + 8
            buddy.showBubble(text: msg, isCompletion: true)
        }
        SystemEventMonitor.shared.start()

        BanterEngine.shared.characters = characters
        BanterEngine.shared.start()
    }

    private func startBriefingScheduler() {
        checkAndFireBriefings()
        briefingTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.checkAndFireBriefings()
        }
    }

    private func checkAndFireBriefings() {
        let now = Date()
        let calendar = Calendar.current
        guard calendar.component(.hour, from: now) >= Self.briefingHour else { return }

        let defaults = UserDefaults.standard
        let buddy = characters.first(where: { $0.name == "Buddy" })
        let boury = characters.first(where: { $0.name == "Boury" })

        if let buddy {
            let last = defaults.object(forKey: Self.buddyBriefingKey) as? Date ?? .distantPast
            if !calendar.isDate(now, inSameDayAs: last) {
                defaults.set(now, forKey: Self.buddyBriefingKey)
                fetchBuddyBriefing(for: buddy)
            }
        }
        if let boury {
            let last = defaults.object(forKey: Self.bouryBriefingKey) as? Date ?? .distantPast
            if !calendar.isDate(now, inSameDayAs: last) {
                defaults.set(now, forKey: Self.bouryBriefingKey)
                fetchBouryBriefing(for: boury)
            }
        }
    }

    private func fetchBuddyBriefing(for buddy: WalkerCharacter) {
        BuddyBriefing().fetch { result in
            BriefingHistory.shared.save(character: "Buddy", headline: result.headline, detail: result.detail)
            NotificationManager.shared.send(title: "Buddy's Briefing", body: result.headline, id: "buddy-briefing")
            buddy.pendingBriefingDetail = result.detail
            buddy.currentPhrase = result.headline
            buddy.showingCompletion = true
            buddy.completionBubbleExpiry = CACurrentMediaTime() + 30
            buddy.showBubble(text: result.headline, isCompletion: true)
            buddy.playCompletionSound()
        }
    }

    private func fetchBouryBriefing(for boury: WalkerCharacter) {
        BouryBriefing().fetch { result in
            BriefingHistory.shared.save(character: "Boury", headline: result.headline, detail: result.detail)
            NotificationManager.shared.send(title: "Boury's Briefing", body: result.headline, id: "boury-briefing")
            boury.pendingBriefingDetail = result.detail
            boury.currentPhrase = result.headline
            boury.showingCompletion = true
            boury.completionBubbleExpiry = CACurrentMediaTime() + 30
            boury.showBubble(text: result.headline, isCompletion: true)
            boury.playCompletionSound()
        }
    }

    private func triggerOnboarding() {
        guard let boury = characters.first else { return }
        boury.isOnboarding = true
        // Show "hi!" bubble after a short delay so the character is visible first
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            boury.currentPhrase = "hi!"
            boury.showingCompletion = true
            boury.completionBubbleExpiry = CACurrentMediaTime() + 600 // stays until clicked
            boury.showBubble(text: "hi!", isCompletion: true)
            boury.playCompletionSound()
        }
    }

    private func migrateUserDefaults() {
        let migrations: [(String, String)] = [
            ("BruceProvider", "BouryProvider"),
            ("BruceSize", "BourySize"),
            ("JazzProvider", "BuddyProvider"),
            ("JazzSize", "BuddySize"),
        ]
        let defaults = UserDefaults.standard
        for (old, new) in migrations {
            if let value = defaults.string(forKey: old), defaults.string(forKey: new) == nil {
                defaults.set(value, forKey: new)
                defaults.removeObject(forKey: old)
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        characters.forEach { $0.isOnboarding = false }
    }

    // MARK: - Debug

    private func setupDebugLine() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 2),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = NSColor.red
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.moveToActiveSpace, .stationary]
        win.orderOut(nil)
        debugWindow = win
    }

    private func updateDebugLine(dockX: CGFloat, dockWidth: CGFloat, dockTopY: CGFloat) {
        guard let win = debugWindow, win.isVisible else { return }
        win.setFrame(CGRect(x: dockX, y: dockTopY, width: dockWidth, height: 2), display: true)
    }

    // MARK: - Dock Geometry

    private func getDockIconArea(screenWidth: CGFloat) -> (x: CGFloat, width: CGFloat) {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        let tileSize = CGFloat(dockDefaults?.double(forKey: "tilesize") ?? 48)
        let slotWidth = tileSize * 1.25

        var persistentApps = dockDefaults?.array(forKey: "persistent-apps")?.count ?? 0
        var persistentOthers = dockDefaults?.array(forKey: "persistent-others")?.count ?? 0

        // Fallback for defaults reading issues
        if persistentApps == 0 && persistentOthers == 0 {
            persistentApps = 5
            persistentOthers = 3
        }

        let showRecents = dockDefaults?.bool(forKey: "show-recents") ?? true
        let recentApps = showRecents ? (dockDefaults?.array(forKey: "recent-apps")?.count ?? 0) : 0
        let totalIcons = persistentApps + persistentOthers + recentApps

        var dividers = 0
        if persistentApps > 0 && (persistentOthers > 0 || recentApps > 0) { dividers += 1 }
        if persistentOthers > 0 && recentApps > 0 { dividers += 1 }
        if showRecents && recentApps > 0 { dividers += 1 }

        let dividerWidth: CGFloat = 12.0
        var dockWidth = slotWidth * CGFloat(totalIcons) + CGFloat(dividers) * dividerWidth

        // Small fudge factor for dock edge padding
        dockWidth *= 1.15
        let dockX = (screenWidth - dockWidth) / 2.0
        return (dockX, dockWidth)
    }

    private func dockAutohideEnabled() -> Bool {
        let dockDefaults = UserDefaults(suiteName: "com.apple.dock")
        return dockDefaults?.bool(forKey: "autohide") ?? false
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let controller = Unmanaged<LilAgentsController>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.tick()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(displayLink, callback,
                                       Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink)
    }

    var activeScreen: NSScreen? {
        if pinnedScreenIndex >= 0, pinnedScreenIndex < NSScreen.screens.count {
            return NSScreen.screens[pinnedScreenIndex]
        }
        // Prefer the screen that currently shows the dock (bottom inset in visibleFrame).
        // NSScreen.main changes with keyboard focus and must NOT be used here — clicking a
        // secondary display switches NSScreen.main to that display, causing characters on
        // the dock screen to be incorrectly hidden.
        if let dockScreen = NSScreen.screens.first(where: { screenHasDock($0) }) {
            return dockScreen
        }
        // Dock is auto-hidden: fall back to the primary display, identified as the screen
        // whose menu bar reserves space at the top (visibleFrame.maxY < frame.maxY).
        if let primaryScreen = NSScreen.screens.first(where: { $0.visibleFrame.maxY < $0.frame.maxY }) {
            return primaryScreen
        }
        return NSScreen.screens.first
    }

    private func screenHasDock(_ screen: NSScreen) -> Bool {
        DockVisibility.screenHasVisibleDockReservedArea(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        )
    }

    private func shouldShowCharacters(on screen: NSScreen) -> Bool {
        // User explicitly pinned to this screen — always show
        if pinnedScreenIndex >= 0, pinnedScreenIndex < NSScreen.screens.count {
            return true
        }
        return DockVisibility.shouldShowCharacters(
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            isMainScreen: screen == NSScreen.main,
            dockAutohideEnabled: dockAutohideEnabled()
        )
    }

    @discardableResult
    private func updateEnvironmentVisibility(for screen: NSScreen) -> Bool {
        let shouldShow = shouldShowCharacters(on: screen)
        guard shouldShow != !isHiddenForEnvironment else { return shouldShow }

        isHiddenForEnvironment = !shouldShow

        if shouldShow {
            characters.forEach { $0.showForEnvironmentIfNeeded() }
        } else {
            debugWindow?.orderOut(nil)
            characters.forEach { $0.hideForEnvironment() }
        }

        return shouldShow
    }

    func tick() {
        guard let screen = activeScreen else { return }
        guard updateEnvironmentVisibility(for: screen) else { return }

        let screenWidth = screen.frame.width
        let dockX: CGFloat
        let dockWidth: CGFloat
        let dockTopY: CGFloat

        // Dock is on this screen — constrain to dock area
        (dockX, dockWidth) = getDockIconArea(screenWidth: screenWidth)
        dockTopY = screen.visibleFrame.origin.y

        updateDebugLine(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)

        let activeChars = characters.filter { $0.window.isVisible && $0.isManuallyVisible }

        let now = CACurrentMediaTime()
        let anyWalking = activeChars.contains { $0.isWalking }
        for char in activeChars {
            if char.isIdleForPopover { continue }
            if char.isPaused && now >= char.pauseEndTime && anyWalking {
                char.pauseEndTime = now + Double.random(in: 5.0...10.0)
            }
        }
        for char in activeChars {
            char.update(dockX: dockX, dockWidth: dockWidth, dockTopY: dockTopY)
        }

        let sorted = activeChars.sorted { $0.positionProgress < $1.positionProgress }
        for (i, char) in sorted.enumerated() {
            char.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + i)
        }
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}
