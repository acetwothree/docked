//
//  PiPHelpView.swift
//  Docked
//
//  Static "how to use Picture-in-Picture" reference, shown from Settings.
//

import SwiftUI
import UIKit

struct PiPHelpView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("Enable Picture-in-Picture on iPhone") {
                Text("Open **Settings ▸ General ▸ Picture in Picture** and turn on **Start PiP Automatically**.")
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Open iPhone Settings", systemImage: "arrow.up.forward.app.fill")
                        .font(.subheadline.weight(.semibold))
                }
                Text("iOS only lets apps open Settings at their own page — from there tap ‹ Settings, then **General ▸ Picture in Picture**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Start a floating video") {
                stepped("1", "Play a video full-screen in the app you want (YouTube, Netflix, Hulu, Safari…).")
                stepped("2", "Swipe up to the Home Screen. The video shrinks into a floating window.")
                stepped("3", "Open Docked, then drag the floating window into the TV frame.")
            }

            Section("By app") {
                appRow("YouTube", "Needs Premium for background PiP in the app. Otherwise open the video in Safari and swipe up.")
                appRow("Netflix · Disney+ · Max · Prime Video · Apple TV · Hulu", "Start playback, then swipe up to the Home Screen.")
                appRow("Twitch", "Swipe up during a live stream.")
                appRow("Safari", "Play any video, then tap the PiP button in the player controls.")
            }

            Section("Fixes for common glitches") {
                fix("Video won't shrink to a window", "Force-quit and reopen the video app, then try again.")
                fix("PiP toggle is greyed out", "Re-check Settings ▸ General ▸ Picture in Picture.")
                fix("The app blocks PiP", "Some free tiers disable it — play the video in Safari or another app instead.")
                fix("Window slid off the edge", "Swipe inward from that edge to pull it back on screen.")
                fix("Frame doesn't line up", "Tap ⧉ in Docked, pick the matching spot, then nudge the window to fit.")
                fix("Black window or audio only", "Close the video and start it again, then re-trigger PiP.")
            }
        }
        .navigationTitle("Picture-in-Picture")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepped(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(n).font(.headline).foregroundStyle(Theme.accent)
            Text(text)
        }
    }
    private func appRow(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
    }
    private func fix(_ problem: String, _ solution: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(problem).font(.subheadline.weight(.semibold))
            Text(solution).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
