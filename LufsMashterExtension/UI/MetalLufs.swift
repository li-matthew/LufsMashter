//
//  DataPlot.swift
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

import MetalKit
import Combine

public class MetalLufs: MTKView, MTKViewDelegate {
    let commandQueue: MTLCommandQueue!
    let pipelineState: MTLRenderPipelineState!
    
    var LufsValues: [[Float]] = [[]]
    var vertexBuffer: MTLBuffer!
    
    let constants = MTLFunctionConstantValues()
    var length: UInt32 = 1024
    
    private var cancellables: Set<AnyCancellable> = []
    
    var metalView: ObservableLufsBuffer? {
        didSet {
            // Subscribe to updates from the ViewModel
            metalView?.$buffer
                .sink { [weak self] newData in
                    self?.LufsValues = newData
                    self?.updateVertexBuffer()
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
        
        updateVertexBuffer()
        
        clearColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0)

        delegate = self
    }
    
    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateVertexBuffer() {
        let vertexData: [[Float]] = LufsValues
        
        vertexBuffer = device!.makeBuffer(bytes: vertexData[0], length: vertexData[0].count * MemoryLayout<Float>.size, options: [])
    }
    
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        // We may want to resize the texture.
    }
    
    public func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let pipelineState = pipelineState,
                  let commandQueue = commandQueue,
                  let vertexBuffer = vertexBuffer else {
                return
            }

            let commandBuffer = commandQueue.makeCommandBuffer()
            let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

            renderEncoder?.setRenderPipelineState(pipelineState)
            renderEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
            renderEncoder?.endEncoding()
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
    }
}
