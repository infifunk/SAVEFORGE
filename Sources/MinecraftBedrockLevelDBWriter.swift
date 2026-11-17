// MARK: - Minecraft Bedrock LevelDB writer

import Foundation

struct BedrockLevelDBMutation {
    let key: Data
    let value: Data?
}

struct BedrockLevelDBCommitReport {
    let outputDatabaseURL: URL
    let walFile: String
    let firstSequence: UInt64
    let lastSequence: UInt64
    let mutationCount: Int
    let validationPassed: Bool
}

enum BedrockLevelDBWriter {
    static func commit(_ mutations: [BedrockLevelDBMutation], copying source: URL, to destination: URL) throws -> BedrockLevelDBCommitReport {
        guard !mutations.isEmpty else { throw Error.emptyBatch }
        guard !FileManager.default.fileExists(atPath: destination.path) else { throw Error.destinationExists }
        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
        do {
            let currentData = try Data(contentsOf: destination.appendingPathComponent("CURRENT"))
            guard let manifestName = String(data: currentData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), manifestName.hasPrefix("MANIFEST-") else { throw Error.invalidCurrent }
            let manifestURL = destination.appendingPathComponent(manifestName)
            var manifest = try Data(contentsOf: manifestURL)
            let state = try parseManifest(manifest)
            var activeLogNumber = state.logNumber
            var activeLogURL = destination.appendingPathComponent(String(format: "%06llu.log", activeLogNumber))
            let createFreshLog = !fm.fileExists(atPath: activeLogURL.path)
            if createFreshLog {
                activeLogNumber = max(state.nextFileNumber, state.logNumber &+ 1)
                guard activeLogNumber > state.logNumber, activeLogNumber < UInt64.max else {
                    throw Error.sequenceOverflow
                }
                activeLogURL = destination.appendingPathComponent(String(format: "%06llu.log", activeLogNumber))
                guard !fm.fileExists(atPath: activeLogURL.path) else { throw Error.logAllocationCollision }
                guard fm.createFile(atPath: activeLogURL.path, contents: Data()) else { throw Error.logCreationFailed }
            }

            let existingRecords = createFreshLog ? [] : try readLog(activeLogURL)
            let highestWALSequence = existingRecords.map(\.sequence).max() ?? 0
            let tableReport = try BedrockLevelDBTableReader.read(databaseAt: destination)
            let highestTableSequence = tableReport.entries.map(\.sequence).max() ?? 0
            let sequenceBase = max(state.lastSequence, max(highestWALSequence, highestTableSequence))
            guard UInt64(mutations.count) > 0,
                  sequenceBase < UInt64.max else { throw Error.sequenceOverflow }
            let firstSequence = sequenceBase + 1
            let mutationCount = UInt64(mutations.count)
            guard firstSequence <= UInt64.max - (mutationCount - 1) else { throw Error.sequenceOverflow }
            let lastSequence = firstSequence + mutationCount - 1

            let batch = try encodeWriteBatch(mutations, firstSequence: firstSequence)
            let existingLogSize = (try fm.attributesOfItem(atPath: activeLogURL.path)[.size] as? NSNumber)?.intValue ?? 0
            let logData = encodeLogRecord(batch, blockOffset: existingLogSize % (32 * 1024))
            let logHandle = try FileHandle(forWritingTo: activeLogURL)
            try logHandle.seekToEnd()
            try logHandle.write(contentsOf: logData)
            try logHandle.synchronize()
            try logHandle.close()
            var edit = Data()
            if createFreshLog {
                edit.appendVarint(2); edit.appendVarint(activeLogNumber)
                edit.appendVarint(3); edit.appendVarint(max(state.nextFileNumber, activeLogNumber &+ 1))
            }
            edit.appendVarint(4); edit.appendVarint(lastSequence)
            let manifestRecord = encodeLogRecord(edit, blockOffset: manifest.count % (32 * 1024))
            manifest.append(manifestRecord)
            try manifest.write(to: manifestURL, options: .atomic)
            try syncFile(manifestURL)
            let verified = try readLog(activeLogURL)
            let committed = Array(verified.suffix(mutations.count))
            guard committed.count == mutations.count,
                  committed.first?.sequence == firstSequence,
                  committed.last?.sequence == lastSequence,
                  committed.enumerated().allSatisfy({ index, record in
                      record.key == mutations[index].key && record.value == mutations[index].value
                  }) else { throw Error.validationFailed }
            let finalState = try parseManifest(manifest)
            guard finalState.logNumber == activeLogNumber, finalState.lastSequence == lastSequence,
                  fm.fileExists(atPath: activeLogURL.path) else { throw Error.validationFailed }
            return BedrockLevelDBCommitReport(outputDatabaseURL: destination, walFile: activeLogURL.lastPathComponent,
                                              firstSequence: firstSequence, lastSequence: lastSequence,
                                              mutationCount: mutations.count, validationPassed: true)
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }

    private struct ManifestState { var logNumber: UInt64 = 0; var nextFileNumber: UInt64 = 1; var lastSequence: UInt64 = 0 }
    private struct Record { let key: Data; let value: Data?; let sequence: UInt64 }

    private static func parseManifest(_ data: Data) throws -> ManifestState {
        var state = ManifestState(), offset = 0
        while offset + 7 <= data.count {
            let length = Int(data.le16(offset + 4)), type = data[offset + 6]
            if length == 0 && type == 0 { offset += 7; continue }
            guard length <= 32 * 1024 - (offset % (32 * 1024)) - 7, offset + 7 + length <= data.count else { throw Error.invalidManifest }
            let payload = data.subdata(in: (offset + 7)..<(offset + 7 + length))
            guard maskedCRC(type: type, payload: payload) == data.le32(offset) else { throw Error.manifestChecksum }
            if type == 1 { try applyVersionEdit(payload, to: &state) }
            else if type == 2 { throw Error.fragmentedManifestUnsupported }
            else { throw Error.invalidManifest }
            offset += 7 + length
        }
        guard state.nextFileNumber > 0 else { throw Error.invalidManifest }
        return state
    }

    private static func applyVersionEdit(_ data: Data, to state: inout ManifestState) throws {
        var c = 0
        while c < data.count {
            let tag = try data.readVarint(&c)
            switch tag {
            case 1: _ = try data.readLengthPrefixed(&c)
            case 2: state.logNumber = try data.readVarint(&c)
            case 3: state.nextFileNumber = try data.readVarint(&c)
            case 4: state.lastSequence = try data.readVarint(&c)
            case 5: _ = try data.readVarint(&c); _ = try data.readLengthPrefixed(&c)
            case 6: _ = try data.readVarint(&c); _ = try data.readVarint(&c)
            case 7:
                _ = try data.readVarint(&c); _ = try data.readVarint(&c)
                _ = try data.readVarint(&c)
                _ = try data.readLengthPrefixed(&c); _ = try data.readLengthPrefixed(&c)
            case 9: _ = try data.readVarint(&c)
            default: throw Error.unknownManifestTag(tag)
            }
        }
    }

    private static func encodeWriteBatch(_ mutations: [BedrockLevelDBMutation], firstSequence: UInt64) throws -> Data {
        var d = Data(); d.appendLE64(firstSequence); d.appendLE32(UInt32(mutations.count))
        for item in mutations {
            d.append(item.value == nil ? 0 : 1)
            d.appendLengthPrefixed(item.key)
            if let value = item.value { d.appendLengthPrefixed(value) }
        }
        return d
    }

    private static func encodeLogRecord(_ payload: Data, blockOffset initialOffset: Int) -> Data {
        let blockSize = 32 * 1024
        var offset = initialOffset
        var cursor = 0
        var output = Data()
        repeat {
            let remaining = blockSize - offset
            if remaining <= 7 {
                output.append(Data(repeating: 0, count: remaining))
                offset = 0
            }
            let available = blockSize - offset - 7
            let length = min(available, payload.count - cursor)
            let isFirst = cursor == 0
            let isLast = cursor + length == payload.count
            let type: UInt8 = isFirst && isLast ? 1 : (isFirst ? 2 : (isLast ? 4 : 3))
            let fragment = payload.subdata(in: cursor..<(cursor + length))
            output.appendLE32(maskedCRC(type: type, payload: fragment))
            output.appendLE16(UInt16(length))
            output.append(type)
            output.append(fragment)
            cursor += length
            offset += 7 + length
            if offset == blockSize { offset = 0 }
        } while cursor < payload.count
        return output
    }

    private static func readLog(_ url: URL) throws -> [Record] {
        let data = try Data(contentsOf: url)
        var offset = 0, assembling = Data(), result: [Record] = []
        while offset + 7 <= data.count {
            let blockRemaining = 32 * 1024 - (offset % (32 * 1024))
            if blockRemaining < 7 { offset += blockRemaining; continue }
            let len = Int(data.le16(offset + 4)), type = data[offset + 6]
            if len == 0 && type == 0 { offset += 7; continue }
            guard len <= blockRemaining - 7, offset + 7 + len <= data.count else { throw Error.validationFailed }
            let fragment = data.subdata(in: (offset + 7)..<(offset + 7 + len))
            guard maskedCRC(type: type, payload: fragment) == data.le32(offset) else { throw Error.validationFailed }
            switch type {
            case 1: assembling = fragment; try appendBatch(assembling, to: &result); assembling.removeAll(keepingCapacity: true)
            case 2: assembling = fragment
            case 3: guard !assembling.isEmpty else { throw Error.validationFailed }; assembling.append(fragment)
            case 4: guard !assembling.isEmpty else { throw Error.validationFailed }; assembling.append(fragment); try appendBatch(assembling, to: &result); assembling.removeAll(keepingCapacity: true)
            default: throw Error.validationFailed
            }
            offset += 7 + len
        }
        return result
    }

    private static func appendBatch(_ payload: Data, to result: inout [Record]) throws {
        guard payload.count >= 12 else { throw Error.validationFailed }
        let seq = payload.le64(0), count = Int(payload.le32(8)); var c = 12
        for i in 0..<count {
            guard c < payload.count else { throw Error.validationFailed }
            let tag = payload[c]; c += 1; let key = try payload.readLengthPrefixed(&c)
            if tag == 1 { let value = try payload.readLengthPrefixed(&c); result.append(Record(key: key, value: value, sequence: seq + UInt64(i))) }
            else if tag == 0 { result.append(Record(key: key, value: nil, sequence: seq + UInt64(i))) }
            else { throw Error.validationFailed }
        }
        guard c == payload.count else { throw Error.validationFailed }
    }

    private static func syncFile(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url); try handle.synchronize(); try handle.close()
    }
    private static func maskedCRC(type: UInt8, payload: Data) -> UInt32 {
        var bytes = Data([type]); bytes.append(payload); let crc = crc32c(bytes)
        return ((crc >> 15) | (crc << 17)) &+ 0xa282ead8
    }
    private static func crc32c(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for b in data { crc ^= UInt32(b); for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x82f63b78 : crc >> 1 } }
        return ~crc
    }

    enum Error: Swift.Error, LocalizedError {
        case emptyBatch, destinationExists, invalidCurrent, invalidManifest, manifestChecksum, activeLogMissing(String), sequenceOverflow
        case logAllocationCollision, logCreationFailed
        case fragmentedManifestUnsupported, validationFailed, unknownManifestTag(UInt64)
        var errorDescription: String? {
            switch self {
            case .emptyBatch: return "There are no database changes to commit."
            case .destinationExists: return "The output database already exists. Choose a new working-copy location."
            case .invalidCurrent: return "CURRENT does not point to a valid MANIFEST file."
            case .invalidManifest: return "The active MANIFEST contains an unsupported or malformed record."
            case .manifestChecksum: return "The active MANIFEST checksum is invalid."
            case .activeLogMissing(let name): return "The active LevelDB log is missing: \(name). No write was committed."
            case .logAllocationCollision: return "A newly allocated LevelDB log filename is already occupied. No write was committed."
            case .logCreationFailed: return "SAVEFORGE could not create the new LevelDB log. No write was committed."
            case .sequenceOverflow: return "The next LevelDB transaction sequence number would overflow. The export was cancelled."
            case .fragmentedManifestUnsupported: return "This MANIFEST uses fragmented records; commit was stopped safely."
            case .validationFailed: return "The new WAL did not pass read-back validation. The output copy was discarded."
            case .unknownManifestTag(let tag): return "Unsupported MANIFEST VersionEdit tag \(tag)."
            }
        }
    }
}

