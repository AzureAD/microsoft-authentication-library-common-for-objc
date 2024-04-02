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

#if MSID_ENABLE_SSO_EXTENSION
#import <AuthenticationServices/AuthenticationServices.h>
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionInteractiveTokenRequest.h"
#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDJsonSerializer.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationInteractiveTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDSSOTokenResponseHandler.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDXPCServiceEndpointAccessory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "NSData+MSIDExtensions.h"

#if TARGET_OS_IPHONE
#import "MSIDBackgroundTaskManager.h"
#endif

@interface MSIDSSOExtensionInteractiveTokenRequest () <ASAuthorizationControllerPresentationContextProviding>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDInteractiveRequestCompletionBlock requestCompletionBlock;
@property (nonatomic, copy) MSIDSSOExtensionRequestDelegateCompletionBlock completionBlock;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;
@property (nonatomic, readonly) MSIDSSOTokenResponseHandler *ssoTokenResponseHandler;
@property (nonatomic) NSDate *requestSentDate;
@property (nonatomic) MSIDBrokerOperationInteractiveTokenRequest *operationRequest;

@end

@implementation MSIDSSOExtensionInteractiveTokenRequest

- (instancetype)initWithRequestParameters:(MSIDInteractiveTokenRequestParameters *)parameters
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       extendedTokenCache:(id<MSIDExtendedTokenCacheDataSource>)extendedTokenCache
{
    self = [super initWithRequestParameters:parameters
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                       accountMetadataCache:accountMetadataCache
                         extendedTokenCache:extendedTokenCache];

    if (self)
    {
        _ssoTokenResponseHandler = [MSIDSSOTokenResponseHandler new];
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __typeof__(self) __weak weakSelf = self;
//        _extensionDelegate.completionBlock
        self.completionBlock = ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
        {
#if TARGET_OS_IPHONE
            [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
            __typeof__(self) strongSelf = weakSelf;
            
#if TARGET_OS_OSX && !EXCLUDE_FROM_MSALCPP
            strongSelf.ssoTokenResponseHandler.externalCacheSeeder = strongSelf.externalCacheSeeder;
#endif
            [strongSelf.ssoTokenResponseHandler handleOperationResponse:operationResponse
                                                      requestParameters:strongSelf.requestParameters
                                                 tokenResponseValidator:strongSelf.tokenResponseValidator
                                                           oauthFactory:strongSelf.oauthFactory
                                                             tokenCache:strongSelf.tokenCache
                                                   accountMetadataCache:strongSelf.accountMetadataCache
                                                        validateAccount:strongSelf.requestParameters.shouldValidateResultAccount
                                                                  error:error
                                                        completionBlock:^(MSIDTokenResult *result, NSError *localError)
             {
                MSIDInteractiveRequestCompletionBlock completionBlock = strongSelf.requestCompletionBlock;
                weakSelf.requestCompletionBlock = nil;
                if (completionBlock) completionBlock(result, localError, nil);
            }];
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
        _providerType = [oauthFactory.class providerType];
        _enrollmentIdsCache = [MSIDIntuneEnrollmentIdsCache sharedCache];
        _mamResourcesCache = [MSIDIntuneMAMResourcesCache sharedCache];
    }

    return self;
}

#pragma mark - MSIDInteractiveTokenRequest

- (void)executeRequestWithCompletion:(MSIDInteractiveRequestCompletionBlock)completionBlock
{
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Beginning interactive broker flow.");
    
    if (!completionBlock)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Passed nil completionBlock. End silent broker flow.");
        return;
    }
    
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.requestParameters.loginHint;
    
    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                           userPrincipalName:upn
                                                     context:self.requestParameters
                                             completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                                               __unused BOOL validated, NSError *error)
     {
        if (error)
        {
            completionBlock(nil, error, nil);
            return;
        }
        
        NSDictionary *enrollmentIds = [self.enrollmentIdsCache enrollmentIdsJsonDictionaryWithContext:self.requestParameters
                                                                                                error:nil];
        NSDictionary *mamResources = [self.mamResourcesCache resourcesJsonDictionaryWithContext:self.requestParameters
                                                                                          error:nil];
        
        self.requestSentDate = [NSDate date];
        NSRect frame = self.requestParameters.parentViewController.view.window.frame;
        self.operationRequest = [MSIDBrokerOperationInteractiveTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                                 providerType:self.providerType
                                                                                                enrollmentIds:enrollmentIds
                                                                                                 mamResources:mamResources
                                                                                              requestSentDate:self.requestSentDate];
        
        ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
        ssoRequest.requestedOperation = [self.operationRequest.class operation];
        [ASAuthorizationSingleSignOnProvider setRequiresUI:YES forRequest:ssoRequest];
        
        NSDictionary *jsonDictionary = [self.operationRequest jsonDictionary];
        
        if (!jsonDictionary)
        {
            error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to serialize SSO request dictionary for interactive token request", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
            completionBlock(nil, error, nil);
            return;
        }
        
        [self nativeXpcFlow:jsonDictionary parentViewFrame:frame];
        
//        __auto_type queryItems = [jsonDictionary msidQueryItems];
//        ssoRequest.authorizationOptions = queryItems;
//        
//#if TARGET_OS_IPHONE
//        [[MSIDBackgroundTaskManager sharedInstance] startOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
//#endif
//        
//        self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
//        self.authorizationController.delegate = self.extensionDelegate;
//        self.authorizationController.presentationContextProvider = self;
//        [self.authorizationController msidPerformRequests];
//        
        self.requestCompletionBlock = completionBlock;
     }];
}

