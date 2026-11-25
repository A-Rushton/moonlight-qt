#pragma once

#include "micencoder.h"
#include "micring.h"

#include <algorithm>

// Hands the echo canceller one far-end frame per capture frame. The producer
// is the audio decode thread; the consumer is the mic encoder thread.
class MicFarEndFeeder
{
public:
    static constexpr size_t FrameSamples = MicEncoder::FrameSamples;
    static constexpr size_t CapacitySamples = MicEncoder::SampleRate / 5;

    // Backlog beyond which the reference is resynchronised to the newest frame
    static constexpr size_t MaxBacklogSamples = 3 * FrameSamples;

    MicFarEndFeeder() : m_Ring(CapacitySamples) {}

    MicFarEndFeeder(const MicFarEndFeeder&) = delete;
    MicFarEndFeeder& operator=(const MicFarEndFeeder&) = delete;

    void push(const float* mono, size_t samples) noexcept
    {
        m_Ring.push(mono, samples);
    }

    // Returns false and fills silence when no full frame is buffered
    bool popFrame(float* out) noexcept
    {
        if (m_Ring.available() > MaxBacklogSamples) {
            m_Ring.discardTo(FrameSamples);
        }

        if (m_Ring.popFrame(out, FrameSamples)) {
            return true;
        }

        std::fill(out, out + FrameSamples, 0.0f);
        return false;
    }

private:
    MicRing m_Ring;
};
