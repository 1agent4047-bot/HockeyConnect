import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 4)
    }
}

struct IceBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.98, blue: 1.0)
                .ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 0.66, green: 0.85, blue: 0.92).opacity(0.35), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
}

extension Color {
    static let iceBlue = Color(red: 0.20, green: 0.55, blue: 0.78)   // deeper for white-bg contrast
    static let navyDark = Color(red: 0.04, green: 0.09, blue: 0.16)  // text accent
}

struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

struct BackBar: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(Color.iceBlue)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
