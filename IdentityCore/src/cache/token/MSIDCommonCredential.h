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
#import "MSIDCredentialType.h"
#import "MSIDJsonSerializable.h"

@class MSIDClientInfo;

@interface MSIDCommonCredential : NSObject <NSCopying, MSIDJsonSerializable>

// Client id
@property (readwrite, nonnull, strong) NSString *clientId;

// Token type
@property (readwrite) MSIDCredentialType credentialType;

// Token
@property (readwrite, nonnull, strong) NSString *secret;

// Target
@property (readwrite, nullable, strong) NSString *target;

// Realm
@property (readwrite, nullable, strong) NSString *realm;

// Environment
@property (readwrite, nullable, strong) NSString *environment;

// Dates
@property (readwrite, nullable, strong) NSDate *cachedAt;
@property (readwrite, nullable, strong) NSDate *expiresOn;
@property (readwrite, nullable, strong) NSDate *extendedExpiresOn;

// Family ID
@property (readwrite, nullable, strong) NSString *familyId;

// Unique user ID
@property (readwrite, nonnull, strong) NSString *homeAccountId;

// Client Info
@property (readwrite, nullable, strong) MSIDClientInfo *clientInfo;

// Additional fields
@property (readwrite, nullable, strong) NSDictionary *additionalFields;

- (nullable instancetype)initWithType:(MSIDCredentialType)credentialType
                        homeAccountId:(nonnull NSString *)homeAccountId
                          environment:(nonnull NSString *)environment
                                realm:(nullable NSString *)realm
                             clientId:(nullable NSString *)clientId
                               target:(nullable NSString *)target
                             cachedAt:(nullable NSDate *)cachedAt
                            expiresOn:(nullable NSDate *)expiresOn
                    extendedExpiresOn:(nullable NSDate *)extendedExpiresOn
                               secret:(nullable NSString *)secret
                             familyId:(nullable NSString *)familyId
                           clientInfo:(nullable MSIDClientInfo *)clientInfo
                     additionalFields:(nullable NSDictionary *)additionalFields;

- (BOOL)isEqualToItem:(nullable MSIDCommonCredential *)item;

@end