#pragma mark - ASAuthorizationControllerPresentationContextProviding

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(__unused ASAuthorizationController *)controller
{
    return [self presentationAnchor];
}

- (ASPresentationAnchor)presentationAnchor
{
    if (![NSThread isMainThread])
    {
        __block ASPresentationAnchor anchor;
        dispatch_sync(dispatch_get_main_queue(), ^{
            anchor = [self presentationAnchor];
        });
        
        return anchor;
    }
    
    __typeof__(self.requestParameters.parentViewController) parentViewController = self.requestParameters.parentViewController;
    return parentViewController ? parentViewController.view.window : self.requestParameters.presentationAnchorWindow;
}

#pragma mark - Dealloc

- (void)dealloc
{
#if TARGET_OS_IPHONE
    [[MSIDBackgroundTaskManager sharedInstance] stopOperationWithType:MSIDBackgroundTaskTypeInteractiveRequest];
#endif
}

- (void)nativeXpcFlow:(NSDictionary *)ssoRequest parentViewFrame:(NSRect)frame
 {
     // Get the bundle object for the main bundle
     NSBundle *mainBundle = [NSBundle mainBundle];

     // Retrieve the bundle identifier
     NSString *bundleIdentifier = [mainBundle bundleIdentifier]; // source_application
     NSDictionary *input = @{@"source_application": bundleIdentifier,
                             @"sso_request_param": ssoRequest,
                             @"is_silent": @(NO),
                             @"sso_request_operation": [self.operationRequest.class operation],
                             @"sso_request_id": [[NSUUID UUID] UUIDString]};
 //    NSDate *innerStartTime = [NSDate date];
     MSIDXPCServiceEndpointAccessory *accessory = [MSIDXPCServiceEndpointAccessory new];
     [accessory getXpcService:^(id<ADBChildBrokerProtocol>  _Nonnull xpcService) {
         [xpcService acquireTokenSilentlyFromBroker:input parentViewFrame:frame completionBlock:^(NSDictionary *replyParam, NSDate* __unused xpcStartDate, NSString __unused *processId, NSError *error) {
 //            NSDate *replyDate = [NSDate date];
             MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:[NSData msidDataFromBase64UrlEncodedString:self.operationRequest.brokerKey]];
             NSDictionary *jsonResponse = [cryptoProvider decryptBrokerResponse:replyParam correlationId:nil error:nil];
             if (error)
             {
                 NSLog(@"[Entra broker] CLIENT Time spent, received operationResponse with error: %@", error.description);
                 self.completionBlock(nil, error);
                 return;
             }
             NSError *innerError = nil;
             __auto_type operationResponse = (MSIDBrokerOperationTokenResponse *)[MSIDJsonSerializableFactory createFromJSONDictionary:jsonResponse classTypeJSONKey:MSID_BROKER_OPERATION_RESPONSE_TYPE_JSON_KEY assertKindOfClass:MSIDBrokerOperationTokenResponse.class error:&innerError];

             if (!operationResponse)
             {
                 NSLog(@"[Entra broker] CLIENT Time spent, received operationResponse: %@", operationResponse.jsonDictionary);
             }
             else
             {
                 self.completionBlock(operationResponse, error);
             }
         }];
     }];
 }
 @end
 #endif

