//
//  LufsMashterExtensionMainView.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import SwiftUI
import Combine

struct LufsMashterExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    @ObservedObject var inLuffers: ObservableLufsBuffer
    @ObservedObject var gainReduction: ObservableLufsBuffer
    @ObservedObject var outLuffers: ObservableLufsBuffer
    
    @State private var metalLufs = MetalLufs(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    @State private var metalLufsOut = MetalLufs(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    @State private var metalGain = MetalLufs(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    
    var body: some View {
        VStack {
            HStack {
                ParameterSlider(param: parameterTree.global.dbs)
                ParameterSlider(param: parameterTree.global.sens)
            }
            Text(String(format: "%.2f dB curr", 20 * log(inLuffers.buffer[0][0])))
            Text(String(format: "%.2f dB out", 20 * log(outLuffers.buffer[0][0])))
            Text(String(format: "%.2f dB red", 20 * log(gainReduction.buffer[0][0])))
            Text(String(format: "%.2f r", gainReduction.buffer[0][0]))
            HStack {
                MetalLufsView(metalLufs: metalLufs).frame(width: 250, height: 100)
                MetalLufsView(metalLufs: metalLufsOut).frame(width: 250, height: 100)
                MetalLufsView(metalLufs: metalGain).frame(width: 100, height: 100)
            }
        }
        .onAppear {
            metalLufs.metalView = inLuffers
            metalLufsOut.metalView = outLuffers
            metalGain.metalView = gainReduction
        }
    }
}
