//
// ContentView.swift
// SAVEFORGE — Cyber Forge
// v0.1.2
//
// Nyxian-safe UI foundation.
// No SwiftUI state or environment property wrappers.
//

import SwiftUI
import UniformTypeIdentifiers
import UIKit
import AVKit
import WebKit

struct ContentView: View {
    var body: some View {
        TabView {
            LibraryScreen()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Library")
                }

            RecentScreen()
                .tabItem {
                    Image(systemName: "clock")
                    Text("Recent")
                }

            FavoritesScreen()
                .tabItem {
                    Image(systemName: "star")
                    Text("Favorites")
                }

            SettingsScreen()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .tint(SF.accent)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Library

private struct LibraryScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                SF.background.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForgeHeader()

                        NavigationLink {
                            SaveImportScreen()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.down")
                                Text("IMPORT A SAVE")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .tracking(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(SF.gold)
                            .padding(14)
                            .background(SF.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(SF.gold.opacity(0.35), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)

                        SectionLabel(title: "YOUR GAME LIBRARY", detail: "6 GAMES")

                        LazyVStack(spacing: 14) {
                            ForEach(GameInfo.all) { game in
                                NavigationLink {
                                    GameEditorScreen(game: game)
                                } label: {
                                    GameCard(game: game)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack(spacing: 7) {
                            Image(systemName: "lock.shield")
                            Text("LOCAL-FIRST • YOUR FILES STAY ON YOUR DEVICE • v0.1.2")
                        }
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(SF.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
    }
}

private struct ForgeHeader: View {
    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Spacer()
                NavigationLink {
                    SettingsScreen()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SF.gold)
                        .frame(width: 40, height: 40)
                        .background(SF.panel)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(SF.gold.opacity(0.4), lineWidth: 1))
                }
            }

            ZStack {
                Circle()
                    .stroke(SF.gold, lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .shadow(color: SF.gold.opacity(0.55), radius: 12)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(SF.gold)
                Image(systemName: "hammer.fill")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(SF.accent)
                    .shadow(color: SF.accent.opacity(0.8), radius: 8)
            }
            .frame(height: 76)

            HStack(spacing: 0) {
                Text("SAVE").foregroundStyle(SF.text)
                Text("FORGE")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [SF.gold, Color(red: 1, green: 0.9, blue: 0.62)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .font(.system(size: 34, weight: .black, design: .rounded))
            .tracking(-1)
            .shadow(color: SF.gold.opacity(0.25), radius: 10)

            HStack(spacing: 8) {
                Rectangle().fill(SF.accent).frame(width: 30, height: 1)
                Text("UNIVERSAL GAME SAVE EDITOR FOR iOS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(SF.secondary)
                Rectangle().fill(SF.accent).frame(width: 30, height: 1)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Game card

private struct GameCard: View {
    let game: GameInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: game.bannerURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    case .empty, .failure:
                        LinearGradient(
                            colors: [game.accent.opacity(0.62), SF.artwork.opacity(0.82), Color.black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    @unknown default:
                        Color.black
                    }
                }

                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.04), location: 0.0),
                        .init(color: .black.opacity(0.18), location: 0.38),
                        .init(color: .black.opacity(0.88), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

            }
            .frame(height: 158)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.title.uppercased())
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(0.3)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(game.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(game.statusColor)
                            .frame(width: 6, height: 6)

                        Text(game.statusTitle)
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.9)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(game.statusColor)
                    .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .padding(.bottom, 13)
                .zIndex(2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [game.accent, SF.gold.opacity(0.58), SF.border],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        }
        .shadow(color: game.accent.opacity(0.13), radius: 11, y: 4)
        .overlay(alignment: .topTrailing) {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Button { AppLibraryStore.shared.toggleFavorite(game.id) } label: {
                    Image(systemName: AppLibraryStore.shared.favoriteIDs.contains(game.id) ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(SF.gold)
                        .frame(width: 38, height: 38).background(.black.opacity(0.76)).clipShape(Circle())
                }.buttonStyle(.plain).padding(10)
            }
        }
    }
}

// MARK: - Game editor

private struct GameEditorScreen: View {
    let game: GameInfo

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                game.background.ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: game.bannerURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .empty, .failure:
                                    LinearGradient(
                                        colors: [game.accent.opacity(0.62), SF.artwork, .black],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                @unknown default:
                                    Color.black
                                }
                            }
                            .frame(width: geometry.size.width - 32, height: 205)
                            .clipped()

                            LinearGradient(
                                colors: [.clear, .black.opacity(0.84)],
                                startPoint: .center,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.title.uppercased())
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                Text(game.subtitle)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .lineLimit(2)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(width: geometry.size.width - 32, height: 205)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(game.accent.opacity(0.55), lineWidth: 1)
                        }

                        ScreenshotGallery(game: game)

                        if game.id == "fallout" {
                            Button {
                                StoredVaultSaveLoader.presentPicker()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 18, weight: .bold))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("LOAD VAULT.SAV FROM STORAGE")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                        Text("Choose a save previously imported on the Library screen")
                                            .font(.system(size: 10)).foregroundStyle(SF.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundStyle(SF.gold)
                                }
                                .foregroundStyle(SF.accent)
                                .padding(14)
                                .background(SF.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(SF.accent.opacity(0.55), lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button {
                                FSSEDependencyCatalog.shared.downloadAll { result in
                                    DispatchQueue.main.async {
                                        let message: String
                                        switch result {
                                        case .success(let files): message = "Offline catalogs ready: \(files.joined(separator: ", "))."
                                        case .failure(let error): message = error.localizedDescription
                                        }
                                        let alert = UIAlertController(title: "Vault.sav Dependencies", message: message, preferredStyle: .alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                                        UIApplication.shared.topMostViewController?.present(alert, animated: true)
                                    }
                                }
                            } label: {
                                TimelineView(.periodic(from: .now, by: 1)) { _ in
                                    let installed = FSSEDependencyCatalog.shared.allDependenciesInstalled
                                    HStack(spacing: 10) {
                                        Image(systemName: installed ? "checkmark.seal.fill" : "arrow.down.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(installed ? "VAULT.SAV DEPENDENCIES INSTALLED" : "DOWNLOAD VAULT.SAV DEPENDENCIES")
                                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                            Text(installed ? "All JSON catalogs ready for offline editing" : "Install JSON catalogs for offline editing")
                                                .font(.system(size: 10)).foregroundStyle(SF.muted)
                                        }
                                        Spacer()
                                        Image(systemName: installed ? "checkmark" : "chevron.right")
                                            .foregroundStyle(installed ? SF.accent : SF.gold)
                                    }
                                    .foregroundStyle(SF.accent).padding(14).background(SF.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(SF.accent.opacity(0.55), lineWidth: 1))
                                }
                            }.buttonStyle(.plain)
                            SectionLabel(title: "VAULT MODULES", detail: "SELECT TO EDIT")
                            ForEach(game.modules, id: \.title) { module in
                                NavigationLink {
                                    FalloutShelterEditorHost(moduleTitle: module.title)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: module.symbol)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(SF.accent)
                                            .frame(width: 42, height: 42)
                                            .background(SF.accent.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 11))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(module.title.uppercased())
                                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                                .foregroundStyle(SF.text)
                                            Text(module.detail)
                                                .font(.system(size: 10))
                                                .foregroundStyle(SF.muted)
                                        }
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(SF.gold)
                                    }
                                    .padding(13)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(SF.panel)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(LinearGradient(colors: [SF.accent.opacity(0.55), SF.gold.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            SectionLabel(title: "EDITOR MODULES", detail: "PLANNED")
                            ForEach(game.modules, id: \.title) { module in
                                HStack(spacing: 12) {
                                    Image(systemName: module.symbol)
                                        .font(.system(size: 17))
                                        .foregroundStyle(game.accent)
                                        .frame(width: 40, height: 40)
                                        .background(game.accent.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(module.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(SF.text)
                                        Text(module.detail).font(.system(size: 10)).foregroundStyle(SF.muted)
                                    }
                                    Spacer(minLength: 8)
                                    Text("PLANNED").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(SF.muted)
                                }
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(game.panel).clipShape(RoundedRectangle(cornerRadius: 13))
                                .overlay { RoundedRectangle(cornerRadius: 13).stroke(game.border, lineWidth: 1) }
                            }
                        }

                        Text(game.id == "fallout" ? "IMPORT A VAULT.SAV, THEN OPEN A MODULE TO EDIT ITS DATA. EXPORT CREATES A SEPARATE COPY." : "This is a visual preview. Editing will be enabled after the game's save format and import/export workflow are implemented and tested.")
                            .font(.system(size: 10))
                            .foregroundStyle(SF.muted)
                            .lineSpacing(3)
                    }
                    .frame(width: geometry.size.width - 32, alignment: .leading)
                    .padding(.top, 14)
                    .padding(.bottom, 112)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("SAVEFORGE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Screenshot gallery

private struct ScreenshotGallery: View {
    let game: GameInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "SCREENSHOTS & CLIPS", detail: "TAP TO OPEN")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ScreenshotTile(url: game.screenshotURL, accent: game.accent, label: "GAMEPLAY")
                    ScreenshotTile(url: game.bannerURL, accent: game.accent, label: "GAME ART")
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct ScreenshotTile: View {
    let url: String
    let accent: Color
    let label: String

    var body: some View {
        NavigationLink {
            MediaPreviewScreen(urlString: url, title: label, accent: accent)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                AsyncImage(url: URL(string: url)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .empty, .failure:
                        LinearGradient(
                            colors: [accent.opacity(0.45), SF.artwork, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(accent)
                        }
                    @unknown default:
                        Color.black
                    }
                }
                .frame(width: 218, height: 124)
                .clipped()
                HStack {
                    Text(label)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SF.panel)
            }
            .frame(width: 218)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent.opacity(0.45), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct MediaPreviewScreen: View {
    let urlString: String
    let title: String
    let accent: Color

    private var isVideo: Bool {
        let value = urlString.lowercased()
        return value.contains(".mp4") || value.contains(".mov") || value.contains(".m4v")
    }

    private var isGIF: Bool {
        urlString.lowercased().contains(".gif")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = URL(string: urlString), isVideo {
                NativeVideoPlayer(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else if let url = URL(string: urlString), isGIF {
                AnimatedWebMedia(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView().tint(accent)
                    case .failure:
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 30))
                                .foregroundStyle(accent)
                            Text("Image could not be loaded")
                                .foregroundStyle(.white)
                        }
                    @unknown default:
                        Color.black
                    }
                }
                .padding(12)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct NativeVideoPlayer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        controller.player?.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player == nil {
            controller.player = AVPlayer(url: url)
            controller.player?.play()
        }
    }
}

private struct AnimatedWebMedia: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if view.url != url {
            view.load(URLRequest(url: url))
        }
    }
}

// MARK: - Load a previously imported Fallout Shelter save from app storage

private enum StoredVaultSaveLoader {
    static func presentPicker() {
        let files = AppFileStore.files(in: AppFileStore.importedDirectory)
            .filter { $0.pathExtension.lowercased() == "sav" }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        guard let presenter = UIApplication.shared.topMostViewController else { return }
        guard !files.isEmpty else {
            let alert = UIAlertController(
                title: "No Stored Vault Saves",
                message: "Import a Fallout Shelter .sav file using IMPORT A SAVE on the Library screen first. It will then appear here.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
            return
        }

        let sheet = UIAlertController(title: "Load Vault From Storage", message: "Select a previously imported .sav file", preferredStyle: .actionSheet)
        for file in files {
            let title = "\(file.lastPathComponent)  •  \(AppFileStore.fileSize(file))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                load(file, from: presenter)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        }
        presenter.present(sheet, animated: true)
    }

    private static func load(_ file: URL, from presenter: UIViewController) {
        do {
            let data = try Data(contentsOf: file)
            let decoded = try FSSEStore.shared.decrypt(data)
            let store = FSSEStore.shared
            store.save = decoded
            store.originalFileName = file.lastPathComponent

            let alert = UIAlertController(
                title: "Vault Loaded",
                message: "Loaded \(file.lastPathComponent) into the Fallout Shelter editor.\n\nVault: \(store.vaultName)\nDwellers: \(store.dwellers.count)\nRooms: \(store.rooms.count)\nInventory items: \(store.inventory.count)\n\nOpen any Vault module to edit this save.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Could Not Load Save",
                message: "This stored file could not be decrypted as a Fallout Shelter Vault.sav.\n\n\(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
        }
    }
}

// MARK: - Import screen / UIKit document picker

private struct SaveImportScreen: View {
    var body: some View {
        ImportPickerControllerHost()
            .background(SF.background.ignoresSafeArea())
            .overlay {
                VStack(spacing: 12) {
                    ProgressView().tint(SF.gold)
                    Text("OPENING FILES…")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(SF.gold)
                    Text("SELECT A GAME SAVE TO IMPORT")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(SF.muted)
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Import Save")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct ImportPickerControllerHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ImportPickerViewController {
        ImportPickerViewController()
    }

    func updateUIViewController(_ controller: ImportPickerViewController, context: Context) {}
}

private final class ImportPickerViewController: UIViewController, UIDocumentPickerDelegate {
    private var hasPresentedPicker = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresentedPicker else { return }
        hasPresentedPicker = true
        presentFilesPicker()
    }

    private func presentFilesPicker() {
        // Request a local copy from Files providers. This avoids relying on
        // in-place document access, which can prevent some providers from handing
        // the selected save back to embedded UIKit hosts such as Nyxian.
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.data],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .formSheet
        present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        returnToLibrary()
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            returnToLibrary()
            return
        }
        importSelectedFile(url)
    }

    private func importSelectedFile(_ url: URL) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let detected = try SaveEngineDetector.detect(
                data: data,
                filename: url.lastPathComponent
            )

            switch detected {
            case .falloutShelter(let decoded):
                let store = FSSEStore.shared
                store.save = decoded
                store.originalFileName = url.lastPathComponent

                do {
                    try AppFileStore.importFile(url)
                    showResult(
                        title: "IMPORT SUCCESSFUL",
                        message: "Your Fallout Shelter save was imported and loaded successfully.\n\nFile: \(url.lastPathComponent)\nVault: \(store.vaultName)\nDwellers: \(store.dwellers.count)\nRooms: \(store.rooms.count)\nInventory items: \(store.inventory.count)\n\nAn untouched backup was saved in Settings > Imported Files."
                    )
                } catch {
                    showResult(
                        title: "IMPORT SUCCESSFUL — BACKUP ERROR",
                        message: "Your Fallout Shelter save was loaded into the editor, but SAVEFORGE could not create its backup in Settings > Imported Files.\n\nFile: \(url.lastPathComponent)\n\nBackup error: \(error.localizedDescription)\n\nYour working save is still loaded."
                    )
                }

            case .recognizedButUnavailable(let gameName):
                showResult(
                    title: "IMPORT ERROR — EDITOR UNAVAILABLE",
                    message: "SAVEFORGE recognized this as a \(gameName) save, but its editing engine is not available yet. Your original file was not modified or imported."
                )

            case .unknown:
                showResult(
                    title: "IMPORT ERROR — UNSUPPORTED FILE",
                    message: "SAVEFORGE could not identify this file as a supported game save. Nothing was changed and no backup was added. Check the relevant game page for supported save formats."
                )
            }
        } catch {
            showResult(
                title: "IMPORT ERROR",
                message: "SAVEFORGE could not read or process this file.\n\n\(error.localizedDescription)"
            )
        }
    }

    private func showResult(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.returnToLibrary()
        })
        present(alert, animated: true)
    }

    private func returnToLibrary() {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        }
    }
}

private enum DetectedSaveEngine {
    case falloutShelter([String: Any])
    case recognizedButUnavailable(String)
    case unknown
}

private enum SaveEngineDetector {
    static func detect(data: Data, filename: String) throws -> DetectedSaveEngine {
        // Fallout Shelter saves are Base64-wrapped AES data. A successful decrypt plus
        // vault/dwellers structure validation is the authoritative engine match.
        if let vault = try? FSSEStore.shared.decrypt(data) {
            return .falloutShelter(vault)
        }

        // Do not route a failed Fallout decrypt into another editor. These signatures
        // are conservative format hints only; their game engines must exist before editing.
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        let lowerName = filename.lowercased()
        if ext == "plr" || lowerName.contains("stardew") {
            return .recognizedButUnavailable("Stardew Valley")
        }
        if ext == "wld" || ext == "twld" || lowerName.contains("terraria") {
            return .recognizedButUnavailable("Terraria")
        }
        if lowerName == "level.dat" || lowerName.contains("minecraft") || ext == "mcworld" {
            return .recognizedButUnavailable("Minecraft Bedrock")
        }
        if lowerName.contains("theotown") || ext == "city" {
            return .recognizedButUnavailable("TheoTown")
        }
        if lowerName.contains("worldbox") {
            return .recognizedButUnavailable("WorldBox")
        }
        return .unknown
    }
}

// MARK: - Recent / favorites / settings

private struct RecentScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                SF.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "RECENTLY OPENED", detail: "NEWEST FIRST")
                        let games = GameInfo.all.filter { AppLibraryStore.shared.recentIDs.contains($0.id) }.sorted { a, b in
                            (AppLibraryStore.shared.recentIDs.firstIndex(of: a.id) ?? 999) < (AppLibraryStore.shared.recentIDs.firstIndex(of: b.id) ?? 999)
                        }
                        if games.isEmpty {
                            EmptyLibraryState(title: "NO RECENT GAMES", detail: "Games you open will appear here.", symbol: "clock")
                        } else {
                            ForEach(games) { game in
                                NavigationLink { GameEditorScreen(game: game) } label: { GameCard(game: game) }.buttonStyle(.plain)
                            }
                        }
                    }.padding(16)
                }
            }.navigationTitle("Recent").toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct FavoritesScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                SF.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionLabel(title: "YOUR FAVORITES", detail: "PINNED GAMES")
                        let games = GameInfo.all.filter { AppLibraryStore.shared.favoriteIDs.contains($0.id) }
                        if games.isEmpty {
                            EmptyLibraryState(title: "NO FAVORITES YET", detail: "Open a game and tap the star to pin it here.", symbol: "star")
                        } else {
                            ForEach(games) { game in
                                NavigationLink { GameEditorScreen(game: game) } label: { GameCard(game: game) }.buttonStyle(.plain)
                            }
                        }
                    }.padding(16)
                }
            }.navigationTitle("Favorites").toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct EmptyLibraryState: View {
    let title: String; let detail: String; let symbol: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(SF.gold)
            Text(title).font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(SF.text)
            Text(detail).font(.system(size: 11)).foregroundStyle(SF.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(28).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                SF.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SETTINGS").font(.system(size: 27, weight: .black, design: .rounded)).foregroundStyle(SF.text)
                        SectionLabel(title: "FILE MANAGEMENT", detail: "LOCAL STORAGE")
                        NavigationLink { ImportedFilesScreen() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill").foregroundStyle(SF.accent).frame(width: 25)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Imported Files").font(.system(size: 12, weight: .semibold)).foregroundStyle(SF.text)
                                    Text("Browse, share, and back up files copied into SAVEFORGE").font(.system(size: 10)).foregroundStyle(SF.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(SF.gold)
                            }.padding(13).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                        NavigationLink { StorageViewerScreen() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "internaldrive.fill").foregroundStyle(SF.accent).frame(width: 25)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Internal Storage Viewer").font(.system(size: 12, weight: .semibold)).foregroundStyle(SF.text)
                                    Text("Inspect SAVEFORGE folders, catalogs, and stored files").font(.system(size: 10)).foregroundStyle(SF.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(SF.gold)
                            }.padding(13).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                        NavigationLink { StorageCleanupScreen() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash.slash.fill").foregroundStyle(SF.gold).frame(width: 25)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Clear Storage").font(.system(size: 12, weight: .semibold)).foregroundStyle(SF.text)
                                    Text("Remove downloaded catalogs, temporary exports, or imported backups").font(.system(size: 10)).foregroundStyle(SF.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(SF.gold)
                            }.padding(13).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                        SettingLine(icon: "arrow.counterclockwise", title: "Backup policy", detail: "Original files remain unchanged")
                        SettingLine(icon: "checkmark.shield", title: "Save validation", detail: "Game-specific checks enabled where supported")
                        SectionLabel(title: "APPLICATION", detail: "V0.1.2")
                        NavigationLink { SaveforgeCreditsScreen() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "info.circle.fill").foregroundStyle(SF.gold).frame(width: 25)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Credits").font(.system(size: 12, weight: .semibold)).foregroundStyle(SF.text)
                                    Text("Developer links and community") .font(.system(size: 10)).foregroundStyle(SF.muted)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(SF.gold)
                            }.padding(13).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                        SettingLine(icon: "app", title: "Version", detail: "0.1.2")
                        SettingLine(icon: "iphone", title: "Platform", detail: "iOS and iPadOS")
                        SettingLine(icon: "wifi.slash", title: "Connectivity", detail: "Designed for offline use")
                    }.padding(18)
                }
            }.navigationTitle("Settings").toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct SaveforgeCreditsScreen: View {
    var body: some View {
        ZStack {
            SF.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        Image(systemName: "gearshape.2.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(SF.gold)
                        Text("SAVEFORGE")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(SF.text)
                        Text("UNIVERSAL GAME SAVE EDITOR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(SF.accent)
                        Text("A universal save management and editing project for supported games.")
                            .font(.system(size: 12))
                            .foregroundStyle(SF.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 18)
                    .background(SF.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    SectionLabel(title: "CONNECT WITH SAVEFORGE", detail: "PROJECT & COMMUNITY")
                    Link(destination: URL(string: "https://github.com/infifunk/")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right").foregroundStyle(SF.gold).frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("GitHub").font(.system(size: 13, weight: .bold)).foregroundStyle(SF.text)
                                Text("Visit the developer profile").font(.system(size: 10)).foregroundStyle(SF.muted)
                            }
                            Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(SF.gold)
                        }.padding(14).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Link(destination: URL(string: "https://discord.gg/44gZWmEVzy")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill").foregroundStyle(SF.accent).frame(width: 26)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SAVEFORGE Discord").font(.system(size: 13, weight: .bold)).foregroundStyle(SF.text)
                                Text("Join the community").font(.system(size: 10)).foregroundStyle(SF.muted)
                            }
                            Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(SF.gold)
                        }.padding(14).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("SAVEFORGE • UNIVERSAL GAME SAVE EDITOR")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(SF.muted)
                        .padding(.top, 12)
                }.padding(18)
            }
        }
        .navigationTitle("Credits")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct ImportedFilesScreen: View {
    var body: some View { LocalFilesList(title: "Imported Files", directory: AppFileStore.importedDirectory) }
}
private struct StorageViewerScreen: View {
    var body: some View { LocalFilesList(title: "Internal Storage", directory: AppFileStore.documentsDirectory) }
}

