# ArkUI iOS 平台适配层

## 项目概述

ArkUI iOS 平台适配层是 ArkUI-X 跨平台框架的 iOS 平台实现，通过 Objective-C/Objective-C++ 桥接机制实现 ArkTS 应用在 iOS 设备上的原生渲染和交互。

**代码位置**: `foundation/arkui/ace_engine/adapter/ios/`

## 目录结构

```
adapter/ios/
├── entrance/                           # 入口层 (ObjC/C++)
│   ├── WindowView.h/mm                 # 窗口视图
│   ├── ace_bridge.h/mm                 # ObjC/C++ 桥接
│   ├── virtual_rs_window.h/mm          # 虚拟渲染窗口 (核心)
│   ├── mmi_event_convertor.h/mm        # 事件转换
│   ├── display_info.h/mm               # 显示信息
│   ├── AcePlatformPlugin.h/mm          # 平台插件
│   ├── AceSurfaceHolder.h/mm           # Surface 持有者
│   ├── AceTextureHolder.h/mm           # Texture 持有者
│   ├── WantParams.h/mm                 # 参数封装
│   ├── DownloadManager.h/mm            # 下载管理
│   ├── accessibility/                  # 无障碍
│   │   ├── AccessibilityWindowView.h/mm
│   │   ├── AccessibilityElement.h/mm
│   │   ├── AccessibilityNodeInfo.h/mm
│   │   └── AceAccessibilityBridge.h/mm
│   ├── resource/                       # 资源管理
│   │   ├── AceResourcePlugin.h/m
│   │   ├── AceResourceRegisterDelegate.h
│   │   ├── AceResourceRegisterOC.h/mm
│   │   ├── IAceOnCallResourceMethod.h
│   │   └── IAceOnResourceEvent.h
│   ├── plugin_lifecycle/               # 插件生命周期
│   │   ├── ArkUIXPluginRegistry.h/mm
│   │   ├── IArkUIXPlugin.h
│   │   ├── IPluginRegistry.h
│   │   └── PluginContext.h/mm
│   ├── logIntercept/                   # 日志拦截
│   │   ├── ILogger.h
│   │   ├── Logger.h/mm
│   │   └── LogInterfaceBridge.h/mm
│   ├── interaction/                    # 交互能力
│   │   └── interaction_impl.h/cpp
│   ├── html/                           # HTML 转换
│   │   └── html_to_span.cpp
│   ├── picker/                         # 选择器
│   ├── report/                         # 上报能力
│   ├── udmf/                           # 统一数据管理框架
│   │   └── udmf_impl.h/cpp
│   ├── ui_session/                     # UI 会话管理
│   │   └── ui_session_manager_ios.h
│   └── xcollie/                        # 看门狗
│       └── xcollieInterface_impl.h
├── stage/                              # Stage 模型适配
│   ├── ability/                        # 能力层 (ObjC)
│   │   ├── StageViewController.h/mm    # 主 ViewController
│   │   ├── StageApplication.h/mm       # 应用入口
│   │   ├── StageContainerView.h/mm     # 容器视图
│   │   ├── StageSecureContainerView.h/mm
│   │   ├── StageAssetManager.h/mm      # 资源管理
│   │   ├── StageConfigurationManager.h/mm
│   │   ├── InstanceIdGenerator.h/mm    # 实例 ID 生成
│   │   ├── Stage.h                     # Stage 定义
│   │   ├── AbilityLoader.h/mm          # 能力加载器
│   │   ├── stage_asset_provider.h/mm
│   │   ├── ability_context_adapter.h/mm
│   │   ├── application_context_adapter.h/mm
│   │   ├── window_view_adapter.h/mm
│   │   └── version_printer.h/cpp
│   └── uicontent/                      # UI 内容 (C++)
│       ├── ace_container_sg.h/cpp      # ACE 容器
│       ├── ui_content_impl.h/cpp       # UI 内容实现
│       ├── ace_view_sg.h/cpp           # ACE 视图
│       └── platform_event_callback.h
├── osal/                               # 平台抽象层 (C++)
│   ├── accessibility_manager_impl.h/cpp # 无障碍服务 (核心)
│   ├── subwindow_ios.h/cpp             # 子窗口管理
│   ├── resource_adapter_impl.h/cpp     # 资源适配
│   ├── resource_adapter_impl_v2.h/cpp  # 资源适配 V2
│   ├── system_properties.cpp           # 系统属性
│   ├── display_manager_ios.h/cpp       # 显示器管理
│   ├── image_source_ios.h/cpp          # 图片解码
│   ├── pixel_map_ios.h/cpp             # 位图操作
│   ├── input_method_manager_ios.cpp    # 输入法管理
│   ├── mouse_style_ios.h/cpp           # 鼠标样式
│   ├── navigation_route_ios.h/cpp      # 导航路由
│   ├── image_packer_ios.h/cpp          # 图片打包
│   ├── drawable_descriptor_ios.h/cpp   # drawable 描述
│   ├── resource_theme_style.h/cpp      # 主题样式
│   ├── resource_convertor.h/cpp        # 资源转换
│   ├── resource_path_util.h/mm         # 资源路径 (ObjC++)
│   ├── file_asset_provider.h/cpp       # 文件资源提供
│   ├── file_uri_helper_ios.cpp         # URI 助手
│   ├── frame_trace_adapter_impl.h/cpp  # 帧追踪
│   ├── layout_inspector.cpp            # 布局检查
│   ├── modal_ui_extension_impl.cpp     # 模态扩展
│   ├── drag_window.cpp                 # 拖拽窗口
│   ├── view_data_wrap_impl.cpp         # 视图数据
│   ├── websocket_manager.cpp           # WebSocket
│   ├── system_bar_style_ohos.h/cpp     # 系统栏样式
│   ├── advance/                        # 高级功能适配
│   │   ├── ai_write_adapter.cpp        # AI 写作
│   │   ├── data_detector_adapter.cpp   # 数据检测
│   │   ├── image_analyzer_adapter_impl.cpp # 图片分析
│   │   ├── text_share_adapter.cpp      # 文本分享
│   │   └── text_translation_adapter.cpp # 文本翻译
│   └── mock/                           # 无障碍模拟实现
│       ├── accessibility_element_info.h/cpp
│       ├── accessibility_constants.h/cpp
│       └── accessibility_def.h
├── capability/                         # 平台能力扩展
│   ├── web/                            # WebView 组件
│   │   ├── AceWeb.h/mm                 # 主类 (核心)
│   │   ├── AceWebControllerBridge.h/mm # 控制器桥接
│   │   ├── AceWebResourcePlugin.h/mm   # 资源插件
│   │   ├── AceWebCallbackObjectWrapper.h/cpp
│   │   ├── AceWebPatternBridge.h/cpp   # Pattern 桥接
│   │   ├── AceWebObject.h/cpp          # Web 对象
│   │   ├── AceWebDownloadImpl.h/cpp    # 下载实现
│   │   ├── WebMessageChannel.h/mm      # 消息通道
│   │   └── AceWebMessageExtImpl.h/cpp
│   ├── video/                          # 视频播放组件
│   │   ├── AceVideo.h/mm               # 视频主类
│   │   └── AceVideoResourcePlugin.h/mm # 资源插件
│   ├── bridge/                         # JS Bridge
│   │   ├── bridge_manager.mm           # 桥接管理
│   │   ├── BridgePluginManager+internal.mm
│   │   ├── BridgePlugin+internal.h/mm  # 插件内部
│   │   ├── BridgePlugin+jsMessage.mm   # JS 消息
│   │   ├── BridgeTaskQueue.h/mm        # 任务队列
│   │   ├── BridgeTaskQueueHandler.mm
│   │   ├── BridgeManagerHolder.mm
│   │   ├── MethodData.mm
│   │   ├── ParameterHelper.mm
│   │   ├── ResultValue.mm
│   │   ├── BridgeTaskInfo.h
│   │   └── codec/                      # 编解码
│   │       ├── BridgeCodecUtil.h/mm
│   │       ├── BridgeSerializer.h/mm
│   │       ├── BridgeBinaryCodec.h/mm
│   │       ├── BridgeJsonCodec.h/mm
│   │       ├── BridgeArray.h/m
│   │       └── BridgeCodesDelegate.h
│   ├── editing/                        # 文本编辑
│   │   └── iOSTxtInputManager.mm       # 输入管理
│   ├── platformview/                   # 原生视图嵌入
│   │   ├── AcePlatformView.h/mm        # 平台视图
│   │   └── render/                     # 渲染
│   ├── surface/                        # Surface 管理
│   │   └── AceSurfaceView.h/mm
│   ├── texture/                        # 纹理渲染
│   │   ├── AceXcomponentTextureView.h/mm
│   │   └── RenderViewXcomponent.h/mm
│   ├── clipboard/                      # 剪贴板
│   ├── vibrator/                       # 振动反馈
│   │   ├── iOSVibratorManager.h/m/mm   # 振动管理
│   │   ├── vibrator_impl.h/mm          # 振动实现
│   │   └── vibrator_proxy_impl.h/cpp   # 代理
│   ├── storage/                        # 存储能力
│   ├── environment/                    # 环境变量
│   └── font/                           # 字体管理
└── build/                              # 构建配置
```

