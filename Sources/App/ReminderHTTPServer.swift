import Foundation
import Network

/// Lightweight embedded HTTP server on 127.0.0.1:18879 for AI-Agent reminder CRUD.
final class ReminderHTTPServer {
    static let shared = ReminderHTTPServer()
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "reminder-http-server", qos: .utility)

    private init() {}

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: 18879)
        } catch {
            print("[ReminderHTTPServer] Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[ReminderHTTPServer] Listening on :18879")
            case .failed(let error):
                print("[ReminderHTTPServer] Failed: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    // MARK: - Connection

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self, let data, !data.isEmpty, error == nil else {
                connection.cancel(); return
            }
            guard let raw = String(data: data, encoding: .utf8) else {
                connection.cancel(); return
            }
            self.process(raw: raw, connection: connection)
        }
    }

    // MARK: - Parsing

    private func process(raw: String, connection: NWConnection) {
        let lines = raw.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ", maxSplits: 2) ?? []
        guard parts.count >= 2 else {
            send(connection: connection, status: 400, body: #"{"error":"bad request"}"#); return
        }

        let method = String(parts[0])
        let path   = String(parts[1]).components(separatedBy: "?").first ?? String(parts[1])
        let body   = raw.range(of: "\r\n\r\n").map { String(raw[$0.upperBound...]) } ?? ""

        route(method: method, path: path, body: body, connection: connection)
    }

    // MARK: - Router

    private func route(method: String, path: String, body: String, connection: NWConnection) {
        switch method {
        case "GET" where path == "/reminders":
            handleList(connection: connection)

        case "POST" where path == "/reminders":
            handleAdd(body: body, connection: connection)

        case "PUT" where path.hasPrefix("/reminders/") && path.hasSuffix("/toggle"):
            let id = path.dropFirst("/reminders/".count).dropLast("/toggle".count)
            handleToggle(id: String(id), connection: connection)

        case "DELETE" where path.hasPrefix("/reminders/"):
            let id = String(path.dropFirst("/reminders/".count))
            handleDelete(id: id, connection: connection)

        default:
            send(connection: connection, status: 404, body: #"{"error":"not found"}"#)
        }
    }

    // MARK: - Handlers

    private func handleList(connection: NWConnection) {
        DispatchQueue.main.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(RulesStore.shared.rules),
                  let json = String(data: data, encoding: .utf8) else {
                self.send(connection: connection, status: 500, body: #"{"error":"encode failed"}"#); return
            }
            self.send(connection: connection, status: 200, body: json)
        }
    }

    private func handleAdd(body: String, connection: NWConnection) {
        guard let data = body.data(using: .utf8) else {
            send(connection: connection, status: 400, body: #"{"error":"invalid body"}"#); return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let rule = try? decoder.decode(ReminderRule.self, from: data) else {
            send(connection: connection, status: 400, body: #"{"error":"invalid rule json"}"#); return
        }
        DispatchQueue.main.async {
            RulesStore.shared.rules.append(rule)
            self.send(connection: connection, status: 200, body: #"{"ok":true}"#)
        }
    }

    private func handleToggle(id: String, connection: NWConnection) {
        guard let uuid = UUID(uuidString: id) else {
            send(connection: connection, status: 400, body: #"{"error":"invalid id"}"#); return
        }
        DispatchQueue.main.async {
            guard let idx = RulesStore.shared.rules.firstIndex(where: { $0.id == uuid }) else {
                self.send(connection: connection, status: 404, body: #"{"error":"not found"}"#); return
            }
            RulesStore.shared.rules[idx].isEnabled.toggle()
            self.send(connection: connection, status: 200, body: #"{"ok":true}"#)
        }
    }

    private func handleDelete(id: String, connection: NWConnection) {
        guard let uuid = UUID(uuidString: id) else {
            send(connection: connection, status: 400, body: #"{"error":"invalid id"}"#); return
        }
        DispatchQueue.main.async {
            let before = RulesStore.shared.rules.count
            RulesStore.shared.rules.removeAll { $0.id == uuid }
            if RulesStore.shared.rules.count == before {
                self.send(connection: connection, status: 404, body: #"{"error":"not found"}"#)
            } else {
                self.send(connection: connection, status: 200, body: #"{"ok":true}"#)
            }
        }
    }

    // MARK: - Response

    private func send(connection: NWConnection, status: Int, body: String) {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        case 500: statusText = "Internal Server Error"
        default:  statusText = "Unknown"
        }
        let bodyData = body.data(using: .utf8) ?? Data()
        let header = "HTTP/1.1 \(status) \(statusText)\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
        var response = header.data(using: .utf8)!
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
