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
#import "MSIDClientInfo.h"
#import "MSIDCredentialCacheItem.h"

@class MSIDTokenResponse;
@class MSIDConfiguration;

/*!
 This is the base class for all possible tokens.
 It's meant to be subclassed to provide additional fields.
 */

@interface MSIDBaseToken : NSObject <NSCopying>
{
    NSURL *_authority;
    NSString *_clientId;
    NSString *_homeAccountId;
    MSIDClientInfo *_clientInfo;
    NSDictionary *_additionalServerInfo;
}

@property (readonly) MSIDCredentialType credentialType;
@property (readwrite) NSURL *authority;
/*
 'storageAuthority' is used only for latter token deletion.
 We can not use 'authority' because cache item could be saved with
'preferred authority' and it might not be equal to provided 'authority'.
 */
@property (readwrite) NSURL *storageAuthority;
@property (readwrite) NSString *clientId;
@property (readwrite) NSString *homeAccountId;

@property (readwrite) MSIDClientInfo *clientInfo;
@property (readwrite) NSDictionary *additionalServerInfo;
@property (readonly) NSString *primaryUserId;

- (instancetype)initWithTokenCacheItem:(MSIDCredentialCacheItem *)tokenCacheItem;
- (MSIDCredentialCacheItem *)tokenCacheItem;

- (BOOL)supportsCredentialType:(MSIDCredentialType)credentialType;
- (BOOL)isEqualToItem:(MSIDBaseToken *)item;

@end
