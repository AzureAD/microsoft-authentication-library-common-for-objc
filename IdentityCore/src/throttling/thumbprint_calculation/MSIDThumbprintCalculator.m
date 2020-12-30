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


#import <Foundation/Foundation.h>
#import "MSIDThumbprintCalculator.h"


//Exclude List:
//1) Client ID - same across all requests
//2) Grant type - fixed as @"refresh_token"
@implementation MSIDThumbprintCalculator

+ (NSString *)calculateThumbprint:(NSDictionary *)requestParameters
                     filteringSet:(NSSet *)filteringSet
                shouldIncludeKeys:(BOOL)shouldIncludeKeys
{
    NSArray *sortedThumbprintRequestList = [self sortRequestParametersUsingFilteredSet:requestParameters
                                                                          filteringSet:filteringSet
                                                                     shouldIncludeKeys:shouldIncludeKeys];
    if (sortedThumbprintRequestList)
    {
        NSUInteger thumbprintKey = [self hash:sortedThumbprintRequestList];
        if (thumbprintKey == 0)
        {
            //Log Warning
            return nil;
        }
        
        else
        {
            return [NSString stringWithFormat:@"%lu", thumbprintKey];
        }
    }
    return nil;
}

+ (NSArray *)sortRequestParametersUsingFilteredSet:(NSDictionary *)requestParameters
                                      filteringSet:(NSSet *)filteringSet
                                 shouldIncludeKeys:(BOOL)shouldIncludeKeys
{
    NSMutableArray *arrayList = [NSMutableArray new];
    [requestParameters enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, __unused BOOL * _Nonnull stop) {
        if ([key isKindOfClass:[NSString class]] && [obj isKindOfClass:[NSString class]])
        {
            if ([filteringSet containsObject:key] == shouldIncludeKeys)
            {
                NSArray *thumbprintObject = [NSArray arrayWithObjects:key, obj, nil];
                [arrayList addObject:thumbprintObject];
            }
        }
    }];
    
    NSArray *sortedArrayList = [arrayList sortedArrayUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2)
    {
        return [[obj1 objectAtIndex:0] caseInsensitiveCompare:[obj2 objectAtIndex:0]];
    }];
    return sortedArrayList;
}

+ (NSUInteger)hash:(NSArray *)thumbprintRequestList
{
    if (!thumbprintRequestList || !thumbprintRequestList.count) return 0;
    
    NSUInteger hash = 0;
    for (id object in thumbprintRequestList)
    {
        if ([object isKindOfClass:[NSArray class]] &&
            ((NSArray *)object).count == 2 &&
            [object[0] isKindOfClass:[NSString class]])
        {
            hash = hash * 31 + ((NSString *)object[1]).hash;
        }
        
        else
        {
            return 0;
        }
    }
    return hash;
}

@end
