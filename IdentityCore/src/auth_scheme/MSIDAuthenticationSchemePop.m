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

@interface MSIDAuthenticationSchemePop ()

@property MSIDDevicePopManager *popManager;

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

- (NSDictionary *)getAuthHeaders
{
    NSMutableDictionary *headers = [NSMutableDictionary new];
    [headers setObject:@"Pop" forKey:MSID_OAUTH2_TOKEN_TYPE];
    NSString *requestConf = [self.popManager getRequestConfirmation:nil];
    if (requestConf)
    {
        [headers setObject:requestConf forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    }
    
    return headers;
}

- (MSIDAccessToken *)getAccessToken
{
    MSIDAccessTokenWithAuthScheme *accessToken = [[MSIDAccessTokenWithAuthScheme alloc] initWithAuthScheme:self];
    accessToken.kid = [self.popManager getPublicKeyJWK];
    return accessToken;
}

- (NSString *)getRawAccessToken:(MSIDAccessToken *)accessToken
{
    return [self.popManager createSignedAccessToken:accessToken.accessToken
                                         httpMethod:MSIDHttpMethodFromType(self.httpMethod)
                                         requestUrl:self.requestUrl.absoluteString
                                              nonce:self.nonce
                                              error:nil];
}

@end
