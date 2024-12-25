//
//  LufsMashterExtensionAUProcessHelper.hpp
//  LufsMashterExtension
//
//  Created by mashen on 12/12/24.
//

#pragma once

#ifdef __OBJC__
    // If compiling with Objective-C++, we can use os_log
    #import <os/log.h>
    #define LOG(fmt, ...) os_log(OS_LOG_DEFAULT, "[DSP LOG] " fmt, ##__VA_ARGS__)
#else
    // If compiling in pure C++, use std::cout as fallback
    #include <iostream>
    #define LOG(fmt, ...) std::cout << "[DSP LOG] " << fmt << std::endl
#endif

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <algorithm>

#include <vector>
#include "LufsMashterExtensionDSPKernel.hpp"
#include "LufsMashterExtensionBufferedAudioBus.hpp"
//#include "LufsAdapter.hpp"

//MARK:- AUProcessHelper Utility Class
class AUProcessHelper
{
public:
    AUProcessHelper(LufsMashterExtensionDSPKernel& kernel, BufferedInputBus& bufferedInputBus)
    : mKernel{kernel},
    mBufferedInputBus(bufferedInputBus)
    {
    }

    const std::vector<float*>& getInLuffers() const {
        return mInLuffers;
    }
    
    const std::vector<float*>& getGainReduction() const {
        return mGainReduction;
    }
    
    const std::vector<float*>& getOutLuffers() const {
        return mOutLuffers;
    }

    void setChannelCount(UInt32 inputChannelCount, UInt32 outputChannelCount)
    {
        mInputBuffers.resize(inputChannelCount);
        mOutputBuffers.resize(outputChannelCount);
        mLufsFrame.resize(inputChannelCount);
        mInLuffers.resize(inputChannelCount);
        mOutLuffers.resize(inputChannelCount);
        mGainReduction.resize(inputChannelCount);
        
        for (int channel = 0; channel < inputChannelCount; ++channel) {
            mLufsFrame[channel] = new float[17640];
            mInLuffers[channel] = new float[1024];
            mOutLuffers[channel] = new float[1024];
            mGainReduction[channel] = new float[1024];
        }
    }

    /**
     This function handles the event list processing and rendering loop for you.
     Call it inside your internalRenderBlock.
     */
    void processWithEvents(AudioBufferList* inBufferList, AudioBufferList* outBufferList, AudioTimeStamp const *timestamp, AUAudioFrameCount frameCount, AURenderEvent const *events) {

        AUEventSampleTime now = AUEventSampleTime(timestamp->mSampleTime);
        AUAudioFrameCount framesRemaining = frameCount;
        AURenderEvent const *nextEvent = events; // events is a linked list, at the beginning, the nextEvent is the first event

        auto callProcess = [this] (AudioBufferList* inBufferListPtr, AudioBufferList* outBufferListPtr, AUEventSampleTime now, AUAudioFrameCount frameCount, AUAudioFrameCount const frameOffset) {
            for (int channel = 0; channel < inBufferListPtr->mNumberBuffers; ++channel) {
                mInputBuffers[channel] = (const float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
            }
            
            for (int channel = 0; channel < outBufferListPtr->mNumberBuffers; ++channel) {
                mOutputBuffers[channel] = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
            }

            mKernel.process(mGainReduction, mLufsFrame, mInLuffers, mOutLuffers, mInputBuffers, mOutputBuffers, now, frameCount);
        };
        
        while (framesRemaining > 0) {
            // If there are no more events, we can process the entire remaining segment and exit.
            if (nextEvent == nullptr) {
                AUAudioFrameCount const frameOffset = frameCount - framesRemaining;
                callProcess(inBufferList, outBufferList, now, framesRemaining, frameOffset);
                return;
            }

            // **** start late events late.
            auto timeZero = AUEventSampleTime(0);
            auto headEventTime = nextEvent->head.eventSampleTime;
            AUAudioFrameCount framesThisSegment = AUAudioFrameCount(std::max(timeZero, headEventTime - now));

            // Compute everything before the next event.
            if (framesThisSegment > 0) {
                AUAudioFrameCount const frameOffset = frameCount - framesRemaining;

                callProcess(inBufferList, outBufferList, now, framesThisSegment, frameOffset);

                // Advance frames.
                framesRemaining -= framesThisSegment;

                // Advance time.
                now += AUEventSampleTime(framesThisSegment);
            }

            nextEvent = performAllSimultaneousEvents(now, nextEvent);
        }
    }

    AURenderEvent const * performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const *event) {
        do {
            mKernel.handleOneEvent(now, event);
            
            // Go to next event.
            event = event->head.next;

            // While event is not null and is simultaneous (or late).
        } while (event && event->head.eventSampleTime <= now);
        return event;
    }
    
    // Block which subclassers must provide to implement rendering.
    AUInternalRenderBlock internalRenderBlock() {
		return ^AUAudioUnitStatus(AudioUnitRenderActionFlags 				*actionFlags,
								  const AudioTimeStamp       				*timestamp,
								  AVAudioFrameCount           				frameCount,
								  NSInteger                   				outputBusNumber,
								  AudioBufferList            				*outputData,
								  const AURenderEvent        				*realtimeEventListHead,
								  AURenderPullInputBlock __unsafe_unretained pullInputBlock) {
		
			AudioUnitRenderActionFlags pullFlags = 0;
		
			if (frameCount > mKernel.maximumFramesToRender()) {
				return kAudioUnitErr_TooManyFramesToProcess;
			}
		
			AUAudioUnitStatus err = mBufferedInputBus.pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
		
			if (err != 0) { return err; }
		
			AudioBufferList *inAudioBufferList = mBufferedInputBus.mutableAudioBufferList;
		
			/*
			 Important:
			 If the caller passed non-null output pointers (outputData->mBuffers[x].mData), use those.
		 
			 If the caller passed null output buffer pointers, process in memory owned by the Audio Unit
			 and modify the (outputData->mBuffers[x].mData) pointers to point to this owned memory.
			 The Audio Unit is responsible for preserving the validity of this memory until the next call to render,
			 or deallocateRenderResources is called.
		 
			 If your algorithm cannot process in-place, you will need to preallocate an output buffer
			 and use it here.
		 
			 See the description of the canProcessInPlace property.
			 */
		
			// If passed null output buffer pointers, process in-place in the input buffer.
			AudioBufferList *outAudioBufferList = outputData;
			if (outAudioBufferList->mBuffers[0].mData == nullptr) {
				for (UInt32 i = 0; i < outAudioBufferList->mNumberBuffers; ++i) {
					outAudioBufferList->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
				}
			}
		
			processWithEvents(inAudioBufferList, outAudioBufferList, timestamp, frameCount, realtimeEventListHead);
			return noErr;
		};
	}
    
    
    
    
    
private:
    LufsMashterExtensionDSPKernel& mKernel;
    std::vector<const float*> mInputBuffers;
    std::vector<float*> mOutputBuffers;
//    std::vector<std::vector<float*>*> mLuffers;
    std::vector<float*> mLufsFrame; // samples for calculating lufs
    std::vector<float*> mInLuffers; // buffer of lufs
    std::vector<float*> mOutLuffers;
    std::vector<float*> mGainReduction;
    BufferedInputBus& mBufferedInputBus;
};
