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

#import "MSIDJsonSerializer.h"
#import "MSIDJsonObject.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "NSJSONSerialization+MSIDExtensions.h"

@implementation MSIDJsonSerializer

- (NSData *)serialize:(NSDictionary *)jsonDictionary
{
    if (!jsonDictionary)
    {
        return nil;
    }
    
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonDictionary
                                                   options:0
                                                     error:&error];
    if (error)
    {
        MSID_LOG_ERROR(nil, @"Failed to serialize token.");
        MSID_LOG_ERROR_PII(nil, @"Failed to serialize token, error: %@", error);
        return nil;
    }

    return data;
}

- (NSDictionary *)deserialize:(NSData *)data
{
    NSError *error = nil;
    NSDictionary *json = [self deserializeJSON:data error:&error];
    
    if (error)
    {
        MSID_LOG_ERROR(nil, @"Failed to deserialize json object.");
        MSID_LOG_ERROR_PII(nil, @"Failed to deserialize json object, error: %@", error);
        return nil;
    }
    
    return json;
}

#pragma mark - Private

- (NSDictionary *)deserializeJSON:(NSData *)data error:(NSError *__autoreleasing *)error
{
    if (!data)
    {
        if (error)
        {
            NSString *errorDescription = [NSString stringWithFormat:@"Attempt to initialize JSON object (%@) with nil data", NSStringFromClass(self.class)];
            *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, errorDescription, nil, nil, nil, nil, nil);
        }
        
        return nil;
    }
    
    NSDictionary *json = [NSJSONSerialization msidNormalizedDictionaryFromJsonData:data error:error];
    
    return json;
}

#pragma mark - Token

- (NSData *)serializeCredentialCacheItem:(MSIDCredentialCacheItem *)item
{
    return [self serialize:item.jsonDictionary];
}

- (MSIDCredentialCacheItem *)deserializeCredentialCacheItem:(NSData *)data
{
    NSDictionary *jsonDictionary = [self deserialize:data];

    NSError *error = nil;

    MSIDCredentialCacheItem *item = [[MSIDCredentialCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    if (!item)
    {
        MSID_LOG_WARN(nil, @"Failed to deserialize credential %@", error);
        return nil;
    }

    return item;
}

#pragma mark - Account

- (NSData *)serializeAccountCacheItem:(MSIDAccountCacheItem *)item
{
    return [self serialize:item.jsonDictionary];
}

- (MSIDAccountCacheItem *)deserializeAccountCacheItem:(NSData *)data
{
    NSDictionary *jsonDictionary = [self deserialize:data];

    NSError *error = nil;

    MSIDAccountCacheItem *item = [[MSIDAccountCacheItem alloc] initWithJSONDictionary:jsonDictionary error:&error];

    if (!item)
    {
        MSID_LOG_WARN(nil, @"Failed to deserialize credential %@", error);
        return nil;
    }

    return item;
}

@end
