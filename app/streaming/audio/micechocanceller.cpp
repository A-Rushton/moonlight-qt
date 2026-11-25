#include "micechocanceller.h"

#include <SDL.h>

#ifdef HAVE_WEBRTC_APM

#include <modules/audio_processing/include/audio_processing.h>

namespace {

constexpr int kSampleRate = 48000;

}

struct MicEchoCanceller::Impl
{
    rtc::scoped_refptr<webrtc::AudioProcessing> apm;
    webrtc::StreamConfig streamConfig{kSampleRate, 1};
    bool captureErrorLogged = false;
    bool reverseErrorLogged = false;
};

MicEchoCanceller::MicEchoCanceller() = default;
MicEchoCanceller::~MicEchoCanceller() = default;

bool MicEchoCanceller::init()
{
    auto impl = std::make_unique<Impl>();

    webrtc::AudioProcessing::Config config;
    config.echo_canceller.enabled = true;
    config.echo_canceller.mobile_mode = false;
    config.noise_suppression.enabled = true;
    config.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kModerate;
    config.gain_controller2.enabled = true;
    config.gain_controller2.adaptive_digital.enabled = true;
    config.high_pass_filter.enabled = true;

    impl->apm = webrtc::AudioProcessingBuilder().SetConfig(config).Create();
    if (!impl->apm) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to create audio processor");
        mImpl.reset();
        return false;
    }

    mImpl = std::move(impl);
    return true;
}

bool MicEchoCanceller::active() const
{
    return mImpl != nullptr;
}

void MicEchoCanceller::processReverse(const float* frame480)
{
    if (!mImpl || !frame480) {
        return;
    }

    const float* src[1] = { frame480 };
    float* dst[1] = { nullptr };
    float scratch[480];
    dst[0] = scratch;

    int err = mImpl->apm->ProcessReverseStream(src, mImpl->streamConfig,
                                               mImpl->streamConfig, dst);
    if (err != webrtc::AudioProcessing::kNoError && !mImpl->reverseErrorLogged) {
        mImpl->reverseErrorLogged = true;
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Echo canceller reverse stream error: %d", err);
    }
}

void MicEchoCanceller::processCapture(float* frame480)
{
    if (!mImpl || !frame480) {
        return;
    }

    const float* src[1] = { frame480 };
    float* dst[1] = { frame480 };

    int err = mImpl->apm->ProcessStream(src, mImpl->streamConfig,
                                        mImpl->streamConfig, dst);
    if (err != webrtc::AudioProcessing::kNoError && !mImpl->captureErrorLogged) {
        mImpl->captureErrorLogged = true;
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Echo canceller capture stream error: %d", err);
    }
}

void MicEchoCanceller::setStreamDelayMs(int ms)
{
    if (mImpl) {
        mImpl->apm->set_stream_delay_ms(ms);
    }
}

#else

struct MicEchoCanceller::Impl {};

MicEchoCanceller::MicEchoCanceller() = default;
MicEchoCanceller::~MicEchoCanceller() = default;

bool MicEchoCanceller::init()
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Echo cancellation not built in");
    return false;
}

bool MicEchoCanceller::active() const { return false; }
void MicEchoCanceller::processReverse(const float*) {}
void MicEchoCanceller::processCapture(float*) {}
void MicEchoCanceller::setStreamDelayMs(int) {}

#endif
