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

#include "adapter/ios/entrance/picker/picker_haptic_controller.h"

#include <memory>
#include <mutex>

#include "adapter/ios/stage/ability/stage_asset_provider.h"

namespace OHOS::Ace::NG {
namespace {
using std::chrono_literals::operator""ms;
const std::string AUDIO_URI = "/systemres/resources/base/media/timepicker.wav";
const std::string EFFECT_ID_NAME = "haptic.slide";
constexpr std::chrono::milliseconds DEFAULT_DELAY(40);
constexpr std::chrono::milliseconds EXTENDED_DELAY(50);
constexpr float HAPTIC_INTENSITY_BASE = 0.5f;
constexpr float HAPTIC_INTENSITY_MAX = 0.98f;
constexpr float HAPTIC_SPEED_FACTOR = 0.0001f;
constexpr double MILLISECONDS_PER_SECOND = 1000.0;
constexpr int8_t PLAY_STATUS_START = 1;
constexpr int8_t PLAY_STATUS_STOP = -1;
constexpr size_t SPEED_MAX = 5000;
constexpr size_t SPEED_PLAY_ONCE = 0;
constexpr size_t SPEED_THRESHOLD = 1560;
constexpr size_t TREND_COUNT = 3;
} // namespace

PickerHapticController::PickerHapticController(const std::string& uri, const std::string& effectId) noexcept
{
    std::string effectiveUri = uri.empty() ? AUDIO_URI : uri;
    std::string effectiveEffectId = effectId.empty() ? EFFECT_ID_NAME : effectId;
    audioHapticPlayer_ = std::make_unique<Platform::AudioHapticPlayer>();
    if (audioHapticPlayer_ != nullptr) {
        const auto bundleCodeDir = AbilityRuntime::Platform::StageAssetProvider::GetInstance()->GetBundleCodeDir();
        audioHapticPlayer_->RegisterSourceWithEffectId(bundleCodeDir + effectiveUri, effectiveEffectId);
        audioHapticPlayer_->Prepare();
    }
    InitPlayThread();
}

PickerHapticController::~PickerHapticController() noexcept
{
    ThreadRelease();
    if (audioHapticPlayer_ != nullptr) {
        audioHapticPlayer_->Release();
    }
}

void PickerHapticController::ThreadRelease()
{
    if (playThread_) {
        {
            std::lock_guard<std::recursive_mutex> guard(threadMutex_);
            playThreadStatus_ = ThreadStatus::NONE;
        }
        threadCv_.notify_one();
        playThread_->join();
        playThread_.reset();
    }
}

bool PickerHapticController::IsThreadReady()
{
    std::lock_guard<std::recursive_mutex> guard(threadMutex_);
    return playThreadStatus_ == ThreadStatus::READY;
}

bool PickerHapticController::IsThreadPlaying()
{
    std::lock_guard<std::recursive_mutex> guard(threadMutex_);
    return playThreadStatus_ == ThreadStatus::PLAYING;
}

bool PickerHapticController::IsThreadPlayOnce()
{
    std::lock_guard<std::recursive_mutex> guard(threadMutex_);
    return playThreadStatus_ == ThreadStatus::PLAY_ONCE;
}

bool PickerHapticController::IsThreadNone()
{
    std::lock_guard<std::recursive_mutex> guard(threadMutex_);
    return playThreadStatus_ == ThreadStatus::NONE;
}

void PickerHapticController::InitPlayThread()
{
    ThreadRelease();
    std::lock_guard<std::recursive_mutex> guard(threadMutex_);
    playThreadStatus_ = ThreadStatus::START;
    playThread_ = std::make_unique<std::thread>(&PickerHapticController::ThreadLoop, this);
    playThreadStatus_ = (playThread_ != nullptr) ? ThreadStatus::READY : ThreadStatus::NONE;
}

void PickerHapticController::ThreadLoop()
{
    while (!IsThreadNone()) {
        {
            std::unique_lock<std::recursive_mutex> lock(threadMutex_);
            threadCv_.wait(lock, [this]() { return IsThreadPlaying() || IsThreadPlayOnce() || IsThreadNone(); });
            if (IsThreadNone()) {
                return;
            }
        }

        isInHapticLoop_ = true;
        float haptic = absSpeedInMm_ * HAPTIC_SPEED_FACTOR + HAPTIC_INTENSITY_BASE;
        haptic = std::clamp(haptic, HAPTIC_INTENSITY_BASE, HAPTIC_INTENSITY_MAX);
        if (audioHapticPlayer_ != nullptr) {
            audioHapticPlayer_->SetHapticIntensity(haptic);
            audioHapticPlayer_->Start();
        }

        {
            auto startTime = std::chrono::high_resolution_clock::now();
            std::unique_lock<std::recursive_mutex> lock(threadMutex_);
            std::chrono::milliseconds delayTime = DEFAULT_DELAY;
            if (IsThreadPlayOnce() && isLoopReadyToStop_) {
                delayTime = EXTENDED_DELAY;
            }
            threadCv_.wait_until(lock, startTime + delayTime);
            if (IsThreadPlayOnce() || isLoopReadyToStop_) {
                playThreadStatus_ = ThreadStatus::READY;
            }
        }
        isInHapticLoop_ = false;
    }
}

void PickerHapticController::Play(size_t speed)
{
    if (playThread_ == nullptr) {
        InitPlayThread();
    }
    bool needNotify = !IsThreadPlaying() && !IsThreadPlayOnce();
    {
        std::lock_guard<std::recursive_mutex> guard(threadMutex_);
        absSpeedInMm_ = speed;
        playThreadStatus_ = ThreadStatus::PLAYING;
    }
    if (needNotify) {
        threadCv_.notify_one();
    }
}

void PickerHapticController::PlayOnce()
{
    if (IsThreadPlaying()) {
        return;
    }
    if (playThread_ == nullptr) {
        InitPlayThread();
    }

    bool needNotify = !IsThreadPlaying() && !IsThreadPlayOnce();
    {
        std::lock_guard<std::recursive_mutex> guard(threadMutex_);
        playThreadStatus_ = ThreadStatus::PLAY_ONCE;
        absSpeedInMm_ = SPEED_PLAY_ONCE;
    }
    if (needNotify) {
        threadCv_.notify_one();
    }
    isHapticCanLoopPlay_ = true;
}

void PickerHapticController::Stop()
{
    {
        std::lock_guard<std::recursive_mutex> guard(threadMutex_);
        playThreadStatus_ = ThreadStatus::READY;
    }
    threadCv_.notify_one();
    lastHandleDeltaTime_ = 0;
}

void PickerHapticController::HandleDelta(double dy)
{
    uint64_t currentTime = GetMilliseconds();
    uint64_t intervalTime = currentTime - lastHandleDeltaTime_;
    CHECK_EQUAL_VOID(intervalTime, 0);

    lastHandleDeltaTime_ = currentTime;
    auto scrollSpeed = std::abs(ConvertPxToMillimeters(dy) / intervalTime) * MILLISECONDS_PER_SECOND;
    if (scrollSpeed > SPEED_MAX) {
        scrollSpeed = SPEED_MAX;
    }
    recentSpeeds_.push_back(scrollSpeed);
    if (recentSpeeds_.size() > TREND_COUNT) {
        recentSpeeds_.pop_front();
    }

    if (!isInHapticLoop_ && isLoopReadyToStop_) {
        isLoopReadyToStop_ = false;
        playThreadStatus_ = ThreadStatus::READY;
        PlayOnce();
    } else if (isHapticCanLoopPlay_ && GetPlayStatus() == PLAY_STATUS_START) {
        Play(scrollSpeed);
    } else if (GetPlayStatus() == PLAY_STATUS_STOP && IsThreadPlaying() && !isLoopReadyToStop_) {
        isLoopReadyToStop_ = true;
        isHapticCanLoopPlay_ = false;
        recentSpeeds_.clear();
        absSpeedInMm_ = scrollSpeed;
    }
}

double PickerHapticController::ConvertPxToMillimeters(double px) const
{
    auto& manager = ScreenSystemManager::GetInstance();
    const double density = manager.GetDensity();
    return density == 0.0 ? 0.0 : (px / density);
}

size_t PickerHapticController::GetCurrentSpeedInMm()
{
    double velocityInPixels = velocityTracker_.GetVelocity().GetVelocityY();
    return std::abs(ConvertPxToMillimeters(velocityInPixels));
}

int8_t PickerHapticController::GetPlayStatus()
{
    if (recentSpeeds_.size() < TREND_COUNT) {
        return 0;
    }
    bool allAbove = true;
    bool allBelow = true;
    for (size_t i = 0; i < TREND_COUNT; ++i) {
        const double speed = recentSpeeds_[i];
        if (speed <= SPEED_THRESHOLD) {
            allAbove = false;
        }
        if (speed >= SPEED_THRESHOLD) {
            allBelow = false;
        }
    }
    return allAbove ? PLAY_STATUS_START : (allBelow ? PLAY_STATUS_STOP : 0);
}
} // namespace OHOS::Ace::NG
