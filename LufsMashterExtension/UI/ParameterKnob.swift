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
struct ParameterKnob: View {
    @State var param: ObservableAUParameter
    var title: String
    
    var body: some View {
        VStack {
            Text(title).fontWeight(.bold)
            if (param.displayName == "filtersize") {
                SmallKnob(value: $param.value, range: param.min...param.max)
                    .onChange(of: param.value) { _, newValue in
                        
                        param.value = round(newValue)
                    }
                    .accessibility(identifier: param.displayName).frame(maxWidth: 100, maxHeight: 100)
                Text(String(format: "%.0f", param.value))
            } else {
                SmallKnob(value: $param.value, range: param.min...param.max)
                    .accessibility(identifier: param.displayName).frame(maxWidth: 100, maxHeight: 100)
                if (param.displayName == "target") {
                    Text(String(format: "%.2f LUFS", (66 * (param.value)) - 60))
                } else if (param.displayName == "thresh") {
                    Text(String(format: "%.2f dB", (66 * (param.value)) - 60))
                } else if (param.displayName == "attack" || param.displayName == "release") {
                    Text(String(format: "%.2f", param.value))
                } else {
                    Text(String(format: "%.2f", param.value))
                }
            }
        }
    }
}
