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
    @State private var pot: Double = 0
    @State private var currentBet: Double = 0
    @State private var actedThisRound: Set<Int> = []

    // UI State
    @State private var phase: RecordingPhase = .setup
    @State private var showingCardPicker = false
    @State private var cardPickerType: CardPickerType = .holeCards
    @State private var showingBetInput = false
    @State private var showingAllInInput = false
    @State private var betAmount = ""
    @State private var pendingAction: ActionType = .bet

    enum RecordingPhase {
        case setup
        case action
        case selectingFlop
        case selectingTurn
        case selectingRiver
        case result
    }

    enum CardPickerType {
        case holeCards, flop, turn, river
    }

    // Preflop order: UTG(3), UTG+1(4), MP(5), MP+1(6), HJ(7), CO(8), BTN(0), SB(1), BB(2)
    let preflopOrder = [3, 4, 5, 6, 7, 8, 0, 1, 2]
    // Postflop order: SB(1), BB(2), UTG(3), UTG+1(4), MP(5), MP+1(6), HJ(7), CO(8), BTN(0)
    let postflopOrder = [1, 2, 3, 4, 5, 6, 7, 8, 0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressBar

                ScrollView {
                    VStack(spacing: 16) {
                        switch phase {
                        case .setup:
                            setupPhase
                        case .action:
                            actionPhase
                        case .selectingFlop, .selectingTurn, .selectingRiver:
                            cardSelectionPhase
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
                CardPickerView(
                    selectedCards: cardPickerBinding,
                    maxCards: maxCardsForPicker,
                    excludedCards: excludedCardsForPicker
                )
            }
            .alert("Enter Amount", isPresented: $showingBetInput) {
                TextField("Amount", text: $betAmount)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { betAmount = "" }
                Button("Confirm") { confirmBetAction() }
            }
            .alert("All-In Amount", isPresented: $showingAllInInput) {
                TextField("Amount", text: $betAmount)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) { betAmount = "" }
                Button("Confirm") { confirmAllInAction() }
            }
            .onAppear { setupInitialState() }
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
        switch currentStreet {
        case .preflop: return 1
        case .flop: return 2
        case .turn: return 3
        case .river: return 4
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .setup: return "Setup Hand"
        case .action: return currentStreet.rawValue
        case .selectingFlop: return "Deal Flop"
        case .selectingTurn: return "Deal Turn"
        case .selectingRiver: return "Deal River"
        case .result: return "Result"
        }
    }

    // MARK: - Setup Phase

    private var setupPhase: some View {
        VStack(spacing: 24) {
            sessionPicker
            Divider()
            heroPositionSelector
            Divider()
            holeCardsSelector

            Spacer().frame(height: 20)

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

    // MARK: - Action Phase (Bird's Eye View)

    private var actionPhase: some View {
        VStack(spacing: 16) {
            // Street indicator
            streetIndicator

            // Poker Table with current player highlighted
            PokerTableView(
                players: players,
                communityCards: board,
                pot: pot,
                activePlayerIndex: getCurrentPlayerPositionId(),
                onPlayerTap: nil
            )
            .frame(height: 240)

            // Current player info and actions
            if let currentPlayer = getCurrentPlayer() {
                currentPlayerActionPanel(currentPlayer)
            } else {
                // All players have acted this round
                roundCompletePanel
            }

            Divider()

            // Action history for current street
            actionHistory
        }
    }

    private var streetIndicator: some View {
        HStack(spacing: 16) {
            ForEach(Street.allCases, id: \.self) { street in
                Text(street.rawValue)
                    .font(.caption)
                    .fontWeight(currentStreet == street ? .bold : .regular)
                    .foregroundColor(currentStreet == street ? .black : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(currentStreet == street ? Color.black.opacity(0.1) : Color.clear)
                    )
            }
        }
    }

    private func currentPlayerActionPanel(_ player: PlayerState) -> some View {
        VStack(spacing: 16) {
            // Player indicator
            HStack {
                Text(player.position.shortName)
                    .font(.title3)
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
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                }
            }

            // Action buttons - 2x2 grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    actionButton("Fold", style: .outline) {
                        recordAction(player: player, action: .fold, amount: nil)
                    }

                    if currentBet == 0 {
                        actionButton("Check", style: .filled) {
                            recordAction(player: player, action: .check, amount: nil)
                        }
                    } else {
                        actionButton("Call $\(Int(currentBet))", style: .filled) {
                            recordAction(player: player, action: .call, amount: currentBet)
                        }
                    }
                }

                HStack(spacing: 10) {
                    actionButton(currentBet == 0 ? "Bet" : "Raise", style: .outline) {
                        pendingAction = currentBet == 0 ? .bet : .raise
                        betAmount = ""
                        showingBetInput = true
                    }

                    actionButton("All-In", style: .outline) {
                        betAmount = ""
                        showingAllInInput = true
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.02)))
    }

    private var roundCompletePanel: some View {
        VStack(spacing: 16) {
            Text("Round Complete")
                .font(.headline)
                .foregroundColor(.black)

            Button {
                advanceToNextStreet()
            } label: {
                Text(nextStreetButtonTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
            }

            if !actions.filter({ $0.street == currentStreet }).isEmpty {
                Button {
                    undoLastAction()
                } label: {
                    HStack {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo Last Action")
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.02)))
    }

    private var nextStreetButtonTitle: String {
        switch currentStreet {
        case .preflop: return "Deal Flop"
        case .flop: return "Deal Turn"
        case .turn: return "Deal River"
        case .river: return "Finish Hand"
        }
    }

    enum ButtonStyle {
        case filled, outline
    }

    private func actionButton(_ title: String, style: ButtonStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(style == .filled ? Color.black : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black, lineWidth: 1.5)
                )
                .foregroundColor(style == .filled ? .white : .black)
        }
    }

    private var actionHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIONS THIS STREET")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                if !actions.filter({ $0.street == currentStreet }).isEmpty {
                    Button {
                        undoLastAction()
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

            let streetActions = actions.filter { $0.street == currentStreet }
            if streetActions.isEmpty {
                Text("No actions yet")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 4)
            } else {
                ForEach(streetActions) { action in
                    HStack(spacing: 8) {
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
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Card Selection Phase

    private var cardSelectionPhase: some View {
        VStack(spacing: 24) {
            Text(cardSelectionTitle)
                .font(.headline)

            // Current board
            HStack(spacing: 8) {
                ForEach(0..<expectedBoardCards, id: \.self) { index in
                    if index < board.count {
                        CardView(card: board[index], size: .large)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.black.opacity(0.3))
                            .frame(width: 56, height: 76)
                    }
                }
            }

            Button {
                showingCardPicker = true
            } label: {
                Text("Select Cards")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
            }

            if board.count == expectedBoardCards {
                Button {
                    continueAfterCardSelection()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 2)
                        )
                }
            }
        }
    }

    private var cardSelectionTitle: String {
        switch phase {
        case .selectingFlop: return "Select 3 Flop Cards"
        case .selectingTurn: return "Select Turn Card"
        case .selectingRiver: return "Select River Card"
        default: return ""
        }
    }

    private var expectedBoardCards: Int {
        switch phase {
        case .selectingFlop: return 3
        case .selectingTurn: return 4
        case .selectingRiver: return 5
        default: return board.count
        }
    }

    // MARK: - Result Phase

    private var resultPhase: some View {
        VStack(spacing: 24) {
            // Final board
            if !board.isEmpty {
                VStack(spacing: 8) {
                    Text("FINAL BOARD")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundColor(.gray)

                    HStack(spacing: 8) {
                        ForEach(board) { card in
                            CardView(card: card, size: .medium)
                        }
                    }
                }
            }

            // Final pot
            HStack {
                Text("FINAL POT")
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

                Text("Positive = win, Negative = loss")
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

    // MARK: - Card Picker Bindings

    private var cardPickerBinding: Binding<[Card]> {
        switch cardPickerType {
        case .holeCards:
            return $holeCards
        case .flop:
            return Binding(
                get: { Array(board.prefix(3)) },
                set: { board = $0 }
            )
        case .turn:
            return Binding(
                get: { board.count > 3 ? [board[3]] : [] },
                set: { if let card = $0.first {
                    if board.count == 3 { board.append(card) }
                    else if board.count > 3 { board[3] = card }
                }}
            )
        case .river:
            return Binding(
                get: { board.count > 4 ? [board[4]] : [] },
                set: { if let card = $0.first {
                    if board.count == 4 { board.append(card) }
                    else if board.count > 4 { board[4] = card }
                }}
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
        // Update hero
        for i in players.indices {
            players[i].isHero = players[i].position.id == heroPositionIndex
            if players[i].isHero {
                players[i].cards = holeCards
            }
        }

        // Initial blinds (assuming 1/2)
        pot = 3
        currentBet = 2
        actedThisRound = []
        phase = .action
    }

    private func getCurrentPlayerPositionId() -> Int? {
        findCurrentPlayer()?.position.id
    }

    private func getCurrentPlayer() -> PlayerState? {
        findCurrentPlayer()
    }

    // Non-mutating function to find current player
    private func findCurrentPlayer() -> PlayerState? {
        let order = currentStreet == .preflop ? preflopOrder : postflopOrder

        // Count active (non-folded) players
        let activePlayers = players.filter { !$0.isFolded }
        if activePlayers.count <= 1 {
            return nil // Hand is over, only one player left
        }

        // Find the first player in order who needs to act
        for i in 0..<order.count {
            let positionId = order[i]

            guard let player = players.first(where: { $0.position.id == positionId }) else {
                continue
            }

            // Skip folded players
            if player.isFolded {
                continue
            }

            // Check if player needs to act (hasn't acted this round)
            if !actedThisRound.contains(positionId) {
                return player
            }
        }

        return nil // Round is complete - all active players have acted
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

            if let amt = amount {
                pot += amt
                if action == .bet || action == .raise || action == .allIn {
                    currentBet = amt
                    // Reset acted set so other players can respond, but keep the raiser as acted
                    let raiserId = player.position.id
                    actedThisRound = [raiserId]
                } else {
                    actedThisRound.insert(player.position.id)
                }
            } else {
                // Fold or check
                actedThisRound.insert(player.position.id)
            }
        }
    }

    private func confirmBetAction() {
        guard let amount = Double(betAmount), let player = getCurrentPlayer() else { return }
        recordAction(player: player, action: pendingAction, amount: amount)
    }

    private func confirmAllInAction() {
        guard let amount = Double(betAmount), let player = getCurrentPlayer() else { return }
        recordAction(player: player, action: .allIn, amount: amount)
    }

    private func advanceToNextStreet() {
        switch currentStreet {
        case .preflop:
            phase = .selectingFlop
            cardPickerType = .flop
        case .flop:
            phase = .selectingTurn
            cardPickerType = .turn
        case .turn:
            phase = .selectingRiver
            cardPickerType = .river
        case .river:
            phase = .result
        }
    }

    private func continueAfterCardSelection() {
        // Reset for new street
        currentBet = 0
        actedThisRound = []

        // Clear last actions
        for i in players.indices {
            if !players[i].isFolded {
                players[i].lastAction = nil
            }
        }

        // Advance street
        switch phase {
        case .selectingFlop:
            currentStreet = .flop
        case .selectingTurn:
            currentStreet = .turn
        case .selectingRiver:
            currentStreet = .river
        default:
            break
        }

        phase = .action
    }

    private func undoLastAction() {
        guard let lastAction = actions.last, lastAction.street == currentStreet else { return }

        actions.removeLast()

        if let index = players.firstIndex(where: { $0.position.shortName == lastAction.position }) {
            players[index].isFolded = false
            players[index].lastAction = nil

            if let amount = lastAction.amount {
                pot -= amount
            }
        }

        // Rebuild actedThisRound from remaining actions
        rebuildActedThisRound()

        // Recalculate current bet
        let streetActions = actions.filter { $0.street == currentStreet }
        if let lastBet = streetActions.last(where: { $0.action == .bet || $0.action == .raise || $0.action == .allIn }) {
            currentBet = lastBet.amount ?? 0
        } else {
            currentBet = currentStreet == .preflop ? 2 : 0
        }
    }

    private func rebuildActedThisRound() {
        actedThisRound = []

        let streetActions = actions.filter { $0.street == currentStreet }

        // Find the last raise/bet action
        if let lastRaiseIndex = streetActions.lastIndex(where: { $0.action == .bet || $0.action == .raise || $0.action == .allIn }) {
            // Only count actions from the last raise onwards
            for i in lastRaiseIndex..<streetActions.count {
                let action = streetActions[i]
                if let player = players.first(where: { $0.position.shortName == action.position }) {
                    actedThisRound.insert(player.position.id)
                }
            }
        } else {
            // No raise, all actions count
            for action in streetActions {
                if let player = players.first(where: { $0.position.shortName == action.position }) {
                    actedThisRound.insert(player.position.id)
                }
            }
        }
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
