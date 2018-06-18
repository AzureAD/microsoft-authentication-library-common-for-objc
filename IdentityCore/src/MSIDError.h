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
     General Errors (510xx, 511xx)
     =================================================  */
    // General internal errors that do not fall into one of the specific type
    // of an error described below.
    MSIDErrorInternal = -51000,
    
    // Parameter errors
    MSIDErrorInvalidInternalParameter   = -51101,
    MSIDErrorInvalidDeveloperParameter  = -51102,
   
    // Unsupported functionality
    MSIDErrorUnsupportedFunctionality = -51199,
    
    /*!
    =================================================
     Cache Errors   (512xx,
                     513xx - Keychain)
    =================================================
     */

    // Multiple users found in cache when one was intended
    MSIDErrorCacheMultipleUsers     = -51201,
    
    /*!
     MSID encounted an error when trying to store or retrieve items from
     keychain. Inspect NSUnderlyingError from the userInfo dictionary for
     more information about the specific error. Keychain error codes are
     documented in Apple's <Security/SecBase.h> header file
     */
    MSIDErrorTokenCacheItemFailure  = -51301,
    MSIDErrorWrapperCacheFailure    = -51302,
    MSIDErrorCacheBadFormat         = -51303,
    MSIDErrorCacheVersionMismatch   = -51304,
    
    /*!
     =================================================
     Server errors  (514xx)
     =================================================
     */
    // Server returned a response indicating an OAuth error
    MSIDErrorServerOauth                = -51401,
    // Server returned an invalid response
    MSIDErrorServerInvalidResponse      = -51402,
    // Server returned a refresh token reject response
    MSIDErrorServerRefreshTokenRejected = -51403,
    // Other specific server response errors
    MSIDErrorInvalidRequest             = -51404,
    MSIDErrorInvalidClient              = -51405,
    MSIDErrorInvalidGrant               = -51406,
    MSIDErrorInvalidScope               = -51407,
    
    /*!
     =================================================
     Interactive flow errors    (515xx)
     =================================================
     */
    /*!
     The user or application failed to authenticate in the interactive flow.
     Inspect MSALOAuthErrorKey and MSALErrorDescriptionKey in the userInfo
     dictionary for more detailed information about the specific error.
     */
    MSIDErrorAuthorizationFailed        = -51510,

    // State verification has failed in the interactive flow.
    MSIDErrorInvalidState               = -51511,

    // User has cancelled the interactive flow.
    MSIDErrorUserCancel                 = -51512,
    
    // The interactive flow was cancelled programmatically.
    MSIDErrorSessionCanceled            = -51513,
    
    // Interactive authentication session failed to start.
    MSIDErrorInteractiveSessionStartFailure = -51514,
    /*!
     An interactive authentication session is already running.
     Another authentication session can not be launched yet.
     */
    MSIDErrorInteractiveSessionAlreadyRunning = -51515,
    
    /*!
     =================================================
     Boundaries - To be used to enumerate all codes
     =================================================
     */
    MSIDErrorCodeFirst = MSIDErrorInternal,
    MSIDErrorCodeLast = MSIDErrorInteractiveSessionAlreadyRunning
    
};

extern NSError *MSIDCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError *underlyingError, NSUUID *correlationId, NSDictionary *additionalUserInfo);

extern MSIDErrorCode MSIDErrorCodeForOAuthError(NSString *oauthError, MSIDErrorCode defaultCode);

