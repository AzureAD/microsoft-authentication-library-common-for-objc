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
#import "MSIDSSOExtensionSilentTokenRequest.h"
#import "MSIDSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDJsonSerializer.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDSSOExtensionTokenRequestDelegate.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDOauth2Factory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDIntuneMAMResourcesCache.h"
#import "MSIDSSOTokenResponseHandler.h"
#import "MSIDThrottlingService.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDXPCServiceEndpointAccessory.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "NSData+MSIDExtensions.h"

#if !EXCLUDE_FROM_MSALCPP
#import "MSIDLastRequestTelemetry.h"
#endif

@interface MSIDSSOExtensionSilentTokenRequest () <ASAuthorizationControllerDelegate>

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) id<MSIDCacheAccessor> tokenCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDSSOExtensionTokenRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic, readonly) MSIDProviderType providerType;
@property (nonatomic, readonly) MSIDIntuneEnrollmentIdsCache *enrollmentIdsCache;
@property (nonatomic, readonly) MSIDIntuneMAMResourcesCache *mamResourcesCache;
@property (nonatomic, readonly) MSIDSSOTokenResponseHandler *ssoTokenResponseHandler;
@property (nonatomic) MSIDBrokerOperationSilentTokenRequest *operationRequest;
@property (nonatomic) NSDate *requestSentDate;
@property (nonatomic, copy) MSIDSSOExtensionRequestDelegateCompletionBlock completionBlock;

@end

@implementation MSIDSSOExtensionSilentTokenRequest

- (instancetype)initWithRequestParameters:(MSIDRequestParameters *)parameters
                             forceRefresh:(BOOL)forceRefresh
                             oauthFactory:(MSIDOauth2Factory *)oauthFactory
                   tokenResponseValidator:(MSIDTokenResponseValidator *)tokenResponseValidator
                               tokenCache:(id<MSIDCacheAccessor>)tokenCache
                     accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       extendedTokenCache:(nullable id<MSIDExtendedTokenCacheDataSource>)extendedTokenCache
{
    self = [super initWithRequestParameters:parameters
                               forceRefresh:forceRefresh
                               oauthFactory:oauthFactory
                     tokenResponseValidator:tokenResponseValidator];

    if (self)
    {
        _tokenCache = tokenCache;
        _ssoTokenResponseHandler = [MSIDSSOTokenResponseHandler new];
        _extensionDelegate = [MSIDSSOExtensionTokenRequestDelegate new];
        _extensionDelegate.context = parameters;
        __typeof__(self) __weak weakSelf = self;
        self.completionBlock = ^(MSIDBrokerOperationTokenResponse *operationResponse, NSError *error)
        {
            __typeof__(self) strongSelf = weakSelf;
#if TARGET_OS_OSX && !EXCLUDE_FROM_MSALCPP
            strongSelf.ssoTokenResponseHandler.externalCacheSeeder = strongSelf.externalCacheSeeder;
#endif
            
#if !EXCLUDE_FROM_MSALCPP
            [operationResponse trackPerfTelemetryWithLastRequest:strongSelf.lastRequestTelemetry
                                                requestStartDate:strongSelf.requestSentDate
                                                   telemetryType:MSID_PERF_TELEMETRY_SILENT_TYPE];
#endif
            
            [strongSelf.ssoTokenResponseHandler handleOperationResponse:operationResponse
                                                      requestParameters:strongSelf.requestParameters
                                                 tokenResponseValidator:strongSelf.tokenResponseValidator
                                                           oauthFactory:strongSelf.oauthFactory
                                                             tokenCache:strongSelf.tokenCache
                                                   accountMetadataCache:strongSelf.accountMetadataCache
                                                        validateAccount:NO
                                                                  error:error
                                                        completionBlock:^(MSIDTokenResult *result, NSError *localError)
             {
                MSIDRequestCompletionBlock completionBlock = strongSelf.requestCompletionBlock;
                strongSelf.requestCompletionBlock = nil;
                if (localError)
                {
                    /**
                     * If SSO-EXT responses error, we should update throttling db
                     */
                    if ([MSIDThrottlingService isThrottlingEnabled])
                    {
                        [strongSelf.throttlingService updateThrottlingService:localError tokenRequest:strongSelf.operationRequest];
                    }
                }
                if (completionBlock) completionBlock(result, localError);
            }];
        };

        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
        _providerType = [[oauthFactory class] providerType];
        _enrollmentIdsCache = [MSIDIntuneEnrollmentIdsCache sharedCache];
        _mamResourcesCache = [MSIDIntuneMAMResourcesCache sharedCache];
        _accountMetadataCache = accountMetadataCache;

        self.throttlingService = [[MSIDThrottlingService alloc] initWithDataSource:extendedTokenCache context:parameters];
    }

    return self;
}

#pragma mark - MSIDSilentTokenRequest

