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

#if !EXCLUDE_FROM_MSALCPP

#import "MSIDLastRequestTelemetry.h"
#import "MSIDLastRequestTelemetrySerializedItem.h"
#import "NSKeyedArchiver+MSIDExtensions.h"
#import "NSKeyedUnarchiver+MSIDExtensions.h"
#import "MSIDRequestTelemetryConstants.h"

@implementation MSIDRequestPerformanceInfo

#define kTotalNumbers              @"totalNumbers"
#define kIpcRequestNumbers         @"ipcRequestNumbers"
#define kIpcResponseNumbers        @"ipcResponseNumbers"

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.totalNumbers forKey:kTotalNumbers];
    [encoder encodeObject:self.ipcRequestNumbers forKey:kIpcRequestNumbers];
    [encoder encodeObject:self.ipcResponseNumbers forKey:kIpcResponseNumbers];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self)
    {
        NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [NSNumber class], nil];
        self.totalNumbers = [decoder decodeObjectOfClasses:classes forKey:kTotalNumbers];
        self.ipcRequestNumbers = [decoder decodeObjectOfClasses:classes forKey:kIpcRequestNumbers];
        self.ipcResponseNumbers = [decoder decodeObjectOfClasses:classes forKey:kIpcResponseNumbers];
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

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
        self.apiId = (NSInteger)[decoder decodeFloatForKey:kApiId];
        
        NSString *uuIdString = [decoder decodeObjectForKey:kCorrelationID];
        if ([NSString msidIsStringNilOrBlank:uuIdString]) return nil;
        
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

NSString * _Nonnull const MSID_PERF_TELEMETRY_SILENT_TYPE = @"silent";
NSString * _Nonnull const MSID_PERF_TELEMETRY_SIGNOUT_TYPE = @"signout";
NSString * _Nonnull const MSID_PERF_TELEMETRY_GETACCOUNTS_TYPE = @"accounts";
NSString * _Nonnull const MSID_PERF_TELEMETRY_GETDEVICEINFO_TYPE = @"deviceinfo";

@interface MSIDLastRequestTelemetry()

@property (nonatomic) NSMutableArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo;
@property (nonatomic) NSInteger schemaVersion;
@property (nonatomic) NSInteger silentSuccessfulCount;
@property (nonatomic) NSMutableDictionary<NSString *, MSIDRequestPerformanceInfo *> *perfTelemetry;
@property (nonatomic) NSMutableArray<NSString *> *platformFields;
@property (nonatomic) dispatch_queue_t synchronizationQueue;
@property (nonatomic) MSIDLastRequestTelemetrySerializedItem *telemetrySerializedItem;

@end

@implementation MSIDLastRequestTelemetry

static bool shouldReadFromDisk = YES;
static int maxErrorCountToArchive = 75;

+ (int)telemetryStringSizeLimit
{
    return MSIDLastRequestTelemetrySerializedItem.telemetryStringSizeLimit;
}

+ (void)updateTelemetryStringSizeLimit:(int)newLimit
{
    MSIDLastRequestTelemetrySerializedItem.telemetryStringSizeLimit = newLimit;
}

+ (void)updateMaxErrorCountToArchive:(int)newMax
{
    maxErrorCountToArchive = newMax;
}

#pragma mark - Init

- (instancetype)initInternal
{
    self = [super init];
    if (self)
    {
        _schemaVersion = HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION;
        _synchronizationQueue = [self initializeDispatchQueue];
        _platformFields = [NSMutableArray<NSString *> new];
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
        self->_silentSuccessfulCount += 1;
        [self saveTelemetryToDisk];
    });
}

- (void)trackSSOExtensionPerformanceWithType:(NSString *)type
                             totalPerfNumber:(NSTimeInterval)totalPerfNumber
                        ipcRequestPerfNumber:(NSTimeInterval)ipcRequestPerfNumber
                       ipcResponsePerfNumber:(NSTimeInterval)ipcResponsePerfNumber
{
    dispatch_barrier_async(self.synchronizationQueue, ^{
        
        [self trackSSOExtensionPerformanceWithTypeImpl:type
                                       totalPerfNumber:totalPerfNumber
                                  ipcRequestPerfNumber:ipcRequestPerfNumber
                                 ipcResponsePerfNumber:ipcResponsePerfNumber];
        
        [self saveTelemetryToDisk];
    });
}

