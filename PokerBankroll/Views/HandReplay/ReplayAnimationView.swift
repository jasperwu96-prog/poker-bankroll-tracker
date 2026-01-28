import SwiftUI

struct ReplayAnimationView: View {
    let hand: PokerHand
    @Environment(\.dismiss) var dismiss

    @State private var currentStep = 0
    @State private var isPlaying = false
    @State private var showHoleCards = false
    @State private var visibleBoardCards = 0
    @State private var currentActionIndex = 0
    @State private var pot: Double = 0

    private var totalSteps: Int {
        // Steps: Hole cards + Flop (if exists) + Turn (if exists) + River (if exists) + Actions
        var steps = 1 // Hole cards
        if hand.flop.count == 3 { steps += 1 }
        if hand.turn != nil { steps += 1 }
        if hand.river != nil { steps += 1 }
        steps += hand.actions.count
        return steps
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Spacer()

                // Table Area
                tableView

                Spacer()

                // Action Display
                actionDisplay

                // Controls
                controls
            }
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
            }

            Spacer()

            VStack(spacing: 2) {
                Text(hand.stakes)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(hand.heroPosition)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Text("Pot: $\(Int(pot))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.black)
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Table View

    private var tableView: some View {
        VStack(spacing: 32) {
            // Board Cards
            boardCardsView

            // Hole Cards
            holeCardsView
        }
        .padding()
    }

    private var boardCardsView: some View {
        VStack(spacing: 8) {
            Text("BOARD")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    if index < visibleBoardCards && index < hand.board.count {
                        CardView(card: hand.board[index], size: .large)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.gray.opacity(0.2))
                            .frame(width: 56, height: 76)
                    }
                }
            }
            .animation(.spring(response: 0.4), value: visibleBoardCards)
        }
    }

    private var holeCardsView: some View {
        VStack(spacing: 8) {
            Text("YOUR HAND")
                .font(.caption2)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    if showHoleCards && index < hand.holeCards.count {
                        CardView(card: hand.holeCards[index], size: .large)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        CardBackView(size: .large)
                    }
                }
            }
            .animation(.spring(response: 0.4), value: showHoleCards)
        }
    }

    // MARK: - Action Display

    private var actionDisplay: some View {
        VStack(spacing: 8) {
            if currentActionIndex > 0 && currentActionIndex <= hand.actions.count {
                let action = hand.actions[currentActionIndex - 1]

                HStack(spacing: 8) {
                    Text(action.position)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(action.isHero ? .black : .gray)

                    Text(action.action.rawValue.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)

                    if let amount = action.amount {
                        Text("$\(Int(amount))")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.05))
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Street Indicator
            Text(currentStreet.rawValue.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .tracking(2)
                .foregroundColor(.gray)
        }
        .frame(height: 80)
        .animation(.easeInOut(duration: 0.3), value: currentActionIndex)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 16) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.linear(duration: 0.2), value: progress)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)

            // Control Buttons
            HStack(spacing: 32) {
                Button {
                    reset()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }

                Button {
                    previousStep()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }

                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(Color.black))
                }

                Button {
                    nextStep()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }

                Button {
                    skipToEnd()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
        }
        .padding()
        .background(Color.white)
    }

    // MARK: - Computed Properties

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentStep) / CGFloat(totalSteps)
    }

    private var currentStreet: Street {
        // Determine current street based on visible board cards
        if visibleBoardCards == 0 {
            return .preflop
        } else if visibleBoardCards <= 3 {
            return .flop
        } else if visibleBoardCards == 4 {
            return .turn
        } else {
            return .river
        }
    }

    // MARK: - Actions

    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            autoPlay()
        }
    }

    private func autoPlay() {
        guard isPlaying && currentStep < totalSteps else {
            isPlaying = false
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if isPlaying {
                nextStep()
                autoPlay()
            }
        }
    }

    private func nextStep() {
        guard currentStep < totalSteps else { return }
        currentStep += 1
        updateState()
    }

    private func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
        updateStateReverse()
    }

    private func reset() {
        isPlaying = false
        currentStep = 0
        showHoleCards = false
        visibleBoardCards = 0
        currentActionIndex = 0
        pot = 0
    }

    private func skipToEnd() {
        isPlaying = false
        currentStep = totalSteps

        showHoleCards = true
        visibleBoardCards = hand.board.count
        currentActionIndex = hand.actions.count

        // Calculate final pot
        pot = hand.actions.compactMap { $0.amount }.reduce(0, +)
    }

    private func updateState() {
        // Step 1: Show hole cards
        if currentStep == 1 {
            withAnimation {
                showHoleCards = true
            }
            return
        }

        var stepCounter = 1

        // Flop
        if hand.flop.count == 3 {
            stepCounter += 1
            if currentStep == stepCounter {
                withAnimation {
                    visibleBoardCards = 3
                }
                return
            }
        }

        // Turn
        if hand.turn != nil {
            stepCounter += 1
            if currentStep == stepCounter {
                withAnimation {
                    visibleBoardCards = 4
                }
                return
            }
        }

        // River
        if hand.river != nil {
            stepCounter += 1
            if currentStep == stepCounter {
                withAnimation {
                    visibleBoardCards = 5
                }
                return
            }
        }

        // Actions
        let actionStep = currentStep - stepCounter
        if actionStep > 0 && actionStep <= hand.actions.count {
            withAnimation {
                currentActionIndex = actionStep
                if let amount = hand.actions[actionStep - 1].amount {
                    pot += amount
                }
            }
        }
    }

    private func updateStateReverse() {
        // Recalculate state based on current step
        showHoleCards = currentStep >= 1
        visibleBoardCards = 0
        currentActionIndex = 0
        pot = 0

        if currentStep <= 1 { return }

        var stepCounter = 1

        // Flop
        if hand.flop.count == 3 {
            stepCounter += 1
            if currentStep >= stepCounter {
                visibleBoardCards = 3
            }
        }

        // Turn
        if hand.turn != nil {
            stepCounter += 1
            if currentStep >= stepCounter {
                visibleBoardCards = 4
            }
        }

        // River
        if hand.river != nil {
            stepCounter += 1
            if currentStep >= stepCounter {
                visibleBoardCards = 5
            }
        }

        // Actions
        let actionStep = currentStep - stepCounter
        if actionStep > 0 {
            currentActionIndex = min(actionStep, hand.actions.count)
            for i in 0..<currentActionIndex {
                if let amount = hand.actions[i].amount {
                    pot += amount
                }
            }
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
            HandAction(street: .flop, position: "UTG", action: .bet, amount: 15),
            HandAction(street: .flop, position: "BTN", action: .raise, amount: 45, isHero: true),
            HandAction(street: .flop, position: "UTG", action: .call, amount: 30)
        ],
        potSize: 100,
        result: 50,
        notes: "Flopped the nuts"
    ))
}
