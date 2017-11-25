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
#import "NSMutableDictionary+MSIDExtensions.h"
#import "MSIDTelemetryEventStrings.h"

#import "MSIDDeviceId.h"
#import "MSIDVersion.h"

@implementation MSIDTelemetryDefaultEvent

- (void)addDefaultParameters
{
    NSDictionary *defaultParameters = [MSIDTelemetryDefaultEvent defaultParameters];
    
    for (NSString *paramaterName in [defaultParameters allKeys])
    {
        [self setProperty:paramaterName value:defaultParameters[paramaterName]];
    }
}

+ (NSDictionary *)defaultParameters
{
    static NSMutableDictionary *s_defaultParameters;
    static dispatch_once_t s_parametersOnce;
    
    dispatch_once(&s_parametersOnce, ^{
        
        s_defaultParameters = [NSMutableDictionary new];
        
        NSString *deviceId = [MSIDDeviceId deviceTelemetryId];
        NSString *applicationName = [MSIDDeviceId applicationName];
        NSString *applicationVersion = [MSIDDeviceId applicationVersion];
        
        [s_defaultParameters msidSetObjectIfNotNil:deviceId forKey:MSID_TELEMETRY_KEY_DEVICE_ID];
        [s_defaultParameters msidSetObjectIfNotNil:applicationName forKey:MSID_TELEMETRY_KEY_APPLICATION_NAME];
        [s_defaultParameters msidSetObjectIfNotNil:applicationVersion forKey:MSID_TELEMETRY_KEY_APPLICATION_VERSION];
        
        NSDictionary *adalId = [MSIDDeviceId deviceId];
        
        for (NSString *key in adalId)
        {
            NSString *propertyName = [NSString stringWithFormat:@"%@.%@", [MSIDVersion telemetryEventPrefix],
                                      [[key lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"]];
            
            [s_defaultParameters msidSetObjectIfNotNil:[adalId objectForKey:key] forKey:propertyName];
        }
    });
    
    return s_defaultParameters;
}

@end
