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


#import <Foundation/Foundation.h>
#import "MSIDWebViewResponseFactory.h"
#import "MSIDWebOAuth2AuthCodeResponse.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDWebAADAuthCodeResponse.h"
#import "MSIDBrokerInteractiveController.h"

@implementation MSIDWebViewResponseFactory

+ (MSIDWebviewResponse *)oAuthResponseWithWebResponseType:(MSIDWebViewResponseType)type
                                                     url:(NSURL *)url
                                     requestState:(NSString *)requestState
                               ignoreInvalidState:(BOOL)ignoreInvalidState
                                          context:(id<MSIDRequestContext>)context
                                            error:(NSError **)error
{

    switch (type) {
        case MSIDWebViewResponseBaseType:
            return [self handleResponseWithBaseResponseTypeUrl:url
                                                  requestState:requestState
                                            ignoreInvalidState:ignoreInvalidState
                                                       context:context
                                                         error:error];
        case MSIDWebViewResponseRichType:
            return [self handleResponseWithRichResponseTypeUrl:url
                                                    requestState:requestState
                                              ignoreInvalidState:ignoreInvalidState
                                                         context:context
                                                           error:error];
        default:
            //Handle error: ie unsupported case or future extension
            return nil;
    }
}

+ (MSIDWebviewResponse *)handleResponseWithBaseResponseTypeUrl:(NSURL *)url
                                                  requestState:(NSString *)requestState
                                            ignoreInvalidState:(BOOL)ignoreInvalidState
                                                       context:(id<MSIDRequestContext>)context
                                                         error:(NSError **)error
{
    NSError *responseCreationError = nil;
    MSIDWebOAuth2AuthCodeResponse *response = [[MSIDWebOAuth2AuthCodeResponse alloc] initWithURL:url
                                                                    requestState:requestState
                                                              ignoreInvalidState:ignoreInvalidState
                                                                         context:context
                                                                           error:&responseCreationError];
    if (responseCreationError)
    {
        if (error)  *error = responseCreationError;
        return nil;
    }

    return response;
}

+ (MSIDWebviewResponse *)handleResponseWithRichResponseTypeUrl:(NSURL *)url
                                                  requestState:(NSString *)requestState
                                            ignoreInvalidState:(BOOL)ignoreInvalidState
                                                       context:(id< MSIDRequestContext>)context
                                                         error:(NSError **)error
{
        // Try to create CBA response
    #if AD_BROKER
        MSIDCBAWebAADAuthResponse *cbaResponse = [[MSIDCBAWebAADAuthResponse alloc] initWithURL:url context:context error:nil];
        if (cbaResponse) return cbaResponse;
    #endif

        // Try to create a WPJ response
        MSIDWebWPJResponse *wpjResponse = [[MSIDWebWPJResponse alloc] initWithURL:url context:context error:nil];
        if (wpjResponse) return wpjResponse;

        // Try to create a browser reponse
        MSIDWebOpenBrowserResponse *browserResponse = [[MSIDWebOpenBrowserResponse alloc] initWithURL:url
                                                                                              context:context
                                                                                                error:nil];
        if (browserResponse) return browserResponse;

        // Try to acreate AAD Auth response
        MSIDWebAADAuthCodeResponse *response = [[MSIDWebAADAuthCodeResponse alloc] initWithURL:url
                                                                          requestState:requestState
                                                                    ignoreInvalidState:ignoreInvalidState
                                                                               context:context
                                                                                 error:error];
        return response;
}

@end
