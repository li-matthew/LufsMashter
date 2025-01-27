//
//  Parameters.swift
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

import Foundation
import AudioToolbox

let LufsMashterExtensionParameterSpecs = ParameterTreeSpec {
    ParameterGroupSpec(identifier: "global", name: "Global") {
//        ParameterSpec(
//            address: .lookahead,
//            identifier: "lookahead",
//            name: "lookahead",
//            units: .generic,
//            valueRange: 0.001...1.0,
//            defaultValue: 1.0
//        )
        ParameterSpec(
            address: .osfactor,
            identifier: "osfactor",
            name: "osfactor",
            units: .generic,
            valueRange: 0.0...3.0,
            defaultValue: 1.0
        )
        ParameterSpec(
            address: .filtersize,
            identifier: "filtersize",
            name: "filtersize",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 0.1
        )
        ParameterSpec(
            address: .thresh,
            identifier: "thresh",
            name: "thresh",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 1.0
        )
        ParameterSpec(
            address: .attack,
            identifier: "attack",
            name: "attack",
            units: .generic,
            valueRange: 0.001...1.0,
            defaultValue: 0.05
        )
        ParameterSpec(
            address: .release,
            identifier: "release",
            name: "release",
            units: .generic,
            valueRange: 0.001...1.0,
            defaultValue: 0.05
        )
        ParameterSpec(
            address: .target,
            identifier: "target",
            name: "target",
            units: .generic,
            valueRange: 0.0...1.0,
            defaultValue: 1.0
        )
//
//        ParameterSpec(
//            address: .knee,
//            identifier: "knee",
//            name: "knee",
//            units: .generic,
//            valueRange: 1.0...25.0,
//            defaultValue: 15.0
//        )
    }
}

extension ParameterSpec {
    init(
        address: LufsMashterExtensionParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [AudioUnitParameterOptions.flag_IsWritable, AudioUnitParameterOptions.flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.init(address: address.rawValue,
                  identifier: identifier,
                  name: name,
                  units: units,
                  valueRange: valueRange,
                  defaultValue: defaultValue,
                  unitName: unitName,
                  flags: flags,
                  valueStrings: valueStrings,
                  dependentParameters: dependentParameters)
    }
}
