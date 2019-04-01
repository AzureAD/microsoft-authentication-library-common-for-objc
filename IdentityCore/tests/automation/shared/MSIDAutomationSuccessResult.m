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

#import "MSIDAutomationSuccessResult.h"

@implementation MSIDAutomationSuccessResult

- (instancetype)initWithAction:(NSString *)actionId
                   accessToken:(NSString *)accessToken
                  refreshToken:(NSString *)refreshToken
                       idToken:(NSString *)idToken
                     authority:(NSString *)authority
                        target:(NSString *)target
                 expiresOnDate:(long)expiresOnDate
                        isMRRT:(BOOL)isMRRT
               userInformation:(MSIDAutomationUserInformation *)userInformation
                additionalInfo:(nullable NSDictionary *)additionalInfo
{
    self = [super initWithAction:actionId success:YES additionalInfo:additionalInfo];

    if (self)
    {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _idToken = idToken;
        _authority = authority;
        _target = target;
        _expiresOnDate = expiresOnDate;
        _isMRRT = isMRRT;
        _userInformation = userInformation;
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *allInfo = [[super jsonDictionary] mutableCopy];

    allInfo[@"access_token"] = self.accessToken;
    allInfo[@"refresh_token"] = self.refreshToken;
    allInfo[@"id_token"] = self.idToken;
    allInfo[@"authority"] = self.authority;
    allInfo[@"target"] = self.target;
    allInfo[@"expires_on"] = @(self.expiresOnDate);
    allInfo[@"is_mrrt"] = @(self.isMRRT);
    allInfo[@"user_info"] = [self.userInformation jsonDictionary];

    return allInfo;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing *)error
{
    self = [super initWithJSONDictionary:json error:error];

    if (self)
    {
        _accessToken = json[@"access_token"];
        _refreshToken = json[@"refresh_token"];
        _idToken = json[@"id_token"];
        _authority = json[@"authority"];
        _target = json[@"target"];
        _expiresOnDate = [json[@"expires_on"] integerValue];
        _isMRRT = [json[@"is_mrrt"] boolValue];
        _userInformation = [[MSIDAutomationUserInformation alloc] initWithJSONDictionary:json[@"user_info"] error:nil];
    }

    return self;
}

@end
