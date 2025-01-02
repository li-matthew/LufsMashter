//
//  DataPlot.swift
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

import MetalKit
import Combine

var lineColors: [SIMD4<Float>] = [
    SIMD4(1.0, 0.0, 0.0, 1.0), // Red
    SIMD4(0.0, 1.0, 0.0, 1.0), // Green
    SIMD4(0.0, 0.0, 1.0, 1.0)  // Blue
]

public class MetalLufs: MTKView, MTKViewDelegate {
    let commandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState!
    
//    var vizValues: [[[Float]]] = [[[]]]
    var vizValues: [[[Float]]] = Array(repeating: [[]], count: 3)
    
//    var vertexBuffers: [MTLBuffer] = []
    var inVertexBuffer: MTLBuffer!
    var outVertexBuffer: MTLBuffer!
    var redVertexBuffer: MTLBuffer!
    
    let constants = MTLFunctionConstantValues()
    var length: UInt32 = 1024
    
    private var cancellables: Set<AnyCancellable> = []
    
    var metalView: ObservableBuffers? {
        didSet {
            // Subscribe to updates from the ViewModel
            metalView?.$buffers
                .sink { [weak self] newData in
                    self?.vizValues = newData
                    self?.updateVertexBuffers()
                    self?.setNeedsDisplay(self?.bounds ?? CGRect.zero)
                }
                .store(in: &cancellables)
        }
    }
    
    public init(frame frameRect: CGRect) {
        
        let device = MTLCreateSystemDefaultDevice()
        commandQueue = device!.makeCommandQueue()
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        constants.setConstantValue(&length, type: .uint, index: 0)
        
        let library = try! device?.makeDefaultLibrary(bundle: Bundle.main)
            
        let fragmentFunction = library!.makeFunction(name: "fragmentData")!
        let vertexFunction = try! library!.makeFunction(name: "vertexData", constantValues: constants)
        pipelineStateDescriptor.vertexFunction = vertexFunction
        pipelineStateDescriptor.fragmentFunction = fragmentFunction
        
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
        
        updateVertexBuffers()
        
        clearColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0)

        delegate = self
    }
    
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateVertexBuffers() {
        let inVertexData: [[Float]] = vizValues[0]
        let outVertexData: [[Float]] = vizValues[1]
        let redVertexData: [[Float]] = vizValues[2]
        
        inVertexBuffer = device!.makeBuffer(bytes: inVertexData[0], length: inVertexData[0].count * MemoryLayout<Float>.size, options: [])
        outVertexBuffer = device!.makeBuffer(bytes: outVertexData[0], length: outVertexData[0].count * MemoryLayout<Float>.size, options: [])
        redVertexBuffer = device!.makeBuffer(bytes: redVertexData[0], length: redVertexData[0].count * MemoryLayout<Float>.size, options: [])
    }
    
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        // We may want to resize the texture.
    }
    
    public func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState,
                  let commandQueue = commandQueue,
                  let inVertexBuffer = inVertexBuffer
        else {
                return
            }

            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

            renderEncoder?.setRenderPipelineState(pipelineState)
        
            renderEncoder?.setVertexBuffer(inVertexBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentBytes(&lineColors[0],
                                                        length: MemoryLayout<SIMD4<Float>>.stride,
                                                        index: 1)
            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
        
            renderEncoder?.setVertexBuffer(outVertexBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentBytes(&lineColors[1],
                                                        length: MemoryLayout<SIMD4<Float>>.stride,
                                                        index: 1)
            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
            
            renderEncoder?.setVertexBuffer(redVertexBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentBytes(&lineColors[2],
                                                        length: MemoryLayout<SIMD4<Float>>.stride,
                                                        index: 1)
            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
        
//            for (index, buffer) in vertexBuffers.enumerated() {
//                renderEncoder?.setVertexBuffer(buffer, offset: 0, index: 0)
//                renderEncoder?.setFragmentBytes(&lineColors[index],
//                                                length: MemoryLayout<SIMD4<Float>>.stride,
//                                                index: 1)
//                renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: Int(length))
//            }

            renderEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
    }
}
