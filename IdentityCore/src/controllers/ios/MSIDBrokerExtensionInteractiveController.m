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

#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDBrokerExtensionInteractiveController.h"
#import "MSIDInteractiveRequestParameters.h"

@interface MSIDBrokerExtensionInteractiveController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>

@property (nonatomic) ASAuthorizationController *authorizationController;

@end

@implementation MSIDBrokerExtensionInteractiveController

+ (BOOL)canPerformAuthorization
{
    return [[self sharedProvider] canPerformAuthorization];
}

- (void)openBrokerWithRequestURL:(NSURL *)requestURL
{
    ASAuthorizationSingleSignOnProvider *ssoProvider = [self.class sharedProvider];
    ASAuthorizationSingleSignOnRequest *request = [ssoProvider createRequest];
    request.requestedOperation = @"interactive_login";
    
    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    self.authorizationController.delegate = self;
    self.authorizationController.presentationContextProvider = self;
    
    [self.authorizationController performRequests];
    
//    [super openBrokerWithRequestURL:requestURL];
    
    
//    __auto_type ssoProvider = [self.class ssoProvider];
//
//    let request: ASAuthorizationSingleSignOnRequest = ssoProvider.createRequest()
//    request.requestedOperation = ASAuthorization.OpenIDOperation(operation)
//    request.requestedScopes = [.fullName, .email]
//
//    self.authorizationController = ASAuthorizationController(authorizationRequests: [request])
//    authorizationController?.delegate = self
//    authorizationController?.presentationContextProvider = self
//    authorizationController?.performRequests()
    
//    NSDictionary *options = nil;
//
//    if (self.interactiveParameters.brokerInvocationOptions.isUniversalLink)
//    {
//        // Option for openURL:options:CompletionHandler: only open URL if it is a valid universal link with an application configured to open it
//        // If there is no application configured, or the user disabled using it to open the link, completion handler called with NO
//        if (@available(iOS 10.0, *))
//        {
//            options = @{UIApplicationOpenURLOptionUniversalLinksOnly : @YES};
//        }
//    }
//
//    [MSIDAppExtensionUtil sharedApplicationOpenURL:requestURL
//                                           options:options
//                                 completionHandler:^(BOOL success) {
//
//                                     if (!success)
//                                     {
//                                         MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"Failed to open broker URL. Falling back to local controller");
//
//                                         [self fallbackToLocalController];
//                                     }
//
//    }];
}

#pragma mark - ASAuthorizationControllerDelegate

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
{
    
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
{
    
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller
{
    return self.interactiveParameters.parentViewController.view.window;
}

#pragma mark - Private

+ (ASAuthorizationSingleSignOnProvider *)sharedProvider
{
    static dispatch_once_t once;
    static ASAuthorizationSingleSignOnProvider *ssoProvider;
    
    dispatch_once(&once, ^{
        NSURL *url = [NSURL URLWithString:@"https://ios-sso-test.azurewebsites.net"];
    
        ssoProvider = [ASAuthorizationSingleSignOnProvider authorizationProviderWithIdentityProviderURL:url];
    });
    
    return ssoProvider;
}

@end
