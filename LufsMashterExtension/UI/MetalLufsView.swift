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
    
    func makeNSView(context: Context) -> MTKView {
//        metalLufs.target = (max(-60.0, min(20 * log10(target.value), 0.0)) + 60) / 60
        metalLufs.target = target.value
        return metalLufs
    }

    // Update the view whenever needed, this could be when the buffer or data changes
    func updateNSView(_ uiView: MTKView, context: Context) {
        // This is where you can perform updates, like refreshing the Metal view
        if let metalLufs = uiView as? MetalLufs {
//            metalLufs.target = (max(-60.0, min(20 * log10(target.value), 0.0)) + 60) / 60
            metalLufs.target = target.value
            metalLufs.updateTarget()
            metalLufs.setNeedsDisplay(metalLufs.bounds)
        }
    }
}
