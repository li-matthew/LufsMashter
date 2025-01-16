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
            ModWheel(value: $param.value).foregroundColor(.white.opacity(0.5))
                .onChange(of: param.value) { _, newValue in
                    // Map the slider value to the discrete range
                    param.value = reMap(sliderValue: mapToDiscreteRange(sliderValue: newValue, minValue: 3, maxValue: 128), minValue: 3, maxValue: 128)
                }
                .frame(width: 10, height: 128)
            Text(String(format: "%.0f", mapToDiscreteRange(sliderValue: param.value, minValue: 3, maxValue: 128)))
        }
            
    }
    
    private func mapToDiscreteRange(sliderValue: Float, minValue: Int, maxValue: Int) -> Float {
        let scaledValue = (sliderValue * Float(maxValue - minValue)) + Float(minValue)
        
        return round(scaledValue)
    }
    
    private func reMap(sliderValue: Float, minValue: Int, maxValue: Int) -> Float {
        let remap = (sliderValue - Float(minValue)) / Float(maxValue - minValue)
        
        return remap
    }
    
}
