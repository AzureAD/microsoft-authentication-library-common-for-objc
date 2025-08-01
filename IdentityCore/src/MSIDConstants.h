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

#import "MSIDBrokerConstants.h"

@class MSIDTokenResult;
@class MSIDAccount;
@class MSIDDeviceInfo;
@class MSIDPrtHeader;
@class MSIDDeviceHeader;
@class MSIDPasskeyAssertion;
@class MSIDPasskeyCredential;

typedef NS_ENUM(NSInteger, MSIDWebviewType)
{
    // For iOS 11 and up, uses AuthenticationSession (ASWebAuthenticationSession
    // or SFAuthenticationSession).
    // For older versions, with AuthenticationSession not being available, uses
    // SafariViewController.
    // For macOS 10.15+ uses ASWebAuthenticationSession
    // For older macOS versions, uses WKWebView
    MSIDWebviewTypeDefault,

    // Use SFAuthenticationSession/ASWebAuthenticationSession
    MSIDWebviewTypeAuthenticationSession,

#if TARGET_OS_IPHONE
    // Use SFSafariViewController for all versions.
    MSIDWebviewTypeSafariViewController,

#endif
    
    // Use WKWebView
    MSIDWebviewTypeWKWebView,
};

typedef NS_ENUM(NSInteger, MSIDRequestType)
{
    MSIDRequestBrokeredType = 0,
    MSIDRequestLocalType
};

typedef NS_ENUM(NSInteger, MSIDUIBehaviorType)
{
    MSIDUIBehaviorInteractiveType = 0,
    MSIDUIBehaviorAutoType,
    MSIDUIBehaviorForceType
};

typedef NS_ENUM(NSInteger, MSIDPromptType)
{
    MSIDPromptTypePromptIfNecessary = 0, // No prompt specified, will use cookies if present, prompt otherwise
    MSIDPromptTypeLogin, // prompt == "login", will force user to enter credentials
    MSIDPromptTypeConsent, // prompt == "consent", will force user to grant permissions
    MSIDPromptTypeCreate,  // prompt == "create", will show create account UI. https://openid.net/specs/openid-connect-prompt-create-1_0.html
    MSIDPromptTypeSelectAccount, // prompt == "select_account", will show an account picker UI
    MSIDPromptTypeRefreshSession, // prompt=refresh_session
    MSIDPromptTypeNever, // prompt=none, ensures user is never prompted
    MSIDPromptTypeDefault = MSIDPromptTypePromptIfNecessary
};

typedef NS_ENUM(NSInteger, MSIDAuthScheme)
{
    MSIDAuthSchemeBearer,
    MSIDAuthSchemePop,
    MSIDAuthSchemeSshCert,
};

typedef NS_ENUM(NSInteger, MSIDHeaderType)
{
    MSIDHeaderTypeAll = 0,
    MSIDHeaderTypePrt,
    MSIDHeaderTypeDeviceRegistration
};

typedef NS_ENUM(NSUInteger, MSIDXpcMode)
{
    MSIDXpcModeDisabled = 0, // Broker Xpc service call is disabled
    MSIDXpcModeSSOExtCompanion,// Broker Xpc service call is only used as a backup service when SsoExtension service failed. If SsoExtension is not available on the device (canPerformRequest returns false), Broker Xpc service call will be disabled
    MSIDXpcModeSSOExtBackup, // Broker Xpc service call is used as a backup call when SsoExtension service failed. If SsoExtension is not available on the device, Xpc service call will be the primary auth service
    MSIDXpcModePrimary // Development only: Broker Xpc service is used as main Sso service, and ignored SsoExtension service completely. This option will be ignored in production and will be treated same as MSIDXpcModeDisable
};

