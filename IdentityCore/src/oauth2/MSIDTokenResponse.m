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

#import "MSIDTokenResponse.h"
#import "MSIDHelpers.h"
#import "MSIDRefreshableToken.h"
#import "MSIDBaseToken.h"
#import "NSDictionary+MSIDExtensions.h"
#import "MSIDTokenResponse+Internal.h"

@implementation MSIDTokenResponse

- (instancetype)initWithAccessToken:(NSString *)accessToken
                       refreshToken:(NSString *)refreshToken
                          expiresIn:(NSInteger)expiresIn
                          tokenType:(NSString *)tokenType
                              scope:(NSString *)scope
                              state:(NSString *)state
                            idToken:(NSString *)idToken
               additionalServerInfo:(NSDictionary *)additionalServerInfo
                              error:(NSString *)error
                   errorDescription:(NSString *)errorDescription
{
    self = [super init];
    if (self)
    {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _expiresIn = expiresIn;
        _tokenType = tokenType;
        _scope = scope;
        _state = state;
        _idToken = idToken;
        self.additionalServerInfo = additionalServerInfo;
        _error = error;
        _errorDescription = errorDescription;
        
        [self initIdTokenObjectIfPossible];
    }
    
    return self;
}

- (instancetype)initWithJSONDictionary:(NSDictionary *)json
                          refreshToken:(MSIDBaseToken<MSIDRefreshableToken> *)token
                                 error:(NSError **)error
{
    self = [self initWithJSONDictionary:json error:error];
    if (self)
    {
        if (token && [NSString msidIsStringNilOrBlank:_refreshToken])
        {
            _refreshToken = token.refreshToken;
        }
    }

    return self;
}

- (NSDate *)expiryDate
{
    NSInteger expiresIn = self.expiresIn;

    if (!expiresIn) return nil;

    return [NSDate dateWithTimeIntervalSinceNow:expiresIn];
}

- (BOOL)isMultiResource
{
    return YES;
}

- (NSString *)target
{
    return self.scope;
}

- (MSIDAccountType)accountType
{
    return MSIDAccountTypeOther;
}

- (MSIDErrorCode)oauthErrorCode
{
    return MSIDErrorCodeForOAuthError(self.error, MSIDErrorServerOauth);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Token response: access token %@, refresh token %@, scope %@, state %@, id token %@, error %@, error description %@", _PII_NULLIFY(self.accessToken), _PII_NULLIFY(self.refreshToken), self.scope, self.state, _PII_NULLIFY(self.idToken), self.error, self.errorDescription];
}

#pragma mark - Protected

- (BOOL)initIdToken:(NSError **)error
{
    if (![NSString msidIsStringNilOrBlank:self.idToken])
    {
        self.idTokenObj = [[MSIDIdTokenClaims alloc] initWithRawIdToken:self.idToken error:error];
        return self.idTokenObj != nil;
    }
    return YES;
}

- (void)setAdditionalServerInfo:(NSDictionary *)additionalServerInfo
{
    NSArray *knownFields = @[MSID_OAUTH2_ERROR,
                             MSID_OAUTH2_ERROR_DESCRIPTION,
                             MSID_OAUTH2_ACCESS_TOKEN,
                             MSID_OAUTH2_TOKEN_TYPE,
                             MSID_OAUTH2_REFRESH_TOKEN,
                             MSID_OAUTH2_SCOPE,
                             MSID_OAUTH2_STATE,
                             MSID_OAUTH2_ID_TOKEN,
                             MSID_OAUTH2_EXPIRES_IN];
    
    NSDictionary *additionalInfo = [additionalServerInfo dictionaryByRemovingFields:knownFields];
    _additionalServerInfo = additionalInfo.count > 0 ? additionalInfo : nil;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_ACCESS_TOKEN required:YES error:error]) return nil;
        NSString *accessToken = json[MSID_OAUTH2_ACCESS_TOKEN];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_REFRESH_TOKEN required:NO error:error]) return nil;
        NSString *refreshToken = json[MSID_OAUTH2_REFRESH_TOKEN];
        
        if (![json msidAssertType:NSNumber.class ofKey:MSID_OAUTH2_EXPIRES_IN required:NO error:error]) return nil;
        NSInteger expiresIn = json[MSID_OAUTH2_EXPIRES_IN] ? [json[MSID_OAUTH2_EXPIRES_IN] integerValue] : 0;
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_TOKEN_TYPE required:YES error:error]) return nil;
        NSString *tokenType = json[MSID_OAUTH2_TOKEN_TYPE];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_SCOPE required:NO error:error]) return nil;
        NSString *scope = json[MSID_OAUTH2_SCOPE];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_STATE required:NO error:error]) return nil;
        NSString *state = json[MSID_OAUTH2_STATE];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_ID_TOKEN required:NO error:error]) return nil;
        NSString *idToken = json[MSID_OAUTH2_ID_TOKEN];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_ERROR required:NO error:error]) return nil;
        NSString *oauthError = json[MSID_OAUTH2_ERROR];
        
        if (![json msidAssertType:NSString.class ofKey:MSID_OAUTH2_ERROR_DESCRIPTION required:NO error:error]) return nil;
        NSString *oauthErrorDescription = json[MSID_OAUTH2_ERROR_DESCRIPTION];
        
        return [self initWithAccessToken:accessToken
                            refreshToken:refreshToken
                               expiresIn:expiresIn
                               tokenType:tokenType
                                   scope:scope
                                   state:state
                                 idToken:idToken
                    additionalServerInfo:json
                                   error:oauthError
                        errorDescription:oauthErrorDescription];
    }
    
    return self;
}

- (NSDictionary *)jsonDictionary
{
    NSMutableDictionary *json = [NSMutableDictionary new];
    if (self.additionalServerInfo) [json addEntriesFromDictionary:self.additionalServerInfo];
    
    json[MSID_OAUTH2_ACCESS_TOKEN] = self.accessToken;
    json[MSID_OAUTH2_REFRESH_TOKEN] = self.refreshToken;
    json[MSID_OAUTH2_EXPIRES_IN] = @(self.expiresIn);
    json[MSID_OAUTH2_TOKEN_TYPE] = self.tokenType;
    json[MSID_OAUTH2_SCOPE] = self.scope;
    json[MSID_OAUTH2_STATE] = self.state;
    json[MSID_OAUTH2_ID_TOKEN] = self.idToken;
    json[MSID_OAUTH2_ERROR] = self.error;
    json[MSID_OAUTH2_ERROR_DESCRIPTION] = self.errorDescription;
    
    return json;
}

#pragma mark - Private

- (void)initIdTokenObjectIfPossible
{
    NSError *localError;
    [self initIdToken:&localError];
    
    if (localError)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to init id token wrapper, error: %@", MSID_PII_LOG_MASKABLE(localError));
    }
}

@end
