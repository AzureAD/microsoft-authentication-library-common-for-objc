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
    NSMutableString *result = [NSMutableString stringWithString:@"{"];
    
    // Always include required fields in specific order: t, tid, ts
    [result appendFormat:@"\"t\":\"%@\",\"ts\":%@,\"tid\":%@", [self escapeJSONString:dictionary[MSID_EXECUTION_FLOW_TAG]], dictionary[MSID_EXECUTION_FLOW_TIME_SPENT], dictionary[MSID_EXECUTION_FLOW_THREAD_ID]];
    
    // Add all other fields
    NSSet *reservedKeys = [NSSet setWithArray:@[MSID_EXECUTION_FLOW_TAG, MSID_EXECUTION_FLOW_TIME_SPENT, MSID_EXECUTION_FLOW_THREAD_ID]];
    for (NSString *key in dictionary)
    {
        if ([reservedKeys containsObject:key] || (![queryKeys containsObject:key] && queryKeys.count != 0))
        {
            continue;
        }
        
        id value = dictionary[key];
        if ([value isKindOfClass:NSString.class])
        {
            [result appendFormat:@",\"%@\":\"%@\"", [self escapeJSONString:key], [self escapeJSONString:value]];
        }
        else if ([value isKindOfClass:NSNumber.class])
        {
            [result appendFormat:@",\"%@\":%@", [self escapeJSONString:key], value];
        }
    }
    
    [result appendString:@"}"];
    
    return result;
}

// Escapes special characters in a string for safe JSON inclusion
- (NSString *)escapeJSONString:(NSString *)string
{
    if (!string)
    {
        return @"";
    }
    
    NSMutableString *escaped = [NSMutableString stringWithCapacity:string.length];
    for (NSUInteger i = 0; i < string.length; i++)
    {
        unichar c = [string characterAtIndex:i];
        switch (c)
        {
            case '\\':
                [escaped appendString:@"\\\\"];
                break;
            case '"':
                [escaped appendString:@"\\\""];
                break;
            case '\n':
                [escaped appendString:@"\\n"];
                break;
            case '\r':
                [escaped appendString:@"\\r"];
                break;
            case '\t':
                [escaped appendString:@"\\t"];
                break;
            case '\b':
                [escaped appendString:@"\\b"];
                break;
            case '\f':
                [escaped appendString:@"\\f"];
                break;
            default:
                if (c < 0x20)
                {
                    // Escape other control characters as \u00XX
                    [escaped appendFormat:@"\\u%04x", c];
                }
                else
                {
                    [escaped appendFormat:@"%C", c];
                }
                break;
        }
    }
    return escaped;
}

@end