private struct StorageCleanupScreen: View {
    var body: some View {
        ZStack {
            SF.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("STORAGE CLEANUP").font(.system(size: 23, weight: .black, design: .rounded)).foregroundStyle(SF.text)
                    Text("Choose what to remove. Each action asks for confirmation before deleting anything.")
                        .font(.system(size: 11)).foregroundStyle(SF.secondary)
                    cleanupButton(title: "Clear Downloaded JSON Catalogs", detail: "Removes offline Fallout Shelter dependencies. You can download them again.", symbol: "doc.zipper", destructive: true) {
                        StorageCleanup.removeDownloadedCatalogs()
                    }
                    cleanupButton(title: "Clear Temporary Exports", detail: "Removes temporary files created during export. Imported backups are preserved.", symbol: "arrow.up.doc", destructive: true) {
                        StorageCleanup.removeTemporaryExports()
                    }
                    cleanupButton(title: "Clear Imported Backups", detail: "Permanently removes copies in Settings → Imported Files. Your original files outside SAVEFORGE are untouched.", symbol: "folder.badge.minus", destructive: true) {
                        StorageCleanup.removeImportedBackups()
                    }
                    Text("The currently loaded save in memory is not changed by these storage actions.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(SF.muted).padding(.top, 5)
                }.padding(18)
            }
        }.navigationTitle("Clear Storage").toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func cleanupButton(title: String, detail: String, symbol: String, destructive: Bool, action: @escaping () -> Void) -> some View {
        Button {
            StorageCleanup.confirm(title: title, message: detail, action: action)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).foregroundStyle(SF.gold).frame(width: 25)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(SF.text)
                    Text(detail).font(.system(size: 10)).foregroundStyle(SF.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").foregroundStyle(SF.gold)
            }.padding(14).background(SF.panel).clipShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

private enum StorageCleanup {
    static func confirm(title: String, message: String, action: @escaping () -> Void) {
        guard let presenter = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in action() })
        presenter.topPresentedViewController.present(alert, animated: true)
    }
    static func removeDownloadedCatalogs() {
        let folder = AppFileStore.documentsDirectory.appendingPathComponent("SAVEFORGE/VaultDependencies", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
    }
    static func removeTemporaryExports() {
        let folder = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix("SAVEFORGE-") { try? FileManager.default.removeItem(at: file) }
    }
    static func removeImportedBackups() {
        let folder = AppFileStore.importedDirectory
        for file in AppFileStore.files(in: folder) { try? FileManager.default.removeItem(at: file) }
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}

private struct LocalFilesList: View {
    let title: String; let directory: URL
    var body: some View {
        ZStack {
            SF.background.ignoresSafeArea()
            List {
                let files = AppFileStore.files(in: directory)
                if files.isEmpty {
                    Text("No files stored here yet.").foregroundStyle(SF.secondary).listRowBackground(SF.panel)
                } else {
                    ForEach(files, id: \.path) { file in
                        ShareLink(item: file) {
                            HStack(spacing: 10) {
                                Image(systemName: file.hasDirectoryPath ? "folder.fill" : "doc.fill").foregroundStyle(SF.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(file.lastPathComponent).font(.system(size: 12, weight: .semibold)).foregroundStyle(SF.text)
                                    Text(AppFileStore.fileSize(file)).font(.system(size: 9, design: .monospaced)).foregroundStyle(SF.muted)
                                }
                                Spacer(); Image(systemName: "square.and.arrow.up").foregroundStyle(SF.gold)
                            }
                        }.listRowBackground(SF.panel)
                    }
                }
            }.scrollContentBackground(.hidden)
        }.navigationTitle(title).toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private enum AppFileStore {
    static var documentsDirectory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var importedDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Imported Files", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func files(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles]))?.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending } ?? []
    }
    static func fileSize(_ url: URL) -> String {
        let n = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }
    static func importFile(_ source: URL) throws {
        let destination = importedDirectory.appendingPathComponent(source.lastPathComponent)
        var target = destination
        if FileManager.default.fileExists(atPath: target.path) {
            let stem = source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension
            target = importedDirectory.appendingPathComponent("\(stem)-\(Int(Date().timeIntervalSince1970)).\(ext)")
        }
        let accessed = source.startAccessingSecurityScopedResource(); defer { if accessed { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: source, to: target)
    }
}

private final class AppLibraryStore {
    static let shared = AppLibraryStore()
    private let recentKey = "saveforge.recent.game.ids"
    private let favoriteKey = "saveforge.favorite.game.ids"
    var recentIDs: [String] { UserDefaults.standard.stringArray(forKey: recentKey) ?? [] }
    var favoriteIDs: [String] { UserDefaults.standard.stringArray(forKey: favoriteKey) ?? [] }
    func recordOpen(_ id: String) { var ids = recentIDs.filter { $0 != id }; ids.insert(id, at: 0); UserDefaults.standard.set(Array(ids.prefix(20)), forKey: recentKey) }
    func toggleFavorite(_ id: String) { var ids = favoriteIDs; if ids.contains(id) { ids.removeAll { $0 == id } } else { ids.append(id) }; UserDefaults.standard.set(ids, forKey: favoriteKey) }
}

private struct SettingLine: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(SF.accent)
                .frame(width: 25)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SF.text)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(SF.muted)
            }
            Spacer()
        }
        .padding(13)
        .background(SF.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SectionLabel: View {
    let title: String
    let detail: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(SF.gold)
            Spacer()
            Text(detail)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(SF.muted)
        }
    }
}

