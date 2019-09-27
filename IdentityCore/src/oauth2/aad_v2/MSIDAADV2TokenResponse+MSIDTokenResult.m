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

#import "MSIDAADV2TokenResponse+MSIDTokenResult.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "NSOrderedSet+MSIDExtensions.h"

@implementation MSIDAADV2TokenResponse (MSIDTokenResult)

+ (MSIDAADV2TokenResponse *)tokenResponseFromTokenResult:(MSIDTokenResult *)result
                                                   error:(NSError **)error
{
    // TODO: implement.
    
    MSIDAADV2TokenResponse *tokenResponse = [MSIDAADV2TokenResponse new];
    tokenResponse.accessToken = result.accessToken.accessToken;
    tokenResponse.scope = [result.accessToken.scopes msidToString];
    tokenResponse.refreshToken = result.refreshToken.refreshToken;
    tokenResponse.expiresIn = [result.accessToken.expiresOn timeIntervalSinceNow];
    tokenResponse.expiresOn = [result.accessToken.expiresOn timeIntervalSince1970];
    tokenResponse.tokenType = MSID_OAUTH2_BEARER; // TODO:?
    tokenResponse.idToken = result.rawIdToken;
    tokenResponse.clientInfo = result.account.clientInfo;
    
    return tokenResponse;
}

@end
