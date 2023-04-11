/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#include <vector>
#include "WindowView.h"
#include "virtual_rs_window.h"

@interface WindowView()

// std::shared_ptr<RSSurfaceNode> surfaceNode_;
// std::shared_ptr<AbilityRuntime::Platform::Context> context_;
// std::unique_ptr<OHOS::Ace::Platform::UIContent> uiContent_;

@end
// #endif  //  FLUTTER_SHELL_ENABLE_METAL

@implementation WindowView

// std::weak_ptr<OHOS::Rosen::Window> _window;

// - (instancetype)initWithWindow:(std::weak_ptr<OHOS::Rosen::Window> )window
// {
//     self = [super init];

//     if (self) {
//         _window = window;;
//     }

//     return self;
// }

    
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

//   [self.windowDelegate  ProcessPointerEvent:event];
}
-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

}
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

}
-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {

}

// -(UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
// {
//     if (_window.expired()) {
//         // 需要处理vec，先传个空的
//         //uint8_t* data = static_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
//         //std::vector<uint8_t> vec(data, data + position);
//         std::vector<uint8_t> vec;
//         std::shared_ptr<OHOS::Rosen::Window> windowPtr = _window.lock();
//         windowPtr->ProcessPointerEvent(vec);
//     }

//     return nil;
// }

// jboolean WindowViewJni::DispatchPointerDataPacket(
//     JNIEnv* env, jobject myObject, jlong view, jobject buffer, jint position)
// {
//     if (env == nullptr) {
//         LOGW("env is null");
//         return false;
//     }

//     uint8_t* data = static_cast<uint8_t*>(env->GetDirectBufferAddress(buffer));
//     std::vector<uint8_t> packet(data, data + position);
//     auto windowPtr = JavaLongToPointer<Rosen::Window>(view);
//     if (windowPtr == nullptr) {
//         LOGE("DispatchPointerDataPacket window is nullptr");
//         return false;
//     }

//     return windowPtr->ProcessPointerEvent(packet);
// }

// - (void)layoutSubviews {
//   if ([self.layer isKindOfClass:[CAEAGLLayer class]]) {
//     CAEAGLLayer* layer = reinterpret_cast<CAEAGLLayer*>(self.layer);
//     layer.allowsGroupOpacity = YES;
//     CGFloat screenScale = [UIScreen mainScreen].scale;
//     layer.contentsScale = screenScale;
//     layer.rasterizationScale = screenScale;
//   }

//   [super layoutSubviews];
// }

// - (void)createSurfaceNode : (CALayer*)layer
// {
//     struct Rosen::RSSurfaceNodeConfig rsSurfaceNodeConfig = { 
//       .SurfaceNodeName = "arkui-x_surface",
//       .additionalData = layer };
//     surfaceNode_ = Rosen::RSSurfaceNode::Create(rsSurfaceNodeConfig);

//     if (!uiContent_) {
//         LOGW("Window Notify uiContent_ Surface Created, uiContent_ is nullptr, delay notify.");
//         delayNotifySurfaceCreated_ = true;
//     } else {
//         LOGI("Window Notify uiContent_ Surface Created");
//         uiContent_->NotifySurfaceCreated();
//     }
// }

// - (void)Window::NotifySurfaceChanged : (int32_t)width, (int32_t)height
// {
//     if (!surfaceNode_) {
//         LOGE("Window Notify Surface Changed, surfaceNode_ is nullptr!");
//         return;
//     }
//     LOGI("Window Notify Surface Changed wh:[%{public}d, %{public}d]", width, height);
//     surfaceWidth_ = width;
//     surfaceHeight_ = height;
//     surfaceNode_->SetBoundsWidth(surfaceWidth_);
//     surfaceNode_->SetBoundsHeight(surfaceHeight_);

//     if (!uiContent_) {
//         LOGW("Window Notify uiContent_ Surface Created, uiContent_ is nullptr, delay notify.");
//         delayNotifySurfaceChanged_ = true;
//     } else {
//         LOGI("Window Notify uiContent_ Surface Created");
//         Ace::ViewportConfig config;
//         config.SetDensity(3.0f);
//         config.SetSize(surfaceWidth_, surfaceHeight_);
//         uiContent_->UpdateViewportConfig(config, WindowSizeChangeReason::RESIZE);
//     }
// }

// - (void)Window::NotifySurfaceDestroyed
// {
//     surfaceNode_ = nullptr;

//     if (!uiContent_) {
//         LOGW("Window Notify Surface Destroyed, uiContent_ is nullptr, delay notify.");
//         delayNotifySurfaceDestroyed_ = true;
//     } else {
//         LOGI("Window Notify uiContent_ Surface Destroyed");
//         uiContent_->NotifySurfaceDestroyed();
//     }
// }

@end
