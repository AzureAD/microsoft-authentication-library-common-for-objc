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


#import "MSIDExecutionFlowBlob.h"
#import "MSIDCache.h"
#import "NSString+MSIDExtensions.h"
#import "MSIDExecutionFlowConstants.h"
#import "MSIDExecutionFlowUtils.h"

@interface MSIDExecutionFlowBlob ()

@property (nonatomic) MSIDCache *blob;

@end

@implementation MSIDExecutionFlowBlob

- (instancetype)initWithTag:(NSString *)tag
                   timeStep:(NSNumber *)ts
                   threadId:(NSNumber *)tid
{
    if ([NSString msidIsStringNilOrBlank:tag] || !ts || !tid)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _blob = [[MSIDCache alloc] initWithDictionary:@{
            MSID_EXECUTION_FLOW_TAG: tag, // Activity or tag name
            MSID_EXECUTION_FLOW_TIME_SPENT: ts, // Time spent since the operation/startDate was created
            MSID_EXECUTION_FLOW_THREAD_ID: tid, // Thread id
        }];
    }
    
    return self;
}

- (void)setObject:(id)obj forKey:(NSString *)key
{
    if (!key)
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Key cannot be nil", nil);
        return;
    }

    // Protect reserved keys
    if ([@[MSID_EXECUTION_FLOW_TAG, MSID_EXECUTION_FLOW_TIME_SPENT, MSID_EXECUTION_FLOW_THREAD_ID] containsObject:key])
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Cannot override reserved keys: t, ts, tid", nil);
        return;
    }

    if ([obj isKindOfClass:NSString.class] || [obj isKindOfClass:NSNumber.class])
    {
        [self.blob setObject:obj forKey:key];
    }
    else
    {
        MSID_LOG_WITH_CTX_PII(MSIDLogLevelWarning, nil, @"Only string and number type are supported", nil);
    }
}

- (NSString *)blobToStringWithKeys:(NSSet<NSString *>*)queryKeys
{
    NSString *result = [[MSIDExecutionFlowUtils sharedInstance] convertDictionary:self.blob.toDictionary
                                                             toJsonStringWithKeys:queryKeys];
    return result;
}

@end