// MARK: - Game data

private struct GameInfo: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    let background: Color
    let panel: Color
    let border: Color
    let modules: [EditorModule]

    // Each game owns its own library-card status and status color.
    var statusTitle: String {
        switch id {
        case "fallout": return "EDITOR READY"
        case "stardew": return "COMING SOON"
        case "terraria": return "COMING SOON"
        case "minecraft": return "COMING SOON"
        case "theotown": return "COMING SOON"
        case "worldbox": return "COMING SOON"
        default: return "COMING SOON"
        }
    }

    var statusColor: Color {
        switch id {
        case "fallout": return SF.steelBlue
        case "stardew": return SF.bronze
        case "terraria": return SF.bronze
        case "minecraft": return SF.bronze
        case "theotown": return SF.bronze
        case "worldbox": return SF.bronze
        default: return SF.secondary
        }
    }

    var bannerURL: String {
        switch id {
        case "fallout":
            return "https://cdn.akamai.steamstatic.com/steam/apps/588430/header.jpg"
        case "stardew":
            return "https://cdn.akamai.steamstatic.com/steam/apps/413150/header.jpg"
        case "terraria":
            return "https://cdn.akamai.steamstatic.com/steam/apps/105600/header.jpg"
        case "minecraft":
            return "https://www.destructoid.com/wp-content/uploads/2024/03/multiple-biomes-minecraft-survival-seed.jpg?resize=1200%2C675"
        case "theotown":
            return "https://www.predygames.com/media/img/steam/1084020/shot_01-1280.webp"
        case "worldbox":
            return "https://cdn.akamai.steamstatic.com/steam/apps/1206560/header.jpg"
        default:
            return ""
        }
    }

    var screenshotURL: String {
        switch id {
        case "fallout":
            return "https://i.jeuxactus.com/datas/jeux/f/a/fallout-shelter/xl/fallout-shelter-55cc9ef7dd98a.jpg"
        case "stardew":
            return "https://s2-techtudo.glbimg.com/VTlAvyhoCAykYIKNbF63_hVccKM%3D/1200x/smart/filters%3Acover%28%29%3Astrip_icc%28%29/i.s3.glbimg.com/v1/AUTH_08fbf48bc0524877943fe86e43087e7a/internal_photos/bs/2023/k/a/7PvxlJQrmWcE8EBvaSAg/imagem-2023-03-06-162257080.png"
        case "terraria":
            return "https://gameinformer.com/sites/default/files/styles/thumbnail/public/2021/03/22/8fbc6ae5/terraria1.jpg.webp"
        case "minecraft":
            return "https://staticg.sportskeeda.com/editor/2024/04/da621-17142697021066-1920.jpg?w=1600"
        case "theotown":
            return "https://is1-ssl.mzstatic.com/image/thumb/Purple123/v4/96/8c/9a/968c9a16-e50d-f4b9-2d41-465a7bd5668b/mzl.nytsmknt.png/1366x1024bb.jpg"
        case "worldbox":
            return "https://clan.fastly.steamstatic.com/images/39496096/e72f427c09c562b5662bf6b0bac8b6a112c2a9ca.gif"
        default:
            return ""
        }
    }

    static let all: [GameInfo] = [
        GameInfo(
            id: "fallout", title: "Fallout Shelter",
            subtitle: "Vault management and save editing",
            symbol: "building.2.crop.circle",
            accent: Color(red: 0.36, green: 0.91, blue: 0.48),
            background: Color(red: 0.025, green: 0.045, blue: 0.035),
            panel: Color(red: 0.055, green: 0.085, blue: 0.065),
            border: Color(red: 0.16, green: 0.29, blue: 0.19),
            modules: [
                EditorModule(title: "Vault Overview", detail: "Vault number and general data", symbol: "building.2"),
                EditorModule(title: "Resources", detail: "Caps, power, food, water and more", symbol: "bolt.fill"),
                EditorModule(title: "Dwellers", detail: "Stats, SPECIAL and assignments", symbol: "person.2"),
                EditorModule(title: "Inventory", detail: "Weapons, outfits, pets and items", symbol: "backpack"),
                EditorModule(title: "Rooms", detail: "Room data and vault layout", symbol: "square.grid.3x3"),
                EditorModule(title: "Export Save", detail: "Create and save an edited Vault.sav copy", symbol: "square.and.arrow.up")
            ]
        ),
        GameInfo(
            id: "stardew", title: "Stardew Valley",
            subtitle: "Farm, inventory, skills and relationships",
            symbol: "leaf",
            accent: Color(red: 0.88, green: 0.67, blue: 0.35),
            background: Color(red: 0.12, green: 0.085, blue: 0.055),
            panel: Color(red: 0.19, green: 0.135, blue: 0.085),
            border: Color(red: 0.34, green: 0.24, blue: 0.15),
            modules: [
                EditorModule(title: "Farm & Player", detail: "Farm identity and player information", symbol: "leaf"),
                EditorModule(title: "Inventory", detail: "Items, quantities and equipment", symbol: "backpack"),
                EditorModule(title: "Skills", detail: "Skill levels and experience", symbol: "chart.bar"),
                EditorModule(title: "Relationships", detail: "Friendship and social data", symbol: "heart")
            ]
        ),
        GameInfo(
            id: "terraria", title: "Terraria",
            subtitle: "Character, inventory and world data",
            symbol: "tree",
            accent: Color(red: 0.43, green: 0.77, blue: 0.91),
            background: Color(red: 0.035, green: 0.055, blue: 0.09),
            panel: Color(red: 0.075, green: 0.105, blue: 0.16),
            border: Color(red: 0.16, green: 0.24, blue: 0.36),
            modules: [
                EditorModule(title: "Character", detail: "Player stats and progression", symbol: "person"),
                EditorModule(title: "Inventory", detail: "Items, stacks and equipment", symbol: "backpack"),
                EditorModule(title: "Equipment", detail: "Armor and accessories", symbol: "shield"),
                EditorModule(title: "World", detail: "World information and settings", symbol: "globe")
            ]
        ),
        GameInfo(
            id: "minecraft", title: "Minecraft Bedrock",
            subtitle: "World, player and inventory data",
            symbol: "cube.transparent",
            accent: Color(red: 0.48, green: 0.78, blue: 0.43),
            background: Color(red: 0.055, green: 0.075, blue: 0.055),
            panel: Color(red: 0.105, green: 0.14, blue: 0.095),
            border: Color(red: 0.21, green: 0.30, blue: 0.18),
            modules: [
                EditorModule(title: "World", detail: "World settings and information", symbol: "globe"),
                EditorModule(title: "Player", detail: "Player data and game mode", symbol: "person"),
                EditorModule(title: "Inventory", detail: "Items and inventory data", symbol: "square.grid.3x3"),
                EditorModule(title: "World Rules", detail: "Supported world rule settings", symbol: "slider.horizontal.3")
            ]
        ),
        GameInfo(
            id: "theotown", title: "TheoTown",
            subtitle: "City management and simulation data",
            symbol: "building.2",
            accent: Color(red: 0.39, green: 0.72, blue: 0.89),
            background: Color(red: 0.035, green: 0.065, blue: 0.085),
            panel: Color(red: 0.07, green: 0.12, blue: 0.15),
            border: Color(red: 0.15, green: 0.27, blue: 0.33),
            modules: [
                EditorModule(title: "City", detail: "City identity and information", symbol: "building.2"),
                EditorModule(title: "Economy", detail: "Funds and city resources", symbol: "banknote"),
                EditorModule(title: "Buildings", detail: "Building and placement data", symbol: "house"),
                EditorModule(title: "Population", detail: "Population and city growth", symbol: "person.3")
            ]
        ),
        GameInfo(
            id: "worldbox", title: "WorldBox",
            subtitle: "World creator and sandbox data",
            symbol: "globe.americas",
            accent: Color(red: 0.79, green: 0.69, blue: 0.40),
            background: Color(red: 0.075, green: 0.065, blue: 0.045),
            panel: Color(red: 0.13, green: 0.115, blue: 0.075),
            border: Color(red: 0.29, green: 0.25, blue: 0.15),
            modules: [
                EditorModule(title: "World", detail: "World information and settings", symbol: "globe"),
                EditorModule(title: "Civilizations", detail: "Kingdom and settlement data", symbol: "crown"),
                EditorModule(title: "Creatures", detail: "Creature and unit information", symbol: "pawprint"),
                EditorModule(title: "History", detail: "World events and progression", symbol: "clock")
            ]
        )
    ]
}

