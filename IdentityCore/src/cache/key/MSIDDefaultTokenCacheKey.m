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
static NSInteger kAccountTypePrefix = 1000;
static NSInteger kTokenTypePrefix = 2000;

@implementation MSIDDefaultTokenCacheKey

#pragma mark - Helpers

// kSecAttrService - (<credential_type>-<client_id>-<realm>-<target>)
+ (NSString *)serviceWithType:(MSIDTokenType)type
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
+ (NSString *)credentialIdWithType:(MSIDTokenType)type
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
+ (NSString *)accountIdWithUniqueUserId:(NSString *)uniqueId
                            environment:(NSString *)environment
{
    uniqueId = uniqueId.msidTrimmedString.lowercaseString;

    return [NSString stringWithFormat:@"%@%@%@",
            uniqueId, keyDelimiter, environment];
}

+ (NSNumber *)accountType:(MSIDAccountType)accountType
{
    return @(kAccountTypePrefix + accountType);
}

+ (NSNumber *)tokenType:(MSIDTokenType)tokenType
{
    return @(kTokenTypePrefix + tokenType);
}

#pragma mark - Internal

+ (MSIDDefaultTokenCacheKey *)keyForAccessTokensWithUniqueUserId:(NSString *)userId
                                                     environment:(NSString *)environment
                                                        clientId:(NSString *)clientId
                                                           realm:(NSString *)realm
                                                          target:(NSString *)target
{
    return [self keyForCredentialWithUniqueUserId:userId
                                      environment:environment
                                         clientId:clientId
                                            realm:realm
                                           target:target
                                             type:MSIDTokenTypeAccessToken];
}

#pragma mark - Default

+ (MSIDDefaultTokenCacheKey *)keyForCredentialWithUniqueUserId:(nonnull NSString *)uniqueUserId
                                                   environment:(nonnull NSString *)environment
                                                      clientId:(nonnull NSString *)clientId
                                                         realm:(nullable NSString *)realm
                                                        target:(nullable NSString *)target
                                                          type:(MSIDTokenType)type
{
    // kSecAttrAccount - account_id (<unique_id>-<environment>)
    // kSecAttrService - credential_id+target (<credential_type>-<client_id>-<realm>-<target>)
    // kSecAttrGeneric - credential_id (<credential_type>-<client_id>-<realm>)
    // kSecAttrType - type

    NSString *account = [self.class accountIdWithUniqueUserId:uniqueUserId environment:environment];
    NSString *generic = [self.class credentialIdWithType:type clientId:clientId realm:realm];
    NSString *service = [self.class serviceWithType:type clientID:clientId realm:realm target:target];
    NSNumber *credentialType = [self tokenType:type];

    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:credentialType];
}

