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
#import "MSIDConstants.h"
#import "MSIDFlightManager.h"

@interface MSIDBrowserNativeMessageGetTokenResponse()

@property (nonatomic) MSIDBrokerOperationTokenResponse *operationTokenResponse;
@property (nonatomic) MSIDTokenResult *tokenResult;

@end

static NSDictionary *MSIDBrowserNativeMessageGetTokenResponseSanitizedDictionary(NSDictionary *tokenResponseJson)
{
    NSArray<NSString *> *allowedKeys = @[MSID_OAUTH2_ACCESS_TOKEN,
                                         MSID_OAUTH2_ID_TOKEN,
                                         MSID_OAUTH2_TOKEN_TYPE,
                                         MSID_OAUTH2_EXPIRES_IN,
                                         MSID_OAUTH2_EXPIRES_ON,
                                         MSID_OAUTH2_SCOPE,
                                         MSID_OAUTH2_REQUEST_CONFIRMATION];
    NSMutableDictionary *sanitizedResponse = [NSMutableDictionary new];
    for (NSString *key in allowedKeys)
    {
        id value = tokenResponseJson[key];
        if (value)
        {
            sanitizedResponse[key] = value;
        }
    }

    return sanitizedResponse;
}

@implementation MSIDBrowserNativeMessageGetTokenResponse

- (instancetype)initWithTokenResponse:(MSIDBrokerOperationTokenResponse *)operationTokenResponse
{
    if (!operationTokenResponse)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetToken' response: operation token response is nil.");
        return nil;
    }

    self = [super initWithDeviceInfo:operationTokenResponse.deviceInfo];
    if (self)
    {
        _operationTokenResponse = operationTokenResponse;
    }

    return self;
}

// Designated initializer: constructs the response from a single canonical token result.
- (instancetype)initWithTokenResult:(MSIDTokenResult *)result
                              state:(NSString *)state
          fallbackRequestAccountUpn:(NSString *)fallbackRequestAccountUpn
{
    if (!result.accessToken && !result.tokenResponse)
    {
        MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create browser 'GetToken' response: result has no access token or token response.");
        return nil;
    }

    self = [super initWithDeviceInfo:nil];
    if (self)
    {
        _tokenResult = result;
        _state = state;
        _requestAccountUpn = fallbackRequestAccountUpn;
    }

    return self;
}

#pragma mark - MSIDJsonSerializable

// Deserialization is intentionally unsupported for this response (it is only ever produced, never
// parsed). The initializer throws instead of delegating to the designated initializer, so the
// convenience-initializer diagnostic is suppressed for this false positive.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithJSONDictionary:(NSDictionary *)json error:(NSError *__autoreleasing*)error
{
    @throw MSIDException(MSIDGenericException, @"Not implemented.", nil);
}
#pragma clang diagnostic pop

// Shapes the GetToken payload from a single canonical token result. Base OAuth fields come from the
// server token response when present (wire parity with a freshly redeemed result); otherwise they are
// derived from the cached access token (access-token cache hit). Optional fields are omitted when
// blank/nil so downstream required-field validation can fail cleanly rather than receiving empty
// placeholder values. The account, state, and properties blocks are shared across both sources.
- (NSDictionary *)jsonDictionary
{
    BOOL sanitizeResponse = [MSIDFlightManager.sharedInstance boolForKey:MSID_FLIGHT_ENABLE_BROWSER_GETTOKEN_RESPONSE_SANITIZATION];

    if (self.operationTokenResponse)
    {
        MSIDTokenResponse *tokenResponse = self.operationTokenResponse.tokenResponse;
        NSDictionary *tokenResponseJson = [tokenResponse jsonDictionary];
        if (!tokenResponseJson)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create token json response.");
            return nil;
        }

        NSMutableDictionary *response = sanitizeResponse
        ? [MSIDBrowserNativeMessageGetTokenResponseSanitizedDictionary(tokenResponseJson) mutableCopy]
        : [tokenResponseJson mutableCopy];

        NSMutableDictionary *accountJson = [NSMutableDictionary new];
        accountJson[@"userName"] = tokenResponse.accountUpn ?: self.requestAccountUpn;
        accountJson[@"id"] = tokenResponse.accountIdentifier;

        response[@"account"] = accountJson;
        response[@"state"] = self.state;

        NSMutableDictionary *propertiesJson = [NSMutableDictionary new];
        propertiesJson[@"UPN"] = accountJson[@"userName"];
        propertiesJson[@"MATS"] = [self.matsReport jsonString];
        response[@"properties"] = propertiesJson;

        return response;
    }

    MSIDTokenResponse *tokenResponse = self.tokenResult.tokenResponse;
    MSIDAccessToken *accessToken = self.tokenResult.accessToken;

    // 1) Base OAuth fields.
    NSMutableDictionary *response;
    if (tokenResponse)
    {
        NSDictionary *tokenResponseJson = [tokenResponse jsonDictionary];
        if (!tokenResponseJson)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to create token json response.");
            return nil;
        }

        response = sanitizeResponse
        ? [MSIDBrowserNativeMessageGetTokenResponseSanitizedDictionary(tokenResponseJson) mutableCopy]
        : [tokenResponseJson mutableCopy];
    }
    else
    {
        response = [NSMutableDictionary new];
        if (![NSString msidIsStringNilOrBlank:accessToken.accessToken])
        {
            response[@"access_token"] = accessToken.accessToken;
        }

        if (![NSString msidIsStringNilOrBlank:accessToken.tokenType])
        {
            response[@"token_type"] = accessToken.tokenType;
        }

        if (![NSString msidIsStringNilOrBlank:self.tokenResult.rawIdToken])
        {
            response[@"id_token"] = self.tokenResult.rawIdToken;
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
    }

    // 2) Account block. Identifiers are resolved from whichever source populated the result.
    NSString *userName = tokenResponse ? tokenResponse.accountUpn : self.tokenResult.account.username;
    if ([NSString msidIsStringNilOrBlank:userName])
    {
        userName = self.requestAccountUpn;
    }

    NSString *accountId = tokenResponse ? tokenResponse.accountIdentifier
                                        : self.tokenResult.account.accountIdentifier.homeAccountId;

    NSMutableDictionary *account = [NSMutableDictionary new];
    if (![NSString msidIsStringNilOrBlank:accountId])
    {
        account[@"id"] = accountId;
    }

    if (![NSString msidIsStringNilOrBlank:userName])
    {
        account[@"userName"] = userName;
    }

    if (account.count)
    {
        response[@"account"] = account;
    }

    // 3) State echo.
    if (![NSString msidIsStringNilOrBlank:self.state])
    {
        response[@"state"] = self.state;
    }

    // 4) Properties: UPN is always echoed when known; MATS is added only when a report exists.
    NSMutableDictionary *propertiesJson = [NSMutableDictionary new];
    // TODO: once ests follow the latest protocol, this should be removed. Account ID should be read from accountJson.
    if (![NSString msidIsStringNilOrBlank:userName])
    {
        propertiesJson[@"UPN"] = userName;
    }

    NSString *matsReportJson = [self.matsReport jsonString];
    if (matsReportJson)
    {
        propertiesJson[@"MATS"] = matsReportJson;
    }

    if (propertiesJson.count)
    {
        response[@"properties"] = propertiesJson;
    }

    return response;
}

@end
