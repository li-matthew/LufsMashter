//
//  ParameterSlider.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import SwiftUI
import Controls

/// A SwiftUI Slider container which is bound to an ObservableAUParameter
///
/// This view wraps a SwiftUI Slider, and provides it relevant data from the Parameter, like the minimum and maximum values.
struct ParameterSlider: View {
    @State var param: ObservableAUParameter
    var title: String
    
    var body: some View {
        VStack {
            Text(title).fontWeight(.bold)
            SmallKnob(value: $param.value, range: param.min...param.max)
                .accessibility(identifier: param.displayName)
            if (param.displayName == "target") {
                Text(String(format: "%.2f dBs", (20 * log10(param.value))))
            } else {
                Text(String(format: "%.2f", param.value))
            }
        }
    }
}
