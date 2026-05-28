# The Twins

![The Twins](hero-thumbnail.png)

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Apple%20Silicon%20%7C%20Intel-silver?style=flat-square&logo=apple)]()
[![GitHub stars](https://img.shields.io/github/stars/utachicodes/thetwins?style=flat-square&color=yellow)](https://github.com/utachicodes/thetwins/stargazers)
[![Author](https://img.shields.io/badge/by-utachicodes-black?style=flat-square)](https://github.com/utachicodes)

**Boury** and **Buddy** — two AI companions that live on your macOS dock.

They walk back and forth above your dock, brief you every morning, react to system events, and banter with each other. Click one to open their AI terminal. Right-click to send your clipboard straight to them.

---

## meet the twins

**Boury** is your personal assistant. Every morning she checks your Gmail, Google Calendar, and Google Tasks — then pops a bubble with your day at a glance. She tracks weather, your schedule, and keeps your inbox under control.

**Buddy** is your tech and security radar. He scans the latest AI and software news, pulls actively exploited CVEs from CISA, monitors your GitHub PRs, checks your codebases for outdated packages, and flags breaches and cyber attacks — all before you've had your coffee.

---

## features

### AI terminal
- Click either twin to open a themed terminal popover
- Each twin has their own persona and role baked in at the session level
- **Voice input** — tap the mic button and speak your message
- **Right-click** any twin → *Ask [Name] about clipboard* to instantly send copied text
- **Global shortcut** — `⌘⇧Space` from anywhere opens the next twin's terminal
- Slash commands: `/clear` `/copy` `/help` `/history` `/connect` `/github`

### daily briefings
| Twin | What she/he checks |
|------|-------------------|
| **Boury** | Weather · Unread emails (subjects) · Today's calendar events · Pending tasks |
| **Buddy** | AI & tech news · Actively exploited CVEs (CISA KEV) · Security & breach news · GitHub PR status · Outdated npm/pip packages |

- Briefings fire automatically at your chosen time (6 am – 12 pm, set in menu bar)
- Each briefing shows as a speech bubble and fires a **macOS notification**
- All briefings are logged — type `/history` in any terminal to review the last 7 days

### integrations
- **Google** (Boury) — Gmail, Google Calendar, Google Tasks via OAuth 2.0  
  → Menu bar › Integrations › Connect Boury to Google *or* type `/connect` in her terminal
- **GitHub** (Buddy) — monitors open PRs across your repos for reviews and CI status  
  → Menu bar › Integrations › Connect Buddy to GitHub *or* type `/github` in his terminal

### system awareness
- 🔋 **Low battery** — Boury pops a bubble + notification when battery hits 15%
- 🌐 **Network lost / restored** — Buddy reacts the moment your connection drops or comes back

### character banter
Every 45–90 minutes the twins exchange a short line with each other in speech bubbles — only when both are idle and no AI session is active.

### customisation
- **4 visual themes** — Midnight · Peach · Cloud · Moss
- **3 character sizes** — Large · Medium · Small
- **Briefing time** — pick your morning hour from the menu bar
- **Display pinning** — pin the twins to any connected monitor
- **Sound effects** — toggle completion sounds from the menu bar
- **Auto-updates** via Sparkle

### AI providers
Switch per-character from the popover title bar, or globally from the menu bar:

[![Codex](https://img.shields.io/badge/OpenAI-Codex-412991?style=flat-square&logo=openai)](https://github.com/openai/codex)
[![Copilot](https://img.shields.io/badge/GitHub-Copilot-black?style=flat-square&logo=github)](https://github.com/features/copilot)
[![Gemini](https://img.shields.io/badge/Google-Gemini-4285F4?style=flat-square&logo=google)](https://github.com/google-gemini/gemini-cli)
[![OpenCode](https://img.shields.io/badge/OpenCode-AI-green?style=flat-square)](https://opencode.ai)

---

## requirements

- **macOS Sonoma 14.0+** (including Sequoia 15.x)
- **Universal binary** — Apple Silicon and Intel
- At least one supported AI CLI:

| Provider | Install |
|----------|---------|
| OpenAI Codex | `npm install -g @openai/codex` |
| GitHub Copilot CLI | `brew install copilot-cli` |
| Google Gemini CLI | `npm install -g @google/gemini-cli` |
| OpenCode | `curl -fsSL https://opencode.ai/install \| bash` |

---

## building

```bash
# open in Xcode
open lil-agents.xcodeproj
```

Press `Cmd+R`. No additional build steps required.

**Required frameworks** (Xcode → Target → General → Frameworks, Libraries, and Embedded Content):

| Framework | Used for |
|-----------|----------|
| `Speech.framework` | Voice input |
| `Network.framework` | Google OAuth callback server · Network monitoring |
| `UserNotifications.framework` | Morning briefing notifications |

---

## privacy

The Twins run entirely on your Mac.

| What | How it's handled |
|------|-----------------|
| AI conversations | Handled by your chosen CLI, running locally. The Twins never see the content. |
| Google data | OAuth tokens stored in your macOS Keychain. Email subjects, events, and tasks are fetched at briefing time and shown only to you — never stored remotely. |
| GitHub data | Personal access token stored in your macOS Keychain. PR data fetched from GitHub API and displayed locally. |
| Weather | Fetched from [wttr.in](https://wttr.in) — a public, no-account service. No location data stored. |
| Security feeds | CVEs from the public [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) feed. News from the public Hacker News API. |
| Analytics | None. No accounts, no user database, no tracking. |
| Updates | Sparkle sends your app version and macOS version. Nothing else. |

---

## license

MIT © 2026 [Abdoullah Al Jersi](https://github.com/utachicodes)

See [LICENSE](LICENSE) for full terms.
