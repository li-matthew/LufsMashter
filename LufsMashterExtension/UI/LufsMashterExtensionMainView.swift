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
    
    @ObservedObject var vizBuffers: ObservableBuffers
    
    @State private var metalLufs = MetalLufs(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    
    var body: some View {
        VStack {
            HStack {
                ParameterSlider(param: parameterTree.global.target, title: "LUFS Target")
                ParameterSlider(param: parameterTree.global.attack, title: "Attack")
                ParameterSlider(param: parameterTree.global.release, title: "Release")
                ParameterSlider(param: parameterTree.global.ratio, title: "Ratio")
            }
            HStack {
                Text(String(format: "%.2f dB Unprocessed LUFS", vizBuffers.buffers[0][0][0]))
                Text(String(format: "%.2f dB OUT LUFS", vizBuffers.buffers[1][0][0]))
                Text(String(format: "%.2f dB Reduction", 20 * log(vizBuffers.buffers[2][0][0])))
                Text(String(format: "%.2f raw reduction", vizBuffers.buffers[2][0][0]))
            }.padding()
            HStack {
                MetalLufsView(metalLufs: metalLufs).frame(width: 500, height: 200)
            }.padding()
        }
        .onAppear {
            metalLufs.metalView = vizBuffers
        }
    }
}
