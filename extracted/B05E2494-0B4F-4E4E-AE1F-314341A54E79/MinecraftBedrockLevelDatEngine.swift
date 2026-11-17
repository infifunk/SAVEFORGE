// MARK: - Minecraft Bedrock level.dat engine

import Foundation

// MARK: - SAVEFORGE Bedrock level.dat engine

enum BedrockNBTValue {
    case byte(Int8), short(Int16), int(Int32), long(Int64)
    case float(Float), double(Double), byteArray(Data), string(String)
    case list(UInt8, [BedrockNBTValue]), compound([String: BedrockNBTValue])
    case intArray([Int32]), longArray([Int64])
}

struct BedrockLevelDatDocument {
    let headerVersion: Int32
    var rootName: String
    var root: [String: BedrockNBTValue]

    var worldName: String? { if case .string(let value) = root["LevelName"] { return value }; return nil }
    var seed: Int64? { if case .long(let value) = root["RandomSeed"] { return value }; if case .int(let value) = root["RandomSeed"] { return Int64(value) }; return nil }
    var gameType: Int32? { if case .int(let value) = root["GameType"] { return value }; return nil }
    var difficulty: Int32? { if case .int(let value) = root["Difficulty"] { return value }; return nil }

    func value(_ key: String) -> BedrockNBTValue? { root[key] }

    mutating func setString(_ key: String, _ value: String) { root[key] = .string(value) }
    mutating func setInt(_ key: String, _ value: Int32) { root[key] = .int(value) }
    mutating func setLong(_ key: String, _ value: Int64) { root[key] = .long(value) }

    func encoded() throws -> Data {
        var payload = Data()
        payload.append(10)
        try BedrockNBTCodec.writeString(rootName, to: &payload)
        try BedrockNBTCodec.writeCompound(root, to: &payload)
        var result = Data()
        result.appendLE(headerVersion)
        result.appendLE(Int32(payload.count))
        result.append(payload)
        return result
    }
}

extension BedrockLevelDatDocument {
    static func encodeRootCompound(_ root: [String: BedrockNBTValue], name: String = "") throws -> Data {
        var payload = Data()
        payload.append(10)
        try BedrockNBTCodec.writeString(name, to: &payload)
        try BedrockNBTCodec.writeCompound(root, to: &payload)
        return payload
    }

    static func decodeRootCompound(_ data: Data) throws -> [String: BedrockNBTValue] {
        var reader = BedrockNBTReader(data: data)
        let tag = try reader.readByte()
        guard tag == 10 else { throw BedrockNBTError.rootMustBeCompound }
        _ = try reader.readString()
        let root = try reader.readCompound()
        guard reader.isAtEnd else { throw BedrockNBTError.trailingData }
        return root
    }

    static func read(from url: URL) throws -> BedrockLevelDatDocument {
        let data = try Data(contentsOf: url)
        guard data.count >= 9 else { throw BedrockNBTError.invalidHeader }
        let version: Int32 = data.readLE(at: 0)
        let declaredLength: Int32 = data.readLE(at: 4)
        guard declaredLength >= 0, Int(declaredLength) == data.count - 8 else {
            throw BedrockNBTError.invalidLength
        }
        var reader = BedrockNBTReader(data: data.subdata(in: 8..<data.count))
        let tag = try reader.readByte()
        guard tag == 10 else { throw BedrockNBTError.rootMustBeCompound }
        let name = try reader.readString()
        let root = try reader.readCompound()
        guard reader.isAtEnd else { throw BedrockNBTError.trailingData }
        return BedrockLevelDatDocument(headerVersion: version, rootName: name, root: root)
    }

