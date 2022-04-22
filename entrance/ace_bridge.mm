
#include <string>
#import "adapter/ios/entrance/resource/AceResourceRegisterOC.h"

// namespace OHOS::Ace::Platform {

void CallOCMethod(void *obj){
    [(__bridge AceResourceRegisterOC*)obj unregisterCallMethod:@"123"];
} 

int64_t CallOC_CreateResource(void *obj, const std::string& resourceType, const std::string& param) {
    NSString *oc_resourceType = [NSString stringWithCString:resourceType.c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *oc_param = [NSString stringWithCString:param.c_str() encoding:[NSString defaultCStringEncoding]];

    return (int64_t)[(__bridge AceResourceRegisterOC*)obj createResource:oc_resourceType param:oc_param];
}

bool CallOC_OnMethodCall(void *obj, const std::string& method, const std::string& param, std::string& result){
    NSString *oc_method = [NSString stringWithCString:method.c_str() encoding:[NSString defaultCStringEncoding]];
    NSString *oc_param = [NSString stringWithCString:param.c_str() encoding:[NSString defaultCStringEncoding]];

    NSString *oc_result = [(__bridge AceResourceRegisterOC*)obj onCallMethod:oc_method param:oc_param];
    result = [oc_result UTF8String];

    return true;
}


bool CallOC_ReleaseResource(void *obj, const std::string& resourceHash){
    NSString *oc_resourceHash = [NSString stringWithCString:resourceHash.c_str() encoding:[NSString defaultCStringEncoding]];
    return [(__bridge AceResourceRegisterOC*)obj releaseObject:oc_resourceHash];
}

// }
