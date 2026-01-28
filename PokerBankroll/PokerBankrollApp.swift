import SwiftUI

@main
struct PokerBankrollApp: App {
    @StateObject private var dataStore = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .preferredColorScheme(.light)
        }
    }
}
