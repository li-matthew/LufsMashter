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
    
    var body: some View {
        VStack {
            ArcKnob("s", value: $param.value, range: param.min...param.max)
            .accessibility(identifier: param.displayName)
            Text("\(param.displayName): \(param.value)")
            LufsRollingView()
        }
        .padding()
    }
}
