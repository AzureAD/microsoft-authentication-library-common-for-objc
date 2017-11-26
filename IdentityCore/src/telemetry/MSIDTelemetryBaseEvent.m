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

#import "MSIDTelemetryBaseEvent.h"
#import "NSDate+MSIDExtensions.h"
#import "NSMutableDictionary+MSIDExtensions.h"
#import "MSIDTelemetryPiiRules.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDVersion.h"

@implementation MSIDTelemetryBaseEvent

@synthesize propertyMap = _propertyMap;
@synthesize errorInEvent = _errorInEvent;

- (instancetype)initWithName:(NSString *)eventName
                   requestId:(NSString *)requestId
               correlationId:(NSUUID *)correlationId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _errorInEvent = NO;
    
    _propertyMap = [NSMutableDictionary dictionary];
    [_propertyMap msidSetObjectIfNotNil:requestId forKey:MSID_TELEMETRY_KEY_REQUEST_ID];
    [_propertyMap msidSetObjectIfNotNil:[correlationId UUIDString] forKey:MSID_TELEMETRY_KEY_CORRELATION_ID];
    
    [_propertyMap msidSetObjectIfNotNil:eventName forKey:MSID_TELEMETRY_KEY_EVENT_NAME];
    
    return self;
}

- (instancetype)initWithName:(NSString *)eventName
                     context:(id<MSIDRequestContext>)requestParams
{
    return [self initWithName:eventName requestId:requestParams.telemetryRequestId correlationId:requestParams.correlationId];
}

- (void)setProperty:(NSString *)name value:(NSString *)value
{
    // value can be empty but not nil
    if ([NSString msidIsStringNilOrBlank:name] || !value)
    {
        return;
    }
    
    if ([MSIDTelemetryPiiRules isPii:name])
    {
        value = [value msidComputeSHA256];
    }
    
    NSString *prefixedName = [NSString stringWithFormat:@"%@%@", [MSIDVersion telemetryEventPrefix], name];
    [_propertyMap setValue:value forKey:prefixedName];
}

- (void)deleteProperty:(NSString  *)name
{
    if ([NSString msidIsStringNilOrBlank:name])
    {
        return;
    }
    
    NSString *prefixedName = [NSString stringWithFormat:@"%@%@", [MSIDVersion telemetryEventPrefix], name];
    [_propertyMap removeObjectForKey:prefixedName];
}

- (NSDictionary *)getProperties
{
    return _propertyMap;
}

- (void)setStartTime:(NSDate *)time
{
    if (!time)
    {
        return;
    }
    
    [self setProperty:MSID_TELEMETRY_KEY_START_TIME value:[time msidToString]];
}

- (void)setStopTime:(NSDate *)time
{
    if (!time)
    {
        return;
    }
    
    [self setProperty:MSID_TELEMETRY_KEY_END_TIME value:[time msidToString]];
}

- (void)setResponseTime:(NSTimeInterval)responseTime
{
    //the property is set in milliseconds
    [self setProperty:MSID_TELEMETRY_KEY_RESPONSE_TIME value:[NSString stringWithFormat:@"%f", responseTime*1000]];
}

- (void)addDefaultProperties
{
    // None for base event
}

@end
