import Foundation

/// Finds the macro plugins Xcode built for a project.
///
/// Searches the DerivedData folders named after the project (`Project.derivedDataNames`), and takes executables named like Swift macro plugins (`…Macros`,
/// `…MacrosPlugin`, `…MacroPlugin`) that are Mach-O binaries. `XCREW_DERIVED_DATA` points at
/// another DerivedData folder; `XCREW_MACRO_PLUGINS` adds binary names (comma-separated) for
/// plugins named otherwise.
public struct MacroPluginLocator: Sendable {
    static let nameSuffixes = ["Macros", "MacrosPlugin", "MacroPlugin"]
    /// Thin and universal Mach-O headers, read little-endian.
    static let machOMagics: Set<UInt32> = [0xFEED_FACF, 0xBEBA_FECA, 0xCAFE_BABE, 0xCFFA_EDFE]

    public let productFolders: [URL]
    public let extraNames: Set<String>

    public init(productFolders: [URL], extraNames: Set<String> = []) {
        self.productFolders = productFolders
        self.extraNames = extraNames
    }

    public init(project: Project, machine: Machine) {
        let derivedData = machine.value("XCREW_DERIVED_DATA").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? machine.home.appending(path: "Library/Developer/Xcode/DerivedData")
        let prefixes = Set(project.derivedDataNames.map { $0 + "-" })
        let builds = Self.children(of: derivedData).filter { folder in prefixes.contains { folder.lastPathComponent.hasPrefix($0) } }
        // Products/ also holds .xctestrun files beside the configuration folders.
        let folders = builds.flatMap { Self.children(of: $0.appending(path: "Build/Products")) }.filter(Self.isDirectory)
        let extra = (machine.value("XCREW_MACRO_PLUGINS") ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        self.init(productFolders: folders.sorted { $0.path < $1.path }, extraNames: Set(extra))
    }

    public func plugins() -> [MacroPlugin] {
        productFolders.flatMap(Self.children).filter(isPlugin).map(MacroPlugin.init)
    }

    func isPlugin(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return (extraNames.contains(name) || Self.nameSuffixes.contains(where: name.hasSuffix))
            && FileManager.default.isExecutableFile(atPath: url.path)
            && Self.isMachO(url)
    }

    static func isMachO(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let head = try? handle.read(upToCount: 4), head.count == 4
        else { return false }
        let magic = head.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return machOMagics.contains(magic)
    }

    static func children(of folder: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.sorted().map { folder.appending(path: $0) }
    }

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
