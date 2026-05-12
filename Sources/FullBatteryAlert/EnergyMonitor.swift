import Foundation
import AppKit
import Combine

struct AppEnergy: Identifiable {
    let id: pid_t
    let displayName: String
    let bundleIdentifier: String?
    let icon: NSImage?
    let powerImpact: Double
    let pids: [pid_t]
}

enum EnergyParser {
    struct RawProcess {
        let pid: pid_t
        let command: String
        let powerImpact: Double
    }

    static func parse(_ output: String) -> [RawProcess] {
        var rows: [RawProcess] = []
        var seenHeader = false
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !seenHeader {
                if trimmed.hasPrefix("PID") && trimmed.contains("POWER") {
                    seenHeader = true
                }
                continue
            }
            if trimmed.isEmpty { continue }
            let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count >= 3,
                  let pid = pid_t(parts[0]),
                  let power = Double(parts[parts.count - 1])
            else { continue }
            let command = parts[1..<(parts.count - 1)].joined(separator: " ")
            rows.append(RawProcess(pid: pid, command: command, powerImpact: power))
        }
        return rows
    }
}

@MainActor
final class EnergyMonitor: ObservableObject {
    @Published private(set) var topApps: [AppEnergy] = []

    private let significanceThreshold: Double = 1.0
    private let maxRows: Int = 5
    private let pollInterval: TimeInterval = 5.0

    private var timer: Timer?
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let raw = Self.runTop()
        let parsed = EnergyParser.parse(raw)
        let grouped = Self.group(parsed)
        let filtered = grouped
            .filter { $0.powerImpact > significanceThreshold }
            .sorted { $0.powerImpact > $1.powerImpact }
            .prefix(maxRows)
        topApps = Array(filtered)
    }

    private static func runTop() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/top")
        process.arguments = ["-l", "1", "-stats", "pid,command,power", "-o", "power", "-n", "20"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func group(_ raw: [EnergyParser.RawProcess]) -> [AppEnergy] {
        var byKey: [String: AppEnergy] = [:]
        for row in raw {
            let runningApp = NSRunningApplication(processIdentifier: row.pid)
            let key = runningApp?.bundleIdentifier ?? row.command
            if let existing = byKey[key] {
                byKey[key] = AppEnergy(
                    id: existing.powerImpact >= row.powerImpact ? existing.id : row.pid,
                    displayName: existing.displayName,
                    bundleIdentifier: existing.bundleIdentifier,
                    icon: existing.icon,
                    powerImpact: existing.powerImpact + row.powerImpact,
                    pids: existing.pids + [row.pid]
                )
            } else {
                byKey[key] = AppEnergy(
                    id: row.pid,
                    displayName: runningApp?.localizedName ?? row.command,
                    bundleIdentifier: runningApp?.bundleIdentifier,
                    icon: runningApp?.icon,
                    powerImpact: row.powerImpact,
                    pids: [row.pid]
                )
            }
        }
        return Array(byKey.values)
    }
}
