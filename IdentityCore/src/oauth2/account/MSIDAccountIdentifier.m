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

#import "MSIDAccountIdentifier.h"
#import "MSIDClientInfo.h"

@implementation MSIDAccountIdentifier

#pragma mark - Init

- (instancetype)initWithLegacyAccountId:(NSString *)legacyAccountId
                             clientInfo:(MSIDClientInfo *)clientInfo
{
    return [self initWithLegacyAccountId:legacyAccountId
                           homeAccountId:clientInfo.accountIdentifier];
}

- (instancetype)initWithLegacyAccountId:(NSString *)legacyAccountId
                          homeAccountId:(NSString *)homeAccountId
{
    if (!(self = [self init]))
    {
        return nil;
    }

    _legacyAccountId = legacyAccountId;
    _homeAccountId = homeAccountId;

    return self;
}

#pragma mark - Copy

- (instancetype)copyWithZone:(NSZone *)zone
{
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier allocWithZone:zone] init];
    account.legacyAccountId = [_legacyAccountId copyWithZone:zone];
    account.homeAccountId = [_homeAccountId copyWithZone:zone];
    return account;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDAccountIdentifier.class])
    {
        return NO;
    }

    return [self isEqualToItem:(MSIDAccountIdentifier *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = 0;
    hash = hash * 31 + self.homeAccountId.hash;
    hash = hash * 31 + self.legacyAccountId.hash;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDAccountIdentifier *)account
{
    if (!account)
    {
        return NO;
    }

    BOOL result = YES;
    result &= (!self.homeAccountId && !account.homeAccountId) || [self.homeAccountId isEqualToString:account.homeAccountId];
    result &= (!self.legacyAccountId && !account.legacyAccountId) || [self.legacyAccountId isEqualToString:account.legacyAccountId];
    return result;
}

@end
