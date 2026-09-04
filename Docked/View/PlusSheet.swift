//
//  PlusSheet.swift
//  Docked
//
//  The paywall. Docked is free with no ads; "Docked Plus" is a small
//  auto-renewing monthly subscription that unlocks the premium activities and
//  the TV colour themes. Must show the price, the term, and links to the
//  Privacy Policy and Terms of Use (Apple rejects subscription paywalls that
//  don't). Scrolls, with the action buttons pinned so "Maybe later" is always
//  reachable.
//

import SwiftUI
import StoreKit

struct PlusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreManager.self) private var store

    /// Optional line naming exactly what the user just tapped, e.g.
    /// "The colour-theme knob is part of Docked Plus."
    var context: String? = nil

    // TODO: before submitting, host a real privacy policy and put its URL here.
    private let privacyURL = URL(string: "https://acetwothree.github.io/docked/privacy")!
    // Apple's standard EULA — acceptable unless you ship your own terms.
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 18)

                    Text(store.entitled ? "You have Docked Plus" : "Docked Plus")
                        .font(.system(size: 19, weight: .heavy))
                        .multilineTextAlignment(.center)

                    if let context, !store.entitled {
                        Text(context)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(Theme.accent.opacity(0.12),
                                       in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Text("No ads, no tracking. Plus unlocks the premium activities and the TV colour themes — and backs a solo developer.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        perk("gamecontroller.fill", "Premium activities",
                             "Flow, Merge, Roll, Scratcher, Kinetic Sand, Connect 4 and Dots & Boxes")
                        divider
                        perk("paintpalette.fill", "TV colour themes",
                             "Switch the cabinet between every colourway")
                    }
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline))

                    if !store.entitled {
                        Text(fineprint)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }

            // Pinned footer — always visible without scrolling.
            VStack(spacing: 10) {
                Divider()
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
                    Button {
                        Task { await store.restore() }
                    } label: {
                        if store.restoring {
                            ProgressView()
                        } else {
                            Text("Restore Purchases").font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                    .disabled(store.restoring)

                    HStack(spacing: 8) {
                        Link("Privacy Policy", destination: privacyURL)
                        Text("·").foregroundStyle(.tertiary)
                        Link("Terms of Use", destination: termsURL)
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                Button(store.entitled ? "Done" : "Maybe later") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .background(.ultraThinMaterial)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backdrop)
        .presentationDetents([.large])
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
            if nowPlus { dismiss() }   // real purchase completed — leave the sheet
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
                    VStack(spacing: 1) {
                        Text("Get Docked Plus").font(.system(size: 16, weight: .heavy))
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
        "Docked Plus is an auto-renewing subscription billed to your Apple Account at \(priceLine). It renews automatically unless turned off at least 24 hours before the end of the current period. Manage or cancel in your Apple Account settings."
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 46)
    }

    private func perk(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 11)
    }
}