typedef void (^MSIDRequestCompletionBlock)(MSIDTokenResult * _Nullable result, NSError * _Nullable error);
typedef void (^MSIDSignoutRequestCompletionBlock)(BOOL success, NSError * _Nullable error);
typedef void (^MSIDGetAccountsRequestCompletionBlock)(NSArray<MSIDAccount *> * _Nullable accounts, BOOL returnBrokerAccountsOnly, NSError * _Nullable error);
typedef void (^MSIDGetDeviceInfoRequestCompletionBlock)(MSIDDeviceInfo * _Nullable deviceInfo, NSError * _Nullable error);
typedef void (^MSIDGetSsoCookiesRequestCompletionBlock)(NSArray<MSIDPrtHeader *> * _Nullable prtHeaders, NSArray<MSIDDeviceHeader *> * _Nullable deviceHeaders, NSError * _Nullable error);
typedef void (^MSIDSsoExtensionWrapperErrorBlock)(NSError * _Nullable error);
typedef void (^MSIDPasskeyAssertionRequestCompletionBlock)(MSIDPasskeyAssertion * _Nullable passkeyAssertion, NSError * _Nullable error);
typedef void (^MSIDPasskeyCredentialRequestCompletionBlock)(MSIDPasskeyCredential * _Nullable passkeyCredential, NSError * _Nullable error);

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
@compatibility_alias MSIDViewController UIViewController;
@compatibility_alias MSIDWindow UIWindow;
#else
#import <AppKit/AppKit.h>
@compatibility_alias MSIDViewController NSViewController;
@compatibility_alias MSIDWindow NSWindow;
#endif

extern NSString * _Nonnull const MSID_PLATFORM_KEY;//The SDK platform. iOS or OSX
extern NSString * _Nonnull const MSID_SOURCE_PLATFORM_KEY;//The source SDK platform. iOS or OSX
extern NSString * _Nonnull const MSID_PLATFORM_SEQUENCE_KEY;
extern NSString * _Nonnull const MSID_VERSION_KEY;
extern NSString * _Nonnull const MSID_CPU_KEY;//E.g. ARM64
extern NSString * _Nonnull const MSID_OS_VER_KEY;//iOS/OSX version
extern NSString * _Nonnull const MSID_DEVICE_MODEL_KEY;//E.g. iPhone 5S
extern NSString * _Nonnull const MSID_APP_NAME_KEY;
extern NSString * _Nonnull const MSID_APP_VER_KEY;
extern NSString * _Nonnull const MSID_CCS_HINT_KEY;
extern NSString * _Nonnull const MSID_WEBAUTH_IGNORE_SSO_KEY;
extern NSString * _Nonnull const MSID_WEBAUTH_REFRESH_TOKEN_KEY;

extern NSString * _Nonnull const MSID_DEFAULT_FAMILY_ID;
extern NSString * _Nonnull const MSID_ADAL_SDK_NAME;
extern NSString * _Nonnull const MSID_MSAL_SDK_NAME;
extern NSString * _Nonnull const MSID_SDK_NAME_KEY;


extern NSString * _Nonnull const MSIDTrustedAuthority;
extern NSString * _Nonnull const MSIDTrustedAuthorityUS;
extern NSString * _Nonnull const MSIDTrustedAuthorityChina;
extern NSString * _Nonnull const MSIDTrustedAuthorityChina2;
extern NSString * _Nonnull const MSIDTrustedAuthorityGermany;
extern NSString * _Nonnull const MSIDTrustedAuthorityWorldWide;
extern NSString * _Nonnull const MSIDTrustedAuthorityUSGovernment;
extern NSString * _Nonnull const MSIDTrustedAuthorityCloudGovApi;

extern NSString * _Nonnull const MSID_DEFAULT_AAD_AUTHORITY;
extern NSString * _Nonnull const MSID_DEFAULT_MSA_TENANTID;
extern NSString * _Nonnull const MSID_CLIENT_SDK_TYPE_MSAL;
extern NSString * _Nonnull const MSID_CLIENT_SDK_TYPE_ADAL;

extern NSString * _Nonnull const MSID_POP_TOKEN_PRIVATE_KEY;
extern NSString * _Nonnull const MSID_POP_TOKEN_KEY_LABEL;

extern NSString * _Nonnull const MSID_THROTTLING_METADATA_KEYCHAIN;
extern NSString * _Nonnull const MSID_THROTTLING_METADATA_KEYCHAIN_VERSION;

