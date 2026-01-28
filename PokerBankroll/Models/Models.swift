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
}

struct Card: Codable, Identifiable, Equatable, Hashable {
    let rank: Rank
    let suit: Suit

    var id: String { "\(rank.rawValue)\(suit.rawValue)" }
    var display: String { "\(rank.display)\(suit.symbol)" }
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
