//
//  DataPlot.swift
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

import AudioKit
import Metal
import Combine
import MetalKit

//public struct FragmentConstants {
//    public var foregroundColor: SIMD4<Float>
//    public var backgroundColor: SIMD4<Float>
//    public var isFFT: Bool
//    public var isCentered: Bool
//    public var isFilled: Bool
//
//    // Padding is required because swift doesn't pad to alignment
//    // like MSL does.
//    public var padding: Int = 0
//}

public class MetalLufs: MTKView, MTKViewDelegate {
//    let plotTexture: MTLTexture!
    let commandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
//    let bufferSampleCount: Int
//    var dataCallback: () -> [Float]
//    var constants: FragmentConstants
    var LufsValues: [[Float]] = [[]]
    
    private var cancellables: Set<AnyCancellable> = []
    
    var metalView: ObservableLufsBuffer? {
        didSet {
            // Subscribe to updates from the ViewModel
            metalView?.$buffer
                .sink { [weak self] newData in
                    self?.LufsValues = newData
//                    self?.updateVertexBuffer()
//                    self?.setNeedsDisplay()
                }
                .store(in: &cancellables)
        }
    }
    
    public init(frame frameRect: CGRect
//                constants: FragmentConstants,
//                dataCallback: @escaping () -> [Float]
    ) {
//        self.dataCallback = dataCallback
//        self.constants = constants
//        bufferSampleCount = Int(frameRect.width)
//        
//        let desc = MTLTextureDescriptor()
//        desc.textureType = .type1D
//        desc.width = Int(frameRect.width)
//        desc.pixelFormat = .r32Float
//        assert(desc.height == 1)
//        assert(desc.depth == 1)
        
        let device = MTLCreateSystemDefaultDevice()
//        plotTexture = device?.makeTexture(descriptor: desc)
        commandQueue = device!.makeCommandQueue()
        
        let library = try! device?.makeDefaultLibrary(bundle: Bundle.main)

        let fragmentProgram = library!.makeFunction(name: "plotFragment")!
        let vertexProgram = library!.makeFunction(name: "plotVertex")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.rasterSampleCount = 1
        
//        let colorAttachment = pipelineStateDescriptor.colorAttachments[0]!
//        colorAttachment.pixelFormat = .bgra8Unorm
//        colorAttachment.isBlendingEnabled = true
//        colorAttachment.sourceRGBBlendFactor = .sourceAlpha
//        colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
//        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
//        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try! device!.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        super.init(frame: frameRect, device: device)
        
        clearColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0)

        delegate = self
    }
    
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateGraphData(_ data: [[Float]]) {
        // Update the amplitude data and re-render
        LufsValues = data
        updateVertexBuffer()
        self.setNeedsDisplay(self.frame)  // Trigger a redraw
    }
    
    func updateVertexBuffer() {
        let vertexData: [[Float]] = LufsValues
        vertexBuffer = device!.makeBuffer(bytes: vertexData[0], length: vertexData[0].count * MemoryLayout<Float>.size, options: [])
    }
    
//    func updatePlot(samples: [Float]) {
//        if samples.count == 0 {
//            return
//        }
//        
//        var resampled = [Float](repeating: 0, count: bufferSampleCount)
//        
//        for i in 0 ..< bufferSampleCount {
//            let x = Float(i) / Float(bufferSampleCount) * Float(samples.count - 1)
//            let j = Int(x)
//            let fraction = x - Float(j)
//            resampled[i] = samples[j] * (1.0 - fraction) + samples[j + 1] * fraction
//        }
//        
//        samples.withUnsafeBytes { ptr in
//            plotTexture.replace(region: MTLRegionMake1D(0, bufferSampleCount),
//                                    mipmapLevel: 0,
//                                    withBytes: ptr.baseAddress!,
//                                    bytesPerRow: 0)
//        }
//    }
    
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        // We may want to resize the texture.
    }
    
    public func draw(in view: MTKView) {
        
//        updatePlot(samples: dataCallback())
//        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            if let renderPassDescriptor = currentRenderPassDescriptor {
                guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                
                encoder.setRenderPipelineState(pipelineState)
//                encoder.setFragmentTexture(plotTexture, index: 0)
                encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
//                assert(MemoryLayout<FragmentConstants>.size == 48)
//                encoder.setFragmentBytes(&constants, length: MemoryLayout<FragmentConstants>.size, index: 0)
                encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
                encoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
//            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}
