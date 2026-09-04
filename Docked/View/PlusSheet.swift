//
//  PlusSheet.swift
//  Docked
//
//  The paywall. Docked is free with no ads; "Docked Plus" is a small
//  auto-renewing monthly subscription that unlocks the premium activities and
//  the TV colour themes. Must show the price, the term, and links to the
//  Privacy Policy and Terms of Use (Apple rejects subscription paywalls that
//  don't). Compact — fits a medium sheet with no scrolling.
//

import SwiftUI
import StoreKit

struct PlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    /// Optional line naming exactly what the user just tapped.
    var context: String? = nil

    // TODO: before submitting, host a real privacy policy and put its URL here.
    private let privacyURL = URL(string: "https://acetwothree.github.io/docked/privacy")!
    // Apple's standard EULA — acceptable unless you ship your own terms.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(Theme.hairline).frame(width: 36, height: 4).padding(.top, 8)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text(store.entitled ? "You have Docked Plus" : "Docked Plus")
                    .font(.system(size: 18, weight: .heavy))
            }

            if let context, !store.entitled {
                Text(context)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(Theme.accent.opacity(0.12),
                               in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(spacing: 6) {
                perk("gamecontroller.fill", "Every premium activity")
                perk("paintpalette.fill", "All TV colour themes")
                perk("checkmark.seal.fill", "No ads, no tracking — ever")
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline))

            Spacer(minLength: 0)

            if store.entitled {
                let activeLabel = store.hasPlus ? "Subscription active" : "Developer unlock active"
                Label(activeLabel, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.accent)
                if store.hasPlus {
                    Text("Manage or cancel in Settings ▸ Apple Account ▸ Subscriptions.")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                buyButton

                Text(fineprint)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Button {
                        Task { await store.restore() }
                    } label: {
                        if store.restoring { ProgressView() }
                        else { Text("Restore").font(.system(size: 12, weight: .semibold)) }
                    }
                    .buttonStyle(.plain)
                    .disabled(store.restoring)
                    Link("Privacy Policy", destination: privacyURL)
                        .font(.system(size: 12, weight: .semibold))
                    Link("Terms", destination: termsURL)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
            }

            Button(store.entitled ? "Done" : "Maybe later") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backdrop)
        .presentationDetents([.medium, .large])
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.hasPlus) { _, nowPlus in
            if nowPlus { dismiss() }
        }
    }

    private var priceLine: String { store.priceText ?? "$2.99 / month" }

    private var buyButton: some View {
        Button {
            Task { await store.purchase() }
        } label: {
            Group {
                if store.purchasing {
                    ProgressView().tint(Color(red: 0.11, green: 0.08, blue: 0.02))
                } else {
                    HStack(spacing: 8) {
                        Text("Get Docked Plus").font(.system(size: 15, weight: .heavy))
                        Text(priceLine).font(.system(size: 11, weight: .semibold)).opacity(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.accent, in: Capsule())
            .foregroundStyle(Color(red: 0.11, green: 0.08, blue: 0.02))
        }
        .buttonStyle(.plain)
        .disabled(store.purchasing || store.plusProduct == nil)
    }

    private var fineprint: String {
        "Auto-renews at \(priceLine) unless cancelled 24h before the period ends. Billed to your Apple Account; manage in Settings."
    }

    private func perk(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}
