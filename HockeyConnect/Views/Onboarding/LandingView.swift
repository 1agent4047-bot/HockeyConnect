import SwiftUI

struct LandingView: View {
    let onContinue: () -> Void

    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var titleOffset: CGFloat = 40
    @State private var titleOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var featuresOpacity: Double = 0
    @State private var ctaOpacity: Double = 0
    @State private var ctaOffset: CGFloat = 24
    @State private var puckSpin: Double = 0

    var body: some View {
        ZStack {
            IceBackground()

            // animated background streaks
            GeometryReader { geo in
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.iceBlue.opacity(0.06))
                            .frame(width: 240 + CGFloat(i) * 90)
                            .offset(
                                x: -geo.size.width * 0.3 + CGFloat(i) * 50,
                                y: -geo.size.height * 0.3 + CGFloat(i) * 70
                            )
                    }
                }
            }
            .blur(radius: 20)

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.iceBlue.opacity(0.12))
                        .frame(width: 180, height: 180)
                        .scaleEffect(logoScale * 1.05)

                    Image(systemName: "hockey.puck.fill")
                        .font(.system(size: 84, weight: .bold))
                        .foregroundStyle(Color.iceBlue)
                        .rotationEffect(.degrees(puckSpin))
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                }

                VStack(spacing: 10) {
                    Text("HockeyConnect")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.primary)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                    Text("Phoenix Hockey Network")
                        .font(.title3)
                        .foregroundStyle(Color.iceBlue)
                        .opacity(taglineOpacity)
                }

                VStack(spacing: 14) {
                    FeatureRow(icon: "figure.ice.hockey", text: "Find pickup games at your skill level")
                    FeatureRow(icon: "person.3.fill", text: "Fill open spots in your roster")
                    FeatureRow(icon: "bolt.fill", text: "Real-time matching, instant payment")
                }
                .padding(.horizontal, 32)
                .opacity(featuresOpacity)

                Spacer()
            }

            VStack {
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.iceBlue, Color(red: 0.13, green: 0.42, blue: 0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.iceBlue.opacity(0.35), radius: 12, x: 0, y: 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(ctaOpacity)
                .offset(y: ctaOffset)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false).delay(0.5)) {
                puckSpin = 360
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.5)) {
                titleOffset = 0
                titleOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.9)) {
                taglineOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.8).delay(1.3)) {
                featuresOpacity = 1
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(2.0)) {
                ctaOpacity = 1
                ctaOffset = 0
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.iceBlue)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
            Spacer()
        }
    }
}
