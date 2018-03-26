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

#import "MSIDAADV2TokenResponse.h"
#import "MSIDAADV2IdTokenWrapper.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDAuthority.h"

@implementation MSIDAADV2TokenResponse

- (MSIDAADV2IdTokenWrapper *)idTokenObj
{
    return [[MSIDAADV2IdTokenWrapper alloc] initWithRawIdToken:self.idToken];
}

- (MSIDAccountType)accountType
{
    return MSIDAccountTypeAADV2;
}

- (NSError *)getOAuthError:(id<MSIDRequestContext>)context
          fromRefreshToken:(BOOL)fromRefreshToken;
{
    if (!self.error)
    {
        return nil;
    }
        
    return MSIDCreateError(MSIDOAuthErrorDomain,
                           self.oauthErrorCode,
                           self.errorDescription,
                           self.error,
                           nil,
                           nil,
                           context.correlationId,
                           nil);
}

- (BOOL)verifyExtendedProperties:(id<MSIDRequestContext>)context
                           error:(NSError **)error
{
    if (!self.clientInfo)
    {
        MSID_LOG_ERROR(context, @"Client info was not returned in the server response");
        MSID_LOG_ERROR_PII(context, @"Client info was not returned in the server response");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Client info was not returned in the server response", nil, nil, nil, context.correlationId, nil);
        }
        return NO;
    }
    
    return [super verifyExtendedProperties:context error:error];
}

- (NSString *)targetWithAdditionFromRequest:(MSIDRequestParameters *)requestParams
{
    // Add additional scopes from request parameters in case they are not returned from server
    // .default scope for V1 app will not be returned from server
    NSMutableOrderedSet<NSString *> *targetScopeSet = [self.scope.scopeSet mutableCopy];
    NSOrderedSet<NSString *> *reqScopes = requestParams.scopes;

    if (reqScopes.count == 1 && [reqScopes.firstObject.lowercaseString hasSuffix:@".default"]){
        [targetScopeSet unionOrderedSet:reqScopes];
    }
    
    return [targetScopeSet msidToString];
}

- (NSURL *)cacheAuthorityURLFromAuthority:(NSURL *)authority
{
    MSIDAADV2IdTokenWrapper *idToken = (MSIDAADV2IdTokenWrapper *)self.idTokenObj;
    return [MSIDAuthority cacheUrlForAuthority:authority tenantId:idToken.tenantId];
}

@end
