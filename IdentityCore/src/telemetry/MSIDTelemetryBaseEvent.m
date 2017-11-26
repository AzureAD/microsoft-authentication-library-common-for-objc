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

#import "MSIDDeviceId.h"
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
    
    [self setProperty:MSID_TELEMETRY_KEY_REQUEST_ID value:requestId];
    [self setProperty:MSID_TELEMETRY_KEY_CORRELATION_ID value:[correlationId UUIDString]];
    [self setProperty:MSID_TELEMETRY_KEY_EVENT_NAME value:eventName];
    
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
    
    [_propertyMap setValue:value forKey:[[self class] prefixedPropertyName:name]];
}

- (NSString *)propertyWithName:(NSString *)name
{
    if ([NSString msidIsStringNilOrBlank:name])
    {
        return nil;
    }
    
    return _propertyMap[[[self class] prefixedPropertyName:name]];
}

- (void)deleteProperty:(NSString  *)name
{
    if ([NSString msidIsStringNilOrBlank:name])
    {
        return;
    }
    
    [_propertyMap removeObjectForKey:[[self class] prefixedPropertyName:name]];
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
    [_propertyMap addEntriesFromDictionary:[[self class] defaultParameters]];
}

+ (NSString *)prefixedPropertyName:(NSString *)name
{
    NSString *prefixedName = [NSString stringWithFormat:@"%@%@", [MSIDVersion telemetryEventPrefix], name];
    return prefixedName;
}

+ (NSDictionary *)defaultParameters
{
    static NSMutableDictionary *s_defaultParameters;
    static dispatch_once_t s_parametersOnce;
    
    dispatch_once(&s_parametersOnce, ^{
        
        s_defaultParameters = [NSMutableDictionary new];
        
        NSString *deviceId = [[MSIDDeviceId deviceTelemetryId] msidComputeSHA256];
        NSString *applicationName = [MSIDDeviceId applicationName];
        NSString *applicationVersion = [MSIDDeviceId applicationVersion];
        
        [s_defaultParameters msidSetObjectIfNotNil:deviceId
                                            forKey:[self prefixedPropertyName:MSID_TELEMETRY_KEY_DEVICE_ID]];
        [s_defaultParameters msidSetObjectIfNotNil:applicationName
                                            forKey:[self prefixedPropertyName:MSID_TELEMETRY_KEY_APPLICATION_NAME]];
        [s_defaultParameters msidSetObjectIfNotNil:applicationVersion
                                            forKey:[self prefixedPropertyName:MSID_TELEMETRY_KEY_APPLICATION_VERSION]];
        
        NSDictionary *adalId = [MSIDDeviceId deviceId];
        
        for (NSString *key in adalId)
        {
            NSString *propertyName = [self prefixedPropertyName:[[key lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
            [s_defaultParameters msidSetObjectIfNotNil:[adalId objectForKey:key] forKey:propertyName];
        }
    });
    
    return s_defaultParameters;
}

@end
