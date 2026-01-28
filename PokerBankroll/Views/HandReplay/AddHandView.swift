import SwiftUI

struct AddHandView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedSession: Session?
    @State private var stakes = ""
    @State private var heroPositionIndex = 0
    @State private var holeCards: [Card] = []
    @State private var board: [Card] = []
    @State private var potSize = ""
    @State private var result = ""
    @State private var notes = ""
    @State private var actions: [HandAction] = []
    @State private var currentStreet: Street = .preflop
    @State private var players: [PlayerState] = []

    @State private var showingCardPicker = false
    @State private var cardPickerTarget: CardPickerTarget = .holeCards
    @State private var showingActionPicker = false
    @State private var selectedPlayerForAction: PlayerState?

    enum CardPickerTarget {
        case holeCards, board
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Session & Stakes
                    sessionSection

                    // Poker Table for position selection
                    tableSection

                    // Hero's Hole Cards
                    holeCardsSection

                    // Board Cards
                    boardSection

                    // Street Selector
                    streetSection

                    // Action Timeline
                    actionTimeline

                    // Result
                    resultSection

                    // Notes
                    notesSection
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("Record Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveHand()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                CardPickerView(
                    selectedCards: cardPickerTarget == .holeCards ? $holeCards : $board,
                    maxCards: cardPickerTarget == .holeCards ? 2 : 5,
                    excludedCards: cardPickerTarget == .holeCards ? board : holeCards
                )
            }
            .sheet(isPresented: $showingActionPicker) {
                if let player = selectedPlayerForAction {
                    QuickActionSheet(
                        player: player,
                        street: currentStreet,
                        onAction: { action in
                            actions.append(action)
                            updatePlayerState(for: action)
                        }
                    )
                }
            }
            .onAppear {
                setupPlayers()
                if selectedSession == nil {
                    selectedSession = dataStore.sessions.first
                    stakes = dataStore.sessions.first?.stakes ?? ""
                }
            }
        }
    }

    // MARK: - Session Section

    private var sessionSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SESSION")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Menu {
                    ForEach(dataStore.sessions) { session in
                        Button {
                            selectedSession = session
                            if stakes.isEmpty { stakes = session.stakes }
                        } label: {
                            Text("\(session.date.formatted(date: .abbreviated, time: .omitted))")
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSession?.date.formatted(date: .abbreviated, time: .omitted) ?? "Select")
                            .font(.subheadline)
                            .foregroundColor(.black)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.03))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("STAKES")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                TextField("1/2", text: $stakes)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.03))
                    )
            }
        }
    }

    // MARK: - Table Section

    private var tableSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TAP YOUR POSITION")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                if heroPositionIndex >= 0 {
                    Text("Hero: \(PlayerPosition.allPositions[heroPositionIndex].shortName)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }

            // Mini poker table for position selection
            PokerTableView(
                players: players,
                communityCards: board,
                pot: calculatePot(),
                activePlayerIndex: nil,
                onPlayerTap: { player in
                    if player.isHero {
                        // Tapping hero shows action picker
                        selectedPlayerForAction = player
                        showingActionPicker = true
                    } else if !player.isFolded {
                        // Tapping opponent - either set as hero or record action
                        if holeCards.isEmpty {
                            // Set as hero position
                            setHeroPosition(player.position)
                        } else {
                            // Record action for this player
                            selectedPlayerForAction = player
                            showingActionPicker = true
                        }
                    }
                }
            )
            .frame(height: 220)
        }
    }

    // MARK: - Hole Cards Section

    private var holeCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("HOLE CARDS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    cardPickerTarget = .holeCards
                    showingCardPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: holeCards.isEmpty ? "plus" : "pencil")
                        Text(holeCards.isEmpty ? "Add" : "Edit")
                    }
                    .font(.caption)
                    .foregroundColor(.black)
                }
            }

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    if index < holeCards.count {
                        CardView(card: holeCards[index], size: .medium)
                    } else {
                        EmptyCardSlot()
                    }
                }
                Spacer()
            }
        }
        .onChange(of: holeCards) { _, newCards in
            updateHeroCards(newCards)
        }
    }

    // MARK: - Board Section

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BOARD")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    cardPickerTarget = .board
                    showingCardPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: board.isEmpty ? "plus" : "pencil")
                        Text(board.isEmpty ? "Add" : "Edit")
                    }
                    .font(.caption)
                    .foregroundColor(.black)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    if index < board.count {
                        CardView(card: board[index], size: .small)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                            .foregroundColor(.gray.opacity(0.3))
                            .frame(width: 32, height: 44)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Street Section

    private var streetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT STREET")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Street.allCases, id: \.self) { street in
                        Button {
                            currentStreet = street
                        } label: {
                            Text(street.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(currentStreet == street ? Color.black : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black, lineWidth: 1)
                                )
                                .foregroundColor(currentStreet == street ? .white : .black)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Timeline

    private var actionTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIONS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                if !actions.isEmpty {
                    Button {
                        if let last = actions.last {
                            undoAction(last)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Undo")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                }
            }

            if actions.isEmpty {
                Text("Tap a player on the table to record actions")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Street.allCases, id: \.self) { street in
                        let streetActions = actions.filter { $0.street == street }
                        if !streetActions.isEmpty {
                            Text(street.rawValue)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                                .padding(.top, 6)

                            ForEach(streetActions) { action in
                                HStack(spacing: 6) {
                                    Text(action.position)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(action.isHero ? .white : .black)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(action.isHero ? Color.black : Color.black.opacity(0.1))
                                        )

                                    Text(action.action.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.black)

                                    if let amount = action.amount, amount > 0 {
                                        Text("$\(Int(amount))")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Button {
                                        undoAction(action)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Result Section

    private var resultSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FINAL POT")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                HStack(spacing: 4) {
                    Text("$")
                        .foregroundColor(.gray)
                    TextField("0", text: $potSize)
                        .keyboardType(.decimalPad)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR RESULT")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                HStack(spacing: 4) {
                    Text("$")
                        .foregroundColor(.gray)
                    TextField("+/-", text: $result)
                        .keyboardType(.numbersAndPunctuation)
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NOTES")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            TextField("Add notes...", text: $notes, axis: .vertical)
                .font(.subheadline)
                .lineLimit(3...6)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
        }
    }

    // MARK: - Helper Methods

    private func setupPlayers() {
        players = PlayerPosition.allPositions.map { position in
            PlayerState(position: position, isActive: true, isHero: position.id == heroPositionIndex)
        }
    }

    private func setHeroPosition(_ position: PlayerPosition) {
        heroPositionIndex = position.id
        for i in players.indices {
            players[i].isHero = players[i].position.id == position.id
        }
    }

    private func updateHeroCards(_ cards: [Card]) {
        if let index = players.firstIndex(where: { $0.isHero }) {
            players[index].cards = cards
        }
    }

    private func updatePlayerState(for action: HandAction) {
        if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
            players[index].lastAction = action.action
            if action.action == .fold {
                players[index].isFolded = true
            }
            if let amount = action.amount {
                players[index].currentBet = amount
            }
        }
    }

    private func undoAction(_ action: HandAction) {
        actions.removeAll { $0.id == action.id }
        // Reset player state if needed
        if action.action == .fold {
            if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                players[index].isFolded = false
            }
        }
    }

    private func calculatePot() -> Double {
        actions.compactMap { $0.amount }.reduce(0, +)
    }

    private var isValid: Bool {
        selectedSession != nil && holeCards.count == 2
    }

    private func saveHand() {
        guard let session = selectedSession else { return }

        let heroPosition = PlayerPosition.allPositions[heroPositionIndex].shortName
        let hand = PokerHand(
            date: Date(),
            stakes: stakes,
            heroPosition: heroPosition,
            holeCards: holeCards,
            board: board,
            actions: actions,
            potSize: Double(potSize) ?? calculatePot(),
            result: Double(result) ?? 0,
            notes: notes
        )

        dataStore.addHand(hand, to: session.id)
        dismiss()
    }
}

// MARK: - Quick Action Sheet

struct QuickActionSheet: View {
    let player: PlayerState
    let street: Street
    let onAction: (HandAction) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedAction: ActionType = .call
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Player Info
                HStack {
                    Text(player.position.shortName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(player.isHero ? .white : .black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(player.isHero ? Color.black : Color.black.opacity(0.1))
                        )

                    Spacer()

                    Text(street.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Action Buttons - 2x3 Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(ActionType.allCases, id: \.self) { action in
                        Button {
                            selectedAction = action
                            if action == .fold || action == .check {
                                submitAction()
                            }
                        } label: {
                            Text(action.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedAction == action ? Color.black : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.black, lineWidth: 1.5)
                                )
                                .foregroundColor(selectedAction == action ? .white : .black)
                        }
                    }
                }

                // Amount Input (for bet/raise/call/all-in)
                if selectedAction != .fold && selectedAction != .check {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .tracking(1)
                            .foregroundColor(.gray)

                        HStack {
                            Text("$")
                                .font(.title2)
                                .foregroundColor(.gray)
                            TextField("0", text: $amount)
                                .font(.title2)
                                .fontWeight(.bold)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.03))
                        )
                    }

                    Button {
                        submitAction()
                    } label: {
                        Text("Add Action")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .disabled(amount.isEmpty && selectedAction != .fold && selectedAction != .check)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Record Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submitAction() {
        let action = HandAction(
            street: street,
            position: player.position.shortName,
            action: selectedAction,
            amount: Double(amount),
            isHero: player.isHero
        )
        onAction(action)
        dismiss()
    }
}

// MARK: - Empty Card Slot

struct EmptyCardSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundColor(.gray.opacity(0.3))
            .frame(width: 44, height: 60)
    }
}

// MARK: - Card Picker View

struct CardPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCards: [Card]
    let maxCards: Int
    let excludedCards: [Card]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected Cards Display
                HStack(spacing: 8) {
                    ForEach(0..<maxCards, id: \.self) { index in
                        if index < selectedCards.count {
                            CardView(card: selectedCards[index], size: .medium)
                                .onTapGesture {
                                    selectedCards.remove(at: index)
                                }
                        } else {
                            EmptyCardSlot()
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.03))

                // Card Grid
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Suit.allCases, id: \.self) { suit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suit.symbol)
                                    .font(.title2)
                                    .foregroundColor(.black)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                                    ForEach(Rank.allCases, id: \.self) { rank in
                                        let card = Card(rank: rank, suit: suit)
                                        let isSelected = selectedCards.contains(card)
                                        let isExcluded = excludedCards.contains(card)

                                        Button {
                                            if isSelected {
                                                selectedCards.removeAll { $0.id == card.id }
                                            } else if selectedCards.count < maxCards && !isExcluded {
                                                selectedCards.append(card)
                                            }
                                        } label: {
                                            Text(rank.display)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .frame(width: 38, height: 48)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(isSelected ? Color.black : Color.white)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(
                                                            isExcluded ? Color.gray.opacity(0.2) : Color.black.opacity(0.3),
                                                            lineWidth: 1
                                                        )
                                                )
                                                .foregroundColor(
                                                    isSelected ? .white : (isExcluded ? .gray.opacity(0.3) : .black)
                                                )
                                        }
                                        .disabled(isExcluded)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color.white)
            .navigationTitle("Select Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                }
            }
        }
    }
}

#Preview {
    AddHandView()
        .environmentObject(DataStore())
}
