import Foundation
import QuartzCore

class BanterEngine {
    static let shared = BanterEngine()
    var characters: [WalkerCharacter] = []
    private var timer: Timer?

    // (Buddy says, Boury replies)
    private let exchanges: [(String, String)] = [
        ("seen any CVEs today?", "a few. patch your stuff"),
        ("busy day?", "your calendar says yes"),
        ("any AI news?", "always. it never stops"),
        ("how's the code?", "could use a review"),
        ("emails piling up?", "you have no idea"),
        ("GPT drop something new?", "probably. they always do"),
        ("ransomware trending?", "unfortunately, yes"),
        ("tasks done?", "...some of them"),
        ("anything on GitHub?", "checking your PRs now"),
        ("what's the weather like?", "just checked — you'll live"),
        ("I'm bored", "same. let's walk"),
        ("all good?", "so far so good"),
        ("zero day?", "not today hopefully"),
        ("inbox zero?", "in your dreams"),
        ("build pass?", "fingers crossed"),
    ]

    func start() {
        scheduleNext()
    }

    private func scheduleNext() {
        // Fire every 45–90 minutes
        let delay = Double.random(in: 2700...5400)
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.fire()
            self?.scheduleNext()
        }
    }

    private func fire() {
        let buddy = characters.first(where: { $0.name == "Buddy" })
        let boury = characters.first(where: { $0.name == "Boury" })
        guard let buddy, let boury,
              !buddy.isIdleForPopover, !boury.isIdleForPopover,
              !buddy.isAgentBusy, !boury.isAgentBusy else { return }

        let (buddyLine, bouryLine) = exchanges.randomElement() ?? ("hey", "hey")

        let now = CACurrentMediaTime()
        buddy.currentPhrase = buddyLine
        buddy.showingCompletion = true
        buddy.completionBubbleExpiry = now + 6
        buddy.showBubble(text: buddyLine, isCompletion: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let now = CACurrentMediaTime()
            boury.currentPhrase = bouryLine
            boury.showingCompletion = true
            boury.completionBubbleExpiry = now + 5
            boury.showBubble(text: bouryLine, isCompletion: false)
        }
    }
}
