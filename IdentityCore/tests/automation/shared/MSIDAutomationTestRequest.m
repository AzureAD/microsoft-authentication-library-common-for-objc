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

#import "MSIDAutomationTestRequest.h"

@implementation MSIDAutomationTestRequest

- (BOOL)usesEmbeddedWebView
{
    return self.webViewType == MSIDWebviewTypeWKWebView || self.usePassedWebView;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                                 error:(NSError * __autoreleasing *)error
{
    self = [super init];

    if (self)
    {
        _clientId = json[@"client_id"];
        _requestResource = json[@"resource"];
        _requestScopes = json[@"scopes"];
        _redirectUri = json[@"redirect_uri"];
        _configurationAuthority = json[@"authority"];
        _acquireTokenAuthority = json[@"acquiretoken_authority"];
        _cacheAuthority = json[@"cache_authority"];
        _promptBehavior = json[@"prompt_behavior"];
        _homeAccountIdentifier = json[@"home_account_identifier"];
        _legacyAccountIdentifier = json[@"user_identifier"];
        _legacyAccountIdentifierType = json[@"user_identifier_type"];
        _loginHint = json[@"login_hint"];
        _claims = json[@"claims"];
        _brokerEnabled = [json[@"brokerEnabled"] boolValue];
        _clientCapabilities = json[@"client_capabilities"];
        _refreshToken = json[@"refresh_token"];

#if TARGET_OS_IPHONE
        NSString *webviewTypeString = json[@"webviewtype"];

        if ([webviewTypeString isEqualToString:@"default"])
        {
            _webViewType = MSIDWebviewTypeDefault;
        }
        else if ([webviewTypeString isEqualToString:@"session"])
        {
            _webViewType = MSIDWebviewTypeAuthenticationSession;
        }
        else if ([webviewTypeString isEqualToString:@"safari"])
        {
            _webViewType = MSIDWebviewTypeSafariViewController;
        }
        else if ([webviewTypeString isEqualToString:@"embedded"])
        {
            _webViewType = MSIDWebviewTypeWKWebView;
        }
#else
        _webViewType = MSIDWebviewTypeWKWebView;
#endif

        _validateAuthority = [json[@"validate_authority"] boolValue];
        _sliceParameters = json[@"slice_parameters"];
        _extraQueryParameters = json[@"extra_query_params"];
        _extraScopes = json[@"extra_scopes"];
        _usePassedWebView = [json[@"use_passed_in_webview"] boolValue];
        _forceRefresh = [json[@"force_refresh"] boolValue];
        _isIntuneMAMCACapable = [json[@"intune_mam_ca_capable"] boolValue];
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"client_id"] = _clientId;
    json[@"resource"] = _requestResource;
    json[@"scopes"] = _requestScopes;
    json[@"redirect_uri"] = _redirectUri;
    json[@"authority"] = _configurationAuthority;
    json[@"acquiretoken_authority"] = _acquireTokenAuthority;
    json[@"cache_authority"] = _cacheAuthority;
    json[@"prompt_behavior"] = _promptBehavior;
    json[@"home_account_identifier"] = _homeAccountIdentifier;
    json[@"user_identifier"] = _legacyAccountIdentifier;
    json[@"login_hint"] = _loginHint;
    json[@"claims"] = _claims;
    json[@"use_passed_in_webview"] = @(_usePassedWebView);
    json[@"refresh_token"] = _refreshToken;
    json[@"intune_mam_ca_capable"] = @(_isIntuneMAMCACapable);

    NSString *webviewType = nil;

    switch (_webViewType) {
#if TARGET_OS_IPHONE
        case MSIDWebviewTypeDefault:
            webviewType = @"default";
            break;

        case MSIDWebviewTypeAuthenticationSession:
            webviewType = @"session";
            break;

        case MSIDWebviewTypeSafariViewController:
            webviewType = @"safari";
            break;
#endif

        case MSIDWebviewTypeWKWebView:
            webviewType = @"embedded";
            break;

        default:
            break;
    }

    json[@"webviewtype"] = webviewType;
    json[@"validate_authority"] = @(_validateAuthority);
    json[@"slice_parameters"] = _sliceParameters;
    json[@"extra_query_params"] = _extraQueryParameters;
    json[@"extra_scopes"] = _extraScopes;
    json[@"force_refresh"] = @(_forceRefresh);
    json[@"brokerEnabled"] = @(_brokerEnabled);
    json[@"client_capabilities"] = _clientCapabilities;
    json[@"user_identifier_type"] = _legacyAccountIdentifierType;

    return json;
}

@end
