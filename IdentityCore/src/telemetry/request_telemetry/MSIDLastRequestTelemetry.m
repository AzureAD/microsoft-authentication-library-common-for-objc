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

#define kApiId              @"apiId"
#define kCorrelationID      @"correlationId"
#define kError              @"error"

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeFloat:self.apiId forKey:kApiId];
    [encoder encodeObject:[self.correlationId UUIDString] forKey:kCorrelationID];
    [encoder encodeObject:self.error forKey:kError];
}

- (id)initWithCoder:(NSCoder *)decoder {
    self.apiId = [decoder decodeFloatForKey:kApiId];
    
    NSString *uuIdString = [decoder decodeObjectForKey:kCorrelationID];
    self.correlationId = [[NSUUID UUID] initWithUUIDString:uuIdString];
    
    self.error = [decoder decodeObjectForKey:kError];
    return self;
}

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

static bool shouldReadFromDisk = YES;

#pragma mark - Init

- (id)initInternal
{
    self = [super init];
    if (self)
    {
        _schemaVersion = 2;
        _synchronizationQueue = [self initializeDispatchQueue];
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static MSIDLastRequestTelemetry *singleton = nil;
    
    dispatch_once(&once, ^{
        if (shouldReadFromDisk)
        {
            singleton = [[MSIDLastRequestTelemetry alloc] initFromDisk];
            shouldReadFromDisk = NO;
        }
        else
        {
            singleton = [[MSIDLastRequestTelemetry alloc] initInternal];
        }
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
    
    [self saveToDisk];
}

- (void)increaseSilentSuccessfulCount
{
    dispatch_barrier_async(self.synchronizationQueue, ^{
        self.silentSuccessfulCount = self.silentSuccessfulCount + 1;
    });
    
    [self saveToDisk];
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

#pragma mark - Private: Serialization

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

#pragma mark - Private: Save To Disk

- (void)saveToDisk
{
    [NSKeyedArchiver archiveRootObject:self toFile:[self filePath]];
}

- (instancetype)initFromDisk
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self filePath]])
    {
        return [NSKeyedUnarchiver unarchiveObjectWithFile:[self filePath]];
    }
    
    return [self initInternal];
}

#pragma mark - NSCoding

#define kSchemaVersion              @"schemaVersion"
#define kSilentSuccessfulCount      @"silentSuccessfulCount"
#define kErrorsInfo                 @"errorsInfo"

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeFloat:self.schemaVersion forKey:kSchemaVersion];
    [encoder encodeFloat:self.silentSuccessfulCount forKey:kSilentSuccessfulCount];
    [encoder encodeObject:self.errorsInfo forKey:kErrorsInfo];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    NSInteger schemaVersion = [decoder decodeFloatForKey:kSchemaVersion];
    NSInteger silentSuccessfulCount = [decoder decodeFloatForKey:kSilentSuccessfulCount];
    NSMutableArray<MSIDRequestTelemetryErrorInfo *> *test = [decoder decodeObjectForKey:kErrorsInfo];
    
    return [self initFromDecodedObjectWithSchemaVersion:schemaVersion silentSuccessfulCount:silentSuccessfulCount errorsInfo:test];
}

- (id)initFromDecodedObjectWithSchemaVersion:(NSInteger)schemaVersion silentSuccessfulCount:(NSInteger)silentSuccessfulCount errorsInfo:(NSMutableArray<MSIDRequestTelemetryErrorInfo *>*) errorsInfo
{
    self = [super init];
    if (self)
    {
        _schemaVersion = schemaVersion;
        _silentSuccessfulCount = silentSuccessfulCount;
        _errorsInfo = errorsInfo;
        _synchronizationQueue = [self initializeDispatchQueue];
    }
    return self;
}

#pragma mark - Private: Misc

- (NSString *)filePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectoryPath stringByAppendingPathComponent:@"lastRequest"];
    return filePath;
}

- (dispatch_queue_t)initializeDispatchQueue
{
    NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidlastrequesttelemetry-%@", [NSUUID UUID].UUIDString];
    return dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
}

@end
