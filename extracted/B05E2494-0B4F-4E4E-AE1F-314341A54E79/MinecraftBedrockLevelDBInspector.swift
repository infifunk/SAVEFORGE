// MARK: - Minecraft Bedrock LevelDB inspector

import Foundation


struct BedrockLevelDBRecord {
    let key: Data
    let value: Data?
    let sequence: UInt64
    var keyText: String { String(data: key, encoding: .utf8) ?? key.map { String(format: "%02x", $0) }.joined() }
}

struct BedrockLevelDBReport {
    let databaseURL: URL
    let currentManifest: String
    let tableFiles: [String]
    let logFiles: [String]
    let walRecords: [BedrockLevelDBRecord]
    let warnings: [String]
    var latestRecords: [BedrockLevelDBRecord] {
        var latest: [Data: BedrockLevelDBRecord] = [:]
        for record in walRecords {
            if let old = latest[record.key], old.sequence > record.sequence { continue }
            latest[record.key] = record
        }
        return latest.values.filter { $0.value != nil }.sorted { $0.keyText < $1.keyText }
    }
    var containsLocalPlayerInWAL: Bool { walRecords.contains { $0.key == Data("~local_player".utf8) && $0.value != nil } }
    var containsPlayerKeyInWAL: Bool { walRecords.contains { $0.keyText.hasPrefix("player_") && $0.value != nil } }
}

enum BedrockLevelDBInspector {
    static func inspect(databaseAt url: URL) throws -> BedrockLevelDBReport {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw InspectorError.databaseDirectoryMissing
        }
        let names = try fm.contentsOfDirectory(atPath: url.path)
        guard let current = names.first(where: { $0 == "CURRENT" }) else { throw InspectorError.currentMissing }
        let manifestName = try String(contentsOf: url.appendingPathComponent(current), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard manifestName.hasPrefix("MANIFEST-") else { throw InspectorError.invalidCurrent }
        guard names.contains(manifestName) else { throw InspectorError.manifestMissing(manifestName) }

        let tables = names.filter { $0.hasSuffix(".ldb") || $0.hasSuffix(".sst") }.sorted()
        let logs = names.filter { $0.hasSuffix(".log") && Int($0.dropLast(4)) != nil }.sorted()
        var records: [BedrockLevelDBRecord] = []
        var warnings: [String] = []
        for log in logs {
            do { records.append(contentsOf: try readWAL(url.appendingPathComponent(log))) }
            catch { warnings.append("\(log): \(error.localizedDescription)") }
        }
        if !tables.isEmpty {
            do {
                let tableReport = try BedrockLevelDBTableReader.read(databaseAt: url)
                records.append(contentsOf: tableReport.entries.map {
                    BedrockLevelDBRecord(key: $0.key, value: $0.valueType == 1 ? $0.value : nil, sequence: $0.sequence)
                })
                warnings.append(contentsOf: tableReport.warnings)
                if tableReport.tablesRead.isEmpty {
                    warnings.append("No SSTable files could be decoded. Player data may be unavailable until the table format is supported.")
                }
            } catch {
                warnings.append("SSTable read failed: \\(error.localizedDescription)")
            }
        }
        if records.isEmpty && !tables.isEmpty { warnings.append("No records could be recovered from the available SSTables or WAL files.") }
        if logs.isEmpty { warnings.append("No numbered WAL files were found. Current records are recovered from SSTables when supported.") }
        return BedrockLevelDBReport(databaseURL: url, currentManifest: manifestName, tableFiles: tables,
                                    logFiles: logs, walRecords: records, warnings: warnings)
    }

