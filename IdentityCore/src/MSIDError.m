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

#import "MSIDErrorConverter.h"

NSString *MSIDErrorDescriptionKey = @"MSIDErrorDescriptionKey";
NSString *MSIDOAuthErrorKey = @"MSIDOAuthErrorKey";
NSString *MSIDOAuthSubErrorKey = @"MSIDOAuthSubErrorKey";
NSString *MSIDCorrelationIdKey = @"MSIDCorrelationIdKey";
NSString *MSIDHTTPHeadersKey = @"MSIDHTTPHeadersKey";
NSString *MSIDHTTPResponseCodeKey = @"MSIDHTTPResponseCodeKey";
NSString *MSIDDeclinedScopesKey = @"MSIDDeclinedScopesKey";
NSString *MSIDGrantedScopesKey = @"MSIDGrantedScopesKey";
NSString *MSIDUserDisplayableIdkey = @"MSIDUserDisplayableIdkey";
NSString *MSIDHomeAccountIdkey = @"MSIDHomeAccountIdkey";
NSString *MSIDBrokerVersionKey = @"MSIDBrokerVersionKey";
NSString *MSIDServerUnavailableStatusKey = @"MSIDServerUnavailableStatusKey";

NSString *MSIDErrorDomain = @"MSIDErrorDomain";
NSString *MSIDOAuthErrorDomain = @"MSIDOAuthErrorDomain";
NSString *MSIDKeychainErrorDomain = @"MSIDKeychainErrorDomain";
NSString *MSIDHttpErrorCodeDomain = @"MSIDHttpErrorCodeDomain";
NSString *MSIDInvalidTokenResultKey = @"MSIDInvalidTokenResultKey";
NSString *MSIDErrorMethodAndLineKey = @"MSIDMethodAndLineKey";
NSInteger const MSIDSSOExtensionUnderlyingError = -6000;

NSExceptionName const MSIDGenericException = @"MSIDGenericException";

NSError *MSIDCreateError(NSString *domain, NSInteger code, NSString *errorDescription, NSString *oauthError, NSString *subError, NSError *underlyingError, NSUUID *correlationId, NSDictionary *additionalUserInfo, BOOL logErrorDescription)
{
    id<MSIDErrorConverting> errorConverter = MSIDErrorConverter.errorConverter;

    if (!errorConverter)
    {
        errorConverter = MSIDErrorConverter.defaultErrorConverter;
    }
    
    if (logErrorDescription)
    {
        MSID_LOG_WITH_CORR(MSIDLogLevelError, correlationId, @"Creating Error with description: %@", errorDescription);
    }

    return [errorConverter errorWithDomain:domain
                                      code:code
                          errorDescription:errorDescription
                                oauthError:oauthError
                                  subError:subError
                           underlyingError:underlyingError
                             correlationId:correlationId
                                  userInfo:additionalUserInfo];
}

MSIDErrorCode MSIDErrorCodeForOAuthError(NSString *oauthError, MSIDErrorCode defaultCode)
{
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_request"] == NSOrderedSame)
    {
        return MSIDErrorServerInvalidRequest;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_client"] == NSOrderedSame)
    {
        return MSIDErrorServerInvalidClient;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_scope"] == NSOrderedSame)
    {
        return MSIDErrorServerInvalidScope;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_grant"] == NSOrderedSame)
    {
        return MSIDErrorServerInvalidGrant;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"unauthorized_client"] == NSOrderedSame)
    {
        return MSIDErrorServerUnauthorizedClient;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"interaction_required"] == NSOrderedSame)
    {
        return MSIDErrorInteractionRequired;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"access_denied"] == NSOrderedSame)
    {
        return MSIDErrorServerAccessDenied;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"tokenTransferFailedOTC"] == NSOrderedSame)
    {   // Account Transfer session time out, When the token's time is expired
        return MSIDErrorUserCancel;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"server_error"] == NSOrderedSame)
    {
        return MSIDErrorServerError;
    }
    return defaultCode;
}

