import Foundation
import Testing
@testable import XcrewCore
import XcrewTestSupport

/// Uses real compiled binaries: the probe's framing and the Mach-O check are what break silently.
@Suite struct MacroPluginTests {
    let project = Project.temporary(containing: ["App.xcworkspace"])
    var products: URL {
        project.root.appending(path: "home/Library/Developer/Xcode/DerivedData/App-abc123/Build/Products/Debug-iphonesimulator")
    }

    var context: CheckContext { .fake(project: project) }
    func repairer(_ machine: Machine? = nil) -> MacroPluginRepairer {
        let machine = machine ?? context.machine
        return MacroPluginRepairer(
            locator: MacroPluginLocator(project: project, machine: machine),
            probe: CapabilityProbe(runner: SystemCommandRunner())
        )
    }

    @Test func healthyPluginsNeedNothing() async throws {
        try await StubPlugin.build(at: products.appending(path: "GoodMacros"), healthy: true)
        #expect(await repairer().deadPlugins().isEmpty)
        #expect(await repairer().repair().isEmpty)
    }

    @Test func findsDeadPluginsAndReportsTheOnesACopyCannotFix() async throws {
        try await StubPlugin.build(at: products.appending(path: "GoodMacros"), healthy: true)
        let dead = products.appending(path: "BadMacrosPlugin")
        try await StubPlugin.build(at: dead, healthy: false)
        let inode = try FileManager.default.attributesOfItem(atPath: dead.path)[.systemFileNumber] as? Int

        #expect(await repairer().deadPlugins().map(\.label) == ["Debug-iphonesimulator/BadMacrosPlugin"])
        // A stub that never answers stays dead after the copy; the report must say so.
        #expect(await repairer().repair() == .init(repaired: [], stillDead: ["Debug-iphonesimulator/BadMacrosPlugin"]))
        #expect(try FileManager.default.attributesOfItem(atPath: dead.path)[.systemFileNumber] as? Int != inode)
        #expect(FileManager.default.isExecutableFile(atPath: dead.path))
        #expect(!FileManager.default.fileExists(atPath: dead.path + ".xcrew-new"))
    }

    @Test func probesOnlyMacroNamedMachOBinaries() async throws {
        try await StubPlugin.build(at: products.appending(path: "Helper"), healthy: false)
        let script = products.appending(path: "ScriptMacros")
        try "#!/bin/sh\nexit 1\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        #expect(await repairer().deadPlugins().isEmpty)
    }

    @Test func extraNamesAreProbedToo() async throws {
        try await StubPlugin.build(at: products.appending(path: "Helper"), healthy: false)
        let machine = Machine(environment: ["XCREW_MACRO_PLUGINS": "Helper"], home: context.machine.home, runner: FakeRunner())
        #expect(await repairer(machine).deadPlugins().count == 1)
    }

    @Test func ignoresOtherProjectsAndTestRunFiles() async throws {
        let other = project.root.appending(path: "home/Library/Developer/Xcode/DerivedData/Other-xyz/Build/Products/Debug")
        try await StubPlugin.build(at: other.appending(path: "BadMacros"), healthy: false)
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        try Data().write(to: products.deletingLastPathComponent().appending(path: "App.xctestrun"))
        #expect(await repairer().deadPlugins().isEmpty)
    }
}

@Suite struct MacroPluginsCheckTests {
    @Test func skipsBeforeTheFirstBuild() async {
        let project = Project.temporary(containing: ["App.xcworkspace"])
        #expect(await MacroPluginsCheck().run(.fake(project: project)).status == .skip)
    }

    @Test func warnsAboutDeadPluginsAndNamesTheRepair() async throws {
        let project = Project.temporary(containing: ["App.xcworkspace"])
        let products = project.root.appending(path: "home/Library/Developer/Xcode/DerivedData/App-1/Build/Products/Debug")
        try await StubPlugin.build(at: products.appending(path: "GoodMacros"), healthy: true)
        let context = CheckContext(project: project, machine: Machine(environment: [:], home: project.root.appending(path: "home"), runner: SystemCommandRunner()))
        #expect(await MacroPluginsCheck().run(context) == .pass("1 answer"))

        try await StubPlugin.build(at: products.appending(path: "BadMacros"), healthy: false)
        let result = await MacroPluginsCheck().run(context)
        #expect(result.status == .warn)
        #expect(result.message.contains("Debug/BadMacros") && result.message.contains("xcrew repair-macros"))
    }

    @Test func aCustomDerivedDataFolderIsSearched() throws {
        let project = Project.temporary(containing: ["App.xcworkspace"])
        let custom = project.root.appending(path: "dd")
        try FileManager.default.createDirectory(at: custom.appending(path: "App-9/Build/Products/Release"), withIntermediateDirectories: true)
        let machine = Machine(environment: ["XCREW_DERIVED_DATA": custom.path], home: project.root, runner: FakeRunner())
        #expect(MacroPluginLocator(project: project, machine: machine).productFolders.map(\.lastPathComponent) == ["Release"])
    }
}

@Suite struct SwiftPackageLocatorTests {
    /// Xcode names a package's DerivedData after the package folder, as it found for a package
    /// opened directly in Xcode 27.
    @Test func aSwiftPackageIsFoundByItsFolderName() throws {
        let project = Project.temporary()
        project.write("// swift-tools-version:6.2\n", to: "Package.swift")
        let derivedData = project.root.appending(path: "dd")
        let products = derivedData.appending(path: "\(project.root.lastPathComponent)-abc123/Build/Products/Debug")
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        let machine = Machine(environment: ["XCREW_DERIVED_DATA": derivedData.path], home: project.root, runner: FakeRunner())
        #expect(MacroPluginLocator(project: project, machine: machine).productFolders.map(\.path) == [products.path])
    }

    @Test func aFolderWithNoPackageOrContainerIsNotSearched() throws {
        let project = Project.temporary()
        let derivedData = project.root.appending(path: "dd")
        try FileManager.default.createDirectory(at: derivedData.appending(path: "\(project.root.lastPathComponent)-abc/Build/Products/Debug"), withIntermediateDirectories: true)
        let machine = Machine(environment: ["XCREW_DERIVED_DATA": derivedData.path], home: project.root, runner: FakeRunner())
        #expect(MacroPluginLocator(project: project, machine: machine).productFolders.isEmpty)
    }
}
