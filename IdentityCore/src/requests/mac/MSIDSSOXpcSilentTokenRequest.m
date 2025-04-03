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


#import "MSIDSSOXpcSilentTokenRequest.h"
#import "MSIDSSOExtensionRequestDelegate.h"
#import "MSIDBrokerOperationSilentTokenRequest.h"
#import "MSIDRequestParameters.h"
#import "MSIDXpcSingleSignOnProvider.h"
#import "MSIDBrokerOperationTokenResponse.h"

@interface MSIDSSOXpcSilentTokenRequest()

@property (nonatomic, copy) MSIDSSOExtensionRequestDelegateCompletionBlock completionBlock;
@property (nonatomic, copy) MSIDRequestCompletionBlock requestCompletionBlock;
@property (nonatomic) MSIDBrokerOperationSilentTokenRequest *operationRequest;
@property (nonatomic) MSIDXpcSingleSignOnProvider *xpcSingleSignOnProvider;
@property (nonatomic) id<MSIDRequestContext> context;

@end

@implementation MSIDSSOXpcSilentTokenRequest

@synthesize requestCompletionBlock, operationRequest;

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
                     tokenResponseValidator:tokenResponseValidator
                                 tokenCache:tokenCache
                       accountMetadataCache:accountMetadataCache
                         extendedTokenCache:extendedTokenCache];
    if (self)
    {
        self.completionBlock = [super getCompletionBlock];
        self.xpcSingleSignOnProvider = [MSIDXpcSingleSignOnProvider new];
        self.context = parameters;
    }

    return self;
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
    [self performXpcRequest:jsonDictionary];
}

- (void)performXpcRequest:(NSDictionary *)xpcRequest
{
    // Get the bundle object for the main bundle
    NSBundle *mainBundle = [NSBundle mainBundle];

    // Retrieve the bundle identifier
    NSString *bundleIdentifier = [mainBundle bundleIdentifier];
    NSDictionary *parameters = @{@"source_application": bundleIdentifier,
                                 @"sso_request_param": xpcRequest,
                                 @"is_silent": @(YES),
                                 @"sso_request_operation": [self.operationRequest.class operation],
                                 @"sso_request_id": [[NSUUID UUID] UUIDString]};
    [self.xpcSingleSignOnProvider handleRequestParam:parameters
                                           brokerKey:self.operationRequest.brokerKey
                           assertKindOfResponseClass:MSIDBrokerOperationTokenResponse.class
                                             context:self.context
                                       continueBlock:^(id _Nullable response, NSError * _Nullable error) {
        self.completionBlock(response, error);
    }];
}

@end