private struct EditorModule {
    let title: String
    let detail: String
    let symbol: String
}

// MARK: - Colors

private enum SF {
    static let background = Color(red: 0.012, green: 0.020, blue: 0.026)
    static let panel = Color(red: 0.035, green: 0.060, blue: 0.071)
    static let artwork = Color(red: 0.018, green: 0.040, blue: 0.052)
    static let accent = Color(red: 0.12, green: 0.88, blue: 0.98)
    static let gold = Color(red: 1.00, green: 0.70, blue: 0.22)
    static let text = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let secondary = Color(red: 0.66, green: 0.73, blue: 0.78)
    static let muted = Color(red: 0.39, green: 0.49, blue: 0.55)
    static let border = Color(red: 0.12, green: 0.25, blue: 0.30)

    // Expanded Cyber Forge palette for independent card accents and UI states.
    static let bronze = Color(red: 0.78, green: 0.43, blue: 0.24)
    static let copper = Color(red: 0.82, green: 0.49, blue: 0.31)
    static let steel = Color(red: 0.62, green: 0.69, blue: 0.75)
    static let steelBlue = Color(red: 0.43, green: 0.66, blue: 0.82)
    static let slate = Color(red: 0.39, green: 0.49, blue: 0.60)
    static let emerald = Color(red: 0.30, green: 0.72, blue: 0.52)
    static let farmGold = Color(red: 0.88, green: 0.68, blue: 0.38)
    static let violet = Color(red: 0.64, green: 0.53, blue: 0.86)
    static let crimson = Color(red: 0.82, green: 0.34, blue: 0.34)
    static let amber = Color(red: 0.96, green: 0.59, blue: 0.22)
    static let teal = Color(red: 0.22, green: 0.68, blue: 0.69)
}


// =====================================================
// FALLOUT SHELTER ENGINE — ported from FSSE iOS v1.2.1
// =====================================================

import CommonCrypto

func fsseError(_ message: String) -> NSError {
    NSError(domain: "SAVEFORGE.FalloutShelter", code: 1,
            userInfo: [NSLocalizedDescriptionKey: message])
}

extension Data {
    init(hex: String) {
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            data.append(UInt8(hex[index..<next], radix: 16) ?? 0)
            index = next
        }
        self = data
    }
}


struct FSSEDwellerCatalogItem {
    let id: String
    let name: String
    let lastName: String
    let rarity: String
    let raw: [String: Any]
    var displayName: String { [name, lastName].filter { !$0.isEmpty }.joined(separator: " ") }
}

final class FSSEStore {
    static let shared = FSSEStore()
    private init() {}

    var save: [String: Any]?
    var originalFileName = "Vault.sav"
    private let aesKey = Data(hex:
        "A7CA9F3366D892C2F0BEF417341CA971" +
        "B69AE9F7BACCCFFCF43C62D1D7D021F9"
    )
    private let aesIV = Data(hex: "7475383967656A693334307438397532")
    var isLoaded: Bool { save != nil }

    func decrypt(_ encrypted: Data) throws -> [String: Any] {
        guard let text = String(data: encrypted, encoding: .utf8) else {
            throw fsseError("Save file is not valid text.")
        }
        let cleaned = text.components(separatedBy: .whitespacesAndNewlines).joined()
        guard let input = Data(base64Encoded: cleaned) else {
            throw fsseError("Unable to decode save file.")
        }
        let decrypted = try crypt(input, operation: CCOperation(kCCDecrypt))
        guard let json = try JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else {
            throw fsseError("Decrypted data is not valid vault JSON.")
        }
        try validateSaveStructure(json)
        return json
    }

    func encrypt() throws -> Data {
        guard let save else { throw fsseError("No vault is loaded.") }
        try validateSaveStructure(save)
        let json = try JSONSerialization.data(withJSONObject: save, options: [.sortedKeys])
        let encrypted = try crypt(json, operation: CCOperation(kCCEncrypt))
        // Verify the encrypted payload can be decrypted and parsed before it is offered for export.
        let verification = try crypt(encrypted, operation: CCOperation(kCCDecrypt))
        guard let verified = try JSONSerialization.jsonObject(with: verification) as? [String: Any] else {
            throw fsseError("Export verification failed. No file was exported.")
        }
        try validateSaveStructure(verified)
        return Data(encrypted.base64EncodedString().utf8)
    }

    private func validateSaveStructure(_ candidate: [String: Any]) throws {
        guard let vault = candidate["vault"] as? [String: Any],
              let dwellersContainer = candidate["dwellers"] as? [String: Any],
              dwellersContainer["dwellers"] is [[String: Any]],
              vault["storage"] is [String: Any],
              vault["inventory"] is [String: Any],
              vault["rooms"] is [[String: Any]] else {
            throw fsseError("This file does not contain the expected Fallout Shelter vault structure. The current vault was not changed.")
        }
    }

    private func crypt(_ input: Data, operation: CCOperation) throws -> Data {
        let capacity = input.count + kCCBlockSizeAES128
        var output = Data(count: capacity)
        var moved = 0
        let status = aesKey.withUnsafeBytes { key in
            aesIV.withUnsafeBytes { iv in
                input.withUnsafeBytes { source in
                    output.withUnsafeMutableBytes { destination in
                        CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                key.baseAddress, kCCKeySizeAES256,
                                iv.baseAddress, source.baseAddress, input.count,
                                destination.baseAddress, capacity, &moved)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            throw fsseError("AES operation failed. Status: \(status)")
        }
        output.count = moved
        return output
    }

    private var vault: [String: Any] { save?["vault"] as? [String: Any] ?? [:] }

    var vaultName: String {
        get { vault["VaultName"] as? String ?? "My Vault" }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            data["VaultName"] = newValue
            root["vault"] = data
            save = root
        }
    }

    // The UI field is intentionally labelled VaultID, but Fallout Shelter's
    // displayed vault identifier for this editor comes from the VaultName key.
    // Preserve the original string exactly and write edits back to VaultName.
    var vaultID: String {
        get { vault["VaultName"] as? String ?? "Unknown" }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            data["VaultName"] = newValue
            root["vault"] = data
            save = root
        }
    }

