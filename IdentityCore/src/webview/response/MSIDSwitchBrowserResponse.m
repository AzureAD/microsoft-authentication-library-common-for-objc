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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSIDSwitchBrowserResponse.h"
#import "MSIDWebResponseOperationFactory.h"
#import "MSIDConstants.h"

@implementation MSIDSwitchBrowserResponse

+ (NSString *)operation
{
    return MSID_BROWSER_RESPONSE_SWITCH_BROWSER;
}

- (instancetype)initWithURL:(NSURL *)url
                    context:(id<MSIDRequestContext>)context
                      error:(NSError *__autoreleasing*)error
{
    self = [super initWithURL:url
                      context:context
                        error:error];
    
    if (self)
    {
        if (![self isMyUrl:url]) return nil;
        
        _actionUri = self.parameters[@"action_uri"];
        if ([NSString msidIsStringNilOrBlank:_actionUri])
        {
            if (error) *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerInvalidResponse, @"action_uri is nil.", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
        
        _switchBrowserSessionToken = self.parameters[MSID_OAUTH2_CODE];
        if ([NSString msidIsStringNilOrBlank:_switchBrowserSessionToken])
        {
            if (error) *error = MSIDCreateError(MSIDOAuthErrorDomain, MSIDErrorServerInvalidResponse, @"code is nil.", nil, nil, nil, context.correlationId, nil, YES);
            return nil;
        }
    }
    
    return self;
}

#pragma mark - Private

- (BOOL)isMyUrl:(NSURL *)url
{
    // msauth://<broker id>/switch_browser?action_uri=(not-null)&code=(not-null)
    // msauth.com.microsoft.msaltestapp://auth/switch_browser?action_uri=(not-null)&code=(not-null)
    NSString *scheme = url.scheme;

    if (![scheme containsString:@"msauth"])
    {
        return NO;
    }
    
    NSArray *pathComponents = url.pathComponents;
    if ([pathComponents count] < 2)
    {
        return NO;
    }
    
    if ([pathComponents[1] isEqualToString:[self.class operation]])
    {
        return YES;
    }
    
    return NO;
}


@end