    private static func readWAL(_ url: URL) throws -> [BedrockLevelDBRecord] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let blockSize = 32 * 1024
        var offset = 0
        var assembling = Data()
        var records: [BedrockLevelDBRecord] = []
        while offset + 7 <= data.count {
            let inBlock = offset % blockSize
            let remaining = blockSize - inBlock
            if remaining < 7 { offset += remaining; continue }
            let checksum: UInt32 = data.readLE32(offset)
            let length = Int(data.readLE16(offset + 4))
            let type = data[offset + 6]
            if checksum == 0 && length == 0 && type == 0 { offset += 7; continue }
            guard length <= remaining - 7, offset + 7 + length <= data.count else {
                throw InspectorError.corruptWAL("Invalid fragment length")
            }
            let fragment = data.subdata(in: (offset + 7)..<(offset + 7 + length))
            guard maskedCRC32(type: type, payload: fragment) == checksum else {
                throw InspectorError.corruptWAL("CRC32 mismatch")
            }
            switch type {
            case 1:
                assembling = fragment
                records.append(contentsOf: try decodeWriteBatch(assembling))
                assembling.removeAll(keepingCapacity: true)
            case 2:
                assembling = fragment
            case 3:
                guard !assembling.isEmpty else { throw InspectorError.corruptWAL("Unexpected MIDDLE fragment") }
                assembling.append(fragment)
            case 4:
                guard !assembling.isEmpty else { throw InspectorError.corruptWAL("Unexpected LAST fragment") }
                assembling.append(fragment)
                records.append(contentsOf: try decodeWriteBatch(assembling))
                assembling.removeAll(keepingCapacity: true)
            default:
                throw InspectorError.corruptWAL("Unknown WAL fragment type \(type)")
            }
            offset += 7 + length
        }
        return records
    }

    private static func decodeWriteBatch(_ data: Data) throws -> [BedrockLevelDBRecord] {
        guard data.count >= 12 else { throw InspectorError.corruptWAL("WriteBatch header is truncated") }
        let sequence: UInt64 = data.readLE64(0)
        let count: UInt32 = data.readLE32(8)
        guard count <= 1_000_000 else { throw InspectorError.corruptWAL("WriteBatch count is unreasonable") }
        var cursor = 12
        var result: [BedrockLevelDBRecord] = []
        for index in 0..<Int(count) {
            guard cursor < data.count else { throw InspectorError.corruptWAL("WriteBatch entry is truncated") }
            let tag = data[cursor]; cursor += 1
            let key = try readLengthPrefixed(data, cursor: &cursor)
            if tag == 1 {
                let value = try readLengthPrefixed(data, cursor: &cursor)
                result.append(BedrockLevelDBRecord(key: key, value: value, sequence: sequence + UInt64(index)))
            } else if tag == 0 {
                result.append(BedrockLevelDBRecord(key: key, value: nil, sequence: sequence + UInt64(index)))
            } else { throw InspectorError.corruptWAL("Unknown WriteBatch tag") }
        }
        guard cursor == data.count else { throw InspectorError.corruptWAL("Unexpected trailing WriteBatch bytes") }
        return result
    }

    private static func readLengthPrefixed(_ data: Data, cursor: inout Int) throws -> Data {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        while cursor < data.count && shift <= 63 {
            let byte = data[cursor]; cursor += 1
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 {
                guard value <= UInt64(data.count - cursor) else { throw InspectorError.corruptWAL("Length-prefixed field exceeds record") }
                let length = Int(value)
                let result = data.subdata(in: cursor..<(cursor + length)); cursor += length
                return result
            }
            shift += 7
        }
        throw InspectorError.corruptWAL("Invalid varint length")
    }

    private static func maskedCRC32(type: UInt8, payload: Data) -> UInt32 {
        var bytes = Data([type]); bytes.append(payload)
        let crc = crc32(bytes)
        return ((crc >> 15) | (crc << 17)) &+ 0xa282ead8
    }
    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x82f63b78 : crc >> 1 }
        }
        return ~crc
    }

    enum InspectorError: Error, LocalizedError {
        case databaseDirectoryMissing, currentMissing, invalidCurrent, manifestMissing(String), corruptWAL(String)
        var errorDescription: String? {
            switch self {
            case .databaseDirectoryMissing: return "The selected db folder does not exist."
            case .currentMissing: return "The LevelDB CURRENT file is missing."
            case .invalidCurrent: return "CURRENT does not point to a valid MANIFEST file."
            case .manifestMissing(let name): return "The active manifest is missing: \(name)."
            case .corruptWAL(let reason): return "The LevelDB write-ahead log is invalid: \(reason)."
            }
        }
    }
}

private extension Data {
    func readLE16(_ offset: Int) -> UInt16 { UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8) }
    func readLE32(_ offset: Int) -> UInt32 { UInt32(self[offset]) | (UInt32(self[offset + 1]) << 8) | (UInt32(self[offset + 2]) << 16) | (UInt32(self[offset + 3]) << 24) }
    func readLE64(_ offset: Int) -> UInt64 { UInt64(readLE32(offset)) | (UInt64(readLE32(offset + 4)) << 32) }
}
