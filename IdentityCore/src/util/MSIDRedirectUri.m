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
                                                        error:(NSError * __autoreleasing *)error
{
    NSURL *defaultRedirectUri = [MSIDRedirectUri defaultBrokerCapableRedirectUri];
    NSString *defaultRedirectUriString = defaultRedirectUri.absoluteString;
    
    if ([NSString msidIsStringNilOrBlank:redirectUri.absoluteString])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI is nil or empty. Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultNilOrEmpty;
    }
    
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
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI uses an unsupported scheme (http(s)://host). Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultHttpFormatNotSupport;
    }
    else if ([redirectUri.host isEqualToString:@"auth"] && [redirectUri.absoluteString hasPrefix:@"msauth"])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI uses MSAL format (msauth.<bundle_id>://auth) but the bundle ID does not match the app’s bundle ID. Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultMSALFormatBundleIdMismatched;
    }
    else if ([redirectUri.absoluteString hasPrefix:@"msauth"])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI uses MSAL scheme (msauth.<bundle_id>) but is missing the required host component \"auth\". Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultMSALFormatHostNilOrEmpty;
    }
    else if ([NSString msidIsStringNilOrBlank:redirectUri.scheme])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI is missing a scheme. Please ensure the redirect URI follows the valid format: %@\nRegister your scheme in Info.plist under CFBundleURLSchemes.", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultSchemeNilOrEmpty;
    }
    else if ([redirectUri.absoluteString isEqualToString:@"urn:ietf:wg:oauth:2.0:oob"])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI 'urn:ietf:wg:oauth:2.0:oob' is not supported. Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultoauth20FormatNotSupport;
    }
    else if ([NSString msidIsStringNilOrBlank:redirectUri.host])
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI is missing a host. Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
        return MSIDRedirectUriValidationResultHostNilOrEmpty;
    }

    MSIDFillAndLogError(error, MSIDErrorInvalidRedirectURI, [NSString stringWithFormat:@"The provided redirect URI is invalid. Please ensure the redirect URI follows the valid format: %@", defaultRedirectUriString], nil);
    return MSIDRedirectUriValidationResultUnknownNotMatched;
}

@end
