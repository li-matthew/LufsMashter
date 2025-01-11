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
    void process(bool* isReset, float* recordAverage, float* recordCount, bool* isRecording, float* currAverage, float* currRed, float* currIn, float* currOut, bool* prevRecording, std::span<float*> inPeaks, float* gainReduction, std::span<float*>inLufsFrame, std::span<float*> outLufsFrame, float* inLuffers, float* outLuffers, std::span<float const*> inputBuffers, std::span<float*> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        
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
        float reduction = 1.0;
        float energyDelta = 1e-6f;
        
        float attack = 1.0f / (/*44.1 * */mAttack);
        float release = 1.0f / (/*44.1 * */mRelease);
        float prevReduction = *gainReduction;
        
        float reds[] = {1.0f, 1.0f};
        float averages[] = {0.0f, 0.0f};
        float ins[] = {0.0f, 0.0f};
        float outs[] = {0.0f, 0.0f};
        
        float finalReduction = 1.0f;
        float finalAverage = 0.0f;
        float finalIn = 0.0f;
        float finalOut = 0.0f;
        
        std::copy_backward(gainReduction, gainReduction + (vizLength - 1), gainReduction + vizLength);
        std::copy_backward(recordAverage, recordAverage + (vizLength - 1), recordAverage + vizLength);
        std::copy_backward(inLuffers, inLuffers + (vizLength - 1), inLuffers + vizLength);
        std::copy_backward(outLuffers, outLuffers + (vizLength - 1), outLuffers + vizLength);
        
        
        // Perform per sample dsp on the incoming float in before assigning it to out
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            float inRms;
            
            if (!tempBuffers[channel]) {
                tempBuffers[channel] = new float[frameCount];
            }
            
            
            // TODO: TRUE PEAK LIMITER
            std::copy_backward(inPeaks[channel], inPeaks[channel] + (vizLength - 1), inPeaks[channel] + vizLength);
            
            const int filterSize = 5;
            float filter[filterSize] = { 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize, 1.0f / filterSize };
            float filteredBuffer[frameCount];
            
            // Perform convolution to simulate the reconstruction (apply the FIR filter)
            vDSP_conv(inputBuffers[channel], 1, filter, 1, filteredBuffer, 1, frameCount, filterSize);
            
            // Find the maximum value in the filtered signal (True Peak)
            float truePeak = 0.0f;
            vDSP_maxmgv(filteredBuffer, 1, &truePeak, frameCount);
            
            std::memcpy(inPeaks[channel], &truePeak, sizeof(float));
            // END TODO
            
            
            
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
            
            // Section Energies
//            float energy;
//            vDSP_svesq(outLufsFrame[channel] + frameCount, 1, &energy, lufsWindow - frameCount);
//            
//            float currEnergy;
//            vDSP_svesq(tempBuffers[channel], 1, &currEnergy, frameCount);
            
            std::memcpy(inLufsFrame[channel], tempBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(inLufsFrame[channel], 1, &inRms, lufsWindow);
            ins[channel] = inRms;
//            std::memcpy(inLuffers[channel], &inRms, sizeof(float));
            
            
//            *currIn = inRms;
//            
            if (*isRecording) {
                LOG("ON");
                *prevRecording = true;
                LOG("%f", inRms);
                LOG("%f", *recordCount);
                LOG("%f", *currAverage);
                averages[channel] = (*currAverage * (*recordCount) + inRms) / (*recordCount + 1);
                LOG("%f", averages[channel]);
                
                if (channel == 1) {
                    *recordCount = *recordCount + 1.0f;
                }
                
                float currEnergy = lufsWindow * averages[channel] * averages[channel];
                float gainFactor = targetEnergy / currEnergy;
                LOG("%f", currEnergy);
                LOG("%f", targetEnergy);
                if (currEnergy <= 0.0f) currEnergy = 1e-6f;
                if (gainFactor < 1.0f) {
//                    reduction = log10(gainFactor + 1.0f);
//                    energyDelta = std::max(currEnergy - targetEnergy, 1e-6f);
//                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
//                    reduction = 1.0f - logExcessEnergy;
                    reduction = std::sqrt(gainFactor);
                    reduction = (float)std::clamp(reduction, 1e-6f, 1.0f);
                    reds[channel] = reduction;
                } else {
                    LOG("POP");
                    reds[channel] = 1.0f;
                }
            } else {
                LOG("OFF");
//                if (*prevRecording) {
//                    // lock in gain
//                    reds[channel] = *currRed;
//                }
                *prevRecording = false;
            }
        }
        finalIn = (ins[0] + ins[1]) / 2;
        std::memcpy(inLuffers, &finalIn, sizeof(float));
        *currIn = *inLuffers;
        
        if (*isRecording) {
            finalAverage = (averages[0] + averages[1]) / 2;
            finalReduction = std::min(reds[0], reds[1]);
            LOG("%f", finalReduction);
            
            //        LOG("%f", finalAverage);
            std::memcpy(gainReduction, &finalReduction, sizeof(float));
            *currRed = *gainReduction;
            std::memcpy(recordAverage, &finalAverage, sizeof(float));
            *currAverage = *recordAverage;
        } else {
//            if (*isReset) {
//                finalReduction = gainReduction[1] + (1.0f - pow(1.0f - gainReduction[1], 3)) / 2;
//                finalReduction = (float)std::clamp(finalReduction, 1e-6f, 1.0f);
//                if (finalReduction > 0.9) {
//                    finalReduction = 1.0f;
//                    *isReset = false;
//                }
//                std::memcpy(gainReduction, &finalReduction, sizeof(float));
//                *currRed = *gainReduction;
//            } else {
                gainReduction[0] = gainReduction[1];
//            }
            recordAverage[0] = recordAverage[1];
        }
//        LOG("%f", recordAverage[0]);
//        LOG("%f", inLuffers[0][0]);
            
//            float reduction = 1.0;
//            if (currEnergy <= 0.0f) currEnergy = 1e-6f;
//            float energyDelta = 1e-6f;
////            LOG("VVV");
//            if (!*prevOverThreshold) {
//                if ((currEnergy + energy) > targetEnergy) {
//                    *prevOverThreshold = true;
//                    energyDelta = std::max(currEnergy + (energy - targetEnergy), 1e-6f);
////                    float reductionCurve = 1.0f - pow((excessEnergy / targetEnergy), 1.0f / mSmooth);
//                    
//                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
//                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
////                    LOG("OOO");
////                    LOG("%f", reduction);
////                    reduction = currReduction + attack * (reduction - currReduction);
//                    if (reduction < currReduction) {
//                        reduction = currReduction + attack * (reduction - currReduction);
//                    } else {
//                        reduction = currReduction + (attack / mKnee) * (currReduction / reduction) * (reduction - currReduction);
//                    }
////                    LOG("%f", reduction);
//                } else {
//                    *prevOverThreshold = false;
//                    energyDelta = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
////                    reduction = 1.0f - pow(energyDelta / targetEnergy, 1.0f / mSmooth);
//                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
//                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
//                    
////                    LOG("UUU");
////                    LOG("%f", energyDelta);
////                    LOG("%f", logExcessEnergy);
////                    LOG("%f", reduction);
//                    reduction = std::max(reduction, 1e-6f);
//                    if ((1.0f - reduction) > currReduction) {
//                        reduction = currReduction + release * ((1.0f - reduction) - currReduction) / 4;
//                    } else {
//                        reduction = currReduction + (release / mKnee) * ((1.0f - reduction) / currReduction) * (1.0f - reduction) * (1.0f - reduction) / 4;
//                    }
////                    LOG("%f", reduction);
//                }
//            } else {
//                if ((energy + currEnergy) > targetEnergy) {
//                    *prevOverThreshold = true;
//                    energyDelta = std::max(currEnergy + (energy - targetEnergy), 1e-6f);
////                    float reductionCurve = 1.0f - pow(excessEnergy / targetEnergy, 1.0f / mSmooth);
//                    
//                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
//                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
////                    LOG("OOO");
//                    reduction = std::max(reduction, 1e-6f);
//                    if (reduction < currReduction) {
//                        // Normal attack behavior when reduction < currReduction
//                        reduction = currReduction + attack * (reduction - currReduction);
//                    } else {
//                        // Slow down the attack when reduction > currReduction
////                        float slowdownFactor = 1.0f - (reduction / currReduction);  // Slowdown factor based on the difference
////                        slowdownFactor = std::max(slowdownFactor, 0.1f);  // Avoid completely stalling the reduction
//
//                        // Apply attack with the slowdown factor to reduce the gain more slowly
//                        reduction = currReduction + (attack / mKnee) * (currReduction / reduction) * (reduction - currReduction);
//                    }
////                    LOG("%f", reduction);
////                    
////                    LOG("%f", reduction);
//                } else {
//                    *prevOverThreshold = false;
//                    energyDelta = std::max(targetEnergy - (currEnergy + energy), 1e-6f);
////                    reduction = 1.0f - pow(energyDelta / targetEnergy, 1.0f / mSmooth);
//                    
//                    float logExcessEnergy = log10(1.0f + energyDelta / targetEnergy);
//                    reduction = 1.0f - pow(logExcessEnergy, 1.0f / mSmooth);
//                    
//                    reduction = std::max(reduction, 1e-6f);
////                    LOG("UUU");
////                    LOG("%f", reduction);
//                    if ((1.0f - reduction) > currReduction) {
//                        reduction = currReduction + release * ((1.0f - reduction) - currReduction) / 4;
//                    } else {
//                        reduction = currReduction + (release / mKnee) * ((1.0f - reduction) / currReduction) * (1.0f - reduction) * (1.0f - reduction) / 4;
//                    }
////                    reduction = currReduction + release * ((currReduction / reduction) - currReduction);
////                    reduction = std::max(reduction, currReduction);
////                    LOG("%f", reduction);
//                }
//            }
//            
//            reduction = (float)std::clamp(reduction, 1e-6f, 1.0f);
//            
//            // Add to Gain Reduction
//            reds[channel] = reduction;

            // Add to Out Luffers
            

//        }
        
//        finalReduction = std::min(reds[0], reds[1]);
//        std::memcpy(gainReduction, &finalReduction, sizeof(float));
//        *currRed = *gainReduction;

        float step = (*currRed - prevReduction) / frameCount;
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            float outRms;
            
            
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
//                if (currReduction > step) {
//                    currReduction += step;
//                }
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] * std::max((prevReduction + step * (frameIndex + 1)), 1e-6f);
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
            outs[channel] = outRms;
            //            std::memcpy(outLuffers[channel], &outRms, sizeof(float));
        }
        
        finalOut = (outs[0] + outs[1]) / 2;
        std::memcpy(outLuffers, &finalOut, sizeof(float));
        *currOut = *outLuffers;
        
        endTime = std::chrono::high_resolution_clock::now();

        // Compute elapsed time
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
        double latencyInMicroseconds = duration.count() / 1000.0;
//            LOG("%f ms", latencyInMicroseconds);
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