- (void)trackSSOExtensionPerformanceWithTypeImpl:(NSString *)type
                                 totalPerfNumber:(NSTimeInterval)totalPerfNumber
                            ipcRequestPerfNumber:(NSTimeInterval)ipcRequestPerfNumber
                           ipcResponsePerfNumber:(NSTimeInterval)ipcResponsePerfNumber
{
    if (!self.perfTelemetry)
    {
        self.perfTelemetry = [NSMutableDictionary new];
    }
    
    MSIDRequestPerformanceInfo *perfInfo = self.perfTelemetry[type];
    
    if (!perfInfo)
    {
        perfInfo = [MSIDRequestPerformanceInfo new];
    }
    
    if (!perfInfo.totalNumbers)
    {
        perfInfo.totalNumbers = [NSMutableArray new];
    }
    
    if (!perfInfo.ipcRequestNumbers)
    {
        perfInfo.ipcRequestNumbers = [NSMutableArray new];
    }
    
    if (!perfInfo.ipcResponseNumbers)
    {
        perfInfo.ipcResponseNumbers = [NSMutableArray new];
    }
    
    [perfInfo.totalNumbers addObject:@(totalPerfNumber)];
    [perfInfo.ipcRequestNumbers addObject:@(ipcRequestPerfNumber)];
    [perfInfo.ipcResponseNumbers addObject:@(ipcResponsePerfNumber)];
    
    self.perfTelemetry[type] = perfInfo;
}

#pragma mark - MSIDTelemetryStringSerializable

- (NSString *)telemetryString
{
    __block NSString *result;
    dispatch_barrier_sync(self.synchronizationQueue, ^{
        result = [self serializeLastTelemetryString];
    });
    
    return result;
}

#pragma mark - NSSecureCoding

#define kSchemaVersion              @"schemaVersion"
#define kSilentSuccessfulCount      @"silentSuccessfulCount"
#define kErrorsInfo                 @"errorsInfo"
#define kPerfTelemetry              @"perfTelemetry"

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeInteger:_schemaVersion forKey:kSchemaVersion];
    [encoder encodeInteger:_silentSuccessfulCount forKey:kSilentSuccessfulCount];
    [encoder encodeObject:_errorsInfo forKey:kErrorsInfo];
    [encoder encodeObject:_perfTelemetry forKey:kPerfTelemetry];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    NSInteger schemaVersion = [decoder decodeIntegerForKey:kSchemaVersion];
    NSInteger silentSuccessfulCount = [decoder decodeIntegerForKey:kSilentSuccessfulCount];
    
    NSSet *classes = [NSSet setWithObjects:[NSMutableArray class], [NSString class], [MSIDRequestTelemetryErrorInfo class], nil];
    NSMutableArray<MSIDRequestTelemetryErrorInfo *> *errorsInfo = [decoder decodeObjectOfClasses:classes forKey:kErrorsInfo];
    
    NSSet *perfClasses = [NSSet setWithObjects:[NSMutableDictionary class], [NSString class], [MSIDRequestPerformanceInfo class], nil];
    NSDictionary *perfTelemetry = [decoder decodeObjectOfClasses:perfClasses forKey:kPerfTelemetry];
    
    return [self initFromDecodedObjectWithSchemaVersion:schemaVersion silentSuccessfulCount:silentSuccessfulCount errorsInfo:errorsInfo perfTelemetry:perfTelemetry];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

#pragma mark - Private: Serialization

- (NSString *)serializeLastTelemetryString
{
    self.telemetrySerializedItem = [self createSerializedItem];
    
    return [self.telemetrySerializedItem serialize];
}

- (MSIDLastRequestTelemetrySerializedItem *)createSerializedItem
{
    NSArray *defaultFields = @[[NSNumber numberWithInteger:self->_silentSuccessfulCount]];
    
    NSMutableArray *platformFields = [NSMutableArray new];
    [platformFields addObjectsFromArray:self.platformFields];
    
    NSString *serializedPerfTelemetry = [self serializedPerfTelemetry];
    
    if (![NSString msidIsStringNilOrBlank:serializedPerfTelemetry])
    {
        [platformFields addObject:[self serializedPerfTelemetry]];
    }
    
    return [[MSIDLastRequestTelemetrySerializedItem alloc] initWithSchemaVersion:[NSNumber numberWithInteger:self.schemaVersion] defaultFields:defaultFields errorInfo:self->_errorsInfo platformFields:platformFields];
}

- (NSString *)serializedPerfTelemetry
{
    if (![self.perfTelemetry count])
    {
        return nil;
    }
    
    NSString *serializedPerfTelemetry = [NSString stringWithFormat:@"%@;%@;%@;%@;",
                                         [self serializedAverageForType:MSID_PERF_TELEMETRY_SILENT_TYPE],
                                         [self serializedAverageForType:MSID_PERF_TELEMETRY_SIGNOUT_TYPE],
                                         [self serializedAverageForType:MSID_PERF_TELEMETRY_GETACCOUNTS_TYPE],
                                         [self serializedAverageForType:MSID_PERF_TELEMETRY_GETDEVICEINFO_TYPE]];
    return serializedPerfTelemetry;
}

