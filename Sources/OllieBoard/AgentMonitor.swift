import AppKit
import Darwin

enum AgentKind: String, CaseIterable {
    case claude, codex, gemini, opencode, cursor, aider

    var title: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        case .opencode: return "OpenCode"
        case .cursor: return "Cursor"
        case .aider: return "Aider"
        }
    }

    /// Whether a process is a session of this agent, judged by the executable in its argv
    /// (never by other arguments, so e.g. `grep codex` doesn't count).
    func matches(_ argv: [String]) -> Bool {
        guard let first = argv.first else { return false }
        let exe = (first as NSString).lastPathComponent
        let script = argv.count > 1 ? (argv[1] as NSString).lastPathComponent : ""
        // npm / pip installs run as `node …/codex` or `python3.12 …/aider`.
        let interpreted = ["node", "bun", "deno"].contains(exe) || exe.lowercased().hasPrefix("python")
        func named(_ names: String...) -> Bool { names.contains(exe) || (interpreted && names.contains(script)) }
        switch self {
        case .claude: return named("claude")
        case .codex: return named("codex")
        case .gemini: return named("gemini")
        case .opencode: return named("opencode") && !argv.contains("serve")   // background server, not a session
        case .cursor: return named("cursor-agent")
        case .aider: return named("aider")
        }
    }
}

enum AgentState: Equatable {
    case idle, working, done, needsInput
}

struct AgentSession {
    let pid: Int32
    let kind: AgentKind
    let project: String
    var state: AgentState
}

/// Polls the process table (via libproc, no `ps` spawning) for AI coding agents. State comes from Claude Code
/// hooks when they are installed (see ClaudeHooks); otherwise it is guessed from CPU use of the agent and its children.
final class AgentMonitor {
    var onUpdate: (([Int32: AgentSession]) -> Void)?

    private let queue = DispatchQueue(label: "ollieboard.agents")
    private var timer: DispatchSourceTimer?
    private let interval: TimeInterval = 2

    // Only touched on `queue`.
    /// Classification per pid, redone only when the process name changes (e.g. after exec).
    private var classified: [Int32: (name: String, kind: AgentKind?)] = [:]
    private var known: [Int32: AgentSession] = [:]
    private var lastCPU: [Int32: Double] = [:]
    private var busyStreak: [Int32: Int] = [:]
    private var lastBusy: [Int32: Date] = [:]

    func start() {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async { [weak self] in
            self?.known = [:]
            DispatchQueue.main.async { self?.onUpdate?([:]) }
        }
    }

    private func poll() {
        var found: [Int32: AgentKind] = [:]
        var seen: [Int32: (name: String, kind: AgentKind?)] = [:]
        for pid in Self.allPIDs() {
            let name = Self.processName(pid)
            let entry = classified[pid].flatMap { $0.name == name ? $0 : nil } ?? (name: name, kind: classify(pid))
            seen[pid] = entry
            if let kind = entry.kind { found[pid] = kind }
        }
        classified = seen

        // A session's own helper processes (same agent further up the tree) are not new sessions.
        found = found.filter { pid, kind in
            var p = Self.parentPID(pid)
            while p > 1 {
                if found[p] == kind { return false }
                p = Self.parentPID(p)
            }
            return true
        }

        func treeCPU(_ pid: Int32) -> Double {
            Self.cpuSeconds(pid) + Self.childPIDs(pid).reduce(0) { $0 + treeCPU($1) }
        }

        let now = Date()
        var result: [Int32: AgentSession] = [:]
        for (pid, kind) in found {
            var session = known[pid] ?? AgentSession(pid: pid, kind: kind, project: Self.projectName(pid), state: .idle)
            let cpu = treeCPU(pid)
            if let event = ClaudeHooks.lastEvent(pid: pid) {
                session.state = ClaudeHooks.state(for: event)
            } else if let previous = lastCPU[pid] {
                // More than ~3% of a core for two polls in a row counts as working; quiet for 12s after that means done.
                let usage = (cpu - previous) / interval
                busyStreak[pid] = usage > 0.03 ? (busyStreak[pid] ?? 0) + 1 : 0
                if busyStreak[pid]! >= 2 {
                    session.state = .working
                    lastBusy[pid] = now
                } else if session.state == .working, now.timeIntervalSince(lastBusy[pid] ?? now) > 12 {
                    session.state = .done
                }
            }
            lastCPU[pid] = cpu
            result[pid] = session
        }

        for pid in known.keys where result[pid] == nil {
            lastCPU[pid] = nil
            busyStreak[pid] = nil
            lastBusy[pid] = nil
            ClaudeHooks.clearEvent(pid: pid)
        }
        known = result
        DispatchQueue.main.async { [weak self] in self?.onUpdate?(result) }
    }