## 核心模块一览

| 模块 | 职责 | 代码位置 | 关键文件 |
|-----|------|---------|---------|
| **Stage 模型** | ViewController/Application 生命周期 | `stage/ability/` | StageViewController.mm |
| **UI 内容** | ACE 容器和 UI 内容管理 | `stage/uicontent/` | ace_container_sg.cpp |
| **ObjC/C++ 桥接** | ObjC 与 C++ 双向通信 | `entrance/` | ace_bridge.mm, virtual_rs_window.mm |
| **窗口视图** | Metal/Surface 渲染 | `entrance/` | WindowView.mm |
| **平台抽象层** | 系统 API 封装 | `osal/` | accessibility_manager_impl.cpp |
| **平台能力** | Web/Video/Bridge 等 | `capability/` | AceWeb.mm, bridge/ |

## 分层架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ArkTS Application                            │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              Stage 模型层 (Objective-C)                             │
│   stage/ability/                                                     │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │StageApplication │→│StageViewController│→│StageContainerView│   │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              UI 内容层 (C++)                                         │
│   stage/uicontent/                                                   │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │ AceContainerSg  │←│ UIContentImpl    │←│ AceViewSg        │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              窗口视图层 (Objective-C++)                              │
│   entrance/                                                          │
│   ┌─────────────────┐  ┌─────────────────┐                          │
│   │   WindowView    │  │VirtualRSWindow  │  ← Metal 渲染            │
│   └─────────────────┘  └─────────────────┘                          │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              ObjC/C++ 桥接层                                         │
│   entrance/                                                          │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │   ace_bridge    │  │MmiEventConvertor│  │Accessibility    │    │
│   │ (资源/方法调用)  │  │ (事件转换)      │  │Bridge           │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              平台抽象层 OSAL (C++/ObjC++)                            │
│   osal/                                                              │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │DisplayManager   │  │ResourceAdapter  │  │Accessibility    │    │
│   │(显示器管理)     │  │(资源加载)       │  │(无障碍)         │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │SubWindow        │  │ImageSource      │  │InputMethod      │    │
│   │(子窗口)         │  │(图片解码)       │  │(输入法)         │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              平台能力层 Capability (ObjC/C++)                        │
│   capability/                                                        │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │Web (WKWebView)  │  │Video (AVPlayer) │  │Bridge (JS桥)   │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│   │PlatformView     │  │Vibrator         │  │Editing          │    │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                                ↓
┌─────────────────────────────────────────────────────────────────────┐
│              iOS Framework                                           │
│   UIKit | Foundation | WebKit | AVFoundation | CoreHaptics | ...   │
└─────────────────────────────────────────────────────────────────────┘
```

## ObjC/C++ 桥接机制详解

### 1. 桥接层 API (`entrance/ace_bridge.h`)

```cpp
// C++ 调用 Objective-C 方法
int64_t CallOC_CreateResource(void *obj, const std::string& resourceType, const std::string& param);
bool CallOC_OnMethodCall(void *obj, const std::string& method, const std::string& param, std::string& result);
bool CallOC_ReleaseResource(void *obj, const std::string& resourceHash);
```

### 2. 类型转换工具

```objective-c
// std::string ↔ NSString
inline NSString* StringToNSString(const std::string& str) {
    return [NSString stringWithUTF8String:str.c_str()];
}

