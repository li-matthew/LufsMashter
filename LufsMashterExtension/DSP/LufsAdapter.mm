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

- (NSArray<NSNumber*>*)getInLuffers {
    const float* buffer = _processHelper->getInLuffers();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getOutLuffers {
    const float* buffer = _processHelper->getOutLuffers();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSArray<NSNumber*>*>*)getInPeaks {
    const std::vector<float*>& buffer = _processHelper->getInPeaks();
    
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
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getRecordAverage {
    const float* buffer = _processHelper->getRecordAverage();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
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

- (BOOL)getIsRecording {
    return _processHelper->getIsRecording();
}

- (void)setIsRecording:(BOOL)recording {
    _processHelper->setIsRecording(recording);
}

- (BOOL)getIsReset {
    return _processHelper->getIsReset();
}

- (void)setIsReset:(BOOL)reset {
    _processHelper->setIsReset(reset);
}
@end
