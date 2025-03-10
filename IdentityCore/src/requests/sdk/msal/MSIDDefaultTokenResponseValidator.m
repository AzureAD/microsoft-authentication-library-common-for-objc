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
             validateScopes:(BOOL)validateScopes
              correlationID:(NSUUID *)correlationID
                      error:(NSError *__autoreleasing*)error
{
    /*
     If server returns less scopes than developer requested,
     we'd like to throw an error and specify which scopes were granted and which ones not
     */
    
    if ([NSString msidIsStringNilOrBlank:tokenResult.accessToken.accessToken])
    {
        return YES;
    }
    
    if (!validateScopes) return YES;

    NSOrderedSet *grantedScopes = tokenResult.accessToken.scopes;
    NSOrderedSet *normalizedGrantedScopes = grantedScopes.normalizedScopeSet;
    NSOrderedSet *requestedScopes = configuration.scopes;
    NSOrderedSet *normalizedRequestedScopes = requestedScopes.normalizedScopeSet;
    
    // Include email as scope returned if it was requested and server did not include it.
    if ([normalizedRequestedScopes containsObject:MSID_OAUTH2_SCOPE_EMAIL_VALUE] &&
        ![normalizedGrantedScopes containsObject:MSID_OAUTH2_SCOPE_EMAIL_VALUE])
    {
        NSMutableOrderedSet *extendedScopes = [normalizedGrantedScopes mutableCopy];
        [extendedScopes addObject:MSID_OAUTH2_SCOPE_EMAIL_VALUE];
        normalizedGrantedScopes = extendedScopes;
    }

    if (![normalizedRequestedScopes isSubsetOfOrderedSet:normalizedGrantedScopes])
    {
        if (error)
        {
            NSMutableDictionary *additionalUserInfo = [NSMutableDictionary new];
            
            MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationID, @"Server returned less scopes than requested, granted scopes: %@", grantedScopes);
            // Remove oidc scopes.
            NSOrderedSet *oidcScopes = oidcScope.msidScopeSet;
            NSOrderedSet *filteredGrantedScopes = [grantedScopes msidMinusOrderedSet:oidcScopes normalize:YES];
            
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationID, @"Removing reserved scopes from granted scopes: %@", oidcScopes);
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationID, @"Final granted scopes: %@", grantedScopes);
            
            additionalUserInfo[MSIDGrantedScopesKey] = [filteredGrantedScopes array];

            NSOrderedSet *declinedScopeSet = [configuration.scopes msidMinusOrderedSet:filteredGrantedScopes normalize:YES];

            additionalUserInfo[MSIDDeclinedScopesKey] = [declinedScopeSet array];
            additionalUserInfo[MSIDInvalidTokenResultKey] = tokenResult;

            *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerDeclinedScopes, @"Server returned less scopes than requested", nil, nil, nil, nil, additionalUserInfo, NO);
        }

        return NO;
    }

    return YES;
}

- (BOOL)validateAccount:(MSIDAccountIdentifier *)accountIdentifier
            tokenResult:(MSIDTokenResult *)tokenResult
              correlationID:(NSUUID *)correlationID
                      error:(NSError *__autoreleasing*)error
{
    if (accountIdentifier.uid != nil
        && ![accountIdentifier.uid isEqualToString:tokenResult.account.accountIdentifier.uid])
    {
        MSID_LOG_WITH_CORR_PII(MSIDLogLevelError, correlationID, @"Different account was returned from the server. Original account %@, returned account %@", MSID_PII_LOG_TRACKABLE(accountIdentifier.uid), MSID_PII_LOG_TRACKABLE(tokenResult.account.accountIdentifier.uid));
        
        // Probably the account was deleted and re-created with the same upn and request contained old cached user's object id
        if (tokenResult.account.accountIdentifier.utid != nil &&
            [tokenResult.account.accountIdentifier.utid isEqualToString:accountIdentifier.utid] &&
            [tokenResult.account.accountIdentifier.displayableId isEqualToString:accountIdentifier.displayableId])
        {
            MSID_LOG_WITH_CORR(MSIDLogLevelInfo, correlationID, @"For the same tenant, different account uids were returned from server but have the same UPN. Probably the account was deleted and recreated with same UPN");
            return YES;
        }
        
        if (error)
        {
            NSDictionary *userInfo = @{MSIDInvalidTokenResultKey : tokenResult};
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMismatchedAccount, @"Different account was returned from the server", nil, nil, nil, correlationID, userInfo, NO);
        }
        
        return NO;
    }
    
    return YES;
}

@end
