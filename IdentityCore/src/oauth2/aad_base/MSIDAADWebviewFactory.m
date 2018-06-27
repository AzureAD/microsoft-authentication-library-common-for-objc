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

#import "MSIDAADWebviewFactory.h"
#import "MSIDWebviewConfiguration.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDWebWPJAuthResponse.h"
#import "MSIDWebAADAuthResponse.h"
#import "MSIDDeviceId.h"
#import "MSIDAADOAuthEmbeddedWebviewController.h"
#import "MSIDWebviewSession.h"

@implementation MSIDAADWebviewFactory

- (NSMutableDictionary<NSString *,NSString *> *)authorizationParametersFromConfiguration:(MSIDWebviewConfiguration *)configuration requestState:(NSString *)state
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [super authorizationParametersFromConfiguration:configuration
                                                                                                 requestState:state];

    NSMutableOrderedSet<NSString *> *allScopes = parameters[MSID_OAUTH2_SCOPE].scopeSet.mutableCopy;
    
    if (!allScopes)
    {
        allScopes = [NSMutableOrderedSet new];
    }
    
    [allScopes addObject:MSID_OAUTH2_SCOPE_OPENID_VALUE];
    
    parameters[MSID_OAUTH2_SCOPE] = allScopes.msidToString;
    parameters[MSID_OAUTH2_PROMPT] = configuration.promptBehavior;
    
    if (configuration.correlationId)
    {
        [parameters addEntriesFromDictionary:
         @{
           MSID_OAUTH2_CORRELATION_ID_REQUEST : @"true",
           MSID_OAUTH2_CORRELATION_ID_REQUEST_VALUE : [configuration.correlationId UUIDString]
           }];
    }
    
    if (configuration.sliceParameters)
    {
        [parameters addEntriesFromDictionary:configuration.sliceParameters];
    }
    
    parameters[@"haschrome"] = @"1";
    parameters[MSID_OAUTH2_CLAIMS] = configuration.claims;
    [parameters addEntriesFromDictionary:MSIDDeviceId.deviceId];

    return parameters;
}

- (MSIDWebviewSession *)embeddedWebviewSessionFromConfiguration:(MSIDWebviewConfiguration *)configuration customWebview:(WKWebView *)webview context:(id<MSIDRequestContext>)context
{
    NSString *state = [self generateStateValue];
    NSURL *startURL = [self startURLFromConfiguration:configuration requestState:state];
    NSURL *redirectURL = [NSURL URLWithString:configuration.redirectUri];
    
    MSIDAADOAuthEmbeddedWebviewController *embeddedWebviewController
    = [[MSIDAADOAuthEmbeddedWebviewController alloc] initWithStartURL:startURL
                                                               endURL:redirectURL
                                                              webview:webview
                                                        configuration:configuration
                                                              context:context];
    
    MSIDWebviewSession *session = [[MSIDWebviewSession alloc] initWithWebviewController:embeddedWebviewController
                                                                                factory:self
                                                                            redirectUri:configuration.redirectUri
                                                                           requestState:state];
    return session;
}

- (MSIDWebviewResponse *)responseWithURL:(NSURL *)url
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    // Try to create a WPJ response
    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithURL:url context:context error:nil];
    if (wpjResponse) return wpjResponse;
    
    // Try to acreate AAD Auth response
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:url
                                                                           context:context
                                                                             error:error];
    return response;
}




@end
