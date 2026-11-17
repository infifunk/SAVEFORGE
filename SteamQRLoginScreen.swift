import SwiftUI
import CoreImage.CIFilterBuiltins

final class SteamQRLoginModel: ObservableObject {
    @Published private(set) var challenge: SteamQRChallenge?
    @Published private(set) var account: SteamAccountSession? = SteamSessionVault.load()
    @Published private(set) var isLoading = false
    @Published private(set) var status = "Connect using the official Steam mobile app."
    @Published private(set) var errorMessage: String?
    private var pollTask: Task<Void, Never>?

    func start() {
        guard !isLoading else { return }
        pollTask?.cancel()
        isLoading = true; errorMessage = nil; status = "Requesting a secure Steam login…"
        Task {
            do {
                let value = try await SteamAuthenticationService.shared.beginQRLogin()
                await MainActor.run {
                    self.challenge = value; self.isLoading = false
                    self.status = "Scan this code with Steam Mobile and approve the sign-in."
                    self.pollTask = Task { await self.pollUntilApproved(value) }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false; self.errorMessage = error.localizedDescription
                    self.status = "Could not start Steam sign-in."
                }
            }
        }
    }

    private func pollUntilApproved(_ value: SteamQRChallenge) async {
        let deadline = Date().addingTimeInterval(600)
        while !Task.isCancelled && Date() < deadline {
            do {
                try await Task.sleep(nanoseconds: UInt64(value.pollInterval * 1_000_000_000))
                if let session = try await SteamAuthenticationService.shared.poll(value) {
                    await MainActor.run {
                        self.account = session; self.challenge = nil
                        self.status = "Steam account connected."
                    }
                    return
                }
            } catch {
                await MainActor.run { self.errorMessage = error.localizedDescription }
                return
            }
        }
        await MainActor.run { self.challenge = nil; self.status = "QR request expired. Start again for a new code." }
    }

    func cancel() {
        pollTask?.cancel(); pollTask = nil; challenge = nil; isLoading = false
        status = "Sign-in cancelled."
    }
    func signOut() {
        pollTask?.cancel(); SteamSessionVault.clear()
        account = nil; challenge = nil; status = "Steam account disconnected."
    }
}

struct SteamQRLoginScreen: View {
    @ObservedObject private var model = SteamQRLoginModel()
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private let cyan = Color(red: 0.12, green: 0.88, blue: 0.98)
    private let gold = Color(red: 1.0, green: 0.70, blue: 0.22)
    private let background = Color(red: 0.012, green: 0.020, blue: 0.026)
    private let panel = Color(red: 0.035, green: 0.060, blue: 0.071)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 7) {
                        Image(systemName: "steam").font(.system(size: 42)).foregroundStyle(cyan)
                        Text("STEAM LINK").font(.system(size: 23, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("SECURE ACCOUNT AUTHENTICATION").font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(gold)
                    }.padding(.top, 14)

                    if let challenge = model.challenge, let image = makeQR(challenge.challengeURL.absoluteString) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                            .frame(width: 236, height: 236).padding(12).background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        Text("SCAN WITH STEAM MOBILE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(.white)
                    } else if model.account != nil {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 62)).foregroundStyle(cyan).padding(30)
                    } else {
                        Image(systemName: "qrcode").font(.system(size: 82, weight: .light)).foregroundStyle(cyan).padding(32)
                    }

                    Text(model.status).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    if let error = model.errorMessage {
                        Text(error).font(.system(size: 11)).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    if let account = model.account {
                        VStack(spacing: 6) {
                            Text("CONNECTED ACCOUNT").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(gold)
                            Text(account.accountName).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        }.frame(maxWidth: .infinity).padding(16).background(panel).clipShape(RoundedRectangle(cornerRadius: 14))
                        Button("DISCONNECT STEAM") { model.signOut() }.foregroundStyle(.red)
                    } else if model.challenge != nil {
                        Button("CANCEL LOGIN") { model.cancel() }.foregroundStyle(gold)
                    } else {
                        Button(action: { model.start() }) {
                            Label("CONNECT WITH STEAM", systemImage: "qrcode")
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(background).frame(maxWidth: .infinity).padding(16)
                                .background(cyan).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.disabled(model.isLoading)
                    }

                    Text("SAVEFORGE never asks for your Steam password. Approve sign-in in the official Steam mobile app. Session tokens are stored in the iOS Keychain.")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center).padding(14).background(panel).clipShape(RoundedRectangle(cornerRadius: 12))
                }.padding(20)
            }
        }.navigationTitle("Steam Account").toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func makeQR(_ value: String) -> UIImage? {
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
