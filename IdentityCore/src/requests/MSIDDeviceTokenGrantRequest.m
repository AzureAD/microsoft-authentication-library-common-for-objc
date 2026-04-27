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


#import <Foundation/Foundation.h>
#import "MSIDDeviceTokenGrantRequest.h"
#import "MSIDAADRequestConfigurator.h"
#import "MSIDKeyOperationUtil.h"
#import "MSIDJWTHelper.h"
#import "MSIDNonceTokenRequest.h"
#import "MSIDTokenResponse.h"
#import "MSIDRequestParameters.h"
#import "MSIDAADAuthority.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADTokenResponseSerializer.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDTokenResponseValidator.h"

@interface MSIDDeviceTokenGrantRequest()

@property (nonatomic) NSString *redirectUri;
@property (nonatomic) NSString *nonce;
@property (nonatomic) NSString *enrollmentId;
@property (nonatomic) MSIDWPJKeyPairWithCert *wpjInfo;
@property (nonatomic) NSString *clientId;
@property (nonatomic) NSString *resource;
@property (nonatomic) NSSet *scopesSet;
@property (nonatomic) MSIDRequestParameters *requestParameters;

@property (nonatomic) MSIDTokenResponseHandler *tokenResponseHandler;

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
        return nil;
    }
    
    self = [super initWithEndpoint:endpoint authScheme:requestParameters.authScheme clientId:requestParameters.clientId scope:scopes ssoContext:ssoContext context:requestParameters];
    if (self)
    {

        NSMutableDictionary *parameters = [_parameters mutableCopy];
        [parameters addEntriesFromDictionary:extraParameters];

        NSSet *scopesSet = parameters[MSID_OAUTH2_SCOPE] ? [NSSet setWithArray:[parameters[MSID_OAUTH2_SCOPE] componentsSeparatedByString:@" "]] : [NSSet set];
        
        NSString *clientId = requestParameters.clientId;
        NSString *redirectUri = requestParameters.redirectUri;
        
        if ([NSString msidIsStringNilOrBlank:clientId])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: clientId is nil or blank.");
            return nil;
        }
        
        if ([NSString msidIsStringNilOrBlank:resource])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: resource is nil or blank.");
            return nil;
        }
        
        if ([NSString msidIsStringNilOrBlank:redirectUri])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: redirectURI is nil or blank.");
            return nil;
        }
        
        if ([NSString msidIsStringNilOrBlank:endpoint.absoluteString])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: authorityEndpoint is nil.");
            return nil;
        }
        
        if (!scopesSet || scopesSet.count == 0)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: scope is nil or empty.");
            return nil;
        }
                
        if ([scopesSet containsObject:@"aza"])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create device token request parameters: scopes contains aza.");
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
    MSIDRequestParameters *nonceReqParams = [MSIDRequestParameters new];
    nonceReqParams.correlationId = self.context.correlationId;
    nonceReqParams.authority = [[MSIDAADAuthority alloc] initWithURL:self.urlRequest.URL rawTenant:MSIDAADTenantTypeCommonRawValue context:self.context error:nil];
    // Passing blank accountId details as device token is not associated with a specific account. This is required to bypass cache look up in nonce request and directly request new nonce from server.
    nonceReqParams.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"" homeAccountId:@""];
    MSIDNonceTokenRequest *nonceRequest = [[MSIDNonceTokenRequest alloc] initWithRequestParameters:nonceReqParams];
    __weak typeof(self) weakSelf = self;
    [nonceRequest executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable error)
    {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
        {
            return;
        }
        if (!resultNonce || error)
        {
            NSError *nonceError = error ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to retrieve nonce for device token request: nonce is nil.", nil, nil, nil, strongSelf.context.correlationId, nil, YES);
            MSID_LOG_WITH_CTX(MSIDLogLevelError, strongSelf.context, @"Failed to retrieve nonce for device token request: %@", nonceError);
            completionBlock(nil, nonceError);
            return;
        }
        strongSelf.nonce = resultNonce;
        [strongSelf tokenRequestWithCompletionBlock:completionBlock];
    }];
}

