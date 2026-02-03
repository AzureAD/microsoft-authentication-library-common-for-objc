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

#import "MSIDWebProfileInstallTriggerResponse.h"
#import "MSIDWebResponseOperationConstants.h"

@implementation MSIDWebProfileInstallTriggerResponse

static NSString *const SCHEME_MSAUTH = @"msauth";
static NSString *const INSTALL_PROFILE = @"installprofile";
static NSString *const PROFILE_INSTALL_URL_HEADER = @"X-Profile-Install-URL";

- (instancetype)initWithURL:(NSURL *)url
               httpResponse:(NSHTTPURLResponse *)httpResponse
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Check for profile install trigger
    if (![self isProfileInstallTrigger:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     [NSString stringWithFormat:
                                      @"Profile install trigger response should have %@ as a scheme and %@ as a host",
                                        SCHEME_MSAUTH, INSTALL_PROFILE],
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        // Extract profile installation URL from HTTP headers
        if (httpResponse && httpResponse.allHeaderFields)
        {
            _profileInstallURL = httpResponse.allHeaderFields[PROFILE_INSTALL_URL_HEADER];
            
            if (!_profileInstallURL)
            {
                // Try case-insensitive search
                for (NSString *headerKey in httpResponse.allHeaderFields.allKeys)
                {
                    if ([headerKey caseInsensitiveCompare:PROFILE_INSTALL_URL_HEADER] == NSOrderedSame)
                    {
                        _profileInstallURL = httpResponse.allHeaderFields[headerKey];
                        break;
                    }
                }
            }
            
            if (_profileInstallURL)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, context, 
                                     @"Extracted profile install URL from header: %@", 
                                     MSID_PII_LOG_MASKABLE(_profileInstallURL));
            }
            else
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning, context, 
                                 @"Profile install trigger detected but no %@ header found", 
                                 PROFILE_INSTALL_URL_HEADER);
            }
        }
    }
    
    return self;
}

/**
 * Return true when the url response is matching a profile installation trigger
 **/
- (BOOL)isProfileInstallTrigger:(NSURL *)url
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
    
    // For system webview, this link will start with the redirect uri and will have msauth and installProfile as path parameters
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
    return @"profile_install_trigger";
}

@end
