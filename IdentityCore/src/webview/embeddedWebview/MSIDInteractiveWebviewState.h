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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 MSIDInteractiveWebviewState maintains session state for the interactive webview controller
 during special URL processing (msauth:// and browser:// schemes).
 
 This lightweight state object tracks:
 - BRT (Broker Refresh Token) acquisition attempt and success
 - HTTP response headers for special URL processing
 
 This state is used with the simplified special URL handling approach (no state machine).
 It provides session-level tracking to ensure BRT is acquired at most once per session
 and makes headers available for URL resolution.
 */
@interface MSIDInteractiveWebviewState : NSObject

#pragma mark - BRT Tracking

/*!
 Whether BRT acquisition has been attempted in this session.
 
 BRT acquisition logic (simplified):
 - Acquired on FIRST msauth:// or browser:// redirect if needed
 - Only ONE attempt per session (no retry)
 
 Check before acquisition: !brtAcquired && !brtAttemptAttempted
 */
@property (nonatomic, assign) BOOL brtAttemptAttempted;

/*! Whether BRT was successfully acquired in this session */
@property (nonatomic, assign) BOOL brtAcquired;

#pragma mark - Response Headers

/*!
 HTTP response headers captured from the most recent navigation response.
 These headers may be needed for various flows:
 - msauth://installProfile: X-Intune-AuthToken, X-Install-Url
 - Telemetry: X-MS-Telemetry and other diagnostic headers
 - Future special URL flows that require header access
 
 Headers are stored temporarily during navigation response processing and can be
 accessed by resolvers and handlers for decision-making.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *responseHeaders;

@end

NS_ASSUME_NONNULL_END
