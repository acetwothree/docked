//
//  OnboardingView.swift
//  Docked
//
//  A floating card shown over the (dimmed) app on first launch: what Docked
//  is, how to turn on Picture-in-Picture, how to place the video, and a note
//  that the app is free. Presented as an in-app overlay, not its own screen.
//

import SwiftUI

struct OnboardingView: View {
    var topClearance: CGFloat = 0
    var onDone: () -> Void

    @State private var page = 0
    private let pageCount = 5

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)

            cardShell
                .frame(maxWidth: 360)
                .padding(.horizontal, 22)
                .padding(.top, topClearance + 14)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private var cardShell: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
                page4.tag(3)
                page5.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 296)

            controls
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.hairline)
        )
        .shadow(color: .black.opacity(0.5), radius: 28, y: 12)
    }

    // MARK: pages

    private var page1: some View {
        card(emoji: "🧩", title: "Meet Docked") {
            Text("Watch anything in a floating window while you doodle, take notes, or play. Docked reshapes itself around your video so nothing is hidden underneath it.")
        }
    }

    private var page2: some View {
        card(emoji: "📺", title: "Turn on Picture-in-Picture") {
            VStack(alignment: .leading, spacing: 9) {
                step("1", "In **Settings ▸ General ▸ Picture in Picture**, turn on **Start PiP Automatically**.")
                step("2", "Play a video full-screen in YouTube, Netflix, Safari…")
                step("3", "Swipe up to the Home Screen — the video becomes a floating window.")

                Button { PiPSettings.open() } label: {
                    Label("Open General settings", systemImage: "arrow.up.forward.app.fill")
                        .font(.system(size: 12.5, weight: .heavy))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)
            }
        }
    }

    private var page3: some View {
        card(emoji: "📺", title: "Place it & go") {
            Text("Drag the floating video window up into the TV screen at the top. Everything you do lives in the space below it, clear of your thumbs. That's it.")
        }
    }

    private var page4: some View {
        card(emoji: "🔊", title: "Make it fit your video") {
            Text("Videos come in different shapes. **Press and drag anywhere along the bottom bar of the TV** — the wood strip, the speaker grille, around the knobs — up or down to stretch the screen until the border hugs your video. The little ↕ by the bottom-left corner is the reminder.")
        }
    }

    private var page5: some View {
        card(emoji: "✨", title: "Free, no ads") {
            Text("Docked is free with no ads or tracking. If you want extra games and want to support development, check out **Docked Plus** in Settings — one small monthly subscription, and the core app always stays free.")
        }
    }

    private var controls: some View {
        HStack {
            Button("Skip", action: onDone)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.accent : Color.white.opacity(0.15))
                        .frame(width: i == page ? 18 : 7, height: 7)
                }
            }

            Spacer()

            Button {
                if page < pageCount - 1 { withAnimation { page += 1 } } else { onDone() }
            } label: {
                Text(page == pageCount - 1 ? "Get started" : "Next")
            }
            .fontWeight(.heavy)
            .padding(.vertical, 9).padding(.horizontal, 18)
            .background(Theme.accent, in: Capsule())
            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func card<Content: View>(
        emoji: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 40))
            Text(title).font(.system(size: 19, weight: .heavy))
                .multilineTextAlignment(.center)
            content()
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step(_ n: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(n).fontWeight(.heavy).foregroundStyle(Theme.accent)
            Text(text)
        }
        .font(.system(size: 12))
        .multilineTextAlignment(.leading)
    }
}
