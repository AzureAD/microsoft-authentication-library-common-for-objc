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

#import "MSIDAutomationTestResult.h"
#import "MSIDAutomationUserInformation.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSIDAutomationSuccessResult : MSIDAutomationTestResult

@property (nonatomic) MSIDAutomationUserInformation *userInformation;
@property (nonatomic) NSString *accessToken;
@property (nonatomic) NSString *refreshToken;
@property (nonatomic) NSString *idToken;
@property (nonatomic) NSString *authority;
@property (nonatomic) NSString *target;
@property (nonatomic) long expiresOnDate;
@property (nonatomic) BOOL isMRRT;

- (instancetype)initWithAction:(NSString *)actionId
                   accessToken:(NSString *)accessToken
                  refreshToken:(NSString *)refreshToken
                       idToken:(NSString *)idToken
                     authority:(NSString *)authority
                        target:(NSString *)target
                 expiresOnDate:(long)expiresOnDate
                        isMRRT:(BOOL)isMRRT
               userInformation:(MSIDAutomationUserInformation *)userInformation
                additionalInfo:(nullable NSDictionary *)additionalInfo;

@end

NS_ASSUME_NONNULL_END
