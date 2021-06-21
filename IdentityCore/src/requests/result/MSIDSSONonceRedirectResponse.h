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
#import "MSIDTokenResult.h"
NS_ASSUME_NONNULL_BEGIN
@interface MSIDSSONonceRedirectResponse : MSIDTokenResult

@property (nonatomic, nonnull, readonly) NSString *ssoNonce;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithNonce:(NSString *)nonce;
- (nullable instancetype)initWithAccessToken:(nonnull MSIDAccessToken *)accessToken
                                refreshToken:(nullable id<MSIDRefreshableToken>)refreshToken
                                     idToken:(nonnull NSString *)rawIdToken
                                     account:(nonnull MSIDAccount *)account
                                   authority:(nonnull MSIDAuthority *)authority
                               correlationId:(nonnull NSUUID *)correlationId
                               tokenResponse:(nullable MSIDTokenResponse *)tokenResponse NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