inline std::string NSStringToString(NSString* nsStr) {
    return nsStr ? [nsStr UTF8String] : "";
}

// std::vector<uint8_t> ↔ NSData
inline NSData* VectorToNSData(const std::vector<uint8_t>& vec) {
    return [NSData dataWithBytes:vec.data() length:vec.size()];
}

inline std::vector<uint8_t> NSDataToVector(NSData* data) {
    if (!data) return {};
    const uint8_t* bytes = static_cast<const uint8_t*>([data bytes]);
    return std::vector<uint8_t>(bytes, bytes + [data length]);
}

// 桥接转换
// __bridge: 不转移所有权
// __bridge_transfer: 转移所有权给 ARC (等价于 CFBridgingRelease)
// __bridge_retained: 转移所有权给手动管理 (等价于 CFBridgingRetain)
```

### 3. 事件转换 (`entrance/mmi_event_convertor.mm`)

```objective-c
// UITouch → TouchEvent
TouchEvent ConvertTouchEvent(UITouch* touch, UIEvent* event);

// UITouchPhase → TouchType
// UITouchPhaseBegan    → TouchEvent::ActionType::DOWN
// UITouchPhaseMoved    → TouchEvent::ActionType::MOVE
// UITouchPhaseEnded    → TouchEvent::ActionType::UP
// UITouchPhaseCancelled → TouchEvent::ActionType::CANCEL
```

## Stage 模型适配

### StageViewController 生命周期

```objective-c
// stage/ability/StageViewController.mm

