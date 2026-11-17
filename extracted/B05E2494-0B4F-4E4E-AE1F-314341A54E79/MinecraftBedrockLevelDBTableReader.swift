// MARK: - Minecraft Bedrock LevelDB table reader

import Foundation

struct BedrockLevelDBTableEntry {
    let key: Data
    let value: Data
    let sequence: UInt64
    let valueType: UInt8
}

struct BedrockLevelDBTableReport {
    let entries: [BedrockLevelDBTableEntry]
    let tablesRead: [String]
    let warnings: [String]
    var latestValues: [Data: Data] {
        var latest: [Data: BedrockLevelDBTableEntry] = [:]
        for entry in entries {
            if let old = latest[entry.key], old.sequence > entry.sequence { continue }
            latest[entry.key] = entry
        }
        var result: [Data: Data] = [:]
        for (key, entry) in latest where entry.valueType == 1 { result[key] = entry.value }
        return result
    }
}

enum BedrockLevelDBTableReader {
    private static let magic: UInt64 = 0xdb4775248b80fb57

    static func read(databaseAt directory: URL) throws -> BedrockLevelDBTableReport {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let tables = files.filter { $0.pathExtension == "ldb" || $0.pathExtension == "sst" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var all: [BedrockLevelDBTableEntry] = []
        var readNames: [String] = []
        var warnings: [String] = []
        for table in tables {
            do {
                let entries = try readTable(table)
                all.append(contentsOf: entries)
                readNames.append(table.lastPathComponent)
            } catch {
                warnings.append("\(table.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return BedrockLevelDBTableReport(entries: all, tablesRead: readNames, warnings: warnings)
    }

    private static func readTable(_ url: URL) throws -> [BedrockLevelDBTableEntry] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 48, data.u64(data.count - 8) == magic else { throw TableError.invalidFooter }
        let footerStart = data.count - 48
        var cursor = footerStart
        _ = try readHandle(data, cursor: &cursor)
        let indexHandle = try readHandle(data, cursor: &cursor)
        guard indexHandle.offset + indexHandle.size + 5 <= UInt64(data.count - 48) else { throw TableError.invalidBlockHandle }
        let index = try readBlock(data, handle: indexHandle)
        let indexEntries = try decodeBlock(index)
        var result: [BedrockLevelDBTableEntry] = []
        for entry in indexEntries {
            var c = 0
            let handle = try readHandle(entry.value, cursor: &c)
            guard handle.offset + handle.size + 5 <= UInt64(data.count - 48) else { throw TableError.invalidBlockHandle }
            let block = try readBlock(data, handle: handle)
            for pair in try decodeBlock(block) {
                guard pair.key.count >= 8 else { continue }
                let trailer = pair.key.u64(pair.key.count - 8)
                let type = UInt8(trailer & 0xff)
                let sequence = trailer >> 8
                let userKey = pair.key.subdata(in: 0..<(pair.key.count - 8))
                if type == 1 || type == 0 { result.append(BedrockLevelDBTableEntry(key: userKey, value: pair.value, sequence: sequence, valueType: type)) }
            }
        }
        return result
    }

    private struct Handle { let offset: UInt64; let size: UInt64 }
    private struct Pair { let key: Data; let value: Data }

    private static func readHandle(_ data: Data, cursor: inout Int) throws -> Handle {
        let offset = try readVarint(data, cursor: &cursor)
        let size = try readVarint(data, cursor: &cursor)
        return Handle(offset: offset, size: size)
    }

    private static func readBlock(_ data: Data, handle: Handle) throws -> Data {
        let start = Int(handle.offset), size = Int(handle.size)
        guard start >= 0, size >= 0, start + size + 5 <= data.count else { throw TableError.invalidBlockHandle }
        let payload = data.subdata(in: start..<(start + size))
        let compression = data[start + size]
        switch compression {
        case 0: return payload
        case 1: return try Snappy.decode(payload)
        case 2: return try ZlibBlock.decode(payload, raw: false)
        case 4: return try ZlibBlock.decode(payload, raw: true)
        default: throw TableError.unsupportedCompression(compression)
        }
    }

    private static func decodeBlock(_ data: Data) throws -> [Pair] {
        guard data.count >= 4 else { throw TableError.invalidBlock }
        let restartCount = Int(data.u32(data.count - 4))
        guard restartCount >= 1, restartCount <= data.count / 4 else { throw TableError.invalidBlock }
        let entriesEnd = data.count - 4 - restartCount * 4
        guard entriesEnd >= 0 else { throw TableError.invalidBlock }
        var cursor = 0
        var previous = Data()
        var result: [Pair] = []
        while cursor < entriesEnd {
            let shared = Int(try readVarint32(data, cursor: &cursor))
            let nonShared = Int(try readVarint32(data, cursor: &cursor))
            let valueLength = Int(try readVarint32(data, cursor: &cursor))
            guard shared <= previous.count, nonShared >= 0, valueLength >= 0,
                  cursor + nonShared + valueLength <= entriesEnd else { throw TableError.invalidBlock }
            var key = previous.prefix(shared)
            key.append(data.subdata(in: cursor..<(cursor + nonShared)))
            cursor += nonShared
            let value = data.subdata(in: cursor..<(cursor + valueLength))
            cursor += valueLength
            result.append(Pair(key: Data(key), value: value))
            previous = Data(key)
        }
        return result
    }

    private static func readVarint(_ data: Data, cursor: inout Int) throws -> UInt64 {
        var value: UInt64 = 0, shift: UInt64 = 0
        while cursor < data.count && shift < 64 {
            let b = data[cursor]; cursor += 1
            value |= UInt64(b & 0x7f) << shift
            if b & 0x80 == 0 { return value }
            shift += 7
        }
        throw TableError.invalidVarint
    }
    private static func readVarint32(_ data: Data, cursor: inout Int) throws -> UInt32 {
        let value = try readVarint(data, cursor: &cursor)
        guard value <= UInt64(UInt32.max) else { throw TableError.invalidVarint }
        return UInt32(value)
    }

    enum TableError: Error, LocalizedError {
        case invalidFooter, invalidBlockHandle, invalidBlock, invalidVarint, unsupportedCompression(UInt8)
        var errorDescription: String? {
            switch self {
            case .invalidFooter: return "SSTable footer or magic number is invalid."
            case .invalidBlockHandle: return "SSTable block handle points outside the table."
            case .invalidBlock: return "SSTable data block is malformed."
            case .invalidVarint: return "SSTable varint is malformed."
            case .unsupportedCompression(let type): return "Unsupported SSTable compression type \(type)."
            }
        }
    }
}

private enum ZlibBlock {
    private struct ZStream {
        var nextIn: UnsafeMutablePointer<UInt8>?
        var availIn: UInt32 = 0
        var totalIn: UInt = 0
        var nextOut: UnsafeMutablePointer<UInt8>?
        var availOut: UInt32 = 0
        var totalOut: UInt = 0
        var message: UnsafePointer<CChar>?
        var state: UnsafeMutableRawPointer?
        var allocate: UnsafeMutableRawPointer?
        var release: UnsafeMutableRawPointer?
        var opaque: UnsafeMutableRawPointer?
        var dataType: Int32 = 0
        var adler: UInt = 0
        var reserved: UInt = 0
    }

    @_silgen_name("zlibVersion") private static func zlibVersion() -> UnsafePointer<CChar>
    @_silgen_name("inflateInit2_") private static func inflateInit2(_ stream: UnsafeMutablePointer<ZStream>, _ windowBits: Int32, _ version: UnsafePointer<CChar>, _ streamSize: Int32) -> Int32
    @_silgen_name("inflate") private static func inflate(_ stream: UnsafeMutablePointer<ZStream>, _ flush: Int32) -> Int32
    @_silgen_name("inflateEnd") private static func inflateEnd(_ stream: UnsafeMutablePointer<ZStream>) -> Int32

    static func decode(_ input: Data, raw: Bool) throws -> Data {
        guard !input.isEmpty, input.count <= Int(UInt32.max) else { throw Error.decompressionFailed }
        var stream = ZStream()
        let windowBits: Int32 = raw ? -15 : 15
        let initStatus = inflateInit2(&stream, windowBits, zlibVersion(), Int32(MemoryLayout<ZStream>.size))
        guard initStatus == 0 else { throw Error.decompressionFailed }
        defer { _ = inflateEnd(&stream) }

        var output = Data()
        output.reserveCapacity(max(4096, input.count * 4))
        let chunkSize = 64 * 1024
        let status: Int32 = input.withUnsafeBytes { source in
            guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else { return -2 }
            stream.nextIn = UnsafeMutablePointer(mutating: sourceBase)
            stream.availIn = UInt32(input.count)
            var result: Int32 = 0
            repeat {
                var chunk = [UInt8](repeating: 0, count: chunkSize)
                let produced = chunk.withUnsafeMutableBufferPointer { buffer -> Int in
                    stream.nextOut = buffer.baseAddress
                    stream.availOut = UInt32(buffer.count)
                    result = inflate(&stream, 0)
                    return buffer.count - Int(stream.availOut)
                }
                if produced > 0 { output.append(contentsOf: chunk.prefix(produced)) }
                if result == 1 { break }
                if result != 0 { return result }
                if produced == 0 && stream.availIn == 0 { return -3 }
                if output.count > 128 * 1024 * 1024 { return -4 }
            } while true
            return result
        }
        guard status == 1, !output.isEmpty else { throw Error.decompressionFailed }
        return output
    }

    enum Error: Swift.Error { case decompressionFailed }
}

private enum Snappy {
    static func decode(_ input: Data) throws -> Data {
        var cursor = 0
        let expected = try varint(input, cursor: &cursor)
        guard expected <= 128 * 1024 * 1024 else { throw Error.invalid }
        var out = Data(); out.reserveCapacity(Int(expected))
        while cursor < input.count && out.count < Int(expected) {
            let tag = input[cursor]; cursor += 1
            switch tag & 3 {
            case 0:
                var length = Int(tag >> 2)
                if length < 60 { length += 1 }
                else {
                    let bytes = length - 59
                    guard bytes >= 1, bytes <= 4, cursor + bytes <= input.count else { throw Error.invalid }
                    length = 0
                    for i in 0..<bytes { length |= Int(input[cursor + i]) << (8 * i) }
                    cursor += bytes; length += 1
                }
                guard length >= 0, cursor + length <= input.count else { throw Error.invalid }
                out.append(input.subdata(in: cursor..<(cursor + length))); cursor += length
            case 1:
                guard cursor < input.count else { throw Error.invalid }
                let length = 4 + Int((tag >> 2) & 7)
                let offset = (Int(tag & 0xe0) << 3) | Int(input[cursor]); cursor += 1
                try copy(offset: offset, length: length, output: &out)
            case 2:
                guard cursor + 2 <= input.count else { throw Error.invalid }
                let length = 1 + Int(tag >> 2)
                let offset = Int(input[cursor]) | (Int(input[cursor + 1]) << 8); cursor += 2
                try copy(offset: offset, length: length, output: &out)
            default:
                guard cursor + 4 <= input.count else { throw Error.invalid }
                let length = 1 + Int(tag >> 2)
                let offset = Int(input.u32(cursor)); cursor += 4
                try copy(offset: offset, length: length, output: &out)
            }
        }
        guard out.count == Int(expected) else { throw Error.invalid }
        return out
    }
    private static func copy(offset: Int, length: Int, output: inout Data) throws {
        guard offset > 0, offset <= output.count, length >= 0 else { throw Error.invalid }
        for _ in 0..<length { output.append(output[output.count - offset]) }
    }
    private static func varint(_ data: Data, cursor: inout Int) throws -> UInt64 {
        var v: UInt64 = 0, shift: UInt64 = 0
        while cursor < data.count && shift < 64 {
            let b = data[cursor]; cursor += 1; v |= UInt64(b & 0x7f) << shift
            if b & 0x80 == 0 { return v }; shift += 7
        }
        throw Error.invalid
    }
    enum Error: Swift.Error { case invalid }
}

private extension Data {
    func u32(_ i: Int) -> UInt32 { UInt32(self[i]) | UInt32(self[i+1]) << 8 | UInt32(self[i+2]) << 16 | UInt32(self[i+3]) << 24 }
    func u64(_ i: Int) -> UInt64 { UInt64(u32(i)) | UInt64(u32(i+4)) << 32 }
}
