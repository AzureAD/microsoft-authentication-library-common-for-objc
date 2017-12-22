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

#import "MSIDDefaultTokenCacheFormat.h"
#import "MSIDJsonSerializer.h"
#import "MSIDAccount.h"
#import "MSIDTokenCacheKey.h"
#import "MSIDToken.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDTelemetryCacheEvent.h"


@interface MSIDDefaultTokenCacheFormat()
{
    id<MSIDTokenCacheDataSource> _dataSource;
    MSIDJsonSerializer *_serializer;
}
@end

@implementation MSIDDefaultTokenCacheFormat

#pragma mark - Init
- (instancetype)initWithDataSource:(id<MSIDTokenCacheDataSource>)dataSource
{
    self = [super init];
    
    if (self)
    {
        _dataSource = dataSource;
        _serializer = [[MSIDJsonSerializer alloc] init];
    }
    
    return self;
}


- (MSIDToken *)getATForAccount:(MSIDAccount *)account requestParams:(MSIDRequestParameters *)parameters context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return nil;
}

- (NSArray<MSIDToken *> *)getAllSharedClientRTsWithParams:(MSIDRequestParameters *)parameters context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return nil;
}

- (MSIDToken *)getSharedRTForAccount:(MSIDAccount *)account requestParams:(MSIDRequestParameters *)parameters context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return nil;
}

- (BOOL)removeRTForAccount:(MSIDAccount *)account token:(MSIDToken *)token context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return nil;
}

- (BOOL)saveAccessToken:(MSIDToken *)token account:(MSIDAccount *)account requestParams:(MSIDRequestParameters *)parameters context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return NO;
}

- (BOOL)saveSharedRTForAccount:(MSIDAccount *)account refreshToken:(MSIDToken *)refreshToken context:(id<MSIDRequestContext>)context error:(NSError *__autoreleasing *)error {
    return NO;
}

#pragma mark - Telemetry helpers

- (void)stopTelemetryEvent:(MSIDTelemetryCacheEvent *)event
                 withToken:(MSIDToken *)token
                   success:(BOOL)success
                   context:(id<MSIDRequestContext>)context
{
    [event setStatus:success ? MSID_TELEMETRY_VALUE_SUCCEEDED : MSID_TELEMETRY_VALUE_FAILED];
    if (token)
    {
        [event setToken:token];
    }
    [[MSIDTelemetry sharedInstance] stopEvent:[context telemetryRequestId]
                                        event:event];
}

@end
