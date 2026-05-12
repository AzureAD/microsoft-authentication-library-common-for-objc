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
#import "MSIDASWebAuthenticationSessionHandler.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - ASWebAuth Handoff Header Names (per specification section 5.2)

/**
 * Required header indicating the URL to be opened in ASWebAuthenticationSession.
 * Format: HTTPS URL
 */
extern NSString *const MSIDASWebAuthHandoffURLHeader;

/**
 * Optional header requesting an ephemeral (private) browser session.
 * Format: Boolean string ("true" or "false")
 * Default: "true" if not specified
 */
extern NSString *const MSIDASWebAuthHandoffUseEphemeralSessionHeader;

/**
 * Optional header to explicitly opt-in for header forwarding.
 * Format: Boolean string ("true" or "false")
 * Required to be "true" for any headers to be forwarded.
 */
extern NSString *const MSIDASWebAuthHandoffIncludeHeadersHeader;

/**
 * Optional header specifying comma-separated list of headers to forward.
 * Format: Comma-separated header names (e.g., "x-ms-token,x-correlation-id")
 * Only headers listed here will be forwarded to ASWebAuthenticationSession.
 */
extern NSString *const MSIDASWebAuthHandoffAttachHeadersHeader;

/**
 * Optional header providing correlation identifier for telemetry.
 * Format: UUID or correlation string
 */
extern NSString *const MSIDASWebAuthHandoffSessionCorrelationIdHeader;

#pragma mark - Callback URL Constants

/**
 * Callback URL scheme for Microsoft authentication flows.
 * Value: "msauth"
 */
extern NSString *const MSIDASWebAuthCallbackScheme;

/**
 * Callback host indicating MDM profile installation is complete.
 * Value: "in_app_enrollment_complete"
 * Full URL pattern: msauth://in_app_enrollment_complete
 */
extern NSString *const MSIDASWebAuthCallbackHostMDMEnrollmentComplete;

#pragma mark - Helper Functions

/**
 * Gets the expected callback URL scheme for a session purpose.
 * 
 * @param purpose The session purpose
 * @return The callback scheme (e.g., "msauth"), or nil if unknown
 */
NSString * _Nullable MSIDASWebAuthGetCallbackSchemeForPurpose(MSIDASWebAuthSessionPurpose purpose);

/**
 * Gets the expected callback URL host for a session purpose.
 * 
 * @param purpose The session purpose
 * @return The callback host (e.g., "in_app_enrollment_complete"), or nil if unknown
 */
NSString * _Nullable MSIDASWebAuthGetCallbackHostForPurpose(MSIDASWebAuthSessionPurpose purpose);

/**
 * Validates if a callback URL matches the expected purpose.
 * Checks both scheme and host against the expected pattern.
 * 
 * @param callbackURL The URL returned from ASWebAuthenticationSession
 * @param purpose The expected session purpose
 * @return YES if callback matches expected pattern, NO otherwise
 */
BOOL MSIDASWebAuthValidateCallbackForPurpose(NSURL * _Nullable callbackURL, MSIDASWebAuthSessionPurpose purpose);

NS_ASSUME_NONNULL_END
