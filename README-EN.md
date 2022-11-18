# ArkUI iOS Adaptation Layer<a name="EN-US_TOPIC_0000001076213364"></a>

-   [Introduction](#section15701932113019)
-   [Directory Structure](#section1791423143211)
-   [How to Use](#section171384529150)

## Introduction<a name="section15701932113019"></a>

The ArkUI framework empowers OpenHarmony UI development by providing a series of UI components, including basic components, container components, and canvas components. Currently, the ArkUI framework supports web-like programming paradigms and declarative programming paradigms.


**Figure 1** ArkUI framework architecture<a name="fig2606133765017"></a> 
![](https://gitee.com/openharmony/arkui_ace_engine/raw/master/figures/JS-UI%E6%A1%86%E6%9E%B6%E6%9E%B6%E6%9E%84.png "JS-UI framework architecture")

The ArkUI framework consists of the application, framework, engine, and porting layers.

-   **Application**

    This layer contains apps with Feature Abilities (FAs) developed using the JS UI framework. The FA app in this document refers to the app with FAs developed using JavaScript.

-   **Framework**

    This layer parses UI pages and provides the Model-View-ViewModel (MVVM), page routing, custom components and more for front end development.

-   **Engine**

    This layer implements animation parsing, Document Object Model (DOM) building, layout computing, rendering command building and drawing, and event management.

-   **Porting Layer**

    This layer abstracts the platform layer to provide interfaces for the interconnection with the OS. For example, event interconnection, rendering pipeline interconnection, and lifecycle interconnection.

Using the APIs provided by the preceding layers, apps developed with the ArkUI framework will be able to access the iOS platform and run on standard iOS devices.

## Directory Structure<a name="section1791423143211"></a>

For details about the source code structure of the ArkUI framework, see [ArkUI Project Structure and Building](https://gitee.com/arkui-x/docs/blob/master/en/framework-dev/quick-start/project-structure-guide.md). The adaptation code for the iOS platform is available at **/foundation/arkui/ace\_engine/adapter/ios**. The directory structure is as follows:

```
/foundation/arkui/ace_engine/adapter/ios
├── build                         # Build configuration
├── capability                    # System capability adaptation
├── entrance                      # Entry-related adaptation
├── osal                          # OS abstraction layer
└── test                          # Test code
```

## How to Use<a name="section171384529150"></a>

You can create an ArkUI cross-platform application project by following instructions in [Application Development](https://gitee.com/arkui-x/docs/blob/master/en/application-dev/README.md). During development on the iOS platform, use either constructor provided by **AceViewController** to set the development paradigm and the ArkUI module instance name or JSBundle directory. The details are as follows:

**Constructor 1**

```objective-c
/**
 * Initializes this AceViewController with the specified instance name.
 *
 *  This API is used for pure ACE application. It will combine the js/`instanceName` as bundleDirectory.
 *
 * @param version  ACE version.
 * @param instanceName Instance name.
 */
- (instancetype)initWithVersion:(ACE_VERSION)version
                  instanceName:(nonnull NSString*)instanceName;
```

How to Use
```objective-c
AceViewController *controller = [[AceViewController alloc] initWithVersion:(ACE_VERSION_ETS) instanceName:@"MainAbility"];
```

Note: The **instanceName** parameter indicates the module instance name. **AceViewController** internally loads the JSBundle whose directory is **js/instanceName** in the xCode project. If you want to customize the JSBundle directory, use constructor 2.

**Constructor 2**

```objective-c
/**
 * Initializes this AceViewController with the specified JSBundle directory.
 *
 * @param version  ACE version.
 * @param bundleDirectory JSBundle directory.
 */
- (instancetype)initWithVersion:(ACE_VERSION)version
               bundleDirectory:(nonnull NSString*)bundleDirectory;
```

How to Use

```objective-c
// Custom JSBundle path
NSString* bundleDirectory = @"xxxxx";
AceViewController *controller = [[AceViewController alloc] initWithVersion::(ACE_VERSION_ETS)
               bundleDirectory:bundleDirectory
```
Up to now, when the app is started, the corresponding ArkUI module source code is automatically loaded and executed for UI rendering and display.
