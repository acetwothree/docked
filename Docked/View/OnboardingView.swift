//
//  OnboardingView.swift
//  Docked
//
//  Three quick cards on first launch: what Docked is, how to turn on
//  Picture-in-Picture, and how to place the video.
//

import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.14, blue: 0.19), Color(red: 0.05, green: 0.05, blue: 0.07)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    card(emoji: "🧩", title: "Meet Docked") {
                        Text("Watch anything in a floating window while you doodle, take notes, or play. Docked reshapes itself around your video so nothing is ever hidden underneath it.")
                    }
                    .tag(0)

                    card(emoji: "📺", title: "Turn on Picture-in-Picture") {
                        VStack(alignment: .leading, spacing: 10) {
                            step("1", "iOS Settings ▸ General ▸ Picture in Picture → turn on “Start PiP Automatically”.")
                            step("2", "Play a video full-screen in YouTube, Netflix, Hulu, Safari…")
                            step("3", "Swipe up to the Home Screen — the video becomes a floating window.")
                        }
                    }
                    .tag(1)

                    card(emoji: "⧉", title: "Place it & go") {
                        Text("Tap **⧉** any time to pick where your video sits — four corners, or a big top / bottom slot. Then drag the floating window into the TV frame. That's it.")
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                controls
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("Skip", action: onDone)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Color.white.opacity(0.15))
                        .frame(width: i == page ? 18 : 7, height: 7)
                }
            }

            Spacer()

            Button(page == 2 ? "Get started" : "Next") {
                if page < 2 { withAnimation { page += 1 } } else { onDone() }
            }
            .fontWeight(.heavy)
            .padding(.vertical, 10).padding(.horizontal, 20)
            .background(Theme.accent, in: Capsule())
            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private func card<Content: View>(
        emoji: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            Text(emoji).font(.system(size: 54))
            Text(title).font(.system(size: 22, weight: .heavy))
            content()
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(n).fontWeight(.heavy).foregroundStyle(Theme.accent)
            Text(text)
        }
        .font(.system(size: 13))
        .multilineTextAlignment(.leading)
    }
}
