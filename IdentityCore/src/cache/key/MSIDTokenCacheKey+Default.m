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

#import "MSIDTokenCacheKey+Default.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDTokenType.h"
#import "MSIDCredentialType.h"
#import "NSURL+MSIDExtensions.h"

static NSString *keyDelimiter = @"-";

@implementation MSIDTokenCacheKey (Default)

#pragma mark - Helpers

// kSecAttrService - credential_id (<credential_type>-<client_id>-<realm>)
+ (NSString *)credentialIdWithType:(MSIDCredentialType)type
                          clientId:(NSString *)clientId
                             realm:(NSString *)realm
{
    NSString *credentialType = [self credentialType:type];
    
    return [NSString stringWithFormat:@"%@%@%@%@%@",
            credentialType, keyDelimiter, clientId,
            keyDelimiter, realm ? realm : @""];
}

// kSecAttrAccount - account_id (<unique_id>-<environment>)
+ (NSString *)accountIdWithUniqueUserId:(NSString *)uniqueId
                            environment:(NSString *)environment
{
    return [NSString stringWithFormat:@"%@%@%@",
            uniqueId, keyDelimiter, environment];
}

+ (NSString *)credentialType:(MSIDCredentialType)type
{
    switch (type)
    {
        case MSIDCredentialTypeOAuthAccessToken:
            return @"AccessToken";
            
        case MSIDCredentialTypeOAuthRefreshToken:
            return @"RefreshToken";
            
        case MSIDCredentialTypeOIDCIdTokenUnsigned:
            return @"IdToken";
            
        case MSIDCredentialTypeOIDCIdToken:
            return @"IdToken";
            
        case MSIDCredentialTypePassword:
            return @"Password";
            
        default:
            return @"Credential";
    }
}

#pragma mark - Internal

+ (MSIDTokenCacheKey *)keyForAccessTokensWithUniqueUserId:(NSString *)userId
                                              environment:(NSString *)environment
                                                 clientId:(NSString *)clientId
                                                    realm:(NSString *)realm
                                                   target:(NSString *)target
{
    // kSecAttrAccount - account_id (<unique_id>-<environment>)
    // kSecAttrService - credential_id (<credential_type>-<client_id>-<realm>)
    // kSecAttrGeneric - target (<target>)
    // kSecAttrType - type
    
    NSString *account = [self.class accountIdWithUniqueUserId:userId environment:environment];
    NSString *service = [self.class credentialIdWithType:MSIDCredentialTypeOAuthAccessToken clientId:clientId realm:realm];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account
                                              service:service
                                              generic:target
                                                 type:@(MSIDCredentialTypeOAuthAccessToken)];
}

#pragma mark - Default

+ (MSIDTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
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

+ (MSIDTokenCacheKey *)keyForAccessTokenWithUniqueUserId:(NSString *)userId
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

+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                 environment:(NSString *)environment
                                                    clientId:(NSString *)clientId
                                                       realm:(NSString *)realm
{
    return [self keyForAccessTokensWithUniqueUserId:userId
                                        environment:environment
                                           clientId:clientId
                                              realm:realm
                                             target:nil];
}

+ (MSIDTokenCacheKey *)keyForAllAccessTokensWithUniqueUserId:(NSString *)userId
                                                   authority:(NSURL *)authority
                                                    clientId:(NSString *)clientId
{
    NSString *environment = authority.msidHostWithPortIfNecessary;
    NSString *tenant = authority.msidTenant;
    
    return [self keyForAllAccessTokensWithUniqueUserId:userId
                                           environment:environment
                                              clientId:clientId
                                                 realm:tenant];
}

+ (MSIDTokenCacheKey *)keyForAllAccessTokens
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil
                                              service:nil
                                              generic:nil
                                                 type:@(MSIDCredentialTypeOAuthAccessToken)];
}

// rt with uid and utid
+ (MSIDTokenCacheKey *)keyForRefreshTokenWithUniqueUserId:(NSString *)userId
                                              environment:(NSString *)environment
                                                 clientId:(NSString *)clientId
{
    NSString *service = [self credentialIdWithType:MSIDCredentialTypeOAuthRefreshToken clientId:clientId realm:nil];
    NSString *account = [self accountIdWithUniqueUserId:userId environment:environment];
    
    return [[MSIDTokenCacheKey alloc] initWithAccount:account
                                              service:service
                                              generic:nil
                                                 type:@(MSIDCredentialTypeOAuthRefreshToken)];
}

+ (MSIDTokenCacheKey *)keyForRefreshTokenWithClientId:(NSString *)clientId
{
    NSString *service = [self credentialIdWithType:MSIDCredentialTypeOAuthRefreshToken clientId:clientId realm:nil];
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil
                                              service:service
                                              generic:nil
                                                 type:@(MSIDCredentialTypeOAuthRefreshToken)];
}

@end
