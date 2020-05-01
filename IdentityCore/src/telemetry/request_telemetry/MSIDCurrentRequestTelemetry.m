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

#import "MSIDCurrentRequestTelemetry.h"

@implementation MSIDCurrentRequestTelemetry

#pragma mark - MSIDTelemetryStringSerializable

- (NSString *)telemetryString
{
    return [self serializeCurrentTelemetryString];
}

- (instancetype)initWithTelemetryString:(__unused NSString *)telemetryString error:(__unused NSError **)error
{
    self = [super init];
    if (self)
    {
        NSError *internalError;
        [self deserializeCurrentTelemetryString:telemetryString error:&internalError];
        
        if (internalError) {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelError, nil, @"Failed to initialize server telemetry, error: %@", MSID_PII_LOG_MASKABLE(internalError));
            if (error) *error = internalError;
            return nil;
        }
    }
    return self;
}

#pragma mark - Private

-(NSString *)serializeCurrentTelemetryString
{
    int forceRefreshValue = (self.forceRefresh ? 1 : 0);
    NSString *telemetryString = [NSString stringWithFormat:@"%ld|%ld,%d|", self.schemaVersion, self.apiId, forceRefreshValue];
    
    // Make sure string to be returned is less than 4kB in size
    if ([telemetryString lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 4000)
    {
        return nil;
    }
    
    return telemetryString;
}

-(void)deserializeCurrentTelemetryString:(NSString *)telemetryString error:(NSError **)error
{
    if ([telemetryString length] == 0)
    {
        NSString *errorDescription = @"Initialized server telemetry string with nil or empty string";
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        return;
    }
    
    NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"|,"];
    NSArray *telemetryItems = [telemetryString componentsSeparatedByCharactersInSet:charSet];
    
    // Pipe symbol in final position creates one extra element at the end of componentsSeparatedByString array
    // Hardcoded value of 4 will be changed based on the number of platform fields added in future releases
    if ([telemetryItems count] == 4)
    {
        self.schemaVersion = [telemetryItems[0] intValue];
        self.apiId = [telemetryItems[1] intValue];
        self.forceRefresh = [telemetryItems[2] boolValue];
    }
    else
    {
        NSString *errorDescription = @"Initialized server telemetry string with invalid string format";
        *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil, NO);
        return;
    }
    
}


@end
