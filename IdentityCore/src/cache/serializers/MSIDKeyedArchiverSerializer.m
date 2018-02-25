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
#import "MSIDTokenCacheItem.h"

@interface MSIDKeyedArchiverSerializer ()
{
    Class _classToSerialize;
}

@end

@implementation MSIDKeyedArchiverSerializer

#pragma mark - Init

- (instancetype)initWithType:(MSIDSerializerType)type
{
    self = [super init];
    
    if (self)
    {
        switch (type) {
            case MSIDTokenSerializerType:
                _classToSerialize = MSIDTokenCacheItem.class;
                break;
                
            case MSIDAccountSerializerType:
                // TODO: set correct serializer type
                _classToSerialize = MSIDCacheItem.class;
                break;
                
            default:
                _classToSerialize = MSIDCacheItem.class;
                break;
        }
    }
    return self;
}

#pragma mark - MSIDCacheItemSerializer

- (NSData *)serialize:(MSIDCacheItem *)item
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
    [archiver setClassName:@"ADTokenCacheStoreItem" forClass:_classToSerialize];
    [archiver encodeObject:item forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    
    return data;
}

- (MSIDCacheItem *)deserialize:(NSData *)data
{
    if (!data)
    {
        return nil;
    }
    
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    // Maintain backward compatibility with ADAL.
    [unarchiver setClass:MSIDUserInformation.class forClassName:@"ADUserInformation"];
    [unarchiver setClass:_classToSerialize forClassName:@"ADTokenCacheStoreItem"];
    MSIDCacheItem *token = [unarchiver decodeObjectOfClass:_classToSerialize forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    
    return token;
}

@end
