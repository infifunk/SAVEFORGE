// MARK: - SAVEFORGE app entry point


import SwiftUI

@main
struct SAVEFORGEApp: App {
    init() {
        SAVEFORGEStartupSessionReset.perform()
    }

	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}
