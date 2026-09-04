import Foundation
import RevenueCat

enum SubscriptionPlanKind: Equatable {
    case weekly
    case monthly
    case annual
    case lifetime
    case other

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        case .other: return "Pro"
        }
    }

    var unitCaption: String {
        switch self {
        case .weekly: return "week"
        case .monthly: return "month"
        case .annual: return "year"
        case .lifetime: return "once"
        case .other: return ""
        }
    }

    static func from(packageTypeDescription: String, productIdentifier: String) -> Self {
        switch packageTypeDescription.lowercased() {
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "annual", "yearly": return .annual
        case "lifetime": return .lifetime
        default:
            return from(productIdentifier: productIdentifier)
        }
    }

    static func from(productIdentifier: String) -> Self {
        let identifier = productIdentifier.lowercased()
        if identifier.contains("week") { return .weekly }
        if identifier.contains("month") { return .monthly }
        if identifier.contains("annual") || identifier.contains("year") { return .annual }
        if identifier.contains("lifetime") || identifier.contains("life") { return .lifetime }
        return .other
    }
}

struct IntroOfferSummary: Equatable {
    enum PaymentMode: Equatable {
        case freeTrial
        case payAsYouGo
        case payUpFront
    }

    enum PeriodUnit: Equatable {
        case day
        case week
        case month
        case year
    }

    var paymentMode: PaymentMode
    var periodCount: Int
    var periodUnit: PeriodUnit

    var isFreeTrial: Bool { paymentMode == .freeTrial }
}

enum SubscriptionOfferPresentation {
    static func durationPhrase(for offer: IntroOfferSummary) -> String {
        "\(offer.periodCount) \(unitName(offer.periodUnit, count: offer.periodCount))"
    }

    /// Title-cased duration used in CTAs, e.g. `1-Week`.
    static func hyphenatedDuration(for offer: IntroOfferSummary) -> String {
        "\(offer.periodCount)-\(unitName(offer.periodUnit, count: offer.periodCount).capitalized)"
    }

    static func trialCardCaption(for offer: IntroOfferSummary) -> String? {
        guard offer.isFreeTrial else { return nil }
        return "\(durationPhrase(for: offer)) free"
    }

    static func purchaseButtonTitle(
        plan: SubscriptionPlanKind,
        price: String,
        intro: IntroOfferSummary?,
        isIntroEligible: Bool
    ) -> String {
        if plan == .lifetime {
            return "Get Lifetime Access - \(price)"
        }
        if isIntroEligible, let intro, intro.isFreeTrial {
            return "Start \(hyphenatedDuration(for: intro)) Free Trial"
        }
        return "Start Pro - \(price)"
    }

    static func legalFooter(
        plan: SubscriptionPlanKind,
        price: String,
        intro: IntroOfferSummary?,
        isIntroEligible: Bool
    ) -> String {
        if plan == .lifetime {
            return "One-time purchase. No subscription, no renewals."
        }
        if isIntroEligible, let intro, intro.isFreeTrial {
            let period = plan.unitCaption.isEmpty ? "period" : plan.unitCaption
            return "Free for \(durationPhrase(for: intro)), then \(price)/\(period). Cancel anytime in Settings at least 24 hours before the trial ends."
        }
        return "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    }

    static func settingsUpgradeTitle(isMonthlyTrialEligible: Bool) -> String {
        isMonthlyTrialEligible ? "Try Pro Free for 1 Week" : "Upgrade to Pro"
    }

    private static func unitName(_ unit: IntroOfferSummary.PeriodUnit, count: Int) -> String {
        switch unit {
        case .day: return count == 1 ? "day" : "days"
        case .week: return count == 1 ? "week" : "weeks"
        case .month: return count == 1 ? "month" : "months"
        case .year: return count == 1 ? "year" : "years"
        }
    }
}

extension Package {
    var planKind: SubscriptionPlanKind {
        switch packageType {
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .annual: return .annual
        case .lifetime: return .lifetime
        default:
            return SubscriptionPlanKind.from(productIdentifier: storeProduct.productIdentifier)
        }
    }

    var introOfferSummary: IntroOfferSummary? {
        guard let discount = storeProduct.introductoryDiscount else { return nil }

        let mode: IntroOfferSummary.PaymentMode
        switch discount.paymentMode {
        case .freeTrial: mode = .freeTrial
        case .payAsYouGo: mode = .payAsYouGo
        case .payUpFront: mode = .payUpFront
        @unknown default: return nil
        }

        let unit: IntroOfferSummary.PeriodUnit
        switch discount.subscriptionPeriod.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }

        return IntroOfferSummary(
            paymentMode: mode,
            periodCount: discount.subscriptionPeriod.value,
            periodUnit: unit
        )
    }
}
