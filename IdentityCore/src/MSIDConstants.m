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

#import "MSIDConstants.h"

NSString *const MSID_PLATFORM_KEY                  = @"x-client-SKU";
NSString *const MSID_SOURCE_PLATFORM_KEY           = @"x-client-src-SKU";
NSString *const MSID_PLATFORM_SEQUENCE_KEY         = @"x-client-xtra-sku";
NSString *const MSID_VERSION_KEY                   = @"x-client-Ver";
NSString *const MSID_CPU_KEY                       = @"x-client-CPU";
NSString *const MSID_OS_VER_KEY                    = @"x-client-OS";
NSString *const MSID_DEVICE_MODEL_KEY              = @"x-client-DM";
NSString *const MSID_APP_NAME_KEY                  = @"x-app-name";
NSString *const MSID_APP_VER_KEY                   = @"x-app-ver";
NSString *const MSID_CCS_HINT_KEY                  = @"X-AnchorMailbox";
NSString *const MSID_WEBAUTH_IGNORE_SSO_KEY        = @"x-ms-sso-Ignore-SSO";
NSString *const MSID_WEBAUTH_REFRESH_TOKEN_KEY     = @"x-ms-sso-RefreshToken";

NSString *const MSID_DEFAULT_FAMILY_ID             = @"1";
NSString *const MSID_ADAL_SDK_NAME                 = @"adal-objc";
NSString *const MSID_MSAL_SDK_NAME                 = @"msal-objc";
NSString *const MSID_SDK_NAME_KEY                  = @"sdk_name";


NSString *const MSIDTrustedAuthority               = @"login.windows.net";
NSString *const MSIDTrustedAuthorityUS             = @"login.microsoftonline.us";
NSString *const MSIDTrustedAuthorityChina          = @"login.chinacloudapi.cn";
NSString *const MSIDTrustedAuthorityChina2         = @"login.partner.microsoftonline.cn";
NSString *const MSIDTrustedAuthorityGermany        = @"login.microsoftonline.de";
NSString *const MSIDTrustedAuthorityWorldWide      = @"login.microsoftonline.com";
NSString *const MSIDTrustedAuthorityUSGovernment   = @"login-us.microsoftonline.com";
NSString *const MSIDTrustedAuthorityCloudGovApi    = @"login.usgovcloudapi.net";

NSString *const MSID_DEFAULT_AAD_AUTHORITY         = @"https://login.microsoftonline.com/common";
NSString *const MSID_DEFAULT_MSA_TENANTID          = @"9188040d-6c67-4c5b-b112-36a304b66dad";

NSString *const MSID_CLIENT_SDK_TYPE_MSAL         = @"sdk_msal";
NSString *const MSID_CLIENT_SDK_TYPE_ADAL         = @"sdk_adal";

NSString *const MSID_POP_TOKEN_PRIVATE_KEY = @"com.microsoft.token.private.key";
NSString *const MSID_POP_TOKEN_KEY_LABEL = @"com.microsoft.token.key";
NSString *const MSID_THROTTLING_METADATA_KEYCHAIN = @"com.microsoft.identity.throttling.metadata";
NSString *const MSID_THROTTLING_METADATA_KEYCHAIN_VERSION = @"Ver1";

NSString *const MSID_USE_SINGLE_FRT_KEYCHAIN          = @"useSingleFRT";
NSString *const MSID_USE_SINGLE_FRT_KEY               = @"use_single_frt";
NSString *const MSID_FRT_STATUS_ENABLED               = @"on";
NSString *const MSID_FRT_STATUS_DISABLED              = @"off";

NSString *const MSID_SHARED_MODE_CURRENT_ACCOUNT_CHANGED_NOTIFICATION_KEY = @"SHARED_MODE_CURRENT_ACCOUNT_CHANGED";

NSString *const MSID_PREFERRED_AUTH_METHOD_KEY     = @"pc";
NSString *const MSID_PREFERRED_AUTH_METHOD_QR_PIN  = @"18";

NSString *const MSID_CLIENT_SKU_MSAL_IOS           = @"MSAL.iOS";
NSString *const MSID_CLIENT_SKU_MSAL_OSX           = @"MSAL.OSX";
NSString *const MSID_CLIENT_SKU_CPP_IOS            = @"MSAL.xplat.iOS";
NSString *const MSID_CLIENT_SKU_CPP_OSX            = @"MSAL.xplat.macOS";
NSString *const MSID_CLIENT_SKU_ADAL_IOS           = @"iOS";

NSString *const MSID_BROWSER_NATIVE_MESSAGE_ACCOUNT_ID_KEY = @"accountId";

NSString *const MSID_BROWSER_RESPONSE_SWITCH_BROWSER = @"switch_browser";
NSString *const MSID_BROWSER_RESPONSE_SWITCH_BROWSER_RESUME = @"switch_browser_resume";

NSString *const MSID_FLIGHT_USE_V2_WEB_RESPONSE_FACTORY = @"use_v2_web_response_factory";
NSString *const MSID_FLIGHT_SUPPORT_DUNA_CBA = @"support_duna_cba_v2";
NSString *const MSID_FLIGHT_CLIENT_SFRT_STATUS = @"sfrt_status";


#define METHODANDLINE   [NSString stringWithFormat:@"%s [Line %d]", __PRETTY_FUNCTION__, __LINE__]
