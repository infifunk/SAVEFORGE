// MARK: - Minecraft Bedrock item icons

import Foundation
import UIKit

enum MinecraftBedrockItemIcons {
    static let source = "https://github.com/infifunk/SAVEFORGE/releases/latest/download/Items.zip"
    private static let rawRoot = "https://raw.githubusercontent.com/Mojang/bedrock-samples/main/resource_pack/"
    private static let assetPackURL = URL(string: source)!
    static var cacheDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SAVEFORGE", isDirectory: true)
            .appendingPathComponent("MinecraftIconPack", isDirectory: true)
    }
    static var assetPackDirectory: URL {
        cacheDirectory.appendingPathComponent("Items", isDirectory: true)
    }
    private static var assetMappingURL: URL {
        assetPackDirectory.appendingPathComponent("item_texture_mapping.json")
    }
    private(set) static var assetPackIsDownloading = false
    private(set) static var assetPackStatus = "Download the complete Minecraft PNG pack for offline inventory icons."

    static var isAssetPackInstalled: Bool {
        guard let data = try? Data(contentsOf: assetMappingURL),
              let mapping = try? JSONDecoder().decode([String: [String]].self, from: data),
              !mapping.isEmpty else { return false }
        let files = (try? FileManager.default.contentsOfDirectory(at: assetPackDirectory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "png" }.count > 0
    }

    static func downloadAssetPack(completion: @escaping (Bool, String) -> Void) {
        guard !assetPackIsDownloading else { return }
        assetPackIsDownloading = true
        assetPackStatus = "Downloading Items.zip from GitHub Releases…"

        URLSession.shared.downloadTask(with: assetPackURL) { temporaryURL, response, error in
            guard error == nil, let temporaryURL,
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                let message = error?.localizedDescription ?? "GitHub did not return Items.zip. Confirm the release is published and the asset is named Items.zip."
                DispatchQueue.main.async {
                    assetPackIsDownloading = false
                    assetPackStatus = "DOWNLOAD FAILED · " + message
                    completion(false, message)
                }
                return
            }

            let stagingRoot = cacheDirectory.appendingPathComponent("Items-Staging-" + UUID().uuidString, isDirectory: true)
            let backupDirectory = cacheDirectory.appendingPathComponent("Items-Previous", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
                try MinecraftZipExtractor.extract(temporaryURL, to: stagingRoot)

                let stagedItems = stagingRoot.appendingPathComponent("Items", isDirectory: true)
                let stagedMapping = stagedItems.appendingPathComponent("item_texture_mapping.json")
                guard let mappingData = try? Data(contentsOf: stagedMapping),
                      let mapping = try? JSONDecoder().decode([String: [String]].self, from: mappingData),
                      !mapping.isEmpty else {
                    throw NSError(domain: "SAVEFORGE.MinecraftIcons", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Items.zip did not contain a valid Items/item_texture_mapping.json file."])
                }

                let stagedFiles = try FileManager.default.contentsOfDirectory(at: stagedItems, includingPropertiesForKeys: nil)
                let pngCount = stagedFiles.filter { $0.pathExtension.lowercased() == "png" }.count
                guard pngCount > 0 else {
                    throw NSError(domain: "SAVEFORGE.MinecraftIcons", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "The downloaded pack contained no PNG images."])
                }

                if FileManager.default.fileExists(atPath: backupDirectory.path) {
                    try FileManager.default.removeItem(at: backupDirectory)
                }
                if FileManager.default.fileExists(atPath: assetPackDirectory.path) {
                    try FileManager.default.moveItem(at: assetPackDirectory, to: backupDirectory)
                }

                do {
                    try FileManager.default.moveItem(at: stagedItems, to: assetPackDirectory)
                    if FileManager.default.fileExists(atPath: backupDirectory.path) {
                        try FileManager.default.removeItem(at: backupDirectory)
                    }
                } catch {
                    if !FileManager.default.fileExists(atPath: assetPackDirectory.path),
                       FileManager.default.fileExists(atPath: backupDirectory.path) {
                        try? FileManager.default.moveItem(at: backupDirectory, to: assetPackDirectory)
                    }
                    throw error
                }

                try? FileManager.default.removeItem(at: stagingRoot)
                resetArchiveCaches()
                let message = "Installed \(pngCount.formatted()) Minecraft PNG icons and \(mapping.count.formatted()) texture mappings."
                DispatchQueue.main.async {
                    assetPackIsDownloading = false
                    assetPackStatus = "READY OFFLINE · \(pngCount) PNG ICONS"
                    completion(true, message)
                }
            } catch {
                try? FileManager.default.removeItem(at: stagingRoot)
                let message = error.localizedDescription
                DispatchQueue.main.async {
                    assetPackIsDownloading = false
                    assetPackStatus = "DOWNLOAD FAILED · " + message
                    completion(false, message)
                }
            }
        }.resume()
    }

    private static let archiveAtlasLock = NSLock()
    private static var archiveAtlasStorage: [String: [String]]?
    private static var archiveAtlas: [String: [String]] {
        archiveAtlasLock.lock()
        defer { archiveAtlasLock.unlock() }
        if let archiveAtlasStorage { return archiveAtlasStorage }
        let decoded: [String: [String]]
        if let data = try? Data(contentsOf: assetMappingURL),
           let value = try? JSONDecoder().decode([String: [String]].self, from: data) {
            decoded = value
        } else {
            decoded = [:]
        }
        archiveAtlasStorage = decoded
        return decoded
    }

    private static func resetArchiveCaches() {
        archiveAtlasLock.lock()
        archiveAtlasStorage = nil
        archiveAtlasLock.unlock()
        bundledImageCache.removeAllObjects()
    }

    private static let migrationLock = NSLock()
    private static var didMigrateLegacyPNGs = false

    private static var legacyCacheDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SAVEFORGE", isDirectory: true)
            .appendingPathComponent("MinecraftItemIcons", isDirectory: true)
    }

    private static func migrateLegacyPNGsIfNeeded() {
        migrationLock.lock()
        defer { migrationLock.unlock() }
        guard !didMigrateLegacyPNGs else { return }
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if let oldFiles = try? FileManager.default.contentsOfDirectory(
            at: legacyCacheDirectory, includingPropertiesForKeys: nil
        ) {
            for oldURL in oldFiles where oldURL.pathExtension.lowercased() == "png" {
                let destination = cacheDirectory.appendingPathComponent(oldURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try? FileManager.default.copyItem(at: oldURL, to: destination)
                }
            }
        }
        didMigrateLegacyPNGs = true
    }

    private static let atlasQueue = DispatchQueue(label: "saveforge.minecraft.texture-atlas")
    private static var atlasLoaded = false
    private static var atlasLoading = false
    private static var itemAtlas: [String: [String]] = [:]
    private static var terrainAtlas: [String: [String]] = [:]
    private static var javaFallbackMap: [String: String] = [:]
    private static var atlasWaiters: [() -> Void] = []

    static func image(for textureKey: String, completion: @escaping (UIImage?) -> Void) {
        let safe = normalizedTextureKey(textureKey)
        guard !safe.isEmpty, safe.range(of: "^[a-z0-9_/-]+$", options: .regularExpression) != nil,
              !safe.contains("..") else { DispatchQueue.main.async { completion(nil) }; return }

        if let bundled = bundledImage(for: safe) {
            DispatchQueue.main.async { completion(bundled) }
            return
        }

        migrateLegacyPNGsIfNeeded()
        let cacheName = safe.replacingOccurrences(of: "/", with: "_")
        let cachedFile = cacheDirectory.appendingPathComponent(cacheName + ".png")
        if let cached = UIImage(contentsOfFile: cachedFile.path) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        loadAtlases {
            let candidates = candidateTexturePaths(for: safe)
            fetchFirstImage(candidates, cacheFile: cachedFile, completion: completion)
        }
    }

    static var bundledTextureKeyCount: Int { bundledAtlas.count }

    static func bundledCoverage(for identifiers: [String]) -> (resolved: Int, total: Int) {
        let unique = Set(identifiers.map {
            $0.lowercased().replacingOccurrences(of: "minecraft:", with: "")
        }.filter { !$0.isEmpty && $0 != "air" })
        let resolved = unique.reduce(into: 0) { count, identifier in
            if bundledImage(for: identifier) != nil { count += 1 }
        }
        return (resolved, unique.count)
    }

    private static let bundledImageCache = NSCache<NSString, UIImage>()

    private static func normalizedTextureKey(_ key: String) -> String {
        var value = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        value = value.replacingOccurrences(of: "\\", with: "/")
        value = value.replacingOccurrences(of: "minecraft:", with: "")
        if value.hasSuffix(".png") { value = String(value.dropLast(4)) }
        if value.hasPrefix("textures/items/") { value = String(value.dropFirst("textures/items/".count)) }
        if value.hasPrefix("textures/blocks/") { value = String(value.dropFirst("textures/blocks/".count)) }
        return value
    }

    private static func bundledFilenames(for key: String) -> [String] {
        let normalized = normalizedTextureKey(key)
        var aliases = [normalized, normalized.replacingOccurrences(of: "/", with: "_")]

        let toolSuffixes = ["axe", "hoe", "pickaxe", "shovel", "sword"]
        let toolMaterials: [String: String] = [
            "wooden": "wood", "wood": "wood", "stone": "stone",
            "iron": "iron", "golden": "gold", "gold": "gold",
            "diamond": "diamond", "netherite": "netherite", "copper": "copper"
        ]
        let parts = normalized.split(separator: "_").map(String.init)
        if parts.count >= 2, let material = toolMaterials[parts[0]],
           toolSuffixes.contains(parts.dropFirst().joined(separator: "_")) {
            let suffix = parts.dropFirst().joined(separator: "_")
            let exact = material + "_" + suffix
            let hashedBedrockAlias: [String: [String]] = [
                "gold_axe": ["gold_axe_a44bd60f"],
                "gold_hoe": ["gold_hoe_57b313c5"],
                "wood_axe": ["bedrock_wood_axe_f9db570"],
                "wood_hoe": ["bedrock_wood_hoe_eeacbc6"]
            ]
            let preferred = [exact] + (hashedBedrockAlias[exact] ?? [])
            let available = preferred.filter { bundledResourceURL(forResource: $0, withExtension: "png") != nil }
            if !available.isEmpty { return available }
        }

        let explicitAliases: [String: [String]] = [
            "firework_star": ["fireworks"],
            "tripwire_hook": ["trip_wire"],
            "leather_boots": ["leather_boots"],
            "leather_helmet": ["leather_helmet"],
            "leather_leggings": ["leather_leggings"],
            "leather_horse_armor": ["leather_horse_armor"]
        ]
        aliases.append(contentsOf: explicitAliases[normalized] ?? [])
        let woodTypes = ["oak", "spruce", "birch", "jungle", "acacia", "dark_oak",
                         "mangrove", "cherry", "bamboo", "crimson", "warped", "pale_oak"]
        if let wood = woodTypes.first(where: { normalized.hasPrefix($0 + "_") }) {
            let suffix = String(normalized.dropFirst(wood.count + 1))
            aliases.append(suffix + "_" + wood)
            if suffix == "double_slab" { aliases += ["double_wooden_slab", "double_slab_" + wood] }
            if suffix == "button" { aliases += ["button_" + wood, "wooden_button"] }
            if suffix == "fence" { aliases.append("fence_" + wood) }
            if suffix == "fence_gate" { aliases.append("fence_gate_" + wood) }
            if suffix == "door" { aliases.append("door_" + wood) }
            if suffix == "boat" { aliases.append("boat_" + wood) }
            if suffix == "planks" { aliases.append("planks_" + wood) }
            if suffix == "log" || suffix == "wood" { aliases.append("log_" + wood) }
            if suffix == "leaves" { aliases.append("leaves_" + wood) }
            if suffix == "sapling" { aliases.append("sapling_" + wood) }
            if suffix == "stairs" { aliases.append("stairs_" + wood) }
            if suffix == "slab" { aliases.append("slab_" + wood) }
        }
        return aliases.compactMap { archiveAtlas[$0] ?? bundledAtlas[$0] }.flatMap { $0 }
    }

    private static let bundledAtlas: [String: [String]] = {
        guard let url = bundledResourceURL(forResource: "item_texture_mapping", withExtension: "json"),
              let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    private static func bundledResourceURL(forResource name: String, withExtension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Minecraft/Items")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }

    private static func bundledImage(for key: String) -> UIImage? {
        let normalized = normalizedTextureKey(key)
        let directName = normalized.replacingOccurrences(of: "/", with: "_") + ".png"
        let directURL = assetPackDirectory.appendingPathComponent(directName)
        if let image = UIImage(contentsOfFile: directURL.path) { return image }

        for filename in bundledFilenames(for: normalized) {
            let cacheKey = filename as NSString
            if let cached = bundledImageCache.object(forKey: cacheKey) { return cached }
            let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            let archiveURL = assetPackDirectory.appendingPathComponent(name + ".png")
            let image: UIImage?
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                image = UIImage(contentsOfFile: archiveURL.path)
            } else if let bundledURL = bundledResourceURL(forResource: name, withExtension: "png") {
                image = UIImage(contentsOfFile: bundledURL.path)
            } else {
                image = nil
            }
            guard let image else { continue }
            bundledImageCache.setObject(image, forKey: cacheKey)
            return image
        }
        return nil
    }

    private static func loadAtlases(_ completion: @escaping () -> Void) {
        atlasQueue.async {
            if atlasLoaded {
                DispatchQueue.main.async(execute: completion)
                return
            }
            atlasWaiters.append(completion)
            guard !atlasLoading else { return }
            atlasLoading = true
            let group = DispatchGroup()
            var loadedItems: [String: [String]] = [:]
            var loadedTerrain: [String: [String]] = [:]
            var loadedJavaFallback: [String: String] = [:]

            group.enter()
            fetchAtlas("textures/item_texture.json") { loadedItems = parseAtlas($0); group.leave() }
            group.enter()
            fetchAtlas("textures/terrain_texture.json") { loadedTerrain = parseAtlas($0); group.leave() }
            group.enter()
            fetchJavaFallbackMap { loadedJavaFallback = $0; group.leave() }

            group.notify(queue: atlasQueue) {
                itemAtlas = loadedItems
                terrainAtlas = loadedTerrain
                javaFallbackMap = loadedJavaFallback
                atlasLoaded = true
                atlasLoading = false
                let callbacks = atlasWaiters
                atlasWaiters.removeAll()
                DispatchQueue.main.async { callbacks.forEach { $0() } }
            }
        }
    }

    private static func fetchAtlas(_ path: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: rawRoot + path) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { completion(nil); return }
            completion(data)
        }.resume()
    }

    private static func fetchJavaFallbackMap(completion: @escaping ([String: String]) -> Void) {
        let urlString = "https://raw.githubusercontent.com/PrismarineJS/minecraft-assets/master/data/common/legacy_texturepack_mappings.json"
        guard let url = URL(string: urlString) else { completion([:]); return }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
                completion([:]); return
            }
            var result: [String: String] = [:]
            for (javaPath, bedrockPath) in object {
                let key = javaPath.split(separator: "/").last.map(String.init)?.lowercased() ?? ""
                if !key.isEmpty { result[key] = bedrockPath }
            }
            completion(result)
        }.resume()
    }

    private static func parseAtlas(_ data: Data?) -> [String: [String]] {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let textureData = root["texture_data"] as? [String: Any] else { return [:] }
        var result: [String: [String]] = [:]
        for (key, rawValue) in textureData {
            guard let entry = rawValue as? [String: Any],
                  let rawTextures = entry["textures"] else { continue }
            let values: [String]
            if let one = rawTextures as? String {
                values = [one]
            } else if let many = rawTextures as? [String] {
                values = many
            } else {
                continue
            }
            result[key.lowercased()] = values
        }
        return result
    }

    private static func candidateTexturePaths(for identifier: String) -> [String] {
        var paths: [String] = []
        func add(_ path: String) {
            let normalized = path.hasSuffix(".png") ? String(path.dropLast(4)) : path
            if !paths.contains(normalized) { paths.append(normalized) }
        }

        let name = identifier
            .replacingOccurrences(of: "minecraft:", with: "")
            .replacingOccurrences(of: "minecraft_", with: "")
        let words = name.split(separator: "_").map(String.init)
        let woodTypes = ["oak", "spruce", "birch", "jungle", "acacia", "dark_oak", "mangrove", "cherry", "bamboo", "crimson", "warped", "pale_oak"]
        let material = woodTypes.first { name.hasPrefix($0 + "_") }

        add("textures/items/" + name)
        add("textures/blocks/" + name)

        if let material {
            let suffix = String(name.dropFirst(material.count + 1))
            add("textures/items/" + suffix + "_" + material)
            add("textures/blocks/" + suffix + "_" + material)
            add("textures/items/" + material + "_" + suffix)
            add("textures/blocks/" + material + "_" + suffix)
            if suffix == "wood" { add("textures/blocks/log_" + material) }
            if suffix == "log" { add("textures/blocks/log_" + material) }
            if suffix == "leaves" { add("textures/blocks/leaves_" + material) }
            if suffix == "planks" { add("textures/blocks/planks_" + material) }
            if suffix == "sapling" { add("textures/blocks/sapling_" + material) }
            if suffix == "door" { add("textures/items/door_" + material) }
            if suffix == "boat" { add("textures/items/boat_" + material) }
            if suffix == "button" { add("textures/blocks/button_" + material) }
            if suffix == "fence" { add("textures/blocks/fence_" + material) }
            if suffix == "fence_gate" { add("textures/blocks/fence_gate_" + material) }
            if suffix == "sign" { add("textures/items/sign_" + material) }
            if suffix == "hanging_sign" { add("textures/items/" + material + "_hanging_sign") }
            if suffix == "stairs" { add("textures/blocks/" + material + "_stairs") }
            if suffix == "slab" { add("textures/blocks/" + material + "_slab") }
            if suffix == "trapdoor" { add("textures/blocks/trapdoor_" + material) }
        }

        func normalized(_ value: String) -> String {
            value.lowercased()
                .replacingOccurrences(of: "textures/items/", with: "")
                .replacingOccurrences(of: "textures/blocks/", with: "")
                .replacingOccurrences(of: ".png", with: "")
                .replacingOccurrences(of: "_item", with: "")
        }
        let identifierTokens = Set(words)
        let itemMatches = itemAtlas.filter { key, _ in
            let k = normalized(key)
            let kt = Set(k.split(separator: "_").map(String.init))
            return k == name || name.hasSuffix("_" + k) || k.hasSuffix("_" + name)
                || (kt.count > 1 && kt.isSubset(of: identifierTokens))
                || (material != nil && k == String(name.dropFirst(material!.count + 1)) + "_" + material!)
        }
        for values in itemMatches.values {
            for value in values {
                if value.hasPrefix("textures/") { add(value) }
                else { add("textures/items/" + value) }
            }
        }

        let terrainMatches = terrainAtlas.filter { key, _ in
            let k = normalized(key)
            let kt = Set(k.split(separator: "_").map(String.init))
            return k == name || name.hasSuffix("_" + k) || k.hasSuffix("_" + name)
                || (kt.count > 1 && kt.isSubset(of: identifierTokens))
                || (material != nil && k == String(name.dropFirst(material!.count + 1)) + "_" + material!)
        }
        for values in terrainMatches.values {
            for value in values {
                if value.hasPrefix("textures/") { add(value) }
                else { add("textures/blocks/" + value) }
            }
        }

        let javaKeys = [name, name.replacingOccurrences(of: "_", with: "")]
        for key in javaKeys {
            if let mapped = javaFallbackMap[key] { add(mapped) }
        }
        for (javaKey, bedrockPath) in javaFallbackMap where javaKey == name || name.hasSuffix("_" + javaKey) {
            add(bedrockPath)
        }

        let woodFamilies = ["oak", "spruce", "birch", "jungle", "acacia", "dark_oak",
                            "mangrove", "cherry", "bamboo", "crimson", "warped", "pale_oak"]
        if let wood = woodFamilies.first(where: { name.hasPrefix($0 + "_") }) {
            let suffix = String(name.dropFirst(wood.count + 1))
            let familyNames: [String: [String]] = [
                "button": ["button_\(wood)", "wooden_button"],
                "pressure_plate": ["pressure_plate_\(wood)", "wooden_pressure_plate"],
                "fence": ["fence_\(wood)"],
                "fence_gate": ["fence_gate_\(wood)"],
                "stairs": ["stairs_\(wood)", "\(wood)_stairs"],
                "slab": ["slab_\(wood)", "\(wood)_slab"],
                "double_slab": ["double_slab_\(wood)", "double_wooden_slab"],
                "trapdoor": ["trapdoor_\(wood)"],
                "door": ["door_\(wood)"],
                "planks": ["planks_\(wood)"],
                "log": ["log_\(wood)", "\(wood)_log"],
                "wood": ["log_\(wood)", "\(wood)_log"],
                "leaves": ["leaves_\(wood)"],
                "sapling": ["sapling_\(wood)"],
                "boat": ["boat_\(wood)", "\(wood)_boat"],
                "chest_boat": ["\(wood)_chest_boat", "boat_\(wood)"]
            ]
            for alias in familyNames[suffix] ?? [] {
                add("textures/items/" + alias)
                add("textures/blocks/" + alias)
            }
        }

        let currentPaths = paths
        for candidate in currentPaths {
            if candidate.hasPrefix("textures/items/") {
                add(candidate.replacingOccurrences(of: "textures/items/", with: "textures/item/"))
            } else if candidate.hasPrefix("textures/blocks/") {
                add(candidate.replacingOccurrences(of: "textures/blocks/", with: "textures/block/"))
            }
        }

        let aliases: [String: [String]] = [
            "lodestone": ["textures/blocks/lodestone_side", "textures/blocks/lodestone_top", "textures/items/lodestonecompass_item"],
            "beetroot_seeds": ["textures/items/seeds_beetroot"],
            "obsidian": ["textures/blocks/obsidian"],
            "crafting_table": ["textures/blocks/crafting_table_front", "textures/blocks/crafting_table_side"],
            "wheat_seeds": ["textures/items/seeds_wheat"],
            "golden_apple": ["textures/items/apple_golden"],
            "enchanted_golden_apple": ["textures/items/apple_golden"],
            "golden_carrot": ["textures/items/carrot_golden"],
            "redstone": ["textures/items/redstone_dust"],
            "torch": ["textures/blocks/torch_on", "textures/blocks/torch_on_floor"],
            "bow": ["textures/items/bow_standby"],
            "potion": ["textures/items/potion_bottle_drinkable"],
            "acacia_boat": ["textures/items/boat_acacia"],
            "acacia_chest_boat": ["textures/items/acacia_chest_boat"],
            "acacia_door": ["textures/items/door_acacia"],
            "acacia_planks": ["textures/blocks/planks_acacia"],
            "acacia_log": ["textures/blocks/log_acacia"],
            "acacia_wood": ["textures/blocks/log_acacia"],
            "acacia_leaves": ["textures/blocks/leaves_acacia"],
            "acacia_sapling": ["textures/blocks/sapling_acacia"],
            "acacia_button": ["textures/blocks/button_acacia", "textures/items/button_acacia", "textures/blocks/wooden_button"],
            "acacia_pressure_plate": ["textures/blocks/pressure_plate_acacia", "textures/blocks/wooden_pressure_plate"],
            "acacia_fence": ["textures/blocks/fence_acacia"],
            "acacia_fence_gate": ["textures/blocks/fence_gate_acacia"],
            "acacia_stairs": ["textures/blocks/acacia_stairs", "textures/blocks/stairs_acacia"],
            "acacia_slab": ["textures/blocks/acacia_slab", "textures/blocks/slab_acacia"],
            "acacia_double_slab": ["textures/blocks/double_slab_acacia", "textures/blocks/double_wooden_slab"],
            "air": []
        ]
        for value in aliases[name] ?? [] { add(value) }
        return paths
    }

    private static func fetchFirstImage(_ paths: [String], index: Int = 0,
                                        cacheFile: URL, completion: @escaping (UIImage?) -> Void) {
        guard index < paths.count, let url = URL(string: rawRoot + paths[index] + ".png") else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            if let data, (response as? HTTPURLResponse)?.statusCode == 200,
               let image = UIImage(data: data) {
                do {
                    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                    try data.write(to: cacheFile, options: .atomic)
                } catch { }
                DispatchQueue.main.async { completion(image) }
            } else {
                fetchFirstImage(paths, index: index + 1, cacheFile: cacheFile, completion: completion)
            }
        }.resume()
    }


    private struct IconPackManifest: Codable {
        var successful: [String] = []
        var failed: [String] = []
        var lastUpdated: Date = Date()
    }

    private static var manifestURL: URL {
        cacheDirectory.appendingPathComponent("icon-pack-manifest.json")
    }

    private static func readManifest() -> IconPackManifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(IconPackManifest.self, from: data) else {
            return IconPackManifest()
        }
        return manifest
    }

    private static func writeManifest(_ manifest: IconPackManifest) {
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }

    static var failedIconIdentifiers: [String] {
        MinecraftBedrockIconDatabase.failedIdentifiers
    }

    static func downloadPack(itemIdentifiers: [String],
                             onlyMissing: Bool = false,
                             progress: @escaping (_ completed: Int, _ total: Int, _ failed: Int) -> Void,
                             completion: @escaping (_ downloaded: Int, _ total: Int, _ failed: Int, _ failedIdentifiers: [String]) -> Void) {
        MinecraftBedrockIconDatabase.downloadPack(itemIdentifiers: itemIdentifiers,
            onlyMissing: onlyMissing, progress: progress, completion: completion)
    }

    static var installedPNGCount: Int {
        migrateLegacyPNGsIfNeeded()
        let cached = (try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)) ?? []
        let archive = (try? FileManager.default.contentsOfDirectory(at: assetPackDirectory, includingPropertiesForKeys: nil)) ?? []
        let names = cached.filter { $0.pathExtension.lowercased() == "png" }.map { $0.lastPathComponent }
            + archive.filter { $0.pathExtension.lowercased() == "png" }.map { $0.lastPathComponent }
        return Set(names).count
    }

    static func cachedImage(for textureKey: String) -> UIImage? {
        let normalized = normalizedTextureKey(textureKey)
        if let bundled = bundledImage(for: normalized) { return bundled }
        let safe = normalized.replacingOccurrences(of: "/", with: "_")
        return UIImage(contentsOfFile: cacheDirectory.appendingPathComponent(safe + ".png").path)
    }
}