    var resources: [String: Any] {
        get {
            let storage = vault["storage"] as? [String: Any] ?? [:]
            return storage["resources"] as? [String: Any] ?? [:]
        }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            var storage = data["storage"] as? [String: Any] ?? [:]
            storage["resources"] = newValue
            data["storage"] = storage
            root["vault"] = data
            save = root
        }
    }
    func setResource(_ key: String, value: Double) {
        var data = resources
        data[key] = value
        resources = data
    }

    var lunchBoxesByType: [Int] {
        get {
            if let values = vault["LunchBoxesByType"] as? [Int] { return values }
            if let values = vault["LunchBoxesByType"] as? [NSNumber] { return values.map { $0.intValue } }
            return []
        }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            data["LunchBoxesByType"] = newValue
            data["LunchBoxesCount"] = newValue.count
            root["vault"] = data
            save = root
        }
    }
    func lunchBoxCount(for type: Int) -> Int { lunchBoxesByType.filter { $0 == type }.count }
    func setLunchBoxCount(type: Int, count: Int) {
        guard (0...3).contains(type), count >= 0 else { return }
        var values = lunchBoxesByType
        values.removeAll { $0 == type }
        if count > 0 { values.append(contentsOf: Array(repeating: type, count: count)) }
        lunchBoxesByType = values
    }

    var dwellers: [[String: Any]] {
        get {
            let data = save?["dwellers"] as? [String: Any] ?? [:]
            return data["dwellers"] as? [[String: Any]] ?? []
        }
        set {
            guard save != nil else { return }
            var root = save!, data = root["dwellers"] as? [String: Any] ?? [:]
            data["dwellers"] = newValue
            root["dwellers"] = data
            save = root
        }
    }

    func updateDweller(index: Int, name: String, lastName: String,
                       level: Int, health: Double, happiness: Double, special: [Int]) {
        var list = dwellers
        guard list.indices.contains(index) else { return }
        var person = list[index]
        person["name"] = name
        person["lastName"] = lastName
        var experience = person["experience"] as? [String: Any] ?? [:]
        experience["currentLevel"] = level
        person["experience"] = experience
        var healthData = person["health"] as? [String: Any] ?? [:]
        healthData["healthValue"] = health
        person["health"] = healthData
        var happinessData = person["happiness"] as? [String: Any] ?? [:]
        happinessData["happinessValue"] = happiness
        person["happiness"] = happinessData
        var statsData = person["stats"] as? [String: Any] ?? [:]
        var stats = statsData["stats"] as? [[String: Any]] ?? []
        // Fallout Shelter stores SPECIAL in stat-record positions 1...7.
        // Position 0 is a separate non-SPECIAL record and must remain untouched.
        let specialRecordIndexes = [1, 2, 3, 4, 5, 6, 7]
        guard stats.count > 7, special.count >= 7 else { return }

        for (specialPosition, recordIndex) in specialRecordIndexes.enumerated() {
            var stat = stats[recordIndex]
            stat["value"] = NSNumber(value: special[specialPosition])
            stats[recordIndex] = stat
        }
        statsData["stats"] = stats
        person["stats"] = statsData
        list[index] = person
        dwellers = list
    }

    func removeDweller(at index: Int) {
        var root = save ?? [:]
        var list = dwellers
        guard list.indices.contains(index) else { return }
        let removed = list.remove(at: index)
        let removedID = (removed["serializeId"] as? NSNumber)?.intValue
        var container = root["dwellers"] as? [String: Any] ?? [:]
        container["dwellers"] = list
        root["dwellers"] = container

        // If the resident was still waiting at the Vault Door, remove that
        // queue reference too so the save cannot point at a deleted resident.
        if let removedID {
            var spawner = root["dwellerSpawner"] as? [String: Any] ?? [:]
            let waiting = spawner["dwellersWaiting"] as? [[String: Any]] ?? []
            spawner["dwellersWaiting"] = waiting.filter {
                ($0["dwellerId"] as? NSNumber)?.intValue != removedID
            }
            root["dwellerSpawner"] = spawner
        }
        save = root
    }

    // Adds a unique dweller to the save roster and registers that dweller in
    // the game's actual Vault Door arrival queue (dwellerSpawner.dwellersWaiting).
    func addUniqueDweller(_ item: FSSEDwellerCatalogItem) throws {
        guard isLoaded else { throw fsseError("Import a vault before adding dwellers.") }
        var root = save!
        var list = dwellers
        guard var person = list.first else {
            throw fsseError("This vault has no dweller template. Add a resident in-game first.")
        }
        // Compare only the canonical unique-dweller catalog key. Catalog JSON may
        // also contain an unrelated `id` field, so the dictionary key is retained
        // separately as `_saveforgeCatalogID` when the catalog is loaded.
        let canonicalID = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = list.first(where: { person in
            guard let savedID = person["uniqueData"] as? String else { return false }
            return savedID.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(canonicalID) == .orderedSame
        }) {
            let first = match["name"] as? String ?? "Unknown"
            let last = match["lastName"] as? String ?? ""
            let existingName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
            throw fsseError("Duplicate unique dweller ID: \(canonicalID)\nExisting resident: \(existingName)\nLoaded save: \(originalFileName)\nResidents: \(list.count)")
        }

        var spawner = root["dwellerSpawner"] as? [String: Any] ?? [:]
        var waiting = spawner["dwellersWaiting"] as? [[String: Any]] ?? []
        guard waiting.count < 10 else {
            throw fsseError("The Vault Door waiting line is full (10 dwellers). Accept or remove someone from the line before adding another unique dweller.")
        }

        person["name"] = item.name
        person["lastName"] = item.lastName
        person["uniqueData"] = item.id

        let source = item.raw
        for key in ["gender", "hair", "hairColor", "skinColor", "faceMask"] {
            if let value = source[key] { person[key] = value }
        }

        let ids = list.compactMap { ($0["serializeId"] as? NSNumber)?.intValue }
        let newID = (ids.max() ?? 0) + 1
        person["serializeId"] = NSNumber(value: newID)
        person["assigned"] = false
        person["WillGoToWasteland"] = false
        person["WillBeEvicted"] = false
        person["IsEvictedWaitingForFollowers"] = false
        person["savedRoom"] = -1

        if let values = source["stats"] as? [Int], values.count >= 7 {
            var container = person["stats"] as? [String: Any] ?? [:]
            var stats = container["stats"] as? [[String: Any]] ?? []
            // Catalog values are ordered S, P, E, C, I, A, L;
            // the save stores them at record indexes 1...7.
            let specialRecordIndexes = [1, 2, 3, 4, 5, 6, 7]
            if stats.count > 7 {
                for (specialPosition, recordIndex) in specialRecordIndexes.enumerated() {
                    var stat = stats[recordIndex]
                    stat["value"] = NSNumber(value: values[specialPosition])
                    stats[recordIndex] = stat
                }
                container["stats"] = stats
                person["stats"] = container
            }
        }

        var experience = person["experience"] as? [String: Any] ?? [:]
        experience["currentLevel"] = 1
        experience["currentExperience"] = 0
        person["experience"] = experience

        var happiness = person["happiness"] as? [String: Any] ?? [:]
        happiness["happinessValue"] = 100
        person["happiness"] = happiness

        var health = person["health"] as? [String: Any] ?? [:]
        if let maximum = health["maxHealth"] as? NSNumber {
            health["healthValue"] = maximum.doubleValue
        }
        person["health"] = health

        // The queue stores a reference to the new dweller by serializeId.
        // Keep the game's existing queue entries intact and append Preston (or
        // whichever unique dweller was selected) as a new arrival at the door.
        list.append(person)
        var dwellersContainer = root["dwellers"] as? [String: Any] ?? [:]
        dwellersContainer["dwellers"] = list
        root["dwellers"] = dwellersContainer

        waiting.append([
            "newDweller": true,
            "charType": "Dweller",
            "dwellerId": NSNumber(value: newID)
        ])
        spawner["dwellersWaiting"] = waiting
        root["dwellerSpawner"] = spawner
        save = root
    }

    var inventory: [[String: Any]] {
        get {
            let data = vault["inventory"] as? [String: Any] ?? [:]
            return data["items"] as? [[String: Any]] ?? []
        }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            var inventoryData = data["inventory"] as? [String: Any] ?? [:]
            inventoryData["items"] = newValue
            data["inventory"] = inventoryData
            root["vault"] = data
            save = root
        }
    }
    // Each Add Item action is limited to 20 units; repeated additions may grow the stored total beyond 20.
    @discardableResult
    func addInventoryItem(id: String, type: String, quantity: Int) -> Int {
        guard quantity > 0 else { return 0 }
        var list = inventory
        let allowed = min(quantity, 20)
        for _ in 0..<allowed {
            list.append(["id": id, "type": type, "hasBeenAssigned": false,
                         "hasRandonWeaponBeenAssigned": false])
        }
        inventory = list
        return allowed
    }
    func removeInventoryItem(index: Int) {
        var list = inventory
        guard list.indices.contains(index) else { return }
        list.remove(at: index)
        inventory = list
    }

    func setInventoryQuantity(id: String, type: String, quantity: Int) {
        guard quantity >= 0 else { return }
        let existing = inventory.filter {
            "\($0["id"] ?? "")" == id && "\($0["type"] ?? "item")" == type
        }
        var template = existing.first ?? [
            "id": id, "type": type, "hasBeenAssigned": false,
            "hasRandonWeaponBeenAssigned": false
        ]
        template["id"] = id
        template["type"] = type
        var rebuilt = inventory.filter {
            "\($0["id"] ?? "")" != id || "\($0["type"] ?? "item")" != type
        }
        if quantity > 0 {
            for _ in 0..<quantity { rebuilt.append(template) }
        }
        inventory = rebuilt
    }

    var rooms: [[String: Any]] {
        get { vault["rooms"] as? [[String: Any]] ?? [] }
        set {
            guard save != nil else { return }
            var root = save!, data = root["vault"] as? [String: Any] ?? [:]
            data["rooms"] = newValue
            root["vault"] = data
            save = root
        }
    }
    func updateRoom(index: Int, level: Int) {
        var list = rooms
        guard list.indices.contains(index) else { return }
        list[index]["level"] = level
        rooms = list
    }
}

final class FSSEDependencyCatalog {
    static let shared = FSSEDependencyCatalog()
    private init() {}
    private let baseURL = "https://raw.githubusercontent.com/dneverson/fallout-shelter-save-editor/main/public/gamedata/"
    private let filenames = ["weapons.json", "outfits.json", "pets.json", "junk.json", "unique-dwellers.json"]
    private var folder: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SAVEFORGE/VaultDependencies", isDirectory: true) }
    var allDependenciesInstalled: Bool {
        filenames.allSatisfy { file in
            let url = folder.appendingPathComponent(file)
            guard let data = try? Data(contentsOf: url), !data.isEmpty,
                  (try? JSONSerialization.jsonObject(with: data)) != nil else { return false }
            return true
        }
    }
    func downloadAll(completion: @escaping (Result<[String], Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                try FileManager.default.createDirectory(at: self.folder, withIntermediateDirectories: true)
                let group = DispatchGroup(); let lock = NSLock(); var installed: [String] = []; var failures: [String] = []
                for file in self.filenames {
                    group.enter()
                    guard let url = URL(string: self.baseURL + file) else { lock.lock(); failures.append(file); lock.unlock(); group.leave(); continue }
                    URLSession.shared.dataTask(with: url) { data, response, error in
                        defer { group.leave() }
                        guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                              (try? JSONSerialization.jsonObject(with: data)) != nil else { lock.lock(); failures.append(file); lock.unlock(); return }
                        do { try data.write(to: self.folder.appendingPathComponent(file), options: .atomic); lock.lock(); installed.append(file); lock.unlock() }
                        catch { lock.lock(); failures.append(file); lock.unlock() }
                    }.resume()
                }
                group.wait()
                if failures.isEmpty { completion(.success(installed.sorted())) }
                else { completion(.failure(fsseError("Some catalogs could not be downloaded: \(failures.joined(separator: ", ")). Online IDs remain available when connected; downloaded catalogs are used offline."))) }
            } catch { completion(.failure(error)) }
        }
    }
    func records(named name: String) -> [[String: Any]] {
        let file = name == "dwellers" ? "unique-dwellers.json" : name + ".json"
        let url = folder.appendingPathComponent(file)
        guard let data = try? Data(contentsOf: url), let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        if let array = object as? [[String: Any]] { return array }
        if let dict = object as? [String: Any] {
            for key in ["items", "dwellers", "data", "results"] { if let array = dict[key] as? [[String: Any]] { return array } }
            return dict.compactMap { key, value in
                guard var entry = value as? [String: Any] else { return nil }
                if name == "dwellers" {
                    // The JSON object's key (for example, L_Preston) is the stable
                    // Fallout Shelter uniqueData identifier. Never substitute an
                    // unrelated `id` property from inside the catalog record.
                    entry["_saveforgeCatalogID"] = key
                    if entry["name"] == nil && entry["Name"] == nil { return nil }
                    if entry["isHidden"] as? Bool == true { return nil }
                } else if entry["id"] == nil && entry["ID"] == nil {
                    entry["id"] = key
                }
                return entry
            }.sorted { "\($0["name"] ?? $0["Name"] ?? "")".localizedCaseInsensitiveCompare("\($1["name"] ?? $1["Name"] ?? "")") == .orderedAscending }
        }
        return []
    }
    static func roomName(for raw: Any) -> String {
        let value = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if let n = Int(value) {
            let names = [
                0: "Elevator", 1: "Living Quarters", 2: "Diner",
                3: "Power Generator", 4: "Water Treatment", 5: "Storage Room",
                6: "Medbay", 7: "Science Lab", 8: "Nuka-Cola Bottler",
                9: "Garden", 10: "Water Purifier", 11: "Nuclear Reactor",
                12: "Fitness Room", 13: "Lounge", 14: "Game Room",
                15: "Weapon Workshop", 16: "Outfit Workshop", 17: "Theme Workshop",
                18: "Weight Room", 19: "Athletics Room", 20: "Armory",
                21: "Classroom", 22: "Barbershop", 23: "Radio Studio",
                24: "Overseer's Office"
            ]
            return names[n] ?? "Unknown Room (\(n))"
        }

        // Save files commonly store internal class identifiers such as
        // RoomPowerGenerator rather than the human-readable room title.
        let key = value.lowercased().filter { $0.isLetter || $0.isNumber }
        let aliases: [String: String] = [
            "entrance": "Vault Entrance", "vaultentrance": "Vault Entrance",
            "fakewasteland": "Wasteland Access", "wasteland": "Wasteland Access",
            "elevator": "Elevator", "roomelevator": "Elevator",
            "livingquarters": "Living Quarters", "roomlivingquarters": "Living Quarters",
            "diner": "Diner", "roomdiner": "Diner",
            "powergenerator": "Power Generator", "roompowergenerator": "Power Generator",
            "watertreatment": "Water Treatment", "roomwatertreatment": "Water Treatment",
            "storageroom": "Storage Room", "storage": "Storage Room", "roomstorage": "Storage Room",
            "medbay": "Medbay", "roommedbay": "Medbay",
            "sciencelab": "Science Lab", "roomsciencelab": "Science Lab",
            "nukacolabottler": "Nuka-Cola Bottler", "nukacolafactory": "Nuka-Cola Bottler",
            "nukacolaplant": "Nuka-Cola Bottler", "roomnukacolabottler": "Nuka-Cola Bottler",
            "garden": "Garden", "roomgarden": "Garden",
            "waterpurifier": "Water Purifier", "roomwaterpurifier": "Water Purifier",
            "nuclearreactor": "Nuclear Reactor", "roomnuclearreactor": "Nuclear Reactor",
            "fitnessroom": "Fitness Room", "roomfitnessroom": "Fitness Room",
            "lounge": "Lounge", "roomlounge": "Lounge",
            "gameroom": "Game Room", "roomgameroom": "Game Room",
            "weaponworkshop": "Weapon Workshop", "weaponfactory": "Weapon Workshop",
            "roomweaponworkshop": "Weapon Workshop", "roomweaponfactory": "Weapon Workshop",
            "outfitworkshop": "Outfit Workshop", "outfitfactory": "Outfit Workshop",
            "roomoutfitworkshop": "Outfit Workshop", "roomoutfitfactory": "Outfit Workshop",
            "themeworkshop": "Theme Workshop", "roomthemeworkshop": "Theme Workshop",
            "weightroom": "Weight Room", "roomweightroom": "Weight Room",
            "athleticsroom": "Athletics Room", "roomathleticsroom": "Athletics Room",
            "armory": "Armory", "roomarmory": "Armory",
            "classroom": "Classroom", "roomclassroom": "Classroom",
            "barbershop": "Barbershop", "roombarbershop": "Barbershop",
            "radiostudio": "Radio Studio", "roomradiostudio": "Radio Studio",
            "overseersoffice": "Overseer's Office", "roomoverseersoffice": "Overseer's Office"
        ]
        if let name = aliases[key] { return name }

        // Make unfamiliar internal identifiers readable instead of showing raw class names.
        var readable = value
        if readable.hasPrefix("Room") { readable.removeFirst(4) }
        readable = readable.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let spaced = readable.replacingOccurrences(
            of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression
        )
        return spaced.isEmpty ? "Unknown Room" : spaced
    }

    static func inventoryName(id: String, type: String) -> String {
        let normalized = type.lowercased()
        let catalog: String
        switch normalized {
        case "weapon": catalog = "weapons"
        case "outfit": catalog = "outfits"
        case "pet": catalog = "pets"
        default: catalog = normalized
        }
        let records = FSSEDependencyCatalog.shared.records(named: catalog)
        if let match = records.first(where: {
            let recordID = "\($0["id"] ?? $0["ID"] ?? "")"
            return recordID.caseInsensitiveCompare(id) == .orderedSame
        }) {
            return match["name"] as? String ?? match["Name"] as? String ?? id
        }
        return id.replacingOccurrences(of: "_", with: " ")
    }
}

