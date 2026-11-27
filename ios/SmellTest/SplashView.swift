import SwiftUI

/// Startup screen: the logo mark and the app name on navy, shown briefly at launch, then it
/// fades into the app. The system launch screen uses the same navy, so there's no white flash.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Brand.navy.ignoresSafeArea()
            VStack(spacing: 18) {
                WispMark(showsDots: true)
                    .frame(width: 120, height: 120)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.85)
                VStack(spacing: 6) {
                    Text("Smell Test")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("by Cognito Agora")
                        .font(.subheadline)
                        .foregroundStyle(Brand.mist)
                }
            }
            .opacity(appeared ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Smell Test by Cognito Agora")
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.5)) { appeared = true }
        }
    }
}

/// Shows the startup screen, then the app.
struct LaunchContainer<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            content
            if showsSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeInOut(duration: 0.4)) { showsSplash = false }
        }
    }
}
