import Foundation

// MARK: - Card Models

enum Suit: String, Codable, CaseIterable {
    case spades = "s"
    case hearts = "h"
    case diamonds = "d"
    case clubs = "c"

    var symbol: String {
        switch self {
        case .spades: return "♠"
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }

    var colorName: String {
        switch self {
        case .spades: return "black"
        case .hearts: return "red"
        case .diamonds: return "blue"
        case .clubs: return "green"
        }
    }
}

enum Rank: String, Codable, CaseIterable {
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "T"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    case ace = "A"

    var display: String {
        switch self {
        case .ten: return "10"
        default: return rawValue
        }
    }

    var value: Int {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
}

struct Card: Codable, Identifiable, Equatable, Hashable {
    let rank: Rank
    let suit: Suit

    var id: String { "\(rank.rawValue)\(suit.rawValue)" }
    var display: String { "\(rank.display)\(suit.symbol)" }
}

// MARK: - Hand Evaluation

enum HandRanking: Int, Comparable {
    case highCard = 1
    case onePair = 2
    case twoPair = 3
    case threeOfAKind = 4
    case straight = 5
    case flush = 6
    case fullHouse = 7
    case fourOfAKind = 8
    case straightFlush = 9
    case royalFlush = 10

    static func < (lhs: HandRanking, rhs: HandRanking) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .highCard: return "High Card"
        case .onePair: return "One Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush: return "Royal Flush"
        }
    }
}

struct EvaluatedHand: Comparable {
    let ranking: HandRanking
    let kickers: [Int] // For tiebreaking (sorted high to low)

    static func < (lhs: EvaluatedHand, rhs: EvaluatedHand) -> Bool {
        if lhs.ranking != rhs.ranking {
            return lhs.ranking < rhs.ranking
        }
        // Compare kickers
        for (l, r) in zip(lhs.kickers, rhs.kickers) {
            if l != r {
                return l < r
            }
        }
        return false
    }
}

struct HandEvaluator {
    // Evaluate the best 5-card hand from hole cards + board
    static func evaluate(holeCards: [Card], board: [Card]) -> EvaluatedHand {
        let allCards = holeCards + board
        guard allCards.count >= 5 else {
            return EvaluatedHand(ranking: .highCard, kickers: allCards.map { $0.rank.value }.sorted(by: >))
        }

        // Generate all 5-card combinations
        var bestHand: EvaluatedHand?
        let combinations = allCards.combinations(of: 5)

        for combo in combinations {
            let evaluated = evaluateFiveCards(combo)
            if bestHand == nil || evaluated > bestHand! {
                bestHand = evaluated
            }
        }

        return bestHand ?? EvaluatedHand(ranking: .highCard, kickers: [])
    }

    private static func evaluateFiveCards(_ cards: [Card]) -> EvaluatedHand {
        let sortedCards = cards.sorted { $0.rank.value > $1.rank.value }
        let values = sortedCards.map { $0.rank.value }
        let suits = sortedCards.map { $0.suit }

        let isFlush = Set(suits).count == 1
        let isStraight = checkStraight(values)
        let isWheelStraight = values == [14, 5, 4, 3, 2] // A-2-3-4-5

        // Count ranks
        var rankCounts: [Int: Int] = [:]
        for value in values {
            rankCounts[value, default: 0] += 1
        }
        let counts = rankCounts.values.sorted(by: >)

        // Determine hand ranking
        if isFlush && isStraight {
            if values == [14, 13, 12, 11, 10] {
                return EvaluatedHand(ranking: .royalFlush, kickers: values)
            }
            return EvaluatedHand(ranking: .straightFlush, kickers: isWheelStraight ? [5, 4, 3, 2, 1] : values)
        }

        if counts == [4, 1] {
            let quadValue = rankCounts.first { $0.value == 4 }!.key
            let kicker = rankCounts.first { $0.value == 1 }!.key
            return EvaluatedHand(ranking: .fourOfAKind, kickers: [quadValue, kicker])
        }

        if counts == [3, 2] {
            let tripValue = rankCounts.first { $0.value == 3 }!.key
            let pairValue = rankCounts.first { $0.value == 2 }!.key
            return EvaluatedHand(ranking: .fullHouse, kickers: [tripValue, pairValue])
        }

        if isFlush {
            return EvaluatedHand(ranking: .flush, kickers: values)
        }

        if isStraight || isWheelStraight {
            return EvaluatedHand(ranking: .straight, kickers: isWheelStraight ? [5, 4, 3, 2, 1] : values)
        }

        if counts == [3, 1, 1] {
            let tripValue = rankCounts.first { $0.value == 3 }!.key
            let kickers = rankCounts.filter { $0.value == 1 }.map { $0.key }.sorted(by: >)
            return EvaluatedHand(ranking: .threeOfAKind, kickers: [tripValue] + kickers)
        }

        if counts == [2, 2, 1] {
            let pairs = rankCounts.filter { $0.value == 2 }.map { $0.key }.sorted(by: >)
            let kicker = rankCounts.first { $0.value == 1 }!.key
            return EvaluatedHand(ranking: .twoPair, kickers: pairs + [kicker])
        }

        if counts == [2, 1, 1, 1] {
            let pairValue = rankCounts.first { $0.value == 2 }!.key
            let kickers = rankCounts.filter { $0.value == 1 }.map { $0.key }.sorted(by: >)
            return EvaluatedHand(ranking: .onePair, kickers: [pairValue] + kickers)
        }

        return EvaluatedHand(ranking: .highCard, kickers: values)
    }