private extension UIApplication {
    var topMostViewController: UIViewController? {
        let root = connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

// =====================================================
// FALLOUT SHELTER EDITOR HOST
// UIKit bridge avoids SwiftUI property wrappers in Nyxian.
// =====================================================

private struct FalloutShelterEditorHost: UIViewControllerRepresentable {
    let moduleTitle: String
    func makeUIViewController(context: Context) -> UIViewController {
        FalloutShelterEditorController(moduleTitle: moduleTitle)
    }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}


// Searchable unique-dweller catalog picker. Uses a real table/search interface
// rather than a truncated action sheet, so the complete JSON catalog is browsable.
private final class SAVEFORGEDwellerCatalogPicker: UITableViewController, UISearchResultsUpdating {
    private let entries: [[String: Any]]
    private let onSelect: ([String: Any]) -> Void
    private let alreadyAddedIDs: Set<String>
    private var filteredEntries: [[String: Any]]
    private let searchController = UISearchController(searchResultsController: nil)
    private var selectionHandled = false
    private var selectedIndexPath: IndexPath?

    init(entries: [[String: Any]], alreadyAddedIDs: Set<String>, onSelect: @escaping ([String: Any]) -> Void) {
        self.entries = entries
        self.filteredEntries = entries
        self.alreadyAddedIDs = Set(alreadyAddedIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = "Add Dweller"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.012, green: 0.020, blue: 0.026, alpha: 1)
        tableView.backgroundColor = view.backgroundColor
        tableView.separatorColor = UIColor(white: 0.22, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "dwellerCatalogCell")
        tableView.rowHeight = 64
        tableView.keyboardDismissMode = .onDrag
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelPicker))
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search dwellers by name or rarity"
        searchController.searchBar.tintColor = UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
        searchController.searchBar.searchTextField.textColor = .white
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.prompt = "TAP A DWELLER TO ADD"
        definesPresentationContext = true
    }

    @objc private func cancelPicker() { dismiss(animated: true) }

    private func catalogID(for entry: [String: Any]) -> String {
        (entry["_saveforgeCatalogID"] as? String
            ?? entry["id"] as? String
            ?? entry["ID"] as? String
            ?? entry["uniqueData"] as? String
            ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isAlreadyAdded(_ entry: [String: Any]) -> Bool {
        let id = catalogID(for: entry)
        return !id.isEmpty && alreadyAddedIDs.contains(id)
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { filteredEntries = entries; tableView.reloadData(); return }
        filteredEntries = entries.filter { entry in
            let first = entry["name"] as? String ?? entry["Name"] as? String ?? ""
            let last = entry["lastName"] as? String ?? entry["LastName"] as? String ?? entry["last_name"] as? String ?? ""
            let rarity = entry["rarity"] as? String ?? entry["Rarity"] as? String ?? ""
            return "\(first) \(last) \(rarity)".localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredEntries.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "dwellerCatalogCell", for: indexPath)
        let entry = filteredEntries[indexPath.row]
        let first = entry["name"] as? String ?? entry["Name"] as? String ?? "Dweller"
        let last = entry["lastName"] as? String ?? entry["LastName"] as? String ?? entry["last_name"] as? String ?? ""
        let rarity = entry["rarity"] as? String ?? entry["Rarity"] as? String ?? "Common"
        var content = cell.defaultContentConfiguration()
        content.text = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        let alreadyAdded = isAlreadyAdded(entry)
        content.secondaryText = alreadyAdded ? "ALREADY ADDED" : rarity
        content.textProperties.color = alreadyAdded ? UIColor(white: 0.58, alpha: 1) : .white
        content.secondaryTextProperties.color = alreadyAdded
            ? UIColor(red: 0.78, green: 0.62, blue: 0.30, alpha: 1)
            : UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
        content.textProperties.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 11, weight: .medium)
        cell.contentConfiguration = content

        let normalBackground = UIColor(red: 0.025, green: 0.040, blue: 0.050, alpha: 1)
        let selectedBackground = UIColor(red: 0.035, green: 0.22, blue: 0.25, alpha: 1)
        if alreadyAdded {
            cell.backgroundColor = normalBackground
            cell.accessoryType = .none
            cell.selectionStyle = .none
        } else if selectedIndexPath == indexPath {
            cell.backgroundColor = selectedBackground
            cell.accessoryType = .checkmark
            cell.tintColor = UIColor(red: 0.20, green: 0.92, blue: 0.98, alpha: 1)
            cell.selectionStyle = .default
        } else {
            cell.backgroundColor = normalBackground
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !selectionHandled, filteredEntries.indices.contains(indexPath.row) else { return }
        guard !isAlreadyAdded(filteredEntries[indexPath.row]) else { return }

        // Give immediate, unmistakable feedback so a tap is not mistaken for
        // merely dismissing the search keyboard.
        selectionHandled = true
        selectedIndexPath = indexPath
        let selected = filteredEntries[indexPath.row]
        let first = selected["name"] as? String ?? selected["Name"] as? String ?? "Dweller"
        let last = selected["lastName"] as? String ?? selected["LastName"] as? String ?? selected["last_name"] as? String ?? ""
        let displayName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")

        searchController.searchBar.resignFirstResponder()
        navigationItem.prompt = "ADDING \(displayName.uppercased())…"
        tableView.reloadRows(at: [indexPath], with: .automatic)
        tableView.isUserInteractionEnabled = false
        navigationItem.leftBarButtonItem?.isEnabled = false

        // Keep the checkmark and ADDING status visible briefly before closing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            self.dismiss(animated: true) {
                self.onSelect(selected)
            }
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        "\(filteredEntries.count) DWELLERS AVAILABLE"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String {
        filteredEntries.isEmpty ? "No dwellers match that search." : "ALREADY ADDED entries cannot be selected. Tap an available dweller to add them."
    }
}

// Searchable inventory picker, matching the dweller catalog experience.
// Shows the complete installed JSON catalogs and filters across item name, ID, and category.
private final class SAVEFORGEInventoryCatalogPicker: UITableViewController, UISearchResultsUpdating {
    private let entries: [(record: [String: Any], catalog: String)]
    private let onSelect: ([String: Any], String) -> Void
    private var filteredEntries: [(record: [String: Any], catalog: String)]
    private let searchController = UISearchController(searchResultsController: nil)

    init(entries: [(record: [String: Any], catalog: String)], onSelect: @escaping ([String: Any], String) -> Void) {
        self.entries = entries
        self.filteredEntries = entries
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        title = "Add Inventory Item"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.012, green: 0.020, blue: 0.026, alpha: 1)
        tableView.backgroundColor = view.backgroundColor
        tableView.separatorColor = UIColor(white: 0.22, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "inventoryCatalogCell")
        tableView.rowHeight = 68
        tableView.keyboardDismissMode = .onDrag
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelPicker))
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search items by name, ID, or category"
        searchController.searchBar.tintColor = UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
        searchController.searchBar.searchTextField.textColor = .white
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    @objc private func cancelPicker() { dismiss(animated: true) }

    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { filteredEntries = entries; tableView.reloadData(); return }
        filteredEntries = entries.filter { item in
            let entry = item.record
            let name = entry["name"] as? String ?? entry["Name"] as? String ?? ""
            let id = "\(entry["id"] ?? entry["ID"] ?? "")"
            let category = item.catalog
            let rarity = entry["rarity"] as? String ?? entry["Rarity"] as? String ?? ""
            return "\(name) \(id) \(category) \(rarity)".localizedCaseInsensitiveContains(query)
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredEntries.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "inventoryCatalogCell", for: indexPath)
        let item = filteredEntries[indexPath.row]
        let entry = item.record
        let id = "\(entry["id"] ?? entry["ID"] ?? "")"
        let name = entry["name"] as? String ?? entry["Name"] as? String ?? id
        let rarity = entry["rarity"] as? String ?? entry["Rarity"] as? String
        var content = cell.defaultContentConfiguration()
        content.text = name
        content.secondaryText = rarity.map { "\(item.catalog.uppercased()) • \($0) • ID: \(id)" } ?? "\(item.catalog.uppercased()) • ID: \(id)"
        content.textProperties.color = .white
        content.secondaryTextProperties.color = UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
        content.textProperties.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        content.secondaryTextProperties.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        cell.contentConfiguration = content
        cell.backgroundColor = UIColor(red: 0.025, green: 0.040, blue: 0.050, alpha: 1)
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard filteredEntries.indices.contains(indexPath.row) else { return }
        let selected = filteredEntries[indexPath.row]
        dismiss(animated: true) { self.onSelect(selected.record, selected.catalog) }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        "\(filteredEntries.count) ITEMS AVAILABLE"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String {
        filteredEntries.isEmpty ? "No inventory items match that search." : "Tap an item to choose its quantity and add it to the vault."
    }
}

