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

#import "MSIDAADV1RefreshTokenGrantRequest.h"
#import "MSIDBoundRefreshToken.h"
#import "MSIDWPJKeyPairWithCert.h"
#import "MSIDJWECrypto.h"

NS_ASSUME_NONNULL_BEGIN
@interface MSIDBoundRefreshTokenGrantRequest : MSIDAADRefreshTokenGrantRequest

@property (nonatomic, readonly) MSIDJWECrypto *jweCrypto;
@property (nonatomic, readonly) MSIDWPJKeyPairWithCert *wpjInfo;


/// Initializer for a BART redemption grant request.
/// - Parameters:
///   - endpoint: The endpoint URL to which the request will be sent. Typically /token endpoint
///   - authScheme: The authScheme
///   - clientId: Application ID of the client app
///   - scope: Scopes for which BART should be used to obtain access tokens.
///   - boundRefreshToken: Bound App Refresh Token
///   - redirectUri: Redirect URI of the client app
///   - enrollmentId: Microsoft intune enrollment ID
///   - claims: claims request for tokens in response
///   - extraParameters: Extra params added to request's form
///   - ssoContext: SSO Context
///   - context: Context for the request
///   - error: Error out parameter
- (instancetype _Nullable )initWithEndpoint:(nonnull NSURL *)endpoint
                                 authScheme:(nonnull MSIDAuthenticationScheme *)authScheme
                                   clientId:(nonnull NSString *)clientId
                                      scope:(nullable NSString *)scope
                          boundrefreshToken:(nonnull MSIDBoundRefreshToken *)boundRefreshToken
                                redirectUri:(nonnull NSString *)redirectUri
                               enrollmentId:(nullable NSString *)enrollmentId
                                     claims:(nullable NSString *)claims
                            extraParameters:(nullable NSDictionary *)extraParameters
                                 ssoContext:(nullable MSIDExternalSSOContext *)ssoContext
                                    context:(nullable id<MSIDRequestContext>)context
                                      error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/// Adds the decryption preprocessor to the response serializer using the provided decryption key.
- (void)configureDecryptionPreProcessorUsingKey;
@end
#endif
NS_ASSUME_NONNULL_END
