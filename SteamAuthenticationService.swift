import Foundation
import Security

struct SteamQRChallenge {
    let clientID: UInt64
    let requestID: Data
    let challengeURL: URL
    let pollInterval: TimeInterval
}

struct SteamAccountSession: Codable {
    let accountName: String
    let accessToken: String
    let refreshToken: String
}

enum SteamAuthenticationError: LocalizedError {
    case invalidResponse
    case serviceRejected(String)
    case keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Steam returned an unexpected authentication response."
        case .serviceRejected(let message): return message
        case .keychain(let status): return "Could not securely store the Steam session (Keychain error \(status))."
        }
    }
}

/// Native Steam QR authentication. No Steam password is requested or stored.
final class SteamAuthenticationService {
    static let shared = SteamAuthenticationService()
    private let baseURL = URL(string: "https://api.steampowered.com/IAuthenticationService/")!
    private init() {}

    func beginQRLogin(deviceName: String = "SAVEFORGE on iOS") async throws -> SteamQRChallenge {
        var details = Data()
        details.protoString(1, deviceName)
        details.protoVarint(2, 1) // Steam client platform
        details.protoVarint(3, 20) // iOS
        var body = Data()
        body.protoString(1, deviceName)
        body.protoVarint(2, 1)
        body.protoBytes(3, details)
        let data = try await post("BeginAuthSessionViaQR", body: body)
        let proto = ProtoReader(data)
        guard let client = proto.uint(1), let urlString = proto.string(2),
              let url = URL(string: urlString), let requestID = proto.bytes(3) else {
            throw SteamAuthenticationError.invalidResponse
        }
        return SteamQRChallenge(clientID: client, requestID: requestID, challengeURL: url,
                                pollInterval: max(2, min(proto.float(4) ?? 5, 15)))
    }

    func poll(_ challenge: SteamQRChallenge) async throws -> SteamAccountSession? {
        var body = Data()
        body.protoVarint(1, challenge.clientID)
        body.protoBytes(2, challenge.requestID)
        let proto = ProtoReader(try await post("PollAuthSessionStatus", body: body))
        guard let refresh = proto.string(3), !refresh.isEmpty,
              let access = proto.string(4), !access.isEmpty else { return nil }
        let session = SteamAccountSession(accountName: proto.string(6) ?? "Steam User",
                                          accessToken: access, refreshToken: refresh)
        try SteamSessionVault.save(session)
        return session
    }

    private func post(_ method: String, body: Data) async throws -> Data {
        let url = baseURL.appendingPathComponent(method).appendingPathComponent("v1")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 25
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-protobuf", forHTTPHeaderField: "Accept")
        request.setValue("SAVEFORGE/1.0.5", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SteamAuthenticationError.invalidResponse }
        if let result = http.value(forHTTPHeaderField: "x-eresult"), let code = Int(result), code != 1 {
            throw SteamAuthenticationError.serviceRejected("Steam rejected the request (result \(code)).")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw SteamAuthenticationError.serviceRejected("Steam returned HTTP \(http.statusCode).")
        }
        return data
    }
}

enum SteamSessionVault {
    private static let service = "com.github.infifunk.SAVEFORGE.steam"
    static func save(_ session: SteamAccountSession) throws {
        let data = try JSONEncoder().encode(session)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: "session"]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw SteamAuthenticationError.keychain(status) }
    }
    static func load() -> SteamAccountSession? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: "session",
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SteamAccountSession.self, from: data)
    }
    static func clear() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                       kSecAttrService as String: service,
                       kSecAttrAccount as String: "session"] as CFDictionary)
    }
}

private extension Data {
    mutating func protoVarint(_ field: Int, _ value: UInt64) {
        appendVarint(UInt64(field << 3)); appendVarint(value)
    }
    mutating func protoString(_ field: Int, _ value: String) { protoBytes(field, Data(value.utf8)) }
    mutating func protoBytes(_ field: Int, _ value: Data) {
        appendVarint(UInt64((field << 3) | 2)); appendVarint(UInt64(value.count)); append(value)
    }
    mutating func appendVarint(_ value: UInt64) {
        var number = value
        while number >= 0x80 { append(UInt8((number & 0x7f) | 0x80)); number >>= 7 }
        append(UInt8(number))
    }
}

private struct ProtoReader {
    let data: Data
    func uint(_ field: Int) -> UInt64? {
        var i = 0
        while i < data.count {
            guard let key = read(&i) else { return nil }
            let number = Int(key >> 3), wire = Int(key & 7)
            if wire == 0 {
                guard let value = read(&i) else { return nil }
                if number == field { return value }
            } else if wire == 2 {
                guard let count = read(&i) else { return nil }
                let length = Int(count)
                guard length >= 0, i + length <= data.count else { return nil }
                i += length
            } else if wire == 5 { i += 4 }
            else if wire == 1 { i += 8 }
            else { return nil }
        }
        return nil
    }
    func bytes(_ field: Int) -> Data? {
        var i = 0
        while i < data.count {
            guard let key = read(&i) else { return nil }
            let number = Int(key >> 3), wire = Int(key & 7)
            if wire == 2 {
                guard let count = read(&i) else { return nil }
                let length = Int(count)
                guard length >= 0, i + length <= data.count else { return nil }
                let value = data.subdata(in: i..<(i + length))
                if number == field { return value }
                i += length
            } else if wire == 0 { guard read(&i) != nil else { return nil } }
            else if wire == 5 { i += 4 }
            else if wire == 1 { i += 8 }
            else { return nil }
        }
        return nil
    }
    func string(_ field: Int) -> String? { bytes(field).flatMap { String(data: $0, encoding: .utf8) } }
    func float(_ field: Int) -> Float? {
        var i = 0
        while i < data.count {
            guard let key = read(&i) else { return nil }
            let number = Int(key >> 3), wire = Int(key & 7)
            if wire == 5 {
                guard i + 4 <= data.count else { return nil }
                let value = data[i..<(i + 4)].withUnsafeBytes { $0.loadUnaligned(as: Float.self) }
                if number == field { return value }
                i += 4
            } else if wire == 0 { guard read(&i) != nil else { return nil } }
            else if wire == 2 {
                guard let count = read(&i) else { return nil }; i += Int(count)
            } else if wire == 1 { i += 8 }
            else { return nil }
        }
        return nil
    }
    private func read(_ index: inout Int) -> UInt64? {
        var result: UInt64 = 0, shift: UInt64 = 0
        while index < data.count && shift < 64 {
            let byte = data[index]; index += 1
            result |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
        }
        return nil
    }
}
