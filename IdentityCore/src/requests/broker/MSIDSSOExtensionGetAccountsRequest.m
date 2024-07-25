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

#import "MSIDSSOExtensionGetAccountsRequest.h"
#import "MSIDRequestParameters.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import "MSIDSSOExtensionOperationRequestDelegate.h"
#import "ASAuthorizationSingleSignOnProvider+MSIDExtensions.h"
#import "MSIDBrokerNativeAppOperationResponse.h"
#import "MSIDBrokerOperationGetAccountsRequest.h"
#import "NSDictionary+MSIDQueryItems.h"
#import "MSIDBrokerOperationGetAccountsResponse.h"
#import "MSIDDeviceInfo.h"
#import "ASAuthorizationController+MSIDExtensions.h"
#import "MSIDXPCServiceEndpointAccessory.h"
#import "MSIDBrokerCryptoProvider.h"
#import "NSData+MSIDExtensions.h"
#import "MSIDJsonSerializableFactory.h"
#import "MSIDBrokerOperationTokenResponse.h"

#if !EXCLUDE_FROM_MSALCPP
#import "MSIDLastRequestTelemetry.h"
#endif

// TODO: 1656998 This file can be refactored and use MSIDSSOExtensionGetDataBaseRequest as super class
@interface MSIDSSOExtensionGetAccountsRequest()

@property (nonatomic) ASAuthorizationController *authorizationController;
@property (nonatomic, copy) MSIDGetAccountsRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDSSOExtensionOperationRequestDelegate *extensionDelegate;
@property (nonatomic) ASAuthorizationSingleSignOnProvider *ssoProvider;
@property (nonatomic) MSIDRequestParameters *requestParameters;
@property (nonatomic) BOOL returnOnlySignedInAccounts;
@property (nonatomic) NSDate *requestSentDate;
@property (nonatomic) MSIDBrokerOperationGetAccountsRequest *getAccountsRequest;
@property (nonatomic, copy) MSIDSSOExtensionRequestDelegateCompletionBlock completionBlock;

#if !EXCLUDE_FROM_MSALCPP
@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;
#endif
 
@end

@implementation MSIDSSOExtensionGetAccountsRequest

- (nullable instancetype)initWithRequestParameters:(MSIDRequestParameters *)requestParameters
                        returnOnlySignedInAccounts:(BOOL)returnOnlySignedInAccounts
                                             error:(NSError * _Nullable * _Nullable)error
{
    self = [super init];
    
    if (!requestParameters)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Unexpected error. Nil request parameter provided", nil, nil, nil, nil, nil, YES);
        }
        
        return nil;
    }
    
    if (self)
    {
        _requestParameters = requestParameters;
        _returnOnlySignedInAccounts = returnOnlySignedInAccounts;
        
        _extensionDelegate = [MSIDSSOExtensionOperationRequestDelegate new];
        _extensionDelegate.context = requestParameters;
        __typeof__(self) __weak weakSelf = self;
        self.completionBlock = ^(MSIDBrokerNativeAppOperationResponse *operationResponse, NSError *resultError)
        {
            NSArray *resultAccounts = nil;
            BOOL returnBrokerAccountsOnly = NO;
            
            if (!operationResponse.success)
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, requestParameters, @"Finished get accounts request with error %@", MSID_PII_LOG_MASKABLE(resultError));
            }
            else if (![operationResponse isKindOfClass:[MSIDBrokerOperationGetAccountsResponse class]])
            {
                resultError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Received incorrect response type for the get accounts request", nil, nil, nil, nil, nil, YES);
            }
            else
            {
                MSIDBrokerOperationGetAccountsResponse *response = (MSIDBrokerOperationGetAccountsResponse *)operationResponse;
                resultAccounts = response.accounts;
                returnBrokerAccountsOnly = operationResponse.deviceInfo.deviceMode == MSIDDeviceModeShared;
            }
            
            __typeof__(self) strongSelf = weakSelf;
            
