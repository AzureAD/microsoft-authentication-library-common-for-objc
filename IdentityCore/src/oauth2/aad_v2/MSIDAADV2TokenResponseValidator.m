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

#import "MSIDAADV2TokenResponseValidator.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"

@implementation MSIDAADV2TokenResponseValidator

- (MSIDTokenResponse *)validateTokenResponse:(id)response
                                oauthFactory:(MSIDOauth2Factory *)factory
                                  tokenCache:(id<MSIDCacheAccessor>)tokenCache
                           requestParameters:(MSIDRequestParameters *)parameters
                                       error:(NSError **)error
{
    MSIDTokenResponse *tokenResponse = [super validateTokenResponse:response
                                                       oauthFactory:factory
                                                         tokenCache:tokenCache
                                                  requestParameters:parameters
                                                              error:error];

    if (!tokenResponse)
    {
        return nil;
    }

    /*
     If server returns less scopes than developer requested,
     we'd like to throw an error and specify which scopes were granted and which ones not
     */

    NSOrderedSet *grantedScopes = [tokenResponse.scope msidScopeSet];

    if (![parameters.msidConfiguration.scopes isSubsetOfOrderedSet:grantedScopes])
    {
        if (error)
        {
            // TODO
            /*
            NSMutableDictionary *additionalUserInfo = [NSMutableDictionary new];
            additionalUserInfo[MSALGrantedScopesKey] = [grantedScopes array];

            NSMutableOrderedSet *declinedScopeSet = [configuration.scopes mutableCopy];
            [declinedScopeSet minusOrderedSet:grantedScopes];

            additionalUserInfo[MSALDeclinedScopesKey] = [declinedScopeSet array];

            *error = MSIDCreateError(MSIDErrorDomain, MSALErrorServerDeclinedScopes, @"Server returned less scopes than requested", nil, nil, nil, nil, additionalUserInfo);*/
        }

        return nil;
    }

    // TODO: decide to return interaction required error

    return tokenResponse;
}

@end
