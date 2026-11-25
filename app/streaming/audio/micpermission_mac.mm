#include "micpermission.h"

#import <AVFoundation/AVFoundation.h>

#include <memory>

MicPermission micPermissionStatus()
{
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
    case AVAuthorizationStatusAuthorized:
        return MicPermission::Granted;
    case AVAuthorizationStatusNotDetermined:
        return MicPermission::Undetermined;
    default:
        return MicPermission::Denied;
    }
}

void requestMicPermission(std::function<void(bool granted)> done)
{
    auto callback = std::make_shared<std::function<void(bool)>>(std::move(done));
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio
                             completionHandler:^(BOOL granted) {
        (*callback)(granted == YES);
    }];
}
