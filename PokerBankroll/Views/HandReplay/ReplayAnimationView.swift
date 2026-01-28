import SwiftUI

struct ReplayAnimationView: View {
    let hand: PokerHand
    @Environment(\.dismiss) var dismiss

    @State private var currentActionIndex = -1
    @State private var isPlaying = false
    @State private var players: [PlayerState] = []
    @State private var visibleBoardCards = 0
    @State private var pot: Double = 0
    @State private var currentStreet: Street = .preflop
    @State private var showHoleCards = false

    private var totalSteps: Int {
        // Steps: Show hole cards (1) + each action
        return 1 + hand.actions.count + boardRevealSteps
    }

    private var boardRevealSteps: Int {
        var steps = 0
        if hand.flop.count == 3 { steps += 1 }
        if hand.turn != nil { steps += 1 }
        if hand.river != nil { steps += 1 }
        return steps
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                // Poker Table
                tableArea
                    .frame(maxHeight: .infinity)

                // Current Action Display
                actionDisplay

                // Controls
                controls
            }
        }
        .onAppear {
            setupPlayers()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.black)
                    .padding(8)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(hand.stakes)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Hero: \(hand.heroPosition)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("POT")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Text("$\(Int(pot))")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    // MARK: - Table Area

    private var tableArea: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            let tableWidth = size * 0.9
            let tableHeight = size * 0.55

            ZStack {
                // Table
                tableShape(width: tableWidth, height: tableHeight)
                    .position(x: centerX, y: centerY)

                // Community Cards
                communityCardsView
                    .position(x: centerX, y: centerY - 15)

                // Pot Display
                if pot > 0 {
                    Text("$\(Int(pot))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.15), radius: 3)
                        )
                        .position(x: centerX, y: centerY + 40)
                }

                // Players around the table
                ForEach(players) { player in
                    let pos = playerPosition(
                        for: player.position,
                        centerX: centerX,
                        centerY: centerY,
                        radiusX: tableWidth / 2 + 40,
                        radiusY: tableHeight / 2 + 40
                    )

                    ReplayPlayerView(player: player, showCards: shouldShowCards(for: player))
                        .position(x: pos.x, y: pos.y)
                }
            }
        }
    }

    // MARK: - Table Shape

    private func tableShape(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Outer border
            Ellipse()
                .stroke(Color.black, lineWidth: 3)
                .frame(width: width, height: height)

            // Inner felt
            Ellipse()
                .fill(Color.black.opacity(0.03))
                .frame(width: width - 10, height: height - 10)

            // Inner border
            Ellipse()
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                .frame(width: width - 20, height: height - 20)
        }
    }

    // MARK: - Community Cards

    private var communityCardsView: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                if index < visibleBoardCards && index < hand.board.count {
                    CardView(card: hand.board[index], size: .small)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: 32, height: 44)
                }
            }
        }
        .animation(.spring(response: 0.4), value: visibleBoardCards)
    }

    // MARK: - Action Display

    private var actionDisplay: some View {
        VStack(spacing: 8) {
            // Street indicator
            HStack(spacing: 12) {
                ForEach(Street.allCases, id: \.self) { street in
                    Text(street.rawValue)
                        .font(.caption)
                        .fontWeight(currentStreet == street ? .bold : .regular)
                        .foregroundColor(currentStreet == street ? .black : .gray)
                }
            }

            // Current action
            if currentActionIndex >= 0 && currentActionIndex < hand.actions.count {
                let action = hand.actions[currentActionIndex]
                HStack(spacing: 8) {
                    Text(action.position)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(action.isHero ? .white : .black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(action.isHero ? Color.black : Color.black.opacity(0.1))
                        )

                    Text(action.action.rawValue.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)

                    if let amount = action.amount, amount > 0 {
                        Text("$\(Int(amount))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if currentActionIndex == -1 {
                Text("Press play to start")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .frame(height: 80)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.25), value: currentActionIndex)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Control buttons
            HStack(spacing: 28) {
                Button { reset() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { previousStep() } label: {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { togglePlay() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Color.black))
                }

                Button { nextStep() } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }

                Button { skipToEnd() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundColor(.black)
                }
            }

            // Result display
            if currentActionIndex >= hand.actions.count - 1 || !isPlaying && currentActionIndex == hand.actions.count - 1 {
                HStack {
                    Text("Result:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(formatResult(hand.result))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(hand.result >= 0 ? .black : .gray)
                }
            }
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Helper Methods

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        let currentStep = max(0, currentActionIndex + 1 + (showHoleCards ? 1 : 0))
        return CGFloat(currentStep) / CGFloat(totalSteps)
    }

    private func setupPlayers() {
        players = PlayerPosition.allPositions.map { position in
            var state = PlayerState(
                position: position,
                isActive: true,
                isHero: position.shortName == hand.heroPosition
            )
            if position.shortName == hand.heroPosition {
                state.cards = hand.holeCards
            }
            return state
        }
    }

    private func shouldShowCards(for player: PlayerState) -> Bool {
        return showHoleCards && player.isHero
    }

    private func playerPosition(
        for position: PlayerPosition,
        centerX: CGFloat,
        centerY: CGFloat,
        radiusX: CGFloat,
        radiusY: CGFloat
    ) -> CGPoint {
        let angle = position.angle * .pi / 180
        let x = centerX + radiusX * cos(angle)
        let y = centerY + radiusY * sin(angle)
        return CGPoint(x: x, y: y)
    }

    private func togglePlay() {
        isPlaying.toggle()
        if isPlaying {
            autoPlay()
        }
    }

    private func autoPlay() {
        guard isPlaying else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if isPlaying {
                if !nextStep() {
                    isPlaying = false
                } else {
                    autoPlay()
                }
            }
        }
    }

    @discardableResult
    private func nextStep() -> Bool {
        // First step: show hole cards
        if !showHoleCards {
            withAnimation {
                showHoleCards = true
            }
            return true
        }

        // Check for board reveals based on current action
        let nextActionIndex = currentActionIndex + 1
        if nextActionIndex < hand.actions.count {
            let nextAction = hand.actions[nextActionIndex]

            // Check if we need to reveal board cards before this action
            if nextAction.street == .flop && visibleBoardCards == 0 && hand.flop.count == 3 {
                withAnimation {
                    visibleBoardCards = 3
                    currentStreet = .flop
                }
                return true
            } else if nextAction.street == .turn && visibleBoardCards == 3 && hand.turn != nil {
                withAnimation {
                    visibleBoardCards = 4
                    currentStreet = .turn
                }
                return true
            } else if nextAction.street == .river && visibleBoardCards == 4 && hand.river != nil {
                withAnimation {
                    visibleBoardCards = 5
                    currentStreet = .river
                }
                return true
            }

            // Process the action
            currentActionIndex = nextActionIndex
            let action = hand.actions[currentActionIndex]

            withAnimation {
                currentStreet = action.street

                // Update player state
                if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                    players[index].lastAction = action.action
                    if action.action == .fold {
                        players[index].isFolded = true
                    }
                    if let amount = action.amount {
                        players[index].currentBet = amount
                        pot += amount
                    }
                }
            }
            return true
        }

        // Reveal remaining board cards if any
        if visibleBoardCards < hand.board.count {
            withAnimation {
                if visibleBoardCards == 0 && hand.flop.count == 3 {
                    visibleBoardCards = 3
                    currentStreet = .flop
                } else if visibleBoardCards == 3 && hand.turn != nil {
                    visibleBoardCards = 4
                    currentStreet = .turn
                } else if visibleBoardCards == 4 && hand.river != nil {
                    visibleBoardCards = 5
                    currentStreet = .river
                }
            }
            return true
        }

        return false
    }

    private func previousStep() {
        if currentActionIndex >= 0 {
            // Undo the current action
            let action = hand.actions[currentActionIndex]
            if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                players[index].lastAction = nil
                players[index].isFolded = false
                if let amount = action.amount {
                    pot -= amount
                }
                players[index].currentBet = 0
            }
            currentActionIndex -= 1

            // Update street
            if currentActionIndex >= 0 {
                currentStreet = hand.actions[currentActionIndex].street
            } else {
                currentStreet = .preflop
            }

            // Hide board if going back to preflop
            updateBoardVisibility()
        } else if showHoleCards {
            showHoleCards = false
        }
    }

    private func updateBoardVisibility() {
        if currentActionIndex < 0 {
            visibleBoardCards = 0
        } else {
            let street = hand.actions[currentActionIndex].street
            switch street {
            case .preflop:
                visibleBoardCards = 0
            case .flop:
                visibleBoardCards = 3
            case .turn:
                visibleBoardCards = 4
            case .river:
                visibleBoardCards = 5
            }
        }
    }

    private func reset() {
        isPlaying = false
        currentActionIndex = -1
        showHoleCards = false
        visibleBoardCards = 0
        pot = 0
        currentStreet = .preflop
        setupPlayers()
    }

    private func skipToEnd() {
        isPlaying = false
        showHoleCards = true
        visibleBoardCards = hand.board.count
        currentActionIndex = hand.actions.count - 1

        if let lastAction = hand.actions.last {
            currentStreet = lastAction.street
        }

        // Calculate final pot and update all player states
        pot = 0
        setupPlayers()
        for action in hand.actions {
            if let index = players.firstIndex(where: { $0.position.shortName == action.position }) {
                players[index].lastAction = action.action
                if action.action == .fold {
                    players[index].isFolded = true
                }
                if let amount = action.amount {
                    pot += amount
                }
            }
        }
    }

    private func formatResult(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }
}

