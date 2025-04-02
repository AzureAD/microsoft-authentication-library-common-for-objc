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

#import "MSIDBrokerFlightProvider.h"
#import "NSJSONSerialization+MSIDExtensions.h"

@interface MSIDBrokerFlightProvider()

@property (nonatomic, nullable, readonly) NSDictionary *clientFlightsPayload;

@end

@implementation MSIDBrokerFlightProvider

- (instancetype _Nullable)initWithBase64EncodedFlightsPayload:(nullable NSString *)base64EncodedFlightsPayload
{
    self = [super init];
    
    if (self)
    {
        if ([NSString msidIsStringNilOrBlank:base64EncodedFlightsPayload])
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo,nil, @"Broker client flights is nil or empty");
            return nil;
        }
        
        NSDictionary *clientFlightsDict = nil;
        
        NSData *decodedJsonData =  [[base64EncodedFlightsPayload msidBase64UrlDecode] dataUsingEncoding:NSUTF8StringEncoding];
        if (decodedJsonData && [decodedJsonData length])
        {
            clientFlightsDict = [NSJSONSerialization msidNormalizedDictionaryFromJsonData:decodedJsonData error:nil];
            
            if (![clientFlightsDict isKindOfClass:[NSDictionary class]])
            {
                MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Invalid broker client flight format");
                return nil;
            }
        }
        else
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelWarning,nil, @"Failed to decode base64encoded client flights from broker");
            return nil;
        }
        
        if (clientFlightsDict)
        {
            _clientFlightsPayload = clientFlightsDict;
            MSID_LOG_WITH_CTX(MSIDLogLevelInfo, nil, @"Client flights from broker is decoded successfully");
        }
    }
    
    return self;
}

#pragma mark - MSIDFlightManagerInterface

- (BOOL)boolForKey:(nonnull NSString *)flightKey
{
    if (self.clientFlightsPayload)
    {
        id value = self.clientFlightsPayload[flightKey];
        
        if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]])
        {
            return [value boolValue];
        }
    }
    
    return NO;
}

- (nullable NSString *)stringForKey:(nonnull NSString *)flightKey
{
    if (self.clientFlightsPayload)
    {
        id value = self.clientFlightsPayload[flightKey];
        
        if ([value isKindOfClass:[NSString class]])
        {
            return value;
        }
    }
    
    return nil;
}


@end
