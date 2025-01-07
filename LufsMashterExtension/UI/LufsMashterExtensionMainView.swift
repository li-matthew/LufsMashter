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
    @ObservedObject var meterVals: ObservableVals
    
    @State private var metalLufs: MetalLufs?
    @State private var meterView: DataView?
    
    var body: some View {
        VStack {
            HStack {
                HStack {
                    if let metalLufs = metalLufs {
                        MetalLufsView(metalLufs: metalLufs, target: parameterTree.global.target)
                            .frame(width: 500, height: 400)
                    } else {
                        Text("Initializing Metal View...").frame(width: 500, height: 200)
                    }
                }.padding()
                Meter(param: parameterTree.global.target, currIn: $meterVals.vals[0], currOut: $meterVals.vals[1], currRed: $meterVals.vals[2])
                VStack {
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $meterVals.vals[0], title: "IN", units: "LUFS")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $meterVals.vals[2], title: "REDUCTION MULT.", units: "x")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $meterVals.vals[2], title: "dB RED.", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $meterVals.vals[1], title: "OUT", units: "LUFS")
                    Spacer()
                }
            }
            .onAppear {
                if metalLufs == nil {
                    metalLufs = MetalLufs(frame: CGRect(x: 0, y: 0, width: 500, height: 200), target: parameterTree.global.target)
                }
                metalLufs?.metalView = vizBuffers
                
            }
            HStack {
                ParameterSlider(param: parameterTree.global.target, title: "LUFS Target")
                Spacer()
                ParameterSlider(param: parameterTree.global.attack, title: "Attack")
                Spacer()
                ParameterSlider(param: parameterTree.global.release, title: "Release")
                Spacer()
                ParameterSlider(param: parameterTree.global.smooth, title: "Smooth")
            }.frame(width: 500, height: 100)
        }.padding()
    }
}
