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

#import "MSIDCredentialWrapper.h"
#import "MSIDTokenType.h"

#define FILL_FIELD(_FIELD, _KEY, _DICT) \
\
    NSString *_FIELD = [_DICT valueForKey:_KEY]; \
    [_DICT removeObjectForKey:_KEY]; \

@implementation MSIDCredentialWrapper

#pragma mark - JSON

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    if (!(self = [super initWithJSONDictionary:json error:error]))
    {
        return nil;
    }
    
    NSMutableDictionary *jsonObject = [json mutableCopy];
    
    FILL_FIELD(clientId, MSID_CLIENT_ID_CACHE_KEY, jsonObject)
    FILL_FIELD(uniqueId, MSID_UNIQUE_ID_CACHE_KEY, jsonObject)
    FILL_FIELD(environment, MSID_ENVIRONMENT_CACHE_KEY, jsonObject)
    FILL_FIELD(realm, MSID_REALM_CACHE_KEY, jsonObject)
    FILL_FIELD(credentialType, MSID_CREDENTIAL_TYPE_CACHE_KEY, jsonObject)
    FILL_FIELD(target, MSID_TARGET_CACHE_KEY, jsonObject)
    FILL_FIELD(cachedAt, MSID_CACHED_AT_CACHE_KEY, jsonObject)
    FILL_FIELD(expiresOn, MSID_EXPIRES_ON_CACHE_KEY, jsonObject)
    FILL_FIELD(extExpiresOn, MSID_EXTENDED_EXPIRES_ON_CACHE_KEY, jsonObject)
    FILL_FIELD(secret, MSID_TOKEN_CACHE_KEY, jsonObject)
    
    MSIDCredential *credential = [[MSIDCredential alloc] initWithUniqueId:uniqueId
                                                              environment:environment
                                                                    realm:realm
                                                           credentialType:[self credentialTypeFromString:credentialType]
                                                                 clientId:clientId
                                                                   target:target
                                                                 cachedAt:[cachedAt integerValue]
                                                                expiresOn:[expiresOn integerValue]
                                                        extendedExpiresOn:[extExpiresOn integerValue]
                                                                   secret:secret
                                                     additionalFieldsJson:@""]; // TODO
    
    _credential = credential;
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    
    // Unique id
    [dictionary setValue:_credential.uniqueId
                  forKey:MSID_UNIQUE_ID_CACHE_KEY];
    
    // Environment
    [dictionary setValue:_credential.environment
                  forKey:MSID_ENVIRONMENT_CACHE_KEY];
    
    // Realm
    [dictionary setValue:_credential.realm
                  forKey:MSID_REALM_CACHE_KEY];
    
    // Credential type
    [dictionary setValue:[self stringFromCredentialType:_credential.credentialType]
                  forKey:MSID_REALM_CACHE_KEY];
    
    // Client ID
    [dictionary setValue:_credential.clientId
                  forKey:MSID_CLIENT_ID_CACHE_KEY];
    
    // Target
    [dictionary setValue:_credential.target
                  forKey:MSID_TARGET_CACHE_KEY];
    
    // Cached At
    [dictionary setValue:[NSString stringWithFormat:@"%lld", _credential.cachedAt]
                  forKey:MSID_CACHED_AT_CACHE_KEY];
    
    // Expires on
    [dictionary setValue:[NSString stringWithFormat:@"%lld", _credential.expiresOn]
                  forKey:MSID_EXPIRES_ON_CACHE_KEY];
    
    // Ext Expires on
    [dictionary setValue:[NSString stringWithFormat:@"%lld", _credential.extendedExpiresOn]
                  forKey:MSID_EXTENDED_EXPIRES_ON_CACHE_KEY];
    
    // Secret
    [dictionary setValue:_credential.secret
                  forKey:MSID_TOKEN_CACHE_KEY];
    
    // TODO: additional fields
    
    return dictionary;
}

#pragma mark - Init

- (instancetype)initWithCredential:(MSIDCredential *)credential
{
    self = [super init];
    
    if (self)
    {
        _credential = credential;
    }
    
    return nil;
}

#pragma mark - Helpers

- (MSIDCredentialType)credentialTypeFromString:(NSString *)string
{
    return MSIDCredentialTypeOIDCIdToken; // TODO
}

- (NSString *)stringFromCredentialType:(MSIDCredentialType)credentialType
{
    return nil; // TODO
}

@end
