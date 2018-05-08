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

#import "MSIDDefaultTokenCacheKey.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDTokenType.h"
#import "NSURL+MSIDExtensions.h"

static NSString *keyDelimiter = @"-";
static NSInteger kCredentialTypePrefix = 2000;

@implementation MSIDDefaultTokenCacheKey

#pragma mark - Helpers

// kSecAttrService - (<credential_type>-<client_id>-<realm>-<target>)
- (NSString *)serviceWithType:(MSIDTokenType)type
                     clientID:(NSString *)clientId
                        realm:(NSString *)realm
                       target:(NSString *)target
{
    realm = realm.msidTrimmedString.lowercaseString;
    clientId = clientId.msidTrimmedString.lowercaseString;
    target = target.msidTrimmedString.lowercaseString;

    NSString *credentialId = [self credentialIdWithType:type clientId:clientId realm:realm];
    NSString *service = [NSString stringWithFormat:@"%@%@%@",
                         credentialId,
                         keyDelimiter,
                         (target ? target : @"")];
    return service;
}

// credential_id - (<credential_type>-<client_id>-<realm>)
- (NSString *)credentialIdWithType:(MSIDTokenType)type
                          clientId:(NSString *)clientId
                             realm:(NSString *)realm
{
    realm = realm.msidTrimmedString.lowercaseString;
    clientId = clientId.msidTrimmedString.lowercaseString;

    NSString *credentialType = [MSIDTokenTypeHelpers tokenTypeAsString:type];
    
    return [NSString stringWithFormat:@"%@%@%@%@%@",
            credentialType, keyDelimiter, clientId,
            keyDelimiter,
            (realm ? realm : @"")];
}

// kSecAttrAccount - account_id (<unique_id>-<environment>)
- (NSString *)accountIdWithUniqueUserId:(NSString *)uniqueId
                            environment:(NSString *)environment
{
    uniqueId = uniqueId.msidTrimmedString.lowercaseString;

    return [NSString stringWithFormat:@"%@%@%@",
            uniqueId, keyDelimiter, environment];
}

- (NSNumber *)credentialTypeNumber:(MSIDTokenType)credentialType
{
    return @(kCredentialTypePrefix + credentialType);
}

#pragma mark - Public

- (instancetype)initWithUniqueUserId:(NSString *)uniqueUserId
                         environment:(NSString *)environment
{
    self = [super init];

    if (self)
    {
        _uniqueUserId = uniqueUserId;
        _environment = environment;
    }

    return self;
}

- (NSData *)generic
{
    return [[self credentialIdWithType:self.credentialType clientId:self.clientId realm:self.realm] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSNumber *)type
{
    return [self credentialTypeNumber:self.credentialType];
}

- (NSString *)account
{
    return [self accountIdWithUniqueUserId:self.uniqueUserId environment:self.environment];
}

- (NSString *)service
{
    return [self serviceWithType:self.credentialType clientID:self.clientId realm:self.realm target:self.target];
}

@end
