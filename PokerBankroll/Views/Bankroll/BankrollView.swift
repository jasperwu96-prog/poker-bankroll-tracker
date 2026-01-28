import SwiftUI

struct BankrollView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddFunds = false
    @State private var fundAmount = ""
    @State private var isWithdraw = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main Bankroll Display
                    bankrollCard

                    // Quick Stats
                    statsGrid

                    // Recent Activity
                    recentActivity
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("Bankroll")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Funds") {
                            isWithdraw = false
                            showingAddFunds = true
                        }
                        Button("Withdraw") {
                            isWithdraw = true
                            showingAddFunds = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showingAddFunds) {
                addFundsSheet
            }
        }
    }

    // MARK: - Bankroll Card

    private var bankrollCard: some View {
        VStack(spacing: 8) {
            Text("TOTAL BANKROLL")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(2)
                .foregroundColor(.gray)

            Text(formatCurrency(dataStore.bankroll))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.black)

            HStack(spacing: 4) {
                Image(systemName: dataStore.stats.totalProfit >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(formatCurrency(dataStore.stats.totalProfit))
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(dataStore.stats.totalProfit >= 0 ? .black : .gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black, lineWidth: 2)
        )
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            statCard(title: "Win Rate", value: String(format: "%.0f%%", dataStore.stats.winRate))
            statCard(title: "Sessions", value: "\(dataStore.stats.totalSessions)")
            statCard(title: "Avg Profit", value: formatCurrency(dataStore.stats.avgSessionProfit))
            statCard(title: "Hourly", value: formatCurrency(dataStore.stats.avgHourlyRate))
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.03))
        )
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT SESSIONS")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(2)
                .foregroundColor(.gray)

            if dataStore.sessions.isEmpty {
                Text("No sessions yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(dataStore.sessions.prefix(5)) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: Session) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.stakes.isEmpty ? session.gameType.rawValue : session.stakes)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(formatCurrency(session.profit, showSign: true))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(session.profit >= 0 ? .black : .gray)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Add Funds Sheet

    private var addFundsSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(isWithdraw ? "WITHDRAW" : "ADD FUNDS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(2)
                    .foregroundColor(.gray)

                TextField("Amount", text: $fundAmount)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)

                Spacer()

                Button {
                    if let amount = Double(fundAmount) {
                        dataStore.addToBankroll(isWithdraw ? -amount : amount)
                        showingAddFunds = false
                        fundAmount = ""
                    }
                } label: {
                    Text(isWithdraw ? "Withdraw" : "Add")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .disabled(Double(fundAmount) == nil)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingAddFunds = false
                        fundAmount = ""
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double, showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"

        if showSign && value != 0 {
            return value > 0 ? "+\(formatted)" : "-\(formatted)"
        }
        return value < 0 ? "-\(formatted)" : formatted
    }
}

#Preview {
    BankrollView()
        .environmentObject(DataStore())
}