#if !EXCLUDE_FROM_MSALCPP
            [operationResponse trackPerfTelemetryWithLastRequest:strongSelf.lastRequestTelemetry
                                                requestStartDate:strongSelf.requestSentDate
                                                   telemetryType:MSID_PERF_TELEMETRY_GETACCOUNTS_TYPE];
#endif
            
            MSIDGetAccountsRequestCompletionBlock completionBlock = strongSelf.requestCompletionBlock;
            strongSelf.requestCompletionBlock = nil;
            
            if (completionBlock) completionBlock(resultAccounts, returnBrokerAccountsOnly, resultError);
        };
        
        _ssoProvider = [ASAuthorizationSingleSignOnProvider msidSharedProvider];
#if !EXCLUDE_FROM_MSALCPP
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
#endif
    }
    
    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDGetAccountsRequestCompletionBlock)completionBlock
{
    self.getAccountsRequest = [MSIDBrokerOperationGetAccountsRequest new];
    [MSIDBrokerOperationGetAccountsRequest fillRequest:self.getAccountsRequest
                                   keychainAccessGroup:self.requestParameters.keychainAccessGroup
                                        clientMetadata:self.requestParameters.appRequestMetadata
                 clientBrokerKeyCapabilityNotSupported: self.requestParameters.clientBrokerKeyCapabilityNotSupported
                                               context:self.requestParameters];
    self.getAccountsRequest.clientId = self.requestParameters.clientId;
    self.getAccountsRequest.returnOnlySignedInAccounts = self.returnOnlySignedInAccounts;
    // TODO: pass familyId, will be addressed in a separate PR
    // TODO: pass returnOnlySignedInAccounts == false, will be addressed in a separate PR

//    NSError *error;
//    ASAuthorizationSingleSignOnRequest *ssoRequest = [self.ssoProvider createSSORequestWithOperationRequest:getAccountsRequest
//                                                                                          requestParameters:self.requestParameters
//                                                                                                 requiresUI:NO
//                                                                                                      error:&error];
//    
//    if (!ssoRequest)
//    {
//        completionBlock(nil, NO, error);
//        return;
//    }
//        
//    self.authorizationController = [self controllerWithRequest:ssoRequest];
//    self.authorizationController.delegate = self.extensionDelegate;
//    
//    self.requestSentDate = [NSDate date];
//    [self.authorizationController msidPerformRequests];
//    
    self.requestCompletionBlock = completionBlock;
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
    //Background Thread
        [self nativeXpcFlow:[self.getAccountsRequest jsonDictionary]];
    });
}

#pragma mark - AuthenticationServices

- (ASAuthorizationController *)controllerWithRequest:(ASAuthorizationSingleSignOnRequest *)ssoRequest
{
    return [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[ssoRequest]];
}

+ (BOOL)canPerformRequest
{
    return [[ASAuthorizationSingleSignOnProvider msidSharedProvider] canPerformAuthorization];
}

- (void)nativeXpcFlow:(NSDictionary *)ssoRequest
{
    NSMutableDictionary *withAuthorityDict = [ssoRequest mutableCopy];
    withAuthorityDict[@"authority"] = MSID_DEFAULT_AAD_AUTHORITY;
    // Get the bundle object for the main bundle
    NSBundle *mainBundle = [NSBundle mainBundle];

    // Retrieve the bundle identifier
    NSString *bundleIdentifier = [mainBundle bundleIdentifier]; // source_application
    NSDictionary *input = @{@"source_application": bundleIdentifier,
                            @"sso_request_param": withAuthorityDict,
                            @"is_silent": @(YES),
                            @"sso_request_operation": [self.getAccountsRequest.class operation],
                            @"sso_request_id": [[NSUUID UUID] UUIDString]};
//    NSDate *innerStartTime = [NSDate date];
    MSIDXPCServiceEndpointAccessory *accessory = [MSIDXPCServiceEndpointAccessory new];
    [accessory handleRequestParam:input
                        brokerKey:self.getAccountsRequest.brokerKey
        assertKindOfResponseClass:MSIDBrokerNativeAppOperationResponse.class
                    continueBlock:^(id  _Nullable response, NSError * _Nullable error) {
        self.completionBlock(response, error);
    }];
}

@end

#endif
