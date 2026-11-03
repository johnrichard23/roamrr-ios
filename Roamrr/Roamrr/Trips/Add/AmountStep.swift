import RoamrrDesign
import SwiftUI

/// Step 1: the amount, typed on a number pad that is already open.
struct AmountStep: View {
    let model: AddExpenseViewModel

    var body: some View {
        AmountPad(text: Binding(get: { model.amountText }, set: { model.amountText = $0 })) {
            AmountPill(title: "PHP")
        }
    }
}
