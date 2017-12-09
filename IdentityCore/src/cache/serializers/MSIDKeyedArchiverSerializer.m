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
#import "MSIDToken.h"
#import "MSIDUserInformation.h"

@interface MSIDKeyedArchiverSerializer ()

@end

@implementation MSIDKeyedArchiverSerializer

#pragma mark - MSIDTokenSerializer

- (NSData *)serialize:(MSIDToken *)token
{
    if (!token)
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
    [archiver setClassName:@"ADTokenCacheStoreItem" forClass:MSIDToken.class];
    [archiver encodeObject:token forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    
    return data;
}

- (MSIDToken *)deserialize:(NSData *)data
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    // Maintain backward compatibility with ADAL.
    [unarchiver setClass:MSIDUserInformation.class forClassName:@"ADUserInformation"];
    [unarchiver setClass:MSIDToken.class forClassName:@"ADTokenCacheStoreItem"];
    MSIDToken *token = [unarchiver decodeObjectOfClass:MSIDToken.class forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver finishDecoding];
    
    return token;
}

@end
