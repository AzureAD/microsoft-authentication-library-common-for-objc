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


#import "MSIDBrowserNativeMessageGetTokenResponse.h"
#import "MSIDBrokerOperationTokenResponse.h"
#import "MSIDTokenResponse.h"
#import "MSIDOAuth2Constants.h"
#import "MSIDBrokerOperationBrowserNativeMessageMATSReport.h"
#import "MSIDTokenResult.h"
#import "MSIDAccessToken.h"
#import "MSIDAccount.h"
#import "MSIDAccountIdentifier.h"
#import "NSString+MSIDExtensions.h"
#import "NSOrderedSet+MSIDExtensions.h"

@interface MSIDBrowserNativeMessageGetTokenResponse()

@property (nonatomic) MSIDBrokerOperationTokenResponse *operationTokenResponse;
@property (nonatomic) MSIDTokenResult *cachedTokenResult;

@end

@implementation MSIDBrowserNativeMessageGetTokenResponse

- (instancetype)initWithTokenResponse:(MSIDBrokerOperationTokenResponse *)operationTokenResponse
{
    self = [super initWithDeviceInfo:operationTokenResponse.deviceInfo];
    if (self)
    {
        if (!operationTokenResponse)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetToken' response: operation token response is nil.");
            return nil;
        }
        
        _operationTokenResponse = operationTokenResponse;
    }
    
    return self;
}

- (instancetype)initWithTokenResponse:(MSIDBrokerOperationTokenResponse *)operationTokenResponse
                                state:(NSString *)state
            fallbackRequestAccountUpn:(NSString *)fallbackRequestAccountUpn
{
    self = [self initWithTokenResponse:operationTokenResponse];
    if (self)
    {
        _state = state;
        _requestAccountUpn = fallbackRequestAccountUpn;
    }

    return self;
}

- (instancetype)initWithCachedTokenResult:(MSIDTokenResult *)tokenResult
                                    state:(NSString *)state
                fallbackRequestAccountUpn:(NSString *)fallbackRequestAccountUpn
{
    if (!tokenResult.accessToken)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetToken' response: cached result has no access token.");
        return nil;
    }

    self = [super initWithDeviceInfo:nil];
    if (self)
    {
        _cachedTokenResult = tokenResult;
        _state = state;
        _requestAccountUpn = fallbackRequestAccountUpn;
    }

    return self;
}

#pragma mark - MSIDJsonSerializable

- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
}

- (NSDictionary *)jsonDictionary
{
    // Cache hit (no fresh server token response): shape the payload from the cached result directly.
    if (self.cachedTokenResult)
    {
        return [self cachedResultJsonDictionary];
    }

    __auto_type tokenResponse = self.operationTokenResponse.tokenResponse;
    NSMutableDictionary *response = [[tokenResponse jsonDictionary] mutableCopy];
    if (!response)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create token json response.");
        return nil;
    }
    
    __auto_type accountJson = [NSMutableDictionary new];
    accountJson[@"userName"] = tokenResponse.accountUpn ?: self.requestAccountUpn;
    accountJson[@"id"] = tokenResponse.accountIdentifier;
    
    response[@"account"] = accountJson;
    response[@"state"] = self.state;
    
    __auto_type propertiesJson = [NSMutableDictionary new];
    // TODO: once ests follow the latest protocol, this should be removed. Account ID should be read from accountJson.
    propertiesJson[@"UPN"] = accountJson[@"userName"];
    // Add MATS report as JSON string
    propertiesJson[@"MATS"] = [self.matsReport jsonString];
    
    response[@"properties"] = propertiesJson;
    
    return response;
}

// Shapes the GetToken payload from a cached token result (access token cache hit). Optional fields
// are omitted when blank/nil so downstream required-field validation can fail cleanly rather than
// receiving empty placeholder values.
- (NSDictionary *)cachedResultJsonDictionary
{
    MSIDAccessToken *accessToken = self.cachedTokenResult.accessToken;
    if (!accessToken)
    {
        return nil;
    }

    NSMutableDictionary *response = [NSMutableDictionary new];
    if (![NSString msidIsStringNilOrBlank:accessToken.accessToken])
    {
        response[@"access_token"] = accessToken.accessToken;
    }

    if (![NSString msidIsStringNilOrBlank:accessToken.tokenType])
    {
        response[@"token_type"] = accessToken.tokenType;
    }

    if (![NSString msidIsStringNilOrBlank:self.cachedTokenResult.rawIdToken])
    {
        response[@"id_token"] = self.cachedTokenResult.rawIdToken;
    }

    NSString *scope = [accessToken.scopes msidToString];
    if (![NSString msidIsStringNilOrBlank:scope])
    {
        response[@"scope"] = scope;
    }

    if (accessToken.expiresOn)
    {
        response[@"expires_on"] = [@((long long)[accessToken.expiresOn timeIntervalSince1970]) stringValue];
        response[@"expires_in"] = [@((long long)MAX(0, (NSInteger)[accessToken.expiresOn timeIntervalSinceNow])) stringValue];
    }

    NSMutableDictionary *account = [NSMutableDictionary new];
    NSString *homeAccountId = self.cachedTokenResult.account.accountIdentifier.homeAccountId;
    if (![NSString msidIsStringNilOrBlank:homeAccountId])
    {
        account[@"id"] = homeAccountId;
    }

    NSString *username = self.cachedTokenResult.account.username;
    if ([NSString msidIsStringNilOrBlank:username])
    {
        username = self.requestAccountUpn;
    }

    if (![NSString msidIsStringNilOrBlank:username])
    {
        account[@"userName"] = username;
    }

    if (account.count)
    {
        response[@"account"] = account;
    }

    if (![NSString msidIsStringNilOrBlank:self.state])
    {
        response[@"state"] = self.state;
    }

    return response;
}

@end
