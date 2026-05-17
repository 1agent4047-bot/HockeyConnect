import SwiftUI
import Firebase
import FirebaseMessaging
import GoogleSignIn

@main
struct HockeyConnectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authVM = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoading {
                SplashView()
            } else if authVM.currentUser == nil {
                OnboardingRootView()
            } else if authVM.currentUser?.type == .player {
                PlayerTabView()
            } else {
                GroupTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.currentUser?.id)
    }
}
