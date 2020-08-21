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
#import "NSKeyedArchiver+MSIDExtensions.h"
#import "NSKeyedUnarchiver+MSIDExtensions.h"

@implementation MSIDRequestTelemetryErrorInfo

#define kApiId              @"apiId"
#define kCorrelationID      @"correlationId"
#define kError              @"error"

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeFloat:self.apiId forKey:kApiId];
    [encoder encodeObject:[self.correlationId UUIDString] forKey:kCorrelationID];
    [encoder encodeObject:self.error forKey:kError];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self)
    {
        self.apiId = [decoder decodeFloatForKey:kApiId];
        
        NSString *uuIdString = [decoder decodeObjectForKey:kCorrelationID];
        self.correlationId = ![NSString msidIsStringNilOrBlank:uuIdString] ? [[NSUUID UUID] initWithUUIDString:uuIdString] : nil;
        
        self.error = [decoder decodeObjectForKey:kError];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@interface MSIDLastRequestTelemetry()

//@property (nonatomic) NSMutableArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo;
@property (nonatomic) NSMutableArray<MSIDRequestTelemetryErrorInfo *> *errorsInfoVal;
@property (nonatomic) NSInteger schemaVersion;
//@property (nonatomic) NSInteger silentSuccessfulCount;
@property (nonatomic) NSInteger silentSuccessfulCountVal;
@property (nonatomic) dispatch_queue_t synchronizationQueue;

@end

@implementation MSIDLastRequestTelemetry

static bool shouldReadFromDisk = YES;
static const NSInteger currentSchemaVersion = 2;

#pragma mark - Init

- (instancetype)initInternal
{
    self = [super init];
    if (self)
    {
        _schemaVersion = currentSchemaVersion;
        _synchronizationQueue = [self initializeDispatchQueue];
    }
    return self;
}

- (instancetype)initFromDisk
{
    NSString *saveLocation = [self filePathToSavedTelemetry];
    if (saveLocation && [[NSFileManager defaultManager] fileExistsAtPath:saveLocation])
    {
        NSData *dataToUnarchive = [NSData dataWithContentsOfFile:saveLocation];
        NSError *error;
        NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver msidCreateForReadingFromData:dataToUnarchive error:&error];
        
        if (error)
        {
            MSID_LOG_WITH_CTX(MSIDLogLevelError, nil, @"Failed to deserialize saved telemetry, error: %@", MSID_PII_LOG_MASKABLE(error));
            return [self initInternal];
        }
        
        MSIDLastRequestTelemetry *telemetry = [unarchiver decodeObjectOfClass:[MSIDLastRequestTelemetry class] forKey:NSKeyedArchiveRootObjectKey];
        
        [unarchiver finishDecoding];
        
        return telemetry;
    }
    
    return [self initInternal];
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

#pragma mark - Update object

- (void)updateWithApiId:(NSInteger)apiId
            errorString:(NSString *)errorString
                context:(id<MSIDRequestContext>)context
{
    if (errorString)
    {
        __auto_type errorInfo = [MSIDRequestTelemetryErrorInfo new];
        errorInfo.apiId = apiId;
        errorInfo.error = errorString;
        errorInfo.correlationId = context.correlationId;
        [self addErrorInfo:errorInfo];
    }
    else
    {
        [self resetTelemetry];
    }
}

- (void)increaseSilentSuccessfulCount
{
    dispatch_barrier_async(self.synchronizationQueue, ^{
        //self.silentSuccessfulCount += 1;
        self.silentSuccessfulCountVal += 1;
        [self saveTelemetryToDisk];
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

#pragma mark - NSSecureCoding

#define kSchemaVersion              @"schemaVersion"
#define kSilentSuccessfulCount      @"silentSuccessfulCount"
#define kErrorsInfo                 @"errorsInfo"

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeInteger:_schemaVersion forKey:kSchemaVersion];
    //[encoder encodeInteger:_silentSuccessfulCount forKey:kSilentSuccessfulCount];
    [encoder encodeInteger:_silentSuccessfulCountVal forKey:kSilentSuccessfulCount];
    //[encoder encodeObject:_errorsInfo forKey:kErrorsInfo];
    [encoder encodeObject:_errorsInfoVal forKey:kErrorsInfo];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSInteger schemaVersion = [decoder decodeIntegerForKey:kSchemaVersion];
    NSInteger silentSuccessfulCount = [decoder decodeIntegerForKey:kSilentSuccessfulCount];
    
    NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [MSIDRequestTelemetryErrorInfo class], nil];
    NSMutableArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo = [decoder decodeObjectOfClasses:classes forKey:kErrorsInfo];
    
    return [self initFromDecodedObjectWithSchemaVersion:schemaVersion silentSuccessfulCount:silentSuccessfulCount errorsInfo:errorsInfo];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
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

#pragma mark - Update object

- (void)addErrorInfo:(MSIDRequestTelemetryErrorInfo *)errorInfo
{
    dispatch_barrier_async(_synchronizationQueue, ^{
        if(errorInfo)
        {
//            if (![self.errorsInfo count])
//            {
//                self.errorsInfo = [NSMutableArray new];
//            }
//            [self.errorsInfo addObject:errorInfo];
            if (![self.errorsInfoVal count])
            {
                self.errorsInfoVal = [NSMutableArray new];
            }
            [self.errorsInfoVal addObject:errorInfo];
            //_errorsInfo = [_errorsInfo count] ? _errorsInfo : [NSMutableArray new];
           //[_errorsInfo addObject:errorInfo];
        }
        
        [self saveTelemetryToDisk];
    });
}

- (void)resetTelemetry
{
    dispatch_barrier_async(_synchronizationQueue, ^{
        //_errorsInfo = nil;
        self.errorsInfoVal = nil;
        //self.silentSuccessfulCount = 0;
        self.silentSuccessfulCountVal = 0;
        [self saveTelemetryToDisk];
    });
}

#pragma mark - Private: Save To Disk

- (void)saveTelemetryToDisk
{
    NSString *saveLocation = [self filePathToSavedTelemetry];
    if (saveLocation)
    {
        NSData *dataToArchive = [NSKeyedArchiver msidArchivedDataWithRootObject:self requiringSecureCoding:YES error:nil];
        
        [dataToArchive writeToFile:saveLocation atomically:YES];
    }
}

- (instancetype)initFromDecodedObjectWithSchemaVersion:(NSInteger)schemaVersion silentSuccessfulCount:(NSInteger)silentSuccessfulCount errorsInfo:(NSMutableArray<MSIDRequestTelemetryErrorInfo *>*) errorsInfo
{
    self = [super init];
    if (self)
    {
        if (schemaVersion == currentSchemaVersion)
        {
            _schemaVersion = schemaVersion;
            //_silentSuccessfulCount = silentSuccessfulCount;
            _silentSuccessfulCountVal = silentSuccessfulCount;
            //_errorsInfo = errorsInfo;
            self.errorsInfoVal = errorsInfo;
            _synchronizationQueue = [self initializeDispatchQueue];
        }
        else
        {
            self = [self initInternal];
        }
        
    }
    return self;
}

- (NSString *)filePathToSavedTelemetry
{
    NSString *filePath = NSTemporaryDirectory();
    filePath = [filePath stringByAppendingPathComponent:@"msal.telemetry.lastRequest"];
    
    return filePath;
}

#pragma mark - Private: Misc.

- (NSArray<MSIDRequestTelemetryErrorInfo *> *)errorsInfo
{
    __block NSArray *errorsInfoCopy;
    dispatch_sync(self.synchronizationQueue, ^{
        //errorsInfoCopy = [_errorsInfo copy];
        errorsInfoCopy = [self.errorsInfoVal copy];
    });
    return errorsInfoCopy;
}

- (NSInteger)silentSuccessfulCount
{
    __block NSInteger count;
    dispatch_sync(self.synchronizationQueue, ^{
        //count = self.silentSuccessfulCount;
        count = self.silentSuccessfulCountVal;
    });
    
    return count;
}

- (dispatch_queue_t)initializeDispatchQueue
{
    NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidlastrequesttelemetry-%@", [NSUUID UUID].UUIDString];
    return dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_CONCURRENT);
}

#pragma mark - MSIDLastRequestTelemetry+Internal

- (instancetype)initTelemetryFromDiskWithQueue:(dispatch_queue_t)queue
{
    __block MSIDLastRequestTelemetry *result;
    dispatch_sync(queue, ^{
        
        NSString *saveLocation = [self filePathToSavedTelemetry];
        if (saveLocation && [[NSFileManager defaultManager] fileExistsAtPath:saveLocation])
        {
            NSData *dataToUnarchive = [NSData dataWithContentsOfFile:saveLocation];
            NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver msidCreateForReadingFromData:dataToUnarchive error:nil];
            
            result = [unarchiver decodeObjectOfClass:[MSIDLastRequestTelemetry class] forKey:NSKeyedArchiveRootObjectKey];
            
            [unarchiver finishDecoding];
        }
        
    });
    
    return result;
}

@end
