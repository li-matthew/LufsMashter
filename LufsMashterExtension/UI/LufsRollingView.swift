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

struct LufsRollingView: View {
    @ObservedObject var luffers: ObservableLufsBuffer
//    @State var param: ObservableAUParameter
//    var update: () -> [Float]
//    @State var vizData: [Float]
//    var timer: Timer?
    
//    init(update: @escaping () -> [Float]) {
//        self.update = update
//        NSLog("\(update())")
//        self.vizData = update()
//        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [self] _ in
//            self.updateVisualization()
////            NSLog("\(vizData)")
//        }
//    }
////    
//    func updateVisualization() {
//        vizData = update()
////        samplesAsString()
//    }
//    @State private var history: [Float]
//    private let nodeTap: LufsTap
//    private let nodeTap: RingBufferTap
//    private let constants: FragmentConstants

//    public init(
//                color: Color = .gray,
//                backgroundColor: Color = .clear,
//                isCentered: Bool = false,
//                isFilled: Bool = false,
//                bufferSize: UInt32 = 1024) {
//        constants = FragmentConstants(foregroundColor: color.simd,
//                                      backgroundColor: backgroundColor.simd,
//                                      isFFT: false,
//                                      isCentered: isCentered,
//                                      isFilled: isFilled)
////        nodeTap = LufsTap(node, bufferSize: bufferSize, callbackQueue: .main)
////        nodeTap = RingBufferTap(node, bufferSize: bufferSize, callbackQueue: .main)
//        history = [Float](repeating: 0.0, count: Int(bufferSize))
//    }
    
//    func rollHistory(data: Float) -> [Float] {
//        history.reverse()
//        _ = history.popLast()
////        history.removeLast(data.count)
//        history.reverse()
//        history.append(data)
////        history.append(contentsOf: data)
//        return history
//    }
    
    private func samplesAsString() -> String {
//        return vizData
        luffers.buffer.map { String(format: "%.2f", $0) }.joined(separator: ", ")
    }
    
    var body: some View {
        Text(samplesAsString())
                        .font(.body)
                        .padding()
                        .multilineTextAlignment(.leading)
        Text("gesg")
    }

//    var plot: DataPlot {
////        nodeTap.start()
//        
//        return DataPlot(frame: CGRect(x: 0, y: 0, width: Int(1024), height: 1024), constants: constants) {
////            rollHistory(data: nodeTap.amp)
//            history
//        }
//    }

//    #if os(macOS)
//    public func makeNSView(context: Context) -> DataPlot { return plot }
//    public func updateNSView(_ nsView: DataPlot, context: Context) {}
//    #else
//    public func makeUIView(context: Context) -> FloatPlot { return plot }
//    public func updateUIView(_ uiView: FloatPlot, context: Context) {}
//    #endif
}

