import Foundation
import Darwin
import ServerMonitorCore

struct RemoteServerService {
    // One SSH invocation samples all resources on the Linux server.
    static let query = #"""
    export LC_ALL=C
    printf '__GPU_BEGIN__\n'
    nvidia-smi --query-gpu=index,name,uuid,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null
    printf '__END__\n'
    cpu_before=$(head -n 1 /proc/stat 2>/dev/null)
    sleep 0.25
    cpu_after=$(head -n 1 /proc/stat 2>/dev/null)
    printf '%s\n%s\n' "$cpu_before" "$cpu_after" | awk '
      $1 == "cpu" { total=0; for (i=2; i<=9; i++) total+=$i; idle=$5+$6;
        if (NR==1) { previous=total; previousIdle=idle }
        else if (total>previous) printf "__CPU__ %.1f\n", 100*(1-(idle-previousIdle)/(total-previous)) }'
    awk '/^MemTotal:/ {t=$2} /^MemAvailable:/ {a=$2; found=1}
      END {if(t>0 && found) printf "__MEM__ %.0f %.0f\n", t, a}' /proc/meminfo 2>/dev/null
    printf '__DISK_BEGIN__\n'
    df -P -k -T -l 2>/dev/null
    printf '__END__\n'
    """#

    func fetch(host: String) async throws -> ServerSnapshot {
        guard Self.isValidHost(host) else { throw RemoteServerError.invalidHost }
        let job = SSHJob(host: host)
        let output = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await Task.detached(priority: .utility) { try job.run() }.value
        } onCancel: {
            job.cancel()
        }
        try Task.checkCancellation()
        let snapshot = ServerResourceParser.parse(output, host: host)
        guard snapshot.hasMetrics else {
            throw RemoteServerError.noMetrics
        }
        return snapshot
    }

    static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, !host.hasPrefix("-") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-[]")
        return host.unicodeScalars.allSatisfy(allowed.contains)
    }
}

private final class SSHJob: @unchecked Sendable {
    private let host: String
    private let process = Process()
    private let lock = NSLock()
    private var stopped = false
    private var timedOut = false

    init(host: String) { self.host = host }

    func cancel() { stop(timeout: false) }

    private func stop(timeout: Bool) {
        lock.lock()
        stopped = true
        timedOut = timedOut || timeout
        if process.isRunning {
            process.terminate()
            let runningProcess = process
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if runningProcess.isRunning { kill(runningProcess.processIdentifier, SIGKILL) }
            }
        }
        lock.unlock()
    }

    func run() throws -> String {
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
                             "-o", "ConnectionAttempts=1", "-o", "ServerAliveInterval=3",
                             "-o", "ServerAliveCountMax=1", host, RemoteServerService.query]
        process.standardOutput = stdout
        process.standardError = stderr

        lock.lock()
        if stopped { lock.unlock(); throw CancellationError() }
        do { try process.run() }
        catch { lock.unlock(); throw RemoteServerError.sshFailed(error.localizedDescription) }
        lock.unlock()

        let timeout = DispatchWorkItem { [weak self] in self?.stop(timeout: true) }
        DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
        defer { timeout.cancel() }

        // Drain both pipes concurrently so neither can block the other.
        let errors = PipeResult()
        let readers = DispatchGroup()
        readers.enter()
        DispatchQueue.global().async {
            errors.data = stderr.fileHandleForReading.readDataToEndOfFile()
            readers.leave()
        }
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        readers.wait()

        lock.lock()
        let didTimeout = timedOut
        let wasStopped = stopped
        lock.unlock()
        if didTimeout { throw RemoteServerError.timedOut }
        if wasStopped { throw CancellationError() }
        guard process.terminationStatus == 0 else {
            let detail = String(data: errors.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw RemoteServerError.sshFailed(detail.flatMap { $0.isEmpty ? nil : $0 } ?? "退出码 \(process.terminationStatus)")
        }
        guard let text = String(data: output, encoding: .utf8) else { throw RemoteServerError.invalidOutput }
        return text
    }
}

// Written by the pipe reader and read only after DispatchGroup.wait().
private final class PipeResult: @unchecked Sendable { var data = Data() }

enum RemoteServerError: LocalizedError {
    case invalidHost
    case sshFailed(String)
    case timedOut
    case noMetrics
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .invalidHost: return "请输入有效的 SSH Host 别名或 IP 地址"
        case let .sshFailed(message): return "SSH 连接失败：\(message)"
        case .timedOut: return "读取服务器超时，稍后自动重试"
        case .noMetrics: return "未采集到有效的服务器指标"
        case .invalidOutput: return "服务器返回了无法识别的文本"
        }
    }
}
