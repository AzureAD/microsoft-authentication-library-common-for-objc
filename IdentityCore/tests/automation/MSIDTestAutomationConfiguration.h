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

@class MSIDAutomationTestRequest;

@interface MSIDTestAccount : NSObject <NSCopying>

@property (nonatomic) NSString *account;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *password;
@property (nonatomic) NSString *keyvaultName;
@property (nonatomic) NSString *labName;
@property (nonatomic) NSString *homeTenantId;
@property (nonatomic) NSString *homeObjectId;
@property (nonatomic) NSString *targetTenantId;
@property (nonatomic) NSString *tenantName;

- (instancetype)initWithJSONResponse:(NSDictionary *)response;
- (NSString *)passwordFromData:(NSData *)responseData;
- (NSString *)homeAccountId;

@end

@interface MSIDTestAutomationConfiguration : NSObject

@property (readonly) NSString *authority;
@property (nonatomic) NSString *authorityHost;
@property (nonatomic) NSString *clientId;
@property (nonatomic) NSString *redirectUri;
@property (nonatomic) NSString *resource;
@property (nonatomic) NSArray<MSIDTestAccount *> *accounts;
@property (nonatomic) NSDictionary *policies;
@property (nonatomic, class) NSString *defaultRegisteredScheme;

- (instancetype)initWithJSONDictionary:(NSDictionary *)response;
- (instancetype)initWithJSONResponseData:(NSData *)response;
- (void)addAdditionalAccount:(MSIDTestAccount *)additionalAccount;
- (NSString *)authorityWithTenantId:(NSString *)tenantId;
- (NSString *)redirectUriWithPrefix:(NSString *)redirectPrefix;

@end
