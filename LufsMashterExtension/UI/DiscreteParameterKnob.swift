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
struct DiscreteParameterKnob: View {
    @State var param: ObservableAUParameter
    var title: String
    
    var body: some View {
        VStack {
            Text(title).fontWeight(.bold)
            
            SmallKnob(value: $param.value, range: param.min...param.max)
                .onChange(of: param.value) { _, newValue in
                                // Snap to the nearest discrete value
                    if (param.displayName == "osfactor") {
//                        param.value = vals.min(by: { abs($0 - newValue) < abs($1 - param.value) }) ?? newValue
//                        NSLog("SGS%f", newValue)
//                        param.value = pow(2, round(newValue))
                        param.value = round(newValue)
                    }
                    else {
                        param.value = round(newValue)
                    }
                }
                .accessibility(identifier: param.displayName).frame(maxWidth: 100, maxHeight: 100)
            Text(String(format: "%.2f", param.value))
        }
            
    }
}
