//
//  ParameterSliderDiscrete.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import SwiftUI
import Controls

/// A SwiftUI Slider container which is bound to an ObservableAUParameter
///
/// This view wraps a SwiftUI Slider, and provides it relevant data from the Parameter, like the minimum and maximum values.
struct ParameterSliderDiscrete: View {
    @State var param: ObservableAUParameter
    var title: String
    
    var body: some View {
        VStack {
            Text(title).fontWeight(.bold)
            Spacer()
            IndexedSlider(index: getIndex(param: $param.value), labels: ["2", "4", "8", "16"])
                .padding()
                .frame(width: 100,
                       height: 10)
            Spacer()
//            Text(String(format: "%.2f", param.value))
        }
            
    }
    
    private func getIndex(param: Binding<Float>) -> Binding<Int> {
        return Binding<Int>(
            get: {
                Int(round(param.wrappedValue)) // Get the rounded value of the float
            },
            set: { newValue in
                param.wrappedValue = Float(newValue) // Set the float value from the integer
            }
        )
    }
}
