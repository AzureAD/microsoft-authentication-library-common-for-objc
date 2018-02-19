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

#import "MSIDBaseToken.h"
#import "MSIDUserInformation.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDTelemetryEventStrings.h"

@implementation MSIDBaseToken

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    MSIDBaseToken *item = [super copyWithZone:zone];
    item->_tokenType = _tokenType;
    
    return item;
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
    
    return [self isEqualToItem:(MSIDBaseCacheItem *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = [super hash];
    hash = hash * 31 + self.tokenType;
    return hash;
}

- (BOOL)isEqualToItem:(MSIDBaseToken *)token
{
    if (!token)
    {
        return NO;
    }
    
    BOOL result = [super isEqualToItem:token];
    result &= self.tokenType == token.tokenType;
    
    return result;
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    /* Mandatory fields */
    NSString *credentialType = json[MSID_CREDENTIAL_TYPE_CACHE_KEY];
    
    if (credentialType
        && ![[MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType] isEqualToString:credentialType])
    {
        return nil;
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [[super jsonDictionary] mutableCopy];
    
    /* Mandatory fields */
    
    // Credential type
    NSString *credentialType = [MSIDTokenTypeHelpers tokenTypeAsString:self.tokenType];
    [dictionary setValue:credentialType
                  forKey:MSID_CREDENTIAL_TYPE_CACHE_KEY];
    
    return dictionary;
}

#pragma mark - Token type

- (MSIDTokenType)tokenType
{
    return MSIDTokenTypeOther;
}

@end
