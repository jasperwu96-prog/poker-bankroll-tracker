import Foundation
import SwiftUI

@MainActor
class DataStore: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var bankroll: Double = 0

    private let sessionsKey = "poker_sessions"
    private let bankrollKey = "poker_bankroll"

    init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded.sorted { $0.date > $1.date }
        }
        bankroll = UserDefaults.standard.double(forKey: bankrollKey)
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
        UserDefaults.standard.set(bankroll, forKey: bankrollKey)
    }

    // MARK: - Bankroll Operations

    func updateBankroll(_ amount: Double) {
        bankroll = amount
        save()
    }

    func addToBankroll(_ amount: Double) {
        bankroll += amount
        save()
    }

    // MARK: - Session Operations

    func addSession(_ session: Session) {
        sessions.insert(session, at: 0)
        bankroll += session.profit
        save()
    }

    func updateSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            let oldProfit = sessions[index].profit
            sessions[index] = session
            bankroll += (session.profit - oldProfit)
            sessions.sort { $0.date > $1.date }
            save()
        }
    }

    func deleteSession(_ session: Session) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            bankroll -= sessions[index].profit
            sessions.remove(at: index)
            save()
        }
    }

    func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            bankroll -= sessions[index].profit
        }
        sessions.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Hand Operations

    func addHand(_ hand: PokerHand, to sessionId: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].hands.append(hand)
            save()
        }
    }

    func updateHand(_ hand: PokerHand, in sessionId: UUID) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
           let handIndex = sessions[sessionIndex].hands.firstIndex(where: { $0.id == hand.id }) {
            sessions[sessionIndex].hands[handIndex] = hand
            save()
        }
    }

    func deleteHand(_ hand: PokerHand, from sessionId: UUID) {
        if let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
           let handIndex = sessions[sessionIndex].hands.firstIndex(where: { $0.id == hand.id }) {
            sessions[sessionIndex].hands.remove(at: handIndex)
            save()
        }
    }

    // MARK: - Stats

    var stats: BankrollStats {
        BankrollStats(sessions: sessions)
    }

    var allHands: [PokerHand] {
        sessions.flatMap { $0.hands }.sorted { $0.date > $1.date }
    }
}
