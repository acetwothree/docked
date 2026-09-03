//
//  OnboardingView.swift
//  Docked
//
//  A floating card shown over the (dimmed) app on first launch: what Docked
//  is, how to turn on Picture-in-Picture, and how to place the video.
//  Presented as an in-app overlay — not its own screen — so the dashboard
//  stays visible behind it.
//

import SwiftUI
import UIKit

struct OnboardingView: View {
    var onDone: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var page = 0

    var body: some View {
        ZStack {
            // dim + blur the live app behind the card
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)

            cardShell
                .frame(maxWidth: 360)
                .padding(.horizontal, 22)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    private var cardShell: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)

            controls
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Theme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.hairline)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
    }

    // MARK: pages

    private var page1: some View {
        card(emoji: "🧩", title: "Meet Docked") {
            Text("Watch anything in a floating window while you doodle, take notes, or play. Docked reshapes itself around your video so nothing is ever hidden underneath it.")
        }
    }

    private var page2: some View {
        card(emoji: "📺", title: "Turn on Picture-in-Picture") {
            VStack(alignment: .leading, spacing: 10) {
                step("1", "Turn on **Start PiP Automatically** in iPhone Settings ▸ General ▸ Picture in Picture.")
                step("2", "Play a video full-screen in YouTube, Netflix, Safari…")
                step("3", "Swipe up to the Home Screen — the video becomes a floating window.")

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Open iPhone Settings", systemImage: "arrow.up.forward.app.fill")
                        .font(.system(size: 13, weight: .heavy))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .padding(.top, 2)

                Text("Opens Settings at Docked — tap ‹ Settings, then General ▸ Picture in Picture.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var page3: some View {
        card(emoji: "⧉", title: "Place it & go") {
            Text("Tap **Layout** any time to pick where your video sits — four corners, or a big top / bottom slot. Then drag the floating window into the TV frame. That's it.")
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

            Button {
                if page < 2 { withAnimation { page += 1 } } else { onDone() }
            } label: {
                Text(page == 2 ? "Get started" : "Next")
            }
            .fontWeight(.heavy)
            .padding(.vertical, 10).padding(.horizontal, 20)
            .background(Theme.accent, in: Capsule())
            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func card<Content: View>(
        emoji: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 14) {
            Text(emoji).font(.system(size: 46))
            Text(title).font(.system(size: 20, weight: .heavy))
                .multilineTextAlignment(.center)
            content()
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(n).fontWeight(.heavy).foregroundStyle(Theme.accent)
            Text(.init(text))
        }
        .font(.system(size: 12.5))
        .multilineTextAlignment(.leading)
    }
}
