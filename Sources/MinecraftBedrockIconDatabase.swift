// MARK: - Minecraft Bedrock icon database

import Foundation
import UIKit

enum MinecraftBedrockIconDatabase {
    private static let rawRoot = "https://raw.githubusercontent.com/Mojang/bedrock-samples/main/resource_pack/"
    private static let databaseURL = MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("bedrock-icon-database.json")
    private static let stateURL = MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("bedrock-icon-download-state.json")
    private static let lock = NSLock()

    private struct Manifest: Codable {
        var source: String
        var edition: String
        var generatedAt: Date
        var entries: [String: [String]]
    }
    private struct State: Codable { var successful: Set<String> = []; var failed: Set<String> = [] }

    private static func paths(from value: Any) -> [String] {
        if let s = value as? String { return [s] }
        if let a = value as? [Any] { return a.flatMap { paths(from: $0) } }
        if let d = value as? [String: Any] {
            var out: [String] = []
            for k in ["path", "textures", "texture", "default"] { if let v = d[k] { out += paths(from: v) } }
            for (k,v) in d where !["path","textures","texture","default","overlay_color","tint_color"].contains(k) { out += paths(from: v) }
            return out
        }
        return []
    }

    private static func removingJSONComments(from data: Data) -> Data {
        let input = [UInt8](data)
        var output = input
        var index = 0
        var inString = false
        var escaped = false
        var inLineComment = false
        var inBlockComment = false

        while index < input.count {
            let byte = input[index]
            let next: UInt8? = index + 1 < input.count ? input[index + 1] : nil

            if inLineComment {
                if byte == 10 || byte == 13 {
                    inLineComment = false
                } else {
                    output[index] = 32
                }
                index += 1
                continue
            }

            if inBlockComment {
                if byte == 42, next == 47 {
                    output[index] = 32
                    output[index + 1] = 32
                    index += 2
                    inBlockComment = false
                } else {
                    if byte != 10 && byte != 13 { output[index] = 32 }
                    index += 1
                }
                continue
            }

            if inString {
                if escaped {
                    escaped = false
                } else if byte == 92 {
                    escaped = true
                } else if byte == 34 {
                    inString = false
                }
                index += 1
                continue
            }

            if byte == 34 {
                inString = true
                index += 1
                continue
            }

            if byte == 47, next == 47 {
                output[index] = 32
                output[index + 1] = 32
                index += 2
                inLineComment = true
                continue
            }

            if byte == 47, next == 42 {
                output[index] = 32
                output[index + 1] = 32
                index += 2
                inBlockComment = true
                continue
            }

            index += 1
        }

        return Data(output)
    }

    private static func fetchJSON(_ path: String, completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: rawRoot + path) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode

            if error != nil {
                completion(nil)
                return
            }

            guard let data, status == 200 else {
                completion(nil)
                return
            }