@interface StageViewController : UIViewController
@property (nonatomic, readonly) NSString *instanceName;
@property (nonatomic, assign) BOOL statusBarHidden;
@property (nonatomic, assign) UIStatusBarStyle statusBarStyle;
@property (nonatomic, assign) BOOL homeIndicatorHidden;
@property (nonatomic, assign) BOOL privacyMode;
@end

// 生命周期:
// initWithInstanceName → viewDidLoad → viewWillAppear → viewDidAppear
//                      → viewWillDisappear → viewDidDisappear → dealloc
```

### StageApplication 初始化

```objective-c
// stage/ability/StageApplication.mm

@interface StageApplication : NSObject
// 配置模块（必须首先调用）
+ (void)configModuleWithBundleDirectory:(NSString *)bundleDirectory;
// 启动应用
+ (void)launchApplication;
// 前后台回调
+ (void)callCurrentAbilityOnForeground;
+ (void)callCurrentAbilityOnBackground;
// 语言设置
+ (void)setLocaleWithLanguage:(NSString *)language
                       country:(NSString *)country
                        script:(NSString *)script;
@end
```

### AbilityLoader 能力加载

```objective-c
// stage/ability/AbilityLoader.h/mm
// 负责动态加载 Ability 模块
```

### UI 内容层 (stage/uicontent/)

| 文件 | 职责 |
|-----|------|
| `ace_container_sg.cpp` | ACE 容器实现，管理 UI 线程和渲染 |
| `ui_content_impl.cpp` | UI 内容接口实现 |
| `ace_view_sg.cpp` | ACE 视图实现，处理输入事件 |

## 平台抽象层 (OSAL)

### 核心模块

| 模块 | 文件 | 职责 |
|-----|------|-----|
| **Accessibility** | `accessibility_manager_impl.cpp` | 无障碍服务核心 |
| **SubWindow** | `subwindow_ios.cpp` | 子窗口管理 (弹窗/菜单) |
| **ResourceAdapter** | `resource_adapter_impl.cpp` | 资源加载适配 |
| **ResourceAdapter V2** | `resource_adapter_impl_v2.cpp` | 资源加载适配 V2 |
| **SystemProperties** | `system_properties.cpp` | 系统属性获取 |
| **DisplayManager** | `display_manager_ios.cpp` | 显示器信息管理 |
| **ImageSource** | `image_source_ios.cpp` | 图片解码 |
| **PixelMap** | `pixel_map_ios.cpp` | 位图操作 |
| **InputMethod** | `input_method_manager_ios.cpp` | 输入法管理 |
| **MouseStyle** | `mouse_style_ios.cpp` | 鼠标光标样式 |
| **NavigationRoute** | `navigation_route_ios.cpp` | 导航路由 |

### 高级功能适配 (`osal/advance/`)

| 模块 | 文件 | 职责 |
|-----|------|-----|
| AI Writing | `ai_write_adapter.cpp` | AI 写作辅助 |
| DataDetector | `data_detector_adapter.cpp` | 数据检测 (电话/链接/地址) |
| ImageAnalyzer | `image_analyzer_adapter_impl.cpp` | 图片智能分析 |
| TextShare | `text_share_adapter.cpp` | 文本分享 |
| TextTranslation | `text_translation_adapter.cpp` | 文本翻译 |

### 无障碍模拟层 (`osal/mock/`)

| 文件 | 职责 |
|-----|------|-----|
| `accessibility_element_info.cpp` | 无障碍元素信息 |
| `accessibility_def.h` | 无障碍定义 |
| `accessibility_constants.cpp` | 无障碍常量 |

## 平台能力层 (Capability)

### 能力模块概览

| 模块 | 位置 | 核心文件 | 职责 |
|-----|------|---------|-----|
| **Web** | `capability/web/` | AceWeb.mm | WKWebView 封装 |
| **Web Controller** | `capability/web/` | AceWebControllerBridge.mm | Web 控制器 |
| **Editing** | `capability/editing/` | iOSTxtInputManager.mm | 文本输入管理 |
| **Bridge** | `capability/bridge/` | BridgePluginManager+internal.mm | JS Bridge 通信 |
| **Video** | `capability/video/` | AceVideo.mm | AVPlayer 封装 |
| **PlatformView** | `capability/platformview/` | AcePlatformView.mm | 原生视图嵌入 |
| **Web Callback** | `capability/web/` | AceWebCallbackObjectWrapper.cpp | 回调封装 |
| **Texture** | `capability/texture/` | AceXcomponentTextureView.mm | 纹理视图 |
| **Surface** | `capability/surface/` | AceSurfaceView.mm | Surface 管理 |
| **Bridge Codec** | `capability/bridge/codec/` | BridgeCodecUtil.mm | 编解码工具 |

### Web 组件关键类

```
capability/web/
├── AceWeb.h/mm                    # WebView 主类
├── AceWebControllerBridge.h/mm    # 控制器桥接
├── AceWebResourcePlugin.h/mm      # 资源插件
├── AceWebCallbackObjectWrapper.h/cpp # 回调封装
├── AceWebPatternBridge.h/cpp      # Pattern 桥接
├── AceWebObject.h/cpp             # Web 对象
├── AceWebDownloadImpl.h/cpp       # 下载实现
├── WebMessageChannel.h/mm         # 消息通道
└── AceWebMessageExtImpl.h/cpp     # 消息扩展
```

### Bridge 组件结构

```
capability/bridge/
├── bridge_manager.mm              # 桥接管理
├── BridgePluginManager+internal.mm # 插件管理
├── BridgePlugin+internal.h/mm     # 插件内部
├── BridgePlugin+jsMessage.mm      # JS 消息
├── BridgeTaskQueue.h/mm           # 任务队列
├── BridgeTaskQueueHandler.mm
├── BridgeManagerHolder.mm
├── MethodData.mm
├── ParameterHelper.mm
├── ResultValue.mm
├── BridgeTaskInfo.h
└── codec/                         # 编解码
    ├── BridgeCodecUtil.h/mm       # 工具
    ├── BridgeSerializer.h/mm      # 序列化
    ├── BridgeBinaryCodec.h/mm     # 二进制编解码
    ├── BridgeJsonCodec.h/mm       # JSON 编解码
    └── BridgeArray.h/m            # 数组
