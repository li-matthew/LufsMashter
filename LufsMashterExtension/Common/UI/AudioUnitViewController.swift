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

class ObservableLufsBuffer: ObservableObject {
    @Published var buffer: [[Float]]
    
    init() {
        buffer = Array(repeating: Array(repeating: 0.0, count: 1024), count: 2)
    }
}

private let log = Logger(subsystem: "mash.LufsMashterExtension", category: "AudioUnitViewController")

@MainActor
public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var luffers: ObservableLufsBuffer = ObservableLufsBuffer()
    var audioUnit: AUAudioUnit?
    var timer: Timer?
    
    var hostingController: HostingController<LufsMashterExtensionMainView>?
    
    private var bufferSubject = CurrentValueSubject<[[Float]], Never>([[]])
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
            Task { @MainActor in
                self?.updateLufsBuffer()
            }
        }
    }
    
    public func updateLufsBuffer() {
        guard let audioUnit = self.audioUnit as? LufsMashterExtensionAudioUnit else { return }
        let buffer = audioUnit.getLufsBuffer()
        bufferSubject.send(buffer)
        luffers.buffer = buffer
    }

    deinit {
        timer?.invalidate()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        // Accessing the `audioUnit` parameter prompts the AU to be created via createAudioUnit(with:)
        
        guard let audioUnit = self.audioUnit else {
            return
        }
        
        configureSwiftUIView(audioUnit: audioUnit)
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
        
        
        let content = LufsMashterExtensionMainView(parameterTree: observableParameterTree, luffers: luffers)
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
