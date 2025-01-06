//
//  Meter.swift
//  LufsMashter
//
//  Created by mashen on 1/3/25.
//

import SwiftUI

struct Meter: View {
    @State var param: ObservableAUParameter
    @Binding var currIn: Float
    @Binding var currOut: Float
    @Binding var currRed: Float
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gray bar
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 400)
            
            // Green bar: Represents the level up to the threshold
            Rectangle()
                .fill(Color.green)
                .frame(height: CGFloat(min(currOut, param.value)) * 400).frame(alignment: .bottom)
            
            // Red bar: Visible when currOut exceeds the threshold
            if currOut > param.value {
                Rectangle()
                    .fill(Color.red)
                    .frame(height: CGFloat((currOut - param.value)) * 400)
                    .offset(y: -CGFloat(param.value) * 400) // Shift up to align above the threshold
            }
            
            // Threshold line
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
                .frame(height: 1) // The thickness of the threshold line
                .offset(y: -CGFloat(param.value) * 400) // Position at threshold value
        }
        .frame(width: 10, height: 400) // Ensure the full height is reserved
        .animation(.linear(duration: 0.1), value: currOut)
    }
}
