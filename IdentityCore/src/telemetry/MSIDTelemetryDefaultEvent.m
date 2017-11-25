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
#import "MSIDTelemetryDefaultEvent.h"
#import "MSIDTelemetryEventInterface.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDLogger.h"
#import "MSIDTelemetryPiiRules.h"
#import "NSMutableDictionary+MSIDExtensions.h"

#import "MSIDDeviceId.h"
#import "MSIDVersion.h"

#if !TARGET_OS_IPHONE
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#endif

@implementation MSIDTelemetryDefaultEvent

@synthesize propertyMap = _propertyMap;

- (id)init
{
    //Ensure that the appropriate init function is called. This will cause the runtime to throw.
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithName:(NSString *)eventName
         requestId:(NSString *)requestId
     correlationId:(NSUUID *)correlationId
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _propertyMap = [[MSIDTelemetryDefaultEvent defaultParameters] mutableCopy];
    [_propertyMap msidSetObjectIfNotNil:requestId forKey:MSID_TELEMETRY_KEY_REQUEST_ID];
    [_propertyMap msidSetObjectIfNotNil:[correlationId UUIDString] forKey:MSID_TELEMETRY_KEY_CORRELATION_ID];
    
    [_propertyMap msidSetObjectIfNotNil:eventName forKey:MSID_TELEMETRY_KEY_EVENT_NAME];
    
    return self;
}

- (id)initWithName:(NSString *)eventName
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
        
    [_propertyMap removeObjectForKey:name];
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
    
    [_propertyMap setValue:[self getStringFromDate:time] forKey:MSID_TELEMETRY_KEY_START_TIME];
}

- (void)setStopTime:(NSDate *)time
{
    if (!time)
    {
        return;
    }
    
    [_propertyMap setValue:[self getStringFromDate:time] forKey:MSID_TELEMETRY_KEY_END_TIME];
}

- (void)setResponseTime:(NSTimeInterval)responseTime
{
    //the property is set in milliseconds
    [_propertyMap setValue:[NSString stringWithFormat:@"%f", responseTime*1000] forKey:MSID_TELEMETRY_KEY_RESPONSE_TIME];
}

- (NSString *)getStringFromDate:(NSDate *)date
{
    static NSDateFormatter* s_dateFormatter = nil;
    static dispatch_once_t s_dateOnce;
    
    dispatch_once(&s_dateOnce, ^{
        s_dateFormatter = [[NSDateFormatter alloc] init];
        [s_dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [s_dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSSS"];
    });
    
    return [s_dateFormatter stringFromDate:date];
}

+ (NSDictionary *)defaultParameters
{
    static NSMutableDictionary *s_defaultParameters;
    static dispatch_once_t s_parametersOnce;
    
    dispatch_once(&s_parametersOnce, ^{
        
        s_defaultParameters = [NSMutableDictionary new];
        
        // TODO: move this to MSIDDeviceId
        
#if TARGET_OS_IPHONE
        //iOS:
        NSString *deviceId = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
        NSString *applicationName = [[NSBundle mainBundle] bundleIdentifier];
#else
        CFStringRef macSerialNumber = nil;
        CopySerialNumber(&macSerialNumber);
        NSString *deviceId = CFBridgingRelease(macSerialNumber);
        NSString *applicationName = [[NSProcessInfo processInfo] processName];
#endif
        
        [s_defaultParameters msidSetObjectIfNotNil:[deviceId msidComputeSHA256] forKey:MSID_TELEMETRY_KEY_DEVICE_ID];
        [s_defaultParameters msidSetObjectIfNotNil:applicationName forKey:MSID_TELEMETRY_KEY_APPLICATION_NAME];
        [s_defaultParameters msidSetObjectIfNotNil:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
                                            forKey:MSID_TELEMETRY_KEY_APPLICATION_VERSION];
        
        NSDictionary *adalId = [MSIDDeviceId deviceId];
        for (NSString *key in adalId)
        {
            NSString *propertyName = [NSString stringWithFormat:@"Microsoft.ADAL.%@",
                                      [[key lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
            
            [s_defaultParameters msidSetObjectIfNotNil:[adalId objectForKey:key] forKey:propertyName];
        }
    });
    
    return s_defaultParameters;
}

- (void)addPropertiesToAggregatedEvent:(NSMutableDictionary *)eventToBeDispatched
                         propertyNames:(NSArray *)propertyNames
{
    NSDictionary *properties = [self getProperties];
    for (NSString *name in propertyNames)
    {
        [eventToBeDispatched msidSetObjectIfNotNil:[properties objectForKey:name] forKey:name];
    }
}

#if !TARGET_OS_IPHONE
// Returns the serial number as a CFString.
// It is the caller's responsibility to release the returned CFString when done with it.
void CopySerialNumber(CFStringRef *serialNumber)
{
    if (serialNumber != NULL) {
        *serialNumber = NULL;
        
        io_service_t    platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                                     IOServiceMatching("IOPlatformExpertDevice"));
        
        if (platformExpert) {
            CFTypeRef serialNumberAsCFString =
            IORegistryEntryCreateCFProperty(platformExpert,
                                            CFSTR(kIOPlatformSerialNumberKey),
                                            kCFAllocatorDefault, 0);
            if (serialNumberAsCFString) {
                *serialNumber = serialNumberAsCFString;
            }
            
            IOObjectRelease(platformExpert);
        }
    }
}
#endif

@end