    // MARK: - Process table

    /// Matches on the command line rather than the process name: native Claude Code runs a binary named after
    /// its version (e.g. "2.1.307"), while argv[0] is still "claude".
    private func classify(_ pid: Int32) -> AgentKind? {
        guard let argv = arguments(pid) else { return nil }
        return AgentKind.allCases.first { $0.matches(argv) }
    }

    private static func allPIDs() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) + 64)
        let n = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        return Array(pids.prefix(Int(max(n, 0))))
    }

    private static func childPIDs(_ pid: Int32) -> [Int32] {
        var pids = [Int32](repeating: 0, count: 256)
        let n = proc_listchildpids(pid, &pids, Int32(pids.count * MemoryLayout<Int32>.size))
        return Array(pids.prefix(Int(max(n, 0))))
    }

    private static func processName(_ pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: 2 * Int(MAXCOMLEN) + 1)
        proc_name(pid, &buffer, UInt32(buffer.count))
        return String(cString: buffer)
    }

    /// Mach time units → nanoseconds.
    private static let timebase: Double = {
        var info = mach_timebase_info()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom)
    }()

    /// Total CPU time (user + system) the process has used, in seconds.
    private static func cpuSeconds(_ pid: Int32) -> Double {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size) == size else { return 0 }
        return Double(info.pti_total_user + info.pti_total_system) * timebase / 1e9
    }

    /// Reused for every KERN_PROCARGS2 read (sized to the kernel's argument limit).
    private var argsBuffer: [UInt8] = {
        var mib = [CTL_KERN, KERN_ARGMAX]
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return [UInt8](repeating: 0, count: sysctl(&mib, 2, &value, &size, nil, 0) == 0 ? Int(value) : 262_144)
    }()

    /// argv of a process (from KERN_PROCARGS2).
    private func arguments(_ pid: Int32) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = argsBuffer.count
        guard sysctl(&mib, 3, &argsBuffer, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        let buffer = argsBuffer
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var i = MemoryLayout<Int32>.size
        while i < size && buffer[i] != 0 { i += 1 }   // executable path
        while i < size && buffer[i] == 0 { i += 1 }   // padding
        var args: [String] = []
        while args.count < argc && i < size {
            let start = i
            while i < size && buffer[i] != 0 { i += 1 }
            args.append(String(decoding: buffer[start..<i], as: UTF8.self))
            i += 1
        }
        return args
    }

    /// Name of the agent's working directory, used as the project label.
    static func projectName(_ pid: Int32) -> String {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return "" }
        let path = withUnsafeBytes(of: &info.pvi_cdir.vip_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        let name = (path as NSString).lastPathComponent
        return name == "/" ? "" : name
    }

    static func parentPID(_ pid: Int32) -> Int32 {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return 0 }
        return Int32(info.pbi_ppid)
    }

    /// The regular app (Terminal, iTerm, VS Code…) the agent runs inside.
    static func hostApp(of pid: Int32) -> NSRunningApplication? {
        var p = pid
        while p > 1 {
            if let app = NSRunningApplication(processIdentifier: p), app.activationPolicy == .regular { return app }
            p = parentPID(p)
        }
        return nil
    }

    /// Brings the agent's host app to the front.
    static func focusHostApp(of pid: Int32) {
        guard let url = hostApp(of: pid)?.bundleURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
