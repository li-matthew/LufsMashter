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

- (NSArray<NSNumber*>*)getInPeaks {
    const float* buffer = _processHelper->getInPeaks();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getOutPeaks {
    const float* buffer = _processHelper->getOutPeaks();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getPeakReduction {
    const float* buffer = _processHelper->getPeakReduction();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSNumber*)getCurrPeakIn {
    const float& val = _processHelper->getCurrPeakIn();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

- (NSNumber*)getCurrPeakOut {
    const float& val = _processHelper->getCurrPeakOut();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

- (NSNumber*)getCurrPeakRed {
    const float& val = _processHelper->getCurrPeakRed();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

- (NSNumber*)getCurrPeakMax {
    const float& val = _processHelper->getCurrPeakMax();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
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

- (NSArray<NSNumber*>*)getGainReduction {
    const float* buffer = _processHelper->getGainReduction();
    
    NSMutableArray<NSNumber*>* resultBuffer = [NSMutableArray array];
        for (int i = 0; i < 1024; ++i) {
            NSNumber* sample = @(buffer[i]);  // Wrap the float sample in NSNumber
            [resultBuffer addObject:sample];  // Add NSNumber to the channel array
        }
    return [resultBuffer copy];
}

- (NSArray<NSNumber*>*)getRecordIntegrated {
    const float* buffer = _processHelper->getRecordIntegrated();
    
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

- (NSNumber*)getCurrIntegrated {
    const float& val = _processHelper->getCurrIntegrated();
    NSNumber* result = [NSNumber numberWithFloat:val];
    return result;
}

//- (BOOL)getIsRecording {
//    return _processHelper->getIsRecording();
//}

- (void)setIsRecording:(BOOL)recording {
    _processHelper->setIsRecording(recording);
}

- (BOOL)getIsReset {
    return _processHelper->getIsReset();
}

- (void)setIsReset:(BOOL)reset {
    _processHelper->setIsReset(reset);
}

- (void)setSoftClipOn:(BOOL)state {
    _processHelper->setSoftClipOn(state);
}

- (void)setHardClipOn:(BOOL)state {
    _processHelper->setHardClipOn(state);
}
@end
