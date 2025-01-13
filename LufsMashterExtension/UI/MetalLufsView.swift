//
//  MetalLufsView.swift
//  LufsMashter
//
//  Created by mashen on 12/21/24.
//

import SwiftUI
import MetalKit

struct MetalLufsView: NSViewRepresentable {
    var metalLufs: MetalLufs
    @State var target: ObservableAUParameter
    @State var thresh: ObservableAUParameter
    @Binding var view: Bool
    
    func makeNSView(context: Context) -> MTKView {
        if (view) {
            metalLufs.target = target.value
        } else {
            metalLufs.target = thresh.value
        }
        return metalLufs
    }

    // Update the view whenever needed, this could be when the buffer or data changes
    func updateNSView(_ uiView: MTKView, context: Context) {
        // This is where you can perform updates, like refreshing the Metal view
        if let metalLufs = uiView as? MetalLufs {
            if (view) {
                metalLufs.target = target.value
            } else {
                metalLufs.target = thresh.value
            }
            metalLufs.updateTarget()
            metalLufs.setNeedsDisplay(metalLufs.bounds)
        }
    }
}
