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
        _matchAnyCredentialType = NO;
    }

    return self;
}

- (NSString *)account
{
    if (self.uniqueUserId && self.environment)
    {
        return [self accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
    }

    return nil;
}

- (NSString *)service
{
    if (self.matchAnyCredentialType
        || self.credentialType == MSIDTokenTypeAccessToken)
    {
        if (self.clientId
            && self.realm
            && self.target
            && (self.targetMatchingOptions == ExactStringMatch || self.targetMatchingOptions == Any))
        {
            return [self serviceWithType:self.credentialType clientID:self.clientId realm:self.realm target:self.target];
        }
        return nil;
    }
    else
    {
        switch (self.credentialType)
        {
            case MSIDTokenTypeRefreshToken:
            {
                if (self.clientId)
                {
                    return [self serviceWithType:self.credentialType clientID:self.clientId realm:nil target:nil];
                }
                break;
            }
            case MSIDTokenTypeIDToken:
            {
                if (self.clientId && self.realm)
                {
                    return [self serviceWithType:MSIDTokenTypeIDToken clientID:self.clientId realm:self.realm target:nil];
                }

                break;
            }
            default:
                break;
        }
    }

    return nil;
}

- (NSData *)generic
{
    NSString *genericString = nil;

    if (self.credentialType == MSIDTokenTypeRefreshToken
        && self.clientId)
    {
        genericString = [self credentialIdWithType:self.credentialType clientId:self.clientId realm:self.realm];
    }
    else if (self.clientId && self.realm)
    {
        genericString = [self credentialIdWithType:self.credentialType clientId:self.clientId realm:self.realm];
    }

    return [genericString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSNumber *)type
{
    if (self.matchAnyCredentialType)
    {
        return nil;
    }

    return [self credentialTypeNumber:self.credentialType];
}

- (BOOL)exactMatch
{
    if (!self.environment
        || !self.uniqueUserId
        || !self.clientId)
    {
        return NO;
    }

    if (self.credentialType == MSIDTokenTypeAccessToken)
    {
        if (!self.realm
            || !self.target
            || self.targetMatchingOptions != ExactStringMatch)
        {
            return NO;
        }
    }

    if (self.credentialType == MSIDTokenTypeIDToken
        && !self.realm)
    {
        return NO;
    }

    return YES;
}

@end