+ (MSIDDefaultTokenCacheKey *)queryForCredentialsWithUniqueUserId:(nullable NSString *)uniqueUserId
                                                      environment:(nullable NSString *)environment
                                                         clientId:(nullable NSString *)clientId
                                                            realm:(nullable NSString *)realm
                                                           target:(nullable NSString *)target
                                                             type:(MSIDTokenType)type
{
    switch (type)
    {
        case MSIDTokenTypeAccessToken:
        {
            return [self queryForAllAccessTokensWithUniqueUserId:uniqueUserId
                                                     environment:environment
                                                        clientId:clientId
                                                           realm:realm
                                                          target:target];
        }
        case MSIDTokenTypeRefreshToken:
        {
            return [self queryForAllRefreshTokensWithUniqueUserId:uniqueUserId
                                                      environment:environment
                                                         clientId:clientId];
        }
        case MSIDTokenTypeIDToken:
        {
            return [self queryForAllIDTokensWithUniqueUserId:uniqueUserId
                                                 environment:environment
                                                       realm:realm
                                                    clientId:clientId];
        }
        default:
            break;
    }

    return nil;
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokensWithUniqueUserId:(nullable NSString *)userId
                                                          environment:(nullable NSString *)environment
                                                             clientId:(nullable NSString *)clientId
                                                                realm:(nullable NSString *)realm
                                                               target:(nullable NSString *)target
{
    NSString *account = nil;

    if (userId && environment)
    {
        account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    }

    NSString *generic = nil;

    if (clientId && realm)
    {
        generic = [self.class credentialIdWithType:MSIDTokenTypeAccessToken clientId:clientId realm:realm];
    }

    NSString *service = nil;

    if (clientId && realm && target)
    {
        service = [self.class serviceWithType:MSIDTokenTypeAccessToken clientID:clientId realm:realm target:target];
    }

    NSNumber *type = [self tokenType:MSIDTokenTypeAccessToken];

    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllRefreshTokensWithUniqueUserId:(nullable NSString *)userId
                                                           environment:(nullable NSString *)environment
                                                              clientId:(nullable NSString *)clientId
{
    NSString *account = nil;

    if (userId && environment)
    {
        account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    }

    NSString *generic = nil;

    if (clientId)
    {
        generic = [self.class credentialIdWithType:MSIDTokenTypeRefreshToken clientId:clientId realm:nil];
    }

    NSString *service = nil;

    if (clientId)
    {
        service = [self.class serviceWithType:MSIDTokenTypeRefreshToken clientID:clientId realm:nil target:nil];
    }

    NSNumber *type = [self tokenType:MSIDTokenTypeRefreshToken];

    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllIDTokensWithUniqueUserId:(nullable NSString *)userId
                                                      environment:(nullable NSString *)environment
                                                            realm:(nullable NSString *)realm
                                                         clientId:(nullable NSString *)clientId
{
    NSString *account = nil;

    if (userId && environment)
    {
        account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    }

    NSString *service = nil;

    if (clientId && realm)
    {
        service = [self.class serviceWithType:MSIDTokenTypeIDToken clientID:clientId realm:realm target:nil];
    }

    NSString *generic = nil;

    if (clientId && realm)
    {
        generic = [self credentialIdWithType:MSIDTokenTypeIDToken clientId:clientId realm:realm];
    }

    NSNumber *type = [self tokenType:MSIDTokenTypeIDToken];

    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAccountsWithUniqueUserId:(nullable NSString *)userId
                                                   environment:(nullable NSString *)environment
                                                         realm:(nullable NSString *)realm
{
    NSString *account = nil;

    if (userId && environment)
    {
        account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    }

    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:realm
                                                     generic:nil
                                                        type:nil];
}

// TODO: check if all are necessary

+ (MSIDDefaultTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
                                                    environment:(NSString *)environment
                                                       clientId:(NSString *)clientId
                                                          realm:(NSString *)realm
                                                         target:(NSString *)target
{
    return [self keyForAccessTokensWithUniqueUserId:userId
                                        environment:environment
                                           clientId:clientId
                                              realm:realm
                                             target:target];
}

+ (MSIDDefaultTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
                                                      authority:(NSURL *)authority
                                                       clientId:(NSString *)clientId
                                                         scopes:(NSOrderedSet<NSString *> *)scopes
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *tenant = authority.msidTenant;
    
    return [self keyForAccessTokenWithUniqueUserId:userId
                                       environment:environment
                                          clientId:clientId
                                             realm:tenant
                                            target:scopes.msidToString];
}

+ (MSIDDefaultTokenCacheKey *)keyForIDTokenWithUniqueUserId:(NSString *)userId
                                                  authority:(NSURL *)authority
                                                   clientId:(NSString *)clientId
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *tenant = authority.msidTenant;
    
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *service = [self.class serviceWithType:MSIDTokenTypeIDToken clientID:clientId realm:tenant target:nil];
    NSNumber *type = [self tokenType:MSIDTokenTypeIDToken];
    NSString *generic = [self credentialIdWithType:MSIDTokenTypeIDToken clientId:clientId realm:tenant];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)keyForAccountWithUniqueUserId:(NSString *)userId
                                                  authority:(NSURL *)authority
                                                   username:(NSString *)username
                                                accountType:(MSIDAccountType)accountType
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *service = authority.msidTenant;
    NSNumber *type = [self accountType:accountType];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[username.msidTrimmedString.lowercaseString dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                            authority:(NSURL *)authority
                                                             clientId:(NSString *)clientId
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *tenant = authority.msidTenant;
    
    return [self queryForAllAccessTokensWithUniqueUserId:userId
                                             environment:environment
                                                clientId:clientId
                                                   realm:tenant];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                          environment:(NSString *)environment
{
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSNumber *type = [self tokenType:MSIDTokenTypeAccessToken];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:nil
                                                     generic:nil
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllTokensWithUniqueUserId:(NSString *)userId
                                                    environment:(NSString *)environment
{
    assert(userId);
    assert(environment);
    
    if (!userId || !environment) return nil;
    
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:nil
                                                     generic:nil
                                                        type:nil];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokens
{
    NSNumber *type = [self tokenType:MSIDTokenTypeAccessToken];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:nil
                                                     generic:nil
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccountsWithType:(MSIDAccountType)accountType
{
    NSNumber *type = [self accountType:accountType];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:nil
                                                     generic:nil
                                                        type:type];
}

// rt with uid and utid
+ (MSIDDefaultTokenCacheKey *)keyForRefreshTokenWithUniqueUserId:(NSString *)userId
                                                     environment:(NSString *)environment
                                                        clientId:(NSString *)clientId
{
    NSString *service = [self.class serviceWithType:MSIDTokenTypeRefreshToken clientID:clientId realm:nil target:nil];
    NSString *account = [self accountIdWithUniqueUserId:userId environment:environment];
    NSNumber *type = [self tokenType:MSIDTokenTypeRefreshToken];
    NSString *generic = [self credentialIdWithType:MSIDTokenTypeRefreshToken clientId:clientId realm:nil];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllTokensWithType:(MSIDTokenType)type
{
    NSNumber *tokenType = [self tokenType:type];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:nil
                                                     generic:nil
                                                        type:tokenType];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllRefreshTokensWithClientId:(NSString *)clientId
{
    NSString *service = [self.class serviceWithType:MSIDTokenTypeRefreshToken clientID:clientId realm:nil target:nil];
    NSNumber *type = [self tokenType:MSIDTokenTypeRefreshToken];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:service
                                                     generic:nil
                                                        type:type];
}

+ (MSIDDefaultTokenCacheKey *)queryForIDTokensWithUniqueUserId:(NSString *)userId
                                                   environment:(NSString *)environment
{
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSNumber *type = [self tokenType:MSIDTokenTypeIDToken];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:nil
                                                     generic:nil
                                                        type:type];
}

@end
