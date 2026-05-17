import SwiftUI

struct SplashView: View {
    @State private var scale = 0.8
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            IceBackground()
            VStack(spacing: 16) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Color.iceBlue)
                Text("HockeyConnect")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Phoenix")
                    .font(.title3)
                    .foregroundStyle(Color.iceBlue)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}
