//
//  LufsAdapter.h
//  LufsMashter
//
//  Created by mashen on 12/19/24.
//

#import <AudioToolbox/AudioToolbox.h>

@interface LufsAdapter : NSObject
@property (nonatomic, readonly) AUProcessHelper * processHelper;
- (instancetype)initWithProcessHelper:(AUProcessHelper*)existingProcessHelper;
- (NSArray<NSNumber*>*)getInPeaks;
- (NSArray<NSNumber*>*)getOutPeaks;
- (NSArray<NSNumber*>*)getPeakReduction;
- (NSNumber*)getCurrPeakIn;
- (NSNumber*)getCurrPeakOut;
- (NSNumber*)getCurrPeakRed;
- (NSNumber*)getCurrPeakMax;
- (NSArray<NSNumber*>*)getInLuffers;
- (NSArray<NSNumber*>*)getOutLuffers;
- (NSArray<NSNumber*>*)getGainReduction;
- (NSArray<NSNumber*>*)getRecordIntegrated;
- (NSNumber*)getCurrIn;
- (NSNumber*)getCurrOut;
- (NSNumber*)getCurrRed;
- (NSNumber*)getCurrIntegrated;
//- (BOOL)getIsRecording;
- (void)setIsRecording:(BOOL)recording;
- (BOOL)getIsReset;
- (void)setIsReset:(BOOL)reset;
- (void)setSoftClipOn:(BOOL)state;
- (void)setHardClipOn:(BOOL)state;
@end
