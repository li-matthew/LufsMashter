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
            VStack {
                Spacer()
                Rectangle()
                    .fill(currOut > param.value ? Color.red : Color.green)
                    .frame(height: 500 * CGFloat(currOut), alignment: .bottom)
                .animation(.linear(duration: 0.1), value: currOut)}
        }.padding()
    }
}
