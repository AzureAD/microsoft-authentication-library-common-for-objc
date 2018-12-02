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
#import "MSIDTelemetry+Internal.h"

@implementation MSIDRequestParameters

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        [self initDefaultSettings];
    }

    return self;
}

- (instancetype)initWithConfiguration:(MSIDConfiguration *)configuration
                           oidcScopes:(NSOrderedSet<NSString *> *)oidScopes
                        correlationId:(NSUUID *)correlationId
                       telemetryApiId:(NSString *)telemetryApiId
                                error:(NSError **)error
{
    self = [super init];

    if (self)
    {
        [self initDefaultSettings];

        _configuration = configuration;

        _correlationId = correlationId ?: [NSUUID new];
        _telemetryApiId = telemetryApiId;

        if ([configuration.scopes intersectsOrderedSet:oidScopes])
        {
            NSString *errorMessage = [NSString stringWithFormat:@"%@ are reserved scopes and may not be specified in the acquire token call.", oidScopes];
            MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, errorMessage, correlationId);
            return nil;
        }

        if (oidScopes) _oidcScope = [oidScopes msidToString];
    }

    return self;
}

- (void)initDefaultSettings
{
    _tokenExpirationBuffer = 300;
    _oidcScope = MSID_OAUTH2_SCOPE_OPENID_VALUE;
    _extendedLifetimeEnabled = NO;
    _logComponent = [MSIDVersion sdkName];
    _telemetryRequestId = [[MSIDTelemetry sharedInstance] generateRequestId];

    NSDictionary *metadata = [[NSBundle mainBundle] infoDictionary];

    NSString *appName = metadata[@"CFBundleDisplayName"];

    if (!appName)
    {
        appName = metadata[@"CFBundleName"];
    }

    NSString *appVer = metadata[@"CFBundleShortVersionString"];

    _appRequestMetadata = @{MSID_VERSION_KEY: [MSIDVersion sdkVersion],
                            MSID_APP_NAME_KEY: appName ? appName : @"",
                            MSID_APP_VER_KEY: appVer ? appVer : @""};
}

#pragma mark - Helpers

- (NSURL *)tokenEndpoint
{
    NSURLComponents *tokenEndpoint = [NSURLComponents componentsWithURL:self.configuration.authority.metadata.tokenEndpoint resolvingAgainstBaseURL:NO];
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

    // TODO: this is a problem, we replace authority and wipe metadata with it
    // tokenEndpointMethod will crash because of that
    NSURL *cloudAuthority = [self.configuration.authority.url msidAuthorityWithCloudInstanceHostname:cloudHostName];
    _configuration.authority = [MSIDAuthorityFactory authorityFromUrl:cloudAuthority context:self error:nil];
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
    NSMutableOrderedSet *requestScopes = [[NSOrderedSet msidOrderedSetFromString:self.configuration.target] mutableCopy];
    NSOrderedSet *oidcScopes = [NSOrderedSet msidOrderedSetFromString:self.oidcScope];

    if (oidcScopes)
    {
        [requestScopes unionOrderedSet:oidcScopes];
    }
    [requestScopes removeObject:self.configuration.clientId];
    return [requestScopes msidToString];
}

#pragma mark - Validate

- (BOOL)validateParametersWithError:(NSError **)error
{
    if (!self.configuration.authority)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Missing authority parameter", self.correlationId);
        return NO;
    }

    if (!self.configuration.redirectUri)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Missing redirectUri parameter", self.correlationId);
        return NO;
    }

    if (!self.configuration.clientId)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Missing clientId parameter", self.correlationId);
        return NO;
    }

    if (!self.configuration.target)
    {
        MSIDFillAndLogError(error, MSIDErrorInvalidDeveloperParameter, @"Missing target parameter", self.correlationId);
        return NO;
    }

    return YES;
}

@end
