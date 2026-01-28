import SwiftUI

enum CardSize {
    case small
    case medium
    case large

    var width: CGFloat {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        }
    }

    var height: CGFloat {
        switch self {
        case .small: return 44
        case .medium: return 60
        case .large: return 76
        }
    }

    var rankFont: Font {
        switch self {
        case .small: return .system(size: 12, weight: .bold, design: .rounded)
        case .medium: return .system(size: 16, weight: .bold, design: .rounded)
        case .large: return .system(size: 20, weight: .bold, design: .rounded)
        }
    }

    var suitFont: Font {
        switch self {
        case .small: return .system(size: 10)
        case .medium: return .system(size: 14)
        case .large: return .system(size: 18)
        }
    }
}

struct CardView: View {
    let card: Card
    var size: CardSize = .medium

    var body: some View {
        VStack(spacing: 0) {
            Text(card.rank.display)
                .font(size.rankFont)
            Text(card.suit.symbol)
                .font(size.suitFont)
        }
        .foregroundColor(.black)
        .frame(width: size.width, height: size.height)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Card Back View

struct CardBackView: View {
    var size: CardSize = .medium

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [Color.black.opacity(0.8), Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size.width, height: size.height)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Animated Card View

struct AnimatedCardView: View {
    let card: Card?
    var size: CardSize = .medium
    @State private var isFlipped = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            if isFlipped, let card = card {
                CardView(card: card, size: size)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                CardBackView(size: size)
            }
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onAppear {
            if card != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        rotation = 180
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isFlipped = true
                    }
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        CardView(card: Card(rank: .ace, suit: .spades), size: .small)
        CardView(card: Card(rank: .king, suit: .hearts), size: .medium)
        CardView(card: Card(rank: .queen, suit: .diamonds), size: .large)
        CardBackView(size: .medium)
    }
    .padding()
}
