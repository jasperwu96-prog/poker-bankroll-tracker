import SwiftUI

struct AddHandView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    // Session & Basic Info
    @State private var selectedSession: Session?
    @State private var stakes = ""
    @State private var heroPositionIndex = 0
    @State private var holeCards: [Card] = []
    @State private var result = ""
    @State private var notes = ""

    // Game State
    @State private var currentStreet: Street = .preflop
    @State private var board: [Card] = []
    @State private var actions: [HandAction] = []
    @State private var players: [PlayerState] = []
    @State private var currentPlayerIndex = 0
    @State private var pot: Double = 0
    @State private var currentBet: Double = 0
    @State private var roundComplete = false

    // UI State
    @State private var phase: RecordingPhase = .setup
    @State private var showingCardPicker = false
    @State private var cardPickerType: CardPickerType = .holeCards

    enum RecordingPhase {
        case setup           // Select position and hole cards
        case preflop         // Record preflop action
        case flop            // Select flop cards then record action
        case turn            // Select turn card then record action
        case river           // Select river card then record action
        case result          // Enter result
    }

    enum CardPickerType {
        case holeCards, flop, turn, river
    }

    // Preflop order: UTG, UTG+1, MP, MP+1, HJ, CO, BTN, SB, BB
    let preflopOrder = [3, 4, 5, 6, 7, 8, 0, 1, 2] // Position IDs in action order
    // Postflop order: SB, BB, UTG, UTG+1, MP, MP+1, HJ, CO, BTN
    let postflopOrder = [1, 2, 3, 4, 5, 6, 7, 8, 0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .setup:
                            setupPhase
                        case .preflop, .flop, .turn, .river:
                            actionPhase
                        case .result:
                            resultPhase
                        }
                    }
                    .padding()
                }
            }
            .background(Color.white)
            .navigationTitle(phaseTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if phase == .result {
                        Button("Save") { saveHand() }
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showingCardPicker) {
                cardPickerSheet
            }
            .onAppear {
                setupInitialState()
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index <= phaseIndex ? Color.black : Color.black.opacity(0.1))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var phaseIndex: Int {
        switch phase {
        case .setup: return 0
        case .preflop: return 1
        case .flop: return 2
        case .turn: return 3
        case .river: return 4
        case .result: return 4
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .setup: return "Setup Hand"
        case .preflop: return "Preflop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .result: return "Result"
        }
    }

    // MARK: - Setup Phase

    private var setupPhase: some View {
        VStack(spacing: 24) {
            // Session picker
            sessionPicker

            Divider()

            // Hero position selector
            heroPositionSelector

            Divider()

            // Hole cards
            holeCardsSelector

            Spacer().frame(height: 20)

            // Start button
            Button {
                startRecording()
            } label: {
                Text("Start Recording")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(holeCards.count == 2 ? Color.black : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(holeCards.count != 2)
        }
    }

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                Menu {
                    ForEach(dataStore.sessions) { session in
                        Button {
                            selectedSession = session
                            stakes = session.stakes
                        } label: {
                            Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedSession?.date.formatted(date: .abbreviated, time: .omitted) ?? "Select")
                            .foregroundColor(.black)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.03)))
                }

                TextField("Stakes", text: $stakes)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.03)))
            }
        }
    }

    private var heroPositionSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR POSITION")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(PlayerPosition.allPositions) { position in
                    Button {
                        heroPositionIndex = position.id
                    } label: {
                        Text(position.shortName)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(heroPositionIndex == position.id ? Color.black : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .foregroundColor(heroPositionIndex == position.id ? .white : .black)
                    }
                }
            }
        }
    }

    private var holeCardsSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR CARDS")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    cardPickerType = .holeCards
                    showingCardPicker = true
                } label: {
                    Text(holeCards.isEmpty ? "Select" : "Change")
                        .font(.caption)
                        .foregroundColor(.black)
                }
            }

            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { index in
                    if index < holeCards.count {
                        CardView(card: holeCards[index], size: .large)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.gray.opacity(0.3))
                            .frame(width: 56, height: 76)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Action Phase

    private var actionPhase: some View {
        VStack(spacing: 20) {
            // Board cards display
            if currentStreet != .preflop {
                boardDisplay
            }

            // Pot display
            potDisplay

            // Current player and action buttons
            if let currentPlayer = getCurrentPlayer() {
                currentPlayerDisplay(currentPlayer)
            }

            Divider()

            // Action history
            actionHistory

            // Skip to next street / End hand buttons
            streetControls
        }
    }

    private var boardDisplay: some View {
        VStack(spacing: 8) {
            Text("BOARD")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    if index < board.count {
                        CardView(card: board[index], size: .medium)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.gray.opacity(0.3))
                            .frame(width: 44, height: 60)
                    }
                }
            }
        }
    }

    private var potDisplay: some View {
        HStack {
            Text("POT")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Spacer()

            Text("$\(Int(pot))")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.03)))
    }

    private func currentPlayerDisplay(_ player: PlayerState) -> some View {
        VStack(spacing: 16) {
            // Player info
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

                if player.isHero {
                    Text("(You)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                if currentBet > 0 {
                    Text("To call: $\(Int(currentBet))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            // Action buttons
            actionButtons(for: player)
        }
    }

    private func actionButtons(for player: PlayerState) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                // Fold
                actionButton(title: "Fold", color: .gray) {
                    recordAction(player: player, action: .fold, amount: nil)
                }

                // Check/Call
                if currentBet == 0 {
                    actionButton(title: "Check", color: .black) {
                        recordAction(player: player, action: .check, amount: nil)
                    }
                } else {
                    actionButton(title: "Call $\(Int(currentBet))", color: .black) {
                        recordAction(player: player, action: .call, amount: currentBet)
                    }
                }
            }

            HStack(spacing: 10) {
                // Bet/Raise
                actionButtonWithAmount(
                    title: currentBet == 0 ? "Bet" : "Raise",
                    player: player
                )

                // All-In
                actionButton(title: "All-In", color: .black) {
                    showAllInPrompt(player: player)
                }
            }
        }
    }

    private func actionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color == .black ? Color.black : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1.5)
                )
                .foregroundColor(color == .black ? .white : .black)
        }
    }

    @State private var betAmount = ""
    @State private var showingBetInput = false
    @State private var pendingBetPlayer: PlayerState?

    private func actionButtonWithAmount(title: String, player: PlayerState) -> some View {
        Button {
            pendingBetPlayer = player
            betAmount = ""
            showingBetInput = true
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1.5)
                )
                .foregroundColor(.black)
        }
        .alert("Enter Amount", isPresented: $showingBetInput) {
            TextField("Amount", text: $betAmount)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                if let amount = Double(betAmount), let player = pendingBetPlayer {
                    let actionType: ActionType = currentBet == 0 ? .bet : .raise
                    recordAction(player: player, action: actionType, amount: amount)
                }
            }
        }
    }

    @State private var showingAllInInput = false
    @State private var allInAmount = ""

    private func showAllInPrompt(player: PlayerState) {
        pendingBetPlayer = player
        allInAmount = ""
        showingAllInInput = true
    }

    private var actionHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIONS")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            if actions.isEmpty {
                Text("No actions yet")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                let streetActions = actions.filter { $0.street == currentStreet }
                ForEach(streetActions) { action in
                    HStack {
                        Text(action.position)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(action.isHero ? .white : .black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(action.isHero ? Color.black : Color.black.opacity(0.1))
                            )

                        Text(action.action.rawValue)
                            .font(.caption)

                        if let amount = action.amount, amount > 0 {
                            Text("$\(Int(amount))")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private var streetControls: some View {
        HStack(spacing: 12) {
            if !actions.filter({ $0.street == currentStreet }).isEmpty {
                Button {
                    undoLastAction()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                }
            }

            Spacer()

            Button {
                advanceToNextStreet()
            } label: {
                Text(nextStreetButtonTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .alert("All-In Amount", isPresented: $showingAllInInput) {
            TextField("Amount", text: $allInAmount)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                if let amount = Double(allInAmount), let player = pendingBetPlayer {
                    recordAction(player: player, action: .allIn, amount: amount)
                }
            }
        }
    }

    private var nextStreetButtonTitle: String {
        switch currentStreet {
        case .preflop: return "Deal Flop →"
        case .flop: return "Deal Turn →"
        case .turn: return "Deal River →"
        case .river: return "Finish Hand →"
        }
    }

    // MARK: - Result Phase

    private var resultPhase: some View {
        VStack(spacing: 24) {
            // Final board
            if !board.isEmpty {
                boardDisplay
            }

            // Final pot
            potDisplay

            Divider()

            // Result input
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR RESULT")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                HStack {
                    Text("$")
                        .font(.title2)
                        .foregroundColor(.gray)
                    TextField("+/- amount", text: $result)
                        .font(.title2)
                        .fontWeight(.bold)
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.03)))

                Text("Enter positive for win, negative for loss")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("NOTES")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                TextField("Add notes...", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.03)))
            }
        }
    }

    // MARK: - Card Picker Sheet

    private var cardPickerSheet: some View {
        CardPickerView(
            selectedCards: cardPickerBinding,
            maxCards: maxCardsForPicker,
            excludedCards: excludedCardsForPicker
        )
    }

    private var cardPickerBinding: Binding<[Card]> {
        switch cardPickerType {
        case .holeCards:
            return $holeCards
        case .flop:
            return Binding(
                get: { Array(board.prefix(3)) },
                set: { newCards in
                    board = newCards + Array(board.dropFirst(3))
                }
            )
        case .turn:
            return Binding(
                get: { board.count > 3 ? [board[3]] : [] },
                set: { newCards in
                    if let card = newCards.first {
                        if board.count == 3 {
                            board.append(card)
                        } else if board.count > 3 {
                            board[3] = card
                        }
                    }
                }
            )
        case .river:
            return Binding(
                get: { board.count > 4 ? [board[4]] : [] },
                set: { newCards in
                    if let card = newCards.first {
                        if board.count == 4 {
                            board.append(card)
                        } else if board.count > 4 {
                            board[4] = card
                        }
                    }
                }
            )
        }
    }

    private var maxCardsForPicker: Int {
        switch cardPickerType {
        case .holeCards: return 2
        case .flop: return 3
        case .turn, .river: return 1
        }
    }

    private var excludedCardsForPicker: [Card] {
        switch cardPickerType {
        case .holeCards: return board
        case .flop: return holeCards
        case .turn: return holeCards + Array(board.prefix(3))
        case .river: return holeCards + Array(board.prefix(4))
        }
    }

    // MARK: - Game Logic

    private func setupInitialState() {
        selectedSession = dataStore.sessions.first
        stakes = dataStore.sessions.first?.stakes ?? ""

        players = PlayerPosition.allPositions.map { position in
            PlayerState(position: position, isActive: true, isHero: position.id == heroPositionIndex)
        }
    }

    private func startRecording() {
        // Update hero position in players
        for i in players.indices {
            players[i].isHero = players[i].position.id == heroPositionIndex
            if players[i].isHero {
                players[i].cards = holeCards
            }
        }

        // Set initial blinds
        pot = 3 // Assuming 1/2 blinds, adjust as needed
        currentBet = 2 // Big blind

        // Start with UTG (first in preflop order)
        currentPlayerIndex = 0
        phase = .preflop
    }

    private func getCurrentPlayer() -> PlayerState? {
        let order = currentStreet == .preflop ? preflopOrder : postflopOrder
        var checkedCount = 0

        while checkedCount < order.count {
            let positionId = order[currentPlayerIndex % order.count]
            if let playerIndex = players.firstIndex(where: { $0.position.id == positionId }) {
                if players[playerIndex].isActive && !players[playerIndex].isFolded {
                    return players[playerIndex]
                }
            }
            currentPlayerIndex += 1
            checkedCount += 1
        }

        return nil
    }

    private func recordAction(player: PlayerState, action: ActionType, amount: Double?) {
        let handAction = HandAction(
            street: currentStreet,
            position: player.position.shortName,
            action: action,
            amount: amount,
            isHero: player.isHero
        )
        actions.append(handAction)

        // Update player state
        if let index = players.firstIndex(where: { $0.position.id == player.position.id }) {
            players[index].lastAction = action

            if action == .fold {
                players[index].isFolded = true
            }

            if let amount = amount {
                pot += amount
                if action == .bet || action == .raise || action == .allIn {
                    currentBet = amount
                }
            }
        }

        // Move to next player
        moveToNextPlayer()
    }

    private func moveToNextPlayer() {
        let order = currentStreet == .preflop ? preflopOrder : postflopOrder
        var attempts = 0

        repeat {
            currentPlayerIndex = (currentPlayerIndex + 1) % order.count
            attempts += 1

            let positionId = order[currentPlayerIndex]
            if let playerIndex = players.firstIndex(where: { $0.position.id == positionId }) {
                if players[playerIndex].isActive && !players[playerIndex].isFolded {
                    return
                }
            }
        } while attempts < order.count

        // All players have acted or folded
        roundComplete = true
    }

    private func advanceToNextStreet() {
        currentBet = 0
        currentPlayerIndex = 0
        roundComplete = false

        switch currentStreet {
        case .preflop:
            cardPickerType = .flop
            showingCardPicker = true
            currentStreet = .flop
        case .flop:
            cardPickerType = .turn
            showingCardPicker = true
            currentStreet = .turn
        case .turn:
            cardPickerType = .river
            showingCardPicker = true
            currentStreet = .river
        case .river:
            phase = .result
        }
    }

    private func undoLastAction() {
        guard let lastAction = actions.last, lastAction.street == currentStreet else { return }

        // Remove the action
        actions.removeLast()

        // Restore player state
        if let index = players.firstIndex(where: { $0.position.shortName == lastAction.position }) {
            players[index].isFolded = false
            players[index].lastAction = nil

            if let amount = lastAction.amount {
                pot -= amount
            }
        }

        // Go back to previous player
        let order = currentStreet == .preflop ? preflopOrder : postflopOrder
        currentPlayerIndex = (currentPlayerIndex - 1 + order.count) % order.count
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
            potSize: pot,
            result: Double(result) ?? 0,
            notes: notes
        )

        dataStore.addHand(hand, to: session.id)
        dismiss()
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
                // Selected cards header
                HStack(spacing: 8) {
                    ForEach(0..<maxCards, id: \.self) { index in
                        if index < selectedCards.count {
                            CardView(card: selectedCards[index], size: .medium)
                                .onTapGesture {
                                    selectedCards.remove(at: index)
                                }
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                                .foregroundColor(.gray.opacity(0.4))
                                .frame(width: 44, height: 60)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.03))

                // Card grid
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(Suit.allCases, id: \.self) { suit in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(suit.symbol)
                                    .font(.title2)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
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
                                                .frame(width: 40, height: 50)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(isSelected ? Color.black : Color.white)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isExcluded ? Color.gray.opacity(0.2) : Color.black.opacity(0.3), lineWidth: 1)
                                                )
                                                .foregroundColor(isSelected ? .white : (isExcluded ? .gray.opacity(0.3) : .black))
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
            .navigationTitle("Select Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(selectedCards.count == maxCards ? .black : .gray)
                    .disabled(selectedCards.count != maxCards)
                }
            }
        }
    }
}

#Preview {
    AddHandView()
        .environmentObject(DataStore())
}
