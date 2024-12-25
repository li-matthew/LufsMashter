//
//  LufsMashterExtensionDSPKernel.hpp
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
#import <algorithm>
#import <vector>
#import <span>

#import <Accelerate/Accelerate.h>

//#import "LufsAdapter.hpp"
#import "LufsMashterExtensionParameterAddresses.h"


/*
 LufsMashterExtensionDSPKernel
 As a non-ObjC class, this is safe to use from render thread.
 */

struct Biquad {
    vDSP_biquad_Setup setup;
    float delay[2 + (2 * 2)]; // 2 + (2 * stages)
};

class LufsMashterExtensionDSPKernel {
public:
    
    void initialize(int inputChannelCount, int outputChannelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
        
        for (int i = 0; i < inputChannelCount; i++) {
            biquads.push_back((Biquad){
                .setup = vDSP_biquad_CreateSetup(Coeffs, stages)
            });
            
            for (int j = 0; j < 4; j++) {
                biquads[i].delay[j] = 0.0;
            }
        }
    }
    
    void deInitialize() {
    }
    
    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }
    
    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }
    
    // MARK: - Parameter Getter / Setter
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case LufsMashterExtensionParameterAddress::dbs:
                mDbs = value;
                break;
                // Add a case for each parameter in LufsMashterExtensionParameterAddresses.h
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
            case LufsMashterExtensionParameterAddress::dbs:
                return (AUValue)mDbs;
                
            default: return 0.f;
        }
    }
    
    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }
    
    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }
    
    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }
    
    /**
     MARK: - Internal Process
     
     This function does the core siginal processing.
     Do your custom DSP here.
     */
    void process(std::span<float*> gainReduction, std::span<float*>lufsFrame, std::span<float*> inLuffers, std::span<float*> outLuffers,  std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        /*
         Note: For an Audio Unit with 'n' input channels to 'n' output channels, remove the assert below and
         modify the check in [LufsMashterExtensionAudioUnit allocateRenderResourcesAndReturnError]
         */
        assert(inputBuffers.size() == outputBuffers.size());
        
        if (mBypassed) {
            // Pass the samples through
            for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
                std::copy_n(inputBuffers[channel], frameCount, outputBuffers[channel]);
            }
            return;
        }
        
        // Use this to get Musical context info from the Plugin Host,
        // Replace nullptr with &memberVariable according to the AUHostMusicalContextBlock function signature
        /*
         if (mMusicalContextBlock) {
         mMusicalContextBlock(nullptr, 	// currentTempo
         nullptr, 	// timeSignatureNumerator
         nullptr, 	// timeSignatureDenominator
         nullptr, 	// currentBeatPosition
         nullptr, 	// sampleOffsetToNextBeat
         nullptr);	// currentMeasureDownbeatPosition
         }
         */
        
        float targetEnergy = lufsWindow * mDbs * mDbs;
        
        // Perform per sample dsp on the incoming float in before assigning it to out
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            // Do your sample by sample dsp here...
            vDSP_biquad_SetCoefficientsDouble(biquads[channel].setup, Coeffs, 0, 1);
            vDSP_biquad(biquads[channel].setup,
                                    biquads[channel].delay,
                                    inputBuffers[channel], 1,
                                    outputBuffers[channel], 1,
                                    frameCount);
            
            // Shift lufsFrame
            std::copy_backward(lufsFrame[channel], lufsFrame[channel] + (lufsWindow - frameCount), lufsFrame[channel] + lufsWindow);
   
            // Section Energies
            float energy;
            vDSP_svesq(lufsFrame[channel] + frameCount, 1, &energy, lufsWindow - frameCount);
            
            float currEnergy;
            vDSP_svesq(outputBuffers[channel], 1, &currEnergy, frameCount);
            
            float rms = sqrt((energy + currEnergy) / lufsWindow);

            // TODO
            float reduction = 1.0;
            
            LOG("PPP");
            LOG("%f", energy);
            LOG("%f", targetEnergy);
            LOG("%f", energy + currEnergy);
            
            if ((energy + currEnergy) > targetEnergy) {
                if (energy < targetEnergy) {
                    reduction = sqrt((targetEnergy - energy) / currEnergy);
                } else {
                    reduction = 0.0;
                }
            }
            
            // Add to Gain Reduction
            std::copy_backward(gainReduction[channel], gainReduction[channel] + (luffersLength - 1), gainReduction[channel] + luffersLength);
            std::memcpy(gainReduction[channel], &reduction, sizeof(float));
            
            // Add to In Luffers
            std::copy_backward(inLuffers[channel], inLuffers[channel] + (luffersLength - 1), inLuffers[channel] + luffersLength);
            std::memcpy(inLuffers[channel], &rms, sizeof(float));

            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * reduction;
            }
            
            std::memcpy(lufsFrame[channel], outputBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(lufsFrame[channel], 1, &rms, lufsWindow);
            
            std::copy_backward(outLuffers[channel], outLuffers[channel] + (luffersLength - 1), outLuffers[channel] + luffersLength);
            std::memcpy(outLuffers[channel], &rms, sizeof(float));
        }
    }
    
    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }
                
            default:
                break;
        }
    }
    
    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        // Implement handling incoming Parameter events as needed
    }
    
    // MARK: Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;
    
    //    std::vector<LufsAdapter::FilterState> filterStates;
    //    LufsAdapter::FilterCoefficients coeffs;
    //    LufsAdapter lufsAdapter;
    std::vector <Biquad> biquads;
    
    const int lufsWindow = 17640;
    const int luffersLength = 1024;
    double mSampleRate = 44100.0;
    
    double mDbs = 0.0;
    int stages = 2;
    double Coeffs[10] = {
        1.53512948,         // b
        -2.69169634,
        1.19839281,
        -1.69500495,        // a
        0.73199158,
        
        1.0,         // b
        -2.0,
        1.0,
        -1.99004745,        // a
        0.990072250
    };
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    
//    float temp[2][1024];
//    std::vector<float> temp;
    
};