MSIDErrorCode MSIDErrorCodeForOAuthErrorWithSubErrorCode(NSString *oauthError, MSIDErrorCode defaultCode, NSString *subError)
{
    if (subError == nil)
    {
        return MSIDErrorCodeForOAuthError(oauthError, defaultCode);
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"invalid_grant"] == NSOrderedSame && [subError caseInsensitiveCompare:@"transfer_token_expired"] == NSOrderedSame)
    {   // When account Transfter Token is expired.
        return MSIDErrorUserCancel;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"access_denied"] == NSOrderedSame && [subError caseInsensitiveCompare:@"tts_denied"] == NSOrderedSame)
    {   //when user cancels, this is the same error we return to mobile app for Account Transfer
        return MSIDErrorUserCancel;
    }
    if (oauthError && [oauthError caseInsensitiveCompare:@"access_denied"] == NSOrderedSame && [subError caseInsensitiveCompare:@"user_skipped"] == NSOrderedSame)
    {   //Account Transfter, when user skips the QR code page.
        return MSIDErrorUserCancel;
    }
    return MSIDErrorCodeForOAuthError(oauthError, defaultCode);
}

NSDictionary* MSIDErrorDomainsAndCodes(void)
{
    return @{ MSIDErrorDomain : @[// General Errors
                      @(MSIDErrorInternal),
                      @(MSIDErrorInvalidInternalParameter),
                      @(MSIDErrorInvalidDeveloperParameter),
                      @(MSIDErrorMissingAccountParameter),
                      @(MSIDErrorUnsupportedFunctionality),
                      @(MSIDErrorInteractionRequired),
                      @(MSIDErrorServerNonHttpsRedirect),
                      @(MSIDErrorMismatchedAccount),
                      
                      // Cache Errors
                      @(MSIDErrorCacheMultipleUsers),
                      @(MSIDErrorCacheBadFormat),
                      
                      // Authority Validation Errors
                      @(MSIDErrorAuthorityValidation),
                      
                      // Interactive flow errors
                      @(MSIDErrorUserCancel),
                      @(MSIDErrorSessionCanceledProgrammatically),
                      @(MSIDErrorInteractiveSessionStartFailure),
                      @(MSIDErrorInteractiveSessionAlreadyRunning),
                      @(MSIDErrorNoMainViewController),
                      @(MSIDErrorAttemptToOpenURLFromExtension),
                      @(MSIDErrorUINotSupportedInExtension),

                      // Broker errors
                      @(MSIDErrorBrokerResponseNotReceived),
                      @(MSIDErrorBrokerNoResumeStateFound),
                      @(MSIDErrorBrokerBadResumeStateFound),
                      @(MSIDErrorBrokerMismatchedResumeState),
                      @(MSIDErrorBrokerResponseHashMissing),
                      @(MSIDErrorBrokerCorruptedResponse),
                      @(MSIDErrorBrokerResponseDecryptionFailed),
                      @(MSIDErrorBrokerResponseHashMismatch),
                      @(MSIDErrorBrokerKeyFailedToCreate),
                      @(MSIDErrorBrokerKeyNotFound),
                      @(MSIDErrorWorkplaceJoinRequired),
                      @(MSIDErrorBrokerUnknown),
                      @(MSIDErrorBrokerApplicationTokenWriteFailed),
                      @(MSIDErrorBrokerApplicationTokenReadFailed),
                      @(MSIDErrorJITLinkServerConfirmationTimeout),
                      @(MSIDErrorJITLinkServerConfirmationError),
                      @(MSIDErrorJITLinkAcquireTokenError),
                      @(MSIDErrorJITLinkTokenAcquiredWrongTenant),
                      @(MSIDErrorJITLinkError),
                      @(MSIDErrorJITComplianceCheckResultNotCompliant),
                      @(MSIDErrorJITComplianceCheckResultTimeout),
                      @(MSIDErrorJITComplianceCheckResultUnknown),
                      @(MSIDErrorJITComplianceCheckInvalidLinkPayload),
                      @(MSIDErrorJITLinkConfigNotFound),
                      @(MSIDErrorJITInvalidLinkTokenConfig),
                      @(MSIDErrorJITWPJDeviceRegistrationFailed),
                      @(MSIDErrorJITWPJAccountIdentifierNil),
                      @(MSIDErrorJITWPJAcquireTokenError),
                      @(MSIDErrorJITRetryRequired),
                      @(MSIDErrorJITUnknownStatusWebCP),
                      @(MSIDErrorJITTroubleshootingRequired),
                      @(MSIDErrorJITTroubleshootingCreateController),
                      @(MSIDErrorJITTroubleshootingResultUnknown),
                      @(MSIDErrorJITTroubleshootingAcquireToken),

                      ],
              MSIDOAuthErrorDomain : @[// Server Errors
                      @(MSIDErrorServerOauth),
                      @(MSIDErrorServerInvalidResponse),
                      @(MSIDErrorServerRefreshTokenRejected),
                      @(MSIDErrorServerInvalidRequest),
                      @(MSIDErrorServerInvalidClient),
                      @(MSIDErrorServerInvalidGrant),
                      @(MSIDErrorServerInvalidScope),
                      @(MSIDErrorServerUnauthorizedClient),
                      @(MSIDErrorServerDeclinedScopes),
                      @(MSIDErrorServerInvalidState),
                      @(MSIDErrorServerProtectionPoliciesRequired),
                      @(MSIDErrorAuthorizationFailed),
                      @(MSIDErrorServerError),
                      ],
              MSIDHttpErrorCodeDomain : @[
                      @(MSIDErrorServerUnhandledResponse)
                      ]

              // TODO: add new codes here
              };
}