private final class FalloutShelterEditorController: UITableViewController, UIDocumentPickerDelegate {
    private let store = FSSEStore.shared
    private let moduleTitle: String
    private var activeSection: Section {
        switch moduleTitle {
        case "Resources": return .resources
        case "Dwellers": return .dwellers
        case "Inventory": return .inventory
        case "Rooms": return .rooms
        case "Export Save": return .export
        default: return .vault
        }
    }

    init(moduleTitle: String) {
        self.moduleTitle = moduleTitle
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var statusMessage = "No vault loaded. Import a Vault.sav to begin."

    private enum Section: Int, CaseIterable {
        case vault, resources, dwellers, inventory, rooms, export
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = moduleTitle == "Dwellers" && store.isLoaded
            ? "DWELLERS • \(store.originalFileName) • \(store.dwellers.count)"
            : moduleTitle.uppercased()
        view.backgroundColor = UIColor(red: 0.012, green: 0.020, blue: 0.026, alpha: 1)
        tableView.backgroundColor = view.backgroundColor
        tableView.separatorColor = UIColor(white: 0.22, alpha: 1)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.rowHeight = 58
        tableView.estimatedRowHeight = 58
        tableView.sectionHeaderTopPadding = 4
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.keyboardDismissMode = .onDrag
        tableView.tintColor = UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
        navigationController?.navigationBar.tintColor = UIColor(red: 0.91, green: 0.70, blue: 0.30, alpha: 1)
        navigationItem.rightBarButtonItems = moduleTitle == "Export Save" ? [
            UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(importSave))
        ] : [
            UIBarButtonItem(title: "Export", style: .done, target: self, action: #selector(exportSave)),
            UIBarButtonItem(title: "Import", style: .plain, target: self, action: #selector(importSave))
        ]
        tableView.tableFooterView = footer()
        configureModuleAction()
    }

    private func configureModuleAction() {
        guard activeSection == .dwellers || activeSection == .inventory else { return }
        // Explicit sizing avoids tableHeaderView/Auto Layout width glitches in Nyxian.
        let width = max(0, tableView.bounds.width)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 68))
        container.backgroundColor = tableView.backgroundColor
        container.autoresizingMask = [.flexibleWidth]
        let button = UIButton(type: .system)
        button.tag = 7401
        button.setTitle(activeSection == .dwellers ? "+  ADD DWELLER FROM JSON" : "+  ADD INVENTORY ITEM FROM JSON", for: .normal)
        button.titleLabel?.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.8
        button.setTitleColor(UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1), for: .normal)
        button.backgroundColor = UIColor(red: 0.035, green: 0.075, blue: 0.085, alpha: 1)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 0.20, green: 0.72, blue: 0.78, alpha: 0.75).cgColor
        button.addTarget(self, action: activeSection == .dwellers ? #selector(addDwellerFromJSON) : #selector(addInventoryFromJSON), for: .touchUpInside)
        button.frame = CGRect(x: 16, y: 8, width: max(0, width - 32), height: 52)
        button.autoresizingMask = [.flexibleWidth]
        container.addSubview(button)
        tableView.tableHeaderView = container
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let width = max(0, tableView.bounds.width)
        let target = CGSize(width: width, height: 68)
        if header.frame.size != target {
            header.frame = CGRect(origin: .zero, size: target)
            tableView.tableHeaderView = header
        }
        if let button = header.viewWithTag(7401) as? UIButton {
            button.frame = CGRect(x: 16, y: 8, width: max(0, width - 32), height: 52)
        }
    }

    @objc private func addDwellerFromJSON() {
        let entries = FSSEDependencyCatalog.shared.records(named: "dwellers")
        guard !entries.isEmpty else {
            showAlert(title: "Dweller JSON Missing", message: "Download Vault.sav Dependencies first. The unique-dwellers catalog is not installed.")
            return
        }
        let existingIDs = Set(self.store.dwellers.compactMap { $0["uniqueData"] as? String })
        let picker = SAVEFORGEDwellerCatalogPicker(entries: entries, alreadyAddedIDs: existingIDs) { [weak self] entry in
            guard let self else { return }
            let name = entry["name"] as? String ?? entry["Name"] as? String ?? "Dweller"
            let lastName = entry["lastName"] as? String ?? entry["LastName"] as? String ?? entry["last_name"] as? String ?? ""
            let identifier = entry["_saveforgeCatalogID"] as? String
                ?? entry["id"] as? String
                ?? entry["ID"] as? String
                ?? entry["uniqueData"] as? String
                ?? UUID().uuidString
            let rarity = entry["rarity"] as? String ?? entry["Rarity"] as? String ?? "Common"
            let item = FSSEDwellerCatalogItem(id: identifier, name: name, lastName: lastName, rarity: rarity, raw: entry)
            do {
                try self.store.addUniqueDweller(item)
                self.tableView.reloadData()
                self.showAlert(title: "Dweller Added", message: "\(item.displayName) was added to your vault.")
            } catch {
                self.showAlert(title: "Could Not Add Dweller", message: error.localizedDescription)
            }
        }
        let navigation = UINavigationController(rootViewController: picker)
        navigation.modalPresentationStyle = .formSheet
        navigationController?.present(navigation, animated: true)
    }

    @objc private func addInventoryFromJSON() {
        let catalogs = ["weapons", "outfits", "pets", "junk"]
        let entries = catalogs.flatMap { catalog in
            FSSEDependencyCatalog.shared.records(named: catalog).map { (record: $0, catalog: catalog) }
        }
        guard !entries.isEmpty else {
            showAlert(title: "Item JSON Missing", message: "Download Vault.sav Dependencies first. The weapons, outfits, pets, and junk catalogs are not installed.")
            return
        }
        let picker = SAVEFORGEInventoryCatalogPicker(entries: entries) { [weak self] entry, type in
            guard let self else { return }
            let id = "\(entry["id"] ?? entry["ID"] ?? entry["name"] ?? entry["Name"] ?? "unknown")"
            let name = entry["name"] as? String ?? entry["Name"] as? String ?? id
            self.prompt(title: "Add \(name) (MAX 20)", value: "1", numeric: true) { value in
                let requested = max(1, Int(value) ?? 1)
                let added = self.store.addInventoryItem(id: id, type: type, quantity: min(requested, 20))
                self.tableView.reloadData()
                if added == 0 {
                    self.showAlert(title: "Item Not Added", message: "Enter a quantity greater than zero.")
                } else {
                    let suffix = requested > 20 ? " Each add operation is limited to 20; you can add more in another operation." : ""
                    self.showAlert(title: "Item Added", message: "Added \(added) × \(name) to your inventory.\(suffix)")
                }
            }
        }
        let navigation = UINavigationController(rootViewController: picker)
        navigation.modalPresentationStyle = .formSheet
        navigationController?.present(navigation, animated: true)
    }

    private func footer() -> UIView {
        let label = UILabel(frame: CGRect(x: 16, y: 0, width: view.bounds.width - 32, height: 54))
        label.text = "SAVEFORGE • FSSE SAVE ENGINE • ORIGINAL FILE IS NOT OVERWRITTEN"
        label.textColor = .secondaryLabel
        label.font = .monospacedSystemFont(ofSize: 9, weight: .medium)
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }

    @objc private func importSave() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.item], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func exportSave() {
        do {
            let data = try store.encrypt()
            let filename = store.originalFileName.isEmpty ? "Vault-Edited.sav" : store.originalFileName
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("SAVEFORGE-" + filename)
            try data.write(to: url, options: .atomic)
            let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            present(picker, animated: true)
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try store.decrypt(data)
            store.save = decoded
            store.originalFileName = url.lastPathComponent
            // Keep a backup copy of every successfully imported save in Settings > Imported Files.
            do { try AppFileStore.importFile(url) }
            catch { showAlert(title: "Vault Imported — Backup Copy Failed", message: "The save was loaded, but SAVEFORGE could not copy it into Settings > Imported Files. \(error.localizedDescription)") }
            statusMessage = "Loaded \(url.lastPathComponent)"
            title = moduleTitle == "Dwellers"
                ? "DWELLERS • \(store.originalFileName) • \(store.dwellers.count)"
                : moduleTitle.uppercased()
            tableView.reloadData()
            showAlert(title: "Vault Imported",
                      message: "Vault: \(store.vaultName)\nVault ID: \(store.vaultID)\nDwellers: \(store.dwellers.count)\nRooms: \(store.rooms.count)\nInventory items: \(store.inventory.count)")
        } catch {
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        statusMessage = "Import cancelled."
    }

    private var loaded: Bool { store.isLoaded }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch activeSection {
        case .vault: return "VAULT OVERVIEW"
        case .resources: return "RESOURCES"
        case .dwellers: return "DWELLERS"
        case .inventory: return "INVENTORY"
        case .rooms: return "ROOMS"
        case .export: return "EXPORT VAULT SAVE"
        }
    }

    private var resourceRows: [(key: String, title: String, symbol: String, value: Double, boxType: Int?)] {
        let definitions: [(String, String, String)] = [
            ("Nuka", "Bottle Caps", "bitcoinsign.circle.fill"),
            ("NukaColaQuantum", "Nuka-Cola Quantum", "drop.fill"),
            ("Food", "Food", "fork.knife"),
            ("Energy", "Power", "bolt.fill"),
            ("Water", "Water", "drop.fill"),
            ("StimPack", "Stimpaks", "cross.case.fill"),
            ("RadAway", "RadAway", "cross.vial.fill")
        ]
        let hiddenTrackers: Set<String> = ["Population", "Happiness", "VaultLevel", "VaultSize", "Dwellers", "RoomCount", "Rooms"]
        var rows: [(key: String, title: String, symbol: String, value: Double, boxType: Int?)] = []
        for (key, title, symbol) in definitions {
            if let raw = store.resources[key], let amount = (raw as? NSNumber)?.doubleValue ?? Double("\(raw)") {
                rows.append((key, title, symbol, amount, nil))
            }
        }
        let boxes: [(String, String, String, Int)] = [
            ("Lunchbox", "Lunchboxes", "shippingbox.fill", 0),
            ("MrHandy", "Mr. Handy", "figure.2.and.child.holdinghands", 1),
            ("PetCarrier", "Pet Carriers", "pawprint.fill", 2),
            ("StarterPack", "Starter Boxes", "gift.fill", 3)
        ]
        for (key, title, symbol, type) in boxes {
            let count = store.lunchBoxCount(for: type)
            rows.append((key, title, symbol, Double(count), type))
        }
        // Ignore non-editable tracker fields and the retired Poker Chips resource.
        rows.removeAll { hiddenTrackers.contains($0.key) || $0.key.lowercased() == "pokerchip" || $0.key.lowercased() == "pokerchips" }
        return rows
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if activeSection == .export { return loaded ? 3 : 2 }
        guard loaded else { return 1 }
        switch activeSection {
        case .vault: return 3
        case .resources: return max(resourceRows.count, 1)
        case .dwellers: return max(store.dwellers.count, 1)
        case .inventory: return max(store.inventory.count, 1)
        case .rooms: return max(store.rooms.count, 1)
        case .export: return 3
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = UIColor(red: 0.035, green: 0.060, blue: 0.071, alpha: 1)
        cell.textLabel?.textColor = UIColor(red: 0.82, green: 0.91, blue: 0.94, alpha: 1)
        cell.textLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        cell.detailTextLabel?.textColor = UIColor(red: 0.48, green: 0.62, blue: 0.67, alpha: 1)
        cell.accessoryType = .none
        cell.selectionStyle = .default

        if activeSection == .export {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = loaded ? "READY • \(store.originalFileName)" : "NO VAULT LOADED"
                cell.textLabel?.textColor = loaded ? UIColor.systemGreen : .secondaryLabel
            case 1:
                cell.textLabel?.text = loaded ? "EXPORT AN EDITED COPY" : "IMPORT A VAULT.SAV FIRST"
                cell.imageView?.image = UIImage(systemName: "square.and.arrow.up")
                cell.imageView?.tintColor = UIColor(red: 0.91, green: 0.70, blue: 0.30, alpha: 1)
                cell.accessoryType = loaded ? .disclosureIndicator : .none
            default:
                cell.textLabel?.text = "ORIGINAL FILE IS NEVER OVERWRITTEN"
                cell.textLabel?.textColor = .secondaryLabel
            }
            return cell
        }

        guard loaded else {
            cell.textLabel?.text = "IMPORT A VAULT.SAV TO EDIT \(moduleTitle.uppercased())"
            cell.textLabel?.textColor = .secondaryLabel
            return cell
        }

        switch activeSection {
        case .vault:
            switch indexPath.row {
            case 0: cell.textLabel?.text = "VaultID: \(store.vaultID)"
            case 1: cell.textLabel?.text = "Dwellers: \(store.dwellers.count)"
            default: cell.textLabel?.text = "Source: \(store.originalFileName)"
            }
            cell.accessoryType = indexPath.row == 0 ? .disclosureIndicator : .none
        case .resources:
            let rows = resourceRows
            if rows.isEmpty { cell.textLabel?.text = "No editable resources found" }
            else {
                let item = rows[indexPath.row]
                cell.textLabel?.text = "\(item.title)  •  \(Int(item.value))"
                cell.imageView?.image = UIImage(systemName: item.symbol)
                cell.imageView?.tintColor = UIColor(red: 0.20, green: 0.88, blue: 0.96, alpha: 1)
                cell.accessoryType = .disclosureIndicator
            }
        case .dwellers:
            let list = store.dwellers
            if list.isEmpty { cell.textLabel?.text = "No dwellers found" }
            else {
                let d = list[indexPath.row]
                let first = d["name"] as? String ?? ""
                let last = d["lastName"] as? String ?? ""
                let displayName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                let level = ((d["experience"] as? [String: Any])?["currentLevel"]) ?? 1
                cell.textLabel?.text = "\(displayName.isEmpty ? "Dweller \(indexPath.row + 1)" : displayName)  •  Lv. \(level)"
                cell.accessoryType = .disclosureIndicator
            }
        case .inventory:
            let list = store.inventory
            if list.isEmpty { cell.textLabel?.text = "No inventory items found" }
            else {
                let item = list[indexPath.row]
                let itemID = "\(item["id"] ?? "")", itemType = "\(item["type"] ?? "item")"
                let quantity = store.inventory.filter { "\($0["id"] ?? "")" == itemID && "\($0["type"] ?? "item")" == itemType }.count
                let friendlyName = FSSEDependencyCatalog.inventoryName(id: itemID, type: itemType)
                cell.textLabel?.text = "\(itemType.capitalized)  •  \(friendlyName)  •  QTY \(quantity)"
                let typeSymbol: String
                switch itemType.lowercased() {
                case "weapon", "weapons": typeSymbol = "scope"
                case "outfit", "outfits": typeSymbol = "tshirt.fill"
                case "pet", "pets": typeSymbol = "pawprint.fill"
                case "junk": typeSymbol = "shippingbox.fill"
                default: typeSymbol = "cube.box.fill"
                }
                cell.imageView?.image = UIImage(systemName: typeSymbol)
                cell.imageView?.tintColor = UIColor(red: 0.91, green: 0.70, blue: 0.30, alpha: 1)
                cell.detailTextLabel?.text = "Tap to adjust quantity"
                cell.accessoryType = .disclosureIndicator
            }
        case .export: break
        case .rooms:
            let list = store.rooms
            if list.isEmpty { cell.textLabel?.text = "No rooms found" }
            else {
                let room = list[indexPath.row]
                let rawType = room["roomType"] ?? room["type"] ?? room["room"] ?? "unknown"
                let roomName = FSSEDependencyCatalog.roomName(for: rawType)
                cell.textLabel?.text = "\(roomName)  •  Level \(room["level"] ?? 1)"
                cell.accessoryType = .disclosureIndicator
            }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        store.isLoaded && activeSection == .dwellers && store.dwellers.indices.contains(indexPath.row)
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .delete
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, store.dwellers.indices.contains(indexPath.row) else { return }
        let person = store.dwellers[indexPath.row]
        let first = person["name"] as? String ?? "Dweller"
        let last = person["lastName"] as? String ?? ""
        let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        let alert = UIAlertController(
            title: "Remove Dweller?",
            message: "Remove \(name) from this vault? This changes the working save. Your imported original backup remains untouched.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
            self.store.removeDweller(at: indexPath.row)
            self.title = "DWELLERS • \(self.store.originalFileName) • \(self.store.dwellers.count)"
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if activeSection == .export {
            if indexPath.row == 1 {
                if loaded { exportSave() } else { importSave() }
            }
            return
        }
        guard loaded else { if indexPath.section == 0 && indexPath.row == 0 { importSave() }; return }
        switch activeSection {
        case .vault:
            if indexPath.row == 0 { prompt(title: "VaultID", value: store.vaultID, numeric: false) { self.store.vaultID = $0; self.tableView.reloadData() } }
        case .resources:
            let rows = resourceRows
            guard rows.indices.contains(indexPath.row) else { return }
            let item = rows[indexPath.row]
            prompt(title: "Edit \(item.title)", value: "\(Int(item.value))", numeric: true) { value in
                guard let amount = Int(value), amount >= 0 else { return }
                if let boxType = item.boxType { self.store.setLunchBoxCount(type: boxType, count: amount) }
                else { self.store.setResource(item.key, value: Double(amount)) }
                self.tableView.reloadData()
            }
        case .dwellers:
            guard store.dwellers.indices.contains(indexPath.row) else { return }
            editDweller(indexPath.row)
        case .inventory:
            guard store.inventory.indices.contains(indexPath.row) else { return }
            let alert = UIAlertController(title: "Inventory Quantity", message: "Use + / − or set the total quantity. Each Add Item operation is limited to 20.", preferredStyle: .alert)
            let current = 1
            alert.addTextField { field in field.text = "\(current)"; field.keyboardType = .numberPad; field.placeholder = "QTY" }
            alert.addAction(UIAlertAction(title: "−", style: .default) { _ in self.store.removeInventoryItem(index: indexPath.row); self.tableView.reloadData() })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "+", style: .default) { _ in
                guard self.store.inventory.indices.contains(indexPath.row) else { return }
                let item = self.store.inventory[indexPath.row]
                self.store.addInventoryItem(id: "\(item["id"] ?? "")", type: "\(item["type"] ?? "item")", quantity: 1)
                self.tableView.reloadData()
            })
            alert.addAction(UIAlertAction(title: "Set QTY", style: .default) { _ in
                guard let text = alert.textFields?.first?.text, let qty = Int(text), qty >= 0,
                      self.store.inventory.indices.contains(indexPath.row) else { return }
                let item = self.store.inventory[indexPath.row]
                let id = "\(item["id"] ?? "")", type = "\(item["type"] ?? "item")"
                self.store.setInventoryQuantity(id: id, type: type, quantity: qty)
                self.tableView.reloadData()

            })
            present(alert, animated: true)
        case .export: break
        case .rooms:
            guard store.rooms.indices.contains(indexPath.row) else { return }
            let current = store.rooms[indexPath.row]["level"] as? Int ?? 1
            let rawType = store.rooms[indexPath.row]["roomType"] ?? store.rooms[indexPath.row]["type"] ?? "unknown"
            prompt(title: "\(FSSEDependencyCatalog.roomName(for: rawType)) Level", value: "\(current)", numeric: true) { value in
                if let level = Int(value) { self.store.updateRoom(index: indexPath.row, level: max(1, level)); self.tableView.reloadData() }
            }
        }
    }

    private func prompt(title: String, value: String, numeric: Bool = false, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.text = value
            if numeric { $0.keyboardType = .decimalPad }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            completion(alert.textFields?.first?.text ?? value)
        })
        present(alert, animated: true)
    }

    private func editDweller(_ index: Int) {
        let list = store.dwellers
        guard list.indices.contains(index) else { return }
        let person = list[index]
        let experience = person["experience"] as? [String: Any] ?? [:]
        let statsData = person["stats"] as? [String: Any] ?? [:]
        let stats = statsData["stats"] as? [[String: Any]] ?? []
        let alert = UIAlertController(title: "Dweller", message: "Edit name, level, health, happiness and SPECIAL values.", preferredStyle: .alert)
        let labels = ["First Name", "Last Name", "Level", "Health", "Happiness", "Strength", "Perception", "Endurance", "Charisma", "Intelligence", "Agility", "Luck"]
        let values = [
            person["name"] as? String ?? "",
            person["lastName"] as? String ?? "",
            "\(experience["currentLevel"] ?? 1)",
            "\((person["health"] as? [String: Any])?["healthValue"] ?? 100)",
            "\((person["happiness"] as? [String: Any])?["happinessValue"] ?? 50)"
        ] + [1, 2, 3, 4, 5, 6, 7].map { $0 < stats.count ? "\(stats[$0]["value"] ?? 1)" : "1" }
        for i in labels.indices {
            alert.addTextField {
                $0.placeholder = labels[i]
                $0.text = values[i]
                if i >= 2 { $0.keyboardType = .decimalPad }
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save Dweller", style: .default) { _ in
            let fields = alert.textFields ?? []
            guard fields.count == 12,
                  let level = Int(fields[2].text ?? ""),
                  let hp = Double(fields[3].text ?? ""),
                  let happy = Double(fields[4].text ?? "") else {
                self.showAlert(title: "Invalid Values", message: "Check the numeric fields.")
                return
            }
            var special: [Int] = []
            for i in 5..<12 {
                guard let value = Int(fields[i].text ?? "") else {
                    self.showAlert(title: "Invalid SPECIAL", message: "SPECIAL values must be whole numbers.")
                    return
                }
                special.append(value)
            }
            self.store.updateDweller(index: index,
                                     name: fields[0].text ?? "",
                                     lastName: fields[1].text ?? "",
                                     level: level, health: hp, happiness: happy,
                                     special: special)
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

