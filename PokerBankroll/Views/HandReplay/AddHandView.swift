import SwiftUI

struct AddHandView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedSession: Session?
    @State private var stakes = ""
    @State private var heroPosition = "BTN"
    @State private var holeCards: [Card] = []
    @State private var board: [Card] = []
    @State private var potSize = ""
    @State private var result = ""
    @State private var notes = ""
    @State private var actions: [HandAction] = []

    @State private var showingCardPicker = false
    @State private var cardPickerTarget: CardPickerTarget = .holeCards
    @State private var showingActionSheet = false
    @State private var currentStreet: Street = .preflop

    enum CardPickerTarget {
        case holeCards, board
    }

    let positions = ["UTG", "UTG+1", "MP", "MP+1", "HJ", "CO", "BTN", "SB", "BB"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    sessionPicker
                    Divider()
                    positionAndStakes
                    Divider()
                    holeCardsSection
                    Divider()
                    boardSection
                    Divider()
                    actionsSection
                    Divider()
                    resultSection
                    Divider()
                    notesSection
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("New Hand")
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
            .sheet(isPresented: $showingActionSheet) {
                AddActionSheet(
                    actions: $actions,
                    currentStreet: $currentStreet
                )
            }
        }
    }

    // MARK: - Session Picker

    private var sessionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Menu {
                ForEach(dataStore.sessions) { session in
                    Button {
                        selectedSession = session
                        if stakes.isEmpty {
                            stakes = session.stakes
                        }
                    } label: {
                        Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) - \(session.stakes.isEmpty ? session.gameType.rawValue : session.stakes)")
                    }
                }
            } label: {
                HStack {
                    if let session = selectedSession {
                        Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) - \(session.stakes.isEmpty ? session.gameType.rawValue : session.stakes)")
                            .foregroundColor(.black)
                    } else {
                        Text("Select session")
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }
        }
        .onAppear {
            if selectedSession == nil {
                selectedSession = dataStore.sessions.first
                stakes = dataStore.sessions.first?.stakes ?? ""
            }
        }
    }

    // MARK: - Position & Stakes

    private var positionAndStakes: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("POSITION")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Menu {
                    ForEach(positions, id: \.self) { pos in
                        Button(pos) {
                            heroPosition = pos
                        }
                    }
                } label: {
                    HStack {
                        Text(heroPosition)
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.03))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("STAKES")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                TextField("1/2", text: $stakes)
                    .foregroundColor(.black)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.03))
                    )
            }
        }
    }

    // MARK: - Hole Cards Section

    private var holeCardsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOLE CARDS")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    if index < holeCards.count {
                        CardView(card: holeCards[index])
                    } else {
                        EmptyCardSlot()
                    }
                }

                Spacer()

                Button {
                    cardPickerTarget = .holeCards
                    showingCardPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
        }
    }

    // MARK: - Board Section

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BOARD")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    if index < board.count {
                        CardView(card: board[index])
                    } else {
                        EmptyCardSlot()
                    }
                }

                Spacer()

                Button {
                    cardPickerTarget = .board
                    showingCardPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIONS")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                Spacer()

                Button {
                    showingActionSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.black)
                }
            }

            if actions.isEmpty {
                Text("No actions recorded")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Street.allCases, id: \.self) { street in
                        let streetActions = actions.filter { $0.street == street }
                        if !streetActions.isEmpty {
                            Text(street.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray)
                                .padding(.top, 4)

                            ForEach(streetActions) { action in
                                actionRow(action)
                            }
                        }
                    }
                }
            }
        }
    }

    private func actionRow(_ action: HandAction) -> some View {
        HStack {
            Text(action.position)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(action.isHero ? .black : .gray)

            Text(action.action.rawValue)
                .font(.caption)
                .foregroundColor(.black)

            if let amount = action.amount {
                Text("$\(Int(amount))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                actions.removeAll { $0.id == action.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Result Section

    private var resultSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("POT SIZE")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                HStack {
                    Text("$")
                        .foregroundColor(.gray)
                    TextField("0", text: $potSize)
                        .keyboardType(.decimalPad)
                        .foregroundColor(.black)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.medium)
                    .tracking(1)
                    .foregroundColor(.gray)

                HStack {
                    Text("$")
                        .foregroundColor(.gray)
                    TextField("0", text: $result)
                        .keyboardType(.numbersAndPunctuation)
                        .foregroundColor(.black)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            TextEditor(text: $notes)
                .font(.body)
                .foregroundColor(.black)
                .frame(minHeight: 60)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Validation & Save

    private var isValid: Bool {
        selectedSession != nil && holeCards.count == 2
    }

    private func saveHand() {
        guard let session = selectedSession else { return }

        let hand = PokerHand(
            date: Date(),
            stakes: stakes,
            heroPosition: heroPosition,
            holeCards: holeCards,
            board: board,
            actions: actions,
            potSize: Double(potSize) ?? 0,
            result: Double(result) ?? 0,
            notes: notes
        )

        dataStore.addHand(hand, to: session.id)
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
            ScrollView {
                VStack(spacing: 16) {
                    // Selected Cards
                    HStack(spacing: 8) {
                        ForEach(selectedCards) { card in
                            CardView(card: card)
                                .onTapGesture {
                                    selectedCards.removeAll { $0.id == card.id }
                                }
                        }
                    }
                    .frame(height: 60)
                    .padding(.vertical)

                    // Card Grid
                    ForEach(Suit.allCases, id: \.self) { suit in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(suit.symbol)
                                .font(.headline)
                                .foregroundColor(.black)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
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
                                            .frame(width: 36, height: 44)
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

// MARK: - Add Action Sheet

struct AddActionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var actions: [HandAction]
    @Binding var currentStreet: Street

    @State private var position = "BTN"
    @State private var actionType: ActionType = .call
    @State private var amount = ""
    @State private var isHero = true

    let positions = ["UTG", "UTG+1", "MP", "MP+1", "HJ", "CO", "BTN", "SB", "BB"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Street Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("STREET")
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundColor(.gray)

                    HStack(spacing: 8) {
                        ForEach(Street.allCases, id: \.self) { street in
                            Button {
                                currentStreet = street
                            } label: {
                                Text(street.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(currentStreet == street ? Color.black : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .foregroundColor(currentStreet == street ? .white : .black)
                            }
                        }
                    }
                }

                // Position & Hero Toggle
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("POSITION")
                            .font(.caption)
                            .fontWeight(.medium)
                            .tracking(1)
                            .foregroundColor(.gray)

                        Menu {
                            ForEach(positions, id: \.self) { pos in
                                Button(pos) {
                                    position = pos
                                }
                            }
                        } label: {
                            HStack {
                                Text(position)
                                    .foregroundColor(.black)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black.opacity(0.03))
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("HERO")
                            .font(.caption)
                            .fontWeight(.medium)
                            .tracking(1)
                            .foregroundColor(.gray)

                        Toggle("", isOn: $isHero)
                            .labelsHidden()
                            .tint(.black)
                    }
                }

                // Action Type
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTION")
                        .font(.caption)
                        .fontWeight(.medium)
                        .tracking(1)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(ActionType.allCases, id: \.self) { action in
                            Button {
                                actionType = action
                            } label: {
                                Text(action.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(actionType == action ? Color.black : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .foregroundColor(actionType == action ? .white : .black)
                            }
                        }
                    }
                }

                // Amount
                if actionType != .fold && actionType != .check {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AMOUNT")
                            .font(.caption)
                            .fontWeight(.medium)
                            .tracking(1)
                            .foregroundColor(.gray)

                        HStack {
                            Text("$")
                                .foregroundColor(.gray)
                            TextField("0", text: $amount)
                                .keyboardType(.decimalPad)
                                .foregroundColor(.black)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.03))
                        )
                    }
                }

                Spacer()

                Button {
                    addAction()
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
            }
            .padding()
            .background(Color.white)
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addAction() {
        let action = HandAction(
            street: currentStreet,
            position: position,
            action: actionType,
            amount: Double(amount),
            isHero: isHero
        )
        actions.append(action)
        amount = ""
    }
}

#Preview {
    AddHandView()
        .environmentObject(DataStore())
}
