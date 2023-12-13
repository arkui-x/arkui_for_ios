# ArkUI iOS平台适配层

-   [简介]
-   [目录介绍]
-   [使用说明]

## 简介

ArkUI是一套构建分布式应用的声明式UI开发框架。它具备简洁自然的UI信息语法、丰富的UI组件、多维的状态管理，以及实时界面预览等相关能力，帮助您提升应用开发效率，并能在多种设备上实现生动而流畅的用户体验。详情可参考[ArkUI框架介绍](https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/ui/arkui-overview.md)。

ArkUI-X进一步将ArkUI扩展到iOS平台，实现对接iOS平台的适配，开发者基于一套ArkTS主代码，就可以构建iOS平台的精美、高性能应用。

## 目录介绍

ArkUI开发框架的源代码结构参见[代码工程结构及构建说明](https://gitee.com/arkui-x/docs/blob/master/zh-cn/framework-dev/quick-start/project-structure-guide.md)，iOS平台的适配代码在/foundation/arkui/ace\_engine/adapter/ios下，目录结构如下图所示：

```
/foundation/arkui/ace_engine/adapter/ios
├── build                         # 编译配置
├── capability                    # 系统平台能力适配
├── entrance                      # 启动入口相关适配
├── osal                          # 操作系统抽象层
└── stage                         # Stage开发模型适配
```

## 使用说明

### iOS 工程创建

通过ACE Tools或DevEco Studio创建一个ArkUI-X应用工程（示例工程名为HelloWorld），其工程目录下的.arkui-x/ios目录代表对应的iOS工程。iOS应用的入口AppDelegate和ViewController类，其中ViewController需要继承自ArkUI提供的基类StageViewController，详情参见[使用说明](https://gitee.com/arkui-x/docs/tree/master/zh-cn/application-dev/reference/arkui-for-ios)。

* ViewController类
该类名通过通过module名和ability名拼接而得，一个ability对应一个iOS工程侧的ViewController类。详情参见[Ability使用说明](https://gitee.com/arkui-x/docs/blob/master/zh-cn/application-dev/quick-start/start-with-ability-on-ios.md):\
EntryEntryAbilityViewController.h 
    ``` objective-c
    #ifndef EntryEntryAbilityViewController_h
    #define EntryEntryAbilityViewController_h
    #import <UIKit/UIKit.h>
    #import <libarkui_ios/StageViewController.h>
    @interface EntryEntryAbilityViewController : StageViewController


    @end

    #endif /* EntryEntryAbilityViewController_h */
    ```
    EntryEntryAbilityViewController.m
    ``` objective-c
    #import "EntryEntryAbilityViewController.h"

    @interface EntryEntryAbilityViewController ()

    @end

    @implementation EntryEntryAbilityViewController
    - (instancetype)initWithInstanceName:(NSString *)instanceName {
        self = [super initWithInstanceName:instanceName];
        if (self) {

        }
        return self;
    }

    - (void)viewDidLoad {
        [super viewDidLoad];
        self.edgesForExtendedLayout = UIRectEdgeNone;
        self.extendedLayoutIncludesOpaqueBars = YES;
    }
    @end

    ```

* AppDelegate类

    AppDelegate.m中实例化EntryEntryAbilityViewController，并加载ArkUI页面。

    ```objective-c
    #import "AppDelegate.h"
    #import "EntryEntryAbilityViewController.h"
    #import <libarkui_ios/StageApplication.h>

    #define BUNDLE_DIRECTORY @"arkui-x"
    #define BUNDLE_NAME @"com.example.helloworld"

    @interface AppDelegate ()

    @end

    @implementation AppDelegate

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        [StageApplication configModuleWithBundleDirectory:BUNDLE_DIRECTORY];
        [StageApplication launchApplication];
        
        NSString *instanceName = [NSString stringWithFormat:@"%@:%@:%@",BUNDLE_NAME, @"entry", @"EntryAbility"];
        EntryEntryAbilityViewController *mainView = [[EntryEntryAbilityViewController alloc] initWithInstanceName:instanceName];//instanceName为ArkUI-X应用编译产物在应用工程中存放的目录
        [self setNavRootVC:mainView];
        return YES;
    }

    - (void)setNavRootVC:(id)viewController {
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.backgroundColor = [UIColor whiteColor];
        [self.window makeKeyAndVisible];
        UINavigationController *navi = [[UINavigationController alloc]initWithRootViewController:viewController];
        [self setNaviAppearance:navi];
        self.window.rootViewController = navi;
    }

    - (void)setNaviAppearance:(UINavigationController *)navi {
        UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = UIColor.whiteColor;
        navi.navigationBar.standardAppearance = appearance;
        navi.navigationBar.scrollEdgeAppearance = navi.navigationBar.standardAppearance;
    }

    @end
    ```

### iOS 工程编译

对iOS工程编译时，ACE Tools或DevEco Studio会完成两个步骤：
* 集成ArkUI-X SDK

  iOS工程集成ArkUI跨平台SDK遵循iOS应用工程集成Framework规则，SDK中Framework(libarkui_ios.xcframework\libhilog.xcframework\libresourcemanager.xcframework)会自动拷贝到工程目frameworks录下，并引入到工程目录。
* 集成ArkUI-X应用编译产物

  ArkUI-X编译产物生成后，自动拷贝到iOS应用工程arkui-x目录下。这里“arkui-x”目录名称是固定的，不能更改；详情参见[ArkUI-X应用工程结构说明](https://gitee.com/arkui-x/docs/blob/master/zh-cn/application-dev/quick-start/package-structure-guide.md)

```
    arkui-x
        ├── entry
        |   ├── ets
        |   |   ├── modules.abc
        |   |   └── sourceMaps.map
        |   ├── resouces.index
        |   ├── resouces
        |   └── module.json
        └── systemres
```
完成上述步骤后即可按照iOS应用构建流程，构建ArkUI iOS应用，并且可以安装至iOS手机后运行。


### 参考

【1】[ArkUI-X Samples仓](https://gitee.com/arkui-x/samples)