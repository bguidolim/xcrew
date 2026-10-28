# Security

Xcrew runs on your Mac with your permissions: it starts MCP servers, runs Xcode's tools, copies macro-plugin binaries inside Xcode's DerivedData and writes `.mobilebuildmcp/` in your project. It sends nothing over the network itself.

Please report a vulnerability privately through [GitHub's security advisories](https://github.com/breferrari/xcrew/security/advisories/new) rather than an issue. Expect an answer within a week.

Xcrew also checks that Xcode's `IDEAllowUnauthenticatedAgents` is off: with it on, any unsigned process on the Mac can drive Xcode's tools.
