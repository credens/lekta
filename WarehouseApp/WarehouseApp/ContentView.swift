import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: MPAuthService
    @State private var splashActive = true
    @State private var splashOpacity: Double = 1
    @State private var splashScale: CGFloat = 1

    var body: some View {
        ZStack {
            if authService.isAuthenticated {
                HomeView()
            } else {
                MPConnectView()
            }

            if splashActive {
                LaunchScreen()
                    .opacity(splashOpacity)
                    .scaleEffect(splashScale)
                    .ignoresSafeArea()
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeIn(duration: 0.4)) {
                splashOpacity = 0
                splashScale = 1.08
            }
            try? await Task.sleep(for: .seconds(0.4))
            splashActive = false
        }
    }
}
