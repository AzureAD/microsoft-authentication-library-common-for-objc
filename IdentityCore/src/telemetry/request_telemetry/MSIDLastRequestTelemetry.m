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

#import "MSIDLastRequestTelemetry.h"

@implementation MSIDRequestTelemetryErrorInfo
@end

@interface MSIDLastRequestTelemetry()

@property (nonatomic) NSInteger schemaVersion;
@property (nonatomic) NSInteger silentSuccessfulCount;
@property (nonatomic) NSArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo;

@end

@implementation MSIDLastRequestTelemetry

#pragma mark - Init

- (id)initInternal
{
    self = [super init];
    if (self)
    {
        _schemaVersion = 2;
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static MSIDLastRequestTelemetry *singleton = nil;
    
    dispatch_once(&once, ^{
        singleton = [[MSIDLastRequestTelemetry alloc] initInternal];
    });
    
    return singleton;
}
- (void)updateWithApiId:(NSInteger)apiId
            errorString:(NSString *)errorString
                context:(id<MSIDRequestContext>)context
{
    if (errorString)
    {
        NSMutableArray *errorsInfo = self.errorsInfo ? [self.errorsInfo mutableCopy] : [NSMutableArray new];
        
        __auto_type errorInfo = [MSIDRequestTelemetryErrorInfo new];
        errorInfo.apiId = apiId;
        errorInfo.error = errorString;
        errorInfo.correlationId = context.correlationId;
        
        [errorsInfo addObject:errorInfo];
        
        self.errorsInfo = errorsInfo;
    }
    else
    {
        self.silentSuccessfulCount = 0;
        self.errorsInfo = nil;
    }
}

- (void)increaseSilentSuccessfulCount
{
    self.silentSuccessfulCount = self.silentSuccessfulCount + 1;
}

#pragma mark - MSIDTelemetryStringSerializable

- (NSString *)telemetryString
{
    return @"";
}

- (instancetype)initWithTelemetryString:(__unused NSString *)csvString error:(__unused NSError **)error
{
    self = [super init];
    if (self)
    {
        
    }
    return self;
}

@end
