#pragma once

#include <memory>
#include <optional>

class MicEchoCanceller
{
public:
    MicEchoCanceller();
    ~MicEchoCanceller();

    MicEchoCanceller(const MicEchoCanceller&) = delete;
    MicEchoCanceller& operator=(const MicEchoCanceller&) = delete;

    bool init();
    bool active() const;

    // Far-end reference: exactly 480 mono 48 kHz samples.
    void processReverse(const float* frame480);

    // Near-end capture, processed in place. No-op when inactive.
    void processCapture(float* frame480);

    void setStreamDelayMs(int ms);

    struct Stats
    {
        std::optional<int> delayMs;
        std::optional<double> erl;
        std::optional<double> erle;
        std::optional<double> divergentFraction;
        std::optional<double> residualEchoMax;
    };

    // Returns false when inactive. Call from the processing thread.
    bool statistics(Stats& out);

private:
    struct Impl;
    std::unique_ptr<Impl> mImpl;
};
