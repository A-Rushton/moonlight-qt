#include "micechocanceller.h"

#include <SDL.h>

#ifdef HAVE_WEBRTC_APM

#if defined(_WIN32) && !defined(NOMINMAX)
#define NOMINMAX
#endif

#if defined(__GNUC__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
#endif
#include <modules/audio_processing/include/audio_processing.h>
#ifdef HAVE_WEBRTC_AEC3_FACTORY
#include <api/audio/echo_canceller3_factory.h>
#endif
#if defined(__GNUC__)
#pragma GCC diagnostic pop
#endif

namespace {

constexpr int kSampleRate = 48000;

#ifdef HAVE_WEBRTC_AEC3_FACTORY
// Speakers with their own DSP (soundbars, TVs) leave a long, poorly modelled
// echo tail, so use a longer filter and let near-end speech win double-talk.
webrtc::EchoCanceller3Config makeEchoConfig()
{
    webrtc::EchoCanceller3Config config;
    config.filter.refined.length_blocks = 20;
    config.filter.coarse.length_blocks = 20;
    config.suppressor.dominant_nearend_detection.enr_threshold = .75f;
    config.suppressor.dominant_nearend_detection.trigger_threshold = 6;
    config.suppressor.dominant_nearend_detection.hold_duration = 100;
    return config;
}
#endif

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

bool MicEchoCanceller::init(const Options& options)
{
    auto impl = std::make_unique<Impl>();

    webrtc::AudioProcessing::Config config;
    config.echo_canceller.enabled = options.echoCancellation;
    config.echo_canceller.mobile_mode = false;
    config.noise_suppression.enabled = options.noiseSuppression;
    config.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kModerate;
    config.gain_controller2.enabled = true;
    config.gain_controller2.adaptive_digital.enabled = true;
    config.high_pass_filter.enabled = true;

    webrtc::AudioProcessingBuilder builder;
    builder.SetConfig(config);
#ifdef HAVE_WEBRTC_AEC3_FACTORY
    if (options.echoCancellation) {
        builder.SetEchoControlFactory(std::make_unique<webrtc::EchoCanceller3Factory>(makeEchoConfig()));
    }
#endif
    impl->apm = builder.Create();
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
    int err = mImpl->apm->AnalyzeReverseStream(src, mImpl->streamConfig);
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

bool MicEchoCanceller::statistics(Stats& out)
{
    if (!mImpl) {
        return false;
    }

    const webrtc::AudioProcessingStats stats = mImpl->apm->GetStatistics();
    out = Stats();
    if (stats.delay_ms) {
        out.delayMs = *stats.delay_ms;
    }
    out.erl = stats.echo_return_loss;
    out.erle = stats.echo_return_loss_enhancement;
    out.divergentFraction = stats.divergent_filter_fraction;
    out.residualEchoMax = stats.residual_echo_likelihood_recent_max;
    return true;
}

#else

struct MicEchoCanceller::Impl {};

MicEchoCanceller::MicEchoCanceller() = default;
MicEchoCanceller::~MicEchoCanceller() = default;

bool MicEchoCanceller::init(const Options&)
{
    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Echo cancellation not built in");
    return false;
}

bool MicEchoCanceller::active() const { return false; }
void MicEchoCanceller::processReverse(const float*) {}
void MicEchoCanceller::processCapture(float*) {}
void MicEchoCanceller::setStreamDelayMs(int) {}
bool MicEchoCanceller::statistics(Stats&) { return false; }

#endif
