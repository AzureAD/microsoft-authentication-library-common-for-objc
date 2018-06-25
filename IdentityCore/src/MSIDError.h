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

typedef NS_ENUM(NSInteger, MSIDErrorCode)
{
    /*! =================================================
     General Errors (510xx, 511xx) - MSIDErrorDomain
     ====================================================
     */
    // General internal errors that do not fall into one of the specific type
    // of an error described below.
    MSIDErrorInternal = -51100,
    
    // Parameter errors
    MSIDErrorInvalidInternalParameter   = -51101,
    MSIDErrorInvalidDeveloperParameter  = -51102,
   
    // Invalid request
    MSIDErrorInvalidRequest             = -51103,
    
    // Unsupported functionality
    MSIDErrorUnsupportedFunctionality   = -51104,
    
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
    MSIDErrorInteractionRequired        = -51401,
    
    // Server returned a response indicating an OAuth error
    MSIDErrorServerOauth                = -51402,
    // Server returned an invalid response
    MSIDErrorServerInvalidResponse      = -51403,
    // Server returned a refresh token reject response
    MSIDErrorServerRefreshTokenRejected = -51404,
    // Other specific server response errors
    
    MSIDErrorServerInvalidClient        = -51405,
    MSIDErrorServerInvalidGrant         = -51406,
    MSIDErrorServerInvalidScope         = -51407,
    
    // State verification has failed
    MSIDErrorServerInvalidState         = -51408,
    
    // Redirect to non HTTPS detected
    MSIDErrorServerNonHttpsRedirect     = -51409,
    
    /*!
     =========================================================
     Authority Validation  (515xx) - MSIDErrorDomain
     =========================================================
     */
    // Authority validation response failure
    MSIDErrorAuthorityValidation  = -51500,
    
    /*!
     =========================================================
     Interactive flow errors    (516xx) - MSIDOAuthErrorDomain
     =========================================================
     */
    /*!
     The user or application failed to authenticate in the interactive flow.
     Inspect MSALOAuthErrorKey and MSALErrorDescriptionKey in the userInfo
     dictionary for more detailed information about the specific error.
     */
    MSIDErrorAuthorizationFailed        = -51600,

    // User has cancelled the interactive flow.
    MSIDErrorUserCancel                 = -51601,
    
    // The interactive flow was cancelled programmatically.
    MSIDErrorSessionCanceledProgramatically = -51602,
    
    // Interactive authentication session failed to start.
    MSIDErrorInteractiveSessionStartFailure = -51603,
    /*!
     An interactive authentication session is already running.
     Another authentication session can not be launched yet.
     */
    MSIDErrorInteractiveSessionAlreadyRunning = -51604,

    // Embedded webview has failed to find a view controller to display web contents
    MSIDErrorNoMainViewController = - 51605,
};

extern NSError *MSIDCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError *underlyingError, NSUUID *correlationId, NSDictionary *additionalUserInfo);

extern MSIDErrorCode MSIDErrorCodeForOAuthError(NSString *oauthError, MSIDErrorCode defaultCode);
