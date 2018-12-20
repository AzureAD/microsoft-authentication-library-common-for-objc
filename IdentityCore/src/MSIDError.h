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

extern NSString *MSIDErrorDescriptionKey;
extern NSString *MSIDOAuthErrorKey;
extern NSString *MSIDOAuthSubErrorKey;
extern NSString *MSIDCorrelationIdKey;
extern NSString *MSIDHTTPHeadersKey;
extern NSString *MSIDHTTPResponseCodeKey;
extern NSString *MSIDUserDisplayableIdKey;

/*!
 ADAL and MSID use different error domains and error codes.
 When extracting shared code to common core, we unify those error domains
 and error codes to be MSID error domains/codes and list them below. Besides,
 domain mapping and error code mapping should be added to ADAuthenticationErrorConverter
 and MSIDErrorConveter in corresponding project.
 */
extern NSString *MSIDErrorDomain;
extern NSString *MSIDOAuthErrorDomain;
extern NSString *MSIDKeychainErrorDomain;
extern NSString *MSIDHttpErrorCodeDomain;

typedef NS_ENUM(NSInteger, MSIDErrorCode)
{
    /*!
     ====================================================
     General Errors (510xx, 511xx) - MSIDErrorDomain
     ====================================================
     */
    // General internal errors that do not fall into one of the specific type
    // of an error described below.
    MSIDErrorInternal = -51100,
    
    // Parameter errors
    MSIDErrorInvalidInternalParameter   = -51111,
    MSIDErrorInvalidDeveloperParameter  = -51112,
   
    // Unsupported functionality
    MSIDErrorUnsupportedFunctionality   = -51199,

    /*!
    =========================================================
     Cache Errors   (512xx) - MSIDErrorDomain
    =========================================================
     */

    // Multiple users found in cache when one was intended
    MSIDErrorCacheMultipleUsers     = -51201,
    MSIDErrorCacheBadFormat         = -51302,
    
    /*!
     =========================================================
     Server errors  (514xx) - MSIDOAuthErrorDomain
     =========================================================
     */
    // Interaction Required
    MSIDErrorInteractionRequired        = -51411,
    
    // Server returned a response indicating an OAuth error
    MSIDErrorServerOauth                = -51421,
    // Server returned an invalid response
    MSIDErrorServerInvalidResponse      = -51422,
    // Server returned a refresh token reject response
    MSIDErrorServerRefreshTokenRejected = -51423,
    // Other specific server response errors
    
    MSIDErrorServerInvalidRequest       = -51431,
    MSIDErrorServerInvalidClient        = -51432,
    MSIDErrorServerInvalidGrant         = -51433,
    MSIDErrorServerInvalidScope         = -51434,
    MSIDErrorServerUnauthorizedClient   = -51435,
    MSIDErrorServerUnhandledResponse    = -51436,
    
    // State verification has failed
    MSIDErrorServerInvalidState         = -51441,
    
    // Redirect to non HTTPS detected
    MSIDErrorServerNonHttpsRedirect     = -51451,

    // Intune Protection Policies Required
    MSIDErrorServerProtectionPoliciesRequired = -51461,
    
    /*!
     =========================================================
     Authority Validation  (515xx) - MSIDErrorDomain
     =========================================================
     */
    // Authority validation response failure
    MSIDErrorAuthorityValidation            = -51500,
    MSIDErrorAuthorityValidationWebFinger   = -51501,

    /*!
     =========================================================
     Interactive flow errors    (516xx) - MSIDOAuthErrorDomain
     =========================================================
     */
    
    // The user or application failed to authenticate in the interactive flow.
    // Inspect MSALOAuthErrorKey and MSALErrorDescriptionKey in the userInfo
    // dictionary for more detailed information about the specific error.
    MSIDErrorAuthorizationFailed        = -51600,

    // User has cancelled the interactive flow.
    MSIDErrorUserCancel                 = -51611,
    
    // The interactive flow was cancelled programmatically.
    MSIDErrorSessionCanceledProgrammatically = -51612,
    
    // Interactive authentication session failed to start.
    MSIDErrorInteractiveSessionStartFailure = -51621,
    /*!
     An interactive authentication session is already running.
     Another authentication session can not be launched yet.
     */
    MSIDErrorInteractiveSessionAlreadyRunning = -51622,

    // Embedded webview has failed to find a view controller to display web contents
    MSIDErrorNoMainViewController = - 51631,
};

extern NSError *MSIDCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError *underlyingError, NSUUID *correlationId, NSDictionary *additionalUserInfo);

extern MSIDErrorCode MSIDErrorCodeForOAuthError(NSString *oauthError, MSIDErrorCode defaultCode);

extern NSDictionary<NSString *, NSArray *> *MSIDErrorDomainsAndCodes(void);
