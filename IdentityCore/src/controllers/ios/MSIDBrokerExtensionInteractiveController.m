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
#import "MSIDDefaultBrokerResponseHandler.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDefaultTokenResponseValidator.h"
#import "MSIDNotifications.h"
#import "MSIDBrokerInteractiveController.h"
#import "MSIDBrokerInteractiveController+Internal.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDJsonSerializer.h"

@interface MSIDBrokerExtensionInteractiveController () <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>

@property (nonatomic) ASAuthorizationController *authorizationController;

@end

@implementation MSIDBrokerExtensionInteractiveController

+ (BOOL)canPerformAuthorization
{
    return [[self sharedProvider] canPerformAuthorization];
}

- (void)openBrokerWithRequestURL:(NSURL *)requestURL
       fallbackToLocalController:(BOOL)shouldFallbackToLocalController
{
    // TODO: hack silent request with interactive params.
    MSIDBrokerOperationSilentTokenRequest *operationRequest = [MSIDBrokerOperationSilentTokenRequest new];
    operationRequest.configuration = self.interactiveParameters.msidConfiguration;
    operationRequest.accountIdentifier = self.interactiveParameters.accountIdentifier;
    
    NSString *jsonString = [[MSIDJsonSerializer new] toJsonString:operationRequest context:nil error:nil];
    
    if (!jsonString)
    {
        // TODO: Fail with error
    }
    
    ASAuthorizationSingleSignOnProvider *ssoProvider = [self.class sharedProvider];
    ASAuthorizationSingleSignOnRequest *request = [ssoProvider createRequest];
    NSURLQueryItem *queryItem = [[NSURLQueryItem alloc] initWithName:@"request" value:jsonString];
    request.authorizationOptions = @[queryItem];
    
    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
    self.authorizationController.delegate = self;
    self.authorizationController.presentationContextProvider = self;
    
    [self.authorizationController performRequests];
}

#pragma mark - ASAuthorizationControllerDelegate

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
{
    // TODO: hack
    ASAuthorizationSingleSignOnCredential *ssoCredential = (ASAuthorizationSingleSignOnCredential *)authorization.credential;
    
    NSDictionary *response = ssoCredential.authenticatedResponse.allHeaderFields;
    
    NSString *urlString = response[@"response"];
    NSURL *resultURL = [NSURL URLWithString:urlString];
    
    MSIDDefaultBrokerResponseHandler *responseHandler = [[MSIDDefaultBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new]
    tokenResponseValidator:[MSIDDefaultTokenResponseValidator new]];
    
    NSError *resultError = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:resultURL sourceApplication:@"" error:&resultError];

    [MSIDNotifications notifyWebAuthDidReceiveResponseFromBroker:result];

    if ([self.class currentBrokerController])
    {
        MSIDBrokerInteractiveController *currentBrokerController = [self.class currentBrokerController];
        [currentBrokerController completeAcquireTokenWithResult:result error:resultError];
    }

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
{
    if ([error.domain isEqualToString:ASAuthorizationErrorDomain])
    {
        if (error.code == ASAuthorizationErrorCanceled)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"User cancelled broker SSO Extension.");
            
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorUserCancel, @"User cancelled broker SSO Extension.", nil, nil, nil, self.requestParameters.correlationId, nil);
            
            if ([self.class currentBrokerController])
            {
                MSIDBrokerInteractiveController *currentBrokerController = [self.class currentBrokerController];
                [currentBrokerController completeAcquireTokenWithResult:nil error:error];
            }
            return;
        }
        
        if (error.code == ASAuthorizationErrorFailed)
        {
            // Try to get Broker Error.
            NSError *brokerError = error.userInfo[NSUnderlyingErrorKey];
            if (brokerError && [self.class currentBrokerController])
            {
                MSIDBrokerInteractiveController *currentBrokerController = [self.class currentBrokerController];
                [currentBrokerController completeAcquireTokenWithResult:nil error:brokerError];
            }
            return;
        }
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"Failed to open broker SSO Extension with error: %@. Falling back to local controller", error);
    [self handleFailedOpenURL:YES];
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
