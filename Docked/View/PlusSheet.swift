//
//  PlusSheet.swift
//  Docked
//
//  The (very low-key) paid tier. Docked is free with no ads; Plus is a small
//  monthly subscription that unlocks premium activities and supports the
//  developer. Purchase flow is not wired up yet — this just presents the offer.
//

import SwiftUI

struct PlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showThanks = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.top, 18)

            Text("Docked is free — always")
                .font(.system(size: 19, weight: .heavy))

            Text("No ads, no tracking, no paywalled core features. **Docked Plus** is an optional way to get the premium activities and back a solo developer.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 0) {
                perk("gamecontroller.fill", "Premium activities", "Extra games & fidgets, unlocked as they ship")
                divider
                perk("heart.fill", "Support development", "Keeps updates coming")
                divider
                perk("checkmark.seal.fill", "Everything else stays free", "The core app never goes behind a paywall")
            }
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))

            Spacer(minLength: 0)

            Button {
                showThanks = true
            } label: {
                VStack(spacing: 1) {
                    Text("Get Docked Plus").font(.system(size: 16, weight: .heavy))
                    Text("$2.99 / month").font(.system(size: 11, weight: .semibold)).opacity(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.accent, in: Capsule())
                .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
            }
            .buttonStyle(.plain)

            Text("In-app purchases arrive in a future update.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            Button("Maybe later") { dismiss() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backdrop)
        .alert("Thanks for the interest!", isPresented: $showThanks) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Subscriptions aren't live yet — this build just shows what's coming. Everything in the app is free right now.")
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
    }

    private func perk(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
    }
}
