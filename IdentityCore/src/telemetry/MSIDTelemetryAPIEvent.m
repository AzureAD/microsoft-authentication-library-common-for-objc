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

#import "MSIDTelemetry.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@implementation MSIDTelemetryAPIEvent

- (void)setCorrelationId:(NSUUID *)correlationId
{
    [self setProperty:MSID_TELEMETRY_KEY_CORRELATION_ID value:[correlationId UUIDString]];
}

- (void)setExtendedExpiresOnSetting:(NSString *)extendedExpiresOnSetting
{
    [self setProperty:MSID_TELEMETRY_KEY_EXTENDED_EXPIRES_ON_SETTING value:extendedExpiresOnSetting];
}

- (void)setUserId:(NSString *)userId
{
    [self setProperty:MSID_TELEMETRY_KEY_USER_ID value:userId];
}

- (void)setClientId:(NSString *)clientId
{
    [self setProperty:MSID_TELEMETRY_KEY_CLIENT_ID value:clientId];
}

- (void)setIsExtendedLifeTimeToken:(NSString *)isExtendedLifeToken
{
    [self setProperty:MSID_TELEMETRY_KEY_IS_EXTENED_LIFE_TIME_TOKEN value:isExtendedLifeToken];
}

- (void)setErrorDescription:(NSString *)errorDescription
{
    [self setProperty:MSID_TELEMETRY_KEY_ERROR_DESCRIPTION value:errorDescription];
}

- (void)setErrorDomain:(NSString *)errorDomain
{
    [self setProperty:MSID_TELEMETRY_KEY_ERROR_DOMAIN value:errorDomain];
}

- (void)setAuthorityValidationStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_AUTHORITY_VALIDATION_STATUS value:status];
}

- (void)setAuthority:(NSString *)authority
{
    [self setProperty:MSID_TELEMETRY_KEY_AUTHORITY value:authority];
}

- (void)setAuthorityType:(NSString *)authorityType
{
    [self setProperty:MSID_TELEMETRY_KEY_AUTHORITY_TYPE value:authorityType];
}

- (void)setGrantType:(NSString *)grantType
{
    [self setProperty:MSID_TELEMETRY_KEY_GRANT_TYPE value:grantType];
}

- (void)setAPIStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_API_STATUS value:status];
}

- (void)setApiId:(NSString *)apiId
{
    [self setProperty:MSID_TELEMETRY_KEY_API_ID value:apiId];
}

- (void)setWebviewType:(NSString *)webviewType
{
    [self setProperty:MSID_TELEMETRY_KEY_WEBVIEW_TYPE value:webviewType];
}

@end
