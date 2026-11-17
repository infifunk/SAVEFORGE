// MARK: - SAVEFORGE hosted Minecraft item assets
// Downloads the dedicated Items.zip release, extracts it into the app's
// Documents cache, and resolves item identifiers to the PNGs in that archive.

import Foundation
import UIKit
import Compression

enum MinecraftReleaseItemAssets {
    static let archiveURL = URL(string: "https://github.com/infifunk/SAVEFORGE/releases/download/assets-v1/Items.zip")!
    private static var root: URL { MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("ReleaseItems", isDirectory: true) }
    private static var archiveFile: URL { MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("Items.zip") }
    private static let lock = NSLock()
    private static var imageIndex: [String: URL] = [:]
    private static var mapping: [String: [String]] = [:]
    private static var indexed = false

    static var installedPNGCount: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return recursiveFiles(in: root).filter { $0.pathExtension.lowercased() == "png" }.count
    }

    static func cachedImage(for identifier: String) -> UIImage? {
        buildIndexIfNeeded()
        let key = normalize(identifier)
        guard !key.isEmpty else { return nil }
        var candidates = [key]
        candidates.append(contentsOf: mapping[key] ?? [])
        candidates.append(key.replacingOccurrences(of: "_", with: ""))
        for candidate in candidates {
            let base = URL(fileURLWithPath: candidate).deletingPathExtension().lastPathComponent.lowercased()
            if let url = imageIndex[base], let image = UIImage(contentsOfFile: url.path) { return image }
        }
        return nil
    }

    static func download(progress: @escaping (String) -> Void, completion: @escaping (Result<Int, Error>) -> Void) {
        lock.lock()
        let busy = downloadInProgress
        if !busy { downloadInProgress = true }
        lock.unlock()
        guard !busy else { return }

        progress("Downloading SAVEFORGE Minecraft icon archive…")
        URLSession.shared.downloadTask(with: archiveURL) { temporaryURL, response, error in
            if let error { finish(.failure(error), completion); return }
            guard let temporaryURL, (response as? HTTPURLResponse)?.statusCode == 200 else {
                finish(.failure(assetError("GitHub did not return the icon archive.")), completion)
                return
            }
            do {
                try FileManager.default.createDirectory(at: MinecraftBedrockItemIcons.cacheDirectory, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: archiveFile.path) { try FileManager.default.removeItem(at: archiveFile) }
                try FileManager.default.moveItem(at: temporaryURL, to: archiveFile)
                let staging = MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("ReleaseItems-Install", isDirectory: true)
                if FileManager.default.fileExists(atPath: staging.path) { try FileManager.default.removeItem(at: staging) }
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                progress("Installing PNG collection…")
                try extractZIP(at: archiveFile, to: staging)
                let pngs = recursiveFiles(in: staging).filter { $0.pathExtension.lowercased() == "png" }
                guard !pngs.isEmpty else { throw assetError("Items.zip downloaded, but no PNG files were found inside it.") }
                if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
                try FileManager.default.moveItem(at: staging, to: root)
                lock.lock(); indexed = false; imageIndex.removeAll(); mapping.removeAll(); lock.unlock()
                buildIndexIfNeeded()
                finish(.success(pngs.count), completion)
            } catch {
                finish(.failure(error), completion)
            }
        }.resume()
    }

    private static var downloadInProgress = false

    private static func finish(_ result: Result<Int, Error>, _ completion: @escaping (Result<Int, Error>) -> Void) {
        lock.lock(); downloadInProgress = false; lock.unlock()
        DispatchQueue.main.async { completion(result) }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "minecraft:", with: "")
            .replacingOccurrences(of: "textures/items/", with: "")
            .replacingOccurrences(of: "textures/blocks/", with: "")
            .replacingOccurrences(of: ".png", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func buildIndexIfNeeded() {
        lock.lock()
        if indexed { lock.unlock(); return }
        lock.unlock()

        var newIndex: [String: URL] = [:]
        for file in recursiveFiles(in: root) where file.pathExtension.lowercased() == "png" {
            let name = file.deletingPathExtension().lastPathComponent.lowercased()
            if newIndex[name] == nil { newIndex[name] = file }
            let flattened = name.replacingOccurrences(of: "/", with: "_")
            if newIndex[flattened] == nil { newIndex[flattened] = file }
        }

        var newMapping: [String: [String]] = [:]
        let jsonFiles = recursiveFiles(in: root).filter {
            $0.lastPathComponent.lowercased() == "item_texture_mapping.json"
        }
        for json in jsonFiles {
            guard let data = try? Data(contentsOf: json),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            for (rawKey, rawValue) in object {
                let key = normalize(rawKey)
                guard !key.isEmpty else { continue }
                let values = strings(in: rawValue).map { normalize($0) }
                    .filter { !$0.isEmpty }
                if !values.isEmpty { newMapping[key] = values }
            }
        }

        lock.lock()
        imageIndex = newIndex
        mapping = newMapping
        indexed = true
        lock.unlock()
    }

    private static func strings(in value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap { strings(in: $0) } }
        if let dictionary = value as? [String: Any] { return dictionary.keys.sorted().flatMap { strings(in: dictionary[$0]!) } }
        return []
    }

    private static func recursiveFiles(in directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        return enumerator.compactMap { $0 as? URL }
    }

    private static func extractZIP(at archive: URL, to destination: URL) throws {
        let data = try Data(contentsOf: archive, options: .mappedIfSafe)
        guard data.count >= 22, let eocd = findEOCD(data) else { throw assetError("The downloaded ZIP archive is invalid or unsupported.") }
        let count = Int(read16(data, eocd + 10))
        var cursor = Int(read32(data, eocd + 16))
        for _ in 0..<count {
            guard cursor + 46 <= data.count, read32(data, cursor) == 0x02014b50 else { throw assetError("The ZIP directory is damaged.") }
            let flags = read16(data, cursor + 8)
            let method = read16(data, cursor + 10)
            let compressedSize = Int(read32(data, cursor + 20))
            let outputSize = Int(read32(data, cursor + 24))
            let nameLength = Int(read16(data, cursor + 28))
            let extraLength = Int(read16(data, cursor + 30))
            let commentLength = Int(read16(data, cursor + 32))
            let localOffset = Int(read32(data, cursor + 42))
            guard cursor + 46 + nameLength + extraLength + commentLength <= data.count else { throw assetError("A ZIP filename record is damaged.") }
            let nameData = data.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            let name = String(data: nameData, encoding: .utf8) ?? ""
            cursor += 46 + nameLength + extraLength + commentLength
            guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\"), !name.split(separator: "/").contains(".."), (flags & 1) == 0 else { throw assetError("The ZIP contains an unsafe or encrypted entry.") }
            let outputURL = destination.appendingPathComponent(name)
            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
                continue
            }
            guard localOffset + 30 <= data.count, read32(data, localOffset) == 0x04034b50 else { throw assetError("A ZIP file entry has an invalid header.") }
            let localName = Int(read16(data, localOffset + 26))
            let localExtra = Int(read16(data, localOffset + 28))
            let start = localOffset + 30 + localName + localExtra
            guard compressedSize >= 0, outputSize >= 0, start + compressedSize <= data.count else { throw assetError("A ZIP file entry is truncated.") }
            let compressed = data.subdata(in: start..<(start + compressedSize))
            let output: Data
            switch method {
            case 0: output = compressed
            case 8: output = try inflate(compressed, expectedSize: outputSize)
            default: throw assetError("The icon archive uses unsupported ZIP compression.")
            }
            guard output.count == outputSize else { throw assetError("A ZIP entry failed decompression.") }
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try output.write(to: outputURL, options: .atomic)
        }
    }

    private static func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        var output = Data(count: expectedSize)
        let decoded = output.withUnsafeMutableBytes { outBuffer in
            input.withUnsafeBytes { inBuffer in
                guard let out = outBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let bytes = inBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_decode_buffer(out, expectedSize, bytes, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard decoded == expectedSize else { throw assetError("Could not decompress the Minecraft icon archive.") }
        return output
    }

    private static func findEOCD(_ data: Data) -> Int? {
        let lower = max(0, data.count - 65_557)
        guard data.count >= 22 else { return nil }
        for offset in stride(from: data.count - 22, through: lower, by: -1) {
            if read32(data, offset) == 0x06054b50 { return offset }
        }
        return nil
    }

    private static func read16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func read32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset]) | (UInt32(data[offset + 1]) << 8) | (UInt32(data[offset + 2]) << 16) | (UInt32(data[offset + 3]) << 24)
    }

    private static func assetError(_ message: String) -> NSError {
        NSError(domain: "SAVEFORGE.MinecraftAssets", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
