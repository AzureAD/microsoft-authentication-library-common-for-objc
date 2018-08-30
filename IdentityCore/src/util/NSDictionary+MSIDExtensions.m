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

#import <Foundation/Foundation.h>
#import "NSDictionary+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"

@implementation NSDictionary (MSIDExtensions)

+ (NSDictionary *)msidDictionaryFromString:(NSString *)string
{
    return [self msidDictionaryFromString:string decode:NO];
}

// Decodes a www-form-urlencoded string into a dictionary of key/value pairs.
// Always returns a dictionary, even if the string is nil, empty or contains no pairs
+ (NSDictionary *)msidURLFormDecode:(NSString *)string
{
    return [self msidDictionaryFromString:string decode:YES];
}

+ (NSDictionary *)msidDictionaryFromString:(NSString *)string
                                    decode:(BOOL)decode
{
    if (!string)
    {
        return nil;
    }
    
    NSArray *queries = [string componentsSeparatedByString:@"&"];
    NSMutableDictionary *queryDict = [NSMutableDictionary new];
    
    for (NSString *query in queries)
    {
        NSArray *queryElements = [query componentsSeparatedByString:@"="];
        if (queryElements.count > 2)
        {
            MSID_LOG_WARN(nil, @"Query parameter must be a form key=value");
            continue;
        }
        
        NSString *key = decode ? [queryElements[0] msidTrimmedString].msidUrlFormDecode : [queryElements[0] msidTrimmedString];
        if ([NSString msidIsStringNilOrBlank:key])
        {
            MSID_LOG_WARN(nil, @"Query parameter must have a key");
            continue;
        }
        
        NSString *value = @"";
        if (queryElements.count == 2)
        {
            value = decode ? [queryElements[1] msidTrimmedString].msidUrlFormDecode : [queryElements[1] msidTrimmedString];
        }
        
        [queryDict setValue:value forKey:key];
    }
    
    return queryDict;
}

// Encodes a dictionary consisting of a set of name/values pairs that are strings to www-form-urlencoded
// Returns nil if the dictionary is empty, otherwise the encoded value
- (NSString *)msidURLFormEncode
{
    __block NSMutableString *encodedString = nil;
    
    [self enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL __unused *stop)
     {
         NSString *encodedKey = [[[key description] msidTrimmedString] msidUrlFormEncode];
         
         if (!encodedString)
         {
             encodedString = [NSMutableString new];
         }
         else
         {
             [encodedString appendString:@"&"];
         }
         
         [encodedString appendFormat:@"%@", encodedKey];
         
         NSString *v = [value description];
         if ([value isKindOfClass:NSUUID.class])
         {
             v = ((NSUUID *)value).UUIDString;
         }
         NSString *encodedValue = [[v msidTrimmedString] msidUrlFormEncode];
         
         if (![NSString msidIsStringNilOrBlank:encodedValue])
         {
             [encodedString appendFormat:@"=%@", encodedValue];
         }
         
     }];
    return encodedString;
}

- (NSDictionary *)dictionaryByRemovingFields:(NSArray *)fieldsToRemove
{
    NSMutableDictionary *mutableDict = [self mutableCopy];
    [mutableDict removeObjectsForKeys:fieldsToRemove];
    return mutableDict;
}

- (NSArray<NSURLQueryItem *> *)urlQueryItemsArray
{
    NSMutableArray<NSURLQueryItem *> *array = [NSMutableArray new];
    
    for (id key in self.allKeys)
    {
        
        NSString *value = [self[key] isKindOfClass:NSUUID.class] ?
        ((NSUUID *)self[key]).UUIDString : [self[key] description];
        
        [array addObject:[NSURLQueryItem queryItemWithName:[[key description] msidUrlFormEncode]
                                                     value:[value description]]];
    }
    
    return array;
}


@end
