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


#if !EXCLUDE_FROM_MSALCPP
#import <Foundation/Foundation.h>
#import "MSIDDeviceTokenGrantRequest.h"
#import "MSIDAADRequestConfigurator.h"
#import "MSIDNonceTokenRequest.h"
#import "MSIDTokenResponse.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDDeviceTokenUtil.h"

@interface MSIDDeviceTokenGrantRequest()

@property (nonatomic) NSString *redirectUri;
@property (nonatomic) NSString *enrollmentId;
@property (nonatomic) MSIDWPJKeyPairWithCert *wpjInfo;
@property (nonatomic) NSString *clientId;
@property (nonatomic) NSString *resource;
@property (nonatomic) NSSet *scopesSet;
@property (nonatomic) MSIDRequestParameters *requestParameters;

@property (nonatomic) MSIDDeviceTokenResponseHandler *tokenResponseHandler;

@end

@implementation MSIDDeviceTokenGrantRequest

- (instancetype _Nullable)initWithEndpoint:(nonnull NSURL *)endpoint
                         requestParameters:(nonnull MSIDRequestParameters *)requestParameters
                                    scopes:(nullable NSString *)scopes
                   registrationInformation:(MSIDWPJKeyPairWithCert *)registrationInformation
                                  resource:(nonnull NSString *)resource
                              enrollmentId:(nullable NSString *)enrollmentId
                           extraParameters:(nullable NSDictionary *)extraParameters
                                ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                      tokenResponseHandler:(nonnull MSIDDeviceTokenResponseHandler *)tokenResponseHandler
                                     error:(NSError *__autoreleasing *__nullable)error
{
    if (!registrationInformation)
    {
        NSString *errorMessage = @"Failed to create device token request parameters: registration information is nil.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        }
        return nil;
    }
    
    if (registrationInformation.certificateData == nil || registrationInformation.privateKeyRef == nil)
    {
        NSString *errorMessage = @"Failed to create device token request parameters: registration information is missing certificate data or private key.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        }
        return nil;
    }
    
    if ([NSString msidIsStringNilOrBlank:endpoint.absoluteString])
    {
        NSString *errorMessage = @"Failed to create device token request parameters: authorityEndpoint is nil.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        }
        return nil;
    }
    
    NSString *clientId = requestParameters.clientId;
    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        NSString *errorMessage = @"Failed to create device token request parameters: clientId is nil or blank.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        }
        return nil;
    }
    
    self = [super initWithEndpoint:endpoint authScheme:requestParameters.authScheme clientId:requestParameters.clientId scope:scopes ssoContext:ssoContext context:requestParameters];
    if (self)
    {

        NSMutableDictionary *parameters = [_parameters mutableCopy];
        if (extraParameters)
        {
            [parameters addEntriesFromDictionary:extraParameters];
        }

        NSSet *scopesSet = parameters[MSID_OAUTH2_SCOPE] ? [NSSet setWithArray:[parameters[MSID_OAUTH2_SCOPE] componentsSeparatedByString:@" "]] : [NSSet set];

        NSString *redirectUri = requestParameters.redirectUri;
                
        if ([NSString msidIsStringNilOrBlank:resource])
        {
            NSString *errorMessage = @"Failed to create device token request parameters: resource is nil or blank.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            }
            return nil;
        }
        
        if ([NSString msidIsStringNilOrBlank:redirectUri])
        {
            NSString *errorMessage = @"Failed to create device token request parameters: redirectURI is nil or blank.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            }
            return nil;
        }
        
        if (!scopesSet || scopesSet.count == 0)
        {
            NSString *errorMessage = @"Failed to create device token request parameters: scope is nil or empty.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            }
            return nil;
        }
                
        if ([scopesSet containsObject:@"aza"])
        {
            NSString *errorMessage = @"Failed to create device token request parameters: scopes contains aza.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
            if (error)
            {
                *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            }
            return nil;
        }
        
        _requestParameters = requestParameters;
        _tokenResponseHandler = tokenResponseHandler;
        _wpjInfo = registrationInformation;
        _resource = resource;
        _enrollmentId = enrollmentId;
        _scopesSet = scopesSet;
        _clientId = clientId;
        _redirectUri = redirectUri;
    }
    return self;
    
}


- (void)executeRequestWithCompletion:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    if ([NSString msidIsStringNilOrBlank:self.nonce])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Failed to execute device token request: nonce is nil or blank.");
        NSError *nonceError = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to execute device token request: nonce is nil or blank.", nil, nil, nil, self.context.correlationId, nil, YES);
        completionBlock(nil, nonceError);
        return;
    }
    [self tokenRequestWithCompletionBlock:completionBlock];
}

- (void)tokenRequestWithCompletionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    NSError *jwtError;
    NSString *jwt = [MSIDDeviceTokenUtil getDeviceTokenRequestJwtForResource:self.resource
                                                                     scopes:self.scopesSet
                                                                redirectUri:self.redirectUri
                                                                   audience:self.urlRequest.URL.absoluteString
                                                                   clientId:self.clientId
                                                                      nonce:self.nonce
                                                    registrationInformation:self.wpjInfo
                                                         extraPayloadClaims:nil
                                                                    context:self.context
                                                                      error:&jwtError];

    if ([NSString msidIsStringNilOrBlank:jwt])
    {
        if (jwtError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, self.context, @"Failed to create JWT for device token request: %@", jwtError);
        }
        completionBlock(nil, jwtError);
        return;
    }

    __auto_type requestConfigurator = [MSIDAADRequestConfigurator new];
    [requestConfigurator configure:self];

    self.parameters = [MSIDDeviceTokenUtil deviceTokenRequestBodyParametersWithJwt:jwt
                                                                     enrollmentId:self.enrollmentId
                                                                  extraParameters:nil];
    __weak typeof(self) weakSelf = self;
    [self sendWithBlock:^(NSDictionary *tokenJsonResponse, NSError *tokenError)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
        {
            return;
        }
        
        if (tokenError)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.context, @"Failed to retrieve device token: %@", tokenError);
            completionBlock(nil, tokenError);
            return;
        }

        [MSIDDeviceTokenUtil handleDeviceTokenResponse:tokenJsonResponse
                                     requestParameters:strongSelf.requestParameters
                                       responseHandler:(MSIDDeviceTokenResponseHandler *)strongSelf.tokenResponseHandler
                                                 error:tokenError
                                       completionBlock:completionBlock];
    }];
}

@end
#endif
