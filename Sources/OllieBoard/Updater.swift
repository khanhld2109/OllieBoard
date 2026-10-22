import AppKit

/// Finds a newer release on GitHub and installs it in one click: downloads its DMG, copies the app out,
/// then a small script swaps it in for this copy once the app has quit and opens the new one.
final class Updater {
    enum State: Equatable {
        case idle, checking, upToDate, installing
        case available(version: String, dmg: URL)
        case failed(String)
    }

    private static let latestRelease = URL(string: "https://api.github.com/repos/vfa-khuongdv/OllieBoard/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Only a packaged OllieBoard.app can replace itself (not `swift run`).
    static var canUpdate: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    private(set) var state: State = .idle
    /// Called on the main thread after an install fails, with the reason.
    var onInstallFailed: ((String) -> Void)?

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let url: URL
            enum CodingKeys: String, CodingKey { case name, url = "browser_download_url" }
        }
        let tagName: String
        let assets: [Asset]
        enum CodingKeys: String, CodingKey { case tagName = "tag_name", assets }
    }

    func check() {
        switch state {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        var request = URLRequest(url: Self.latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            let result: State
            if let data, let release = try? JSONDecoder().decode(Release.self, from: data),
               let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") }) {
                let version = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                result = Self.isNewer(version, than: Self.currentVersion) ? .available(version: version, dmg: dmg.url) : .upToDate
            } else {
                result = .failed(error?.localizedDescription ?? "No release with a DMG found")
            }
            DispatchQueue.main.async { self.state = result }
        }.resume()
    }

    func install() {
        guard case .available(_, let dmg) = state, Self.canUpdate else { return }
        let target = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            return fail(ui(.updateNoPermission, target.deletingLastPathComponent().path))
        }
        state = .installing
        URLSession.shared.downloadTask(with: dmg) { file, _, error in
            // The downloaded file is deleted once this handler returns, so everything happens in here.
            guard let file else { return self.fail(error?.localizedDescription ?? "Download failed") }
            do {
                let newApp = try Self.extractApp(fromDMG: file)
                try Self.swapInWhenQuit(newApp, replacing: target)
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch {
                self.fail(error.localizedDescription)
            }
        }.resume()
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.state = .failed(message)
            self.onInstallFailed?(message)
        }
    }

    /// "1.10" is newer than "1.9"; missing parts count as 0.
    static func isNewer(_ version: String, than current: String) -> Bool {
        let a = version.split(separator: ".").map { Int($0) ?? 0 }, b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Mounts the DMG, copies the .app inside it to a temporary folder and returns where it went.
    private static func extractApp(fromDMG file: URL) throws -> URL {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("OllieBoard-update-\(UUID().uuidString)")
        let mount = work.appendingPathComponent("mount")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        let dmg = work.appendingPathComponent("update.dmg")
        try FileManager.default.moveItem(at: file, to: dmg)
        try run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }
        guard let app = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app inside the DMG"])
        }
        let copy = work.appendingPathComponent(app.lastPathComponent)
        try run("/usr/bin/ditto", app.path, copy.path)
        return copy
    }

    /// Starts a detached script that waits for this process to exit, replaces `target` with `newApp` and opens it.
    private static func swapInWhenQuit(_ newApp: URL, replacing target: URL) throws {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$1" && /usr/bin/ditto "$2" "$1" && /usr/bin/xattr -dr com.apple.quarantine "$1"
        /usr/bin/open "$1"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", target.path, newApp.path]
        try process.run()
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "Updater", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "\((tool as NSString).lastPathComponent) failed: \(message)",
            ])
        }
    }
}
