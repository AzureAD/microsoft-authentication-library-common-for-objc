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

#import "MSIDCBAWebAADAuthResponse.h"
#import "MSIDConstants.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDFlightManager.h"

@interface MSIDCBAWebAADAuthResponse ()

+ (BOOL)isCBAWebAADAuthResponse:(NSURL *)url
            expectedRedirectUri:(NSString *)expectedRedirectUri
                         context:(nullable id<MSIDRequestContext>)context;

@end

@implementation MSIDCBAWebAADAuthResponse

+ (BOOL)isCBAWebAADAuthResponse:(NSURL *)url
{
    if (!url) return NO;
    return ([url.scheme isEqualToString:@"msauth"] && [url.host isEqualToString:@"code"]);
}

+ (BOOL)isCBAWebAADAuthResponse:(NSURL *)url
            expectedRedirectUri:(NSString *)expectedRedirectUri
                         context:(nullable id<MSIDRequestContext>)context
{
    if (!url) return NO;
    
    // Check scheme and host
    if (![url.scheme isEqualToString:@"msauth"] || ![url.host isEqualToString:@"code"])
    {
        return NO;
    }
    
    // If flight flag disabled, use legacy behavior (loose matching)
    if (![MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_ENABLE_CBA_OAUTH_RESPONSE_VALIDATION])
    {
        return YES;
    }
    
    if ([NSString msidIsStringNilOrBlank:expectedRedirectUri])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, @"CBA response validation: expected redirect URI is nil");
        return NO;
    }
    
    NSURLComponents *responseComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    responseComponents.query = nil;
    responseComponents.fragment = nil;
    NSString *responseRedirectUri = responseComponents.URL.absoluteString;
    
    BOOL urisMatch = [responseRedirectUri isEqualToString:expectedRedirectUri];
    
    if (!urisMatch)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context,
                         @"CBA response validation failed: redirect URI mismatch. Expected: %@, Received: %@",
                         expectedRedirectUri, responseRedirectUri);
    }
    
    return urisMatch;
}

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Check for WPJ or broker response
    if (![self.class isCBAWebAADAuthResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"MSAuth CBA response should have msauth as a scheme and code as a host",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        NSURLComponents *resultUrlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        resultUrlComponents.query = nil;
        resultUrlComponents.fragment = nil;
        
        _redirectUri = resultUrlComponents.URL.absoluteString;
    }
    
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
        expectedRedirectUri:(NSString *)expectedRedirectUri
                requestState:(nullable NSString *)requestState
          ignoreInvalidState:(BOOL)ignoreInvalidState
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Check for CBA response
    if (![self.class isCBAWebAADAuthResponse:url
                         expectedRedirectUri:expectedRedirectUri
                                      context:context])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     @"MSAuth CBA response should match the expected redirect URI",
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    if ([MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_ENABLE_CBA_OAUTH_RESPONSE_VALIDATION])
    {
        self = [super initWithURL:url
                     requestState:requestState
               ignoreInvalidState:ignoreInvalidState
                          context:context
                            error:error];
    }
    else
    {
        // Legacy behavior: skip state validation
        self = [super initWithURL:url context:context error:error];
    }
    
    if (self)
    {
        NSURLComponents *resultUrlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        resultUrlComponents.query = nil;
        resultUrlComponents.fragment = nil;
        
        _redirectUri = resultUrlComponents.URL.absoluteString;
    }
    
    return self;
}

#pragma mark - MSIDWebOAuth2AuthCodeResponse

- (void)updateRequestParameters:(MSIDInteractiveTokenRequestParameters *)requestParameters
{
    [super updateRequestParameters:requestParameters];
    
    requestParameters.redirectUri = self.redirectUri;
}

@end
