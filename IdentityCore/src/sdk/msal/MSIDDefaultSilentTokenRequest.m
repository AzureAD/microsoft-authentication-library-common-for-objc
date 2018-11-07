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

#import "MSIDDefaultSilentTokenRequest.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDIDToken.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDRefreshToken.h"

@interface MSIDDefaultSilentTokenRequest()

@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
@property (nonatomic) MSIDAppMetadataCacheItem *appMetadata;

@end

@implementation MSIDDefaultSilentTokenRequest

#pragma mark - Init

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDRequestParameters *)parameters
                                      forceRefresh:(BOOL)forceRefresh
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull MSIDDefaultTokenCacheAccessor *)tokenCache
{
    self = [super initWithRequestParameters:parameters
                               forceRefresh:forceRefresh
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator];

    if (self)
    {
        self.defaultAccessor = tokenCache;
    }

    return self;
}

#pragma mark - Abstract impl

- (nullable MSIDAccessToken *)accessTokenWithError:(NSError **)error
{
    NSError *cacheError = nil;

    MSIDAccessToken *accessToken = [self.defaultAccessor getAccessTokenForAccount:self.requestParameters.accountIdentifier
                                                                    configuration:self.requestParameters.msidConfiguration
                                                                          context:self.requestParameters
                                                                            error:&cacheError];

    if (!accessToken && cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }

        MSID_LOG_ERROR(self.requestParameters, @"Access token lookup error %ld, %@", (long)cacheError.code, cacheError.domain);
        MSID_LOG_ERROR_PII(self.requestParameters, @"Access token lookup error %@", cacheError);
        return nil;
    }

    return accessToken;
}

- (nullable MSIDTokenResult *)resultWithAccessToken:(MSIDAccessToken *)accessToken
                                              error:(NSError * _Nullable * _Nullable)error
{
    if (!accessToken)
    {
        return nil;
    }

    NSError *cacheError = nil;

    MSIDIdToken *idToken = [self.defaultAccessor getIDTokenForAccount:self.requestParameters.accountIdentifier
                                                        configuration:self.requestParameters.msidConfiguration
                                                              context:self.requestParameters
                                                                error:&cacheError];

    if (!idToken)
    {
        MSID_LOG_WARN(self.requestParameters, @"Couldn't find an id token for clientId %@, authority %@", self.requestParameters.clientId, self.requestParameters.authority.url);
    }

    MSIDAccount *account = [self.defaultAccessor accountForIdentifier:self.requestParameters.accountIdentifier
                                                             familyId:nil
                                                        configuration:self.requestParameters.msidConfiguration
                                                              context:self.requestParameters
                                                                error:&cacheError];

    if (!account)
    {
        MSID_LOG_WARN(self.requestParameters, @"Couldn't find an account for clientId %@, authority %@", self.requestParameters.clientId, self.requestParameters.authority.url);
    }

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                                   idToken:idToken.rawIdToken
                                                                   account:account
                                                                 authority:accessToken.authority
                                                             correlationId:self.requestParameters.correlationId
                                                             tokenResponse:nil];

    return result;
}

- (nullable MSIDRefreshToken *)familyRefreshTokenWithError:(NSError * _Nullable * _Nullable)error
{
    self.appMetadata = [self appMetadataWithError:error];

    //On first network try, app metadata will be nil but on every subsequent attempt, it should reflect if clientId is part of family
    NSString *familyId = self.appMetadata ? self.appMetadata.familyId : @"1";

    if (![NSString msidIsStringNilOrBlank:familyId])
    {
        return [self.defaultAccessor getRefreshTokenWithAccount:self.requestParameters.accountIdentifier
                                                       familyId:familyId
                                                  configuration:self.requestParameters.msidConfiguration
                                                        context:self.requestParameters
                                                          error:error];
    }

    return nil;
}

- (nullable id<MSIDRefreshableToken>)appRefreshTokenWithError:(NSError * _Nullable * _Nullable)error
{
    return [self.defaultAccessor getRefreshTokenWithAccount:self.requestParameters.accountIdentifier
                                                   familyId:nil
                                              configuration:self.requestParameters.msidConfiguration
                                                    context:self.requestParameters
                                                      error:error];
}

- (BOOL)updateFamilyIdCacheWithServerError:(NSError *)serverError
                                cacheError:(NSError **)cacheError
{
    //When FRT is used by client which is not part of family, the server returns "client_mismatch" as sub-error
    NSString *subError = serverError.userInfo[MSIDOAuthSubErrorKey];
    if (subError && [subError isEqualToString:MSIDServerErrorClientMismatch])
    {
        //reset family id if set in app's metadata
        if (!self.appMetadata)
        {
            self.appMetadata = [self appMetadataWithError:cacheError];

            if (!self.appMetadata)
            {
                if (cacheError)
                {
                    *cacheError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Cannot update app metadata, because it's missing", nil, nil, nil, self.requestParameters.correlationId, nil);
                }

                MSID_LOG_ERROR(self.requestParameters, @"Cannot update app metadata");
                return NO;
            }
        }

        self.appMetadata.familyId = nil;
        return [self.defaultAccessor updateAppMetadata:self.appMetadata context:self.requestParameters error:cacheError];
    }

    return YES;
}

- (id<MSIDCacheAccessor>)tokenCache
{
    return self.defaultAccessor;
}

#pragma mark - Helpers

- (MSIDAppMetadataCacheItem *)appMetadataWithError:(NSError * _Nullable * _Nullable)error
{
    NSError *cacheError = nil;
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [self.defaultAccessor getAppMetadataEntries:self.requestParameters.msidConfiguration
                                                                                                  context:self.requestParameters
                                                                                                    error:&cacheError];

    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }

        MSID_LOG_ERROR(self.requestParameters, @"Failed reading app metadata with error %ld, %@", (long)cacheError.code, cacheError.domain);
        MSID_LOG_ERROR_PII(self.requestParameters, @"Failed reading app metadata with error %@", cacheError);
        return nil;
    }

    return appMetadataEntries.firstObject;
}

@end
