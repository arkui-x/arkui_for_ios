//
//  AceWebErrorReceiveObject.hpp
//  AceWeb
//
//  Created by liuxiao on 2023/9/17.
//

#ifndef AceWebErrorReceiveInfoObject_hpp
#define AceWebErrorReceiveInfoObject_hpp
#include <string>

#include <iostream>
class AceWebErrorReceiveInfoObject {
public:
    AceWebErrorReceiveInfoObject(const std::string& url,const std::string& info, long code):
                requestUrl_(url), errorInfo_(info), errorCode_(code) {}
    std::string GetRequestUrl();
    std::string GetErrorInfo();
    long GetErrorCode();
private:
    std::string requestUrl_;
    std::string errorInfo_ ;
    long errorCode_ = 0;
};

#endif /* AceWebErrorReceiveInfoObject_hpp */
