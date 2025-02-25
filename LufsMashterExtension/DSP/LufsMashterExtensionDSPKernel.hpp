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
//            case LufsMashterExtensionParameterAddress::lookahead:
//                mLookAhead = value;
//                break;
            case LufsMashterExtensionParameterAddress::osfactor:
                mOsFactor = value;
                break;
            case LufsMashterExtensionParameterAddress::filtersize:
                mFilterSize = value;
                break;
            case LufsMashterExtensionParameterAddress::thresh:
                mThresh = value;
                break;
            case LufsMashterExtensionParameterAddress::attack:
                mAttack = value;
                break;
            case LufsMashterExtensionParameterAddress::release:
                mRelease = value;
                break;
            case LufsMashterExtensionParameterAddress::target:
                mTarget = value;
                break;
            case LufsMashterExtensionParameterAddress::makeup:
                mMakeUp = value;
                break;
            
            
//            case LufsMashterExtensionParameterAddress::knee:
//                mKnee = value;
//                break;
                // Add a case for each parameter in LufsMashterExtensionParameterAddresses.h
        }
    }
    
    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        
        switch (address) {
//            case LufsMashterExtensionParameterAddress::lookahead:
//                return (AUValue)mLookAhead;
            case LufsMashterExtensionParameterAddress::osfactor:
                return (AUValue)mOsFactor;
            case LufsMashterExtensionParameterAddress::filtersize:
                return (AUValue)mFilterSize;
            case LufsMashterExtensionParameterAddress::thresh:
                return (AUValue)mThresh;
            case LufsMashterExtensionParameterAddress::attack:
                return (AUValue)mAttack;
            case LufsMashterExtensionParameterAddress::release:
                return (AUValue)mRelease;
            case LufsMashterExtensionParameterAddress::target:
                return (AUValue)mTarget;
            case LufsMashterExtensionParameterAddress::makeup:
                return (AUValue)mMakeUp;
            
//            case LufsMashterExtensionParameterAddress::knee:
//                return (AUValue)mKnee;
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
    
    template <typename T>
    void getTruePeak(float* truePeak, std::span<T> buffers, AUAudioFrameCount frameCount, int oversamplingFactor, int filterSize) {
        static_assert(std::is_same_v<T, float*> || std::is_same_v<T, const float*>,
                              "T must be either float* or const float*");
        int channels = buffers.size();
        float peaks[] = {0.0f, 0.0f};
        int oversampleSize = (frameCount + filterSize - 1) * oversamplingFactor;
        
        for (UInt32 channel = 0; channel < channels; ++channel) {
            float* overSamples = new float[oversampleSize];
            std::fill(overSamples, overSamples + oversampleSize, 0.0f);

            // Oversample the buffer by inserting zeros between each sample
            for (size_t i = 0; i < frameCount; ++i) {
                for (int j = 0; j < oversamplingFactor; ++j) {
                    if (j == 0) {
                        overSamples[(i + (filterSize / 2)) * oversamplingFactor + j] = buffers[channel][i];  // Copy original sample
                    }
                }
            }
            
            float filter[filterSize];
//            float normCutoff = ((mSampleRate / 2.0) * 0.98) / mSampleRate;
//            float normCutoff = 1.0f / (2.0f * oversamplingFactor);
            float normCutoff = (mSampleRate / 2.0f) * 0.98 / mSampleRate;
            for (int i = 0; i < filterSize; ++i) {
                float x = i - (filterSize - 1) / 2.0f;
                float sinc = ((fabsf(x) < 1e-6f)) ? 1.0f : sinf(2.0f * M_PI * normCutoff * x) / (M_PI * x);
                float hamming = 0.54f - 0.46f * cosf(2.0f * M_PI * i / (filterSize - 1));
                filter[i] = sinc * hamming;
            }
            
            float sum = 0.0f;
            vDSP_sve(filter, 1, &sum, filterSize);
            float normFactor = 1.0f / sum;
            vDSP_vsmul(filter, 1, &normFactor, filter, 1, filterSize);
            
            float filteredBuffer[oversampleSize];
            
            // Perform convolution to simulate the reconstruction (apply the FIR filter)
            vDSP_conv(overSamples, 1, filter, 1, filteredBuffer, 1, oversampleSize, filterSize);
            
            // Find the maximum value in the filtered signal (True Peak)
            float channelPeak = 0.0f;
            vDSP_maxmgv(filteredBuffer, 1, &channelPeak, oversampleSize);
            peaks[channel] = channelPeak;
            delete[] overSamples;
        }
        
        
        *truePeak = std::max(peaks[0], peaks[1]);
        if (*truePeak > 1.0) {
            LOG("%fAAA", *truePeak);
        }
    }
    
    float getEnvelope(const float targetReduction, float prevReduction, float attack, float release, float sampleRate) {
        // Calculate attack and release coefficients
        float attackCoef = std::pow(10.0f, -1.0f / (attack * sampleRate));
        float releaseCoef = std::pow(10.0f, -1.0f / (release * sampleRate));
        float result = 0.0f;
        // Smooth the gain reduction based on whether it's increasing or decreasing
        if (targetReduction > prevReduction) {
            // Release phase: Envelope decays towards the target reduction
            result = releaseCoef * (targetReduction - prevReduction);
        } else {
            // Attack phase: Envelope quickly follows the target reduction
            result = attackCoef * (targetReduction - prevReduction);
        }
        return result;
    }
    
    void softClip(std::span<float *> buffers, AUAudioFrameCount frameCount, float threshold, int oversamplingFactor) {
        int oversampleSize = frameCount * oversamplingFactor;
        
        for (UInt32 channel = 0; channel < buffers.size(); ++channel) {
            float* overSamples = new float[oversampleSize];
            std::fill(overSamples, overSamples + oversampleSize, 0.0f);

            // Oversample the buffer by inserting zeros between each sample
            for (size_t i = 0; i < frameCount - 1; ++i) {
                for (int j = 0; j < oversamplingFactor; ++j) {
                    float alpha = static_cast<float>(j) / oversamplingFactor;
                    // Linear interpolation between buffers[i] and buffers[i+1]
                    overSamples[i * oversamplingFactor + j] = buffers[channel][i] + alpha * (buffers[channel][i + 1] - buffers[channel][i]);
                }
            }
            
            for (int j = 0; j < oversamplingFactor; ++j) {
                overSamples[(frameCount - 1) * oversamplingFactor + j] = buffers[channel][frameCount - 1];
            }
//
            
//            for (UInt32 frameIndex = 0; frameIndex < oversampleSize; ++frameIndex) {
//                float sample = overSamples[frameIndex];
//                if (fabs(sample) <= threshold) {
//                    overSamples[frameIndex] = sample - (sample * sample * sample) / (threshold * threshold);
//                } else {
//                    overSamples[frameIndex] = threshold * (sample > 0 ? 1.0f : -1.0f);
//                }
//            }
            
            for (size_t i = 0; i < frameCount; ++i) {
                float sum = 0.0f;
                for (int j = 0; j < oversamplingFactor; ++j) {
                    sum += overSamples[i * oversamplingFactor + j];
                }
                buffers[channel][i] = sum / oversamplingFactor;  // Average for downsampling
            }
            delete[] overSamples;
        }
        
    }

    void hardClip(std::span<float *> buffers, AUAudioFrameCount frameCount, float threshold) {
        float sample;
        for (UInt32 channel = 0; channel < buffers.size(); ++channel) {
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                sample = buffers[channel][frameIndex];
                if (sample > threshold) {
                    buffers[channel][frameIndex] = threshold;
                } else if (sample < -threshold) {
                    buffers[channel][frameIndex] = -threshold;
                } else {
                    buffers[channel][frameIndex] = sample;
                }
            }
        }
        
    }
    
    /**
     MARK: - Internal Process
     
     This function does the core siginal processing.
     Do your custom DSP here.
     */
    void process(float* lookAhead, std::span<float*> lookAheadBuffers, bool* hardClipOn, bool* softClipOn, float* currPeakMax, bool* isReset, float* recordIntegrated, float* recordCount, bool* isRecording, float* currIntegrated, float* currRed, float* currIn, float* currOut, bool* prevRecording, float* inPeaks, float* outPeaks, float* peakReduction, float* currPeakIn, float* currPeakOut,  float* currPeakRed, float* gainReduction, std::span<float*> inLufsFrame, std::span<float*> outLufsFrame, float* inLuffers, float* outLuffers, std::span<float const*> inputBuffers, std::span<float*> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        
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
        
        // START
        // Perform per sample dsp on the incoming float in before assigning it to out
        
        std::vector<float*> clipBuffers;
        clipBuffers.resize(2);
        std::vector<float*> kFilterBuffers;
        kFilterBuffers.resize(2);
        
        int lookAheadSize = (int)(mSampleRate * *lookAhead);
        
        float lufsGate = pow(10, -60 / 10);
        float lufsTarget = pow(10, ((mTarget * 66) - 60) / 20);
        float tpThresh = pow(10, ((mThresh * 66) - 60) / 20);
        float scThresh = pow(10, (((mThresh * 66) - 60) + 3) / 20);
        float makeup = pow(10, ((mMakeUp * 12) - 6) / 20);

        float targetEnergy = lufsWindow * lufsTarget * lufsTarget;
        float reduction = 1.0;
        int oversamplingFactor = osFactors[(int)mOsFactor];
        int filterSize = (int)(mFilterSize * (128 - 3)) + 3;
        
        float attack = 1.0f - std::exp((-1.0f * frameCount) / (mAttack * mSampleRate));
        float release = 1.0f - std::exp((-1.0f * frameCount) / (mRelease * mSampleRate));
        float prevReduction = *gainReduction;
        
        float reds[] = {1.0f, 1.0f};
        float averages[] = {0.0f, 0.0f};
        float ins[] = {0.0f, 0.0f};
        float outs[] = {0.0f, 0.0f};
        
        float finalReduction = 1.0f;
        float finalAverage = 0.0f;
        float finalIn = 0.0f;
        float finalOut = 0.0f;
        
        float truePeak = 0.0f;
        float prevLimit = *peakReduction;
//        float finalPeakIn = 0.0f;
//        float finalPeakOut = 0.0f;
        
        // SHIFT BUFFERS
        std::copy_backward(gainReduction, gainReduction + (vizLength - 1), gainReduction + vizLength);
        std::copy_backward(recordIntegrated, recordIntegrated + (vizLength - 1), recordIntegrated + vizLength);
        std::copy_backward(inLuffers, inLuffers + (vizLength - 1), inLuffers + vizLength);
        std::copy_backward(outLuffers, outLuffers + (vizLength - 1), outLuffers + vizLength);
        std::copy_backward(inPeaks, inPeaks + (vizLength - 1), inPeaks + vizLength);
        std::copy_backward(outPeaks, outPeaks + (vizLength - 1), outPeaks + vizLength);
        std::copy_backward(peakReduction, peakReduction + (vizLength - 1), peakReduction + vizLength);
        
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex];
            }
        }
