#include "api/audio/echo_canceller3_factory.h"

#include <optional>

#include "modules/audio_processing/aec3/echo_canceller3.h"

namespace webrtc {

EchoCanceller3Factory::EchoCanceller3Factory(const EchoCanceller3Config& config)
    : config_(config) {
  EchoCanceller3Config::Validate(&config_);
}

std::unique_ptr<EchoControl> EchoCanceller3Factory::Create(
    int sample_rate_hz,
    int num_render_channels,
    int num_capture_channels) {
  return std::make_unique<EchoCanceller3>(config_, std::nullopt, sample_rate_hz,
                                          num_render_channels,
                                          num_capture_channels);
}

}  // namespace webrtc
