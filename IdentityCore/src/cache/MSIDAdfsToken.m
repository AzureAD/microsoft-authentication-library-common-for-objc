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

#import "MSIDAdfsToken.h"

@implementation MSIDAdfsToken

- (BOOL)isEqualToToken:(MSIDAdfsToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = YES;
    result &= [super isEqualToToken:token];
    result &= (!self.singleResourceRefreshToken && !token.singleResourceRefreshToken) || [self.singleResourceRefreshToken isEqualToString:token.singleResourceRefreshToken];
    
    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }
    
    if (![object isKindOfClass:MSIDAdfsToken.class])
    {
        return NO;
    }
    
    return [self isEqualToToken:(MSIDAdfsToken *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash ^= self.singleResourceRefreshToken.hash;
    
    return hash;
}

#pragma mark - NSSecureCoding

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
   
    _singleResourceRefreshToken = [coder decodeObjectOfClass:[NSString class] forKey:@"refreshToken"];
    _tokenType = MSIDTokenTypeAdfsUserToken;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_singleResourceRefreshToken forKey:@"refreshToken"];
}

#pragma mark - Init

- (instancetype)initWithTokenResponse:(MSIDTokenResponse *)response
                              request:(MSIDRequestParameters *)requestParams
                            tokenType:(MSIDTokenType)tokenType
{
    self = [super initWithTokenResponse:response
                                request:requestParams
                              tokenType:tokenType];
    
    if (self)
    {
        _singleResourceRefreshToken = response.refreshToken;
    }
    
    return self;
}

@end
