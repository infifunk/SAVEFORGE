// MARK: - Minecraft Bedrock player editing and export

import Foundation

enum MinecraftPlayerEditService {
    enum Field: String, Hashable {
        case health, maximumHealth, hunger, saturation, xpLevel
    }
    private static let stableFieldOrder: [Field] = [.health, .maximumHealth, .hunger, .saturation, .xpLevel]

    static func exportEditedWorld(sourceWorld: URL, field: Field, value: Double) throws -> URL {
        try exportEditedWorld(sourceWorld: sourceWorld, edits: [field: value])
    }

    static func exportEditedWorld(sourceWorld: URL, edits: [Field: Double], abilityEdits: [String: Bool] = [:], inventoryCounts: [Int: Int] = [:], removedInventorySlots: Set<Int> = [], levelEdits: [String: String] = [:], inventoryAdditions: [Int: MinecraftStagedInventoryAddition] = [:], inventoryMoves: [Int: Int] = [:], inventorySwaps: [Int: Int] = [:]) throws -> URL {
        guard !edits.isEmpty || !abilityEdits.isEmpty || !inventoryCounts.isEmpty || !removedInventorySlots.isEmpty || !levelEdits.isEmpty || !inventoryAdditions.isEmpty || !inventoryMoves.isEmpty || !inventorySwaps.isEmpty else { throw EditError.emptyEdits }
        guard levelEdits["RandomSeed"] == nil else { throw EditError.seedLocked }
        for (field, value) in edits {
            guard value.isFinite else { throw EditError.invalidValue }
            switch field {
            case .health, .maximumHealth:
                guard value >= 0 && value <= 2048 else { throw EditError.fieldOutOfRange(field.rawValue, value, "0–2048") }
            case .hunger, .saturation:
                guard value >= 0 && value <= 20 else { throw EditError.fieldOutOfRange(field.rawValue, value, "0–20") }
            case .xpLevel:
                guard value >= 0 && value <= 2_147_483_647 && value.rounded() == value else { throw EditError.fieldOutOfRange(field.rawValue, value, "a whole number from 0–2,147,483,647") }
            }
        }
        let hasPlayerEdits = !edits.isEmpty || !abilityEdits.isEmpty || !inventoryCounts.isEmpty || !removedInventorySlots.isEmpty || !inventoryAdditions.isEmpty || !inventoryMoves.isEmpty || !inventorySwaps.isEmpty
        let dbURL = sourceWorld.appendingPathComponent("db", isDirectory: true)
        var updatedPlayerBytes: Data? = nil
        if hasPlayerEdits {
            let report = try BedrockLevelDBInspector.inspect(databaseAt: dbURL)
            guard let player = report.latestRecords.first(where: { $0.key == Data("~local_player".utf8) }),
                  let originalBytes = player.value else { throw EditError.playerRecordMissing }
            var playerRoot = try BedrockLevelDatDocument.decodeRootCompound(originalBytes)
            for field in stableFieldOrder where edits[field] != nil {
                try apply(field: field, value: edits[field]!, to: &playerRoot)
            }
            if !abilityEdits.isEmpty { try apply(abilities: abilityEdits, to: &playerRoot) }
            if !inventoryCounts.isEmpty || !removedInventorySlots.isEmpty || !inventoryAdditions.isEmpty || !inventoryMoves.isEmpty || !inventorySwaps.isEmpty {
                try applyInventory(counts: inventoryCounts, removals: removedInventorySlots, additions: inventoryAdditions, moves: inventoryMoves, swaps: inventorySwaps, to: &playerRoot)
            }
            updatedPlayerBytes = try BedrockLevelDatDocument.encodeRootCompound(playerRoot)
        }

        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exports = documents.appendingPathComponent("SAVEFORGE/Exports", isDirectory: true)
        try fm.createDirectory(at: exports, withIntermediateDirectories: true)
        let baseName = sourceWorld.lastPathComponent.isEmpty ? "Minecraft World" : sourceWorld.lastPathComponent
        let safeName = baseName.replacingOccurrences(of: "/", with: "-")
        let outputWorld = exports.appendingPathComponent("\(safeName)-Edited", isDirectory: true)
        if fm.fileExists(atPath: outputWorld.path) { try fm.removeItem(at: outputWorld) }
        try fm.copyItem(at: sourceWorld, to: outputWorld)
        do {
            if let updatedBytes = updatedPlayerBytes {
                let copiedDB = outputWorld.appendingPathComponent("db", isDirectory: true)
                try fm.removeItem(at: copiedDB)
                let outputDB = outputWorld.appendingPathComponent("db", isDirectory: true)
                let mutation = BedrockLevelDBMutation(key: Data("~local_player".utf8), value: updatedBytes)
                let commit = try BedrockLevelDBWriter.commit([mutation], copying: dbURL, to: outputDB)
                guard commit.validationPassed else { throw EditError.databaseValidationFailed }
                let check = try BedrockLevelDBInspector.inspect(databaseAt: outputDB)
                guard let saved = check.latestRecords.first(where: { $0.key == Data("~local_player".utf8) })?.value,
                      saved == updatedBytes else { throw EditError.readBackMismatch }
            }
            if !levelEdits.isEmpty {
                let levelURL = outputWorld.appendingPathComponent("level.dat")
                var document = try BedrockLevelDatDocument.read(from: levelURL)
                try applyLevelEdits(levelEdits, to: &document)
                try document.writeAtomically(to: levelURL, makeBackup: true)
                let reopened = try BedrockLevelDatDocument.read(from: levelURL)
                guard try reopened.encoded() == document.encoded() else { throw EditError.levelDataReadBackMismatch }
            }
            let archiveURL = exports.appendingPathComponent("\(safeName)-Edited.mcworld")
            if fm.fileExists(atPath: archiveURL.path) { try fm.removeItem(at: archiveURL) }
            try makeMCWorldArchive(from: outputWorld, to: archiveURL)
            try fm.removeItem(at: outputWorld)
            return archiveURL
        } catch {
            try? fm.removeItem(at: outputWorld)
            throw error
        }
    }

