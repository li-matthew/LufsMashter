//
//  LufsMashterExtensionAudioUnit.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import AVFoundation
import Combine

public class LufsMashterExtensionAudioUnit: AUAudioUnit, @unchecked Sendable
{
    // C++ Objects
    var kernel = LufsMashterExtensionDSPKernel()
    var processHelper: AUProcessHelper?
    var inputBus = BufferedInputBus()
    
    var adapter: LufsAdapter?
    
    private var outputBus: AUAudioUnitBus?
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!
    
    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try super.init(componentDescription: componentDescription, options: options)
        outputBus = try AUAudioUnitBus(format: format)
        outputBus?.maximumChannelCount = 2
        
        // Create the input and output busses.
        inputBus.initialize(format, 8);
        
        // Create the input and output bus arrays.
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [inputBus.bus!])
        
        // Create the input and output bus arrays.
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus!])
        
        processHelper = AUProcessHelper(&kernel, &inputBus)
        
        adapter = LufsAdapter(processHelper: &processHelper!)
    }
    
    public func getInLuffers() -> [Float] {
        guard let buffer = adapter!.getInLuffers() else {
            return []
        }
        let result: [Float] = buffer.map { (max(-60.0, min((20 * log10($0.floatValue)), 0.0)) + 60) / 60
            }
        return result
    }
    
    public func getOutLuffers() -> [Float] {
        guard let buffer = adapter!.getOutLuffers() else {
            return []
        }
        let result: [Float] = buffer.map { (max(-60.0, min((20 * log10($0.floatValue)), 0.0)) + 60) / 60
            }
        return result
    }
    
    public func getInPeaks() -> [[Float]] {
        guard let buffer = adapter!.getInPeaks() else {
            return []
        }
        let result: [[Float]] = buffer.map { row in
            row.map { (max(-60.0, min((20 * log10($0.floatValue)), 6.0)) + 60) / 66
            }
        }
        return result
    }
    
    public func getGainReduction() -> [Float] {
        guard let buffer = adapter!.getGainReduction() else {
            return []
        }
        let result: [Float] = buffer.map { $0.floatValue }
        return result
    }
    
    public func getRecordAverage() -> [Float] {
        guard let buffer = adapter!.getRecordAverage() else {
            return []
        }
        let result: [Float] = buffer.map { (max(-60.0, min((20 * log10($0.floatValue)), 0.0)) + 60) / 60 }
        return result
    }
    
    public func getCurrIn() -> Float {
        guard let val = adapter!.getCurrIn() else {
            return 1e-6
        }
        let result: Float = (max(-60.0, min((20 * log10(val.floatValue)), 0.0)) + 60) / 60/* val.floatValue*/
        
        return result
    }
    
    public func getCurrOut() -> Float {
        guard let val = adapter!.getCurrOut() else {
            return 1e-6
        }
        let result: Float = (max(-60.0, min((20 * log10(val.floatValue)), 0.0)) + 60) / 60
        
        return result
    }
    
    public func getCurrRed() -> Float {
        guard let val = adapter!.getCurrRed() else {
            return 1.0
        }
        let result: Float = val.floatValue
        
        return result
    }
    
    public func getIsRecording() -> Bool {
        guard let val = adapter?.getIsRecording() else {
            return false
        }
        
        return val
    }
    
    public func setIsRecording(recording: Bool) {
        adapter!.setIsRecording(recording)
    }
    
    public func getIsReset() -> Bool {
        guard let val = adapter?.getIsReset() else {
            return false
        }
        
        return val
    }
    
    public func setIsReset(reset: Bool) {
        adapter!.setIsReset(reset)
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override var channelCapabilities: [NSNumber] {
        get {
            return [NSNumber(value: 2), NSNumber(value: 2)]
        }
    }
    
    public override var  maximumFramesToRender: AUAudioFrameCount {
        get {
            return kernel.maximumFramesToRender()
        }
        
        set {
            kernel.setMaximumFramesToRender(newValue)
        }
    }
    
    public override var shouldBypassEffect: Bool {
        get {
            return kernel.isBypassed()
        }
        
        set {
            kernel.setBypass(newValue)
        }
    }
    
    // MARK: - Rendering
    public override var internalRenderBlock: AUInternalRenderBlock {
        return processHelper!.internalRenderBlock()
    }
    
    // Allocate resources required to render.
    // Subclassers should call the superclass implementation.
    public override func allocateRenderResources() throws {
        let inputChannelCount = self.inputBusses[0].format.channelCount
        let outputChannelCount = self.outputBusses[0].format.channelCount
        
        if outputChannelCount != inputChannelCount {
            setRenderResourcesAllocated(false)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
        }
        
        inputBus.allocateRenderResources(self.maximumFramesToRender);
        
        kernel.setMusicalContextBlock(self.musicalContextBlock)
        kernel.initialize(Int32(inputChannelCount), Int32(outputChannelCount), outputBus!.format.sampleRate)
        
        processHelper?.setChannelCount(inputChannelCount, outputChannelCount)
        
        try super.allocateRenderResources()
    }
    
    // Deallocate resources allocated in allocateRenderResourcesAndReturnError:
    // Subclassers should call the superclass implementation.
    public override func deallocateRenderResources() {
        
        // Deallocate your resources.
        kernel.deInitialize()
        
        super.deallocateRenderResources()
    }
    
    public func setupParameterTree(_ parameterTree: AUParameterTree) {
        self.parameterTree = parameterTree
        
        // Set the Parameter default values before setting up the parameter callbacks
        for param in parameterTree.allParameters {
            kernel.setParameter(param.address, param.value)
        }
        
        setupParameterCallbacks()
    }
    
    private func setupParameterCallbacks() {
        // implementorValueObserver is called when a parameter changes value.
        parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
            self?.kernel.setParameter(param.address, value)
        }
        
        // implementorValueProvider is called when the value needs to be refreshed.
        parameterTree?.implementorValueProvider = { [weak self] param in
            return self!.kernel.getParameter(param.address)
        }
        
        // A function to provide string representations of parameter values.
        parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
            guard let value = valuePtr?.pointee else {
                return "-"
            }
            return NSString.localizedStringWithFormat("%.f", value) as String
        }
    }
    
}