            let cleaned = removingJSONComments(from: data)
            do {
                let object = try JSONSerialization.jsonObject(with: cleaned, options: [])
                guard let json = object as? [String: Any] else {
                    completion(nil)
                    return
                }
                guard let textureData = json["texture_data"] as? [String: Any], !textureData.isEmpty else {
                    completion(nil)
                    return
                }
                completion(json)
            } catch {
                completion(nil)
            }
        }.resume()
    }

    private static func buildEntries(ids: [String], item: [String: Any], terrain: [String: Any]) -> [String: [String]] {
        func atlas(_ root: [String: Any]) -> [String: [String]] {
            let data = root["texture_data"] as? [String: Any] ?? [:]
            return data.reduce(into: [:]) { result, pair in
                let values = paths(from: pair.value).map { $0.hasSuffix(".png") ? String($0.dropLast(4)) : $0 }
                    .filter { $0.hasPrefix("textures/") }
                if !values.isEmpty { result[pair.key.lowercased()] = Array(NSOrderedSet(array: values)) as? [String] ?? values }
            }
        }
        let itemMap = atlas(item), blockMap = atlas(terrain)
        var output: [String: [String]] = [:]
        let woods = ["oak","spruce","birch","jungle","acacia","dark_oak","mangrove","cherry","bamboo","crimson","warped","pale_oak"]
        for rawID in ids {
            let id = rawID.lowercased().replacingOccurrences(of: "minecraft:", with: "")
            guard !id.isEmpty && id != "air" else { continue }
            var candidates: [String] = []
            func add(_ p: String) { if !candidates.contains(p) { candidates.append(p) } }
            add("textures/items/" + id); add("textures/blocks/" + id)
            let material = woods.first { id.hasPrefix($0 + "_") }
            if let material {
                let suffix = String(id.dropFirst(material.count + 1))
                let aliases: [String: [String]] = [
                    "button":["button_\(material)"], "door":["door_\(material)"],
                    "fence":["fence_\(material)"], "fence_gate":["fence_gate_\(material)"],
                    "pressure_plate":["pressure_plate_\(material)"], "stairs":["\(material)_stairs","stairs_\(material)"],
                    "slab":["\(material)_slab","slab_\(material)"], "trapdoor":["trapdoor_\(material)"],
                    "planks":["planks_\(material)"], "log":["log_\(material)"], "wood":["log_\(material)"],
                    "leaves":["leaves_\(material)"], "sapling":["sapling_\(material)"], "boat":["boat_\(material)" ]]
                for key in aliases[suffix] ?? [] { add("textures/items/" + key); add("textures/blocks/" + key) }
            }
            let aliases: [String: [String]] = [
                "golden_apple":["textures/items/apple_golden"], "enchanted_golden_apple":["textures/items/apple_golden"],
                "golden_carrot":["textures/items/carrot_golden"], "redstone":["textures/items/redstone_dust"],
                "wheat_seeds":["textures/items/seeds_wheat"], "beetroot_seeds":["textures/items/seeds_beetroot"],
                "lodestone":["textures/blocks/lodestone_side","textures/blocks/lodestone_top"],
                "obsidian":["textures/blocks/obsidian"], "torch":["textures/blocks/torch_on"],
                "bow":["textures/items/bow_standby"], "acacia_boat":["textures/items/boat_acacia"],
                "acacia_door":["textures/items/door_acacia"], "acacia_planks":["textures/blocks/planks_acacia"],
                "acacia_log":["textures/blocks/log_acacia"], "acacia_leaves":["textures/blocks/leaves_acacia"]]
            for p in aliases[id] ?? [] { add(p) }
            var atlasKeys: [String] = [id]
            if let material {
                let suffix = String(id.dropFirst(material.count + 1))
                let family: [String: [String]] = [
                    "boat": ["boat_\(material)", "boat"],
                    "chest_boat": ["\(material)_chest_boat", "chest_boat"],
                    "door": ["door_\(material)", "door"],
                    "button": ["button_\(material)", "wooden_button", "button"],
                    "pressure_plate": ["pressure_plate_\(material)", "wooden_pressure_plate", "pressure_plate"],
                    "fence": ["fence_\(material)", "fence"],
                    "fence_gate": ["fence_gate_\(material)", "fence_gate"],
                    "trapdoor": ["trapdoor_\(material)", "trapdoor"],
                    "stairs": ["\(material)_stairs", "stairs_\(material)", "stairs"],
                    "slab": ["\(material)_slab", "slab_\(material)", "wooden_slab"],
                    "double_slab": ["double_slab_\(material)", "double_wooden_slab"],
                    "planks": ["planks_\(material)"],
                    "log": ["log_\(material)", "log"],
                    "wood": ["log_\(material)", "wood"],
                    "leaves": ["leaves_\(material)", "leaves"],
                    "sapling": ["sapling_\(material)", "sapling"],
                    "sign": ["sign_\(material)", "sign"],
                    "hanging_sign": ["\(material)_hanging_sign", "hanging_sign"]
                ]
                atlasKeys.append(contentsOf: family[suffix] ?? [])
            }
            let colorNames = ["white","orange","magenta","light_blue","yellow","lime","pink","gray","light_gray","cyan","purple","blue","brown","green","red","black"]
            if let color = colorNames.first(where: { id.hasPrefix($0 + "_") }) {
                let suffix = String(id.dropFirst(color.count + 1))
                let colorAliases: [String: [String]] = [
                    "wool": ["wool_\(color)"], "carpet": ["carpet_\(color)"],
                    "concrete": ["concrete_\(color)"], "concrete_powder": ["concrete_powder_\(color)"],
                    "stained_glass": ["glass_\(color)"], "stained_glass_pane": ["glass_pane_top"]
                ]
                atlasKeys.append(contentsOf: colorAliases[suffix] ?? [])
                atlasKeys.append(contentsOf: ["\(suffix)_\(color)", "\(color)_\(suffix)"])
            }
            let explicitAtlasAliases: [String: [String]] = [
                "writable_book": ["book_writable"], "written_book": ["book_written"],
                "enchanted_book": ["book_enchanted"], "white_wool": ["wool_white"],
                "orange_wool": ["wool_orange"], "magenta_wool": ["wool_magenta"],
                "light_blue_wool": ["wool_light_blue"], "yellow_wool": ["wool_yellow"],
                "lime_wool": ["wool_lime"], "pink_wool": ["wool_pink"],
                "gray_wool": ["wool_gray"], "light_gray_wool": ["wool_silver"],
                "cyan_wool": ["wool_cyan"], "purple_wool": ["wool_purple"],
                "blue_wool": ["wool_blue"], "brown_wool": ["wool_brown"],
                "green_wool": ["wool_green"], "red_wool": ["wool_red"],
                "black_wool": ["wool_black"], "white_carpet": ["carpet"],
                "redstone": ["redstone_dust"], "golden_apple": ["apple_golden"],
                "golden_carrot": ["carrot_golden"], "nautilus_shell": ["nautilus"],
                "heart_of_the_sea": ["heartofthesea_closed"], "dragon_breath": ["dragons_breath"],
                "wheat_seeds": ["seeds_wheat"], "beetroot_seeds": ["seeds_beetroot"],
                "melon_seeds": ["seeds_melon"], "pumpkin_seeds": ["seeds_pumpkin"],
                "cooked_beef": ["beef_cooked"], "raw_beef": ["beef_raw"],
                "cooked_chicken": ["chicken_cooked"], "raw_chicken": ["chicken_raw"],
                "cooked_porkchop": ["porkchop_cooked"], "raw_porkchop": ["porkchop_raw"],
                "cooked_mutton": ["mutton_cooked"], "raw_mutton": ["mutton_raw"],
                "cooked_cod": ["fish_cooked"], "raw_cod": ["fish_raw"],
                "cooked_salmon": ["fish_salmon_cooked"], "raw_salmon": ["fish_salmon_raw"],
                "wooden_pickaxe": ["pickaxe"], "stone_pickaxe": ["pickaxe"],
                "iron_pickaxe": ["pickaxe"], "golden_pickaxe": ["pickaxe"],
                "diamond_pickaxe": ["pickaxe"], "netherite_pickaxe": ["pickaxe"],
                "wooden_axe": ["axe"], "stone_axe": ["axe"], "iron_axe": ["axe"],
                "golden_axe": ["axe"], "diamond_axe": ["axe"], "netherite_axe": ["axe"],
                "wooden_shovel": ["shovel"], "stone_shovel": ["shovel"],
                "iron_shovel": ["shovel"], "golden_shovel": ["shovel"],
                "diamond_shovel": ["shovel"], "netherite_shovel": ["shovel"],
                "wooden_sword": ["sword"], "stone_sword": ["sword"],
                "iron_sword": ["sword"], "golden_sword": ["sword"],
                "diamond_sword": ["sword"], "netherite_sword": ["sword"]
            ]
            atlasKeys.append(contentsOf: explicitAtlasAliases[id] ?? [])

            for map in [itemMap, blockMap] {
                for key in atlasKeys {
                    if let values = map[key] { values.forEach(add) }
                }
                let normalizedTargets = Set(atlasKeys.map { $0.replacingOccurrences(of: "_", with: "") })
                let matches = map.keys.filter { key in
                    let normalized = key.replacingOccurrences(of: "_", with: "")
                    if normalizedTargets.contains(normalized) { return true }
                    return atlasKeys.contains { target in
                        key.hasSuffix("_" + target) || target.hasSuffix("_" + key)
                    }
                }
                for key in matches.sorted() { (map[key] ?? []).forEach(add) }
            }
            let officialPaths = candidates.filter { path in
                (Array(itemMap.values) + Array(blockMap.values)).contains { $0.contains(path) }
            }
            let fallbackPaths = candidates.filter { !officialPaths.contains($0) }
            output[id] = officialPaths + fallbackPaths
        }
        return output
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(value) { try? data.write(to: url, options: .atomic) }
    }
    private static var legacyStateURL: URL {
        MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent("icon-pack-manifest.json")
    }

    private static func readState() -> State {
        var merged = State()
        if let data = try? Data(contentsOf: stateURL),
           let value = try? JSONDecoder().decode(State.self, from: data) {
            merged.successful.formUnion(value.successful)
            merged.failed.formUnion(value.failed)
        }
        if let data = try? Data(contentsOf: legacyStateURL),
           let legacy = try? JSONDecoder().decode(LegacyIconState.self, from: data) {
            merged.successful.formUnion(legacy.successful)
            merged.failed.formUnion(legacy.failed)
        }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: MinecraftBedrockItemIcons.cacheDirectory, includingPropertiesForKeys: nil
        )) ?? []
        let diskIDs = Set(files.filter { $0.pathExtension.lowercased() == "png" }.map { $0.deletingPathExtension().lastPathComponent.lowercased() })
        merged.successful.formUnion(diskIDs)
        merged.failed.subtract(merged.successful)
        return merged
    }

    private struct LegacyIconState: Codable {
        var successful: [String] = []
        var failed: [String] = []
        var lastUpdated: Date?
    }

    static var failedIdentifiers: [String] {
        readState().failed.sorted()
    }

    static func downloadPack(itemIdentifiers: [String], onlyMissing: Bool,
        progress: @escaping (Int, Int, Int) -> Void,
        completion: @escaping (Int, Int, Int, [String]) -> Void) {
        let ids = Array(Set(itemIdentifiers.map { $0.lowercased().replacingOccurrences(of: "minecraft:", with: "") }))
            .filter { !$0.isEmpty && $0 != "air" }.sorted()
        guard !ids.isEmpty else { DispatchQueue.main.async { completion(0,0,0,[]) }; return }
        let run: ([String: [String]]) -> Void = { entries in
            let manifest = Manifest(source: "Mojang/bedrock-samples", edition: "Bedrock", generatedAt: Date(), entries: entries)
            writeJSON(manifest, to: databaseURL)
            let state = readState()
            let retry = Set(state.failed)
            let queue = ids.filter { id in
                let file = MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent(id + ".png")
                return onlyMissing ? retry.contains(id) : !FileManager.default.fileExists(atPath: file.path)
            }
            guard !queue.isEmpty else {
                DispatchQueue.main.async { completion(0,0,0,state.failed.sorted()) }
                return
            }
            try? FileManager.default.createDirectory(at: MinecraftBedrockItemIcons.cacheDirectory, withIntermediateDirectories: true)
            let group = DispatchGroup(), semaphore = DispatchSemaphore(value: 5), stateLock = NSLock()
            var done = 0, failed = 0, succeededIDs = Set<String>(), failedIDs = Set<String>()
            for id in queue {
                group.enter(); semaphore.wait()
                let candidates = entries[id] ?? []
                fetchPNG(candidates, identifier: id, index: 0) { data in
                    stateLock.lock(); done += 1
                    if let data {
                        let file = MinecraftBedrockItemIcons.cacheDirectory.appendingPathComponent(id + ".png")
                        do {
                            try data.write(to: file, options: .atomic)
                            succeededIDs.insert(id)
                        } catch {
                            failed += 1; failedIDs.insert(id)
                        }
                    } else {
                        failed += 1; failedIDs.insert(id)
                    }
                    let d = done, f = failed; stateLock.unlock()
                    DispatchQueue.main.async { progress(d, queue.count, f) }
                    semaphore.signal(); group.leave()
                }
            }
            group.notify(queue: .global(qos: .utility)) {
                stateLock.lock(); var updated = readState()
                updated.successful.formUnion(succeededIDs)
                updated.failed.subtract(succeededIDs)
                updated.failed.formUnion(failedIDs)
                let finalFailed = updated.failed.sorted(); writeJSON(updated, to: stateURL)
                stateLock.unlock()
                DispatchQueue.main.async { completion(succeededIDs.count, queue.count, failed, finalFailed) }
            }
        }
        let group = DispatchGroup(); var item: [String: Any]?; var terrain: [String: Any]?
        group.enter(); fetchJSON("textures/item_texture.json") { item = $0; group.leave() }
        group.enter(); fetchJSON("textures/terrain_texture.json") { terrain = $0; group.leave() }
        group.notify(queue: .global(qos: .utility)) {
            guard let item, let terrain else {
                DispatchQueue.main.async { completion(0, ids.count, ids.count, ids) }
                return
            }
            run(buildEntries(ids: ids, item: item, terrain: terrain))
        }
    }

    private static func fetchPNG(_ paths: [String], identifier: String, index: Int,
                                 completion: @escaping (Data?) -> Void) {
        guard index < paths.count else {
            completion(nil)
            return
        }

        let path = paths[index]
        guard let url = URL(string: rawRoot + path + ".png") else {
            fetchPNG(paths, identifier: identifier, index: index + 1, completion: completion)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            if let data, status == 200, UIImage(data: data) != nil {
                completion(data)
            } else {
                fetchPNG(paths, identifier: identifier, index: index + 1, completion: completion)
            }
        }.resume()
    }

}
