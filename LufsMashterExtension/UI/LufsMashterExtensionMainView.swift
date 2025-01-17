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
    @ObservedObject var lufsVals: ObservableVals
    @ObservedObject var tpVals: ObservableVals
    
    @ObservedObject var isRecording: ObservableState
    @ObservedObject var isReset: ObservableState
    @ObservedObject var toggleView: ObservableState
    
    @State private var metalLufs: MetalLufs?
    @State private var meterView: DataView?
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack { // TOP
                VStack {
                    Text("6dB")
                    Spacer()
                    Text("-60dB")
                }
                
                HStack { // Rolling View
                    if let metalLufs = metalLufs {
                        MetalLufsView(metalLufs: metalLufs, target: parameterTree.global.target, thresh: parameterTree.global.thresh, view: $toggleView.val)
                            .frame(width: 800, height: 400)
                    } else {
                        Text("Initializing Metal View...")
                            .frame(width: 800, height: 400)
                    }
                }
                .padding()
                
                Meter(param: parameterTree.global.target, currIn: $lufsVals.vals[0], currOut: $lufsVals.vals[1], currRed: $lufsVals.vals[2])
                
                VStack { // LIMITER READOUT
                    Text("TP LIMIT")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[0], section: "TP", title: "IN", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[2], section: "TP", title: "REDUCTION MULT.", units: "x")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[2], section: "TP", title: "dB RED.", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[1], section: "TP", title: "OUT", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[1], section: "TP", title: "DELTA", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $tpVals.vals[3], section: "TP", title: "MAX", units: "dB")
                    Spacer()
                }
                
                VStack { // LUFFER READOUT
                    Text("LUFFER")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[0], section: "LUFS", title: "IN", units: "LUFS")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[2], section: "LUFS", title: "REDUCTION MULT.", units: "x")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[2], section: "LUFS", title: "dB RED.", units: "dB")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[1], section: "LUFS", title: "OUT", units: "LUFS")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[1], section: "LUFS", title: "DELTA", units: "LUFS")
                    Spacer()
                    DataView(param: parameterTree.global.target, val: $lufsVals.vals[3], section: "LUFS", title: "INTEGRATED", units: "LUFS")
                    Spacer()
                }
            }
            .onAppear {
                if metalLufs == nil {
                    metalLufs = MetalLufs(frame: CGRect(x: 0, y: 0, width: 800, height: 400), target: parameterTree.global.target, isRecording: isRecording, toggleView: toggleView)
                }
                metalLufs?.metalView = vizBuffers
            }
            
            HStack { // BOTTOM
                ParameterSliderDiscrete(param: parameterTree.global.osfactor, title: "Oversampling")
//                ParameterSlider(param: parameterTree.global.filtersize, title: "Filter Size")
                
                ParameterKnob(param: parameterTree.global.thresh, title: "Threshold")
                ParameterKnob(param: parameterTree.global.attack, title: "Attack")
                ParameterKnob(param: parameterTree.global.release, title: "Release")
                
//                Spacer()
//                ParameterKnob(param: parameterTree.global.knee, title: "Knee")
//                Spacer()
                Text(toggleView.val ? "LUFS" : "TP")
                    .frame(width: 50)
                    .padding(2)
                    .background(toggleView.val ? Color.pink : Color.purple)
                    .opacity(toggleView.val ? 0.5 : 1.0)
                    .onTapGesture {
                        toggleView.update(state: !toggleView.val)
                    }
                
                ParameterKnob(param: parameterTree.global.target, title: "LUFS Target")
                
                Text("Reset")
                    .frame(width: 50)
                    .padding(2)
                    .background((isReset.val || isRecording.val) ? Color.red : Color.blue)
                    .opacity(isReset.val ? 0.5 : 1.0)
                    .onTapGesture {
                        if (!isReset.val) {
                            isReset.update(state: true)
                        }
                    }
                    .disabled(isReset.val || isRecording.val)
                
                Text(isRecording.val ? "Stop" : "Start")
                    .frame(width: 50)
                    .padding(2)
                    .background(isReset.val ? Color.red : (isRecording.val ? Color.green : Color.blue))
                    .opacity(isRecording.val ? 0.5 : 1.0)
                    .onTapGesture {
                        isRecording.update(state: !isRecording.val)
                    }
                    .disabled(isReset.val)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        Spacer()
    }
}