- (NSString *)serializedAverageForType:(NSString *)type
{
    MSIDRequestPerformanceInfo *perfInfo = self.perfTelemetry[type];
    
    if (!perfInfo)
    {
        return [NSString stringWithFormat:@"%@:", type];
    }
 
    NSNumber *totalAverage = perfInfo.totalNumbers ? [perfInfo.totalNumbers valueForKeyPath:@"@avg.self"] : nil;
    NSNumber *ipcRequestAverage = perfInfo.ipcRequestNumbers ? [perfInfo.ipcRequestNumbers valueForKeyPath:@"@avg.self"] : nil;
    NSNumber *ipcResponseAverage = perfInfo.ipcResponseNumbers ? [perfInfo.ipcResponseNumbers valueForKeyPath:@"@avg.self"] : nil;
    
    return [NSString stringWithFormat:@"%@:%f:%f:%f", type, [totalAverage doubleValue], [ipcRequestAverage doubleValue], [ipcResponseAverage doubleValue]];
}

#pragma mark - Update object

- (void)addErrorInfo:(MSIDRequestTelemetryErrorInfo *)errorInfo
{
    dispatch_barrier_async(_synchronizationQueue, ^{
        if(errorInfo)
        {
           self->_errorsInfo = [self->_errorsInfo count] ? self->_errorsInfo : [NSMutableArray new];
           [self->_errorsInfo addObject:errorInfo];
        }
        
        [self saveTelemetryToDisk];
    });
}

- (void)resetTelemetry
{
    dispatch_barrier_async(_synchronizationQueue, ^{
        self->_silentSuccessfulCount = 0;
        
        if (self.telemetrySerializedItem && [self.telemetrySerializedItem getUnserializedTelemetry])
        {
            self->_errorsInfo = [NSMutableArray arrayWithArray:[self.telemetrySerializedItem getUnserializedTelemetry]];
            // "1" in platform fields indicates entry contains telemetry cut off in previous
            // request. Pending investigation into which platform fields are needed
            [self->_platformFields addObject:@"1"];
        }
        else
        {
            self->_errorsInfo = nil;
        }
        
        self.perfTelemetry = [NSMutableDictionary new];

        [self saveTelemetryToDisk];
    });
}

#pragma mark - Private: Save To Disk

- (void)saveTelemetryToDisk
{
    NSString *saveLocation = [self filePathToSavedTelemetry];
    if (saveLocation)
    {
        // Some testing has determined that 75 errors corresponds to an archive size of about 8kb. 
        if ((int)_errorsInfo.count > maxErrorCountToArchive)
        {
            MSID_LOG_WITH_CTX_PII(MSIDLogLevelVerbose, nil, @"Telemetry size over limit when saving to disk, cutting down to limit", nil);
            
            NSRange rangeToRemove;
            rangeToRemove.location = 0;
            rangeToRemove.length = _errorsInfo.count - maxErrorCountToArchive;
            [_errorsInfo removeObjectsInRange:rangeToRemove];
        }
        
        NSData *dataToArchive = [NSKeyedArchiver msidArchivedDataWithRootObject:self requiringSecureCoding:YES error:nil];
        
        if (@available(macOS 11.0, *)) {
            [dataToArchive writeToFile:saveLocation options:(NSDataWritingAtomic | NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication) error:nil];
        } else {
            [dataToArchive writeToFile:saveLocation atomically:YES];
        }
    }
}

- (instancetype)initFromDecodedObjectWithSchemaVersion:(NSInteger)schemaVersion silentSuccessfulCount:(NSInteger)silentSuccessfulCount errorsInfo:(NSMutableArray<MSIDRequestTelemetryErrorInfo *>*) errorsInfo perfTelemetry:(NSDictionary *)perfTelemetry
{
    self = [super init];
    if (self)
    {
        if (schemaVersion == HTTP_REQUEST_TELEMETRY_SCHEMA_VERSION)
        {
            _schemaVersion = schemaVersion;
            _silentSuccessfulCount = silentSuccessfulCount;
            _errorsInfo = errorsInfo;
            _synchronizationQueue = [self initializeDispatchQueue];
            _perfTelemetry = [[NSMutableDictionary alloc] initWithDictionary:perfTelemetry];
            _platformFields = [NSMutableArray<NSString *> new];
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
        errorsInfoCopy = [_errorsInfo copy];
    });
    return errorsInfoCopy;
}

- (NSInteger)silentSuccessfulCount
{
    __block NSInteger count;
    dispatch_sync(self.synchronizationQueue, ^{
        count = _silentSuccessfulCount;
    });
    
    return count;
}

- (dispatch_queue_t)initializeDispatchQueue
{
    NSString *queueName = [NSString stringWithFormat:@"com.microsoft.msidlastrequesttelemetry-%@", [NSUUID UUID].UUIDString];
    return dispatch_queue_create([queueName cStringUsingEncoding:NSASCIIStringEncoding], DISPATCH_QUEUE_SERIAL);
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

#endif