```

## 关键代码位置索引

### 入口层 (`entrance/`)

| 功能 | 文件 |
|-----|------|
| 窗口视图 | `WindowView.h/mm` |
| 虚拟渲染窗口 | `virtual_rs_window.h/mm` |
| ObjC/C++ 桥接 | `ace_bridge.h/mm` |
| 事件转换 | `mmi_event_convertor.h/mm` |
| 显示信息 | `display_info.h/mm` |
| 平台插件 | `AcePlatformPlugin.h/mm` |
| 交互能力 | `interaction/interaction_impl.cpp` |
| UDMF | `udmf/udmf_impl.cpp` |
| HTML 转换 | `html/html_to_span.cpp` |
| 无障碍窗口 | `accessibility/AccessibilityWindowView.mm` |

### Stage 模型 (`stage/`)

| 功能 | 文件 |
|-----|------|
| StageViewController | `ability/StageViewController.mm` |
| StageApplication | `ability/StageApplication.mm` |
| AbilityLoader | `ability/AbilityLoader.mm` |
| Stage 资源提供 | `ability/stage_asset_provider.mm` |
| ACE 容器 | `uicontent/ace_container_sg.cpp` |
| UI 内容 | `uicontent/ui_content_impl.cpp` |
| ACE 视图 | `uicontent/ace_view_sg.cpp` |

### OSAL 层 (`osal/`)

| 功能 | 文件 |
|-----|------|
| 无障碍管理 | `accessibility_manager_impl.cpp` |
| 子窗口 | `subwindow_ios.cpp` |
| 资源适配 | `resource_adapter_impl.cpp` |
| 资源适配 V2 | `resource_adapter_impl_v2.cpp` |
| 系统属性 | `system_properties.cpp` |
| 无障碍元素 | `mock/accessibility_element_info.cpp` |
| 显示管理 | `display_manager_ios.cpp` |
| 图片解码 | `image_source_ios.cpp` |
| 位图操作 | `pixel_map_ios.cpp` |
| 输入法 | `input_method_manager_ios.cpp` |
| 鼠标样式 | `mouse_style_ios.cpp` |

### Capability 层 (`capability/`)

| 功能 | 文件 |
|-----|------|
| Web 主类 | `web/AceWeb.mm` |
| Web 控制器 | `web/AceWebControllerBridge.mm` |
| Web 回调 | `web/AceWebCallbackObjectWrapper.cpp` |
| 视频播放 | `video/AceVideo.mm` |
| Bridge 插件管理 | `bridge/BridgePluginManager+internal.mm` |
| Bridge 管理 | `bridge/bridge_manager.mm` |
| Bridge 编解码 | `bridge/codec/BridgeCodecUtil.mm` |
| 文本输入 | `editing/iOSTxtInputManager.mm` |
| 平台视图 | `platformview/AcePlatformView.mm` |
| Surface | `surface/AceSurfaceView.mm` |
| 纹理视图 | `texture/AceXcomponentTextureView.mm` |

## 关键技术点

### 1. 跨线程通信

```objective-c
// ObjC → Native (主线程 → UI 线程)
void PostTaskToPlatformThread(std::function<void()>&& task) {
    auto taskScheduler = Container::Current()->GetTaskScheduler();
    if (taskScheduler) {
        taskScheduler->PostTask(std::move(task), TaskType::PLATFORM);
    }
}

