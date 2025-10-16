/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
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

#include "resource_request.h"
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

ArkWeb_ResourceRequest* CreateResourceRequest(WKNavigationAction* navigationAction) {
    if (!navigationAction || !navigationAction.request) {
        return nullptr;
    }
    NSURLRequest* request = navigationAction.request;
    ArkWeb_ResourceRequest* resourceRequest = new ArkWeb_ResourceRequest();
    if (!resourceRequest) {
        return nullptr;
    }
    resourceRequest->method_ = request.HTTPMethod ? [request.HTTPMethod UTF8String] : "GET";
    resourceRequest->url_ = request.URL ? [request.URL.absoluteString UTF8String] : "";
    NSString* referrerString = [request valueForHTTPHeaderField:@"Referrer"];
    resourceRequest->referrer_ = referrerString ? [referrerString UTF8String] : resourceRequest->url_;
    resourceRequest->isRedirect_ = (navigationAction.navigationType == WKNavigationTypeOther);
    resourceRequest->isMainFrame_ = navigationAction.targetFrame ? navigationAction.targetFrame.isMainFrame : YES;
    resourceRequest->hasGesture_ = (navigationAction.navigationType == WKNavigationTypeLinkActivated ||
                                   navigationAction.navigationType == WKNavigationTypeFormSubmitted ||
                                   navigationAction.navigationType == WKNavigationTypeFormResubmitted);
    if (resourceRequest->isMainFrame_) {
        resourceRequest->frameUrl_ = request.URL ? [request.URL.absoluteString UTF8String] : "";
    } else {
        if (navigationAction.targetFrame && navigationAction.targetFrame.request && navigationAction.targetFrame.request.URL) {
            resourceRequest->frameUrl_ = [navigationAction.targetFrame.request.URL.absoluteString UTF8String];
        } else if (request.URL) {
            resourceRequest->frameUrl_ = [request.URL.absoluteString UTF8String];
        } else {
            resourceRequest->frameUrl_ = "";
        }
    }
    NSDictionary* headers = request.allHTTPHeaderFields;
    if (headers) {
        for (NSString* key in headers) {
            NSString* value = headers[key];
            std::string keyStr = key ? [key UTF8String] : "";
            std::string valueStr = value ? [value UTF8String] : "";
            resourceRequest->headerList_.push_back(std::make_pair(keyStr, valueStr));
        }
    }
    
    return resourceRequest;
}
