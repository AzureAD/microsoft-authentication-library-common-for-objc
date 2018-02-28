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

@class MSIDAccountCacheItem;
@class MSIDRequestParameters;
@class MSIDTokenResponse;

@interface MSIDAccount : NSObject <NSCopying>

// Legacy user identifier
@property (readwrite) NSString *legacyUserId;
@property (readwrite) NSString *utid;
@property (readwrite) NSString *uid;

// Primary user identifier
@property (readonly) NSString *userIdentifier;

@property (readonly) MSIDAccountType accountType;

@property (readonly) NSString *username;
@property (readonly) NSString *firstName;
@property (readonly) NSString *lastName;
@property (readonly) NSDictionary *additionalFields;

@property (readonly) NSURL *authority;

- (instancetype)initWithLegacyUserId:(NSString *)legacyUserId
                                utid:(NSString *)utid
                                 uid:(NSString *)uid;

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams;

- (instancetype)initWithAccountCacheItem:(MSIDAccountCacheItem *)cacheItem;

- (MSIDAccountCacheItem *)accountCacheItem;

@end
