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

#import "MSIDTokenCacheKey.h"
#import "MSIDTokenType.h"

@implementation MSIDTokenCacheKey

- (id)initWithAccount:(NSString *)account
              service:(NSString *)service
              generic:(NSData *)generic
                 type:(NSNumber *)type
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.account = account;
    self.service = service;
    self.type = type;
    self.generic = generic;
    
    return self;
}

+ (MSIDTokenCacheKey *)queryForAllItems
{
    return [[MSIDTokenCacheKey alloc] initWithAccount:nil service:nil generic:nil type:nil];
}

+ (NSString *)familyClientId:(NSString *)familyId
{
    if (!familyId)
    {
        familyId = @"1";
    }
    
    return [NSString stringWithFormat:@"foci-%@", familyId];
}

- (NSString *)logDescription
{
    // TODO
    return nil;
}

- (NSString *)piiLogDescription
{
    // TODO
    return nil;
}

@end
