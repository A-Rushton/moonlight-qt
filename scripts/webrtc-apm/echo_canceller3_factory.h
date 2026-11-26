#ifndef API_AUDIO_ECHO_CANCELLER3_FACTORY_H_
#define API_AUDIO_ECHO_CANCELLER3_FACTORY_H_

#include <memory>

#include "api/audio/echo_canceller3_config.h"
#include "api/audio/echo_control.h"

namespace webrtc {

class EchoCanceller3Factory : public EchoControlFactory {
 public:
  explicit EchoCanceller3Factory(const EchoCanceller3Config& config);

  std::unique_ptr<EchoControl> Create(int sample_rate_hz,
                                      int num_render_channels,
                                      int num_capture_channels) override;

 private:
  EchoCanceller3Config config_;
};

}  // namespace webrtc

#endif  // API_AUDIO_ECHO_CANCELLER3_FACTORY_H_