extern NSString * _Nonnull const MSID_USE_SINGLE_FRT_KEYCHAIN;
extern NSString * _Nonnull const MSID_USE_SINGLE_FRT_KEY;

extern NSString * _Nonnull const MSID_SHARED_MODE_CURRENT_ACCOUNT_CHANGED_NOTIFICATION_KEY;

extern NSString * _Nonnull const MSID_PREFERRED_AUTH_METHOD_KEY;
extern NSString * _Nonnull const MSID_PREFERRED_AUTH_METHOD_QR_PIN;

extern NSString * _Nonnull const MSID_CLIENT_SKU_MSAL_IOS;
extern NSString * _Nonnull const MSID_CLIENT_SKU_MSAL_OSX;
extern NSString * _Nonnull const MSID_CLIENT_SKU_CPP_IOS;
extern NSString * _Nonnull const MSID_CLIENT_SKU_CPP_OSX;
extern NSString * _Nonnull const MSID_CLIENT_SKU_ADAL_IOS;

extern NSString * _Nonnull const MSID_BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY;

typedef NS_ENUM(NSInteger, MSIDPlatformSequenceIndex)
{
    MSIDPlatformSequenceIndexSrc = 0,
    MSIDPlatformSequenceIndexMsalRuntime = 1,
    MSIDPlatformSequenceIndexBrowserExt = 2,
    MSIDPlatformSequenceIndexBrowserCore = 3,
    MSIDPlatformSequenceIndexLast = MSIDPlatformSequenceIndexBrowserCore,
};

typedef NS_ENUM(NSInteger, MSIDIsFRTEnabledStatus)
{
    // FRT has not been explicitly enabled with keychain item
    MSIDIsFRTEnabledStatusNotEnabled = 0,
    
    // FRT is enabled
    MSIDIsFRTEnabledStatusEnabled,
    
    // Client app has disabled FRT through MSIDRequestParameters or was disabled previuosly by keychain item
    MSIDIsFRTEnabledStatusDisabledByClientApp,
    
    // There was an error reading keychain item
    MSIDIsFRTEnabledStatusDisabledByKeychainError,
    
    // There was an error deserializing keychain item
    MSIDIsFRTEnabledStatusDisabledByDeserializationError,
    
    // FRT has been disabled with keychain item
    MSIDIsFRTEnabledStatusDisabledByKeychainItem
};

extern NSString * _Nonnull const MSID_FRT_STATUS_ENABLED;
extern NSString * _Nonnull const MSID_FRT_STATUS_DISABLED;

extern NSString * _Nonnull const MSID_BROWSER_RESPONSE_SWITCH_BROWSER;
extern NSString * _Nonnull const MSID_BROWSER_RESPONSE_SWITCH_BROWSER_RESUME;

extern NSString * _Nonnull const MSID_FLIGHT_USE_V2_WEB_RESPONSE_FACTORY;
extern NSString * _Nonnull const MSID_FLIGHT_SUPPORT_DUNA_CBA;
extern NSString * _Nonnull const MSID_FLIGHT_DISABLE_JIT_TROUBLESHOOTING_LEGACY_AUTH;
extern NSString * _Nonnull const MSID_FLIGHT_CLIENT_SFRT_STATUS;
extern NSString * _Nonnull const MSID_FLIGHT_DISABLE_PREFERRED_IDENTITY_CBA;
extern NSString * _Nonnull const MSID_FLIGHT_SUPPORT_STATE_DUNA_CBA;

/**
 * Flight to indicate if remove account artifacts should be disabled
 * Owner: Antonio
 * Link: N/A - No ECS flag created as this is a disable flight to be created on demand
 * Created Date: N/A
 * Status: Not started
 * Fully Allocated: Not Started
 * WorkItem: 3168316
 */
extern NSString * _Nonnull const MSID_FLIGHT_DISABLE_REMOVE_ACCOUNT_ARTIFACTS;

#define METHODANDLINE   [NSString stringWithFormat:@"%s [Line %d]", __PRETTY_FUNCTION__, __LINE__]
