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

#import "MSIDRequestParameters.h"
#import "MSIDVersion.h"
#import "MSIDConstants.h"
#import "MSIDAuthorityFactory.h"
#import "MSIDAuthority.h"
#import "NSOrderedSet+MSIDExtensions.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDConfiguration.h"

@implementation MSIDRequestParameters

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [self initDefaultAppMetadata];
    }

    return self;
}

- (void)initDefaultAppMetadata
{
    NSDictionary *metadata = [[NSBundle mainBundle] infoDictionary];

    NSString *appName = metadata[@"CFBundleDisplayName"];

    if (!appName)
    {
        appName = metadata[@"CFBundleName"];
    }

    NSString *appVer = metadata[@"CFBundleShortVersionString"];

    self.appRequestMetadata = @{MSID_VERSION_KEY: [MSIDVersion sdkVersion],
                                MSID_APP_NAME_KEY: appName ? appName : @"",
                                MSID_APP_VER_KEY: appVer ? appVer : @""};
}

#pragma mark - Helpers

- (NSURL *)tokenEndpoint
{
    NSURLComponents *tokenEndpoint = [NSURLComponents componentsWithURL:self.authority.metadata.tokenEndpoint resolvingAgainstBaseURL:NO];

    if (self.cloudAuthority)
    {
        tokenEndpoint.host = self.cloudAuthority.environment;
    }

    NSMutableDictionary *endpointQPs = [[NSDictionary msidDictionaryFromWWWFormURLEncodedString:tokenEndpoint.percentEncodedQuery] mutableCopy];

    if (!endpointQPs)
    {
        endpointQPs = [NSMutableDictionary dictionary];
    }

    if (self.sliceParameters)
    {
        [endpointQPs addEntriesFromDictionary:self.sliceParameters];
    }

    tokenEndpoint.query = [endpointQPs msidWWWFormURLEncode];
    return tokenEndpoint.URL;
}

- (void)setCloudAuthorityWithCloudHostName:(NSString *)cloudHostName
{
    if ([NSString msidIsStringNilOrBlank:cloudHostName]) return;

    NSURL *cloudAuthority = [self.authority.url msidAuthorityWithCloudInstanceHostname:cloudHostName];
    _cloudAuthority = [[MSIDAuthorityFactory new] authorityFromUrl:cloudAuthority context:self error:nil];
}

- (BOOL)setClaimsFromJSON:(NSString *)claims error:(NSError **)error
{
    NSString *trimmedClaims = claims.msidTrimmedString;

    if ([NSString msidIsStringNilOrBlank:trimmedClaims]) return YES;

    NSDictionary *decodedDictionary = trimmedClaims.msidJson;
    if (!decodedDictionary)
    {
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInvalidDeveloperParameter, @"Claims is not proper JSON. Please make sure it is correct JSON claims parameter.", nil, nil, nil, self.correlationId, nil);
        }
        return NO;
    }

    self.claims = decodedDictionary;
    return YES;
}

- (NSString *)allTokenRequestScopes
{
    NSMutableOrderedSet *requestScopes = [[NSOrderedSet msidOrderedSetFromString:self.target] mutableCopy];
    NSOrderedSet *oidcScopes = [NSOrderedSet msidOrderedSetFromString:self.oidcScope];

    if (oidcScopes)
    {
        [requestScopes unionOrderedSet:oidcScopes];
    }
    [requestScopes removeObject:self.clientId];
    return [requestScopes msidToString];
}

- (MSIDConfiguration *)msidConfiguration
{
    // TODO: don't create config every time
    MSIDAuthority *authority = self.cloudAuthority ? self.cloudAuthority : self.authority;

    MSIDConfiguration *config = [[MSIDConfiguration alloc] initWithAuthority:authority
                                                                 redirectUri:self.redirectUri
                                                                    clientId:self.clientId
                                                                      target:self.target];

    return config;
}

#pragma mark - Validate

- (BOOL)validateParametersWithError:(NSError **)error
{
    // TODO: validate
    return NO;
}

@end
