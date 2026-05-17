import SwiftUI

struct PlayerTabView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        TabView {
            GamesFeedView()
                .tabItem {
                    Label("Games", systemImage: "sportscourt.fill")
                }

            AvailabilityView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            PlayerProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Color.iceBlue)
        .preferredColorScheme(.light)
    }
}
