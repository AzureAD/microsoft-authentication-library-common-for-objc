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
#import "MSIDAuthorityFactory.h"
#import "MSIDAADAuthority.h"
#import "MSIDAADTenant.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDIntuneEnrollmentIdsCache.h"

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
                                     context:(__unused id<MSIDRequestContext>)context
                                       error:(NSError **)error
{
    return [[MSIDAADTokenResponse alloc] initWithJSONDictionary:json error:error];
}

- (MSIDTokenResponse *)tokenResponseFromJSON:(NSDictionary *)json
                                refreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                     context:(__unused id<MSIDRequestContext>)context
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
        if (response.error && error)
        {
            MSIDErrorCode errorCode = response.oauthErrorCode;
            NSDictionary *additionalUserInfo = nil;
            
            /* This is a special error case for True MAM,
             where a combination of unauthorized client and MSID_PROTECTION_POLICY_REQUIRED should produce a different error */
            MSIDErrorCode oauthErrorCode = MSIDErrorCodeForOAuthError(response.error, MSIDErrorServerOauth);
            if (oauthErrorCode == MSIDErrorServerUnauthorizedClient
                && [response.suberror isEqualToString:MSID_PROTECTION_POLICY_REQUIRED])
            {
                errorCode = MSIDErrorServerProtectionPoliciesRequired;
                additionalUserInfo = @{MSIDUserDisplayableIdkey : response.additionalUserId ?: @""};
            }
            
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     errorCode,
                                     response.errorDescription,
                                     response.error,
                                     response.suberror,
                                     nil,
                                     context.correlationId,
                                     additionalUserInfo);
        }
        
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
    
    accessToken.enrollmentId = [[MSIDIntuneEnrollmentIdsCache sharedCache] enrollmentIdForHomeAccountId:accessToken.accountIdentifier.homeAccountId
                                                                                           legacyUserId:accessToken.accountIdentifier.displayableId
                                                                                                context:nil
                                                                                                  error:nil];
    accessToken.extendedExpiresOn = response.extendedExpiresOnDate;

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

- (BOOL)fillAppMetadata:(MSIDAppMetadataCacheItem *)metadata
           fromResponse:(MSIDAADTokenResponse *)response
          configuration:(MSIDConfiguration *)configuration
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return NO;
    }
    
    BOOL result = [super fillAppMetadata:metadata fromResponse:response configuration:configuration];
    
    if (!result)
    {
        return NO;
    }
    
    metadata.familyId = response.familyId ? response.familyId : @"";
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

    account.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:account.accountIdentifier.displayableId
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

    baseToken.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:baseToken.accountIdentifier.displayableId
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
