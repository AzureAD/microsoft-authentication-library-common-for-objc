// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDAutomationErrorResult.h"

NSString * const MSIDAutomationErrorDescriptionKey = @"MSIDAutomationErrorDescriptionKey";

@implementation MSIDAutomationErrorResult

- (instancetype)initWithAction:(NSString *)actionId
                         error:(NSError *)error
                additionalInfo:(NSDictionary *)additionalInfo
{
    self = [super initWithAction:actionId success:NO additionalInfo:additionalInfo];

    if (self)
    {
        _errorCode = error.code;
        _errorDomain = error.domain;
        _errorDescription = error.description;
        _errorUserInfo = [self userInfoDictionary:error];
    }

    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError **)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        _errorCode = [json[@"error_code"] integerValue];
        _errorDomain = json[@"error_domain"];
        _errorDescription = json[@"error_description"];
        _errorUserInfo = json[@"user_info"];
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [[super jsonDictionary] mutableCopy];
    json[@"error_code"] = @(self.errorCode);
    json[@"error_domain"] = self.errorDomain;
    json[@"error_description"] = self.errorDescription;
    json[@"user_info"] = self.errorUserInfo;
    return json;
}

- (NSDictionary *)userInfoDictionary:(NSError *)error
{
    NSMutableDictionary *userInfo = [NSMutableDictionary new];

    for (NSString *userInfoKey in error.userInfo.allKeys)
    {
        id userInfoObj = error.userInfo[userInfoKey];

        if ([userInfoObj isKindOfClass:[NSString class]]
            || [userInfoObj isKindOfClass:[NSArray class]]
            || [userInfoObj isKindOfClass:[NSDictionary class]])
        {
            userInfo[userInfoKey] = userInfoObj;
        }
        else
        {
            userInfo[userInfoKey] = [userInfoObj description];
        }
    }

    return userInfo;
}

@end
