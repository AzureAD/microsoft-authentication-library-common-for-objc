//------------------------------------------------------------------------------
//
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAADOauth2Factory.h"
#import "MSIDAADTokenResponse.h"
#import "MSIDAccessToken.h"
#import "MSIDBaseToken.h"
#import "MSIDRefreshToken.h"
#import "MSIDLegacySingleResourceToken.h"
#import "MSIDAccount.h"
#import "MSIDIdToken.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDOauth2Factory+Internal.h"
#import "MSIDAADWebviewFactory.h"
#import "MSIDAadAuthorityCache.h"
#import "MSIDAuthority.h"
#import "MSIDAccountIdentifier.h"

@implementation MSIDAADOauth2Factory

#pragma mark - Helpers

- (BOOL)checkResponseClass:(MSIDTokenResponse *)response
                   context:(id<MSIDRequestContext>)context
                     error:(NSError **)error
{
    if (![response isKindOfClass:[MSIDAADTokenResponse class]])
    {
        if (error)
        {
            NSString *errorMessage = [NSString stringWithFormat:@"Wrong token response type passed, which means wrong factory is being used (expected MSIDAADTokenResponse, passed %@", response.class];

            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorMessage, nil, nil, nil, context.correlationId, nil);
        }

        return NO;
    }

    return YES;
}

#pragma mark - Response

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    return [[MSIDAADTokenResponse alloc] initWithJSONDictionary:json error:error];
}

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                refreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                     context:(id<MSIDRequestContext>)context
                                       error:(NSError * __autoreleasing *)error
{
    return [[MSIDAADTokenResponse alloc] initWithJSONDictionary:json refreshToken:token error:error];
}

- (BOOL)verifyResponse:(MSIDAADTokenResponse *)response
               context:(id<MSIDRequestContext>)context
                 error:(NSError * __autoreleasing *)error
{
    if (![self checkResponseClass:response context:context error:error])
    {
        return NO;
    }

    BOOL result = [super verifyResponse:response context:context error:error];

    if (!result)
    {
        return result;
    }

    [self checkCorrelationId:context.correlationId response:response];
    return YES;
}

- (void)checkCorrelationId:(NSUUID *)requestCorrelationId response:(MSIDAADTokenResponse *)response
{
    MSID_LOG_VERBOSE_CORR(requestCorrelationId, @"Token extraction. Attempt to extract the data from the server response.");

    if (![NSString msidIsStringNilOrBlank:response.correlationId])
    {
        NSUUID *responseUUID = [[NSUUID alloc] initWithUUIDString:response.correlationId];
        if (!responseUUID)
        {
            MSID_LOG_INFO_CORR(requestCorrelationId, @"Bad correlation id - The received correlation id is not a valid UUID. Sent: %@; Received: %@", requestCorrelationId, response.correlationId);
        }
        else if (![requestCorrelationId isEqual:responseUUID])
        {
            MSID_LOG_INFO_CORR(requestCorrelationId, @"Correlation id mismatch - Mismatch between the sent correlation id and the received one. Sent: %@; Received: %@", requestCorrelationId, response.correlationId);
        }
    }
    else
    {
        MSID_LOG_INFO_CORR(requestCorrelationId, @"Missing correlation id - No correlation id received for request with correlation id: %@", [requestCorrelationId UUIDString]);
    }
}

- (NSString *)cacheEnvironmentFromEnvironment:(NSString *)originalEnvironment context:(id<MSIDRequestContext>)context
{
    return [[MSIDAadAuthorityCache sharedInstance] cacheEnvironmentForEnvironment:originalEnvironment context:context];
}

- (NSArray<NSURL *> *)legacyAccessTokenLookupAuthorities:(NSURL *)originalAuthority
{
    return [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthority:originalAuthority];
}

- (NSArray<NSString *> *)defaultCacheAliasesForEnvironment:(NSString *)originalEnvironment
{
    return [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForEnvironment:originalEnvironment];
}

- (NSURL *)cacheURLForAuthority:(NSURL *)originalAuthority
                        context:(id<MSIDRequestContext>)context
{
    if (!originalAuthority)
    {
        return nil;
    }

    NSURL *authority = [MSIDAuthority universalAuthorityURL:originalAuthority];
    return [[MSIDAadAuthorityCache sharedInstance] cacheUrlForAuthority:authority context:context];
}

