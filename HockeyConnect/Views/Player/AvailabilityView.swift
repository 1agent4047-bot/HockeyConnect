import SwiftUI

struct AvailabilityView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var slots: [AvailabilitySlot] = []
    @State private var isSaving = false
    @State private var saved = false

    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let timeBlocks = ["Morning\n6–12am", "Afternoon\n12–5pm", "Evening\n5–10pm"]
    private let blockHours: [(Int, Int)] = [(6, 12), (12, 17), (17, 22)]

    var body: some View {
        NavigationStack {
            ZStack {
                IceBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Tap your available windows")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)

                        GlassCard {
                            VStack(spacing: 0) {
                                // Header row
                                HStack(spacing: 0) {
                                    Text("").frame(width: 50)
                                    ForEach(days, id: \.self) { day in
                                        Text(day)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.bottom, 8)

                                Divider().overlay(Color.black.opacity(0.1))

                                ForEach(Array(timeBlocks.enumerated()), id: \.offset) { blockIdx, blockLabel in
                                    HStack(spacing: 0) {
                                        Text(blockLabel)
                                            .font(.system(size: 9))
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 50)
                                        ForEach(1...7, id: \.self) { day in
                                            let isOn = isActive(day: day, block: blockIdx)
                                            Button {
                                                toggle(day: day, block: blockIdx)
                                            } label: {
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(isOn ? Color.iceBlue.opacity(0.8) : Color.white.opacity(0.07))
                                                    .frame(height: 44)
                                                    .padding(3)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .stroke(isOn ? Color.iceBlue : .clear, lineWidth: 1.5)
                                                            .padding(3)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .padding(.horizontal, 16)

                        Button(action: save) {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else if saved {
                                    Label("Saved!", systemImage: "checkmark")
                                        .fontWeight(.semibold)
                                } else {
                                    Text("Save Schedule").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.iceBlue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("My Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            slots = authVM.playerProfile?.availability ?? []
        }
    }

    private func isActive(day: Int, block: Int) -> Bool {
        let (start, end) = blockHours[block]
        return slots.contains { $0.dayOfWeek == day && $0.startHour == start && $0.endHour == end }
    }

    private func toggle(day: Int, block: Int) {
        let (start, end) = blockHours[block]
        withAnimation(.spring(response: 0.25)) {
            if let idx = slots.firstIndex(where: { $0.dayOfWeek == day && $0.startHour == start && $0.endHour == end }) {
                slots.remove(at: idx)
            } else {
                slots.append(AvailabilitySlot(dayOfWeek: day, startHour: start, endHour: end))
            }
        }
    }

    private func save() {
        guard let uid = authVM.currentUser?.id else { return }
        isSaving = true
        Task {
            try? await FirestoreService.shared.updateAvailability(uid: uid, slots: slots)
            authVM.playerProfile?.availability = slots
            isSaving = false
            saved = true
            try? await Task.sleep(for: .seconds(2))
            saved = false
        }
    }
}
