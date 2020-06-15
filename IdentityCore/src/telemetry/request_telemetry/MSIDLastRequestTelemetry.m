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
#import "MSIDLastRequestTelemetrySerializedItem.h"

@implementation MSIDRequestTelemetryErrorInfo
@end

@interface MSIDLastRequestTelemetry()
{
    NSMutableArray<MSIDRequestTelemetryErrorInfo *> *_errorsInfo;
}

@property (nonatomic) NSInteger schemaVersion;
@property (nonatomic) NSInteger silentSuccessfulCount;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDLastRequestTelemetry

#pragma mark - Init

- (id)initInternal
{
    self = [super init];
    if (self)
    {
        _schemaVersion = 2;
        
        NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidlastrequesttelemetry-%@", [NSUUID UUID].UUIDString];
        _synchronizationQueue = dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
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
        dispatch_barrier_async(self.synchronizationQueue, ^{
            _errorsInfo = [_errorsInfo count] ? _errorsInfo : [NSMutableArray new];
            
            __auto_type errorInfo = [MSIDRequestTelemetryErrorInfo new];
            errorInfo.apiId = apiId;
            errorInfo.error = errorString;
            errorInfo.correlationId = context.correlationId;
            
            [_errorsInfo addObject:errorInfo];
        });
    }
    else
    {
        dispatch_barrier_async(self.synchronizationQueue, ^{
            self.silentSuccessfulCount = 0;
            _errorsInfo = nil;
        });
    }
}

- (void)increaseSilentSuccessfulCount
{
    dispatch_barrier_async(self.synchronizationQueue, ^{
        self.silentSuccessfulCount = self.silentSuccessfulCount + 1;
    });
}

#pragma mark - MSIDTelemetryStringSerializable

- (NSString *)telemetryString
{
    __block NSString *result;
    dispatch_sync(self.synchronizationQueue, ^{
        result = [self serializeLastTelemetryString];
    });
    
    return result;
}

- (NSArray<MSIDRequestTelemetryErrorInfo *> *)errorsInfo
{
    __block NSArray *errorsInfoCopy;
    dispatch_sync(self.synchronizationQueue, ^{
        errorsInfoCopy = [NSArray arrayWithArray:_errorsInfo];
    });
    return errorsInfoCopy;
}

#pragma mark - Private

- (NSString *)serializeLastTelemetryString
{
    MSIDLastRequestTelemetrySerializedItem *lastTelemetryFields = [self createSerializedItem];
    
    return [lastTelemetryFields serialize];
}

- (MSIDLastRequestTelemetrySerializedItem *)createSerializedItem
{
    NSArray *defaultFields = @[[NSNumber numberWithInteger:self.silentSuccessfulCount]];
    return [[MSIDLastRequestTelemetrySerializedItem alloc] initWithSchemaVersion:[NSNumber numberWithInteger:self.schemaVersion] defaultFields:defaultFields errorInfo:self.errorsInfo platformFields:nil];
}

@end
