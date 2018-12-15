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
        _requestTarget = json[@"target"];
        _redirectUri = json[@"redirect_uri"];
        _configurationAuthority = json[@"configuration_authority"];
        _acquireTokenAuthority = json[@"acquiretoken_authority"];
        _cacheAuthority = json[@"cache_authority"];
        _uiBehavior = json[@"ui_behavior"];
        _homeAccountIdentifier = json[@"home_account_id"];
        _displayableAccountIdentifier = json[@"displayable_account_id"];
        _loginHint = json[@"login_hint"];
        _claims = json[@"claims"];

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

        _validateAuthority = [json[@"validate_authority"] boolValue];
        _sliceParameters = json[@"slice_parameters"];
        _extraQueryParameters = json[@"extra_query_params"];
        _extraScopes = json[@"extra_scopes"];
        _usePassedWebView = [json[@"use_passed_in_webview"] boolValue];
    }

    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    json[@"client_id"] = _clientId;
    json[@"target"] = _requestTarget;
    json[@"redirect_uri"] = _redirectUri;
    json[@"configuration_authority"] = _configurationAuthority;
    json[@"acquiretoken_authority"] = _acquireTokenAuthority;
    json[@"cache_authority"] = _cacheAuthority;
    json[@"ui_behavior"] = _uiBehavior;
    json[@"home_account_id"] = _homeAccountIdentifier;
    json[@"displayable_account_id"] = _displayableAccountIdentifier;
    json[@"login_hint"] = _loginHint;
    json[@"claims"] = _claims;
    json[@"use_passed_in_webview"] = @(_usePassedWebView);

    NSString *webviewType = nil;

    switch (_webViewType) {
        case MSIDWebviewTypeDefault:
            webviewType = @"default";
            break;

        case MSIDWebviewTypeAuthenticationSession:
            webviewType = @"session";
            break;

        case MSIDWebviewTypeSafariViewController:
            webviewType = @"safari";
            break;

        case MSIDWebviewTypeWKWebView:
            webviewType = @"embedded";
            break;

        default:
            break;
    }

    json[@"validate_authority"] = @(_validateAuthority);
    json[@"slice_parameters"] = _sliceParameters;
    json[@"extra_query_params"] = _extraQueryParameters;
    json[@"extra_scopes"] = _extraScopes;

    return json;
}

@end
