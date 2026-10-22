import Foundation

/// Optional Claude Code hooks that record each session's latest event in a file named after the
/// `claude` process id, so the matching character knows exactly when the agent works or waits.
enum ClaudeHooks {
    static let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("OllieBoard")
    static let eventsDir = supportDir.appendingPathComponent("agents")
    static let script = supportDir.appendingPathComponent("claude-hook.sh")
    static let settings = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")

    /// Hook events we listen to, with the tool matcher where Claude Code expects one.
    private static let events: [(name: String, matcher: String?)] = [
        ("UserPromptSubmit", nil), ("PreToolUse", "*"), ("PostToolUse", "*"),
        ("PermissionRequest", "*"), ("Notification", nil), ("Stop", nil),
    ]

    static func state(for event: String) -> AgentState {
        switch event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return .working
        case "PermissionRequest", "Notification": return .needsInput
        case "Stop": return .done
        default: return .idle
        }
    }

    static func lastEvent(pid: Int32) -> String? {
        let url = eventsDir.appendingPathComponent(String(pid))
        return (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func clearEvent(pid: Int32) {
        try? FileManager.default.removeItem(at: eventsDir.appendingPathComponent(String(pid)))
    }

    static var isInstalled: Bool {
        (try? String(contentsOf: settings, encoding: .utf8))?.contains(script.path) ?? false
    }

    /// Adds our hooks next to whatever hooks already exist. The previous settings are kept as a backup.
    static func install() throws {
        try writeScript()
        try addHooksToSettings()
    }

    static func writeScript() throws {
        try FileManager.default.createDirectory(at: eventsDir, withIntermediateDirectories: true)
        // Walks up from the hook's shell to the `claude` process so the event lands under that session's pid.
        let body = """
        #!/bin/sh
        # Written by OllieBoard: records the latest Claude Code hook event for this session.
        dir='\(eventsDir.path)'
        pid=$PPID
        while [ "${pid:-1}" -gt 1 ]; do
          case "$(ps -o args= -p "$pid")" in
            *claude-hook.sh*) ;;
            claude*|*/claude|*/claude\\ *) echo "$1" > "$dir/$pid"; exit 0 ;;
          esac
          pid=$(ps -o ppid= -p "$pid" | tr -d ' ')
        done
        exit 0

        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    }

    private static func addHooksToSettings() throws {
        var root: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: settings.path) {
            let data = try Data(contentsOf: settings)
            // Refuse to touch a file we cannot parse rather than overwrite it.
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            root = parsed
            try data.write(to: settings.appendingPathExtension("ollieboard-backup"))
        } else {
            try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var entry: [String: Any] = ["hooks": [["type": "command", "command": "sh '\(script.path)' \(event.name)"]]]
            if let matcher = event.matcher { entry["matcher"] = matcher }
            hooks[event.name] = (hooks[event.name] as? [[String: Any]] ?? []) + [entry]
        }
        root["hooks"] = hooks
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: settings, options: .atomic)
    }
}
