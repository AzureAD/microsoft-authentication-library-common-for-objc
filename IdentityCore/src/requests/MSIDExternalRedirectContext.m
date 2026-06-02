//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "MSIDExternalRedirectContext.h"

@implementation MSIDExternalRedirectContext

- (instancetype)initWithRedirectURL:(NSURL *)redirectURL
                      correlationId:(NSUUID *)correlationId
                          loginHint:(NSString *)loginHint
                    parentAuthority:(MSIDAuthority *)parentAuthority
      parentExtraURLQueryParameters:(NSDictionary<NSString *, NSString *> *)parentExtraURLQueryParameters
                      parentWebView:(WKWebView *)parentWebView
                         tokenCache:(id<MSIDCacheAccessor>)tokenCache
               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       oauthFactory:(MSIDOauth2Factory *)oauthFactory
{
    self = [super init];
    if (self)
    {
        _redirectURL = redirectURL;
        _correlationId = correlationId;
        _loginHint = [loginHint copy];
        _parentAuthority = parentAuthority;
        _parentExtraURLQueryParameters = [parentExtraURLQueryParameters copy];
        _parentWebView = parentWebView;
        _tokenCache = tokenCache;
        _accountMetadataCache = accountMetadataCache;
        _oauthFactory = oauthFactory;
    }
    return self;
}

@end
