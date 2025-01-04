//
//  MeterView.swift
//  LufsMashter
//
//  Created by mashen on 1/2/25.
//

import SwiftUI
import Combine

/// A SwiftUI Slider container which is bound to an ObservableAUParameter
///
/// This view wraps a SwiftUI Slider, and provides it relevant data from the Parameter, like the minimum and maximum values.
struct MeterView: View {
    @State var param: ObservableAUParameter
    @Binding var val: Float
    var title: String
    var units: String

    var body: some View {
        VStack {
            Text(title).fontWeight(.bold)
//            Text(String(format: "%f", param.value))
            if units == "LUFS" {
                Text(String(format: "%.2f %@", 20 * log10(val), units))
            } else {
                Text(String(format: "%.2f %@", val, units))
            }
        }
    }
}
