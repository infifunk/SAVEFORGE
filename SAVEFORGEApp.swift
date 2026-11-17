import SwiftUI

@main
struct SAVEFORGEApp: App {
    init() {
        SAVEFORGEStartupSessionReset.perform()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(alignment: .topTrailing) {
                    Button {
                        SteamQRRouter.shared.isPresented = true
                    } label: {
                        Label("STEAM", systemImage: "steam")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(red: 0.012, green: 0.020, blue: 0.026))
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .background(Color(red: 0.12, green: 0.88, blue: 0.98))
                            .clipShape(Capsule())
                    }.padding(.top, 6).padding(.trailing, 12)
                }
                .sheet(isPresented: Binding(
                    get: { SteamQRRouter.shared.isPresented },
                    set: { SteamQRRouter.shared.isPresented = $0 }
                )) {
                    NavigationStack { SteamQRLoginScreen() }
                }
        }
    }
}

final class SteamQRRouter: ObservableObject {
    static let shared = SteamQRRouter()
    @Published var isPresented = false
    private init() {}
}