// Native → ObjC (UI 线程 → 主线程)
void PostTaskToMainThread(std::function<void()>&& task) {
    dispatch_async(dispatch_get_main_queue(), ^{
        task();
    });
}

// 延迟执行
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
               dispatch_get_main_queue(), ^{
    task();
});
```

### 2. 内存管理规则

**规则 1**: ARC 自动管理 ObjC 对象
```objective-c
// 强引用（默认）
@property (nonatomic, strong) NSString* name;

// 弱引用（避免循环引用）
@property (nonatomic, weak) id<Delegate> delegate;

// 自动释放池
@autoreleasepool {
    NSString* temp = [[NSString alloc] init];
    // temp 在池销毁时自动释放
}
```

**规则 2**: C++ 对象生命周期由 shared_ptr 管理
```objective-c
@interface MyView : UIView {
    std::shared_ptr<NativeRenderer> _renderer;  // C++ 智能指针
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _renderer = std::make_shared<NativeRenderer>();
    }
    return self;
}
// ARC 会在 dealloc 时自动释放 _renderer（shared_ptr 析构）
@end
```

**规则 3**: 避免循环引用 (Block 中使用 self)
```objective-c
// ❌ 循环引用
self.completion = ^{
    [self doSomething];  // self → completion → self
};

// ✅ 使用 __weak 打破循环引用
__weak typeof(self) weakSelf = self;
self.completion = ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    [strongSelf doSomething];
};
```

**规则 4**: 桥接转换
```objective-c
// __bridge: 不转移所有权
void* ptr = ...;
id obj = (__bridge id)ptr;

