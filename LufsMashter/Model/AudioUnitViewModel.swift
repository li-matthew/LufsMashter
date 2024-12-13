//
//  AudioUnitViewModel.swift
//  LufsMashter
//
//  Created by mashen on 12/12/24.
//

import SwiftUI
import AudioToolbox
internal import CoreAudioKit

struct AudioUnitViewModel {
    var showAudioControls: Bool = false
    var showMIDIContols: Bool = false
    var title: String = "-"
    var message: String = "No Audio Unit loaded.."
    var viewController: ViewController?
}
