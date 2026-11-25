#pragma once

#include <QtGlobal>

#include <functional>

enum class MicPermission { Granted, Denied, Undetermined };

#ifdef Q_OS_DARWIN

MicPermission micPermissionStatus();

// done is invoked exactly once, on an arbitrary thread
void requestMicPermission(std::function<void(bool granted)> done);

#else

inline MicPermission micPermissionStatus()
{
    return MicPermission::Granted;
}

inline void requestMicPermission(std::function<void(bool granted)> done)
{
    done(true);
}

#endif
