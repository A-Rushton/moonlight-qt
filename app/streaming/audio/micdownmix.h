#pragma once

#include <cstdint>

// Averages interleaved PCM channels into mono float. int16 input is scaled
// to [-1, 1).
inline void micDownmixToMono(const void* pcm, int frames, int channels, bool isFloat, float* out)
{
    if (pcm == nullptr || out == nullptr || frames <= 0 || channels <= 0) {
        return;
    }

    if (isFloat) {
        const float* in = static_cast<const float*>(pcm);
        const float scale = 1.0f / channels;
        for (int f = 0; f < frames; f++) {
            float sum = 0.0f;
            for (int c = 0; c < channels; c++) {
                sum += in[c];
            }
            out[f] = sum * scale;
            in += channels;
        }
    }
    else {
        const int16_t* in = static_cast<const int16_t*>(pcm);
        const float scale = 1.0f / (32768.0f * channels);
        for (int f = 0; f < frames; f++) {
            int32_t sum = 0;
            for (int c = 0; c < channels; c++) {
                sum += in[c];
            }
            out[f] = static_cast<float>(sum) * scale;
            in += channels;
        }
    }
}
