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

#import "MSIDDeviceTokenUtil.h"
#import "MSIDRequestParameters.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinUtilBase.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDNonceTokenRequest.h"
#import "MSIDHttpRequest.h"
#import "MSIDAADRequestConfigurator.h"
#import "MSIDAADAuthority.h"
#import "MSIDAADTenant.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAuthority.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDKeyOperationUtil.h"
#import "MSIDJWTHelper.h"
#import "MSIDDeviceTokenResponseHandler.h"
#import "MSIDOauth2Factory.h"

@interface MSIDDeviceTokenUtil ()

// Overridable seam used to look up the workplace-join registration for a tenant.
// Exposed so tests can inject a fake registration via a subclass without swizzling.
+ (nullable MSIDWPJKeyPairWithCert *)deviceRegistrationForTenantId:(nullable NSString *)tenantId
                                                          context:(nullable id<MSIDRequestContext>)context;

@end

@implementation MSIDDeviceTokenUtil

+ (nullable MSIDWPJKeyPairWithCert *)deviceRegistrationForTenantId:(nullable NSString *)tenantId
                                                          context:(nullable id<MSIDRequestContext>)context
{
    return [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:tenantId context:context];
}

+ (nullable NSURL *)getDeviceTokenEndpoint:(nonnull MSIDRequestParameters *)requestParameters
                                  tenantId:(nonnull NSString *)tenantId
{
    if (!requestParameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to construct device token endpoint: requestParameters is nil.");
        return nil;
    }
    
    NSURL *url = requestParameters.authority.url;

    if (!url)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"Failed to construct device token endpoint: authority url is nil.");
        return nil;
    }

    if ([url.pathComponents.lastObject isEqualToString:@"common"])
    {
        if ([NSString msidIsStringNilOrBlank:tenantId])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"Failed to construct device token endpoint: tenantId is nil or blank while authority is common.");
            return nil;
        }

        url = [url URLByDeletingLastPathComponent];
        url = [url URLByAppendingPathComponent:tenantId];
    }

    NSURL *endpoint = [url URLByAppendingPathComponent:@"oauth2/v2.0/token"];
    MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, requestParameters, @"Constructed device token endpoint.");
    return endpoint;
}

+ (void)getDeviceTokenRequest:(nonnull MSIDRequestParameters *)requestParameters
                     tenantId:(nonnull NSString *)tenantId
                     resource:(nonnull NSString *)resource
                 enrollmentId:(nullable NSString *)enrollmentId
              extraParameters:(nullable NSDictionary *)extraParameters
                   ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
              completionBlock:(nonnull MSIDDeviceTokenRequestCompletionBlock)completionBlock
{
    if (!requestParameters)
    {
        NSString *errorMessage = @"Failed to create device token request: requestParameters is nil.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"%@", errorMessage);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, nil, nil, YES);
        completionBlock(nil, error);
        return;
    }

    if ([NSString msidIsStringNilOrBlank:resource])
    {
        NSString *errorMessage = @"Failed to create device token request: resource is nil or blank.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"%@", errorMessage);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    NSURL *endpoint = [self getDeviceTokenEndpoint:requestParameters tenantId:tenantId];
    if (!endpoint)
    {
        NSString *errorMessage = @"Failed to create device token request: could not construct endpoint.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"%@", errorMessage);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    // The workplace-join registration is required to sign the device-token JWT.
    MSIDWPJKeyPairWithCert *wpjCerts = [self deviceRegistrationForTenantId:tenantId context:requestParameters];
    if (!wpjCerts)
    {
        NSString *errorMessage = @"Failed to create device token request: no device registration found for the requested tenant.";
        MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"%@", errorMessage);
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorWorkplaceJoinRequired, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
        completionBlock(nil, error);
        return;
    }

    // Device tokens are not tied to a user, so use the first available enrollment id (if any).
    NSString *deviceEnrollmentId = enrollmentId;
    if ([NSString msidIsStringNilOrBlank:deviceEnrollmentId])
    {
        deviceEnrollmentId = [requestParameters.authority enrollmentIdForHomeAccountId:nil
                                                                          legacyUserId:nil
                                                                               context:requestParameters
                                                                                 error:nil];
    }

    NSSet *scopesSet = nil;
    NSString *scope = requestParameters.allTokenRequestScopes;
    if (![NSString msidIsStringNilOrBlank:scope])
    {
        scopesSet = [NSSet setWithArray:[scope componentsSeparatedByString:@" "]];
    }

    // 1. Fetch a fresh nonce from the server. It is embedded into the signed JWT as request_nonce.
    MSIDRequestParameters *nonceRequestParameters = [MSIDRequestParameters new];
    nonceRequestParameters.correlationId = requestParameters.correlationId;
    nonceRequestParameters.authority = [[MSIDAADAuthority alloc] initWithURL:endpoint
                                                                   rawTenant:MSIDAADTenantTypeCommonRawValue
                                                                     context:requestParameters
                                                                       error:nil];
    // Blank account id bypasses the nonce cache and forces a fresh nonce request.
    nonceRequestParameters.accountIdentifier = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@""
                                                                                     homeAccountId:@""];

    MSIDNonceTokenRequest *nonceRequest =
        [[MSIDNonceTokenRequest alloc] initWithRequestParameters:nonceRequestParameters];
    [nonceRequest executeRequestWithCompletion:^(NSString * _Nullable resultNonce, NSError * _Nullable nonceError)
    {
        if ([NSString msidIsStringNilOrBlank:resultNonce])
        {
            NSString *errorMessage = @"Failed to retrieve nonce for device token request.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"%@ %@", errorMessage, MSID_PII_LOG_MASKABLE(nonceError));
            NSError *finalNonceError = nonceError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            completionBlock(nil, finalNonceError);
            return;
        }

        // 2. Build the signed device-token JWT using the common core workplace-join helper.
        NSError *jwtError;
        NSString *signedJwt = [self getDeviceTokenRequestJwtForResource:resource
                                                                scopes:scopesSet
                                                           redirectUri:requestParameters.redirectUri
                                                              audience:endpoint.absoluteString
                                                              clientId:requestParameters.clientId
                                                                 nonce:resultNonce
                                               registrationInformation:wpjCerts
                                                    extraPayloadClaims:nil
                                                               context:requestParameters
                                                                 error:&jwtError];
        if ([NSString msidIsStringNilOrBlank:signedJwt])
        {
            NSString *errorMessage = @"Failed to create signed JWT for device token request.";
            MSID_LOG_WITH_CTX(MSIDLogLevelError, requestParameters, @"%@ %@", errorMessage, MSID_PII_LOG_MASKABLE(jwtError));
            NSError *finalJwtError = jwtError ?: MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidInternalParameter, errorMessage, nil, nil, nil, requestParameters.correlationId, nil, YES);
            completionBlock(nil, finalJwtError);
            return;
        }

        // 3. POST the signed JWT to the token endpoint using the common core HTTP request factory.
        //    The signed JWT is attached to the request body under the 'request' key.
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest new];
        urlRequest.URL = endpoint;
        urlRequest.HTTPMethod = @"POST";

        MSIDHttpRequest *deviceTokenHttpRequest = [MSIDHttpRequest new];
        deviceTokenHttpRequest.urlRequest = urlRequest;
        deviceTokenHttpRequest.context = requestParameters;
        [[MSIDAADRequestConfigurator new] configure:deviceTokenHttpRequest];

        deviceTokenHttpRequest.parameters = [self deviceTokenRequestBodyParametersWithJwt:signedJwt
                                                                             enrollmentId:deviceEnrollmentId
                                                                          extraParameters:extraParameters];

        completionBlock(deviceTokenHttpRequest, nil);
    }];
}