    private static func makeMCWorldArchive(from worldFolder: URL, to archiveURL: URL) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: worldFolder, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: []) else { throw EditError.archiveCreationFailed }
        struct Entry { let name: Data; let bytes: Data; let crc: UInt32; let offset: UInt32; let isDirectory: Bool }
        var archive = Data(); var entries: [Entry] = []
        let rootPath = worldFolder.standardizedFileURL.path
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            let relative = String(url.standardizedFileURL.path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard !relative.isEmpty else { continue }
            let isDirectory = values.isDirectory == true
            let name = Data((isDirectory ? relative + "/" : relative).utf8)
            let bytes = isDirectory ? Data() : try Data(contentsOf: url, options: [.mappedIfSafe])
            guard name.count <= Int(UInt16.max), bytes.count <= Int(UInt32.max), archive.count <= Int(UInt32.max) else { throw EditError.archiveTooLarge }
            var crc: UInt32 = 0xffffffff
            for byte in bytes { crc ^= UInt32(byte); for _ in 0..<8 { crc = (crc & 1) == 0 ? (crc >> 1) : ((crc >> 1) ^ 0xedb88320) } }
            crc ^= 0xffffffff
            let offset = UInt32(archive.count)
            archive.appendLE(UInt32(0x04034b50)); archive.appendLE(UInt16(20)); archive.appendLE(UInt16(0x0800)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0))
            archive.appendLE(crc); archive.appendLE(UInt32(bytes.count)); archive.appendLE(UInt32(bytes.count)); archive.appendLE(UInt16(name.count)); archive.appendLE(UInt16(0)); archive.append(name); archive.append(bytes)
            entries.append(Entry(name: name, bytes: bytes, crc: crc, offset: offset, isDirectory: isDirectory))
        }
        guard !entries.isEmpty, entries.count <= Int(UInt16.max) else { throw EditError.archiveCreationFailed }
        let centralOffset = UInt32(archive.count)
        for entry in entries {
            archive.appendLE(UInt32(0x02014b50)); archive.appendLE(UInt16(20)); archive.appendLE(UInt16(20)); archive.appendLE(UInt16(0x0800)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0))
            archive.appendLE(entry.crc); archive.appendLE(UInt32(entry.bytes.count)); archive.appendLE(UInt32(entry.bytes.count)); archive.appendLE(UInt16(entry.name.count)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt32(entry.isDirectory ? 0x10 : 0)); archive.appendLE(entry.offset); archive.append(entry.name)
        }
        guard archive.count <= Int(UInt32.max) else { throw EditError.archiveTooLarge }
        let centralSize = UInt32(archive.count) - centralOffset
        archive.appendLE(UInt32(0x06054b50)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(entries.count)); archive.appendLE(UInt16(entries.count)); archive.appendLE(centralSize); archive.appendLE(centralOffset); archive.appendLE(UInt16(0))
        try archive.write(to: archiveURL, options: .atomic)
        let check = try Data(contentsOf: archiveURL, options: [.mappedIfSafe])
        guard check.count >= 22, check.suffix(22).prefix(4) == Data([0x50, 0x4b, 0x05, 0x06]) else { try? fm.removeItem(at: archiveURL); throw EditError.archiveCreationFailed }
    }

    private static func apply(abilities: [String: Bool], to root: inout [String: BedrockNBTValue]) throws {
        guard case .compound(var values)? = root["abilities"] else { throw EditError.abilitiesMissing }
        for (key, enabled) in abilities {
            guard let existing = values[key] else { throw EditError.abilityNotFound(key) }
            switch existing {
            case .byte: values[key] = .byte(enabled ? 1 : 0)
            case .int: values[key] = .int(enabled ? 1 : 0)
            default: throw EditError.unsupportedAbilityType(key)
            }
        }
        root["abilities"] = .compound(values)
    }

    private static func applyInventory(counts: [Int: Int], removals: Set<Int>, additions: [Int: MinecraftStagedInventoryAddition], moves: [Int: Int], swaps: [Int: Int], to root: inout [String: BedrockNBTValue]) throws {
        guard case .list(let elementType, var values)? = root["Inventory"] else { throw EditError.inventoryMissing }
        guard elementType == 10 else { throw EditError.inventoryFormatUnsupported }
        guard moves.allSatisfy({ (0...35).contains($0.key) && (0...35).contains($0.value) && $0.key != $0.value }),
              Set(moves.values).count == moves.count else { throw EditError.inventoryMoveInvalid }
        let moveSources = Set(moves.keys)
        let moveDestinations = Set(moves.values)
        guard moveSources.isDisjoint(with: moveDestinations) else { throw EditError.inventoryMoveInvalid }
        guard swaps.allSatisfy({ (0...35).contains($0.key) && (0...35).contains($0.value) && $0.key != $0.value }),
              swaps.count % 2 == 0,
              swaps.allSatisfy({ swaps[$0.value] == $0.key }),
              Set(swaps.keys).isDisjoint(with: moveSources),
              Set(swaps.values).isDisjoint(with: moveDestinations),
              Set(swaps.keys).isDisjoint(with: moveDestinations),
              Set(swaps.values).isDisjoint(with: moveSources) else { throw EditError.inventoryMoveInvalid }
        let originalOccupied = Set(values.compactMap { entry -> Int? in
            guard case .compound(let fields) = entry,
                  case .string(let name)? = fields["Name"], !name.isEmpty else { return nil }
            let count: Int
            switch fields["Count"] { case .byte(let n): count = Int(n); case .short(let n): count = Int(n); case .int(let n): count = Int(n); default: count = 0 }
            guard count > 0 else { return nil }
            switch fields["Slot"] { case .byte(let n): return Int(n); case .short(let n): return Int(n); case .int(let n): return Int(n); default: return nil }
        })
        guard moveSources.isSubset(of: originalOccupied), moveDestinations.isDisjoint(with: originalOccupied),
              Set(swaps.keys).isSubset(of: originalOccupied) else {
            throw EditError.inventoryMoveDestinationOccupied
        }
        guard counts.values.allSatisfy({ (1...64).contains($0) }) else { throw EditError.inventoryCountOutOfRange }
        guard additions.allSatisfy({ slot, item in slot == item.slot && (0...35).contains(slot) && (1...64).contains(item.count) && item.identifier.range(of: #"^minecraft:[a-z0-9_]+$"#, options: .regularExpression) != nil }) else { throw EditError.inventoryAdditionOutOfRange }
        var found = Set<Int>()
        var replacedAdditionSlots = Set<Int>()
        values = values.compactMap { entry in
            guard case .compound(var item) = entry else { return entry }
            let slot: Int
            switch item["Slot"] { case .byte(let n): slot = Int(n); case .short(let n): slot = Int(n); case .int(let n): slot = Int(n); default: return entry }
            if let destination = moves[slot] ?? swaps[slot] {
                item["Slot"] = .byte(Int8(destination))
                found.insert(slot)
            }
            if removals.contains(slot) { found.insert(slot); return nil }
            if let count = counts[slot] {
                switch item["Count"] { case .byte: item["Count"] = .byte(Int8(count)); case .short: item["Count"] = .short(Int16(count)); case .int: item["Count"] = .int(Int32(count)); default: item["Count"] = .byte(Int8(count)) }
                found.insert(slot)
            }
            if let addition = additions[slot] {
                let name: String
                if case .string(let existingName)? = item["Name"] { name = existingName } else { name = "" }
                let existingCount: Int
                switch item["Count"] { case .byte(let n): existingCount = Int(n); case .short(let n): existingCount = Int(n); case .int(let n): existingCount = Int(n); default: existingCount = 0 }
                if name.isEmpty || existingCount <= 0 {
                    item["Name"] = .string(addition.identifier)
                    item["Count"] = .byte(Int8(addition.count))
                    if item["Damage"] == nil { item["Damage"] = .short(0) }
                    if item["WasPickedUp"] == nil { item["WasPickedUp"] = .byte(0) }
                    replacedAdditionSlots.insert(slot)
                }
            }
            return .compound(item)
        }
        let requested = Set(counts.keys).union(removals).union(moveSources).union(swaps.keys)
        guard requested.isSubset(of: found) else { throw EditError.inventorySlotMissing }
        let occupied = Set(values.compactMap { entry -> Int? in
            guard case .compound(let fields) = entry else { return nil }
            let name: String
            if case .string(let value)? = fields["Name"] { name = value } else { name = "" }
            let count: Int
            switch fields["Count"] { case .byte(let n): count = Int(n); case .short(let n): count = Int(n); case .int(let n): count = Int(n); default: count = 0 }
            guard !name.isEmpty && count > 0 else { return nil }
            switch fields["Slot"] { case .byte(let n): return Int(n); case .short(let n): return Int(n); case .int(let n): return Int(n); default: return nil }
        })
        let slotsToAppend = Set(additions.keys).subtracting(replacedAdditionSlots)
        guard slotsToAppend.isDisjoint(with: occupied), slotsToAppend.isDisjoint(with: removals) else { throw EditError.inventorySlotMissing }
        for slot in slotsToAppend.sorted() {
            guard let item = additions[slot] else { continue }
            values.append(.compound(["Name": .string(item.identifier), "Count": .byte(Int8(item.count)), "Slot": .byte(Int8(slot)), "Damage": .short(0), "WasPickedUp": .byte(0)]))
        }
        root["Inventory"] = .list(elementType, values)
    }

    private static func applyLevelEdits(_ edits: [String: String], to document: inout BedrockLevelDatDocument) throws {
        for (key, raw) in edits {
            switch key {
            case "LevelName": document.setString(key, raw)
            case "GameType":
                guard let value = Int32(raw), [0, 1, 2, 6].contains(value) else { throw EditError.levelFieldOutOfRange(key, raw, "0, 1, 2, or 6") }
                document.setInt(key, value)
            case "Difficulty":
                guard let value = Int32(raw), (0...3).contains(value) else { throw EditError.levelFieldOutOfRange(key, raw, "0–3") }
                document.setInt(key, value)
            case "RandomSeed": throw EditError.seedLocked
            case "Time":
                guard let value = Int64(raw), value >= 0 else { throw EditError.levelFieldOutOfRange(key, raw, "0 or greater") }; document.setLong(key, value)
            case "commandsEnabled":
                guard let value = Int(raw), value == 0 || value == 1 else { throw EditError.levelFieldOutOfRange(key, raw, "0 or 1") }
                document.root[key] = .byte(Int8(value))
            case "rainLevel", "lightningLevel":
                guard let value = Float(raw), value.isFinite, value >= 0, value <= 1 else { throw EditError.levelFieldOutOfRange(key, raw, "0–1") }
                document.root[key] = .float(value)
            default:
                if key.hasPrefix("GameRules.") {
                    let name = String(key.dropFirst("GameRules.".count))
                    var rules: [String: BedrockNBTValue]
                    if case .compound(let existingRules)? = document.root["GameRules"] { rules = existingRules }
                    else { rules = [:] }
                    guard let v = Int8(raw), v == 0 || v == 1 else { throw EditError.levelFieldOutOfRange(name, raw, "0 or 1") }
                    if let existing = rules[name] {
                        switch existing {
                        case .byte: rules[name] = .byte(v)
                        case .int: rules[name] = .int(Int32(v))
                        default: throw EditError.gameruleTypeUnsupported(name)
                        }
                    } else {
                        let supported: Set<String> = ["keepInventory", "mobGriefing", "doDaylightCycle", "doMobSpawning", "doFireTick", "naturalRegeneration", "doEntityDrops"]
                        guard supported.contains(name) else { throw EditError.gameruleMissing(name) }
                        rules[name] = .byte(v)
                    }
                    document.root["GameRules"] = .compound(rules)
                } else { throw EditError.unsupportedLevelField(key) }
            }
        }
    }

    private static func apply(field: Field, value: Double, to root: inout [String: BedrockNBTValue]) throws {
        if field == .xpLevel {
            root["PlayerLevel"] = .int(Int32(value))
            return
        }
        guard case .list(let elementType, var values)? = root["Attributes"] else { throw EditError.attributesMissing }
        let targetName: String
        switch field {
        case .health, .maximumHealth: targetName = "minecraft:health"
        case .hunger: targetName = "minecraft:player.hunger"
        case .saturation: targetName = "minecraft:player.saturation"
        case .xpLevel: return
        }
        var found = false
        for index in values.indices {
            guard case .compound(var attribute) = values[index],
                  case .string(let name)? = attribute["Name"], name == targetName else { continue }
            let n = Float(value)
            switch field {
            case .health: attribute["Current"] = .float(n)
            case .maximumHealth: attribute["DefaultMax"] = .float(n)
            case .hunger, .saturation: attribute["Current"] = .float(n)
            case .xpLevel: break
            }
            values[index] = .compound(attribute)
            found = true
            break
        }
        guard found else { throw EditError.attributeNotFound(targetName) }
        root["Attributes"] = .list(elementType, values)
    }

    enum EditError: Error, LocalizedError {
        case invalidValue, outOfRange, emptyEdits, playerRecordMissing, attributesMissing, inventoryMissing, inventoryFormatUnsupported, inventorySlotMissing, levelDataReadBackMismatch, seedLocked
        case fieldOutOfRange(String, Double, String), levelFieldOutOfRange(String, String, String), inventoryCountOutOfRange, inventoryAdditionOutOfRange
        case inventoryMoveInvalid, inventoryMoveDestinationOccupied
        case gameruleMissing(String), gameruleTypeUnsupported(String), unsupportedLevelField(String)
        case attributeNotFound(String), abilitiesMissing, abilityNotFound(String), unsupportedAbilityType(String), databaseValidationFailed, readBackMismatch, archiveCreationFailed, archiveTooLarge
        var errorDescription: String? {
            switch self {
            case .invalidValue: return "Enter a valid number."
            case .seedLocked: return "World seed editing is locked to protect existing world generation. No seed change was made."
            case .inventoryMissing: return "The player inventory list is missing."
            case .inventoryFormatUnsupported: return "The inventory uses an unsupported NBT list format."
            case .inventorySlotMissing: return "One or more requested inventory slots were not found."
            case .levelDataReadBackMismatch: return "The exported level.dat did not pass read-back validation."
            case .gameruleMissing(let n): return "The world does not contain the gamerule tag: \(n)."
            case .gameruleTypeUnsupported(let n): return "The gamerule has an unsupported value type: \(n)."
            case .unsupportedLevelField(let n): return "This level.dat field is not supported: \(n)."
            case .emptyEdits: return "There are no pending edits to export."
            case .outOfRange: return "A value is outside the supported range. Review each staged value and try again."
            case .fieldOutOfRange(let field, let value, let range):
                return "\(field.capitalized) value \(value) is outside its supported range (\(range)). No export was created."
            case .levelFieldOutOfRange(let field, let value, let range):
                return "\(field) value \(value) is outside its supported range (\(range)). No export was created."
            case .inventoryMoveInvalid: return "The requested inventory move is invalid. Each source and destination must be a different slot from 1–36."
            case .inventoryMoveDestinationOccupied: return "The destination slot is occupied. Move or remove that stack first."
            case .inventoryCountOutOfRange:
                return "An inventory stack count must be between 1 and 64. No export was created."
            case .inventoryAdditionOutOfRange:
                return "An added item must use a valid Minecraft identifier, inventory slot 0–35, and count 1–64. No export was created."
            case .playerRecordMissing: return "The latest ~local_player record could not be found. No export was created."
            case .attributesMissing: return "The player record has no Attributes list in the expected Bedrock format."
            case .attributeNotFound(let name): return "The player record does not contain the expected attribute: \(name)."
            case .abilitiesMissing: return "The player record does not contain an abilities compound."
            case .abilityNotFound(let name): return "The player record does not contain the ability: \(name)."
            case .unsupportedAbilityType(let name): return "The ability tag has an unsupported NBT type: \(name)."
            case .databaseValidationFailed: return "The exported database did not pass transaction validation."
            case .readBackMismatch: return "The edited player record did not match after reopening the exported database."
            case .archiveCreationFailed: return "The world was edited, but SAVEFORGE could not create a valid .mcworld archive."
            case .archiveTooLarge: return "The edited world exceeds the supported ZIP archive size."
            }
        }
    }
}


private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
