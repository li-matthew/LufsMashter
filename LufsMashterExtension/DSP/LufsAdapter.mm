//
//  LufsAdapter.mm
//  LoudMashter
//
//  Created by mashen on 12/17/24.
//

#import <Foundation/Foundation.h>
#import "LufsMashterExtensionAUProcessHelper.hpp"
#import "LufsAdapter.h"

@implementation LufsAdapter

- (instancetype)initWithProcessHelper:(AUProcessHelper*)existingProcessHelper {
    self = [super init];
    if (self) {
        _processHelper = existingProcessHelper;
    }
    return self;
}

- (NSArray<NSArray<NSNumber*>*>*)getInLuffers {
    const std::vector<float*>& buffer = _processHelper->getInLuffers();
    
    NSMutableArray<NSMutableArray<NSNumber*>*>* resultBuffer = [NSMutableArray array];
    
    for (float * channel : buffer) {
        NSMutableArray<NSNumber*>* channelBuffer = [NSMutableArray array];
        
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(channel[i]);  // Wrap the float sample in NSNumber
            [channelBuffer addObject:sample];  // Add NSNumber to the channel array
        }
        
        [resultBuffer addObject:channelBuffer];
    }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getGainReduction {
    const float* buffer = _processHelper->getGainReduction();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
    
//    for (float * channel : buffer) {
//        NSMutableArray<NSNumber*>* channelBuffer = [NSMutableArray array];
        
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
        
//        [resultBuffer addObject:channelBuffer];
//    }
    return [resultBuffer copy];
}

- (NSArray<NSArray<NSNumber*>*>*)getOutLuffers {
    const std::vector<float*>& buffer = _processHelper->getOutLuffers();
    
    NSMutableArray<NSMutableArray<NSNumber*>*>* resultBuffer = [NSMutableArray array];
    
    for (float * channel : buffer) {
        NSMutableArray<NSNumber*>* channelBuffer = [NSMutableArray array];
        
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(channel[i]);  // Wrap the float sample in NSNumber
            [channelBuffer addObject:sample];  // Add NSNumber to the channel array
        }
        
        [resultBuffer addObject:channelBuffer];
    }
    return [resultBuffer copy];
}

- (NSNumber*)getCurrIn {
    const float& val = _processHelper->getCurrIn();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

- (NSNumber*)getCurrOut {
    const float& val = _processHelper->getCurrOut();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

- (NSNumber*)getCurrRed {
    const float& val = _processHelper->getCurrRed();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

@end
