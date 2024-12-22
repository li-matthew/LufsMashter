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
    
    func makeNSView(context: Context) -> MTKView {
        return metalLufs
    }

    // Update the view whenever needed, this could be when the buffer or data changes
    func updateNSView(_ uiView: MTKView, context: Context) {
        // This is where you can perform updates, like refreshing the Metal view
        uiView.setNeedsDisplay(uiView.bounds)
    }
}
