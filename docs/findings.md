# Findings

What Xcrew's choices rest on. Measured in October 2026 on one Mac (macOS 26, Xcode 27.1, MobileBuildMCP 2.7.1) against a large modular Tuist app; versions move, so treat numbers as that snapshot. `xcrew doctor` checks the parts that can change under you.

## The two servers

| | Xcode MCP | MobileBuildMCP |
| --- | --- | --- |
| Ships with | Xcode 27 (`xcrun mcpbridge`) | Homebrew, from Sentry (formerly XcodeBuildMCP) |
| Builds through | Xcode itself, in Xcode's DerivedData | `xcodebuild`, in its own DerivedData |
| Knows | The open project: navigator, active scheme, real build settings | Whatever you point it at, through session-default profiles |
| Unique strengths | Per-file diagnostics, SwiftUI previews with variants, code snippets in a module, Organizer crash and performance logs, string catalogs, physical devices | Test filtering, coverage reports, simulator control and environment, UI automation by accessibility tree, LLDB |
| Settings | None of its own; Xcode decides | `.mobilebuildmcp/config.yaml`: tool groups, profiles, debugger backend |

They overlap on build, test and run. Xcrew sends those to MobileBuildMCP because its DerivedData never collides with Xcode's, its profiles survive restarts, and it filters tests. The Xcode MCP keeps what only it can do.

## Behaviours that shaped xcrew

- **The Xcode MCP works with Xcode closed.** After `sudo xcrun mcp-server enable`, the server runs headless. Each agent is approved once, through a dialog Xcode raises on that agent's first call; `xcrun mcp-server status` lists approved agents.
- **The Xcode MCP's file tools take project-navigator paths, not disk paths.** A disk path fails with "File not found in project structure".
- **`XcodeWrite` re-saves the whole project file.** Creating one file rewrote over a thousand lines of a generated `.pbxproj` in Xcode's newer format. Projects with synchronized folders, and generated projects, pick up files written to disk anyway, so the guard costs nothing.
- **Previews, snippets and diagnostics follow the active scheme.** "Active scheme does not build this file" means switching scheme, which also changes the person's Xcode window.
- **Macro plugins die after an in-place rewrite.** The kernel caches a Mach-O file's code signature and doesn't flush that cache when the file is rewritten in place, so the next launch is killed; Apple's guidance is to replace such a file rather than overwrite it ([Apple Developer Forums](https://developer.apple.com/forums/thread/130313)). Xcode does rewrite macro plugins in place when it rebuilds them, and the build then reports "produced malformed response". A copy of the same bytes, renamed over the original, runs: that is the whole repair, and probing a plugin means sending the compiler's own capability request. Observed repeatedly in a large modular app with several macro packages; it recurred after plugin rebuilds, which is why the repair is automatic. The same message also comes from other causes, such as a toolchain mismatch or stale prebuilt macros, which the repair doesn't address: it finds no dead plugin and changes nothing.
- **SourceKit can't read Xcode projects.** Claude Code's Swift language server reads settings only from a Swift package, a compilation database or a build server. Without a `Package.swift` it checks each file alone against the macOS SDK, so `import UIKit` and every first-party module show as errors. The Xcode MCP's `XcodeRefreshCodeIssuesInFile` uses the real settings.
- **The XcodeBuildMCP → MobileBuildMCP rename (2.7.1) has no fallback.** The binary, the `MOBILEBUILDMCP_*` variables and the config folder (`.mobilebuildmcp/`) all changed; an old `.xcodebuildmcp/config.yaml` is ignored silently, leaving only the simulator tools. An old binary on `PATH`, from Homebrew or npm, can shadow the new one.
- **MobileBuildMCP reads its config from its working directory**, so the plugin starts it in the project root.
- **`test_sim` takes no scheme argument**; the scheme comes from the session defaults, and `-only-testing:` goes in `extraArgs`.
- **MobileBuildMCP's command line resolves simulator names on the newest installed iOS only**; the MCP server doesn't have this limit.
- **LLDB `expr` needs `debuggerBackend: lldb-cli`**; the default backend handles attach, stacks and breakpoints.
- **Coverage tools need an absolute `.xcresult` path**; `~` isn't expanded.
- **The `mobilebuildmcp://doctor` resource reports Sentry as enabled regardless.** That line reads only a legacy variable; the environment section below it is accurate.
- **Sosumi beats `DocumentationSearch` for documentation**: short results with links, WWDC sessions, and each API's minimum OS version. `DocumentationSearch` matches the installed SDK and works offline.
- **`IDEAllowUnauthenticatedAgents`** lets any unsigned process drive Xcode's tools; leave it off.

## Tried and rejected

| Option | Why not |
| --- | --- |
| MobileBuildMCP's `incrementalBuildsEnabled` | Slower than plain rebuilds in testing, downloads and runs `xcodemake`, and writes a large `Makefile` into the project root |
| Building through the Xcode MCP by default | Shares and fights Xcode's DerivedData, and follows the person's active scheme |
| Python for Xcrew's logic | Apple's Python is 3.9 and contributors to an iOS tool write Swift; a cached Swift binary also starts faster (about 0.02 s against 0.05 s) |
| Swift scripts | Compiled on every run, about 0.65 s per call, too slow for hooks |
| A shell installer as a third install path | The plugin already installs without mcs, and a third path would drift |
| `swift-subprocess` | A package dependency means a network fetch on every user's first build |
