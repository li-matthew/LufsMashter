//
//  DataPlot.swift
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

import AudioKit
import Metal
import MetalKit

public struct FragmentConstants {
    public var foregroundColor: SIMD4<Float>
    public var backgroundColor: SIMD4<Float>
    public var isFFT: Bool
    public var isCentered: Bool
    public var isFilled: Bool

    // Padding is required because swift doesn't pad to alignment
    // like MSL does.
    public var padding: Int = 0
}

public class DataPlot: MTKView, MTKViewDelegate {
    let plotTexture: MTLTexture!
    let commandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState!
    let bufferSampleCount: Int
    var dataCallback: () -> [Float]
    var constants: FragmentConstants
    
    public init(frame frameRect: CGRect,
                constants: FragmentConstants,
                dataCallback: @escaping () -> [Float]) {
        self.dataCallback = dataCallback
        self.constants = constants
        bufferSampleCount = Int(frameRect.width)
        
        let desc = MTLTextureDescriptor()
        desc.textureType = .type1D
        desc.width = Int(frameRect.width)
        desc.pixelFormat = .r32Float
        assert(desc.height == 1)
        assert(desc.depth == 1)
        
        let device = MTLCreateSystemDefaultDevice()
        plotTexture = device?.makeTexture(descriptor: desc)
        commandQueue = device!.makeCommandQueue()
        
        let library = try! device?.makeDefaultLibrary(bundle: Bundle.main)
//        let library = device?.makeDefaultLibrary()

        let fragmentProgram = library!.makeFunction(name: "plotFragment")!
        let vertexProgram = library!.makeFunction(name: "plotVertex")!
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.rasterSampleCount = 1
        
        let colorAttachment = pipelineStateDescriptor.colorAttachments[0]!
        colorAttachment.pixelFormat = .bgra8Unorm
        colorAttachment.isBlendingEnabled = true
        colorAttachment.sourceRGBBlendFactor = .sourceAlpha
        colorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        colorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        colorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        pipelineState = try! device!.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        super.init(frame: frameRect, device: device)
        
        clearColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0)

        delegate = self
    }
    
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updatePlot(samples: [Float]) {
        if samples.count == 0 {
            return
        }
        
        var resampled = [Float](repeating: 0, count: bufferSampleCount)
        
        for i in 0 ..< bufferSampleCount {
            let x = Float(i) / Float(bufferSampleCount) * Float(samples.count - 1)
            let j = Int(x)
            let fraction = x - Float(j)
            resampled[i] = samples[j] * (1.0 - fraction) + samples[j + 1] * fraction
        }
        
        samples.withUnsafeBytes { ptr in
            plotTexture.replace(region: MTLRegionMake1D(0, bufferSampleCount),
                                    mipmapLevel: 0,
                                    withBytes: ptr.baseAddress!,
                                    bytesPerRow: 0)
        }
    }
    
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        // We may want to resize the texture.
    }
    
    public func draw(in view: MTKView) {
        updatePlot(samples: dataCallback())
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            if let renderPassDescriptor = currentRenderPassDescriptor {
                guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
                
                encoder.setRenderPipelineState(pipelineState)
                encoder.setFragmentTexture(plotTexture, index: 0)
                assert(MemoryLayout<FragmentConstants>.size == 48)
                encoder.setFragmentBytes(&constants, length: MemoryLayout<FragmentConstants>.size, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                encoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}
