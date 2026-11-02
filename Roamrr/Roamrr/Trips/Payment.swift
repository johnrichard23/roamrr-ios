import Foundation
import RoamrrDesign

/// How a payment between two people was made.
enum PaymentMethod: String, CaseIterable, Hashable {
    case cash = "Cash"
    case bank = "Bank transfer"
    case eWallet = "E-wallet"

    var symbol: String {
        switch self {
        case .cash: "banknote"
        case .bank: "building.columns"
        case .eWallet: "qrcode"
        }
    }
}

/// Money one person handed another to settle up. Roamrr only records it; nothing moves through the app.
struct Payment: Identifiable, Hashable {
    let id: UUID
    var from: AvatarMember
    var to: AvatarMember
    var amount: Decimal
    var method: PaymentMethod
    var date: Date
    var note: String
    /// Added on this phone and not sent yet.
    var isPending = false
}
