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
            case LufsMashterExtensionParameterAddress::smooth:
                mSmooth = value;
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
            case LufsMashterExtensionParameterAddress::smooth:
                return (AUValue)mSmooth;
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
    void process(float* currRed, float* currIn, float* currOut, bool* prevOverThreshold, std::span<float*> inPeaks, float* gainReduction, std::span<float*>inLufsFrame, std::span<float*>outLufsFrame, std::span<float*> inLuffers, std::span<float*> outLuffers,  std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        
        startTime = std::chrono::high_resolution_clock::now();
        
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
        std::vector<float*> tempBuffers;
        tempBuffers.resize(2);
        
        float target =  pow(10, ((mTarget * 60) - 60) / 20);

        float targetEnergy = lufsWindow * target * target;
        
        float attack = 1.0 / (44.1 * mAttack);
        float release = 1.0 / (44.1 * mRelease);
        float currReduction = *gainReduction;
        float reds[] = {1.0, 1.0};
        float finalReduction = 1.0;
        
        std::copy_backward(gainReduction, gainReduction + (vizLength - 1), gainReduction + vizLength);
        
        // Perform per sample dsp on the incoming float in before assigning it to out
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            
            float inRms;
            
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
            //            std::copy_backward(lookAhead[channel], lookAhead[channel] + (441 - frameCount), lookAhead[channel] + 441);
            std::copy_backward(inLuffers[channel], inLuffers[channel] + (vizLength - 1), inLuffers[channel] + vizLength);
            std::copy_backward(outLuffers[channel], outLuffers[channel] + (vizLength - 1), outLuffers[channel] + vizLength);
            
            std::copy_backward(inPeaks[channel], inPeaks[channel] + (vizLength - 1), inPeaks[channel] + vizLength);
            
            const int filterSize = 5;
            float filter[filterSize] = { 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize };
                
            // Output buffer for the filtered signal
            float filteredBuffer[frameCount];
                
            // Perform convolution to simulate the reconstruction (apply the FIR filter)
            vDSP_conv(tempBuffers[channel], 1, filter, 1, filteredBuffer, 1, frameCount, filterSize);
            
            // Find the maximum value in the filtered signal (True Peak)
            float truePeak = 0.0f;
            vDSP_maxmgv(filteredBuffer, 1, &truePeak, frameCount);
            
//            LOG("DDD");
//            LOG("%f", truePeak);
//            LOG("%f", 20 * log10(truePeak));
            std::memcpy(inPeaks[channel], &truePeak, sizeof(float));
//            if (truePeak > 1.0f) {
//                float peakReduction = 1.0f / truePeak;
//                vDSP_vsmul(tempBuffers[channel], 1, &peakReduction, tempBuffers[channel], 1, frameCount);
//            }
            
            // Section Energies
            float energy;
            vDSP_svesq(outLufsFrame[channel] + frameCount, 1, &energy, lufsWindow - frameCount);
            
            float currEnergy;
            vDSP_svesq(tempBuffers[channel], 1, &currEnergy, frameCount);
            
            float reduction = 1.0;
            if (currEnergy <= 0.0f) currEnergy = 1e-6f;
            float energyDelta = 1e-6f;
            LOG("VVV");
            LOG("%d", *prevOverThreshold);
            if (!*prevOverThreshold) {
                if ((currEnergy + energy) > targetEnergy) {
                    *prevOverThreshold = true;
                    energyDelta = std::max(currEnergy + (energy - targetEnergy), 1e-6f);
//                    float reductionCurve = 1.0f - pow((excessEnergy / targetEnergy), 1.0f / mSmooth);
                    
                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);

//                    reduction = std::max(reductionCurve, 1e-6f);
//                    reduction = reductionCurve;
                    if (reduction > currReduction) {
                        reduction = currReduction - attack * reduction / currReduction * (1.0f - reduction);
                    } else {
                        reduction = currReduction - attack * (1.0f - reduction);
                    }
                } else {
                    *prevOverThreshold = false;
                    energyDelta = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
//                    reduction = 1.0f - pow(energyDelta / targetEnergy, 1.0f / mSmooth);
                    
                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
                    LOG("TTT");
                    LOG("%f", energyDelta);
                    LOG("%f", reduction);
                    reduction = std::min(reduction, 1.0f);
//                    reduction = reductionCurve;
                    if (reduction < currReduction) {
                        reduction = currReduction + release * currReduction / reduction * (1.0f - reduction);
                    } else {
                        reduction = currReduction + release * (1.0f - reduction);
                    }
//                    reduction = currReduction + release * (1.0f - reduction);
                    LOG("%f", currReduction);
                    LOG("%f", reduction);
                    
                }
            } else {
                if ((energy + currEnergy) > targetEnergy) {
                    *prevOverThreshold = true;
                    energyDelta = std::max(currEnergy + (energy - targetEnergy), 1e-6f);
//                    float reductionCurve = 1.0f - pow(excessEnergy / targetEnergy, 1.0f / mSmooth);
                    
                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);

//                    reduction = std::max(reductionCurve, 1e-6f);
//                    reduction = reductionCurve;
                    if (reduction > currReduction) {
                        reduction = currReduction - attack * currReduction / reduction * (1.0f - reduction);
                    } else {
                        reduction = currReduction - attack * (1.0f - reduction);
                    }
                    
                } else {
                    *prevOverThreshold = false;
                    energyDelta = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
//                    reduction = 1.0f - pow(energyDelta / targetEnergy, 1.0f / mSmooth);
                    
                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
                    
                    reduction = std::min(reduction, 1.0f);
//                    reduction = reductionCurve;
                    LOG("SSS");
                    LOG("%f", reduction);
                    if (reduction > currReduction) {
                        reduction = currReduction + release * currReduction / reduction * (1.0f - reduction);
                    } else {
                        reduction = currReduction + release * (1.0f - reduction);
                    }
//                    reduction = currReduction + release * (1.0f - reduction);
                    
                    LOG("%f", reduction);
                }
            }
            
            reduction = (float)std::clamp(reduction, 1e-6f, 1.0f);
            
            // Add to Gain Reduction
            reds[channel] = reduction;

            // Add to Out Luffers
            
            std::memcpy(inLufsFrame[channel], tempBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(inLufsFrame[channel], 1, &inRms, lufsWindow);
            std::memcpy(inLuffers[channel], &inRms, sizeof(float));
            
            *currIn = inRms;
        }
        
        finalReduction = std::min(reds[0], reds[1]);
        std::memcpy(gainReduction, &finalReduction, sizeof(float));
        *currRed = *gainReduction;

        float step = /*2 * */(*gainReduction - currReduction) / frameCount;
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            float outRms;
            
            
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                if (currReduction > step) {
                    currReduction += step;
                }
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * currReduction;
            }
            
            vDSP_biquad(biquadOut[channel].setup,
                                    biquadOut[channel].delay,
                                    outputBuffers[channel], 1,
                                    tempBuffers[channel], 1,
                                    frameCount);
//            float truePeak;
//            vDSP_maxmgv(tempBuffers[channel], 1, &truePeak, frameCount);
//            LOG("DDD");
//            LOG("%f", truePeak);
//            if (truePeak > 1.0f) {
//                float peakReduction = 1.0f / truePeak;
//                vDSP_vsmul(tempBuffers[channel], 1, &peakReduction, tempBuffers[channel], 1, frameCount);
//            }
            
            std::memcpy(outLufsFrame[channel], tempBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(outLufsFrame[channel], 1, &outRms, lufsWindow);
            std::memcpy(outLuffers[channel], &outRms, sizeof(float));
            *currOut = outRms;
            
            endTime = std::chrono::high_resolution_clock::now();

            // Compute elapsed time
            auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
            double latencyInMicroseconds = duration.count() / 1000.0;
//            LOG("%f ms", latencyInMicroseconds);
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
    const int vizLength = 1024;
    double mSampleRate = 44100.0;
    
    double mTarget = 1.0;
    double mAttack = 0.5;
    double mRelease = 0.5;
    double mSmooth = 2.0;
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
