#pragma once

#include "micencoder.h"
#include "micring.h"

#include <algorithm>
#include <cstdint>

// Hands the echo canceller one far-end frame per capture frame. The producer
// is the audio decode thread; the consumer is the mic encoder thread, which
// alone owns the counters.
class MicFarEndFeeder
{
public:
    static constexpr size_t FrameSamples = MicEncoder::FrameSamples;
    static constexpr size_t CapacitySamples = MicEncoder::SampleRate / 5;

    // Ordinary network jitter is absorbed below MaxBacklogSamples; beyond it
    // the reference is resynchronised to the newest TargetBacklogSamples
    static constexpr size_t MaxBacklogSamples = 10 * FrameSamples;
    static constexpr size_t TargetBacklogSamples = 4 * FrameSamples;

    struct Counters
    {
        uint64_t frames = 0;
        uint64_t starved = 0;
        uint64_t trims = 0;
        uint64_t trimmedSamples = 0;
    };

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
        m_Counters.frames++;

        if (m_Ring.available() > MaxBacklogSamples) {
            m_Counters.trims++;
            m_Counters.trimmedSamples += m_Ring.discardTo(TargetBacklogSamples);
        }

        if (m_Ring.popFrame(out, FrameSamples)) {
            return true;
        }

        m_Counters.starved++;
        std::fill(out, out + FrameSamples, 0.0f);
        return false;
    }

    size_t depth() const noexcept
    {
        return m_Ring.available();
    }

    // Returns the counters since the previous call and resets them
    Counters takeCounters() noexcept
    {
        Counters c = m_Counters;
        m_Counters = Counters();
        return c;
    }

private:
    MicRing m_Ring;
    Counters m_Counters;
};
