/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "adapter/ios/capability/vibrator/audio_haptic_player.h"

#import "adapter/ios/capability/vibrator/iOSAudioHapticPlayer.h"

namespace OHOS::Ace::Platform {
namespace {
NSString* ToNSString(const std::string& value)
{
    if (value.empty()) {
        return @"";
    }
    return [NSString stringWithUTF8String:value.c_str()];
}

iOSAudioHapticPlayer* GetPlayer(void* player)
{
    if (player == nullptr) {
        return nil;
    }
    return (__bridge iOSAudioHapticPlayer*)player;
}
} // namespace

AudioHapticPlayer::AudioHapticPlayer()
{
    iosAudioHapticPlayerObject_ = (__bridge_retained void*)[[iOSAudioHapticPlayer alloc] init];
}

AudioHapticPlayer::~AudioHapticPlayer()
{
    Release();
}

void AudioHapticPlayer::RegisterSourceWithEffectId(const std::string& effectiveUri, const std::string& effectId)
{
    std::lock_guard<std::mutex> lock(playerMutex_);
    iOSAudioHapticPlayer* player = GetPlayer(iosAudioHapticPlayerObject_);
    if (player != nil) {
        [player registerSourceWithEffectId:ToNSString(effectiveUri) effectId:ToNSString(effectId)];
    }
}

void AudioHapticPlayer::SetHapticIntensity(float intensity)
{
    std::lock_guard<std::mutex> lock(playerMutex_);
    iOSAudioHapticPlayer* player = GetPlayer(iosAudioHapticPlayerObject_);
    if (player != nil) {
        [player setHapticIntensity:intensity];
    }
}

void AudioHapticPlayer::Prepare()
{
    std::lock_guard<std::mutex> lock(playerMutex_);
    iOSAudioHapticPlayer* player = GetPlayer(iosAudioHapticPlayerObject_);
    if (player != nil) {
        [player prepare];
    }
}

void AudioHapticPlayer::Start()
{
    std::lock_guard<std::mutex> lock(playerMutex_);
    iOSAudioHapticPlayer* player = GetPlayer(iosAudioHapticPlayerObject_);
    if (player != nil) {
        [player start];
    }
}

void AudioHapticPlayer::Release()
{
    std::lock_guard<std::mutex> lock(playerMutex_);
    if (iosAudioHapticPlayerObject_ != nullptr) {
        iOSAudioHapticPlayer* player = (__bridge_transfer iOSAudioHapticPlayer*)iosAudioHapticPlayerObject_;
        if (player != nil) {
            [player releaseResources];
        }
        iosAudioHapticPlayerObject_ = nullptr;
    }
}
} // namespace OHOS::Ace::Platform
