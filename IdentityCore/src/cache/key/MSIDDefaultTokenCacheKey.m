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

@implementation MSIDDefaultTokenCacheKey

#pragma mark - Helpers

// kSecAttrService - (<credential_type>-<client_id>-<realm>-<target>)
+ (NSString *)serviceWithType:(MSIDTokenType)type
                     clientID:(NSString *)clientId
                        realm:(NSString *)realm
                       target:(NSString *)target
{
    NSString *credentialId = [self credentialIdWithType:type clientId:clientId realm:realm];
    NSString *service = [NSString stringWithFormat:@"%@%@%@",
                         credentialId,
                         (target ? keyDelimiter : @""),
                         (target ? target : @"")];
    return service;
}

// credential_id - (<credential_type>-<client_id>-<realm>)
+ (NSString *)credentialIdWithType:(MSIDTokenType)type
                          clientId:(NSString *)clientId
                             realm:(NSString *)realm
{
    NSString *credentialType = [MSIDTokenTypeHelpers tokenTypeAsString:type];
    
    return [NSString stringWithFormat:@"%@%@%@%@%@",
            credentialType, keyDelimiter, clientId,
            (realm ? keyDelimiter : @""),
            (realm ? realm : @"")];
}

// kSecAttrAccount - account_id (<unique_id>-<environment>)
+ (NSString *)accountIdWithUniqueUserId:(NSString *)uniqueId
                            environment:(NSString *)environment
{
    return [NSString stringWithFormat:@"%@%@%@",
            uniqueId, keyDelimiter, environment];
}

#pragma mark - Internal

+ (MSIDDefaultTokenCacheKey *)keyForAccessTokensWithUniqueUserId:(NSString *)userId
                                                     environment:(NSString *)environment
                                                        clientId:(NSString *)clientId
                                                           realm:(NSString *)realm
                                                          target:(NSString *)target
{
    // kSecAttrAccount - account_id (<unique_id>-<environment>)
    // kSecAttrService - credential_id+target (<credential_type>-<client_id>-<realm>-<target>)
    // kSecAttrGeneric - credential_id (<credential_type>-<client_id>-<realm>)
    // kSecAttrType - type
    
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *generic = [self.class credentialIdWithType:MSIDTokenTypeAccessToken clientId:clientId realm:realm];
    NSString *service = [self.class serviceWithType:MSIDTokenTypeAccessToken clientID:clientId realm:realm target:target];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:@(MSIDTokenTypeAccessToken)];
}

#pragma mark - Default

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
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[service dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:@(MSIDTokenTypeIDToken)];
}

+ (MSIDDefaultTokenCacheKey *)keyForAccountWithUniqueUserId:(NSString *)userId
                                                  authority:(NSURL *)authority
                                                   clientId:(NSString *)clientId
                                                accountType:(MSIDAccountType)accountType
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *service = authority.msidTenant;
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:nil
                                                        type:@(accountType)];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                          environment:(NSString *)environment
                                                             clientId:(NSString *)clientId
                                                                realm:(NSString *)realm
{
    // kSecAttrAccount - account_id (<unique_id>-<environment>)
    // kSecAttrGeneric - credential_id (<credential_type>-<client_id>-<realm>)
    // kSecAttrType - type
    
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *generic = [self.class credentialIdWithType:MSIDTokenTypeAccessToken clientId:clientId realm:realm];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:nil
                                                     generic:[generic dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:@(MSIDTokenTypeAccessToken)];
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

+ (MSIDDefaultTokenCacheKey *)queryForAllAccessTokens
{
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:nil
                                                     generic:nil
                                                        type:@(MSIDTokenTypeAccessToken)];
}

// rt with uid and utid
+ (MSIDDefaultTokenCacheKey *)keyForRefreshTokenWithUniqueUserId:(NSString *)userId
                                                     environment:(NSString *)environment
                                                        clientId:(NSString *)clientId
{
    NSString *service = [self.class serviceWithType:MSIDTokenTypeRefreshToken clientID:clientId realm:nil target:nil];
    NSString *account = [self accountIdWithUniqueUserId:userId environment:environment];
    
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:account
                                                     service:service
                                                     generic:[service dataUsingEncoding:NSUTF8StringEncoding]
                                                        type:@(MSIDTokenTypeRefreshToken)];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllTokensWithType:(MSIDTokenType)type
{
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:nil
                                                     generic:nil
                                                        type:@(type)];
}

+ (MSIDDefaultTokenCacheKey *)queryForAllRefreshTokensWithClientId:(NSString *)clientId
{
    NSString *service = [self.class serviceWithType:MSIDTokenTypeRefreshToken clientID:clientId realm:nil target:nil];
    return [[MSIDDefaultTokenCacheKey alloc] initWithAccount:nil
                                                     service:service
                                                     generic:nil
                                                        type:@(MSIDTokenTypeRefreshToken)];
}

@end