//            if (frameCount < lookAheadSize) {
//                LOG("DSOGIHSDGOPI");
////                LOG("%f", sizeof(lookAheadBuffers[channel]) / sizeof(float));
////                for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
////                    outputBuffers[channel][frameIndex] = lookAheadBuffers[channel][lookAheadSize - frameCount + frameIndex];
////                }
//                LOG("%f", lookAheadBuffers[channel][lookAheadSize - 1]);
//               
//                std::memcpy(outputBuffers[channel], lookAheadBuffers[channel] + (lookAheadSize - frameCount), frameCount * sizeof(float));
//                std::copy_backward(lookAheadBuffers[channel], lookAheadBuffers[channel] + (lookAheadSize - frameCount), lookAheadBuffers[channel] + lookAheadSize);
//                std::memcpy(lookAheadBuffers[channel], inputBuffers[channel], frameCount * sizeof(float));
//                LOG("%f", outputBuffers[channel][0 + frameCount - 1]);
//                
//            } else {
//                LOG("OPIHUPSGDO");
//                LOG("%f", *lookAhead);
////                for (UInt32 frameIndex = 0; frameIndex < lookAheadSize; ++frameIndex) {
////                    outputBuffers[channel][frameIndex] = lookAheadBuffers[channel][frameIndex];
////                }
////                for (UInt32 frameIndex = lookAheadSize; frameIndex < frameCount; ++frameIndex) {
////                    outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex - lookAheadSize];
////                }
////                for (UInt32 frameIndex = 0; frameIndex < lookAheadSize; ++frameIndex) {
////                    lookAheadBuffers[channel][frameIndex] = inputBuffers[channel][frameCount - lookAheadSize];
////                }
//            }
//        }
//            int copySize = std::max(lookAheadSize, j)
            
