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

#import "MSIDKeyedArchiverSerializer.h"
#import "MSIDUserInformation.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDLegacyTokenCacheItem.h"

@implementation MSIDKeyedArchiverSerializer

#pragma mark - Private

- (NSData *)serialize:(MSIDCredentialCacheItem *)item
{
    if (!item)
    {
        return nil;
    }
    
    NSMutableData *data = [NSMutableData data];
    
    // In order to customize the archiving process Apple recommends to create an instance of the archiver and
    // customize it (instead of using share NSKeyedArchiver).
    // See here: https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Archiving/Articles/creating.html
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    // Maintain backward compatibility with ADAL.
    [archiver setClassName:@"ADUserInformation" forClass:MSIDUserInformation.class];
    [archiver setClassName:@"ADTokenCacheStoreItem" forClass:MSIDLegacyTokenCacheItem.class];
    [archiver encodeObject:item forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    
    return data;
}

- (MSIDLegacyTokenCacheItem *)deserialize:(NSData *)data className:(Class)className
{
    if (!data)
    {
        return nil;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    // Maintain backward compatibility with ADAL.
    [unarchiver setClass:MSIDUserInformation.class forClassName:@"ADUserInformation"];
    [unarchiver setClass:className forClassName:@"ADTokenCacheStoreItem"];
    MSIDLegacyTokenCacheItem *token = [unarchiver decodeObjectOfClass:className forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    
    return token;
}

#pragma mark - Token

- (NSData *)serializeCredentialCacheItem:(MSIDCredentialCacheItem *)item
{
    if (![item isKindOfClass:[MSIDLegacyTokenCacheItem class]])
    {
        MSID_LOG_WARN(nil, @"Asked to serialize MSIDCredentialCacheItem, which is unsupported");
        return nil;
    }

    return [self serialize:item];
}

- (MSIDCredentialCacheItem *)deserializeCredentialCacheItem:(NSData *)data
{
    MSIDLegacyTokenCacheItem *item = [self deserialize:data className:MSIDLegacyTokenCacheItem.class];
    
    // Because theoretically any item data can be passed in here for deserialization,
    // we need to ensure that the correct item got deserialized
    if ([item isKindOfClass:[MSIDLegacyTokenCacheItem class]])
    {
        return (MSIDLegacyTokenCacheItem *) item;
    }
    
    return nil;
}

#pragma mark - Account

- (NSData *)serializeAccountCacheItem:(MSIDAccountCacheItem *)item
{
    // Account cache item doesn't support keyed archiver serialization
    return nil;
}

- (MSIDAccountCacheItem *)deserializeAccountCacheItem:(NSData *)data
{
    // Account cache item doesn't support keyed archiver deserialization
    return nil;
}

@end
