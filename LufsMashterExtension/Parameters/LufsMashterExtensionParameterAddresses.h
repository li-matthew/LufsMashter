//
//  LufsMashterExtensionParameterAddresses.h
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

#pragma once

#include <AudioToolbox/AUParameters.h>

typedef NS_ENUM(AUParameterAddress, LufsMashterExtensionParameterAddress) {
    target = 0,
    attack = 1,
    release = 2,
    ratio = 3,
    knee = 4
};
