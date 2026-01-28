import SwiftUI

// MARK: - Player Position

struct PlayerPosition: Identifiable {
    let id: Int
    let name: String
    let shortName: String
    let angle: Double // Angle around the table

    // 9 positions evenly distributed (40 degrees apart)
    // BTN at bottom (270°), going clockwise
    static let allPositions: [PlayerPosition] = [
        PlayerPosition(id: 0, name: "Dealer", shortName: "BTN", angle: 270),
        PlayerPosition(id: 1, name: "Small Blind", shortName: "SB", angle: 310),
        PlayerPosition(id: 2, name: "Big Blind", shortName: "BB", angle: 350),
        PlayerPosition(id: 3, name: "Under the Gun", shortName: "UTG", angle: 30),
        PlayerPosition(id: 4, name: "UTG+1", shortName: "UTG+1", angle: 70),
        PlayerPosition(id: 5, name: "Middle Position", shortName: "MP", angle: 110),
        PlayerPosition(id: 6, name: "MP+1", shortName: "MP+1", angle: 150),
        PlayerPosition(id: 7, name: "Hijack", shortName: "HJ", angle: 190),
        PlayerPosition(id: 8, name: "Cutoff", shortName: "CO", angle: 230),
    ]
}

// MARK: - Player State

struct PlayerState: Identifiable {
    let id: Int
    var position: PlayerPosition
    var isActive: Bool
    var isHero: Bool
    var isFolded: Bool
    var cards: [Card]
    var currentBet: Double
    var lastAction: ActionType?
    var stack: Double

    init(position: PlayerPosition, isActive: Bool = true, isHero: Bool = false) {
        self.id = position.id
        self.position = position
        self.isActive = isActive
        self.isHero = isHero
        self.isFolded = false
        self.cards = []
        self.currentBet = 0
        self.lastAction = nil
        self.stack = 0
    }
}

// MARK: - Poker Table View

struct PokerTableView: View {
    let players: [PlayerState]
    let communityCards: [Card]
    let pot: Double
    let activePlayerIndex: Int?
    let onPlayerTap: ((PlayerState) -> Void)?

    init(
        players: [PlayerState],
        communityCards: [Card] = [],
        pot: Double = 0,
        activePlayerIndex: Int? = nil,
        onPlayerTap: ((PlayerState) -> Void)? = nil
    ) {
        self.players = players
        self.communityCards = communityCards
        self.pot = pot
        self.activePlayerIndex = activePlayerIndex
        self.onPlayerTap = onPlayerTap
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let centerX = width / 2
            let centerY = height / 2
            // Make table smaller to leave room for player labels
            let tableWidth = width * 0.65
            let tableHeight = height * 0.45

            ZStack {
                // Table
                tableShape(width: tableWidth, height: tableHeight)
                    .position(x: centerX, y: centerY)

                // Community Cards
                communityCardsView
                    .position(x: centerX, y: centerY - 10)

                // Pot
                if pot > 0 {
                    potView
                        .position(x: centerX, y: centerY + 30)
                }

                // Players - position with padding from edges
                ForEach(players) { player in
                    let pos = playerPosition(
                        for: player.position,
                        centerX: centerX,
                        centerY: centerY,
                        radiusX: tableWidth / 2 + 45,
                        radiusY: tableHeight / 2 + 50
                    )

                    // Clamp positions to stay within bounds
                    let clampedX = max(40, min(width - 40, pos.x))
                    let clampedY = max(35, min(height - 35, pos.y))

                    PlayerSeatView(
                        player: player,
                        isActive: activePlayerIndex == player.id,
                        onTap: { onPlayerTap?(player) }
                    )
                    .position(x: clampedX, y: clampedY)
                }
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
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
                .frame(width: width - 8, height: height - 8)

            // Inner border
            Ellipse()
                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                .frame(width: width - 16, height: height - 16)
        }
    }

    // MARK: - Community Cards

    private var communityCardsView: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                if index < communityCards.count {
                    CardView(card: communityCards[index], size: .small)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [2]))
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: 28, height: 38)
                }
            }
        }
    }

    // MARK: - Pot View

    private var potView: some View {
        Text("$\(Int(pot))")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.1), radius: 2)
            )
    }

    // MARK: - Position Calculator

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
}

// MARK: - Player Seat View

struct PlayerSeatView: View {
    let player: PlayerState
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Cards (if visible)
                if !player.cards.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(player.cards) { card in
                            MiniCardView(card: card)
                                .scaleEffect(0.8)
                        }
                    }
                }

                // Player info
                VStack(spacing: 2) {
                    Text(player.position.shortName)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(player.isHero ? .white : (player.isFolded ? .gray : .black))

                    // Stack size
                    if player.stack > 0 {
                        Text("$\(Int(player.stack))")
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundColor(player.isHero ? .white.opacity(0.7) : .gray)
                    }

                    if let action = player.lastAction {
                        Text(action.rawValue)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(player.isHero ? .white.opacity(0.8) : .gray)
                    }

                    if player.currentBet > 0 {
                        Text("Bet $\(Int(player.currentBet))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(player.isHero ? .white : .black)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(player.isHero ? Color.black : (player.isFolded ? Color.gray.opacity(0.1) : Color.white))
                        .shadow(color: isActive ? Color.black.opacity(0.3) : Color.black.opacity(0.1), radius: isActive ? 4 : 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isActive ? Color.black : Color.black.opacity(0.2), lineWidth: isActive ? 2 : 1)
                )
                .opacity(player.isActive ? 1 : 0.4)
            }
        }
        .buttonStyle(.plain)
        .disabled(!player.isActive || player.isFolded)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PokerTableView(
            players: PlayerPosition.allPositions.enumerated().map { index, position in
                var state = PlayerState(position: position, isActive: true, isHero: position.shortName == "BTN")
                if position.shortName == "BTN" {
                    state.cards = [Card(rank: .ace, suit: .spades), Card(rank: .king, suit: .spades)]
                }
                if position.shortName == "UTG" {
                    state.lastAction = .raise
                    state.currentBet = 15
                }
                return state
            },
            communityCards: [
                Card(rank: .queen, suit: .hearts),
                Card(rank: .jack, suit: .diamonds),
                Card(rank: .ten, suit: .clubs)
            ],
            pot: 50,
            activePlayerIndex: 3
        )
        .frame(height: 300)
        .padding()
    }
}
