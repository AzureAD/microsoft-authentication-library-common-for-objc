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


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MSIDRedirectUriValidationResult)
{
    MSIDRedirectUriValidationResultMatched = 0,
    MSIDRedirectUriValidationResultNilOrEmpty,
    MSIDRedirectUriValidationResultSchemeNilOrEmpty,
    MSIDRedirectUriValidationResultHostNilOrEmpty,
    MSIDRedirectUriValidationResultHttpFormatNotSupport,
    MSIDRedirectUriValidationResultMSALFormatBundleIdMismatched,
    MSIDRedirectUriValidationResultMSALFormatHostNilOrEmpty,
    MSIDRedirectUriValidationResultoauth20FormatNotSupport,
    MSIDRedirectUriValidationResultUnknownNotMatched
};


NS_ASSUME_NONNULL_BEGIN

/**
    MSIDRedirectUri is a representation of an OAuth redirect_uri parameter.
    A redirect URI, or reply URL, is the location that the authorization server will send the user to once the app has been successfully authorized, and granted an authorization code or access token.
 */
@interface MSIDRedirectUri : NSObject <NSCopying>

#pragma mark - Getting a redirect_uri parameter

/**
    Redirect URI that will be used for network requests
 */
@property (nonatomic, readonly) NSURL *url;

#pragma mark - Checking redirect uri capabilities

/**
    Indicates if redirect URI can be used to talk to the Microsoft Authenticator application (broker).
    Broker redirect URIs need to follow particular format, e.g. msauth.your.app.bundleId://auth */
@property (nonatomic, readonly) BOOL brokerCapable;

- (nullable instancetype)initWithRedirectUri:(NSURL *)redirectUri
                               brokerCapable:(BOOL)brokerCapable;

+ (nullable NSURL *)defaultNonBrokerRedirectUri:(NSString *)clientId;

+ (nullable NSURL *)defaultBrokerCapableRedirectUri;

+ (MSIDRedirectUriValidationResult)redirectUriIsBrokerCapable:(NSURL *)redirectUri
                                                        error:(NSError * __autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
