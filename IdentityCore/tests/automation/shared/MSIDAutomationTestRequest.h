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

#import <Foundation/Foundation.h>
#import "MSIDTestAutomationConfiguration.h"
#import "MSIDConstants.h"
#import "MSIDJsonSerializable.h"

@interface MSIDAutomationTestRequest : NSObject <MSIDJsonSerializable>

@property (nonatomic, strong) NSString *clientId;
@property (nonatomic, strong) NSString *requestResource;
@property (nonatomic, strong) NSString *requestScopes;
@property (nonatomic, strong) NSString *expectedResultScopes;
@property (nonatomic, strong) NSString *extraScopes;
@property (nonatomic, strong) NSString *redirectUri;
@property (nonatomic, strong) NSString *configurationAuthority;
@property (nonatomic, strong) NSString *acquireTokenAuthority;
@property (nonatomic, strong) NSString *expectedResultAuthority;
@property (nonatomic, strong) NSString *cacheAuthority;
@property (nonatomic, strong) NSString *promptBehavior;
@property (nonatomic, strong) NSString *homeAccountIdentifier;
@property (nonatomic, strong) NSString *legacyAccountIdentifier;
@property (nonatomic, strong) NSString *legacyAccountIdentifierType;
@property (nonatomic, strong) NSString *loginHint;
@property (nonatomic, strong) NSString *claims;
@property (nonatomic, strong) MSIDTestAccount *testAccount;
@property (nonatomic) BOOL usePassedWebView;
@property (nonatomic) MSIDWebviewType webViewType;
@property (nonatomic) BOOL validateAuthority;
@property (nonatomic, strong) NSDictionary *extraQueryParameters;
@property (nonatomic, strong) NSDictionary *sliceParameters;
@property (nonatomic) BOOL forceRefresh;
@property (nonatomic, strong) NSString *requestIDP;
@property (nonatomic) BOOL brokerEnabled;
@property (nonatomic) NSArray *clientCapabilities;
@property (nonatomic) NSString *refreshToken;

- (BOOL)usesEmbeddedWebView;

@end
