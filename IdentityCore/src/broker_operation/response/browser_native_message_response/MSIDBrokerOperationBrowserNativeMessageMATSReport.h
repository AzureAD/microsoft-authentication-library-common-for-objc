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
 * MATS Silent Status Enum
 *
 * Represents the outcome of a silent token request attempt.
 * Based on WebTokenRequestStatus values used in Windows WAM.
 */
typedef NS_ENUM(NSInteger, MSIDMATSSilentStatus) {
    /**
     * Silent token obtained successfully
     */
    MSIDMATSSilentStatusSuccess = 0,
    
    /**
     * User cancelled the silent token request
     */
    MSIDMATSSilentStatusUserCancel = 1,
    
    /**
     * Silent attempt concluded that user interaction is required
     */
    MSIDMATSSilentStatusUserInteractionRequired = 3,
    
    /**
     * Silent attempt hit a provider error (e.g., refresh token expired)
     */
    MSIDMATSSilentStatusProviderError = 5
};

typedef NSString *MSIDMATSDeviceJoinStatus NS_TYPED_ENUM;
extern MSIDMATSDeviceJoinStatus const MSIDMATSDeviceJoinStatusNotJoined;
extern MSIDMATSDeviceJoinStatus const MSIDMATSDeviceJoinStatusAADJ; 

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
 * A boolean flag where YES (1) means the broker returned a cached token without a network call,
 * and NO (0) means a network request was made to acquire a new token. This helps measure
 * how often silent SSO worked via cache vs network.
 *
 * Example: YES (token was served from cache), NO (fresh call required)
 */
@property (nonatomic) BOOL isCached;

/**
 * Version of the broker handling the request.
 *
 * Example:  "3.9.0"
 */
@property (nonatomic, nullable) NSString *brokerVersion;

/**
 * Account state at start.
 */
@property (nonatomic, nullable) NSString *accountJoinOnStart;

/**
 * Account state at end.
 *
 */
@property (nonatomic, nullable) NSString *accountJoinOnEnd;

/**
 * Device's AAD join status.
 *
 * Indicates the device's registration state in Entra ID (Azure AD). Possible values:
 * - MSIDMATSDeviceJoinStatusAADJ (@"aadj") - Device is Azure AD joined (managed by org)
 * - MSIDMATSDeviceJoinStatusNotJoined (@"not_joined") - Device is not joined to AAD
 * This field helps identify if device is corporate-managed or personal.
 *
 * Example: MSIDMATSDeviceJoinStatusAADJ (managed device), MSIDMATSDeviceJoinStatusNotJoined (personal device)
 */
@property (nonatomic, nullable) MSIDMATSDeviceJoinStatus deviceJoin;

/**
 * Type of prompt that occurred.
 *
 * Reflects the UI interaction required. Values borrowed from MSAL's prompt parameters:
 * - "none" - No prompt was needed (silent token acquired)
 * - "login" - User was prompted to sign in (enter credentials)
 * - "consent" - User was prompted for consent
 * - "select_account" - User was prompted to select account
 *
 * Example: @"none" (silent SSO), @"login" (credentials required)
 */
@property (nonatomic, nullable) NSString *promptBehavior;

/**
 * Broker/IDP error code.
 *
 * A numeric code representing the error if the token request failed. 0 if the operation
 * succeeded or no specific error.
 *
 * Example: 0 (no error, success), -50005 (MSALErrorUserCanceled)
 */
@property (nonatomic) NSInteger apiErrorCode;

/**
 * Was UI shown?
 *
 * Boolean flag: YES if the broker showed any UI to the user. NO if the entire flow was silent/invisible.
 * This directly indicates if the user was interrupted with a prompt.
 *
 * Example: YES (user saw sign-in window), NO (completely silent SSO).
 */
@property (nonatomic) BOOL uiVisible;

/**
 * Silent attempt error code.
 *
 * If the broker attempted to get a token silently (using cached credentials or refresh
 * token) and that attempt failed, this is the error code from the silent try. 0 if
 * silent succeeded or no error was encountered silently.
 *
 * Example: 0 (silent succeeded or not attempted), -50002 (MSALErrorInteractionRequired)
 */
@property (nonatomic) NSInteger silentCode;

/**
 * Transient error code, not used on Mac.
 */
@property (nonatomic) NSInteger silentBiSubCode;

/**
 * Silent attempt error message.
 *
 * A short text description of why the silent attempt failed, if an error occurred.
 * Including this helps debugging exact silent failure reasons.
 *
 * Example: @"" (silent succeeded), @"The web page and the redirect uri must be on the same origin."
 */
@property (nonatomic, nullable) NSString *silentMessage;

/**
 * Outcome of silent request (status code).
 *
 * Corresponds to the broker's internal status enum for a silent token attempt.
 * Values based on WebTokenRequestStatus:
 * - MSIDMATSSilentStatusSuccess (0) - Silent token obtained successfully
 * - MSIDMATSSilentStatusUserCancel (1) - User cancelled the silent token request
 * - MSIDMATSSilentStatusUserInteractionRequired (3) - Silent attempt concluded that user interaction is required
 * - MSIDMATSSilentStatusProviderError (5) - Silent attempt hit a provider error
 *
 * Example: MSIDMATSSilentStatusSuccess (silent success), MSIDMATSSilentStatusUserInteractionRequired (interaction required)
 */
@property (nonatomic) MSIDMATSSilentStatus silentStatus;

/**
 * HTTP response code from token endpoint.
 *
 * If the broker made a network request to AAD (for token, device code, etc.), this
 * captures the HTTP status code. 200 for success, 4xx/5xx for various errors.
 * Will be 0 if no network call occurred (e.g., fully cached token).
 *
 * Example: 200 (token obtained successfully), 400 (bad request), 500 (server error)
 */
@property (nonatomic) NSInteger httpStatus;

/**
 * Number of HTTP calls made.
 *
 * Counts how many web requests were performed during the token acquisition.
 * 0 means no network call (pure cache usage), 1 means one token request to AAD,
 * 2 might indicate a retry or an extra OIDC metadata call, etc.
 *
 * Example: 0 (cache hit), 1 (typical token acquisition), 2 (token + metadata call)
 */
@property (nonatomic) NSInteger httpEventCount;

/**
 * JSON string representation of the report.
 *
 * Converts the MATS report into a JSON string format for easy logging or transmission.
 *
 * @return A JSON string representing the MATS report, or nil if serialization fails.
 */
- (NSString *)jsonString;

@end

NS_ASSUME_NONNULL_END
