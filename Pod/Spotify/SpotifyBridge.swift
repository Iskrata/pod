import Foundation
import Combine

class SpotifyBridge: ObservableObject {
    static let shared = SpotifyBridge()

    @Published var isRunning = false

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var requestId: UInt64 = 0
    private var pendingRequests: [UInt64: (Result<Any, Error>) -> Void] = [:]
    private let queue = DispatchQueue(label: "com.pod.spotify-bridge", qos: .userInitiated)

    var onEvent: ((String, [String: Any]) -> Void)?

    private init() {}

    // MARK: - Process Lifecycle

    func start() {
        guard process == nil else { return }

        let binaryPath = findBridgeBinary()
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            print("[SpotifyBridge] Binary not found at \(binaryPath)")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.environment = ProcessInfo.processInfo.environment

        let stdin = Pipe()
        let stdout = Pipe()

        proc.standardInput = stdin
        proc.standardOutput = stdout
        let stderrPipe = Pipe()
        proc.standardError = stderrPipe
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                print("[SpotifyBridge stderr] \(str)")
            }
        }

        stdinPipe = stdin
        stdoutPipe = stdout
        process = proc

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.process = nil
                print("[SpotifyBridge] Process terminated")
            }
        }

        // Read stdout on background thread
        queue.async { [weak self] in
            self?.readStdout(stdout)
        }

        do {
            try proc.run()
            DispatchQueue.main.async { self.isRunning = true }
            print("[SpotifyBridge] Started")
        } catch {
            print("[SpotifyBridge] Failed to start: \(error)")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        isRunning = false
        pendingRequests.removeAll()
    }

    // MARK: - Communication

    func send(method: String, params: [String: Any]? = nil, completion: ((Result<Any, Error>) -> Void)? = nil) {
        requestId += 1
        let id = requestId

        var message: [String: Any] = ["id": id, "method": method]
        if let params = params {
            message["params"] = params
        }

        if let completion = completion {
            pendingRequests[id] = completion
        }

        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            completion?(.failure(BridgeError.serializationFailed))
            return
        }

        let line = jsonString + "\n"
        stdinPipe?.fileHandleForWriting.write(line.data(using: .utf8)!)
    }

    func send(method: String, params: [String: Any]? = nil) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            send(method: method, params: params) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Stdout Reader

    private func readStdout(_ pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        var buffer = Data()

        while true {
            let data = handle.availableData
            if data.isEmpty { break } // EOF

            buffer.append(data)

            // Process complete lines
            while let newlineRange = buffer.range(of: Data("\n".utf8)) {
                let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                guard let line = String(data: lineData, encoding: .utf8),
                      !line.isEmpty,
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }

                DispatchQueue.main.async { [weak self] in
                    self?.handleMessage(json)
                }
            }
        }
    }

    private func handleMessage(_ json: [String: Any]) {
        // Response to a request
        if let id = json["id"] as? UInt64, let callback = pendingRequests.removeValue(forKey: id) {
            if let error = json["error"] as? String {
                callback(.failure(BridgeError.bridgeError(error)))
            } else if let result = json["result"] {
                callback(.success(result))
            } else {
                callback(.success(json))
            }
            return
        }

        // Also handle Int id (JSON numbers)
        if let idNum = json["id"] as? Int, let callback = pendingRequests.removeValue(forKey: UInt64(idNum)) {
            if let error = json["error"] as? String {
                callback(.failure(BridgeError.bridgeError(error)))
            } else if let result = json["result"] {
                callback(.success(result))
            } else {
                callback(.success(json))
            }
            return
        }

        // Event (no id)
        if let event = json["event"] as? String {
            onEvent?(event, json)
        }
    }

    // MARK: - Binary Location

    private func findBridgeBinary() -> String {
        if let bundlePath = Bundle.main.path(forResource: "pod-spotify-bridge", ofType: nil) {
            return bundlePath
        }

        // Dev fallback: source tree relative to this file
        let projectPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Spotify/
            .deletingLastPathComponent() // Pod/
            .deletingLastPathComponent() // pod/
            .appendingPathComponent("pod-spotify-bridge/target/release/pod-spotify-bridge")
            .path
        return projectPath
    }

    // MARK: - Error Type

    enum BridgeError: Error, LocalizedError {
        case serializationFailed
        case bridgeError(String)
        case notRunning

        var errorDescription: String? {
            switch self {
            case .serializationFailed: return "Failed to serialize message"
            case .bridgeError(let msg): return msg
            case .notRunning: return "Bridge not running"
            }
        }
    }
}
