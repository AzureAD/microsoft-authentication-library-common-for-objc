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

#import "MSIDAADV1TokenRequestFactory.h"
#import "MSIDClientCapabilitiesUtil.h"
#import "MSIDAADV1AuthorizationCodeRequest.h"
#import "MSIDRequestParameters.h"

@implementation MSIDAADV1TokenRequestFactory

- (MSIDAuthorizationCodeGrantRequest *)authorizationGrantRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                                         codeVerifier:(NSString *)pkceCodeVerifier
                                                                             authCode:(NSString *)authCode
{
    return nil; // TODO: implement me
}

- (MSIDRefreshTokenGrantRequest *)refreshTokenRequestWithRequestParameters:(MSIDRequestParameters *)parameters
                                                              refreshToken:(NSString *)refreshToken
{
    return nil; // TODO: implement me
}

- (MSIDWebviewConfiguration *)webViewConfigurationWithRequestParameters:(MSIDInteractiveRequestParameters *)parameters
{
    return nil; // TODO: implement me
}

@end
