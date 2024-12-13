//
//  LufsRollingView.swift
//  LoudMashter
//
//  Created by mashen on 12/10/24.
//

import AudioKitUI
import SwiftUI
import AudioKit
import Accelerate

public struct LufsRollingView: ViewRepresentable {
    @State private var history: [Float]
//    private let nodeTap: LufsTap
//    private let nodeTap: RingBufferTap
    private let constants: FragmentConstants

    public init(
                color: Color = .gray,
                backgroundColor: Color = .clear,
                isCentered: Bool = false,
                isFilled: Bool = false,
                bufferSize: UInt32 = 1024) {
        constants = FragmentConstants(foregroundColor: color.simd,
                                      backgroundColor: backgroundColor.simd,
                                      isFFT: false,
                                      isCentered: isCentered,
                                      isFilled: isFilled)
//        nodeTap = LufsTap(node, bufferSize: bufferSize, callbackQueue: .main)
//        nodeTap = RingBufferTap(node, bufferSize: bufferSize, callbackQueue: .main)
        history = [Float](repeating: 0.0, count: Int(bufferSize))
    }
    
    func rollHistory(data: Float) -> [Float] {
        history.reverse()
        _ = history.popLast()
//        history.removeLast(data.count)
        history.reverse()
        history.append(data)
//        history.append(contentsOf: data)
        return history
    }
    
    public func test() {
        
    }

    var plot: DataPlot {
//        nodeTap.start()
        
        return DataPlot(frame: CGRect(x: 0, y: 0, width: Int(1024), height: 1024), constants: constants) {
//            rollHistory(data: nodeTap.amp)
            history
        }
    }

    #if os(macOS)
    public func makeNSView(context: Context) -> DataPlot { return plot }
    public func updateNSView(_ nsView: DataPlot, context: Context) {}
    #else
    public func makeUIView(context: Context) -> FloatPlot { return plot }
    public func updateUIView(_ uiView: FloatPlot, context: Context) {}
    #endif
}

