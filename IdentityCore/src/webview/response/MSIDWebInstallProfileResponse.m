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

#import "MSIDWebInstallProfileResponse.h"
#import "MSIDWebResponseOperationConstants.h"

@implementation MSIDWebInstallProfileResponse

static NSString *const SCHEME_MSAUTH = @"msauth";
static NSString *const PROFILE_INSTALLED = @"profileinstalled";

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    // Check for profile installed response
    if (![self isProfileInstalledResponse:url])
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDOAuthErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     [NSString stringWithFormat:
                                      @"Profile installed response should have %@ as a scheme and %@ as a host",
                                        SCHEME_MSAUTH, PROFILE_INSTALLED],
                                     nil, nil, nil, context.correlationId, nil, NO);
        }
        return nil;
    }
    
    self = [super initWithURL:url context:context error:error];
    if (self)
    {
        _status = self.parameters[@"status"];
        
        // Store any additional parameters that might be useful
        NSMutableDictionary *additionalInfo = [NSMutableDictionary new];
        for (NSString *key in self.parameters.allKeys)
        {
            if (![key isEqualToString:@"status"])
            {
                additionalInfo[key] = self.parameters[key];
            }
        }
        _additionalInfo = [additionalInfo copy];
    }
    
    return self;
}

/**
 * Return true when the url response is matching a profile installation completion
 **/
- (BOOL)isProfileInstalledResponse:(NSURL *)url
{
    NSString *scheme = url.scheme;
    NSString *host = url.host;
    
    // For embedded webview, if link starts with msauth scheme and contains profileInstalled host
    // e.g. msauth://profileInstalled?status=success
    if ([scheme isEqualToString:SCHEME_MSAUTH] && [host caseInsensitiveCompare:PROFILE_INSTALLED] == NSOrderedSame)
    {
        return YES;
    }
    
    NSArray *pathComponents = url.pathComponents;
    
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    // For system webview, this link will start with the redirect uri and will have msauth and profileInstalled as path parameters
    // e.g. myscheme://auth/msauth/profileInstalled?status=success
    NSUInteger pathComponentCount = pathComponents.count;
    
    if ([pathComponents[pathComponentCount - 1] caseInsensitiveCompare:PROFILE_INSTALLED] == NSOrderedSame
        && [pathComponents[pathComponentCount - 2] isEqualToString:SCHEME_MSAUTH])
    {
        return YES;
    }
    
    return NO;
}

+ (NSString *)operation
{
    return @"install_profile";
}

@end
