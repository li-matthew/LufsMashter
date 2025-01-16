//
//  LufsMashterExtensionParameterAddresses.h
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

#pragma once

#include <AudioToolbox/AUParameters.h>

typedef NS_ENUM(AUParameterAddress, LufsMashterExtensionParameterAddress) {
    osfactor = 0,
    filtersize = 1,
    thresh = 2,
    attack = 3,
    release = 4,
    target = 5
//    knee = 4
};
