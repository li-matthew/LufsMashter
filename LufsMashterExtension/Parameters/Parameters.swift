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
        ParameterSpec(
            address: .dbs,
            identifier: "dbs",
            name: "dBs",
            units: .generic,
            valueRange: 0.0...0.5,
            defaultValue: 0.1
        )
        ParameterSpec(
            address: .sens,
            identifier: "sens",
            name: "sens",
            units: .generic,
            valueRange: 0.01...1.0,
            defaultValue: 0.5
        )
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
