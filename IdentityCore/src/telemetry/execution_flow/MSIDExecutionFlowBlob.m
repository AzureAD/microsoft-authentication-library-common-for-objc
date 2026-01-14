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
            @"t": tag, // Activity or tag name
            @"ts": ts, // Time spent since the operation/startDate was created
            @"tid": tid, // Thread id
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
    if ([@[@"t", @"ts", @"tid"] containsObject:key])
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

- (NSString *)blobToStringWithKeys:(NSSet<NSString *>*)queryKeys
{
    NSDictionary *dict = self.blob.toDictionary;
    NSMutableString *result = [NSMutableString stringWithString:@"{"];
    
    // Always include required fields in specific order: t, tid, ts
    [result appendFormat:@"\"t\":\"%@\",\"tid\":%@,\"ts\":%@", [self escapeJSONString:dict[@"t"]], dict[@"tid"], dict[@"ts"]];
    
    // Add all other fields
    NSSet *reservedKeys = [NSSet setWithArray:@[@"t", @"tid", @"ts"]];
    for (NSString *key in dict)
    {
        if ([reservedKeys containsObject:key] || (![queryKeys containsObject:key] && queryKeys.count != 0))
        {
            continue;
        }
        
        id value = dict[key];
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

@end
