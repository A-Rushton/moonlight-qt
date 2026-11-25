#pragma once

#include <memory>

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

private:
    struct Impl;
    std::unique_ptr<Impl> mImpl;
};
