#pragma once

#include <algorithm>
#include <cmath>

// Normalised 0..1 meter level over a -60..0 dBFS range. dBFS follows AES17,
// so a full-scale sine reads 0 dBFS.
inline float micLevelFromSamples(const float* samples, int count)
{
    if (samples == nullptr || count <= 0) {
        return 0.0f;
    }

    double sumSquares = 0.0;
    for (int i = 0; i < count; i++) {
        sumSquares += double(samples[i]) * samples[i];
    }

    double rms = std::sqrt(sumSquares / count);
    if (rms <= 0.0) {
        return 0.0f;
    }

    double db = 20.0 * std::log10(rms * std::sqrt(2.0));
    return static_cast<float>(std::clamp((db + 60.0) / 60.0, 0.0, 1.0));
}
