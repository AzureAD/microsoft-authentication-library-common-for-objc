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

#import "MSIDMacAppCredential.h"

@implementation MSIDMacAppCredential

- (nullable id)initWithAccount:(nullable NSString *)account
                       service:(nullable NSString *)service
                       generic:(nullable NSData *)generic
                          type:(nullable NSNumber *)type
           credentialCacheItem:(MSIDCredentialCacheItem *)cacheItem
{
    self = [super init];
    if (self)
    {
        _acct = account;
        _svce = service;
        _gena = generic;
        _type = type;
        _cacheItem = cacheItem;
    }
    
    return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:self.class])
    {
        return NO;
    }
    
    return [self isEqualToItem:(MSIDMacAppCredential *)object];
}

- (BOOL)isEqualToItem:(MSIDMacAppCredential *)item
{
    BOOL result = YES;
    result &= (!self.acct && !item.acct) || [self.acct isEqualToString:item.acct];
    result &= (!self.svce && !item.svce) || [self.svce isEqualToString:item.svce];
    result &= (!self.gena && !item.gena) || [self.gena isEqualToData:item.gena];
    result &= (!self.type && !item.type) || [self.type isEqualToNumber:item.type];
    return result;
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.acct.hash;
    hash = hash * 31 + self.svce.hash;
    hash = hash * 31 + self.gena.hash;
    hash = hash * 31 + self.type.hash;
    return hash;
}


@end
