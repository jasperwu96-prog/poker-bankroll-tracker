import SwiftUI

struct AddHandView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    // Session & Basic Info
    @State private var selectedSession: Session?
    @State private var selectedStakesIndex = 1 // Default to 1/3
    @State private var heroPositionIndex = 0
    @State private var holeCards: [Card] = []
    @State private var notes = ""

    // Stakes options
    let stakesOptions = ["1/2", "1/3", "2/5", "5/10", "10/20", "25/50"]

    // Game State
    @State private var currentStreet: Street = .preflop
    @State private var board: [Card] = []
    @State private var actions: [HandAction] = []
    @State private var players: [PlayerState] = []
    @State private var pot: Double = 0
    @State private var currentBet: Double = 0
    @State private var actedThisRound: Set<Int> = []
    @State private var playerContributions: [Int: Double] = [:] // Track each player's total contributions
    @State private var winnerPositionId: Int? = nil // Who won the hand
    @State private var opponentHands: [Int: [Card]] = [:] // Store opponent hole cards for showdown
    @State private var selectedOpponentId: Int? = nil // Currently selecting cards for this opponent
    @State private var muckedOpponents: Set<Int> = [] // Opponents who mucked their hands
    @State private var playerStacks: [Int: Double] = [:] // Position ID -> Stack size
    @State private var showingStackInput = false
    @State private var editingStackPositionId: Int? = nil
    @State private var stackInputAmount = ""

    // Computed blinds from stakes
    private var smallBlind: Double {
        let parts = stakesOptions[selectedStakesIndex].split(separator: "/")
        return Double(parts.first ?? "1") ?? 1
    }

    private var bigBlind: Double {
        let parts = stakesOptions[selectedStakesIndex].split(separator: "/")
        return Double(parts.last ?? "2") ?? 2
    }

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
        case holeCards, flop, turn, river, opponentCards
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
                            .foregroundColor(winnerPositionId != nil ? .black : .gray)
                            .disabled(winnerPositionId == nil)
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
            stakesSelector
            Divider()
            heroPositionSelector
            Divider()
            holeCardsSelector
            Divider()
            stackSizesSelector

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
        .alert("Enter Stack Size", isPresented: $showingStackInput) {
            TextField("Stack ($)", text: $stackInputAmount)
                .keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { stackInputAmount = "" }
            Button("Save") { saveStackSize() }
        } message: {
            if let posId = editingStackPositionId {
                Text("Stack for \(PlayerPosition.allPositions[posId].shortName)")
            }
        }
    }

    private var stackSizesSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STACK SIZES")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                Text("Tap position to edit")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Mini table view for stack entry
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(PlayerPosition.allPositions) { position in
                    let stack = playerStacks[position.id]
                    let isHero = position.id == heroPositionIndex

                    Button {
                        editingStackPositionId = position.id
                        stackInputAmount = stack != nil ? "\(Int(stack!))" : ""
                        showingStackInput = true
                    } label: {
                        VStack(spacing: 4) {
                            Text(position.shortName)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(isHero ? .white : .black)

                            if let stack = stack {
                                Text("$\(Int(stack))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(isHero ? .white.opacity(0.8) : .gray)
                            } else {
                                Text("--")
                                    .font(.caption2)
                                    .foregroundColor(isHero ? .white.opacity(0.5) : .gray.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isHero ? Color.black : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(stack != nil ? Color.black : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }

            Text("Optional: Enter stack sizes for more accurate tracking")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private func saveStackSize() {
        guard let posId = editingStackPositionId,
              let amount = Double(stackInputAmount), amount > 0 else {
            stackInputAmount = ""
            return
        }
        playerStacks[posId] = amount
        stackInputAmount = ""
    }

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Menu {
                ForEach(dataStore.sessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            } label: {
                HStack {
                    Text(selectedSession?.date.formatted(date: .abbreviated, time: .omitted) ?? "Select Session")
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.03)))
            }
        }
    }

    private var stakesSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STAKES")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<stakesOptions.count, id: \.self) { index in
                    Button {
                        selectedStakesIndex = index
                    } label: {
                        Text(stakesOptions[index])
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedStakesIndex == index ? Color.black : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .foregroundColor(selectedStakesIndex == index ? .white : .black)
                    }
                }
            }

            Text("SB: $\(Int(smallBlind)) / BB: $\(Int(bigBlind))")
                .font(.caption)
                .foregroundColor(.gray)
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
        let amountToCall = max(0, currentBet - player.currentBet)
        let canCheck = amountToCall == 0

        return VStack(spacing: 16) {
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

                if amountToCall > 0 {
                    Text("To call: $\(Int(amountToCall))")
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

                    if canCheck {
                        actionButton("Check", style: .filled) {
                            recordAction(player: player, action: .check, amount: nil)
                        }
                    } else {
                        actionButton("Call $\(Int(amountToCall))", style: .filled) {
                            recordAction(player: player, action: .call, amount: currentBet)
                        }
                    }
                }

                HStack(spacing: 10) {
                    actionButton(canCheck ? "Bet" : "Raise", style: .outline) {
                        pendingAction = canCheck ? .bet : .raise
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

            // Current board - tap cards to remove them
            HStack(spacing: 8) {
                ForEach(0..<expectedBoardCards, id: \.self) { index in
                    if index < board.count {
                        CardView(card: board[index], size: .large)
                            .onTapGesture {
                                // Remove this card and all cards after it
                                if phase == .selectingFlop {
                                    board = []
                                } else if phase == .selectingTurn && index >= 3 {
                                    board = Array(board.prefix(3))
                                } else if phase == .selectingRiver && index >= 4 {
                                    board = Array(board.prefix(4))
                                }
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.black.opacity(0.3))
                            .frame(width: 56, height: 76)
                    }
                }
            }

            // Show helpful text
            if board.count < expectedBoardCards {
                Text("Tap to select cards")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                Text("Tap a card to change selection")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Button {
                // Clear current selection for this street before opening picker
                prepareCardPicker()
                showingCardPicker = true
            } label: {
                Text(board.count >= expectedBoardCards ? "Change Cards" : "Select Cards")
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

    private func prepareCardPicker() {
        // Clear cards for current street to allow fresh selection
        switch phase {
        case .selectingFlop:
            board = []
            cardPickerType = .flop
        case .selectingTurn:
            board = Array(board.prefix(3)) // Keep only flop
            cardPickerType = .turn
        case .selectingRiver:
            board = Array(board.prefix(4)) // Keep flop and turn
            cardPickerType = .river
        default:
            break
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

    private var activePlayers: [PlayerState] {
        players.filter { !$0.isFolded }
    }

    private var isShowdown: Bool {
        activePlayers.count > 1
    }

    private var opponentsAtShowdown: [PlayerState] {
        activePlayers.filter { !$0.isHero }
    }

    private var allShowdownHandsEntered: Bool {
        guard isShowdown else { return true }
        return opponentsAtShowdown.allSatisfy { opponent in
            opponentHands[opponent.position.id]?.count == 2 || muckedOpponents.contains(opponent.position.id)
        }
    }

    private var heroContribution: Double {
        playerContributions[heroPositionIndex] ?? 0
    }

    private var calculatedResult: Double {
        guard let winnerId = winnerPositionId else { return 0 }
        if winnerId == heroPositionIndex {
            return pot - heroContribution
        } else {
            return -heroContribution
        }
    }

    private func checkAndEvaluateWinner() {
        if isShowdown && allShowdownHandsEntered {
            evaluateWinner()
        }
    }

    private func evaluateWinner() {
        guard isShowdown && allShowdownHandsEntered && board.count >= 3 else { return }

        var bestHand: EvaluatedHand?
        var bestPlayerId: Int?

        // Evaluate hero's hand
        let heroHand = HandEvaluator.evaluate(holeCards: holeCards, board: board)
        bestHand = heroHand
        bestPlayerId = heroPositionIndex

        // Evaluate opponent hands (skip mucked opponents - they automatically lose)
        for opponent in opponentsAtShowdown {
            // Skip mucked opponents
            if muckedOpponents.contains(opponent.position.id) {
                continue
            }

            if let oppCards = opponentHands[opponent.position.id], oppCards.count == 2 {
                let oppHand = HandEvaluator.evaluate(holeCards: oppCards, board: board)
                if bestHand == nil || oppHand > bestHand! {
                    bestHand = oppHand
                    bestPlayerId = opponent.position.id
                }
            }
        }

        winnerPositionId = bestPlayerId
    }

    private func getHandDescription(for playerId: Int) -> String? {
        guard board.count >= 3 else { return nil }

        let cards: [Card]
        if playerId == heroPositionIndex {
            cards = holeCards
        } else if let oppCards = opponentHands[playerId], oppCards.count == 2 {
            cards = oppCards
        } else {
            return nil
        }

        let evaluated = HandEvaluator.evaluate(holeCards: cards, board: board)
        return evaluated.ranking.displayName
    }

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

            // Showdown: Enter opponent hands
            if isShowdown {
                showdownHandEntry
            } else {
                // No showdown - manually select winner
                manualWinnerSelection
            }

            // Auto-calculated result
            if winnerPositionId != nil {
                resultDisplay
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

    private var showdownHandEntry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SHOWDOWN - ENTER HANDS")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            // Hero's hand (already known)
            HStack(spacing: 12) {
                Text("You (\(PlayerPosition.allPositions[heroPositionIndex].shortName))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 80, alignment: .leading)

                HStack(spacing: 4) {
                    ForEach(holeCards) { card in
                        CardView(card: card, size: .small)
                    }
                }

                Spacer()

                if let handDesc = getHandDescription(for: heroPositionIndex) {
                    Text(handDesc)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                if winnerPositionId == heroPositionIndex {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.black)
                        .font(.caption)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05)))

            // Opponent hands
            ForEach(opponentsAtShowdown) { opponent in
                let hasCards = opponentHands[opponent.position.id]?.count == 2
                let hasMucked = muckedOpponents.contains(opponent.position.id)

                HStack(spacing: 12) {
                    Text(opponent.position.shortName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 60, alignment: .leading)

                    if hasMucked {
                        Text("MUCKED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.gray))
                    } else if hasCards, let cards = opponentHands[opponent.position.id] {
                        HStack(spacing: 4) {
                            ForEach(cards) { card in
                                CardView(card: card, size: .small)
                            }
                        }
                    } else {
                        HStack(spacing: 4) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                                    .foregroundColor(.gray.opacity(0.4))
                                    .frame(width: 28, height: 38)
                            }
                        }
                    }

                    Spacer()

                    if hasMucked {
                        Button {
                            muckedOpponents.remove(opponent.position.id)
                            checkAndEvaluateWinner()
                        } label: {
                            Text("Undo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if hasCards {
                        if let handDesc = getHandDescription(for: opponent.position.id) {
                            Text(handDesc)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        if winnerPositionId == opponent.position.id {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.black)
                                .font(.caption)
                        }

                        Button {
                            selectedOpponentId = opponent.position.id
                            cardPickerType = .opponentCards
                            opponentHands[opponent.position.id] = []
                            showingCardPicker = true
                        } label: {
                            Text("Change")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Button {
                            muckedOpponents.insert(opponent.position.id)
                            checkAndEvaluateWinner()
                        } label: {
                            Text("Muck")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).stroke(Color.gray, lineWidth: 1))
                        }

                        Button {
                            selectedOpponentId = opponent.position.id
                            cardPickerType = .opponentCards
                            opponentHands[opponent.position.id] = []
                            showingCardPicker = true
                        } label: {
                            Text("Cards")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.03)))
            }

        }
    }

    private var manualWinnerSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHO WON?")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(activePlayers) { player in
                    Button {
                        winnerPositionId = player.position.id
                    } label: {
                        VStack(spacing: 4) {
                            Text(player.position.shortName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if player.isHero {
                                Text("(You)")
                                    .font(.caption2)
                                    .foregroundColor(winnerPositionId == player.position.id ? .white.opacity(0.7) : .gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(winnerPositionId == player.position.id ? Color.black : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 1)
                        )
                        .foregroundColor(winnerPositionId == player.position.id ? .white : .black)
                    }
                }
            }
        }
    }

    private var resultDisplay: some View {
        VStack(spacing: 8) {
            Text("YOUR RESULT")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack {
                Text(calculatedResult >= 0 ? "+$\(Int(calculatedResult))" : "-$\(Int(abs(calculatedResult)))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(calculatedResult >= 0 ? .black : .gray)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("You put in: $\(Int(heroContribution))")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if calculatedResult >= 0 {
                        Text("Won pot: $\(Int(pot))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(calculatedResult >= 0 ? Color.black.opacity(0.05) : Color.gray.opacity(0.1))
            )
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
        case .opponentCards:
            return Binding(
                get: { selectedOpponentId.flatMap { opponentHands[$0] } ?? [] },
                set: { cards in
                    if let oppId = selectedOpponentId {
                        opponentHands[oppId] = cards
                        // Auto-evaluate winner when opponent hand is complete
                        if cards.count == 2 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                checkAndEvaluateWinner()
                            }
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
        case .opponentCards: return 2
        }
    }

    private var excludedCardsForPicker: [Card] {
        switch cardPickerType {
        case .holeCards: return board
        case .flop: return holeCards
        case .turn: return holeCards + Array(board.prefix(3))
        case .river: return holeCards + Array(board.prefix(4))
        case .opponentCards:
            // Exclude hero's cards, board cards, and other opponents' cards
            var excluded = holeCards + board
            for (_, cards) in opponentHands {
                excluded += cards
            }
            // Remove current opponent's cards from excluded (allow reselection)
            if let currentOppId = selectedOpponentId, let currentCards = opponentHands[currentOppId] {
                excluded = excluded.filter { card in !currentCards.contains(card) }
            }
            return excluded
        }
    }

    // MARK: - Game Logic

    private func setupInitialState() {
        selectedSession = dataStore.sessions.first
        players = PlayerPosition.allPositions.map { position in
            PlayerState(position: position, isActive: true, isHero: position.id == heroPositionIndex)
        }
    }

    private func startRecording() {
        // Update hero and apply stack sizes
        for i in players.indices {
            players[i].isHero = players[i].position.id == heroPositionIndex
            if players[i].isHero {
                players[i].cards = holeCards
            }
            // Apply stack sizes
            if let stack = playerStacks[players[i].position.id] {
                players[i].stack = stack
            }
        }

        // Reset contributions tracking
        playerContributions = [:]

        // Auto-post blinds
        let sb = smallBlind
        let bb = bigBlind

        // SB posts small blind (position id 1)
        if let sbIndex = players.firstIndex(where: { $0.position.id == 1 }) {
            players[sbIndex].currentBet = sb
            players[sbIndex].lastAction = .bet
            playerContributions[1] = sb

            let sbAction = HandAction(
                street: .preflop,
                position: players[sbIndex].position.shortName,
                action: .bet,
                amount: sb,
                isHero: players[sbIndex].isHero
            )
            actions.append(sbAction)
        }

        // BB posts big blind (position id 2)
        if let bbIndex = players.firstIndex(where: { $0.position.id == 2 }) {
            players[bbIndex].currentBet = bb
            players[bbIndex].lastAction = .bet
            playerContributions[2] = bb

            let bbAction = HandAction(
                street: .preflop,
                position: players[bbIndex].position.shortName,
                action: .bet,
                amount: bb,
                isHero: players[bbIndex].isHero
            )
            actions.append(bbAction)
        }

        // Initial pot and bet to call
        pot = sb + bb
        currentBet = bb
        actedThisRound = [] // SB and BB have posted but still need to act preflop
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
        // Calculate the actual amount added to pot (for calls, it's the difference)
        var actualAmount = amount
        let playerId = player.position.id

        if action == .call, let amt = amount {
            // For a call, the amount added is the call amount minus what they've already put in this street
            let alreadyIn = players.first(where: { $0.position.id == playerId })?.currentBet ?? 0
            actualAmount = amt - alreadyIn
        }

        let handAction = HandAction(
            street: currentStreet,
            position: player.position.shortName,
            action: action,
            amount: amount, // Store the total bet/raise amount for display
            isHero: player.isHero
        )
        actions.append(handAction)

        // Update player state
        if let index = players.firstIndex(where: { $0.position.id == playerId }) {
            players[index].lastAction = action

            if action == .fold {
                players[index].isFolded = true
            }

            if let amt = actualAmount, amt > 0 {
                pot += amt
                playerContributions[playerId, default: 0] += amt

                if action == .bet || action == .raise || action == .allIn {
                    // For raise/bet, update current bet to the total amount
                    currentBet = amount ?? amt
                    players[index].currentBet = currentBet
                    // Reset acted set so other players can respond, but keep the raiser as acted
                    actedThisRound = [playerId]
                } else if action == .call {
                    // For call, player matches the current bet
                    players[index].currentBet = currentBet
                    actedThisRound.insert(playerId)
                } else {
                    actedThisRound.insert(playerId)
                }
            } else {
                // Fold or check
                actedThisRound.insert(playerId)
            }
        }
    }

    private func confirmBetAction() {
        guard let amount = Double(betAmount), amount > 0, let player = getCurrentPlayer() else { return }
        // For raise, the amount is the total bet TO (e.g., raise to 15 means total is 15)
        // Calculate how much is actually being added
        let playerCurrentBet = player.currentBet
        let additionalAmount = amount - playerCurrentBet

        if additionalAmount > 0 {
            recordAction(player: player, action: pendingAction, amount: amount)
        }
        betAmount = ""
    }

    private func confirmAllInAction() {
        guard let amount = Double(betAmount), amount > 0, let player = getCurrentPlayer() else { return }
        recordAction(player: player, action: .allIn, amount: amount)
        betAmount = ""
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

        // Clear last actions and reset current bets for new street
        for i in players.indices {
            if !players[i].isFolded {
                players[i].lastAction = nil
                players[i].currentBet = 0 // Reset street bet
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
        let winnerPosition = winnerPositionId != nil ? PlayerPosition.allPositions.first(where: { $0.id == winnerPositionId })?.shortName : nil

        // Convert position IDs to position names for stacks
        var stacksByPosition: [String: Double] = [:]
        for (posId, stack) in playerStacks {
            let posName = PlayerPosition.allPositions[posId].shortName
            stacksByPosition[posName] = stack
        }

        let hand = PokerHand(
            date: Date(),
            stakes: stakesOptions[selectedStakesIndex],
            heroPosition: heroPosition,
            holeCards: holeCards,
            board: board,
            actions: actions,
            potSize: pot,
            result: calculatedResult,
            notes: notes,
            winner: winnerPosition,
            playerStacks: stacksByPosition.isEmpty ? nil : stacksByPosition
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

    private func suitColor(for suit: Suit) -> Color {
        switch suit.colorName {
        case "red": return .red
        case "blue": return .blue
        case "green": return Color(red: 0.0, green: 0.6, blue: 0.2)
        default: return .black
        }
    }

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
                                    .foregroundColor(suitColor(for: suit))

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
                                                        .fill(isSelected ? suitColor(for: suit) : Color.white)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(isExcluded ? Color.gray.opacity(0.2) : suitColor(for: suit).opacity(0.5), lineWidth: 1)
                                                )
                                                .foregroundColor(isSelected ? .white : (isExcluded ? .gray.opacity(0.3) : suitColor(for: suit)))
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
