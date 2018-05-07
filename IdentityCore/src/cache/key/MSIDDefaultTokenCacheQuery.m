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

#import "MSIDDefaultTokenCacheQuery.h"

@implementation MSIDDefaultTokenCacheQuery

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _targetMatchingOptions = Any;
        _credentialType = MSIDTokenTypeOther;
        _matchAnyCredentialType = NO;
    }

    return self;
}

- (void)generateKeyWithExactMatch:(BOOL *)exactMatch
{
    if (self.matchAnyCredentialType)
    {
        [self generateCredentialKeyWithExactMatch:exactMatch];
    }

    switch (self.credentialType)
    {
        case MSIDTokenTypeAccessToken:
        {
            [self generateAccessTokenKeyWithExactMatch:exactMatch];
        }
        case MSIDTokenTypeRefreshToken:
        {
            [self generateRefreshTokenKeyWithExactMatch:exactMatch];
        }
        case MSIDTokenTypeIDToken:
        {
            [self generateIDTokenKeyWithExactMatch:exactMatch];
        }
        default:
            break;
    }
}

- (void)generateAccessTokenKeyWithExactMatch:(BOOL *)exactMatch
{
    [self generateCredentialKeyWithExactMatch:exactMatch];
    self.type = [MSIDDefaultTokenCacheKey tokenType:MSIDTokenTypeAccessToken];
}

- (void)generateCredentialKeyWithExactMatch:(BOOL *)exactMatch
{
    *exactMatch = YES;

    NSString *account = nil;

    if (self.uniqueUserId && self.environment)
    {
        account = [MSIDDefaultTokenCacheKey accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
    }
    else
    {
        *exactMatch = NO;
    }

    NSString *generic = nil;

    if (self.clientId && self.realm)
    {
        generic = [MSIDDefaultTokenCacheKey credentialIdWithType:MSIDTokenTypeAccessToken clientId:self.clientId realm:self.realm];
    }

    NSString *service = nil;

    if (self.clientId && self.realm && self.target && self.targetMatchingOptions == ExactStringMatch)
    {
        service = [self.class serviceWithType:MSIDTokenTypeAccessToken clientID:self.clientId realm:self.realm target:self.target];
    }
    else
    {
        *exactMatch = NO;
    }

    self.account = account;
    self.service = service;
    self.generic = [generic dataUsingEncoding:NSUTF8StringEncoding];
}

- (void)generateRefreshTokenKeyWithExactMatch:(BOOL *)exactMatch
{
    *exactMatch = YES;

    NSString *account = nil;

    if (self.uniqueUserId && self.environment)
    {
        account = [MSIDDefaultTokenCacheKey accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
    }
    else
    {
        *exactMatch = NO;
    }

    NSString *generic = nil;

    if (self.clientId)
    {
        generic = [MSIDDefaultTokenCacheKey credentialIdWithType:MSIDTokenTypeRefreshToken clientId:self.clientId realm:nil];
    }
    else
    {
        *exactMatch = NO;
    }

    NSString *service = nil;

    if (self.clientId)
    {
        service = [MSIDDefaultTokenCacheKey serviceWithType:MSIDTokenTypeRefreshToken clientID:self.clientId realm:nil target:nil];
    }

    self.account = account;
    self.service = service;
    self.generic = [generic dataUsingEncoding:NSUTF8StringEncoding];
    self.type = [MSIDDefaultTokenCacheKey tokenType:MSIDTokenTypeRefreshToken];
}

- (void)generateIDTokenKeyWithExactMatch:(BOOL *)exactMatch
{
    *exactMatch = YES;

    NSString *account = nil;

    if (self.uniqueUserId && self.environment)
    {
        account = [MSIDDefaultTokenCacheKey accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
    }
    else
    {
        *exactMatch = NO;
    }

    NSString *service = nil;
    NSString *generic = nil;

    if (self.clientId && self.realm)
    {
        service = [MSIDDefaultTokenCacheKey serviceWithType:MSIDTokenTypeIDToken clientID:self.clientId realm:self.realm target:nil];
        generic = [MSIDDefaultTokenCacheKey credentialIdWithType:MSIDTokenTypeIDToken clientId:self.clientId realm:self.realm];
    }
    else
    {
        *exactMatch = NO;
    }

    self.account = account;
    self.service = service;
    self.generic = [generic dataUsingEncoding:NSUTF8StringEncoding];
    self.type = [MSIDDefaultTokenCacheKey tokenType:MSIDTokenTypeIDToken];
}

- (void)generateAccountKeyWithExactMatch:(BOOL *)exactMatch
{
    *exactMatch = NO;

    NSString *account = nil;

    if (self.uniqueUserId && self.environment)
    {
        account = [MSIDDefaultTokenCacheKey accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
        *exactMatch = self.realm != nil;
    }

    self.account = account;
    self.service = self.realm;
}

@end
