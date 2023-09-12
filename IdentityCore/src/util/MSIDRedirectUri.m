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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import "MSIDRedirectUri.h"

@implementation MSIDRedirectUri

- (instancetype)initWithRedirectUri:(NSURL *)redirectUri
                      brokerCapable:(BOOL)brokerCapable
{
    self = [super init];

    if (self)
    {
        _url = redirectUri;
        _brokerCapable = brokerCapable;
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSURL *url = [_url copyWithZone:zone];
    MSIDRedirectUri *redirectUri = [[MSIDRedirectUri alloc] initWithRedirectUri:url brokerCapable:_brokerCapable];
    return redirectUri;
}

#pragma mark - Helpers

+ (NSURL *)defaultNonBrokerRedirectUri:(NSString *)clientId
{
    if ([NSString msidIsStringNilOrBlank:clientId])
    {
        return nil;
    }
    
    NSString *redirectUri = [NSString stringWithFormat:@"msal%@://auth", clientId];
    return [NSURL URLWithString:redirectUri];
}

+ (NSURL *)defaultBrokerCapableRedirectUri
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSString *redirectUri = [NSString stringWithFormat:@"msauth.%@://auth", bundleID];
    return [NSURL URLWithString:redirectUri];
}

+ (MSIDRedirectUriValidationResult)redirectUriIsBrokerCapable:(NSURL *)redirectUri
{
    if ([NSString msidIsStringNilOrBlank:redirectUri.absoluteString])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is nil or empty");
        return MSIDRedirectUriValidationResultNilOrEmpty;
    }
    
    NSURL *defaultRedirectUri = [MSIDRedirectUri defaultBrokerCapableRedirectUri];
    
    // Check default MSAL format
    if ([defaultRedirectUri isEqual:redirectUri])
    {
        return MSIDRedirectUriValidationResultMatched;
    }
    
    // Check default ADAL format
    if ([redirectUri.host isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]
        && redirectUri.scheme.length > 0)
    {
        return MSIDRedirectUriValidationResultMatched;
    }
    
    // Add extra validation on why redirect_uri is not capable
    if ([redirectUri.scheme isEqualToString:@"http"] || [redirectUri.scheme isEqualToString:@"https"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is (http(s)://host), and is not supported");
        return MSIDRedirectUriValidationResultHttpFormatNotSupport;
    }
    else if ([redirectUri.host isEqualToString:@"auth"] && [redirectUri.absoluteString hasPrefix:@"msauth"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is MSAL format, but bundle_id could mismatch");
        return MSIDRedirectUriValidationResultMSALFormatBundleIdMismatched;
    }
    else if ([redirectUri.absoluteString hasPrefix:@"msauth"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is as (msauth.bundle_id), and auth host is missing");
        return MSIDRedirectUriValidationResultMSALFormatHostNilOrEmpty;
    }
    else if ([NSString msidIsStringNilOrBlank:redirectUri.scheme])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is as (://host) without schema");
        return MSIDRedirectUriValidationResultSchemeNilOrEmpty;
    }
    else if ([redirectUri.absoluteString isEqualToString:@"urn:ietf:wg:oauth:2.0:oob"])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is urn:ietf:wg:oauth:2.0:oob, and not supported");
        return MSIDRedirectUriValidationResultoauth20FormatNotSupport;
    }
    else if ([NSString msidIsStringNilOrBlank:redirectUri.host])
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelVerbose, nil, @"MSIDRedirectUri validation: redirect_uri is as (scheme://) without host");
        return MSIDRedirectUriValidationResultHostNilOrEmpty;
    }

    return MSIDRedirectUriValidationResultUnknownNotMatched;
}

@end