private extension Data {
    func le16(_ i: Int) -> UInt16 { UInt16(self[i]) | UInt16(self[i + 1]) << 8 }
    func le32(_ i: Int) -> UInt32 { UInt32(self[i]) | UInt32(self[i + 1]) << 8 | UInt32(self[i + 2]) << 16 | UInt32(self[i + 3]) << 24 }
    func le64(_ i: Int) -> UInt64 { UInt64(le32(i)) | UInt64(le32(i + 4)) << 32 }
    mutating func appendLE16(_ v: UInt16) { append(UInt8(v & 0xff)); append(UInt8((v >> 8) & 0xff)) }
    mutating func appendLE32(_ v: UInt32) { for i in 0..<4 { append(UInt8((v >> (i * 8)) & 0xff)) } }
    mutating func appendLE64(_ v: UInt64) { for i in 0..<8 { append(UInt8((v >> (i * 8)) & 0xff)) } }
    mutating func appendVarint(_ value: UInt64) { var v = value; while v >= 0x80 { append(UInt8(v & 0x7f) | 0x80); v >>= 7 }; append(UInt8(v)) }
    mutating func appendLengthPrefixed(_ value: Data) { appendVarint(UInt64(value.count)); append(value) }
    func readVarint(_ cursor: inout Int) throws -> UInt64 {
        var value: UInt64 = 0, shift: UInt64 = 0
        while cursor < count && shift < 64 { let b = self[cursor]; cursor += 1; value |= UInt64(b & 0x7f) << shift; if b & 0x80 == 0 { return value }; shift += 7 }
        throw BedrockLevelDBWriter.Error.invalidManifest
    }
    func readLengthPrefixed(_ cursor: inout Int) throws -> Data {
        let n = try readVarint(&cursor); guard n <= UInt64(count - cursor) else { throw BedrockLevelDBWriter.Error.invalidManifest }
        let size = Int(n); let value = subdata(in: cursor..<(cursor + size)); cursor += size; return value
    }
}