    func writeAtomically(to url: URL, makeBackup: Bool = true) throws {
        let output = try encoded()
        let manager = FileManager.default
        if makeBackup, manager.fileExists(atPath: url.path) {
            let backup = url.deletingLastPathComponent().appendingPathComponent("level.dat.saveforge-backup")
            if manager.fileExists(atPath: backup.path) { try manager.removeItem(at: backup) }
            try manager.copyItem(at: url, to: backup)
        }
        let temporary = url.deletingLastPathComponent().appendingPathComponent("level.dat.saveforge-tmp")
        try output.write(to: temporary, options: .atomic)
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
        try manager.moveItem(at: temporary, to: url)
        do { _ = try BedrockLevelDatDocument.read(from: url) }
        catch {
            if makeBackup {
                let backup = url.deletingLastPathComponent().appendingPathComponent("level.dat.saveforge-backup")
                if manager.fileExists(atPath: backup.path) {
                    if manager.fileExists(atPath: url.path) { try? manager.removeItem(at: url) }
                    try? manager.copyItem(at: backup, to: url)
                }
            }
            throw error
        }
    }
}

private enum BedrockNBTError: Error, LocalizedError {
    case invalidHeader, invalidLength, rootMustBeCompound, unsupportedTag(UInt8)
    case truncated, invalidString, invalidList, invalidArray, trailingData, excessiveNesting
    var errorDescription: String? {
        switch self {
        case .invalidHeader: return "The level.dat header is invalid."
        case .invalidLength: return "The level.dat payload length does not match its header."
        case .rootMustBeCompound: return "The Bedrock NBT root is not a compound."
        case .unsupportedTag(let id): return "Unsupported NBT tag type: \(id)."
        case .truncated: return "The NBT data ended unexpectedly."
        case .invalidString: return "The NBT string is invalid UTF-8."
        case .invalidList: return "The NBT list has an invalid element type or length."
        case .invalidArray: return "The NBT array length is invalid."
        case .trailingData: return "Unexpected bytes follow the NBT root compound."
        case .excessiveNesting: return "The NBT structure exceeds the safe nesting limit."
        }
    }
}

private struct BedrockNBTReader {
    let data: Data
    var offset = 0
    var isAtEnd: Bool { offset == data.count }

    mutating func readByte() throws -> UInt8 { guard offset < data.count else { throw BedrockNBTError.truncated }; defer { offset += 1 }; return data[offset] }
    mutating func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let size = MemoryLayout<T>.size
        guard offset + size <= data.count else { throw BedrockNBTError.truncated }
        let value: T = data.readLE(at: offset); offset += size; return value
    }
    mutating func readString() throws -> String {
        let length = Int(try read(UInt16.self))
        guard length >= 0, offset + length <= data.count else { throw BedrockNBTError.truncated }
        let bytes = data.subdata(in: offset..<(offset + length)); offset += length
        guard let value = String(data: bytes, encoding: .utf8) else { throw BedrockNBTError.invalidString }
        return value
    }
    mutating func readCompound(depth: Int = 0) throws -> [String: BedrockNBTValue] {
        guard depth < 512 else { throw BedrockNBTError.excessiveNesting }
        var values: [String: BedrockNBTValue] = [:]
        while true {
            let type = try readByte()
            if type == 0 { return values }
            let name = try readString()
            values[name] = try readPayload(type, depth: depth + 1)
        }
    }
    mutating func readPayload(_ type: UInt8, depth: Int) throws -> BedrockNBTValue {
        guard depth < 512 else { throw BedrockNBTError.excessiveNesting }
        switch type {
        case 1: return .byte(Int8(bitPattern: try readByte()))
        case 2: return .short(try read(Int16.self))
        case 3: return .int(try read(Int32.self))
        case 4: return .long(try read(Int64.self))
        case 5: return .float(Float(bitPattern: try read(UInt32.self)))
        case 6: return .double(Double(bitPattern: try read(UInt64.self)))
        case 7:
            let count = try checkedCount(); guard offset + count <= data.count else { throw BedrockNBTError.truncated }
            let bytes = data.subdata(in: offset..<(offset + count)); offset += count; return .byteArray(bytes)
        case 8: return .string(try readString())
        case 9:
            let elementType = try readByte(); let count = try checkedCount()
            guard elementType <= 12, (count == 0 || elementType != 0) else { throw BedrockNBTError.invalidList }
            var values: [BedrockNBTValue] = []; values.reserveCapacity(count)
            for _ in 0..<count { values.append(try readPayload(elementType, depth: depth + 1)) }
            return .list(elementType, values)
        case 10: return .compound(try readCompound(depth: depth + 1))
        case 11:
            let count = try checkedCount(); guard count <= (data.count - offset) / 4 else { throw BedrockNBTError.invalidArray }
            var values: [Int32] = []; values.reserveCapacity(count)
            for _ in 0..<count { values.append(try read(Int32.self)) }; return .intArray(values)
        case 12:
            let count = try checkedCount(); guard count <= (data.count - offset) / 8 else { throw BedrockNBTError.invalidArray }
            var values: [Int64] = []; values.reserveCapacity(count)
            for _ in 0..<count { values.append(try read(Int64.self)) }; return .longArray(values)
        default: throw BedrockNBTError.unsupportedTag(type)
        }
    }
    mutating func checkedCount() throws -> Int {
        let value = try read(Int32.self)
        guard value >= 0, value <= 10_000_000 else { throw BedrockNBTError.invalidArray }
        return Int(value)
    }
}

