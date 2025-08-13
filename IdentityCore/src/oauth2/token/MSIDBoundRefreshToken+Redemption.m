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

#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshToken+Redemption.h"
#import "MSIDWorkplaceJoinUtil.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDJweCrypto.h"
#import "MSIDEcdhApv.h"
#import "MSIDJwtAlgorithm.h"
#import "MSIDJWTHelper.h"

@implementation MSIDBoundRefreshToken (Redemption)

#pragma mark - Redeem bound refresh token

- (NSString *)getTokenRedemptionJwtForTenantId:(nullable NSString *)tenantId
                     tokenRedemptionParameters:(MSIDBoundRefreshTokenRedemptionParameters *) requestParameters
                                     jweCrypto:(NSDictionary * _Nullable __autoreleasing)jweCrypto
                                       context:(id<MSIDRequestContext> _Nullable)context
                                         error:(NSError *__autoreleasing  _Nullable * _Nullable)error
{
    if (![self validateRequestParameters:requestParameters context:context error:error])
    {
        return nil;
    }
    
    MSID_LOG_WITH_CTX(MSIDLogLevelInfo, context, @"%@", [@"[Bound Refresh token redemption] Tenant ID passed in for bound RT redemption JWT:" stringByAppendingString:tenantId ?: @"nil. Primary registration will be queried."]);
    
    if (![self validateBoundDeviceId:context error:error])
    {
        return nil;
    }
    
    MSIDWPJKeyPairWithCert *workplacejoinData = [self validateAndGetWorkplaceJoinData:tenantId context:context error:error];
    if (!workplacejoinData)
    {
        return nil;
    }
    
    // TODO: Use new method to query STK private reference
    SecKeyRef publicSessionTransportKeyRef = NULL;
    NSString *apvPrefix = @"MsalClient"; // TODO: Make this a constant
    MSIDEcdhApv *ecdhPartyVInfoData = [[MSIDEcdhApv alloc] initWithKey:publicSessionTransportKeyRef
                                                             apvPrefix:apvPrefix
                                                               context:context
                                                                 error:error];
    if (!ecdhPartyVInfoData)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to create ECDH APV data for bound RT redemption JWT.");
        return nil;
    }

    MSIDJWECrypto *jweCryptoObj = [[MSIDJWECrypto alloc] initWithKeyExchangeAlg:MSID_JWT_ALG_ECDH
                                                            encryptionAlgorithm:MSID_JWT_ALG_A256GCM
                                                                            apv:ecdhPartyVInfoData
                                                                        context:context
                                                                          error:error];
    if (!jweCryptoObj)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to create JWE crypto for bound RT redemption JWT.");
        return nil;
    }
    
    jweCrypto = [jweCryptoObj.jweCryptoDictionary copy];
    
    NSMutableDictionary *jwtPayload = [requestParameters jsonDictionary];
    [jwtPayload setObject:self.refreshToken forKey:MSID_OAUTH2_REFRESH_TOKEN];
    [jwtPayload setObject:jweCrypto forKey:@"jwe_crypto"];
    
    NSArray *certificateData = @[[NSString stringWithFormat:@"%@", [[workplacejoinData certificateData] base64EncodedStringWithOptions:kNilOptions]]];
    NSDictionary *header = @{
                             @"alg" : MSID_JWT_ALG_ES256,
                             @"typ" : @"JWT",
                             @"x5c" : certificateData
                             };
                                                                                 
    NSString *signedJwt = [MSIDJWTHelper createSignedJWTforHeader:header payload:jwtPayload signingKey:workplacejoinData.privateKeyRef];
    if ([NSString msidIsStringNilOrBlank:signedJwt])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to sign JWT for bound RT redemption.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorInvalidInternalParameter
                                     description:@"Failed to sign JWT for bound RT redemption."
                                         context:context];
        return nil;
    }
    
    return signedJwt;
}

#pragma mark - Private Helper Methods
- (BOOL)validateRequestParameters:(MSIDBoundRefreshTokenRedemptionParameters *)requestParameters
                          context:(id<MSIDRequestContext>)context
                            error:(NSError *__autoreleasing * _Nullable)error
{
    if (!requestParameters)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to get signed JWT request for bound refresh token redemption. Request parameters are nil.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorInvalidInternalParameter
                                     description:@"Request parameters for bound refresh token redemption are nil."
                                         context:context];
        return NO;
    }
    return YES;
}

- (BOOL)validateBoundDeviceId:(id<MSIDRequestContext>)context
                        error:(NSError *__autoreleasing * _Nullable)error
{
    if ([NSString msidIsStringNilOrBlank:self.boundDeviceId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to get signed JWT request for bound refresh token redemption. Bound device ID is nil or blank in RT.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorInvalidInternalParameter
                                     description:@"Bound device ID for bound refresh token is nil or blank."
                                         context:context];
        return NO;
    }
    return YES;
}

- (MSIDWPJKeyPairWithCert *)validateAndGetWorkplaceJoinData:(NSString *)tenantId
                                                    context:(id<MSIDRequestContext>)context
                                                      error:(NSError *__autoreleasing * _Nullable)error
{
    MSIDWPJKeyPairWithCert *workplacejoinData = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:tenantId context:context];
    if (!workplacejoinData)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to obtain device registration details when trying to formulate bound refresh token redemption JWT.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorWorkplaceJoinRequired
                                     description:@"Failed to get registered device metadata information when formulating bound refresh token redemption JWT."
                                         context:context];
        return nil;
    }
    
    NSString *deviceId = workplacejoinData.certificateSubject;
    if ([NSString msidIsStringNilOrBlank:deviceId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Obtained device registration details, but device ID is nil or blank when formulating bound RT redemption JWT.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorWorkplaceJoinRequired
                                     description:@"Obtained device registration details, but device ID is nil or blank when formulating bound RT redemption JWT."
                                         context:context];
        return nil;
    }
    
    if (![self.boundDeviceId isEqualToString:deviceId])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Bound device ID %@ in refresh token does not match device ID %@ from WPJ registration details.", self.boundDeviceId, deviceId);
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorServerInvalidGrant
                                     description:@"Bound device ID does not match device ID from WPJ keys."
                                         context:context];
        return nil;
    }
    
    if (!workplacejoinData.privateKeyRef)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, context, @"[Bound Refresh token redemption] Failed to obtain private device key for signing bound RT redemption JWT.");
        if (error)
            *error = [self createErrorWithDomain:MSIDErrorDomain
                                            code:MSIDErrorWorkplaceJoinRequired
                                     description:@"Failed to obtain private device key for signing bound RT redemption JWT."
                                         context:context];
        return nil;
    }
    
    return workplacejoinData;
}

- (NSError *)createErrorWithDomain:(NSString *)domain
                              code:(NSInteger)code
                       description:(NSString *)description
                           context:(id<MSIDRequestContext>)context
{
    return MSIDCreateError(domain, code, description, nil, nil, nil, context.correlationId, nil, YES);
}
@end
