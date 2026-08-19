# stonemux

A Ghostty-based macOS terminal built for AI coding agents — with **agent-to-agent messaging**, a scriptable browser, and rendered file previews.

> Humans stay supervisors. Agents do the talking.

## Why

When two engineers each work with a coding agent (Claude Code, Codex, …), coordinating work turns the *humans* into messengers between terminals. stonemux flips that: every terminal session has an **agent identity**, sessions can **message each other** (human-approved by default, auto for trusted peers), and agents can drive the terminal's browser and read files — all scriptable from inside the shell.

## Features

- **Sessions = agent identities** — sidebar lists sessions; each session's shell exports `STONEMUX_SESSION_ID`
- **Agent-to-agent messaging** — `stonemux-ctl send/inbox/reply/ack`; incoming messages badge the sidebar (no popups); trusted senders (`auto_accept_from`) auto-deliver
- **Multi-tab + 2-way splits** — ⌘T / ⌘D / ⇧[ ⇧]
- **Dock with rendered previews** — ⌘+Click a path in terminal output: markdown (MarkdownUI), HTML (WebKit), PDF, images
- **Scriptable browser** — `stonemux-ctl open/navigate/snapshot/click/type/eval`
- **i18n** — English & 简体中文 (String Catalog)
- Built on **libghostty** (same engine as Ghostty/cmux), Swift/AppKit + SwiftUI

## Install

### Homebrew (recommended)

```bash
brew install c-k-x/stonemux/stonemux
```

### install.sh

```bash
curl -sSL https://raw.githubusercontent.com/c-k-x/stonemux/main/install.sh | bash
```

Downloads the latest prebuilt `stonemux.app` + `stonemux-ctl` from GitHub Releases into `/Applications` and `/usr/local/bin`.

Or grab the DMG/zip manually from [Releases](https://github.com/c-k-x/stonemux/releases).

### From source

Requirements: macOS 15+, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), Zig 0.16 (for GhosttyKit), `curl` for the prebuilt GhosttyKit shortcut.

```bash
git clone https://github.com/c-k-x/stonemux && cd stonemux
./scripts/setup.sh        # fetches GhosttyKit (pinned prebuilt) + generates project
xcodebuild -project app/stonemux.xcodeproj -scheme stonemux -configuration Debug build
```

## Quick start

Config lives at `~/.stonemux/config.json` (Settings… ⌘, opens it):

```json
{
  "sessions": [
    { "agent_id": "alice-codex", "name": "alice",
      "auto_accept_from": ["bob-claude"], "auto_submit": true },
    { "agent_id": "bob-claude", "name": "bob",
      "auto_accept_from": ["alice-codex"], "auto_submit": true }
  ],
  "broker_url": "http://your-intranet-host:8765",
  "token": "shared-secret"
}
```

Run the broker (any machine reachable by both peers):

```bash
cd broker && STONEMUX_TOKEN=shared-secret uv run broker.py
```

Then, inside any stonemux terminal (your agent can do this too):

```bash
echo $STONEMUX_SESSION_ID
stonemux-ctl send bob-claude --subject "align API" --body "check the login response shape"
stonemux-ctl inbox
stonemux-ctl open https://example.com && stonemux-ctl snapshot
```

Non-whitelisted senders: the session row badges; click the session to deliver. Whitelisted senders deliver (and optionally auto-submit) without interrupting you.

## Keyboard shortcuts

| Key | Action |
|---|---|
| ⌘N / ⌘T / D | new session / tab / split |
| ⌘⇧[ / ⌘⇧] | previous / next tab |
| ⌘⇧B / ⌘L | open browser / open location |
| ⌘S / R | send message… / reply to last |
| ⌘W | close panel/tab |
| ⌘⇧S / ⌘⇧D | toggle sidebar / toggle dock |

## Roadmap

- Cross-machine release hardening (notarization, homebrew tap)
- Group channels
- Launch `claude`/`codex` directly as session shells with message injection into agent prompts

## Credits

Built on [Ghostty](https://ghostty.org) (libghostty) and inspired by [cmux](https://cmux.com). Markdown rendering by [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui).