//
//            std::copy(inputBuffers[channel], inputBuffers[channel] + frameCount, lookAheadBuffers[channel]);
        
        // START TP LIMITER
        LOG("SDGSDGHSDG%d", oversamplingFactor);
        if (*softClipOn) {
            softClip(outputBuffers, frameCount, scThresh, oversamplingFactor);
        }
        getTruePeak(&truePeak, outputBuffers, frameCount, oversamplingFactor, 31);
        std::memcpy(inPeaks, &truePeak, sizeof(float));
        *currPeakIn = *inPeaks;

//        if (truePeak < 2.0 ) { // Clamp
        if (truePeak > *currPeakMax) {
            *currPeakMax = truePeak;
        }
        
        // soft clip

        
        if (truePeak > tpThresh) {
            *currPeakRed = tpThresh / truePeak; // Gain factor to bring the peak under threshold
        } else {
            *currPeakRed = 1.0f;
        }
        
//            float adaptiveRelease = (1 - *currReduction)
        
        if (*currPeakRed < prevLimit) {
            *currPeakRed = prevLimit + attack * (*currPeakRed - prevLimit);
        } else {
            *currPeakRed = prevLimit + release * (*currPeakRed - prevLimit);
        }
        
        *peakReduction = (float)std::clamp(*currPeakRed, 1e-6f, 1.0f);
        *currPeakRed = *peakReduction;