private enum BedrockNBTCodec {
    static func writeString(_ value: String, to data: inout Data) throws {
        let bytes = Data(value.utf8)
        guard bytes.count <= Int(UInt16.max) else { throw BedrockNBTError.invalidString }
        data.appendLE(UInt16(bytes.count)); data.append(bytes)
    }
    static func writeCompound(_ values: [String: BedrockNBTValue], to data: inout Data, depth: Int = 0) throws {
        guard depth < 512 else { throw BedrockNBTError.excessiveNesting }
        for key in values.keys.sorted() {
            guard let value = values[key] else { continue }
            let type = tagID(value); data.append(type); try writeString(key, to: &data)
            try writePayload(value, to: &data, depth: depth + 1)
        }
        data.append(0)
    }
    static func tagID(_ value: BedrockNBTValue) -> UInt8 {
        switch value {
        case .byte: return 1; case .short: return 2; case .int: return 3; case .long: return 4
        case .float: return 5; case .double: return 6; case .byteArray: return 7; case .string: return 8
        case .list: return 9; case .compound: return 10; case .intArray: return 11; case .longArray: return 12
        }
    }
    static func writePayload(_ value: BedrockNBTValue, to data: inout Data, depth: Int) throws {
        switch value {
        case .byte(let v): data.append(UInt8(bitPattern: v))
        case .short(let v): data.appendLE(v)
        case .int(let v): data.appendLE(v)
        case .long(let v): data.appendLE(v)
        case .float(let v): data.appendLE(v.bitPattern)
        case .double(let v): data.appendLE(v.bitPattern)
        case .byteArray(let v): data.appendLE(Int32(v.count)); data.append(v)
        case .string(let v): try writeString(v, to: &data)
        case .list(let type, let values):
            data.append(type); data.appendLE(Int32(values.count))
            for item in values { guard tagID(item) == type else { throw BedrockNBTError.invalidList }; try writePayload(item, to: &data, depth: depth + 1) }
        case .compound(let values): try writeCompound(values, to: &data, depth: depth + 1)
        case .intArray(let values): data.appendLE(Int32(values.count)); for item in values { data.appendLE(item) }
        case .longArray(let values): data.appendLE(Int32(values.count)); for item in values { data.appendLE(item) }
        }
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
    func readLE<T: FixedWidthInteger>(at offset: Int) -> T {
        var value: T = 0
        Swift.withUnsafeMutableBytes(of: &value) { raw in
            _ = self.copyBytes(to: raw, from: offset..<(offset + MemoryLayout<T>.size))
        }
        return T(littleEndian: value)
    }
}
