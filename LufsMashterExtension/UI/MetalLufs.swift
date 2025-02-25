//
//  MetalLufs.swift
//  LoudMashter
//
//  Created by mashen on 12/11/24.
//

import MetalKit
import Combine

var lineColors: [SIMD4<Float>] = [
    SIMD4(1.0, 1.0, 1.0, 0.35), // gray
    SIMD4(0.0, 1.0, 0.0, 1.0), // Green
    SIMD4(0.0, 0.0, 1.0, 1.0),  // Blue
    SIMD4(1.0, 1.0, 1.0, 0.15),   // White 0.25
    SIMD4(1.0, 1.0, 1.0, 1.0),
    SIMD4(1.0, 0.0, 1.0, 0.5),
    SIMD4(1.0, 0.0, 0.0, 1.0)
]

var horGrid: [Float] = [
    0.125,
    0.25,
    0.375,
    0.5,
    0.625,
    0.75,
    0.875,
]

public class MetalLufs: MTKView, MTKViewDelegate {
    let commandQueue: MTLCommandQueue!
    let vizPipelineState: MTLRenderPipelineState!
    let gridPipelineState: MTLRenderPipelineState!
    
    var vizValues: [[[Float]]] = Array(repeating: [[]], count: 5)
    
    var inVertexBuffer: MTLBuffer!
    var outVertexBuffer: MTLBuffer!
    var redVertexBuffer: MTLBuffer!
    var inPeakVertexBuffer: MTLBuffer!
    var recordIntegratedVertexBuffer: MTLBuffer!
    
    var horGridBuffer: MTLBuffer!
    var verGridBuffer: MTLBuffer!
    var targetBuffer: MTLBuffer!
    
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
    
    var target: Float
    var isRecording: Bool
    var toggleView: Bool
    
    init(frame frameRect: CGRect, target: ObservableAUParameter, isRecording: ObservableState, toggleView: ObservableState) {
        self.target = target.value
        self.isRecording = isRecording.val
        self.toggleView = toggleView.val
        let device = MTLCreateSystemDefaultDevice()
        commandQueue = device!.makeCommandQueue()
        let vizPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        let gridPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        constants.setConstantValue(&length, type: .uint, index: 0)
        
        let library = try! device?.makeDefaultLibrary(bundle: Bundle.main)
        
        let fragmentFunction = library!.makeFunction(name: "fragmentData")!
        let vertexFunction = try! library!.makeFunction(name: "vertexData", constantValues: constants)
        let gridFunction = library!.makeFunction(name: "gridData")!
        
        gridPipelineStateDescriptor.vertexFunction = gridFunction
        gridPipelineStateDescriptor.fragmentFunction = fragmentFunction
        vizPipelineStateDescriptor.vertexFunction = vertexFunction
        vizPipelineStateDescriptor.fragmentFunction = fragmentFunction
        
        gridPipelineStateDescriptor.rasterSampleCount = 1
        vizPipelineStateDescriptor.rasterSampleCount = 1
        
        let vizColorAttachment = vizPipelineStateDescriptor.colorAttachments[0]!
        vizColorAttachment.pixelFormat = .bgra8Unorm
        vizColorAttachment.isBlendingEnabled = true
        vizColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        vizColorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        vizColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        vizColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        let gridColorAttachment = gridPipelineStateDescriptor.colorAttachments[0]!
        gridColorAttachment.pixelFormat = .bgra8Unorm
        gridColorAttachment.isBlendingEnabled = true
        gridColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        gridColorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        gridColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        gridColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        vizPipelineState = try! device!.makeRenderPipelineState(descriptor: vizPipelineStateDescriptor)
        gridPipelineState = try! device!.makeRenderPipelineState(descriptor: gridPipelineStateDescriptor)
        
        super.init(frame: frameRect, device: device)
        
        horGridBuffer = device!.makeBuffer(bytes: horGrid, length: horGrid.count * MemoryLayout<Float>.size, options: [])
        
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
        let recordIntegratedVertexData: [[Float]] = vizValues[3]
//        let inPeakVertexData: [[Float]] = vizValues[3]
//        let outPeakVertexData: [[Float]] = vizValues[3]
//        let peakRedVertexData: [[Float]] = vizValues[3]
        
        inVertexBuffer = device!.makeBuffer(bytes: inVertexData[0], length: inVertexData[0].count * MemoryLayout<Float>.size, options: [])
        outVertexBuffer = device!.makeBuffer(bytes: outVertexData[0], length: outVertexData[0].count * MemoryLayout<Float>.size, options: [])
        
//        inPeakVertexBuffer = device!.makeBuffer(bytes: inPeakVertexData[0], length: inPeakVertexData[0].count * MemoryLayout<Float>.size, options: [])
        redVertexBuffer = device!.makeBuffer(bytes: redVertexData[0], length: redVertexData[0].count * MemoryLayout<Float>.size, options: [])
        recordIntegratedVertexBuffer  = device!.makeBuffer(bytes: recordIntegratedVertexData[0], length: recordIntegratedVertexData[0].count * MemoryLayout<Float>.size, options: [])
        
    }
    
