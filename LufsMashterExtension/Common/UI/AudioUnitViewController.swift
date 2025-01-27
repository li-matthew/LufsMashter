//
//  AudioUnitViewController.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import Combine
import CoreAudioKit
import os
import SwiftUI

class ObservableBuffers: ObservableObject {
    @Published var buffers: [[[Float]]]
    
    init() {
        buffers = Array(repeating: Array(repeating: Array(repeating: 0.0, count: 1024), count: 2), count: 4)
    }
}

class ObservableVals: ObservableObject {
    @Published var vals: [Float]
    
    init() {
        vals = Array(repeating: 0.0, count: 8)
    }
}

class ObservableState: ObservableObject {
    @Published var val: Bool {
        didSet {
            updateAction?(val)
        }
    }

    var updateAction: ((Bool) -> Void)? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateAction?(self?.val ?? false)
            }
        }
    }

    init(initialValue: Bool = false) {
        self.val = initialValue
    }
    
    public func update(state: Bool) {
        if state != val {  // Prevent redundant updates
            self.val = state
        }
    }
}

private let log = Logger(subsystem: "mash.LufsMashterExtension", category: "AudioUnitViewController")

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var vizBuffers: ObservableBuffers = ObservableBuffers()
    
    var lufsVals: ObservableVals = ObservableVals()
    var tpVals: ObservableVals = ObservableVals()
    
    var softClipOn: ObservableState = ObservableState()
    var hardClipOn: ObservableState = ObservableState()
    var isRecording: ObservableState = ObservableState()
    var isReset: ObservableState = ObservableState()
    var toggleView: ObservableState = ObservableState()
    
    var audioUnit: AUAudioUnit?
    var timer: Timer?
    
    var hostingController: HostingController<LufsMashterExtensionMainView>?
    
    private var bufferSubject = CurrentValueSubject<[[[Float]]], Never>([[[]]])
    private var valSubject = CurrentValueSubject<[Float], Never>([])
    
    
    private var observation: NSKeyValueObservation?
    
    /* iOS View lifcycle
     public override func viewWillAppear(_ animated: Bool) {
     super.viewWillAppear(animated)
     
     // Recreate any view related resources here..
     }
     
     public override func viewDidDisappear(_ animated: Bool) {
     super.viewDidDisappear(animated)
     
     // Destroy any view related content here..
     }
     */
    
    /* macOS View lifcycle
     public override func viewWillAppear() {
     super.viewWillAppear()
     
     // Recreate any view related resources here..
     }
     
     public override func viewDidDisappear() {
     super.viewDidDisappear()
     
     // Destroy any view related content here..
     }
     */
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            if let self = self {
                Task { @MainActor in
                    if (self.toggleView.val) {
                        self.updateLufsBuffers()
                    } else {
                        self.updateTpBuffers()
                    }
                    
                    self.updateLufsVals()
                    self.updateTpVals()
                    
                    if (self.isReset.val) {
                        self.isReset.update(state: self.getIsReset())
                    }
                }
            }
        }
    }
 
    public func updateLufsBuffers() {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
        let buffers = [[audioUnit.getInLuffers()], [audioUnit.getOutLuffers()], [audioUnit.getGainReduction()], [audioUnit.getRecordIntegrated()]]
        bufferSubject.send(buffers)
        vizBuffers.buffers = buffers
    }
    public func updateTpBuffers() {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
        let buffers = [[audioUnit.getInPeaks()], [audioUnit.getOutPeaks()], [audioUnit.getPeakReduction()], [audioUnit.getRecordIntegrated()]]
        bufferSubject.send(buffers)
        vizBuffers.buffers = buffers
    }
    
    public func updateLufsVals() {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
        let vals = [audioUnit.getCurrIn(), audioUnit.getCurrOut(), audioUnit.getCurrRed(), audioUnit.getCurrIntegrated()]
        valSubject.send(vals)
        lufsVals.vals = vals
    }
    
    public func updateTpVals() {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
        let vals = [audioUnit.getCurrPeakIn(), audioUnit.getCurrPeakOut(), audioUnit.getCurrPeakRed(), audioUnit.getCurrPeakMax()]
        valSubject.send(vals)
        tpVals.vals = vals
    }
    
    public func updateIsRecording(state: Bool) {
        Task { @MainActor in
            guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
            audioUnit.setIsRecording(recording: state)
        }
    }
    
    public func updateIsReset(state: Bool) {
        Task { @MainActor in
            guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
            
            audioUnit.setIsReset(reset: state)
        }
    }
    
    public func getIsReset() -> Bool {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return false }
        return audioUnit.getIsReset()
    }
    
    public func updateSoftClipOn(state: Bool) {
        Task { @MainActor in
            guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
            audioUnit.setSoftClipOn(state: state)
        }
    }
    
    public func updateHardClipOn(state: Bool) {
        Task { @MainActor in
            guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
            audioUnit.setHardClipOn(state: state)
        }
    }
    
    public func updateActions() {
        isRecording.updateAction = { state in
            self.updateIsRecording(state: state)
        }
        isReset.updateAction = { state in
            self.updateIsReset(state: state)
        }
        
        softClipOn.updateAction = { state in
            self.updateSoftClipOn(state: state)
        }
        hardClipOn.updateAction = { state in
            self.updateHardClipOn(state: state)
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Accessing the `audioUnit` parameter prompts the AU to be created via createAudioUnit(with:)
        self.view.frame = CGRect(x: 0, y: 0, width: 1100, height: 700)
        guard let audioUnit = self.audioUnit else {
            return
        }
        
        configureSwiftUIView(audioUnit: audioUnit)
        updateActions()
        startTimer()
    }
    
    nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        return try DispatchQueue.main.sync {
            
            audioUnit = try LufsMashterExtensionAudioUnit(componentDescription: componentDescription, options: [])
            
            guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else {
                log.error("Unable to create LufsMashterExtensionAudioUnit")
                return audioUnit!
            }
            
            defer {
                
                // Configure the SwiftUI view after creating the AU, instead of in viewDidLoad,
                // so that the parameter tree is set up before we build our @AUParameterUI properties
                DispatchQueue.main.async {
                    self.configureSwiftUIView(audioUnit: audioUnit)
                    self.updateActions()
                    self.startTimer()
                }
            }
            
            audioUnit.setupParameterTree(LufsMashterExtensionParameterSpecs.createAUParameterTree())
            
            self.observation = audioUnit.observe(\.allParameterValues, options: [.new]) { object, change in
                guard let tree = audioUnit.parameterTree else { return }
                
                // This insures the Audio Unit gets initial values from the host.
                for param in tree.allParameters { param.value = param.value }
            }
            
            guard audioUnit.parameterTree != nil else {
                log.error("Unable to access AU ParameterTree")
                return audioUnit
            }
            
            return audioUnit
        }
    }
    
    private func configureSwiftUIView(audioUnit: AUAudioUnit) {
        if let host = hostingController {
            host.removeFromParent()
            host.view.removeFromSuperview()
        }
        
        guard let observableParameterTree = audioUnit.observableParameterTree else {
            return
        }
        
        
        let content = LufsMashterExtensionMainView(parameterTree: observableParameterTree, vizBuffers: vizBuffers, lufsVals: lufsVals, tpVals: tpVals, softClipOn: softClipOn, hardClipOn: hardClipOn, isRecording: isRecording, isReset: isReset, toggleView: toggleView)
        let host = HostingController(rootView: content)
        self.addChild(host)
        host.view.frame = self.view.bounds

        self.view.addSubview(host.view)
        hostingController = host
        
        // Make sure the SwiftUI view fills the full area provided by the view controller
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        self.view.bringSubviewToFront(host.view)
    }
    
}