//        }
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            // APPLY LIMITER REDUCTION
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = outputBuffers[channel][frameIndex] * *currPeakRed;
            }
        }
            
       
            // OUT PEAKS
            getTruePeak(&truePeak, outputBuffers, frameCount, oversamplingFactor, 31);
            std::memcpy(outPeaks, &truePeak, sizeof(float));
            *currPeakOut = *outPeaks;
        
        if (*hardClipOn) {
            hardClip(outputBuffers, frameCount, tpThresh);
        }
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            // APPLY LIMITER REDUCTION
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = std::min((outputBuffers[channel][frameIndex] * makeup), 1.0f);
            }
        }
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            
            // LUFFERS BEGIN
            if (!kFilterBuffers[channel]) {
                kFilterBuffers[channel] = new float[frameCount];
            }
            
            float inRms;
            
            // SHIFT LUFSFRAME
            std::copy_backward(outLufsFrame[channel], outLufsFrame[channel] + (lufsWindow - frameCount), outLufsFrame[channel] + lufsWindow);
            std::copy_backward(inLufsFrame[channel], inLufsFrame[channel] + (lufsWindow - frameCount), inLufsFrame[channel] + lufsWindow);
//            std::copy_backward(lookAhead[channel], lookAhead[channel] + (441 - frameCount), lookAhead[channel] + 441);

            // K WEIGHTING FILTER
            vDSP_biquad_SetCoefficientsDouble(biquadIn[channel].setup, Coeffs, 0, 1);
            vDSP_biquad_SetCoefficientsDouble(biquadOut[channel].setup, Coeffs, 0, 1);
            
            vDSP_biquad(biquadIn[channel].setup,
                        biquadIn[channel].delay,
                        outputBuffers[channel], 1,
                        kFilterBuffers[channel], 1,
                        frameCount);
            
            std::memcpy(inLufsFrame[channel], kFilterBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(inLufsFrame[channel], 1, &inRms, lufsWindow);
            ins[channel] = inRms;
        }
        
        // COMBINE CHANNEL CALCS
        finalIn = ((ins[0] * ins[0]) + (ins[1] * ins[1]));
        if (finalIn < lufsGate) {
            finalIn = 0.0f;
        }
        std::memcpy(inLuffers, &finalIn, sizeof(float));
        *currIn = *inLuffers;
        
        // GET AVG AND GAIN RED WHILE RECORDING
        if (!*isReset) {
            if (*isRecording) {
                LOG("ON");
                *prevRecording = true;
                finalAverage = (*currIntegrated * (*recordCount) + finalIn) / (*recordCount + 1);

                *recordCount = *recordCount + 1.0f;
                
                float currEnergy = lufsWindow * finalAverage;
                float gainFactor = targetEnergy / currEnergy;
                if (currEnergy <= 0.0f) currEnergy = 1e-6f;
                
                if (gainFactor < 1.0f) {
                    reduction = std::sqrt(gainFactor);
                    reduction = (float)std::clamp(reduction, 1e-6f, 1.0f);
                    finalReduction = reduction;
                } else {
                    LOG("POP");
                    finalReduction = 1.0f;
                }
            } else {
                LOG("OFF");
                *prevRecording = false;
                finalReduction = gainReduction[1];
                finalAverage = recordIntegrated[1];
            }
        } else {
            if (!*isRecording) {
                LOG("SETTING");
                
                finalReduction = gainReduction[1] + 0.05;
                finalReduction = (float)std::clamp(finalReduction, 1e-6f, 1.0f);
                if (finalReduction > 0.9) {
                    finalReduction = 1.0f;
                    *isReset = false;
                }
                finalAverage = 0.0f;
            }
        }
        
        std::memcpy(gainReduction, &finalReduction, sizeof(float));
        *currRed = *gainReduction;
        std::memcpy(recordIntegrated, &finalAverage, sizeof(float));
        *currIntegrated = *recordIntegrated;
        
        // APPLY GAIN RED
        float step = (*currRed - prevReduction) / frameCount;
        
        for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
            float outRms;
            
            for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
                outputBuffers[channel][frameIndex] = outputBuffers[channel][frameIndex] * std::max((prevReduction + step * (frameIndex + 1)), 1e-6f);
            }
            
            // OUT LUFS
            vDSP_biquad(biquadOut[channel].setup,
                        biquadOut[channel].delay,
                        outputBuffers[channel], 1,
                        kFilterBuffers[channel], 1,
                        frameCount);
            
            std::memcpy(outLufsFrame[channel], kFilterBuffers[channel], frameCount * sizeof(float));
            vDSP_rmsqv(outLufsFrame[channel], 1, &outRms, lufsWindow);
            outs[channel] = outRms;
        }

        finalOut = ((outs[0] * outs[0]) + (outs[1] * outs[1]));
        if (finalOut < lufsGate) {
            finalOut = 0.0f;
        }
        std::memcpy(outLuffers, &finalOut, sizeof(float));
        *currOut = *outLuffers;
        
        endTime = std::chrono::high_resolution_clock::now();

        // Compute elapsed time
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
        double latencyInMilliseconds = duration.count() / 1000.0f;
        LOG("%f ms", latencyInMilliseconds);
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
//    std::vector<float*> lookAheadBuffers;
    
    int osFactors[4] = { 2, 4, 8, 16 };
    double mOsFactor = 1.0;
    double mFilterSize = 5.0;
    double mThresh = 1.0;
    double mAttack = 0.5;
    double mRelease = 0.5;
    double mTarget = 1.0;
    double mLookAhead = 0.01;
    double mMakeUp = 0.0;
//    double mKnee = 12.0;
    
    int stages = 2;
    double Coeffs[10] = {
        1.53512485,         // b
        -2.69169618,
        1.19839281,
        -1.69065929,        // a
        0.73248077,
        
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