// __bridge_transfer: 转移所有权给 ARC (ptr 被释放)
void* ptr = ...;
id obj = (__bridge_transfer id)ptr;

// __bridge_retained: 转移所有权给手动管理 (需要手动 CFRelease)
id obj = ...;
void* ptr = (__bridge_retained void*)obj;
CFRelease(ptr);  // 需要手动释放
```

### 3. Metal 渲染层创建

```objective-c
// WindowView.mm
- (void)createSurfaceNode {
    // 创建 Metal 渲染层
    self.metalLayer = [CAMetalLayer layer];
    self.metalLayer.frame = self.bounds;
    self.metalLayer.device = MTLCreateSystemDefaultDevice();
    self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer.framebufferOnly = YES;
    
    [self.layer addSublayer:self.metalLayer];
    
    // 通知 Native 层 Surface 创建
    nativeSurfaceCreated((__bridge void*)self.metalLayer);
}
```

### 4. Safe Area 适配

```objective-c
- (void)notifySafeAreaChanged {
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeArea = self.safeAreaInsets;
        nativeSafeAreaChanged(safeArea.top, safeArea.bottom,
                              safeArea.left, safeArea.right);
    }
}

- (void)safeAreaInsetsDidChange {
    [super safeAreaInsetsDidChange];
    [self notifySafeAreaChanged];
}
```

### 5. 条件编译

```cpp
#ifdef IOS_PLATFORM
    #include "adapter/ios/osal/display_manager_ios.h"
#elif defined(ANDROID_PLATFORM)
    #include "adapter/android/osal/display_manager_android.h"
#endif

#ifdef WEB_SUPPORTED
    // Web 组件相关代码
#endif

#ifdef VIDEO_SUPPORTED
    // 视频组件相关代码
#endif
```

## 开发注意事项

1. **线程安全**: UI 操作必须在主线程，Native 回调可能在工作线程
   ```objective-c
   dispatch_async(dispatch_get_main_queue(), ^{
       // UI 操作
   });
   ```

2. **内存泄漏**: 
   - Block 中使用 `__weak` 避免循环引用
   - C++ 对象使用 `shared_ptr` 管理
   - 注意 `__bridge` vs `__bridge_transfer` 的区别

3. **@autoreleasepool**: 
   - 大量临时对象创建时使用
   - 在 for 循环中避免内存峰值

4. **iOS 版本兼容**:
   ```objective-c
   if (@available(iOS 11.0, *)) {
       // iOS 11+ 代码
   } else {
       // 降级处理
   }
   ```

5. **代码为准**: 修改代码前务必阅读实际源码，以源码实现为准

6. **大型文件注意**: 
   - `AbilityLoader.mm` - 能力加载器
   - `AceWeb.mm` - Web 组件核心
   - `accessibility_manager_impl.cpp` - 无障碍核心
   - `virtual_rs_window.mm` - 虚拟窗口
   - `ace_container_sg.cpp` - ACE 容器
   - `AceWebControllerBridge.mm` - Web 控制器
   修改这些文件需格外谨慎