- (NSArray<NSURL *> *)legacyRefreshTokenLookupAuthorities:(NSURL *)originalAuthority
{
    if (!originalAuthority)
    {
        return @[];
    }

    if ([MSIDAuthority isConsumerInstanceURL:originalAuthority])
    {
        // AAD v1 doesn't support consumer authority
        return @[];
    }

    NSMutableArray *lookupAuthorities = [NSMutableArray array];

    if ([MSIDAuthority isTenantless:originalAuthority])
    {
        // If it's a tenantless authority, lookup by universal "common" authority, which is supported by both v1 and v2
        [lookupAuthorities addObject:[MSIDAuthority universalAuthorityURL:originalAuthority]];
    }
    else
    {
        // If it's a tenanted authority, lookup original authority and common as those are the same, but start with original authority
        [lookupAuthorities addObject:originalAuthority];
        [lookupAuthorities addObject:[MSIDAuthority commonAuthorityWithURL:originalAuthority]];
    }

    return [[MSIDAadAuthorityCache sharedInstance] cacheAliasesForAuthorities:lookupAuthorities];
}

#pragma mark - Tokens

- (BOOL)fillAccessToken:(MSIDAccessToken *)accessToken
           fromResponse:(MSIDAADTokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [super fillAccessToken:accessToken fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    if (!response.extendedExpiresOnDate) return YES;

    NSMutableDictionary *additionalServerInfo = [accessToken.additionalServerInfo mutableCopy];
    additionalServerInfo[MSID_EXTENDED_EXPIRES_ON_LEGACY_CACHE_KEY] = response.extendedExpiresOnDate;
    accessToken.additionalServerInfo = additionalServerInfo;

    return YES;
}

- (BOOL)fillLegacyToken:(MSIDLegacySingleResourceToken *)token
           fromResponse:(MSIDAADTokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [super fillLegacyToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    token.familyId = response.familyId;
    return YES;
}

- (BOOL)fillRefreshToken:(MSIDRefreshToken *)token
            fromResponse:(MSIDAADTokenResponse *)response
           configuration:(MSIDConfiguration *)configuration
{
    BOOL result = [super fillRefreshToken:token fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    token.familyId = response.familyId;
    return YES;
}

- (BOOL)fillAccount:(MSIDAccount *)account
       fromResponse:(MSIDAADTokenResponse *)response
      configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return NO;
    }

    BOOL result = [super fillAccount:account fromResponse:response configuration:configuration];

    if (!result)
    {
        return NO;
    }

    account.clientInfo = response.clientInfo;
    account.accountType = MSIDAccountTypeMSSTS;
    account.alternativeAccountId = response.idTokenObj.alternativeAccountId;

    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:account.accountIdentifier.legacyAccountId
                                                                         homeAccountId:response.clientInfo.accountIdentifier];

    return YES;
}

#pragma mark - Fill token

- (BOOL)fillBaseToken:(MSIDBaseToken *)baseToken
         fromResponse:(MSIDAADTokenResponse *)response
        configuration:(MSIDConfiguration *)configuration
{
    if (![super fillBaseToken:baseToken fromResponse:response configuration:configuration])
    {
        return NO;
    }

    if (![self checkResponseClass:response context:nil error:nil])
    {
        return NO;
    }

    baseToken.clientInfo = response.clientInfo;

    baseToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithLegacyAccountId:baseToken.accountIdentifier.legacyAccountId
                                                                           homeAccountId:response.clientInfo.accountIdentifier];

    if (response.speInfo)
    {
        NSMutableDictionary *additionalServerInfo = [baseToken.additionalServerInfo mutableCopy];
        additionalServerInfo[MSID_SPE_INFO_CACHE_KEY] = response.speInfo;
        baseToken.additionalServerInfo = additionalServerInfo;
    }

    return YES;
}


#pragma mark - Webview
- (MSIDWebviewFactory *)webviewFactory
{
    if (!_webviewFactory)
    {
        _webviewFactory = [[MSIDAADWebviewFactory alloc] init];
    }
    return _webviewFactory;
}


@end
