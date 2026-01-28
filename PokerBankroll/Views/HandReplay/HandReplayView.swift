import SwiftUI

struct HandReplayView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddHand = false
    @State private var selectedHand: PokerHand?

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.allHands.isEmpty {
                    emptyState
                } else {
                    handsList
                }
            }
            .background(Color.white)
            .navigationTitle("Hands")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddHand = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.black)
                    }
                    .disabled(dataStore.sessions.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddHand) {
                AddHandView()
            }
            .sheet(item: $selectedHand) { hand in
                HandDetailView(hand: hand)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "suit.spade.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.5))

            Text("No Hands")
                .font(.headline)
                .foregroundColor(.black)

            if dataStore.sessions.isEmpty {
                Text("Create a session first to log hands")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("Tap + to record your first hand")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hands List

    private var handsList: some View {
        List {
            ForEach(dataStore.allHands) { hand in
                HandRowView(hand: hand)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedHand = hand
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Hand Row

struct HandRowView: View {
    let hand: PokerHand

    var body: some View {
        HStack(spacing: 12) {
            // Hole Cards
            HStack(spacing: 4) {
                ForEach(hand.holeCards) { card in
                    MiniCardView(card: card)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(hand.heroPosition)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.1))
                        )

                    if !hand.stakes.isEmpty {
                        Text(hand.stakes)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Text(hand.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatResult(hand.result))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(hand.isWin ? .black : .gray)

                Text("Pot: \(formatAmount(hand.potSize))")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatResult(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Mini Card View

struct MiniCardView: View {
    let card: Card

    var body: some View {
        VStack(spacing: 0) {
            Text(card.rank.display)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(card.suit.symbol)
                .font(.system(size: 10))
        }
        .foregroundColor(.black)
        .frame(width: 28, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HandReplayView()
        .environmentObject(DataStore())
}