    func updateTarget() {
        targetBuffer = device!.makeBuffer(bytes: [target], length: 1 * MemoryLayout<Float>.size, options: [])
    }
    
    public func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        // We may want to resize the texture.
    }
    
    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let vizPipelineState = vizPipelineState,
              let gridPipelineState = gridPipelineState,
              let commandQueue = commandQueue
        else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        
        renderEncoder?.setRenderPipelineState(gridPipelineState)
        
        renderEncoder?.setVertexBuffer(horGridBuffer, offset: 0, index: 0)
        renderEncoder?.setFragmentBytes(&lineColors[3],
                                        length: MemoryLayout<SIMD4<Float>>.stride,
                                        index: 1)
        renderEncoder?.drawPrimitives(type: .line, vertexStart: 0, vertexCount: horGrid.count * 2)
        
//        if (toggleView) {
            renderEncoder?.setVertexBuffer(targetBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentBytes(&lineColors[4],
                                            length: MemoryLayout<SIMD4<Float>>.stride,
                                            index: 1)
            renderEncoder?.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2)
            
            
            renderEncoder?.setRenderPipelineState(vizPipelineState)
            
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
            renderEncoder?.setVertexBuffer(recordIntegratedVertexBuffer, offset: 0, index: 0)
            renderEncoder?.setFragmentBytes(&lineColors[6],
                                            length: MemoryLayout<SIMD4<Float>>.stride,
                                            index: 1)
            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
//        } else {
//            renderEncoder?.setVertexBuffer(threshBuffer, offset: 0, index: 0)
//            renderEncoder?.setFragmentBytes(&lineColors[4],
//                                            length: MemoryLayout<SIMD4<Float>>.stride,
//                                            index: 1)
//            renderEncoder?.drawPrimitives(type: .line, vertexStart: 0, vertexCount: 2)
//            
//            renderEncoder?.setVertexBuffer(inPeakVertexBuffer, offset: 0, index: 0)
//            renderEncoder?.setFragmentBytes(&lineColors[5],
//                                            length: MemoryLayout<SIMD4<Float>>.stride,
//                                            index: 1)
//            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
//            
//            renderEncoder?.setVertexBuffer(outPeakVertexBuffer, offset: 0, index: 0)
//            renderEncoder?.setFragmentBytes(&lineColors[1],
//                                            length: MemoryLayout<SIMD4<Float>>.stride,
//                                            index: 1)
//            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
//            
//            renderEncoder?.setVertexBuffer(peakRedVertexBuffer, offset: 0, index: 0)
//            renderEncoder?.setFragmentBytes(&lineColors[2],
//                                            length: MemoryLayout<SIMD4<Float>>.stride,
//                                            index: 1)
//            renderEncoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: 1024)
//        }
        renderEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
