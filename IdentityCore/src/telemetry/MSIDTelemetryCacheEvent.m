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
#import "MSIDTelemetryCacheEvent.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDRefreshToken.h"

@implementation MSIDTelemetryCacheEvent

- (id)initWithName:(NSString *)eventName
         requestId:(NSString *)requestId
     correlationId:(NSUUID *)correlationId
{
    if (!(self = [super initWithName:eventName requestId:requestId correlationId:correlationId]))
    {
        return nil;
    }
    
    [self setProperty:MSID_TELEMETRY_KEY_IS_FRT value:@""];
    [self setProperty:MSID_TELEMETRY_KEY_IS_MRRT value:@""];
    [self setProperty:MSID_TELEMETRY_KEY_IS_RT value:@""];
    
    return self;
}

- (void)setTokenType:(MSIDTokenType)tokenType
{
    switch (tokenType)
    {
        case MSIDTokenTypeAccessToken:
            [self setProperty:MSID_TELEMETRY_KEY_TOKEN_TYPE value:MSID_TELEMETRY_VALUE_ACCESS_TOKEN];
            break;
            
        case MSIDTokenTypeRefreshToken:
            [self setProperty:MSID_TELEMETRY_KEY_TOKEN_TYPE value:MSID_TELEMETRY_VALUE_REFRESH_TOKEN];
            break;
            
        case MSIDTokenTypeLegacyADFSToken:
            [self setProperty:MSID_TELEMETRY_KEY_TOKEN_TYPE value:MSID_TELEMETRY_VALUE_ADFS_TOKEN];
            break;
            
        default:
            break;
    }
}

- (void)setStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_RESULT_STATUS value:status];
}

- (void)setIsRT:(NSString *)isRT
{
    [self setProperty:MSID_TELEMETRY_KEY_IS_RT value:isRT];
}

- (void)setIsMRRT:(NSString *)isMRRT
{
    [self setProperty:MSID_TELEMETRY_KEY_IS_MRRT value:isMRRT];
}

- (void)setIsFRT:(NSString *)isFRT
{
    [self setProperty:MSID_TELEMETRY_KEY_IS_FRT value:isFRT];
}

- (void)setRTStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_RT_STATUS value:status];
}

- (void)setMRRTStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_MRRT_STATUS value:status];
}

- (void)setFRTStatus:(NSString *)status
{
    [self setProperty:MSID_TELEMETRY_KEY_FRT_STATUS value:status];
}

- (void)setSpeInfo:(NSString *)speInfo
{
    [self setProperty:MSID_TELEMETRY_KEY_SPE_INFO value:speInfo];
}

- (void)setToken:(MSIDBaseToken *)token
{
    [self setTokenType:token.tokenType];
    [self setSpeInfo:token.additionalInfo[MSID_TELEMETRY_KEY_SPE_INFO]];
    
    if (token.tokenType == MSIDTokenTypeRefreshToken)
    {
        MSIDRefreshToken *refresToken = (MSIDRefreshToken *)token;
        [self setIsFRT:[NSString msidIsStringNilOrBlank:refresToken.familyId] ? MSID_TELEMETRY_VALUE_NO : MSID_TELEMETRY_VALUE_YES];
    }
}

- (void)setCacheWipeApp:(NSString *)wipeApp
{
    [self setProperty:MSID_TELEMETRY_KEY_WIPE_APP value:wipeApp];
}

- (void)setCacheWipeTime:(NSString *)wipeTime
{
    [self setProperty:MSID_TELEMETRY_KEY_WIPE_TIME value:wipeTime];
}

@end
