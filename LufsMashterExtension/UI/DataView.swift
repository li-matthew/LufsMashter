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
struct DataView: View {
    @State var param: ObservableAUParameter
    @Binding var val: Float
    var title: String
    var units: String

    var body: some View {
        VStack {
            Text(title).font(.headline).fontWeight(.bold)
            if units == "LUFS" {
                Text(String(format: "%.2f", (60 * val) - 60)).font(.title).fontWeight(.bold).foregroundColor(val > param.value ? .red : .green)
                Text(units).font(.subheadline).fontWeight(.bold)
            } else if units == "x" {
                Text(String(format: "%.4f%@", val, units)).font(.title).fontWeight(.bold).foregroundColor(Color(red: 1 - Double(val), green: Double(val), blue: 0.0))
                
            } else if units == "dB" {
                Text(String(format: "%.2f", (20 * log10(val)))).font(.title).fontWeight(.bold).foregroundColor(Color(red: 1 - Double(val), green: Double(val), blue: 0.0))
                Text(units).font(.subheadline).fontWeight(.bold)
            }
            
        }.frame(width: 150, height: 50)
    }
}
