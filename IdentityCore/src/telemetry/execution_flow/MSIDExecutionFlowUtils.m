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
// copies of the Software, and to permit persons to whom the Software are
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

#import "MSIDExecutionFlowUtils.h"
#import "MSIDExecutionFlowBlob.h"
#import "MSIDExecutionFlowConstants.h"
#import "MSIDJsonSerializer.h"


static NSSet<NSString *> *MSIDReservedExecutionFlowKeys(void)
{
    static NSSet<NSString *> *reservedKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reservedKeys = [NSSet setWithArray:@[MSID_EXECUTION_FLOW_TAG,
                                             MSID_EXECUTION_FLOW_TIME_SPENT,
                                             MSID_EXECUTION_FLOW_THREAD_ID]];
    });
    return reservedKeys;
}


@implementation MSIDExecutionFlowUtils

+ (instancetype)sharedInstance
{
    static MSIDExecutionFlowUtils *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MSIDExecutionFlowUtils alloc] init];
    });
    return sharedInstance;
}

- (NSString *)convertDictionary:(NSDictionary *)dictionary
           toJsonStringWithKeys:(NSSet<NSString *> *)queryKeys
{
    MSIDJsonSerializer *serializer = [MSIDJsonSerializer new];
    
    if ([queryKeys count] == 0)
    {
        return [serializer serializeToJsonString:dictionary error:nil];
        
    }
    else
    {
        NSSet *reservedKeys = MSIDReservedExecutionFlowKeys();
        NSMutableDictionary *resultDict = [NSMutableDictionary new];
        for (NSString *key in dictionary)
        {
            if ([reservedKeys containsObject:key] || [queryKeys containsObject:key])
            {
                id value = dictionary[key];
                resultDict[key] = value;
            }
        }
        
        return [serializer serializeToJsonString:resultDict error:nil];
    }
}

@end
