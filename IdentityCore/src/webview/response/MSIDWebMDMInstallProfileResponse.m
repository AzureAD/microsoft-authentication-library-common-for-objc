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

#import "MSIDWebMDMInstallProfileResponse.h"
#import "MSIDWebResponseOperationConstants.h"

@implementation MSIDWebMDMInstallProfileResponse

static NSString *const SCHEME_MSAUTH = @"msauth";
static NSString *const INSTALL_PROFILE = @"installProfile";
static NSString *const INTUNE_URL_HEADER = @"x-ms-intune-profile-url";
static NSString *const INTUNE_TOKEN_HEADER = @"x-ms-intune-authToken";

- (instancetype)initWithURL:(NSURL *)url
            responseHeaders:(NSDictionary<NSString *, NSString *> *)lastResponseHeaders
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Check for profile install trigger
    if (![self isInstallProfileResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     [NSString stringWithFormat:
                                      @"Install profile response should have %@ as a scheme and %@ as a host",
                                        SCHEME_MSAUTH, INSTALL_PROFILE],
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        // Extract Intune URL and token from HTTP headers
        if (lastResponseHeaders)
        {
            _intuneURL = [self extractHeaderValue:INTUNE_URL_HEADER fromResponseHeaders:lastResponseHeaders];
            _intuneToken = [self extractHeaderValue:INTUNE_TOKEN_HEADER fromResponseHeaders:lastResponseHeaders];
            
            if (_intuneURL)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, 
                                     @"Extracted Intune URL from header: %@", 
                                     MSID_PII_LOG_MASKABLE(_intuneURL));
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, 
                                 @"Install profile response  detected but no %@ header found",
                                 INTUNE_URL_HEADER);
            }
            
            if (_intuneToken)
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, 
                                 @"Extracted Intune token from header");
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, 
                                 @"No %@ header found in response", 
                                 INTUNE_TOKEN_HEADER);
            }
        }
    }
    
    return self;
}

/**
 * Helper method to extract header value with case-insensitive matching
 */
- (nullable NSString *)extractHeaderValue:(NSString *)headerName fromResponseHeaders:(NSDictionary<NSString *, NSString *> *)responseHeaders
{
    // Try exact match first
    NSString *value = responseHeaders[headerName];
    
    if (!value)
    {
        // Try case-insensitive search
        for (NSString *headerKey in responseHeaders.allKeys)
        {
            if ([headerKey caseInsensitiveCompare:headerName] == NSOrderedSame)
            {
                value = responseHeaders[headerKey];
                break;
            }
        }
    }
    
    return value;
}

/**
 * Return true when the url response is matching a profile installation trigger
 **/
- (BOOL)isInstallProfileResponse:(NSURL *)url
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // For embedded webview, if link starts with msauth scheme and contains installProfile host
    // e.g. msauth://installProfile
    if ([scheme isEqualToString:SCHEME_MSAUTH] && [host caseInsensitiveCompare:INSTALL_PROFILE] == NSOrderedSame)
    {
        return YES;
    }
    
    NSArray *pathComponents = url.pathComponents;
    
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    // For system webview, this link will start with the redirect uri and will have msauth and installProfile as path parameters - Verify this
    // e.g. myscheme://auth/msauth/installProfile
    NSUInteger pathComponentCount = pathComponents.count;
    
    if ([pathComponents[pathComponentCount - 1] caseInsensitiveCompare:INSTALL_PROFILE] == NSOrderedSame
        && [pathComponents[pathComponentCount - 2] isEqualToString:SCHEME_MSAUTH])
    {
        return YES;
    }
    
    return NO;
}

+ (NSString *)operation
{
    return @"install-profile";
}

@end