void MSIDFillAndLogError(NSError **error, MSIDErrorCode errorCode, NSString *errorDescription, NSUUID *correlationID)
{
    if (error)
    {
        *error = MSIDCreateError(MSIDErrorDomain, errorCode, errorDescription, nil, nil, nil, correlationID, nil, NO);
    }

    MSID_LOG_WITH_CORR_PII(MSIDLogLevelError, correlationID, @"Encountered error with code %ld, description %@", (long)errorCode, MSID_PII_LOG_MASKABLE(errorDescription));
}

NSString *MSIDErrorCodeToString(MSIDErrorCode errorCode)
{
    switch (errorCode)
    {
            // General errors
        case MSIDErrorInternal:
            return @"MSIDErrorInternal";
        case MSIDErrorInvalidInternalParameter:
            return @"MSIDErrorInvalidInternalParameter";
        case MSIDErrorInvalidDeveloperParameter:
            return @"MSIDErrorInvalidDeveloperParameter";
        case MSIDErrorMissingAccountParameter:
            return @"MSIDErrorMissingAccountParameter";
        case MSIDErrorUnsupportedFunctionality:
            return @"MSIDErrorUnsupportedFunctionality";
        case MSIDErrorInteractionRequired:
            return @"MSIDErrorInteractionRequired";
        case MSIDErrorServerNonHttpsRedirect:
            return @"MSIDErrorServerNonHttpsRedirect";
        case MSIDErrorMismatchedAccount:
            return @"MSIDErrorMismatchedAccount";
        case MSIDErrorRedirectSchemeNotRegistered:
            return @"MSIDErrorRedirectSchemeNotRegistered";
            // Cache errors
        case MSIDErrorCacheMultipleUsers:
            return @"MSIDErrorCacheMultipleUsers";
        case MSIDErrorCacheBadFormat:
            return @"MSIDErrorCacheBadFormat";
            // Server errors
        case MSIDErrorServerOauth:
            return @"MSIDErrorServerOauth";
        case MSIDErrorServerInvalidResponse:
            return @"MSIDErrorServerInvalidResponse";
        case MSIDErrorServerRefreshTokenRejected:
            return @"MSIDErrorServerRefreshTokenRejected";
        case MSIDErrorServerInvalidRequest:
            return @"MSIDErrorServerInvalidRequest";
        case MSIDErrorServerInvalidClient:
            return @"MSIDErrorServerInvalidClient";
        case MSIDErrorServerInvalidGrant:
            return @"MSIDErrorServerInvalidGrant";
        case MSIDErrorServerInvalidScope:
            return @"MSIDErrorServerInvalidScope";
        case MSIDErrorServerUnauthorizedClient:
            return @"MSIDErrorServerUnauthorizedClient";
        case MSIDErrorServerDeclinedScopes:
            return @"MSIDErrorServerDeclinedScopes";
        case MSIDErrorServerAccessDenied:
            return @"MSIDErrorServerAccessDenied";
        case MSIDErrorServerError:
            return @"MSIDErrorServerError";
        case MSIDErrorServerInvalidState:
            return @"MSIDErrorServerInvalidState";
        case MSIDErrorServerProtectionPoliciesRequired:
            return @"MSIDErrorServerProtectionPoliciesRequired";
        case MSIDErrorAuthorizationFailed:
            return @"MSIDErrorAuthorizationFailed";
            // HTTP errors
        case MSIDErrorServerUnhandledResponse:
            return @"MSIDErrorServerUnhandledResponse";
            // Authority validation errors
        case MSIDErrorAuthorityValidation:
            return @"MSIDErrorAuthorityValidation";
            // Interactive flow errors
        case MSIDErrorUserCancel:
            return @"MSIDErrorUserCancel";
        case MSIDErrorSessionCanceledProgrammatically:
            return @"MSIDErrorSessionCanceledProgrammatically";
        case MSIDErrorInteractiveSessionStartFailure:
            return @"MSIDErrorInteractiveSessionStartFailure";
        case MSIDErrorInteractiveSessionAlreadyRunning:
            return @"MSIDErrorInteractiveSessionAlreadyRunning";
        case MSIDErrorNoMainViewController:
            return @"MSIDErrorNoMainViewController";
        case MSIDErrorAttemptToOpenURLFromExtension:
            return @"MSIDErrorAttemptToOpenURLFromExtension";
        case MSIDErrorUINotSupportedInExtension:
            return @"MSIDErrorUINotSupportedInExtension";
            // Broker flow errors
        case MSIDErrorBrokerResponseNotReceived:
            return @"MSIDErrorBrokerResponseNotReceived";
        case MSIDErrorBrokerNoResumeStateFound:
            return @"MSIDErrorBrokerNoResumeStateFound";
        case MSIDErrorBrokerBadResumeStateFound:
            return @"MSIDErrorBrokerBadResumeStateFound";
        case MSIDErrorBrokerMismatchedResumeState:
            return @"MSIDErrorBrokerMismatchedResumeState";
        case MSIDErrorBrokerResponseHashMissing:
            return @"MSIDErrorBrokerResponseHashMissing";
            // Valid broker response not present
        case MSIDErrorBrokerCorruptedResponse:
            return @"MSIDErrorBrokerCorruptedResponse";
            // Failed to decrypt broker response
        case MSIDErrorBrokerResponseDecryptionFailed:
            return @"MSIDErrorBrokerResponseDecryptionFailed";
            // Broker hash mismatched in result after decryption
        case MSIDErrorBrokerResponseHashMismatch:
            return @"MSIDErrorBrokerResponseHashMismatch";
            // Failed to create broker encryption key
        case MSIDErrorBrokerKeyFailedToCreate:
            return @"MSIDErrorBrokerKeyFailedToCreate";
            // Couldn't read broker key
        case MSIDErrorBrokerKeyNotFound :
            return @"MSIDErrorBrokerKeyNotFound";
        case MSIDErrorWorkplaceJoinRequired:
            return @"MSIDErrorWorkplaceJoinRequired";
            // Unknown broker error returned
        case MSIDErrorBrokerUnknown:
            return @"MSIDErrorBrokerUnknown";
            // Failed to save broker application token
        case MSIDErrorBrokerApplicationTokenWriteFailed :
            return @"MSIDErrorBrokerApplicationTokenWriteFailed";
        case MSIDErrorBrokerApplicationTokenReadFailed :
            return @"MSIDErrorBrokerApplicationTokenReadFailed";
        case MSIDErrorBrokerNotAvailable:
            return @"MSIDErrorBrokerNotAvailable";
            // SSO Extension internal error
        case MSIDErrorSSOExtensionUnexpectedError:
            return @"MSIDErrorSSOExtensionUnexpectedError";
            // JIT - Link errors
        case MSIDErrorJITLinkServerConfirmationTimeout:
            return @"MSIDErrorJITLinkServerConfirmationTimeout";
        case MSIDErrorJITLinkServerConfirmationError:
            return @"MSIDErrorJITLinkServerConfirmationError";
        case MSIDErrorJITLinkAcquireTokenError:
            return @"MSIDErrorJITLinkAcquireTokenError";
        case MSIDErrorJITLinkTokenAcquiredWrongTenant:
            return @"MSIDErrorJITLinkTokenAcquiredWrongTenant";
        case MSIDErrorJITLinkError:
            return @"MSIDErrorJITLinkError";
            // JIT - Compliance errors
        case MSIDErrorJITComplianceCheckResultNotCompliant:
            return @"MSIDErrorJITComplianceCheckResultNotCompliant";
        case MSIDErrorJITComplianceCheckResultTimeout:
            return @"MSIDErrorJITComplianceCheckResultTimeout";
        case MSIDErrorJITComplianceCheckResultUnknown:
            return @"MSIDErrorJITComplianceCheckResultUnknown";
        case MSIDErrorJITComplianceCheckInvalidLinkPayload:
            return @"MSIDErrorJITComplianceCheckInvalidLinkPayload";
        case MSIDErrorJITComplianceCheckCreateController:
            return @"MSIDErrorJITComplianceCheckCreateController";
            // JIT - Link errors
        case MSIDErrorJITLinkConfigNotFound:
            return @"MSIDErrorJITLinkConfigNotFound";
        case MSIDErrorJITInvalidLinkTokenConfig:
            return @"MSIDErrorJITInvalidLinkTokenConfig";
            // JIT - WPJ errors
        case MSIDErrorJITWPJDeviceRegistrationFailed:
            return @"MSIDErrorJITWPJDeviceRegistrationFailed";
        case MSIDErrorJITWPJAccountIdentifierNil:
            return @"MSIDErrorJITWPJAccountIdentifierNil";
        case MSIDErrorJITWPJAcquireTokenError:
            return @"MSIDErrorJITWPJAcquireTokenError";
        case MSIDErrorJITUnknownStatusWebCP:
            return @"MSIDErrorJITUnknownStatusWebCP";
        case MSIDErrorJITRetryRequired:
            return @"MSIDErrorJITRetryRequired";
        case MSIDErrorJITTroubleshootingRequired:
            return @"MSIDErrorJITTroubleshootingRequired";
        case MSIDErrorJITTroubleshootingCreateController:
            return @"MSIDErrorJITTroubleshootingCreateController";
        case MSIDErrorJITTroubleshootingResultUnknown:
            return @"MSIDErrorJITTroubleshootingResultUnknown";
        case MSIDErrorJITTroubleshootingAcquireToken:
            return @"MSIDErrorJITTroubleshootingAcquireToken";
            // Throttling errors
        case MSIDErrorThrottleCacheNoRecord:
            return @"MSIDErrorThrottleCacheNoRecord";
        case MSIDErrorThrottleCacheInvalidSignature:
            return @"MSIDErrorThrottleCacheInvalidSignature";
    }
    return @"Unknown";
}
