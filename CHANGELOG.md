# Changelog

## 0.1.0 — unreleased

- Plugin with MobileBuildMCP, the Xcode MCP and Sosumi; a session briefing with the routing rules.
- Mod: macro-plugin repair with retry, build and test timing, the `XcodeWrite` guard.
- Swift CLI: `setup`, `doctor`, `repair-macros`, `xcode-skills`, and the hook entry points.
- mcs techpack installing the plugin, MobileBuildMCP and the per-project setup.
- The status line names the scheme and simulator a build or test run uses.
- A build or test run of a minute or more also sends its result as a notification.
- The build and test toast says what failed: the first compile error with its file and line, or how many tests failed and the first one. Failed Xcode MCP builds and test runs now count as failures; the server reports them as normal results.
- The doctor names projects still generated with Tuist's pre-4.203 in-place macro copy phase, and the repair message gives that cause and its fix.
- The macro-plugin repair hook runs only when a build fails with the plugin-kill message, and the doctor skips projects with no macro plugins.
- The `XcodeWrite` guard applies only to generated projects; `xcode-skills` keeps a project's own skills of the same name unless `--force`; setup keeps a managed config that was edited by hand; the README installs per project.
- Macro-plugin repair also covers the indexer's build and Swift packages opened directly, and labels the indexer's copies.
- Setup keeps `.mobilebuildmcp/` out of git; the doctor warns when the config points at a workspace that moved; `xcrew --version`; the CLI cache keeps only the current build.
