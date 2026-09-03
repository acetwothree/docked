//
//  StoreManager.swift
//  Docked
//
//  StoreKit 2 wrapper for the single "Docked Plus" auto-renewable
//  subscription. Loads the product, runs the purchase / restore flows, and
//  publishes `hasPlus` from the current entitlements — refreshed on launch,
//  on every `Transaction.updates` event, and when the app returns to the
//  foreground.
//

import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {

    /// Must match the Product ID created in App Store Connect and in
    /// Docked.storekit.
    static let plusProductID = "com.acetwothree.docked.plus.monthly"

    private(set) var plusProduct: Product?
    /// True while the user has an active, non-revoked Plus subscription.
    private(set) var hasPlus = false
    /// Flips true once the first entitlement check has completed, so callers
    /// can tell "not Plus" from "haven't checked yet".
    private(set) var ready = false

    private(set) var purchasing = false
    private(set) var restoring = false

    /// Set when a user-facing error should be shown; cleared by the view.
    var errorMessage: String?

    // MARK: Lifecycle

    /// Drives the whole manager. Call once from a long-lived `.task {}` — it
    /// loads the product, does the initial entitlement check, then listens for
    /// transaction updates for the rest of the app's lifetime.
    func start() async {
        await loadProduct()
        await refreshEntitlements()
        ready = true
        for await update in Transaction.updates {
            await apply(update)
        }
    }

    // MARK: Product

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.plusProductID])
            plusProduct = products.first
        } catch {
            errorMessage = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    /// e.g. "$2.99 / month" — nil until the product loads.
    var priceText: String? {
        guard let product = plusProduct else { return nil }
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayPrice }
        return "\(product.displayPrice) / \(Self.unitName(period))"
    }

    private static func unitName(_ period: Product.SubscriptionPeriod) -> String {
        let v = period.value
        switch period.unit {
        case .day:   return v == 1 ? "day" : "\(v) days"
        case .week:  return v == 1 ? "week" : "\(v) weeks"
        case .month: return v == 1 ? "month" : "\(v) months"
        case .year:  return v == 1 ? "year" : "\(v) years"
        @unknown default: return "period"
        }
    }

    // MARK: Purchase / restore

    func purchase() async {
        guard let product = plusProduct else {
            await loadProduct()
            if plusProduct == nil {
                errorMessage = "The subscription isn't available right now. Please try again later."
            }
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if let transaction = verified(verification) {
                    await transaction.finish()
                    await refreshEntitlements()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Your purchase is pending approval and will unlock once it's approved."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase didn't go through. You haven't been charged — please try again."
        }
    }

    func restore() async {
        restoring = true
        defer { restoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            // Not an error — the user dismissed the sign-in sheet.
        } catch {
            errorMessage = "Couldn't restore your purchases. Please try again."
        }
        await refreshEntitlements()
        if !hasPlus {
            errorMessage = errorMessage ?? "No active Docked Plus subscription was found on this Apple Account."
        }
    }

    // MARK: Entitlements

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = verified(result) else { continue }
            if transaction.productID == Self.plusProductID, transaction.revocationDate == nil {
                active = true
            }
        }
        hasPlus = active
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard let transaction = verified(result) else { return }
        await transaction.finish()
        await refreshEntitlements()
    }

    private func verified<T>(_ result: VerificationResult<T>) -> T? {
        switch result {
        case .verified(let safe): return safe
        case .unverified:         return nil
        }
    }
}
