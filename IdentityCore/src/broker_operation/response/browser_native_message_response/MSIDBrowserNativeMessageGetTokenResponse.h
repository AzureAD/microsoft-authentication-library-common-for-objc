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


#import "MSIDBrokerNativeAppOperationResponse.h"

@class MSIDBrokerOperationBrowserNativeMessageMATSReport;
@class MSIDBrokerOperationTokenResponse;
@class MSIDTokenResult;

NS_ASSUME_NONNULL_BEGIN

@interface MSIDBrowserNativeMessageGetTokenResponse : MSIDBrokerNativeAppOperationResponse

- (instancetype)initWithDeviceInfo:(nullable MSIDDeviceInfo *)deviceInfo NS_UNAVAILABLE;

/// Compatibility initializer for callers that still shape the response from the broker operation response.
- (instancetype _Nullable)initWithTokenResponse:(nonnull MSIDBrokerOperationTokenResponse *)tokenResponse NS_DESIGNATED_INITIALIZER;

/// Shapes a browser-native-message GetToken response from the canonical token result. Works for both
/// a freshly redeemed result (its `tokenResponse` is present, so base fields come from the server
/// response) and an access-token cache hit (no `tokenResponse`, base fields derived from
/// `accessToken`). Returns nil when the result has neither an access token nor a token response.
/// Also carries the browser-native-message `state` echo and the fallback account UPN so a caller does
/// not have to set those properties individually after construction. Keeps response parsing/shaping
/// owned by this response class, depending on a single response type (`MSIDTokenResult`).
- (instancetype _Nullable)initWithTokenResult:(nonnull MSIDTokenResult *)result
                                        state:(nullable NSString *)state
                    fallbackRequestAccountUpn:(nullable NSString *)fallbackRequestAccountUpn NS_DESIGNATED_INITIALIZER;

@property (nonatomic, nullable) NSString *state;
@property (nonatomic, nullable) NSString *requestAccountUpn;
@property (nonatomic, nullable) MSIDBrokerOperationBrowserNativeMessageMATSReport *matsReport;


@end

NS_ASSUME_NONNULL_END