// MARK: - Replay Player View

struct ReplayPlayerView: View {
    let player: PlayerState
    let showCards: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Cards
            if showCards && !player.cards.isEmpty {
                HStack(spacing: 2) {
                    ForEach(player.cards) { card in
                        MiniCardView(card: card)
                            .scaleEffect(0.85)
                    }
                }
            }

            // Player badge
            VStack(spacing: 2) {
                Text(player.position.shortName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(player.isHero ? .white : (player.isFolded ? .gray : .black))

                if let action = player.lastAction {
                    Text(action.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(player.isHero ? .white.opacity(0.8) : .gray)
                }

                if player.currentBet > 0 {
                    Text("$\(Int(player.currentBet))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(player.isHero ? .white : .black)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(player.isHero ? Color.black : (player.isFolded ? Color.gray.opacity(0.15) : Color.white))
                    .shadow(color: .black.opacity(0.1), radius: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(player.isHero ? Color.clear : Color.black.opacity(0.2), lineWidth: 1)
            )
            .opacity(player.isFolded ? 0.5 : 1)
        }
    }
}

#Preview {
    ReplayAnimationView(hand: PokerHand(
        stakes: "1/2 NL",
        heroPosition: "BTN",
        holeCards: [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)],
        board: [
            Card(rank: .queen, suit: .spades),
            Card(rank: .jack, suit: .hearts),
            Card(rank: .ten, suit: .diamonds),
            Card(rank: .two, suit: .clubs),
            Card(rank: .seven, suit: .hearts)
        ],
        actions: [
            HandAction(street: .preflop, position: "UTG", action: .raise, amount: 10),
            HandAction(street: .preflop, position: "BTN", action: .call, amount: 10, isHero: true),
            HandAction(street: .preflop, position: "BB", action: .fold),
            HandAction(street: .flop, position: "UTG", action: .bet, amount: 15),
            HandAction(street: .flop, position: "BTN", action: .raise, amount: 45, isHero: true),
            HandAction(street: .flop, position: "UTG", action: .call, amount: 30),
            HandAction(street: .turn, position: "UTG", action: .check),
            HandAction(street: .turn, position: "BTN", action: .bet, amount: 80, isHero: true),
            HandAction(street: .turn, position: "UTG", action: .fold)
        ],
        potSize: 190,
        result: 190,
        notes: "Flopped the nuts!"
    ))
}
