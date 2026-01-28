import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddSession = false

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.sessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
            .background(Color.white)
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSession = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                AddSessionView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Sessions")
                .font(.headline)
                .foregroundColor(.black)

            Text("Tap + to log your first session")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        List {
            ForEach(groupedSessions.keys.sorted().reversed(), id: \.self) { month in
                Section {
                    ForEach(groupedSessions[month] ?? []) { session in
                        SessionRowView(session: session)
                    }
                    .onDelete { offsets in
                        deleteSession(in: month, at: offsets)
                    }
                } header: {
                    Text(month)
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundColor(.gray)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Grouped Sessions

    private var groupedSessions: [String: [Session]] {
        Dictionary(grouping: dataStore.sessions) { session in
            session.date.formatted(.dateTime.month(.wide).year())
        }
    }

    private func deleteSession(in month: String, at offsets: IndexSet) {
        guard let sessions = groupedSessions[month] else { return }
        for index in offsets {
            dataStore.deleteSession(sessions[index])
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(session.stakes.isEmpty ? session.gameType.rawValue : session.stakes)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    if !session.location.isEmpty {
                        Text("•")
                            .foregroundColor(.gray)
                        Text(session.location)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                HStack(spacing: 8) {
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    Text("•")
                    Text(session.durationFormatted)
                }
                .font(.caption)
                .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatProfit(session.profit))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(session.profit >= 0 ? .black : .gray)

                if session.hands.count > 0 {
                    Text("\(session.hands.count) hands")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatProfit(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
}

#Preview {
    SessionsView()
        .environmentObject(DataStore())
}