- (void)executeRequestWithCompletion:(MSIDRequestCompletionBlock)completionBlock
{
    if (!self.requestParameters.accountIdentifier)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.requestParameters, @"Account parameter cannot be nil");

        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorMissingAccountParameter, @"Account parameter cannot be nil", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    NSString *upn = self.requestParameters.accountIdentifier.displayableId;

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

        NSDictionary *enrollmentIds = [self.enrollmentIdsCache enrollmentIdsJsonDictionaryWithContext:self.requestParameters
                                                                                                error:nil];

        NSDictionary *mamResources = [self.mamResourcesCache resourcesJsonDictionaryWithContext:self.requestParameters
                                                                                          error:nil];
        self.requestSentDate = [NSDate date];
        self.operationRequest = [MSIDBrokerOperationSilentTokenRequest tokenRequestWithParameters:self.requestParameters
                                                                                            providerType:self.providerType
                                                                                           enrollmentIds:enrollmentIds
                                                                                            mamResources:mamResources
                                                                                  requestSentDate:self.requestSentDate];
        if (![MSIDThrottlingService isThrottlingEnabled])
        {
            [self executeRequestImplWithCompletionBlock:completionBlock];
        }
        else
        {
            [self.throttlingService shouldThrottleRequest:self.operationRequest resultBlock:^(BOOL shouldBeThrottled, NSError * _Nullable cachedError)
             {
                MSID_LOG_WITH_CTX(MSIDLogLevelInfo, self.requestParameters, @"Throttle decision: %@" , (shouldBeThrottled ? @"YES" : @"NO"));

                if (cachedError)
                {
                    MSID_LOG_WITH_CTX(MSIDLogLevelWarning, self.requestParameters, @"Throttling return error: %@ ", MSID_PII_LOG_MASKABLE(cachedError));
                }

                if (shouldBeThrottled && cachedError)
                {
                    completionBlock(nil,cachedError);
                    return;
                }

                [self executeRequestImplWithCompletionBlock:completionBlock];
            }];
        }

    }];
}

- (void)executeRequestImplWithCompletionBlock:(MSIDRequestCompletionBlock _Nonnull)completionBlock
{
    NSDictionary *jsonDictionary = [self.operationRequest jsonDictionary];

    if (!jsonDictionary)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to serialize SSO request dictionary for silent token request", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    self.requestCompletionBlock = completionBlock;
    [self nativeXpcFlow:jsonDictionary];
    
//    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createRequest];
//    ssoRequest.requestedOperation = [self.operationRequest.class operation];
//    __auto_type queryItems = [jsonDictionary msidQueryItems];
//    ssoRequest.authorizationOptions = queryItems;
//    [ASAuthorizationSingleSignOnProvider setRequiresUI:NO forRequest:ssoRequest];

//    self.authorizationController = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
//    self.authorizationController.delegate = self.extensionDelegate;
//    
//    [self.authorizationController msidPerformRequests];
//
//    self.requestCompletionBlock = completionBlock;
}

- (id<MSIDCacheAccessor>)tokenCache
{
    return _tokenCache;
}

- (MSIDAccountMetadataCacheAccessor *)metadataCache
{
    return self.accountMetadataCache;
}

- (void)nativeXpcFlow:(NSDictionary *)ssoRequest
{
    // Get the bundle object for the main bundle
    NSBundle *mainBundle = [NSBundle mainBundle];

    // Retrieve the bundle identifier
    NSString *bundleIdentifier = [mainBundle bundleIdentifier]; // source_application
    NSDictionary *input = @{@"source_application": bundleIdentifier, 
                            @"sso_request_param": ssoRequest,
                            @"is_silent": @(YES),
                            @"sso_request_operation": [self.operationRequest.class operation],
                            @"sso_request_id": [[NSUUID UUID] UUIDString]};
//    NSDate *innerStartTime = [NSDate date];
    MSIDXPCServiceEndpointAccessory *accessory = [MSIDXPCServiceEndpointAccessory new];
    [accessory getXpcService:^(id<ADBChildBrokerProtocol>  _Nonnull xpcService) {
        [xpcService acquireTokenSilentlyFromBroker:input parentViewFrame:NSMakeRect(0, 0, 0, 0) completionBlock:^(NSDictionary *replyParam, NSDate* __unused xpcStartDate, NSString __unused *processId, NSError *error) {
//            NSDate *replyDate = [NSDate date];
            MSIDBrokerCryptoProvider *cryptoProvider = [[MSIDBrokerCryptoProvider alloc] initWithEncryptionKey:[NSData msidDataFromBase64UrlEncodedString:self.operationRequest.brokerKey]];
            NSDictionary *jsonResponse = [cryptoProvider decryptBrokerResponse:replyParam correlationId:nil error:nil];
            
            BOOL forceRunOnBackgroundQueue = [[jsonResponse objectForKey:MSID_BROKER_OPERATION_KEY] isEqualToString:@"refresh"];
            [self forceRunOnBackgroundQueue:forceRunOnBackgroundQueue dispatchBlock:^{
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
    }];
}

- (void)forceRunOnBackgroundQueue:(BOOL)forceOnBackgroundQueue dispatchBlock:(void (^)(void))dispatchBlock {
    if (forceOnBackgroundQueue && [NSThread isMainThread])
    {
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            dispatchBlock();
        });
    }
    else
    {
        dispatchBlock();
    }
}

@end
#endif
