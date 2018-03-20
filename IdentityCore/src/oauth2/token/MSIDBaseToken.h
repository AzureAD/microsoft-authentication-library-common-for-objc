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
#import "MSIDTokenType.h"
#import "MSIDClientInfo.h"
#import "MSIDTokenCacheItem.h"

@class MSIDTokenResponse;
@class MSIDRequestParameters;

/*!
 This is the base class for all possible tokens.
 It's meant to be subclassed to provide additional fields.
 */

@interface MSIDBaseToken : NSObject <NSCopying>
{
    NSURL *_authority;
    NSString *_clientId;
    NSString *_uniqueUserId;
    MSIDClientInfo *_clientInfo;
    NSDictionary *_additionaServerlInfo;
    NSString *_username;
}

@property (readonly) MSIDTokenType tokenType;
@property (readwrite) NSURL *authority;
@property (readwrite) NSString *clientId;

@property (readonly) MSIDClientInfo *clientInfo;
@property (readonly) NSDictionary *additionaServerlInfo;
@property (readonly) NSDictionary *additionalClientInfo;

// User info
@property (readonly) NSString *uniqueUserId;
@property (readonly) NSString *username;

- (instancetype)initWithTokenCacheItem:(MSIDTokenCacheItem *)tokenCacheItem;

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams;

- (MSIDTokenCacheItem *)tokenCacheItem;

- (BOOL)supportsTokenType:(MSIDTokenType)tokenType;
- (BOOL)isEqualToItem:(MSIDBaseToken *)item;

@end
