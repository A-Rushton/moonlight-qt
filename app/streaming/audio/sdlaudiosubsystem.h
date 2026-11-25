#pragma once

#include "SDL_compat.h"

#include <mutex>

// SDL's subsystem refcount is not thread-safe, and the playback renderer and
// the microphone take references from different threads.
namespace SdlAudioSubsystem {

inline std::mutex& lock()
{
    static std::mutex mutex;
    return mutex;
}

inline bool acquire()
{
    std::lock_guard<std::mutex> guard(lock());
    return SDL_InitSubSystem(SDL_INIT_AUDIO) == 0;
}

inline void release()
{
    std::lock_guard<std::mutex> guard(lock());
    SDL_QuitSubSystem(SDL_INIT_AUDIO);
}

}
