#pragma once

#include <memory>

struct OpusEncoder;

#define MIC_MAX_OPUS_FRAME_BYTES 1000

class MicEncoder
{
public:
    static constexpr int SampleRate = 48000;
    static constexpr int FrameSamples = 480;

    MicEncoder() = default;
    ~MicEncoder();

    MicEncoder(const MicEncoder&) = delete;
    MicEncoder& operator=(const MicEncoder&) = delete;

    bool init();

    // Encodes exactly FrameSamples mono float samples. Returns the packet
    // size in bytes (1..MIC_MAX_OPUS_FRAME_BYTES) or a negative Opus error.
    int encode(const float* frame480, unsigned char* out, int outCapacity);

private:
    struct Deleter { void operator()(OpusEncoder* enc) const; };
    std::unique_ptr<OpusEncoder, Deleter> mEncoder;
};
