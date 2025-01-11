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
- (NSArray<NSNumber*>*)getInLuffers;
- (NSArray<NSNumber*>*)getOutLuffers;
- (NSArray<NSArray<NSNumber*>*>*)getInPeaks;
- (NSArray<NSNumber*>*)getGainReduction;
- (NSArray<NSNumber*>*)getRecordAverage;
- (NSNumber*)getCurrIn;
- (NSNumber*)getCurrOut;
- (NSNumber*)getCurrRed;
- (BOOL)getIsRecording;
- (void)setIsRecording:(BOOL)recording;
- (BOOL)getIsReset;
- (void)setIsReset:(BOOL)reset;
@end
