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

#pragma mark - Tokens

- (MSIDBaseToken *)baseTokenFromResponse:(MSIDAADTokenResponse *)response
                                 request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDBaseToken *baseToken = [super baseTokenFromResponse:response request:requestParams];
    return (MSIDBaseToken *) [self fillAADBaseToken:baseToken fromResponse:response request:requestParams];
}

- (MSIDAccessToken *)accessTokenFromResponse:(MSIDAADTokenResponse *)response
                                     request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDAccessToken *accessToken = [super accessTokenFromResponse:response request:requestParams];

    if (!response.extendedExpiresOnDate)
    {
        return (MSIDAccessToken *) [self fillAADBaseToken:accessToken fromResponse:response request:requestParams];
    }

    NSMutableDictionary *additionalServerInfo = [accessToken.additionalServerInfo mutableCopy];
    additionalServerInfo[MSID_EXTENDED_EXPIRES_ON_LEGACY_CACHE_KEY] = response.extendedExpiresOnDate;
    accessToken.additionalServerInfo = additionalServerInfo;

    return (MSIDAccessToken *) [self fillAADBaseToken:accessToken fromResponse:response request:requestParams];
}

- (MSIDRefreshToken *)refreshTokenFromResponse:(MSIDAADTokenResponse *)response
                                       request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDRefreshToken *refreshToken = [super refreshTokenFromResponse:response request:requestParams];
    refreshToken.familyId = response.familyId;

    return (MSIDRefreshToken *) [self fillAADBaseToken:refreshToken fromResponse:response request:requestParams];
}

- (MSIDIdToken *)idTokenFromResponse:(MSIDAADTokenResponse *)response
                             request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDIdToken *idToken = [super idTokenFromResponse:response request:requestParams];
    return (MSIDIdToken *)[self fillAADBaseToken:idToken fromResponse:response request:requestParams];
}

- (MSIDLegacySingleResourceToken *)legacyTokenFromResponse:(MSIDAADTokenResponse *)response
                                                   request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDLegacySingleResourceToken *legacyToken = [super legacyTokenFromResponse:response request:requestParams];
    legacyToken.familyId = response.familyId;
    return (MSIDLegacySingleResourceToken *) [self fillAADBaseToken:legacyToken fromResponse:response request:requestParams];
}

- (MSIDAccount *)accountFromResponse:(MSIDAADTokenResponse *)response
                             request:(MSIDConfiguration *)requestParams
{
    if (![self checkResponseClass:response context:nil error:nil])
    {
        return nil;
    }

    MSIDAccount *account = [super accountFromResponse:response request:requestParams];
    account.clientInfo = response.clientInfo;

    if (response.clientInfo.userIdentifier)
    {
        account.uniqueUserId = response.clientInfo.userIdentifier;
    }

    return account;
}

#pragma mark - Fill token

- (MSIDBaseToken *)fillAADBaseToken:(MSIDBaseToken *)baseToken
                       fromResponse:(MSIDAADTokenResponse *)response
                            request:(MSIDConfiguration *)requestParams
{
    baseToken.clientInfo = response.clientInfo;

    if (response.clientInfo.userIdentifier)
    {
        baseToken.uniqueUserId = response.clientInfo.userIdentifier;
    }

    if (response.speInfo)
    {
        NSMutableDictionary *additionalServerInfo = [baseToken.additionalServerInfo mutableCopy];
        additionalServerInfo[MSID_SPE_INFO_CACHE_KEY] = response.speInfo;
        baseToken.additionalServerInfo = additionalServerInfo;
    }

    return baseToken;
}

@end
