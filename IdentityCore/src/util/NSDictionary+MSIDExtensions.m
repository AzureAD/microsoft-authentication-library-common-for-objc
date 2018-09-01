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

// Decodes a www-form-urlencoded string into a dictionary of key/value pairs.
// Always returns a dictionary, even if the string is nil, empty or contains no pairs
+ (NSDictionary *)msidURLFormDecode:(NSString *)string
{
    if (!string)
    {
        return nil;
    }
    
    NSMutableDictionary *configuration = [[NSMutableDictionary alloc] init];
    
    if ( nil != string && string.length != 0 )
    {
        NSArray *pairs = [string componentsSeparatedByString:@"&"];
        
        for ( NSString *pair in pairs )
        {
            NSArray *elements = [pair componentsSeparatedByString:@"="];
            
            if ( elements != nil && elements.count == 2 )
            {
                NSString *key     = [[[elements objectAtIndex:0] msidTrimmedString] msidUrlFormDecode];
                NSString *value   = [[[elements objectAtIndex:1] msidTrimmedString] msidUrlFormDecode];
                if ( nil != key && key.length != 0 )
                    [configuration setObject:value forKey:key];
            }
        }
    }
    return configuration;
}

// Encodes a dictionary consisting of a set of name/values pairs that are strings to www-form-urlencoded
// Returns nil if the dictionary is empty, otherwise the encoded value
- (NSString *)msidURLFormEncode
{
    __block NSMutableString *configuration = nil;
    
    [self enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL __unused *stop)
     {
         NSString *encodedKey = [[[key description] msidTrimmedString] msidUrlFormEncode];
         NSString *v = [value description];
         if ([value isKindOfClass:NSUUID.class])
         {
             v = ((NSUUID *)value).UUIDString;
         }
         NSString* encodedValue = [[v msidTrimmedString] msidUrlFormEncode];
         
         if ( configuration == nil )
         {
             configuration = [NSMutableString new];
             [configuration appendFormat:@"%@=%@", encodedKey, encodedValue];
         }
         else
         {
             [configuration appendFormat:@"&%@=%@", encodedKey, encodedValue];
         }
     }];
    return configuration;
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

- (BOOL)assertType:(Class)type
           ofField:(NSString *)field
           context:(id <MSIDRequestContext>)context
         errorCode:(NSInteger)errorCode
             error:(NSError **)error
{
    id fieldValue = self[field];
    if (![fieldValue isKindOfClass:type])
    {
        __auto_type message = [NSString stringWithFormat:@"%@ is not a %@.", field, type];
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     errorCode,
                                     message,
                                     nil,
                                     nil, nil, context.correlationId, nil);
        }
        
        MSID_LOG_ERROR(nil, @"%@", message);
        return NO;
    }
    
    return YES;
}

- (BOOL)assertContainsField:(NSString *)field
                    context:(id <MSIDRequestContext>)context
                      error:(NSError **)error
{
    id fieldValue = self[field];
    if (!fieldValue)
    {
        __auto_type message = [NSString stringWithFormat:@"%@ is missing.", field];
        
        if (error)
        {
            *error = MSIDCreateError(MSIDErrorDomain,
                                     MSIDErrorServerInvalidResponse,
                                     message,
                                     nil,
                                     nil, nil, context.correlationId, nil);
        }
        
        MSID_LOG_ERROR(nil, @"%@", message);
        return NO;
    }
    
    return YES;
}

@end
