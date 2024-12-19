//
//  LufsAdapter.hpp
//  LoudMashter
//
//  Created by mashen on 12/17/24.
//

#ifndef LufsAdapter_hpp
#define LufsAdapter_hpp
//
//#import "DSPKernel.hpp"
//#import "ParameterRamper.hpp"
#import <vector>

static inline float convertBadValuesToZero(float x) {
    /*
     Eliminate denormals, not-a-numbers, and infinities.
     Denormals fails the first test (absx > 1e-15), infinities fails
     the second test (absx < 1e15), and NaNs fails both tests. Zero will
     also fail both tests, but because the system sets it to zero, that's OK.
     */
    
    float absx = fabs(x);
    
    if (absx > 1e-15 && absx < 1e15) {
        return x;
    }
    
    return 0.0;
}

class LufsAdapter {
public:
    struct FilterCoefficients {
//        float highShelf_b1 = 1.53512948;
//        float highShelf_b2 = -2.69169634;
//        float highShelf_b3 = 1.19839281;
//        float highShelf_a1 = -1.69500495;
//        float highShelf_a2 = 0.73199158;
        float highShelf_b1 = 0.25;
        float highShelf_b2 = -2.69169634;
        float highShelf_b3 = 1.19839281;
        float highShelf_a1 = -1.69500495;
        float highShelf_a2 = 0.73199158;
        
        //        let bHighShelfCoeff: [Float] = [
        //            1.53512948, -2.69169634, 1.19839281
        //        ]
        //        let aHighShelfCoeff: [Float] = [
        //            -1.69500495, 0.73199158
        //        ]
        //        let bHighPassCoeff: [Float] = [
        //            1.0, -2.0, 1.0
        //        ]
        //        let aHighPassCoeff: [Float] = [
        //            -1.99004745, 0.990072250
        //        ]
    };
    
    struct FilterState {
        float prevHighShelfIn = 0.0;
        float prevPrevHighShelfIn = 0.0;
        float prevHighShelfOut = 0.0;
        float prevPrevHighShelfOut = 0.0;
        
        void clear() {
            prevHighShelfIn = 0.0;
            prevPrevHighShelfIn = 0.0;
            prevHighShelfOut = 0.0;
            prevPrevHighShelfOut = 0.0;
        }
        void convertBadStateValuesToZero() {
            /*
             These filters work by feedback. If an infinity or NaN needs to come
             into the filter input, the feedback variables can become infinity
             or NaN, which causes the filter to stop operating. This function
             clears out any bad numbers in the feedback variables.
             */
            prevHighShelfIn = convertBadValuesToZero(prevHighShelfIn);
            prevPrevHighShelfIn = convertBadValuesToZero(prevPrevHighShelfIn);
            prevHighShelfOut = convertBadValuesToZero(prevHighShelfOut);
            prevPrevHighShelfOut = convertBadValuesToZero(prevPrevHighShelfOut);
        }
    };
    
    void filterPhase(const float frame, float *out, int channel) {
        FilterState& state = channelStates[channel];
//        float highShelfIn = frame;
//        float highShelfOut = (coeffs.highShelf_b1 * highShelfIn) + (coeffs.highShelf_b2 * state.prevHighShelfIn) + (coeffs.highShelf_b3 * state.prevPrevHighShelfIn) - (coeffs.highShelf_a1 * state.prevHighShelfOut) - (coeffs.highShelf_a2 * state.prevPrevHighShelfOut);
//        *out = highShelfOut / 2;
//        
//        state.prevPrevHighShelfIn = state.prevHighShelfIn;
//        state.prevHighShelfIn = highShelfIn;
//        state.prevPrevHighShelfOut = state.prevHighShelfOut;
//        state.prevHighShelfOut = highShelfOut;
//        
//        channelStates[channel].convertBadStateValuesToZero();
        
//        return highShelfOut;
    }
    
    void proc(std::span<float const*> inputBuffers, std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            for (UInt32 channel = 0; channel < inputBuffers.size(); ++channel) {
                filterPhase(inputBuffers[channel][frameIndex], &outputBuffers[channel][frameIndex], channel);
                // Do your sample by sample dsp here...
//                outputBuffers[channel][frameIndex] = inputBuffers[channel][frameIndex] / 2;
            }
        }
    }
    
    std::vector<FilterState> channelStates;
    FilterCoefficients coeffs;
};

#endif
