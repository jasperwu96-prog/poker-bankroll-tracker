import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            BankrollView()
                .tabItem {
                    Image(systemName: "dollarsign.circle")
                    Text("Bankroll")
                }
                .tag(0)

            SessionsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Sessions")
                }
                .tag(1)

            HandReplayView()
                .tabItem {
                    Image(systemName: "suit.spade.fill")
                    Text("Hands")
                }
                .tag(2)
        }
        .tint(.black)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore())
}
