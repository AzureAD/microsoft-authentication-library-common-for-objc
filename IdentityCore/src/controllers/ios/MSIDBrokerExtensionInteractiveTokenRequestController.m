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

#import "MSIDBrokerExtensionInteractiveTokenRequestController.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "MSIDVersion.h"
#import "MSIDJsonSerializer.h"
#import "MSIDBrokerExtensionTokenRequestController+Internal.h"
#import "MSIDAuthority.h"
#import "MSIDInteractiveRequestParameters.h"

@interface MSIDBrokerExtensionInteractiveTokenRequestController () <ASAuthorizationControllerPresentationContextProviding>

@end

@implementation MSIDBrokerExtensionInteractiveTokenRequestController

- (instancetype)initWithInteractiveRequestParameters:(MSIDInteractiveRequestParameters *)parameters
                                tokenRequestProvider:(id<MSIDTokenRequestProviding>)tokenRequestProvider
                                  fallbackController:(id<MSIDRequestControlling>)fallbackController
                                               error:(NSError **)error
{
    self = [super initWithRequestParameters:parameters
                       tokenRequestProvider:tokenRequestProvider
                         fallbackController:fallbackController
                                      error:error];
    if (self)
    {
        _interactiveRequestParameters = parameters;
    }
    
    return self;
}

#pragma mark - MSIDRequestControlling

- (void)acquireToken:(MSIDRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive broker flow.");
    
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End silent broker flow.");
        return;
    }
    
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.interactiveRequestParameters.loginHint;
    
    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                           userPrincipalName:upn
                                                     context:self.requestParameters
                                             completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                                               __unused BOOL validated, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error);
             return;
         }
        
        NSString *accessGroup = self.requestParameters.keychainAccessGroup ?: MSIDKeychainTokenCache.defaultKeychainGroup;
        __auto_type brokerKeyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:accessGroup];
        
        // TODO: move this logic to MSIDBrokerKeyProvider (broker key as string)
        NSError *localError;
        NSData *brokerKey = [brokerKeyProvider brokerKeyWithError:&localError];
        
        if (!brokerKey)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, self.requestParameters, @"Failed to retrieve broker key with error %@", MSID_PII_LOG_MASKABLE(localError));
            
            // TODO: Fail with error
            return;
        }
        
        NSString *base64UrlKey = [[NSString msidBase64UrlEncodedStringFromData:brokerKey] msidWWWFormURLEncode];
        
        if (!base64UrlKey)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Unable to base64 encode broker key");
            
            // TODO: Fail with error
            
            return;
        }
        
        NSDictionary *clientMetadata = self.requestParameters.appRequestMetadata;
        //    NSString *claimsString = [self claimsParameter];
        NSString *clientAppName = clientMetadata[MSID_APP_NAME_KEY];
        NSString *clientAppVersion = clientMetadata[MSID_APP_VER_KEY];
        
        // TODO: hack silent request with interactive params.
        MSIDBrokerOperationInteractiveTokenRequest *operationRequest = [MSIDBrokerOperationInteractiveTokenRequest new];
        operationRequest.brokerKey = base64UrlKey;
        operationRequest.clientVersion = [MSIDVersion sdkVersion];
        operationRequest.protocolVersion = 4;
        operationRequest.clientAppVersion = clientAppVersion;
        operationRequest.clientAppName = clientAppName;
        operationRequest.correlationId = self.requestParameters.correlationId;
        operationRequest.configuration = self.requestParameters.msidConfiguration;
        operationRequest.accountIdentifier = self.requestParameters.accountIdentifier;
        
        operationRequest.loginHint = self.interactiveRequestParameters.loginHint;
        operationRequest.promptType = self.interactiveRequestParameters.promptType;
        
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
        self.requestCompletionBlock = completionBlock;
     }];
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller
{
    return self.interactiveRequestParameters.parentViewController.view.window;
}

@end
