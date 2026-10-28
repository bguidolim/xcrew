# xcrew

**Apple's Xcode MCP, Sentry's MobileBuildMCP and Sosumi, set up to work together for iOS projects in Claude Code.**

[![CI](https://github.com/breferrari/xcrew/actions/workflows/ci.yml/badge.svg)](https://github.com/breferrari/xcrew/actions/workflows/ci.yml)
[![Canary](https://github.com/breferrari/xcrew/actions/workflows/canary.yml/badge.svg)](https://github.com/breferrari/xcrew/actions/workflows/canary.yml)
![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Xcode 27+](https://img.shields.io/badge/Xcode-27%2B-blue)
![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-orange)
[![MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Each of the three servers is good at different things, and on their own they overlap, misroute and trip over each other. xcrew installs all three, tells Claude which one to use for what, and fixes the failures you'd otherwise hit by hand:

- **Routing.** Every session in an Apple-platform project starts knowing which server builds, which previews, which knows the docs, and which tool never to touch.
- **Macro-plugin repair.** When Xcode rewrites a Swift macro plugin in place, macOS kills it and the build fails with *"produced malformed response"*. xcrew re-copies the plugin and retries the build before Claude sees the failure.
- **Build and test timing.** A live status line while a build or test runs, and a toast when it ends: `✓ build_sim · 1:12 (avg 1:05)`.
- **Project-file guard.** The Xcode MCP's `XcodeWrite` re-saves the whole `.pbxproj`; xcrew refuses it and points Claude at its own Write tool.
- **Setup and doctor.** `/xcrew:setup` writes MobileBuildMCP's per-project profiles from your schemes and installed simulators; `xcrew doctor` checks the Mac and the project and prints the fix for anything wrong.

## Quick start

You need macOS 26 or later, Xcode 27 or later, [Homebrew](https://brew.sh) and [Claude Code](https://claude.com/claude-code).

**As a Claude Code plugin**, from Claude Code:

```
/plugin marketplace add breferrari/xcrew
/plugin install xcrew@xcrew
```

Then once per Mac, in a terminal:

```sh
brew install getsentry/xcodebuildmcp/mobilebuildmcp
sudo xcrun mcp-server enable
```

Restart Claude Code in your project and run `/xcrew:setup`. The first call builds xcrew's small Swift CLI, about ten seconds, once per version.

**With [mcs](https://github.com/mcs-cli/mcs)**, which installs the Homebrew package and the plugin together and asks the setup questions:

```sh
mcs pack add breferrari/xcrew
mcs sync
```

Either way, the last step is approving Claude Code in Xcode's dialog the first time Claude calls the Xcode MCP. `xcrew doctor` tells you when anything is still missing:

```
ok    mobilebuildmcp/version           version 2.7.1
ok    mobilebuildmcp/no-legacy-binary  none
ok    mobilebuildmcp/project-config    .mobilebuildmcp/config.yaml
ok    mobilebuildmcp/simulators        iPhone 17
ok    xcode-mcp/headless-enabled       enabled
warn  xcode-mcp/claude-approved        not approved yet: have Claude call XcodeOpenWorkspace, then allow it in Xcode's dialog
ok    xcode-mcp/unsigned-agents-off    off
ok    xcode-mcp/macro-plugins          6 answer
```

## What you get

| Piece | What it does |
| --- | --- |
| MCP servers | MobileBuildMCP (started in your project, telemetry off), the Xcode MCP (`xcrun mcpbridge`), Sosumi |
| Session briefing | The routing rules in [`context/routing.md`](context/routing.md), plus what this project or Mac still lacks; silent outside Apple-platform projects |
| Mod | Macro-plugin repair with retry, build and test timing, the `XcodeWrite` guard |
| Hooks | The same repair after a failed Xcode MCP build, for sessions where mods don't run |
| Skills | `/xcrew:setup`, and the `xcrew` reference Claude loads when something fails |
| CLI | `xcrew setup`, `doctor`, `repair-macros`, `xcode-skills`; on Claude's `PATH` while the plugin is enabled |

`xcrew xcode-skills` copies the agent skills your Xcode ships (SwiftUI, accessibility, device interaction) into the project, and picks up new ones after each Xcode update.

## Which server does what

The short version Claude gets at session start:

| Job | Server | Why |
| --- | --- | --- |
| Build, test, coverage, simulators, UI automation, LLDB | MobileBuildMCP | Runs `xcodebuild` with its own DerivedData, so it never fights Xcode's; switchable profiles; test filtering |
| One file's compile errors, SwiftUI previews, code snippets, crash logs, physical devices | Xcode MCP | Uses Xcode's real build settings, which a plain language server can't read in an Xcode project |
| Apple documentation | Sosumi | Short results with each API's minimum OS version |
| Writing files | Claude's own tools | `XcodeWrite` rewrites the whole project file |

[docs/findings.md](docs/findings.md) has the evidence behind each choice, and what was tried and rejected.

## Configuration

- **Profiles.** `.mobilebuildmcp/config.yaml` holds a `unit` profile, plus `ui` and `app` when you name those schemes. Rerun `/xcrew:setup` or `xcrew setup --help` to change them. A config xcrew didn't write is left alone unless you pass `--force`, which keeps a backup.
- **Macro plugins named otherwise.** Set `XCREW_MACRO_PLUGINS=MyPlugin,OtherPlugin`. Set `XCREW_DERIVED_DATA` when Xcode's DerivedData isn't in its default place.
- **Already registered the servers yourself?** Claude Code prefers your own `xcode` and `MobileBuildMCP` entries over the plugin's. Remove yours (`claude mcp remove <name>`) to use xcrew's, or keep them: the hooks and the mod work with either.

## Troubleshooting

Run `xcrew doctor` first; every line that isn't `ok` names its fix. Beyond that:

| Symptom | Cause | Fix |
| --- | --- | --- |
| Every Xcode MCP call fails with "not approved" | Xcode asks once per agent | Have Claude call `XcodeOpenWorkspace`; allow it in Xcode's dialog |
| MobileBuildMCP has only simulator tools | No `.mobilebuildmcp/config.yaml` in the project | `/xcrew:setup`, then restart Claude Code |
| `No such module 'UIKit'` from SourceKit | Claude Code's language server can't read Xcode projects | Ignore it; the Xcode MCP's diagnostics are the real ones |
| A build keeps failing with "malformed response" after a repair | The plugin is broken, not just killed | Clean the build folder and rebuild |

## How it works

```
Claude Code ──┬── plugin: .mcp.json ─────────── MobileBuildMCP · Xcode MCP · Sosumi
              ├── plugin: hooks/hooks.json ──── SessionStart, PostToolUse(Failure) ─┐
              ├── plugin: mod (TypeScript) ──── tool.call: guard · timing · repair ─┤
              └── plugin: skills/ ───────────── setup · xcrew reference             │
                                                                                    ▼
                                         bin/xcrew ── builds once, then runs ── Swift CLI
                                                                                (setup, doctor,
mcs ── techpack.yaml ── brew + plugin + prompts ── mcs/configure.sh, mcs/checks ─▶ repair, hooks)
```

All logic lives in one dependency-free Swift package. The plugin, the hooks, the mod and mcs call that CLI, so there is one implementation, and `Tests/ManifestTests` fails when an install path drifts from it. [docs/architecture.md](docs/architecture.md) walks through the layout.

## Development

```sh
swift test                     # CLI, core, shim and manifest-parity tests
claude plugin test .           # the mod's tests, against Claude Code's own engine
claude plugin validate .
mcs pack validate .            # when mcs is installed
claude --plugin-dir .          # try your checkout in a session
```

[CONTRIBUTING.md](CONTRIBUTING.md) covers the conventions, and how to add a check, a command or a mod behaviour.

## Privacy

xcrew sends nothing anywhere: it has no telemetry, and it turns MobileBuildMCP's off. Sosumi is a third-party documentation service that receives your documentation searches; see [sosumi.ai](https://sosumi.ai).

## License

[MIT](LICENSE).
