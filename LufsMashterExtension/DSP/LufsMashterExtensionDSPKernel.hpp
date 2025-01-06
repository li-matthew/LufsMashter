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
#import <chrono>

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
            biquadIn.push_back((Biquad){
                .setup = vDSP_biquad_CreateSetup(Coeffs, stages)
            });
            biquadOut.push_back((Biquad){
                .setup = vDSP_biquad_CreateSetup(Coeffs, stages)
            });
            
            for (int j = 0; j < 4; j++) {
                biquadIn[i].delay[j] = 0.0;
                biquadOut[i].delay[j] = 0.0;
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
            case LufsMashterExtensionParameterAddress::target:
                mTarget = value;
                break;
            case LufsMashterExtensionParameterAddress::attack:
                mAttack = value;
                break;
            case LufsMashterExtensionParameterAddress::release:
                mRelease = value;
                break;
            case LufsMashterExtensionParameterAddress::ratio:
                mRatio = value;
                break;
            case LufsMashterExtensionParameterAddress::knee:
                mKnee = value;
                break;
                // Add a case for each parameter in LufsMashterExtensionParameterAddresses.h
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
            case LufsMashterExtensionParameterAddress::target:
                return (AUValue)mTarget;
            case LufsMashterExtensionParameterAddress::attack:
                return (AUValue)mAttack;
            case LufsMashterExtensionParameterAddress::release:
                return (AUValue)mRelease;
            case LufsMashterExtensionParameterAddress::ratio:
                return (AUValue)mRatio;
            case LufsMashterExtensionParameterAddress::knee:
                return (AUValue)mKnee;
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
    void process(float* currRed, float* currIn, float* currOut, bool* prevOverThreshold, std::span<float*> lookAhead, std::span<float*> gainReduction, std::span<float*>inLufsFrame, std::span<float*>outLufsFrame, std::span<float*> inLuffers, std::span<float*> outLuffers,  std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        
        startTime = std::chrono::high_resolution_clock::now();
        /*
         Note: For an Audio Unit with 'n' input channels to 'n' output channels, remove the assert below and
         modify the check in [LufsMashterExtensionAudioUnit allocateRenderResourcesAndReturnError]
         */
        
        std::vector<float*> tempBuffers;
        tempBuffers.resize(2);
        
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
//        float targetVal = pow(10.0, mTarget / 20.0);
//        float targetDb = 20 * log10(mTarget);
//        float targetGain = pow(10.0, targetDb / 20.0);
        float targetEnergy = lufsWindow * mTarget * mTarget;
        
        float attack = mAttack;
        float release = mRelease;

        
        // Perform per sample dsp on the incoming float in before assigning it to out
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            float currReduction = *gainReduction[channel];
            float inRms;
            float outRms;
            
            if (!tempBuffers[channel]) {
                tempBuffers[channel] = new float[frameCount];
            }
            LOG("PPP");
            
            // Do your sample by sample dsp here...
            vDSP_biquad_SetCoefficientsDouble(biquadIn[channel].setup, Coeffs, 0, 1);
            vDSP_biquad_SetCoefficientsDouble(biquadOut[channel].setup, Coeffs, 0, 1);
            
            vDSP_biquad(biquadIn[channel].setup,
                                    biquadIn[channel].delay,
                                    inputBuffers[channel], 1,
                                    tempBuffers[channel], 1,
                                    frameCount);

            // Shift lufsFrame
            std::copy_backward(outLufsFrame[channel], outLufsFrame[channel] + (lufsWindow - frameCount), outLufsFrame[channel] + lufsWindow);
            std::copy_backward(inLufsFrame[channel], inLufsFrame[channel] + (lufsWindow - frameCount), inLufsFrame[channel] + lufsWindow);
            std::copy_backward(gainReduction[channel], gainReduction[channel] + (luffersLength - 1), gainReduction[channel] + luffersLength);
//            std::copy_backward(lookAhead[channel], lookAhead[channel] + (441 - frameCount), lookAhead[channel] + 441);
            std::copy_backward(inLuffers[channel], inLuffers[channel] + (luffersLength - 1), inLuffers[channel] + luffersLength);
            std::copy_backward(outLuffers[channel], outLuffers[channel] + (luffersLength - 1), outLuffers[channel] + luffersLength);
        
            // Section Energies
            float energy;
            vDSP_svesq(outLufsFrame[channel] + frameCount, 1, &energy, lufsWindow - frameCount);
            
            float currEnergy;
            vDSP_svesq(tempBuffers[channel], 1, &currEnergy, frameCount);
            LOG("%f", mRatio);
            // TODO
            float reduction = 1.0;
            if (currEnergy <= 0.0f) currEnergy = 1e-6f;
            if (!*prevOverThreshold) {
                if ((currEnergy + energy) > targetEnergy) {
                    *prevOverThreshold = true;
                    float excessEnergy = std::max(currEnergy + (energy - targetEnergy), 1e-6f);

                    // Custom power curve for reduction
                    float reductionCurve = pow(excessEnergy / targetEnergy, 1.0f / mRatio);

                    reduction = reductionCurve;
                    reduction = currReduction - attack * (reduction - currReduction);
//                    reduction = (1.0f - attack) * currReduction - attack * reduction;
                } else {
                    float missingEnergy = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
                    float reductionCurve = pow(missingEnergy / targetEnergy, 1.0f / mRatio);
                    reduction = reductionCurve;
//                    reduction = *gainReduction[channel] + ((1.0f - *gainReduction[channel])); // Smooth release
                    reduction = currReduction + release * (reductionCurve - currReduction);
//                    reduction = (1.0f - release) * currReduction + release * reduction;
                }
            } else {
                if ((energy + currEnergy) > targetEnergy) {
                    float excessEnergy = std::max(currEnergy + (energy - targetEnergy), 1e-6f);

                    float reductionCurve = pow(excessEnergy / targetEnergy, 1.0f / mRatio);
                    
                    reduction = reductionCurve;
                    reduction = currReduction - attack * (reduction - currReduction);
//                    reduction = (1.0f - attack) * currReduction - attack * reduction;
                } else {
                    *prevOverThreshold = false;
                    float missingEnergy = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
                    float reductionCurve = pow(missingEnergy / targetEnergy, 1.0f / mRatio);
                    reduction = reductionCurve;
//                    reduction = *gainReduction[channel] + ((1.0f - *gainReduction[channel])); // Smooth release
                    reduction = currReduction + release * (reduction - currReduction);
//                    reduction = (1.0f - release) * currReduction + release * reduction;
                }
            }
            
            reduction = (float)std::clamp(reduction, 1e-6f, 1.0f);
            
            // Add to Gain Reduction
            std::memcpy(gainReduction[channel], &reduction, sizeof(float));
            
            // Add to Out Luffers
            
            std::memcpy(inLufsFrame[channel], tempBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(inLufsFrame[channel], 1, &inRms, lufsWindow);
            std::memcpy(inLuffers[channel], &inRms, sizeof(float));
            
            *currIn = inRms;
            *currRed = *gainReduction[channel];
            
            float step = (*gainReduction[channel] - currReduction) / frameCount;
            
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                currReduction += step;
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * currReduction;
            }
            
            vDSP_biquad(biquadOut[channel].setup,
                                    biquadOut[channel].delay,
                                    outputBuffers[channel], 1,
                                    tempBuffers[channel], 1,
                                    frameCount);
            
            std::memcpy(outLufsFrame[channel], tempBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(outLufsFrame[channel], 1, &outRms, lufsWindow);
            std::memcpy(outLuffers[channel], &outRms, sizeof(float));
            *currOut = outRms;
            
            endTime = std::chrono::high_resolution_clock::now();

            // Compute elapsed time
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
            double latencyInMicroseconds = duration.count() / 1000.0;
            LOG("%f ms", latencyInMicroseconds);
           
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
    std::vector <Biquad> biquadIn;
    std::vector <Biquad> biquadOut;
    
//    const int lufsWindow = 17640;
    const int lufsWindow = 132300;
    const int luffersLength = 1024;
    double mSampleRate = 44100.0;
    
    double mTarget = 1.0;
    double mAttack = 0.5;
    double mRelease = 0.5;
    double mRatio = 2.0;
    double mKnee = 12.0;
    
    int stages = 2;
    double Coeffs[10] = {
        1.53512948,         // b
        -2.69169634,
        1.19839281,
        -1.69500495,        // a
        0.73199158,
        
        1.0,                // b
        -2.0,
        1.0,
        -1.99004745,        // a
        0.990072250
    };
    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
    std::chrono::high_resolution_clock::time_point startTime;
    std::chrono::high_resolution_clock::time_point endTime;
};