- (void)tokenRequestWithCompletionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    NSError *jwtError;
    NSString *jwt = [self getTokenRedemptionJwtForResource:self.resource
                                                  scopes:self.scopesSet
                                              redirectUri:self.redirectUri
                                                 audience:self.urlRequest.URL.absoluteString
                                                 clientId:self.clientId
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

    NSMutableDictionary *requestParameters = [NSMutableDictionary new];
    requestParameters[MSID_OAUTH2_CLIENT_INFO] = @NO;  // Set client_info = 0 to explicitly set that id token is not expected.

    if (self.enrollmentId)
    {
        requestParameters[MSID_ENROLLMENT_ID] = self.enrollmentId;
    }
    requestParameters[MSID_OAUTH2_GRANT_TYPE] = @"urn:ietf:params:oauth:grant-type:jwt-bearer";
    requestParameters[@"request"] = jwt;

    self.parameters = requestParameters;
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
        MSIDDeviceTokenResponseHandler *tokenResponseHandler = (MSIDDeviceTokenResponseHandler *)strongSelf.tokenResponseHandler;
        [tokenResponseHandler handleTokenResponse:tokenJsonResponse
                                          context:strongSelf.requestParameters
                                            error:nil
                                  completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable error) {
            completionBlock(result, error);
        }];
    }];
}

#pragma mark standard payload

- (NSString *)getTokenRedemptionJwtForResource:(nonnull NSString *)resource
                                        scopes:(NSSet *)scopes
                                   redirectUri:(nonnull NSString *)redirectUri
                                      audience:(nonnull NSString *)audience
                                      clientId:(nonnull NSString *)clientId
                            extraPayloadClaims:(NSDictionary *)extraPayloadClaims
                                       context:(id<MSIDRequestContext> _Nullable)context
                                         error:(NSError * __autoreleasing *)error
{
    MSIDWPJKeyPairWithCert *workplacejoinData = self.wpjInfo;
    NSMutableDictionary *jwtPayload = [NSMutableDictionary new];
    for (NSString *key in extraPayloadClaims)
    {
        jwtPayload[key] = extraPayloadClaims[key];
    }
    jwtPayload[MSID_OAUTH2_GRANT_TYPE] = MSID_OAUTH2_DEVICE_TOKEN;
    jwtPayload[@"aud"] = audience;
    jwtPayload[@"iss"] = clientId; // Issuer is the client ID
    jwtPayload[MSID_OAUTH2_REDIRECT_URI] = redirectUri;
    [jwtPayload setObject:clientId forKey:MSID_OAUTH2_CLIENT_ID];
    if (![NSString msidIsStringNilOrBlank:self.nonce])
    {
        [jwtPayload setObject:self.nonce forKey:@"request_nonce"];
    }
    NSString *scopeString = [scopes.allObjects componentsJoinedByString:@" "];
    if (![NSString msidIsStringNilOrBlank:scopeString])
    {
        [jwtPayload setObject:scopeString forKey:MSID_OAUTH2_SCOPE];
    }
    [jwtPayload setObject:resource forKey:@"resource"];
    
    NSArray *certificateData = @[[NSString stringWithFormat:@"%@", [[workplacejoinData certificateData] base64EncodedStringWithOptions:kNilOptions]]];
    MSIDJwtAlgorithm alg = [[MSIDKeyOperationUtil sharedInstance] getJwtAlgorithmForKey:self.wpjInfo.privateKeyRef context:context error:error];
    if (!alg)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Device token] Failed to get JWT algorithm for signing key.");
        return nil;
    }
    
    NSDictionary *header = @{
                             @"alg" : alg,
                             @"typ" : @"JWT",
                             @"x5c" : certificateData
                             };
                                                                                 
    NSString *signedJwt = [MSIDJWTHelper createSignedJWTforHeader:header payload:jwtPayload signingKey:workplacejoinData.privateKeyRef];
    if ([NSString msidIsStringNilOrBlank:signedJwt])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Device token] Failed to sign JWT for requesting device token.");
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, @"Failed to sign JWT for requesting device token.", nil, nil, nil, context.correlationId, nil, YES);
        }
        return nil;
    }
    
    return signedJwt;
}



@end
