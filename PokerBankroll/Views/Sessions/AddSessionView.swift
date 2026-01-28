import SwiftUI

struct AddSessionView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss

    @State private var date = Date()
    @State private var gameType: GameType = .cashGame
    @State private var stakes = ""
    @State private var location = ""
    @State private var buyIn = ""
    @State private var cashOut = ""
    @State private var hours = ""
    @State private var minutes = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Date & Game Type
                    VStack(spacing: 16) {
                        dateField
                        gameTypePicker
                    }

                    Divider()

                    // Stakes & Location
                    VStack(spacing: 16) {
                        inputField(title: "Stakes", placeholder: "1/2 NL", text: $stakes)
                        inputField(title: "Location", placeholder: "Casino name", text: $location)
                    }

                    Divider()

                    // Financials
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            currencyField(title: "Buy-in", text: $buyIn)
                            currencyField(title: "Cash Out", text: $cashOut)
                        }

                        profitDisplay
                    }

                    Divider()

                    // Duration
                    durationFields

                    Divider()

                    // Notes
                    notesField
                }
                .padding()
            }
            .background(Color.white)
            .navigationTitle("New Session")
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
                        saveSession()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .disabled(!isValid)
                }
            }
        }
    }

    // MARK: - Date Field

    private var dateField: some View {
        HStack {
            Text("DATE")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Spacer()

            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .tint(.black)
        }
    }

    // MARK: - Game Type Picker

    private var gameTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GAME TYPE")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 8) {
                ForEach(GameType.allCases, id: \.self) { type in
                    Button {
                        gameType = type
                    } label: {
                        Text(type.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(gameType == type ? Color.black : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                            .foregroundColor(gameType == type ? .white : .black)
                    }
                }
            }
        }
    }

    // MARK: - Input Field

    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundColor(.black)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
        }
    }

    // MARK: - Currency Field

    private func currencyField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack {
                Text("$")
                    .foregroundColor(.gray)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .foregroundColor(.black)
            }
            .font(.body)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.03))
            )
        }
    }

    // MARK: - Profit Display

    private var profitDisplay: some View {
        HStack {
            Text("PROFIT/LOSS")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            Spacer()

            Text(formatProfit(profit))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(profit >= 0 ? .black : .gray)
        }
    }

    // MARK: - Duration Fields

    private var durationFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DURATION")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                HStack {
                    TextField("0", text: $hours)
                        .keyboardType(.numberPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                    Text("hours")
                        .foregroundColor(.gray)
                }
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )

                HStack {
                    TextField("0", text: $minutes)
                        .keyboardType(.numberPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                    Text("min")
                        .foregroundColor(.gray)
                }
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
            }
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.caption)
                .fontWeight(.medium)
                .tracking(1)
                .foregroundColor(.gray)

            TextEditor(text: $notes)
                .font(.body)
                .foregroundColor(.black)
                .frame(minHeight: 80)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.03))
                )
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Computed Properties

    private var profit: Double {
        let buy = Double(buyIn) ?? 0
        let cash = Double(cashOut) ?? 0
        return cash - buy
    }

    private var duration: TimeInterval {
        let h = Double(hours) ?? 0
        let m = Double(minutes) ?? 0
        return (h * 3600) + (m * 60)
    }

    private var isValid: Bool {
        !buyIn.isEmpty || !cashOut.isEmpty
    }

    // MARK: - Methods

    private func formatProfit(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "$0"
        return value >= 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private func saveSession() {
        let session = Session(
            date: date,
            gameType: gameType,
            stakes: stakes,
            location: location,
            buyIn: Double(buyIn) ?? 0,
            cashOut: Double(cashOut) ?? 0,
            duration: duration,
            notes: notes
        )
        dataStore.addSession(session)
        dismiss()
    }
}

#Preview {
    AddSessionView()
        .environmentObject(DataStore())
}
