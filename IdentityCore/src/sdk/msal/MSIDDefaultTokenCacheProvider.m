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

#import "MSIDDefaultTokenCacheProvider.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDAccessToken.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResult.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDAppMetadataCacheItem.h"
#import "MSIDIdToken.h"

@interface MSIDDefaultTokenCacheProvider()

@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;
// TODO: I don't like saving app metadata here! Query app metadata before updating it again so that nobody else updates it...
@property (nonatomic) MSIDAppMetadataCacheItem *appMetadata;

@end

@implementation MSIDDefaultTokenCacheProvider

#pragma mark - Init

- (instancetype)initWithDefaultAccessor:(MSIDDefaultTokenCacheAccessor *)defaultAccessor
{
    self = [super init];

    if (self)
    {
        self.defaultAccessor = defaultAccessor;
    }

    return self;
}

#pragma mark - MSIDSilentTokenRequestHandling

- (nullable MSIDAccessToken *)accessTokenWithParameters:(MSIDRequestParameters *)requestParameters
                                                  error:(NSError **)error
{
    NSError *cacheError = nil;

    MSIDAccessToken *accessToken = [self.defaultAccessor getAccessTokenForAccount:requestParameters.accountIdentifier
                                                                    configuration:requestParameters.msidConfiguration
                                                                          context:requestParameters
                                                                            error:&cacheError];

    if (!accessToken && cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }

        MSID_LOG_ERROR(requestParameters, @"Access token lookup error %ld, %@", (long)cacheError.code, cacheError.domain);
        MSID_LOG_ERROR_PII(requestParameters, @"Access token lookup error %@", cacheError);
        return nil;
    }

    return accessToken;
}

- (nullable MSIDTokenResult *)resultWithAccessToken:(MSIDAccessToken *)accessToken
                                  requestParameters:(MSIDRequestParameters *)requestParameters
                                              error:(NSError * _Nullable * _Nullable)error
{
    if (!accessToken)
    {
        return nil;
    }

    NSError *idTokenError = nil;

    MSIDIdToken *idToken = [self.defaultAccessor getIDTokenForAccount:requestParameters.accountIdentifier
                                                        configuration:requestParameters.msidConfiguration
                                                              context:requestParameters
                                                                error:&idTokenError];

    if (!idToken)
    {
        MSID_LOG_WARN(requestParameters, @"Couldn't find an id token for clientId %@, authority %@", requestParameters.clientId, requestParameters.authority.url);
        MSID_LOG_WARN_PII(requestParameters, @"Couldn't find an id token for clientId %@, authority %@, account %@", requestParameters.clientId, requestParameters.authority.url, requestParameters.accountIdentifier.homeAccountId);
    }

    MSIDTokenResult *result = [[MSIDTokenResult alloc] initWithAccessToken:accessToken
                                                                   idToken:idToken.rawIdToken
                                                                 authority:accessToken.authority
                                                             correlationId:requestParameters.correlationId
                                                             tokenResponse:nil];

    return result;
}

- (nullable MSIDRefreshToken *)familyRefreshTokenWithParameters:(MSIDRequestParameters *)requestParameters
                                                          error:(NSError * _Nullable * _Nullable)error
{
    NSError *cacheError = nil;
    NSArray<MSIDAppMetadataCacheItem *> *appMetadataEntries = [self.defaultAccessor getAppMetadataEntries:requestParameters.msidConfiguration
                                                                                                  context:requestParameters
                                                                                                    error:&cacheError];

    if (cacheError)
    {
        if (error)
        {
            *error = cacheError;
        }

        MSID_LOG_ERROR(requestParameters, @"Failed reading app metadata with error %ld, %@", (long)cacheError.code, cacheError.domain);
        MSID_LOG_ERROR_PII(requestParameters, @"Failed reading app metadata with error %@", cacheError);
        return nil;
    }

    //On first network try, app metadata will be nil but on every subsequent attempt, it should reflect if clientId is part of family
    NSString *familyId = appMetadataEntries.firstObject ? appMetadataEntries.firstObject.familyId : @"1";

    self.appMetadata = appMetadataEntries.firstObject;

    if (![NSString msidIsStringNilOrBlank:familyId])
    {
        return [self.defaultAccessor getRefreshTokenWithAccount:requestParameters.accountIdentifier
                                                       familyId:familyId
                                                  configuration:requestParameters.msidConfiguration
                                                        context:requestParameters
                                                          error:error];
    }

    return nil;
}

- (nullable MSIDRefreshToken *)multiResourceTokenWithParameters:(MSIDRequestParameters *)requestParameters
                                                          error:(NSError * _Nullable * _Nullable)error
{
    return [self.defaultAccessor getRefreshTokenWithAccount:requestParameters.accountIdentifier
                                                   familyId:nil
                                              configuration:requestParameters.msidConfiguration
                                                    context:requestParameters
                                                      error:error];
}

- (BOOL)updateClientFamilyStateWithRequestPrameters:(MSIDRequestParameters *)requestParameters
                                        newFamilyId:(NSString *)newFamilyId
                                        updateError:(NSError **)updateError
{
    // TODO: query app metadata instead
    if (!self.appMetadata)
    {
        if (updateError)
        {
            *updateError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Cannot update app metadata, because it's missing", nil, nil, nil, requestParameters.correlationId, nil);
        }

        MSID_LOG_ERROR(requestParameters, @"Cannot update app metadata");
        return NO;
    }

    self.appMetadata.familyId = newFamilyId;
    return [self.defaultAccessor updateAppMetadata:self.appMetadata context:requestParameters error:updateError];
}

- (id<MSIDCacheAccessor>)cacheAccessor
{
    return self.defaultAccessor;
}

@end
