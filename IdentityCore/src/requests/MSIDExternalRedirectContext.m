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

#import "MSIDExternalRedirectContext.h"
#import "MSIDAuthority.h"
#import "MSIDCacheAccessor.h"
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDOauth2Factory.h"

@implementation MSIDExternalRedirectContext

#if TARGET_OS_IPHONE
- (instancetype)initWithRedirectURL:(NSURL *)redirectURL
                      parentWebView:(WKWebView *)parentWebView
                    parentAuthority:(MSIDAuthority *)parentAuthority
                      correlationId:(NSUUID *)correlationId
                          loginHint:(NSString *)loginHint
                         tokenCache:(id<MSIDCacheAccessor>)tokenCache
               accountMetadataCache:(MSIDAccountMetadataCacheAccessor *)accountMetadataCache
                       oauthFactory:(MSIDOauth2Factory *)oauthFactory
       parentExtraURLQueryParameters:(NSDictionary<NSString *, NSString *> *)parentExtraURLQueryParameters
{
    if ((self = [super init]))
    {
        _redirectURL = redirectURL;
        _parentWebView = parentWebView;
        _parentAuthority = parentAuthority;
        _correlationId = correlationId;
        _loginHint = [loginHint copy];
        _tokenCache = tokenCache;
        _accountMetadataCache = accountMetadataCache;
        _oauthFactory = oauthFactory;
        _parentExtraURLQueryParameters = [parentExtraURLQueryParameters copy];
    }
    return self;
}
#endif

@end
