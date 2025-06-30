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
#import "MSIDJsonSerializable.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Microsoft Authentication Telemetry System (MATS) Report
 *
 * This class represents detailed telemetry information about the token acquisition process
 * that the native broker returns to MSAL.js. MSAL.js will record these fields in its
 * telemetry if the broker provides them. This telemetry helps correlate broker operations
 * (like cache hits, device state, or errors) with MSAL.js events.
 */
@interface MSIDBrokerOperationBrowserNativeMessageMATSReport : NSObject <MSIDJsonSerializable>

/**
 * Indicates if the token came from cache.
 *
 * A boolean flag where YES means the broker returned a cached token without a network call,
 * and NO means a network request was made.
 *
 * Example: YES (token was found in cache), NO (network request required)
 */
@property (nonatomic) BOOL isCached;

/**
 * Version of the broker handling the request.
 *
 * Typically a string of the broker app or library version. This helps identify which
 * broker implementation produced the telemetry.
 *
 * Example: @"3.2.7" (broker version 3.2.7)
 */
@property (nonatomic, nullable) NSString *brokerVersion;

/**
 * Device/account join state at start.
 *
 * Indicates the device's join status (or the account's join status to the device) before
 * the token request. Common values might be: "Azure AD Joined", "Azure AD Registered",
 * "Domain Joined", or "None" if the device wasn't workplace joined at start.
 * On macOS/iOS, "Azure AD Registered" typically means the device or account had a
 * work/school account registered via Company Portal.
 *
 * Example: @"None" (no AAD join at start)
 */
@property (nonatomic, nullable) NSString *accountJoinOnStart;

/**
 * Device/account join state at end.
 *
 * The join status after the token request completes. This could change during an
 * interactive login if the user registered the device. For example, it might switch
 * from "None" to "Azure AD Registered" if the login process involved device registration.
 *
 * Example: @"Azure AD Registered" (device joined during login)
 */
@property (nonatomic, nullable) NSString *accountJoinOnEnd;

/**
 * Overall device join type.
 *
 * This describes the device's management state. Possible strings include
 * "Azure AD Joined" (AADJ), "Azure AD Registered" (workplace joined),
 * "Hybrid AD Joined", or "Not Joined". On Apple devices, this is usually
 * "Azure AD Registered" if any work account is added, otherwise "Not Joined".
 *
 * Example: @"Azure AD Registered" (device has work account registered)
 */
@property (nonatomic, nullable) NSString *deviceJoin;

/**
 * Prompt behavior used.
 *
 * Describes how the broker decided to prompt the user. For example, "auto" if the
 * broker tried silent first and only prompted if needed, "always" or "force_login"
 * if it forced an interactive prompt. This typically mirrors the MSAL Prompt parameter.
 *
 * Example: @"auto" (prompt only if necessary)
 */
@property (nonatomic, nullable) NSString *promptBehavior;

/**
 * Broker API error code.
 *
 * If an error occurred in the broker, this numeric code identifies it. A value of 0
 * means no error at the API layer. Non-zero values correspond to specific failure
 * reasons (e.g., a COM error code or internal broker error).
 *
 * Example: 0 (no broker-level error) or 3400017 (example error code)
 */
@property (nonatomic) NSInteger apiErrorCode;

/**
 * Whether any UI was shown.
 *
 * Boolean flag: YES if the broker displayed an interactive UI (such as a sign-in
 * webview or account picker), NO if the operation was completely silent.
 *
 * Example: NO (no UI needed because token was in cache)
 */
@property (nonatomic) BOOL uiVisible;

/**
 * Silent attempt result code.
 *
 * If the broker attempted a silent token request first (using cached refresh token
 * or SSO), this is the result code of that attempt. 0 typically means silent succeeded.
 * Non-zero means silent failed and an interactive step was needed. This might map to
 * an AAD or broker error code; e.g., code for "interaction required".
 *
 * Example: 0 (silent succeeded) or 65001 (InteractionRequired error code)
 */
@property (nonatomic) NSInteger silentCode;

/**
 * Silent attempt sub-code.
 *
 * Additional info about the silent failure, if any. "BI" could stand for
 * Broker/Identity substatus. This might be an internal sub-error or detailed status
 * from the token service. It's an integer providing granular error detail beyond silentCode.
 *
 * Example: 0 (no sub-error) or 1001 (example sub-code)
 */
@property (nonatomic) NSInteger silentBiSubCode;

/**
 * Silent attempt message.
 *
 * A textual message or description corresponding to the silent attempt result.
 * Often this is the error description if silentCode is non-zero.
 *
 * Example: @"User interaction required for consent"
 */
@property (nonatomic, nullable) NSString *silentMessage;

/**
 * Silent attempt status.
 *
 * A numeric status indicator for the silent flow. This can overlap with silentCode
 * but usually represents a category (e.g., 0 for success, 1 for failure, 2 for
 * interaction required). It may map to internal status enums (for example,
 * 0 = SUCCESS, 1 = FAILURE_NEED_UI).
 *
 * Example: 1 (silent token failed, needs UI)
 */
@property (nonatomic) NSInteger silentStatus;

/**
 * HTTP status code from token endpoint.
 *
 * If a network request was made to Azure AD (STS), this captures the HTTP response code.
 * 200 indicates success. In error cases, you might see 400 (bad request, e.g. token
 * refresh error) or other 4xx/5xx codes from the server. If no network call happened
 * (cache hit), this may be 0.
 *
 * Example: 200 (OK success from STS) or 400 (bad request error)
 */
@property (nonatomic) NSInteger httpStatus;

/**
 * Number of HTTP calls made.
 *
 * How many HTTP network requests the broker made to AAD during the operation.
 * For a cache-only scenario this is 0. A silent refresh token attempt would typically
 * be 1. An interactive flow might involve 1 (token endpoint) or 2 calls (e.g., token
 * endpoint and maybe device registration or discovery). This helps assess if multiple
 * round-trips occurred.
 *
 * Example: 1 (one network request made to token endpoint)
 */
@property (nonatomic) NSInteger httpEventCount;

@end

NS_ASSUME_NONNULL_END
