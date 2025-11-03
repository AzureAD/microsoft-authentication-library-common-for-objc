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

#import "MSIDBoundRefreshTokenGrantRequest.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDBoundRefreshToken+Redemption.h"
#import "MSIDAADV1RefreshTokenGrantRequest.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDJweResponseDecryptPreProcessor.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDJwtAlgorithm.h"
#import "MSIDHttpResponseSerializer.h"
#import "MSIDWorkplaceJoinUtil.h"
#import "MSIDJsonResponsePreprocessor.h"
#import "MSIDAADRequestConfigurator.h"
#import "MSIDBrokerConstants.h"

@implementation MSIDBoundRefreshTokenGrantRequest

- (instancetype _Nullable)initWithEndpoint:(nonnull NSURL *)endpoint
                                authScheme:(nonnull MSIDAuthenticationScheme *)authScheme
                                  clientId:(nonnull NSString *)clientId
                                     scope:(nullable NSString *)scope
                         boundrefreshToken:(nonnull MSIDBoundRefreshToken *)boundRefreshToken
                               redirectUri:(nonnull NSString *)redirectUri
                                  resource:(nonnull NSString *)resource
                              enrollmentId:(nullable NSString *)enrollmentId
                                    claims:(nullable NSString *)claims
                           extraParameters:(nullable NSDictionary *)extraParameters
                                ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                                   context:(nullable id<MSIDRequestContext>)context
{
    if (!boundRefreshToken)
    {
        return nil;
    }
    self = [super initWithEndpoint:endpoint
                        authScheme:authScheme
                          clientId:clientId
                             scope:scope
                      refreshToken:boundRefreshToken.refreshToken
                       redirectUri:redirectUri
                   extraParameters:extraParameters
                        ssoContext:ssoContext
                           context:context];
    if (self)
    {
        NSParameterAssert(resource);
        
        NSMutableDictionary *parameters = [_parameters mutableCopy];
        [parameters addEntriesFromDictionary:extraParameters];

        NSSet *scopes = parameters[MSID_OAUTH2_SCOPE] ? [NSSet setWithArray:[parameters[MSID_OAUTH2_SCOPE] componentsSeparatedByString:@" "]] : [NSSet set];
        
        MSIDWPJKeyPairWithCert *workplacejoinData = [MSIDWorkPlaceJoinUtil getWPJKeysWithTenantId:boundRefreshToken.accountIdentifier.utid context:context];
        MSIDBoundRefreshTokenRedemptionParameters *params = [[MSIDBoundRefreshTokenRedemptionParameters alloc]
                                                             initWithClientId:clientId
                                                            authorityEndpoint:endpoint
                                                                       scopes:scopes
                                                                        nonce:@""
                                                             extraPayloadClaims:extraParameters
                                                             workplaceJoinInfo:workplacejoinData];
        NSError *jwtCreationError;
        MSIDJWECrypto *jweCrypto;
        NSString *jwt = [boundRefreshToken getTokenRedemptionJwtForTenantId:boundRefreshToken.accountIdentifier.utid
                                                  tokenRedemptionParameters:params
                                                                    context:context
                                                                  jweCrypto:&jweCrypto
                                                                      error:&jwtCreationError];

        if ([NSString msidIsStringNilOrBlank:jwt])
        {
            return nil;
        }
        _jweCrypto = jweCrypto;
        
        __auto_type requestConfigurator = [MSIDAADRequestConfigurator new];
        [requestConfigurator configure:self];
        
        NSMutableDictionary *requestParameters = [NSMutableDictionary new];
        requestParameters[MSID_OAUTH2_CLIENT_INFO] = @YES;
        requestParameters[MSID_OAUTH2_CLAIMS] = claims;
        requestParameters[MSID_ENROLLMENT_ID] = enrollmentId;
        requestParameters[MSID_OAUTH2_GRANT_TYPE] = @"urn:ietf:params:oauth:grant-type:jwt-bearer";
        requestParameters[@"request"] = jwt;
        
        _parameters = requestParameters;
        _wpjInfo = workplacejoinData;
    }
    
    return self;
}

- (void)configureDecryptionPreProcessorUsingKey
{
    MSIDHttpResponseSerializer *serializer = self.responseSerializer;
    if (serializer)
    {
        MSIDJsonResponsePreprocessor *preprocessor = serializer.preprocessor;
        preprocessor.jweDecryptPreProcessor =
        [[MSIDJweResponseDecryptPreProcessor alloc] initWithDecryptionKey:self.wpjInfo.privateTransportKeyRef
                                                                jweCrypto:self.jweCrypto
                                                 additionalResponseClaims:@{
            MSID_BART_DEVICE_ID_KEY : self.wpjInfo.certificateSubject
                                                                            }
        ];
        serializer.preprocessor = preprocessor;
        self.responseSerializer = serializer;
    }
}

@end
