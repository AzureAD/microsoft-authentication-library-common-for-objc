//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDAuthenticationSchemePop.h"
#import "MSIDDevicePopManager.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDHttpMethod.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDAuthScheme.h"

@interface MSIDAuthenticationSchemePop ()

@property (nonatomic) MSIDDevicePopManager *popManager;

@end

@implementation MSIDAuthenticationSchemePop

- (instancetype)initWithHttpMethod:(MSIDHttpMethod)httpMethod requestUrl:(NSURL *)requestUrl
{
    self = [super init];
    if (self)
    {
        _scheme = MSIDAuthSchemePop;
        _httpMethod = httpMethod;
        _requestUrl = requestUrl;
        _nonce = [[NSUUID UUID] UUIDString];
        _popManager = [MSIDDevicePopManager sharedInstance];
    }

    return self;
}

- (NSDictionary *)authHeaders
{
    NSMutableDictionary *headers = [NSMutableDictionary new];
    NSString *requestConf = [self.popManager getRequestConfirmation];
    if (requestConf)
    {
        [headers setObject:MSIDAuthSchemeParamFromType(self.scheme) forKey:MSID_OAUTH2_TOKEN_TYPE];
        [headers setObject:requestConf forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    }
    else
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to append public key jwk to request headers.");
    }
    
    return headers;
}

- (MSIDAccessToken *)getAccessTokenFromResponse:(MSIDTokenResponse *)response
{
    MSIDAccessTokenWithAuthScheme *accessToken = [MSIDAccessTokenWithAuthScheme new];
    accessToken.tokenType = response.tokenType;
    accessToken.kid = [self.popManager getPublicKeyJWK];
    return accessToken;
}

- (NSString *)getSecret:(MSIDAccessToken *)accessToken error:(NSError *__autoreleasing * _Nullable)error
{
    NSString *secret = [self.popManager createSignedAccessToken:accessToken.accessToken
                                                     httpMethod:MSIDHttpMethodFromType(self.httpMethod)
                                                     requestUrl:self.requestUrl.absoluteString
                                                          nonce:self.nonce
                                                          error:error];
    
    return secret;
}

- (NSString *)getAuthorizationHeader:(NSString *)accessToken
{
    return [NSString stringWithFormat:@"%@ %@", MSIDAuthSchemeParamFromType(self.scheme), accessToken];
}

- (NSString *)authenticationScheme
{
    return MSIDAuthSchemeParamFromType(self.scheme);
}

- (MSIDCredentialType)credentialType
{
    return MSIDAccessTokenWithAuthSchemeType;
}

- (NSString *)tokenType
{
    return MSIDAuthSchemeParamFromType(self.scheme);
}

@end
