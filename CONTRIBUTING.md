# Contributing

Thanks for helping. Xcrew is small on purpose: one Swift package does the work, and every other file is a thin way to reach it.

## Set up

macOS 26 or later with Xcode 27 or later, and Claude Code.

```sh
git clone https://github.com/breferrari/xcrew && cd xcrew
swift test
claude plugin test .
claude --plugin-dir .   # try your checkout in a real session
```

## How changes are made

- **Test first.** Write the test for the behaviour you're adding, watch it fail for the reason you expect, then write the code that passes it. Pull requests say which tests were seen failing first.
- **Keep install paths in step.** The plugin and the mcs techpack name the same hooks, checks and setup questions as the Swift code; `Tests/ManifestTests` fails when they drift, so a red parity test usually means a second file to update.
- **Prefer discovering to hard-coding.** If a value can change with a new Xcode, simulator lineup or server release, read it at runtime.
- **No dependencies, no unsafe code.** See [CLAUDE.md](CLAUDE.md) for the full conventions; they apply to people as much as to Claude.

[docs/architecture.md](docs/architecture.md) shows where things live and how to add a check, a command, a setup question or a mod behaviour.

## Reporting a problem

Open an issue with the output of `xcrew doctor` in the affected project and your versions. Security issues go through [SECURITY.md](SECURITY.md) instead.
