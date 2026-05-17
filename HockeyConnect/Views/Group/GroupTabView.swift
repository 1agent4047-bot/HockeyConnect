import SwiftUI

struct GroupTabView: View {
    var body: some View {
        TabView {
            GroupDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            GroupProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Color.iceBlue)
        .preferredColorScheme(.light)
    }
}
