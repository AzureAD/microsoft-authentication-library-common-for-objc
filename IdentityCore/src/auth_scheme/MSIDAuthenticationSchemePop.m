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

#import "MSIDAuthenticationSchemePop.h"
#import "MSIDDevicePopManager.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDHttpMethod.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDAuthScheme.h"
#import "NSString+MSIDExtensions.h"

@interface MSIDAuthenticationSchemePop()

@property (nonatomic) NSString *kid;

@end


@implementation MSIDAuthenticationSchemePop

- (instancetype)initWithSchemeParameters:(NSDictionary *)schemeParameters
{
    self = [super init];
    if (self)
    {
        _scheme = MSIDAuthSchemePop;
        _schemeParameters = schemeParameters;
    }

    return self;
}

- (NSString *)kid
{
    if (!_kid)
    {
        NSString *requestConf = [self.schemeParameters msidObjectForKey:MSID_OAUTH2_REQUEST_CONFIRMATION ofClass:[NSString class]];
        if (!requestConf)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to read req_cnf from scheme parameters.");
            return nil;
        }
        
        NSString *kidJwk = [requestConf msidBase64UrlDecode];
        NSData *kidData = [kidJwk dataUsingEncoding:NSUTF8StringEncoding];
        
        NSError *kidReadingError = nil;
        NSDictionary *kidDict = [NSJSONSerialization JSONObjectWithData:kidData options:0 error:&kidReadingError];
        _kid = [kidDict objectForKey:MSID_KID_CACHE_KEY];
        if (!_kid)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError,nil, @"Failed to generate kid from req_cnf, error: %@", MSID_PII_LOG_MASKABLE(kidReadingError));
        }
    }
    
    return _kid;
}

- (MSIDAccessToken *)getAccessTokenFromResponse:(MSIDTokenResponse *)response
{
    MSIDAccessTokenWithAuthScheme *accessToken = [MSIDAccessTokenWithAuthScheme new];
    accessToken.tokenType = response.tokenType;
    accessToken.kid = self.kid;
    return accessToken;
}

- (MSIDCredentialType)credentialType
{
    return MSIDAccessTokenWithAuthSchemeType;
}

- (NSString *)tokenType
{
    return MSIDAuthSchemeParamFromType(self.scheme);
}

- (BOOL)matchAccessTokenKeyThumbprint:(MSIDAccessToken *)accessToken
{
    return accessToken.kid && self.kid && [self.kid isEqualToString:accessToken.kid];
}

@end