+ (nonnull NSMutableDictionary *)deviceTokenRequestBodyParametersWithJwt:(nonnull NSString *)signedJwt
                                                           enrollmentId:(nullable NSString *)enrollmentId
                                                        extraParameters:(nullable NSDictionary *)extraParameters
{
    NSMutableDictionary *bodyParameters = [NSMutableDictionary new];
    if (extraParameters)
    {
        [bodyParameters addEntriesFromDictionary:extraParameters];
    }
    bodyParameters[MSID_OAUTH2_CLIENT_INFO] = @NO; // id token is not expected for a device token
    bodyParameters[MSID_OAUTH2_GRANT_TYPE] = MSID_OAUTH2_JWT_BEARER_VALUE;
    bodyParameters[@"request"] = signedJwt;
    if (![NSString msidIsStringNilOrBlank:enrollmentId])
    {
        bodyParameters[MSID_ENROLLMENT_ID] = enrollmentId;
    }
    return bodyParameters;
}

+ (nullable NSString *)getDeviceTokenRequestJwtForResource:(nonnull NSString *)resource
                                                    scopes:(NSSet *)scopes
                                               redirectUri:(nonnull NSString *)redirectUri
                                                  audience:(nonnull NSString *)audience
                                                  clientId:(nonnull NSString *)clientId
                                                     nonce:(NSString *)nonce
                                   registrationInformation:(nonnull MSIDWPJKeyPairWithCert *)registrationInformation
                                        extraPayloadClaims:(NSDictionary *)extraPayloadClaims
                                                   context:(id<MSIDRequestContext> _Nullable)context
                                                     error:(NSError * __autoreleasing *)error
{
    MSIDWPJKeyPairWithCert *workplacejoinData = registrationInformation;
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
    if (![NSString msidIsStringNilOrBlank:nonce])
    {
        [jwtPayload setObject:nonce forKey:@"request_nonce"];
    }
    NSString *scopeString = [scopes.allObjects componentsJoinedByString:@" "];
    if (![NSString msidIsStringNilOrBlank:scopeString])
    {
        [jwtPayload setObject:scopeString forKey:MSID_OAUTH2_SCOPE];
    }
    [jwtPayload setObject:resource forKey:@"resource"];
    
    NSArray *certificateData = @[[NSString stringWithFormat:@"%@", [[workplacejoinData certificateData] base64EncodedStringWithOptions:kNilOptions]]];
    MSIDJwtAlgorithm alg = [[MSIDKeyOperationUtil sharedInstance] getJwtAlgorithmForKey:registrationInformation.privateKeyRef context:context error:error];
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

+ (void)handleDeviceTokenResponse:(nullable NSDictionary *)tokenJsonResponse
                requestParameters:(nonnull MSIDRequestParameters *)requestParameters
                  responseHandler:(nullable MSIDDeviceTokenResponseHandler *)responseHandler
                            error:(nullable NSError *)error
                  completionBlock:(nonnull MSIDRequestCompletionBlock)completionBlock
{
    MSIDDeviceTokenResponseHandler *tokenResponseHandler = responseHandler ?: [[MSIDDeviceTokenResponseHandler alloc] initWithRequestParameters:requestParameters
                                                                                                                                  oauthFactory:[MSIDOauth2Factory new]];
    [tokenResponseHandler handleTokenResponse:tokenJsonResponse
                                      context:requestParameters
                                        error:error
                              completionBlock:^(MSIDTokenResult * _Nullable result, NSError * _Nullable resultError) {
        completionBlock(result, resultError);
    }];
}

@end

