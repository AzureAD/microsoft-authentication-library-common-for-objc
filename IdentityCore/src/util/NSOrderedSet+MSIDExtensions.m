//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import "NSOrderedSet+MSIDExtensions.h"
#import "NSString+MSIDExtensions.h"

@implementation NSOrderedSet (MSIDExtensions)

- (NSString *)msidToString
{
    return [NSString msidStringFromOrderedSet:self];
}

+ (NSOrderedSet *)msidOrderedSetFromString:(NSString *)string
{
    return [self msidOrderedSetFromString:string normalize:YES];
}

+ (NSOrderedSet *)msidOrderedSetFromString:(NSString *)string normalize:(BOOL)normalize
{
    NSMutableOrderedSet<NSString *> *scope = [NSMutableOrderedSet<NSString *> new];
    NSArray* parts = [string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
    for (NSString *part in parts)
    {
        if (![NSString msidIsStringNilOrBlank:part])
        {
            if (normalize)
            {
                [scope addObject:part.msidTrimmedString.lowercaseString];
            }
            else
            {
                [scope addObject:part.msidTrimmedString];
            }
        }
    }
    return scope;
}

@end