    private static func checkStraight(_ values: [Int]) -> Bool {
        let sorted = values.sorted(by: >)
        for i in 0..<sorted.count - 1 {
            if sorted[i] - sorted[i + 1] != 1 {
                return false
            }
        }
        return true
    }
}

// MARK: - Array Combinations Extension

extension Array {
    func combinations(of count: Int) -> [[Element]] {
        guard count > 0, count <= self.count else { return [] }
        if count == self.count { return [self] }
        if count == 1 { return self.map { [$0] } }

        var result: [[Element]] = []
        for (index, element) in self.enumerated() {
            let rest = Array(self[(index + 1)...])
            let subCombinations = rest.combinations(of: count - 1)
            for var combo in subCombinations {
                combo.insert(element, at: 0)
                result.append(combo)
            }
        }
        return result
    }
}

// MARK: - Hand Action Models

enum Street: String, Codable, CaseIterable {
    case preflop = "Preflop"
    case flop = "Flop"
    case turn = "Turn"
    case river = "River"
}

enum ActionType: String, Codable, CaseIterable {
    case fold = "Fold"
    case check = "Check"
    case call = "Call"
    case bet = "Bet"
    case raise = "Raise"
    case allIn = "All-In"
}

struct HandAction: Codable, Identifiable {
    let id: UUID
    let street: Street
    let position: String
    let action: ActionType
    let amount: Double?
    let isHero: Bool

    init(street: Street, position: String, action: ActionType, amount: Double? = nil, isHero: Bool = false) {
        self.id = UUID()
        self.street = street
        self.position = position
        self.action = action
        self.amount = amount
        self.isHero = isHero
    }
}

// MARK: - Hand Model

struct PokerHand: Codable, Identifiable {
    let id: UUID
    var date: Date
    var stakes: String
    var heroPosition: String
    var holeCards: [Card]
    var board: [Card]
    var actions: [HandAction]
    var potSize: Double
    var result: Double
    var notes: String
    var winner: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        stakes: String = "",
        heroPosition: String = "",
        holeCards: [Card] = [],
        board: [Card] = [],
        actions: [HandAction] = [],
        potSize: Double = 0,
        result: Double = 0,
        notes: String = "",
        winner: String? = nil
    ) {
        self.id = id
        self.date = date
        self.stakes = stakes
        self.heroPosition = heroPosition
        self.holeCards = holeCards
        self.board = board
        self.actions = actions
        self.potSize = potSize
        self.result = result
        self.notes = notes
        self.winner = winner
    }

    var flop: [Card] {
        Array(board.prefix(3))
    }

    var turn: Card? {
        board.count > 3 ? board[3] : nil
    }

    var river: Card? {
        board.count > 4 ? board[4] : nil
    }

    var isWin: Bool {
        result > 0
    }
}

// MARK: - Session Model

enum GameType: String, Codable, CaseIterable {
    case cashGame = "Cash Game"
    case tournament = "Tournament"
    case sitAndGo = "Sit & Go"
}

struct Session: Codable, Identifiable {
    let id: UUID
    var date: Date
    var gameType: GameType
    var stakes: String
    var location: String
    var buyIn: Double
    var cashOut: Double
    var duration: TimeInterval
    var notes: String
    var hands: [PokerHand]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        gameType: GameType = .cashGame,
        stakes: String = "",
        location: String = "",
        buyIn: Double = 0,
        cashOut: Double = 0,
        duration: TimeInterval = 0,
        notes: String = "",
        hands: [PokerHand] = []
    ) {
        self.id = id
        self.date = date
        self.gameType = gameType
        self.stakes = stakes
        self.location = location
        self.buyIn = buyIn
        self.cashOut = cashOut
        self.duration = duration
        self.notes = notes
        self.hands = hands
    }

    var profit: Double {
        cashOut - buyIn
    }

    var hourlyRate: Double {
        guard duration > 0 else { return 0 }
        return profit / (duration / 3600)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Bankroll Stats

struct BankrollStats {
    let totalProfit: Double
    let totalSessions: Int
    let winRate: Double
    let avgSessionProfit: Double
    let avgHourlyRate: Double
    let biggestWin: Double
    let biggestLoss: Double
    let currentStreak: Int

    init(sessions: [Session]) {
        self.totalSessions = sessions.count
        self.totalProfit = sessions.reduce(0) { $0 + $1.profit }

        let winningSessions = sessions.filter { $0.profit > 0 }.count
        self.winRate = sessions.isEmpty ? 0 : Double(winningSessions) / Double(sessions.count) * 100

        self.avgSessionProfit = sessions.isEmpty ? 0 : totalProfit / Double(sessions.count)

        let totalHours = sessions.reduce(0) { $0 + $1.duration } / 3600
        self.avgHourlyRate = totalHours > 0 ? totalProfit / totalHours : 0

        self.biggestWin = sessions.map { $0.profit }.max() ?? 0
        self.biggestLoss = sessions.map { $0.profit }.min() ?? 0

        var streak = 0
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            if session.profit > 0 {
                streak += 1
            } else if session.profit < 0 {
                streak -= 1
            }
            if streak == 0 { break }
        }
        self.currentStreak = streak
    }
}
