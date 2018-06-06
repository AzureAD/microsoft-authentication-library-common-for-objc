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

#import "MSIDAADV2WebviewFactory.h"
#import "MSIDWebviewConfiguration.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDWebWPJAuthResponse.h"
#import "MSIDWebAADAuthResponse.h"

@implementation MSIDAADV2WebviewFactory

- (MSIDWebviewSession *)embeddedWebviewSessionFromConfiguration:(MSIDWebviewConfiguration *)configuration verifyState:(BOOL)verifyState customWebview:(WKWebView *)webview context:(id<MSIDRequestContext>)context
{
    return nil;
}


- (NSMutableDictionary<NSString *,NSString *> *)authorizationParametersFromConfiguration:(MSIDWebviewConfiguration *)configuration requestState:(NSString *)state
{
    NSMutableDictionary<NSString *, NSString *> *parameters = [super authorizationParametersFromConfiguration:configuration
                                                                                                 requestState:state];
    
    NSOrderedSet<NSString *> *allScopes = configuration.scopes;
    parameters[MSID_OAUTH2_SCOPE] = [NSString stringWithFormat:@"%@ %@", MSID_OAUTH2_SCOPE_OPENID_VALUE,  [allScopes msidToString]];
    parameters[MSID_OAUTH2_PROMPT] = configuration.promptBehavior;
    parameters[@"haschrome"] = @"1";
    
    return parameters;
}

- (MSIDWebviewResponse *)responseWithURL:(NSURL *)url
                                 context:(id<MSIDRequestContext>)context
                                   error:(NSError **)error
{
    MSIDWebWPJAuthResponse *wpjResponse = [[MSIDWebWPJAuthResponse alloc] initWithURL:url context:context error:nil];

    if (wpjResponse) return wpjResponse;
    
    NSError *responseCreationError = nil;
    MSIDWebAADAuthResponse *response = [[MSIDWebAADAuthResponse alloc] initWithURL:url
                                                                           context:context
                                                                             error:&responseCreationError];
    if (responseCreationError) {
        if (error)  *error = responseCreationError;
        return nil;
    }
    
    return response;
}



@end
