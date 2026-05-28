# The Twins

**Boury** and **Buddy** — two AI companions that live on your macOS dock.

They walk back and forth above your dock, give you daily briefings, react to system events, and banter with each other. Click one to open their AI terminal. Right-click to send your clipboard.

---

## meet the twins

**Boury** is your personal assistant. Every morning she checks your Gmail, Google Calendar, and Google Tasks — then pops a bubble with your day at a glance. She monitors weather, tracks your schedule, and keeps your inbox under control.

**Buddy** is your tech and security radar. He scans the latest AI and software news, pulls actively exploited CVEs from CISA, monitors your GitHub PRs, checks your codebases for outdated packages, and flags cyber attacks and breaches from Hacker News — all before you've had your coffee.

---

## features

### AI terminal
- Click either twin to open a themed terminal popover
- Each twin has their own persona and system prompt baked in
- Voice input — tap the mic button and speak your message
- Slash commands: `/clear`, `/copy`, `/help`, `/history`, `/connect`, `/github`
- Right-click any twin → **Ask [Name] about clipboard** to instantly send copied text

### daily briefings
- **Boury** — weather, unread emails (subjects), today's calendar events, pending tasks
- **Buddy** — top AI/tech stories, actively exploited CVEs (CISA KEV feed), security & breach news, GitHub PR status, outdated npm/pip packages in your codebases
- Briefings fire automatically every morning at your chosen time (6am–12pm, pick from menu)
- Each briefing shows as a speech bubble, fires a macOS notification, and is logged to `/history`
- Type `/history` in either terminal to review the last 7 days of briefings

### integrations
- **Google** (Boury) — Gmail, Google Calendar, Google Tasks via OAuth 2.0. Setup: menu bar → Integrations → Connect Boury to Google, or type `/connect` in her terminal
- **GitHub** (Buddy) — monitors open PRs across your repos for review requests and CI status. Setup: menu bar → Integrations → Connect Buddy to GitHub, or type `/github` in his terminal

### system awareness
- **Low battery** — Boury pops a bubble + sends a macOS notification when battery hits 15%
- **Network lost / restored** — Buddy reacts instantly when your connection drops or comes back

### character banter
- Every 45–90 minutes the twins exchange a short line with each other in speech bubbles
- Only fires when both are idle and no AI session is running

### global shortcut
- `⌘⇧Space` from anywhere opens the next twin's terminal instantly
- Requires Accessibility permission (macOS will prompt on first use)

### AI providers
Switch providers per-character or globally from the menu bar:
- OpenAI Codex
- GitHub Copilot
- Google Gemini CLI
- OpenCode
- OpenClaw

### customisation
- Four visual themes: Midnight, Peach, Cloud, Moss
- Three character sizes: Large, Medium, Small
- Sound effects on AI completion (toggle in menu)
- Pin to a specific display (menu bar → Display)
- Auto-updates via Sparkle

---

## requirements

- macOS Sonoma 14.0+ (including Sequoia 15.x)
- Universal binary — Apple Silicon and Intel
- At least one supported AI CLI installed:
  - [OpenAI Codex](https://github.com/openai/codex) — `npm install -g @openai/codex`
  - [GitHub Copilot CLI](https://github.com/github/copilot-cli) — `brew install copilot-cli`
  - [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) — `npm install -g @google/gemini-cli`
  - [OpenCode](https://opencode.ai) — `curl -fsSL https://opencode.ai/install | bash`

---

## building

```
open the-twins.xcodeproj   # (or lil-agents.xcodeproj)
```

Hit `Cmd+R`. No additional build steps.

**Required frameworks** (add in Xcode → Target → General → Frameworks):
- `Speech.framework`
- `Network.framework`
- `UserNotifications.framework`

---

## privacy

The Twins run entirely on your Mac.

- **Local only.** Character animations are bundled videos. Dock positioning reads `com.apple.dock` defaults. Nothing else is read from your system without your action.
- **AI conversations.** Handled by whichever CLI you choose, running locally on your machine. The Twins do not intercept, log, or transmit chat content.
- **Google integration.** OAuth tokens are stored in your macOS Keychain. Email subjects, calendar events, and task titles are fetched at briefing time and displayed only to you — never stored remotely.
- **GitHub integration.** Your personal access token is stored in your macOS Keychain. PR data is fetched from the GitHub API and displayed locally.
- **Weather.** Fetched from wttr.in — a public, no-account weather service. No location data is stored.
- **Security feeds.** CVE data pulled from the public CISA Known Exploited Vulnerabilities feed. Hacker News stories fetched from the public Firebase API.
- **No analytics.** No accounts, no user database, no tracking.
- **Updates.** Sparkle sends your app version and macOS version to check for updates. Nothing else.

---

## license

MIT — see [LICENSE](LICENSE).
