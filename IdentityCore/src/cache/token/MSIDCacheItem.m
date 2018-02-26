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

#import "MSIDCacheItem.h"

@interface MSIDCacheItem()

@property (readwrite) NSDictionary *json;

@end

@implementation MSIDCacheItem

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    NSString *authorityString = [coder decodeObjectOfClass:[NSString class] forKey:@"authority"];
    
    if (authorityString)
    {
        _authority = [NSURL URLWithString:authorityString];
    }
    
    _additionalInfo = [coder decodeObjectOfClass:[NSDictionary class] forKey:@"additionalServer"];
    _username = [coder decodeObjectOfClass:[NSString class] forKey:@"username"];
    
    NSString *rawClientInfo = [coder decodeObjectOfClass:[NSString class] forKey:@"clientInfo"];
    [self fillClientInfo:rawClientInfo];
    
    _uniqueUserId = _clientInfo.userIdentifier;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.authority.absoluteString forKey:@"authority"];
    
    [coder encodeObject:self.clientInfo forKey:@"clientInfo"];
    [coder encodeObject:self.additionalInfo forKey:@"additionalServer"];
    
    // Backward compatibility with ADAL.
    [coder encodeObject:@"Bearer" forKey:@"accessTokenType"];
    [coder encodeObject:[NSMutableDictionary dictionary] forKey:@"additionalClient"];
    [coder encodeObject:self.username forKey:@"username"];
}

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _json = json;
    
    // Unique ID
    _uniqueUserId = json[MSID_UNIQUE_ID_CACHE_KEY];
    
    // Environment
    _environment = json[MSID_ENVIRONMENT_CACHE_KEY];
    
    /* Optional fields */
    NSString *rawClientInfo = json[MSID_OAUTH2_CLIENT_INFO];
    [self fillClientInfo:rawClientInfo];
    
    // Additional info
    _additionalInfo = json[MSID_ADDITIONAL_INFO_CACHE_KEY];
    
    // Username
    _username = json[MSID_USERNAME_CACHE_KEY];
    
    // Authority
    NSString *authorityString = json[MSID_AUTHORITY_CACHE_KEY];
    
    if (authorityString)
    {
        _authority = [NSURL URLWithString:authorityString];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    if (_json)
    {
        [dictionary addEntriesFromDictionary:_json];
    }
    
    /* Mandatory fields */
    
    // Unique id
    dictionary[MSID_UNIQUE_ID_CACHE_KEY] = _uniqueUserId;
    
    // Environment
    dictionary[MSID_ENVIRONMENT_CACHE_KEY] = _environment;
    
    /* Optional fields */
    
    // Client info
    dictionary[MSID_CLIENT_INFO_CACHE_KEY] = _clientInfo.rawClientInfo;
    
    // Additional info
    dictionary[MSID_ADDITIONAL_INFO_CACHE_KEY] = _additionalInfo;
    
    // Username
    dictionary[MSID_USERNAME_CACHE_KEY] = _username;
    
    // Authority
    dictionary[MSID_AUTHORITY_CACHE_KEY] = _authority.absoluteString;
    
    return dictionary;
}

#pragma mark - Helpers

- (void)fillClientInfo:(NSString *)rawClientInfo
{
    if (!rawClientInfo)
    {
        return;
    }
    
    NSError *error = nil;
    _clientInfo = [[MSIDClientInfo alloc] initWithRawClientInfo:rawClientInfo error:&error];
    
    if (error)
    {
        MSID_LOG_ERROR(nil, @"Client info is corrupted.");
    }
    
    _uniqueUserId = _clientInfo.userIdentifier;
}

@end
