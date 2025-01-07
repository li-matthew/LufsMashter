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
- (NSArray<NSArray<NSNumber*>*>*)getInLuffers;
- (NSArray<NSArray<NSNumber*>*>*)getOutLuffers;
- (NSArray<NSArray<NSNumber*>*>*)getInPeaks;
- (NSArray<NSNumber*>*)getGainReduction;
- (NSNumber*)getCurrIn;
- (NSNumber*)getCurrOut;
- (NSNumber*)getCurrRed;
@end
