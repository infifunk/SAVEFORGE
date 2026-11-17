// MARK: - Minecraft Bedrock player snapshot

import Foundation

struct MinecraftPlayerInventoryItem {
    let identifier: String
    let slot: Int
    let count: Int
    let damage: Int
}

struct MinecraftPlayerSnapshot {
    let sequence: UInt64
    let health: Double?
    let maximumHealth: Double?
    let hunger: Double?
    let saturation: Double?
    let xpLevel: Int?
    let gameMode: Int?
    let abilities: [String: Bool]
    let inventory: [MinecraftPlayerInventoryItem]

    var hotbar: [MinecraftPlayerInventoryItem?] {
        (0..<9).map { slot in inventory.first(where: { $0.slot == slot && !$0.identifier.isEmpty && $0.count > 0 }) }
    }

    static func load(worldURL: URL) throws -> MinecraftPlayerSnapshot {
        let db = worldURL.appendingPathComponent("db", isDirectory: true)
        let report = try BedrockLevelDBInspector.inspect(databaseAt: db)
        let playerKey = Data("~local_player".utf8)

        var playerCandidates: [(sequence: UInt64, value: Data?)] = report.walRecords
            .filter { $0.key == playerKey }
            .map { ($0.sequence, $0.value) }

        let tableReport = try BedrockLevelDBTableReader.read(databaseAt: db)
        playerCandidates.append(contentsOf: tableReport.entries
            .filter { $0.key == playerKey }
            .map { ($0.sequence, $0.valueType == 1 ? Optional($0.value) : nil) })

        guard let newest = playerCandidates.max(by: { $0.sequence < $1.sequence }),
              let bytes = newest.value else {
            let tableNames = tableReport.tablesRead.joined(separator: ", ")
            let warningText = tableReport.warnings.joined(separator: " | ")
            throw SnapshotError.localPlayerNotFound(
                tables: tableNames,
                warnings: warningText,
                candidates: playerCandidates.count
            )
        }
        let recordSequence = newest.sequence
        let root = try BedrockLevelDatDocument.decodeRootCompound(bytes)
        let attributes: [[String: BedrockNBTValue]] = {
            guard case .list(_, let values)? = root["Attributes"] else { return [] }
            return values.compactMap { if case .compound(let c) = $0 { return c }; return nil }
        }()
        func attribute(_ name: String) -> Double? {
            guard let attr = attributes.first(where: {
                if case .string(let n)? = $0["Name"] { return n == name }
                return false
            }) else { return nil }
            if case .float(let v)? = attr["Current"] { return Double(v) }
            if case .double(let v)? = attr["Current"] { return v }
            if case .float(let v)? = attr["Base"] { return Double(v) }
            if case .double(let v)? = attr["Base"] { return v }
            return nil
        }
        func intValue(_ key: String) -> Int? {
            switch root[key] {
            case .int(let v): return Int(v)
            case .short(let v): return Int(v)
            case .byte(let v): return Int(v)
            case .long(let v): return Int(v)
            default: return nil
            }
        }
        var abilities: [String: Bool] = [:]
        if case .compound(let values)? = root["abilities"] {
            for (key, value) in values {
                switch value {
                case .byte(let v): abilities[key] = v != 0
                case .int(let v): abilities[key] = v != 0
                default: break
                }
            }
        }
        var inventory: [MinecraftPlayerInventoryItem] = []
        if case .list(_, let values)? = root["Inventory"] {
            for value in values {
                guard case .compound(let fields) = value else { continue }
                func fieldInt(_ key: String) -> Int {
                    switch fields[key] {
                    case .byte(let v): return Int(v)
                    case .short(let v): return Int(v)
                    case .int(let v): return Int(v)
                    default: return 0
                    }
                }
                let identifier: String
                if case .string(let name)? = fields["Name"] { identifier = name } else { identifier = "" }
                inventory.append(MinecraftPlayerInventoryItem(
                    identifier: identifier,
                    slot: fieldInt("Slot"),
                    count: fieldInt("Count"),
                    damage: fieldInt("Damage")
                ))
            }
        }
        return MinecraftPlayerSnapshot(
            sequence: recordSequence,
            health: attribute("minecraft:health"),
            maximumHealth: attributes.first(where: {
                if case .string(let n)? = $0["Name"] { return n == "minecraft:health" }
                return false
            }).flatMap { if case .float(let v)? = $0["DefaultMax"] { return Double(v) }; return nil },
            hunger: attribute("minecraft:player.hunger"),
            saturation: attribute("minecraft:player.saturation"),
            xpLevel: intValue("PlayerLevel"),
            gameMode: intValue("PlayerGameMode"),
            abilities: abilities,
            inventory: inventory.sorted { $0.slot < $1.slot }
        )
    }

    enum SnapshotError: Error, LocalizedError {
        case localPlayerNotFound(tables: String, warnings: String, candidates: Int)
        var errorDescription: String? {
            switch self {
            case .localPlayerNotFound(let tables, let warnings, let candidates):
                let tableSummary = tables.isEmpty ? "No SSTable was decoded." : "Read tables: " + tables + "."
                let warningSummary = warnings.isEmpty ? "" : " Table warnings: " + warnings
                return "No live ~local_player record was found. Checked WAL and SSTables; found " + String(candidates) + " matching record versions. " + tableSummary + warningSummary
            }
        }
    }
}


struct MinecraftStagedInventoryAddition {
    let identifier: String
    let slot: Int
    let count: Int
}
