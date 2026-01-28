import SwiftUI

struct HandDetailView: View {
    let hand: PokerHand
    @Environment(\.dismiss) var dismiss
    @State private var showingReplay = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with Result
                    headerSection

                    Divider()

                    // Hole Cards
                    holeCardsSection

                    if !hand.board.isEmpty {
                        Divider()
                        boardSection
                    }

                    if !hand.actions.isEmpty {
                        Divider()
                        actionsSection
                    }

                    if !hand.notes.isEmpty {
                        Divider()
                        notesSection
                    }

                    // Replay Button
                    if !hand.actions.isEmpty {
                        replayButton
                    }
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("Hand Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
            .fullScreenCover(isPresented: $showingReplay) {
                ReplayAnimationView(hand: hand)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hand.heroPosition)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black)
                        )
                        .foregroundColor(.white)

                    Text(hand.stakes)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatResult(hand.result))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(hand.isWin ? .black : .gray)

                    Text("Pot: \(formatAmount(hand.potSize))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            Text(hand.date.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Hole Cards Section

    private var holeCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOLE CARDS")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                ForEach(hand.holeCards) { card in
                    CardView(card: card, size: .large)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Board Section

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BOARD")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            VStack(spacing: 8) {
                // Flop
                if hand.flop.count == 3 {
                    HStack(spacing: 8) {
                        Text("Flop")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .leading)

                        ForEach(hand.flop) { card in
                            CardView(card: card)
                        }
                    }
                }

                // Turn
                if let turn = hand.turn {
                    HStack(spacing: 8) {
                        Text("Turn")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .leading)

                        CardView(card: turn)
                    }
                }

                // River
                if let river = hand.river {
                    HStack(spacing: 8) {
                        Text("River")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .frame(width: 40, alignment: .leading)

                        CardView(card: river)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACTION")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Street.allCases, id: \.self) { street in
                    let streetActions = hand.actions.filter { $0.street == street }
                    if !streetActions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(street.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.black)

                            ForEach(streetActions) { action in
                                HStack(spacing: 8) {
                                    Text(action.position)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(action.isHero ? .black : .gray)
                                        .frame(width: 50, alignment: .leading)

                                    Text(action.action.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.black)

                                    if let amount = action.amount {
                                        Text("$\(Int(amount))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Text(hand.notes)
                .font(.body)
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Replay Button

    private var replayButton: some View {
        Button {
            showingReplay = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Replay Hand")
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .cornerRadius(12)
        }
        .padding(.top)
    }

    // MARK: - Helpers

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

#Preview {
    HandDetailView(hand: PokerHand(
        stakes: "1/2 NL",
        heroPosition: "BTN",
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)],
        board: [Card(rank: .queen, suit: .spades), Card(rank: .jack, suit: .hearts), Card(rank: .ten, suit: .diamonds)],
        actions: [
            HandAction(street: .preflop, position: "UTG", action: .raise, amount: 10),
            HandAction(street: .preflop, position: "BTN", action: .call, amount: 10, isHero: true)
        ],
        potSize: 100,
        result: 50,
        notes: "Good spot to 3-bet"
    ))
}
