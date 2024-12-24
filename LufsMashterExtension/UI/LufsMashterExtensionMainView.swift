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
    @ObservedObject var luffers: ObservableLufsBuffer
    
    @State private var metalLufs = MetalLufs(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    
    var body: some View {
        VStack {
            ParameterSlider(param: parameterTree.global.dbs)
            
            MetalLufsView(metalLufs: metalLufs)
        }
        .onAppear {
            metalLufs.metalView = luffers
        }
    }
}
