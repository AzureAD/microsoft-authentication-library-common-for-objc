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

#import "MSIDExternalAADCacheSeeder.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDRefreshTokenGrantRequest.h"
#import "MSIDTokenResponse.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDIdToken.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADV2Oauth2FactoryForV1Request.h"

@interface MSIDExternalAADCacheSeeder()

@property (nonatomic) MSIDLegacyTokenCacheAccessor *externalLegacyAccessor;
@property (nonatomic) MSIDDefaultTokenCacheAccessor *defaultAccessor;

@end

@implementation MSIDExternalAADCacheSeeder

- (instancetype)initWithDefaultAccessor:(MSIDDefaultTokenCacheAccessor *)defaultAccessor
                 externalLegacyAccessor:(MSIDLegacyTokenCacheAccessor *)externalLegacyAccessor
{
    NSParameterAssert(defaultAccessor);
    NSParameterAssert(externalLegacyAccessor);
    
    self = [super init];
    if (self)
    {
        _defaultAccessor = defaultAccessor;
        _externalLegacyAccessor = externalLegacyAccessor;
    }
    
    return self;
}

- (void)seedTokenResponse:(MSIDTokenResponse *)originalTokenResponse
                  factory:(MSIDOauth2Factory *)factory
        requestParameters:(MSIDRequestParameters *)requestParameters
          completionBlock:(void(^)(void))completionBlock
{
    NSParameterAssert(originalTokenResponse);
    NSParameterAssert(factory);
    NSParameterAssert(requestParameters);
    NSParameterAssert(completionBlock);
    
    MSID_LOG_INFO(requestParameters, @"Beginning external cache seeding.");
    
    void (^completionBlockWrapper)(void) = ^
    {
        MSID_LOG_INFO(requestParameters, @"External cache seeding finished.");
        completionBlock();
    };
    
    MSIDIdToken *idToken = [factory idTokenFromResponse:originalTokenResponse
                                          configuration:requestParameters.msidConfiguration];
    
    __auto_type accountIdentifier = idToken.accountIdentifier;
    
    NSError *error;
    MSIDConfiguration *configuration = [requestParameters.msidConfiguration copy];
    configuration.authority = originalTokenResponse.idTokenObj.issuerAuthority;
    
    MSID_LOG_INFO(requestParameters, @"Trying to get legacy id token from cache.");
    
    MSIDIdToken *legacyIdToken = [self.defaultAccessor getIDTokenForAccount:accountIdentifier
                                                              configuration:configuration
                                                                idTokenType:MSIDLegacyIDTokenType
                                                                    context:requestParameters
                                                                      error:&error];
    
    
    
    if (legacyIdToken)
    {
        MSID_LOG_INFO(requestParameters, @"Found legacy id token in cache.");
        
        [self seedExternalCacheWithIdToken:legacyIdToken
                             tokenResponse:originalTokenResponse
                                   factory:factory
                             configuration:requestParameters.msidConfiguration
                                   context:requestParameters
                           completionBlock:completionBlockWrapper];
        return;
    }
    
    MSID_LOG_INFO(requestParameters, @"Legacy id token wasn't found in cache, sending network request to acquire legacy id token.");
    
    __auto_type refreshToken = [factory refreshTokenFromResponse:originalTokenResponse
                                                   configuration:requestParameters.msidConfiguration];
    
    NSMutableDictionary *extraTokenRequestParameters = [requestParameters.extraTokenRequestParameters mutableCopy];
    extraTokenRequestParameters[@"itver"] = @"1";
    requestParameters.extraTokenRequestParameters = extraTokenRequestParameters;
    
    factory = [MSIDAADV2Oauth2FactoryForV1Request new];
    MSIDRefreshTokenGrantRequest *tokenRequest = [factory refreshTokenRequestWithRequestParameters:requestParameters
                                                                                      refreshToken:refreshToken.refreshToken];
    [tokenRequest sendWithBlock:^(MSIDTokenResponse *tokenResponse, NSError *error)
     {
         if (error)
         {
             MSID_LOG_ERROR(requestParameters, @"Failed to acquire V1 Id Token token via Refresh token. Error %ld, %@", (long)error.code, error.domain);
             MSID_LOG_ERROR_PII(requestParameters, @"Failed to acquire V1 Id Token token via Refresh token. Error %@", error);
             
             completionBlockWrapper();
             return;
         }
         
         MSIDIdToken *legacyIdToken = [factory idTokenFromResponse:tokenResponse
                                                     configuration:requestParameters.msidConfiguration];
         
         if (!legacyIdToken)
         {
             MSID_LOG_ERROR(requestParameters, @"Failed to parse V1 Id Token. Error %ld, %@", (long)error.code, error.domain);
             MSID_LOG_ERROR_PII(requestParameters, @"Failed to parse V1 Id Token. Error %@", error);
             
             completionBlockWrapper();
         }
         
         MSID_LOG_INFO(requestParameters, @"Saving V1 id token in default cache.");
         
         NSError *localError;
         BOOL result = [self.defaultAccessor saveToken:legacyIdToken context:requestParameters error:&localError];
         if (result)
         {
             MSID_LOG_INFO(requestParameters, @"Saved V1 id token in default cache.");
         }
         else
         {
             MSID_LOG_ERROR(requestParameters, @"Failed to save V1 id token in default cache. Error %ld, %@", (long)error.code, error.domain);
             MSID_LOG_ERROR_PII(requestParameters, @"Failed to save V1 id token in default cache. Error %@", error);
         }
         
         [self seedExternalCacheWithIdToken:legacyIdToken
                              tokenResponse:originalTokenResponse
                                    factory:factory
                              configuration:requestParameters.msidConfiguration
                                    context:requestParameters
                            completionBlock:completionBlockWrapper];
     }];
}

#pragma mark - Private

- (void)seedExternalCacheWithIdToken:(MSIDIdToken *)idToken
                       tokenResponse:(MSIDTokenResponse *)tokenResponse
                             factory:(MSIDOauth2Factory *)factory
                       configuration:(MSIDConfiguration *)configuration
                             context:(id<MSIDRequestContext>)context
                     completionBlock:(void(^)(void))completionBlock
{
    NSParameterAssert(completionBlock);
    
    MSIDLegacyRefreshToken *refreshToken = [factory legacyRefreshTokenFromResponse:tokenResponse
                                                                     configuration:configuration];
    refreshToken.idToken = idToken.rawIdToken;
    refreshToken.accountIdentifier = idToken.accountIdentifier;
    
    MSID_LOG_INFO(context, @"Saving refresh token in external cache.");
    
    NSError *error;
    BOOL result = [self.externalLegacyAccessor saveRefreshToken:refreshToken
                                                  configuration:configuration
                                                        context:context
                                                          error:&error];
    
    if (result)
    {
        MSID_LOG_INFO(context, @"Refresh token was saved in external cache.");
    }
    else
    {
        MSID_LOG_ERROR(context, @"Failed to save refresh token in external cache. Error %ld, %@", (long)error.code, error.domain);
        MSID_LOG_ERROR_PII(context, @"Failed to save refresh token in external cache. Error %@", error);
    }
    
    completionBlock();
}

@end
