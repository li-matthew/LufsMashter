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
//    @State var target: ObservableAUParameter
    
    func makeNSView(context: Context) -> MTKView {
//        metalLufs.target = target.value
//        metalLufs = MetalLufs(target: target)
        return metalLufs
    }

    // Update the view whenever needed, this could be when the buffer or data changes
    func updateNSView(_ uiView: MTKView, context: Context) {
        // This is where you can perform updates, like refreshing the Metal view
        if let metalLufs = uiView as? MetalLufs {
//            metalLufs.target = target.value
            metalLufs.setNeedsDisplay(metalLufs.bounds)
        }
    }
}
