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

#import "MSIDDefaultTokenResponseValidator.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDRequestParameters.h"
#import "MSIDTokenResponse.h"
#import "MSIDTokenResult.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccessToken.h"

@implementation MSIDDefaultTokenResponseValidator

- (BOOL)validateTokenResult:(MSIDTokenResult *)tokenResult
              configuration:(MSIDConfiguration *)configuration
                  oidcScope:(NSString *)oidcScope
             requestAccount:(MSIDAccountIdentifier *)accountIdentifier
              correlationID:(NSUUID *)correlationID
                      error:(NSError **)error
{
    /*
     If server returns less scopes than developer requested,
     we'd like to throw an error and specify which scopes were granted and which ones not
     */

    NSMutableOrderedSet *grantedScopes = [tokenResult.accessToken.scopes mutableCopy];
    NSOrderedSet *oidcScopes = [oidcScope msidScopeSet];

    if (![configuration.scopes isSubsetOfOrderedSet:grantedScopes])
    {
        if (error)
        {
            NSMutableDictionary *additionalUserInfo = [NSMutableDictionary new];
            
            MSID_LOG_ERROR_CORR(correlationID, @"Server returned less scopes than requested, granted scopes: %@", grantedScopes);
            // Remove oidc scopes.
            [grantedScopes minusOrderedSet:oidcScopes];
            
            MSID_LOG_INFO_CORR(correlationID, @"Removing reserved scopes from granted scopes: %@", oidcScopes);
            MSID_LOG_INFO_CORR(correlationID, @"Final granted scopes: %@", grantedScopes);
            
            additionalUserInfo[MSIDGrantedScopesKey] = [grantedScopes array];

            NSMutableOrderedSet *declinedScopeSet = [[NSOrderedSet msidOrderedSetFromString:configuration.target] mutableCopy];
            [declinedScopeSet minusOrderedSet:grantedScopes];

            additionalUserInfo[MSIDDeclinedScopesKey] = [declinedScopeSet array];
            additionalUserInfo[MSIDInvalidTokenResultKey] = tokenResult;

            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerDeclinedScopes, @"Server returned less scopes than requested", nil, nil, nil, nil, additionalUserInfo);
        }

        return NO;
    }

    if (accountIdentifier.homeAccountId != nil
        && ![accountIdentifier.homeAccountId isEqualToString:tokenResult.accessToken.accountIdentifier.homeAccountId])
    {
        if (error)
        {
            NSDictionary *userInfo = @{MSIDInvalidTokenResultKey : tokenResult};
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMismatchedAccount, @"Different account was returned from the server", nil, nil, nil, correlationID, userInfo);
        }

        return NO;
    }

    return YES;
}

@end
