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
#import "MSIDCacheItem.h"
#import "MSIDAccountType.h"
#import "MSIDUserIdentifiers.h"

@class MSIDAccountCacheItem;
@class MSIDRequestParameters;
@class MSIDTokenResponse;

@interface MSIDAccount : NSObject <NSCopying, MSIDUserIdentifiers>

// Primary user identifier
@property (readwrite) NSString *uniqueUserId;

// Legacy user identifier
@property (readwrite) NSString *legacyUserId;
@property (readwrite) MSIDAccountType accountType;
@property (readwrite) NSString *environment;

@property (readwrite) NSString *username;
@property (readwrite) NSString *givenName;
@property (readwrite) NSString *middleName;
@property (readwrite) NSString *familyName;
@property (readwrite) NSString *name;

@property (readwrite) MSIDClientInfo *clientInfo;

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                        clientInfo:(MSIDClientInfo *)clientInfo;

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                        uniqueUserId:(NSString *)userIdentifier;

- (instancetype)initWithAccountCacheItem:(MSIDAccountCacheItem *)cacheItem;

- (MSIDAccountCacheItem *)accountCacheItem;

@end
