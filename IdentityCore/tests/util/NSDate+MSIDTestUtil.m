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

#import "NSDate+MSIDTestUtil.h"
#import <objc/runtime.h>

static NSDate *s_mockDate;
static BOOL s_swizzleState = NO;

@implementation NSDate (MSIDTestUtil)

+ (void)mockCurrentDate:(NSDate *)date
{
    s_mockDate = date;
    
    if (!s_swizzleState)
    {
        [self swapMethods];
        
        s_swizzleState = YES;
    }
}

+ (void)reset
{
    if (s_swizzleState)
    {
        [self swapMethods];
        
        s_swizzleState = NO;
    }
}

+ (instancetype)mockDate
{
    return s_mockDate;
}

#pragma mark - Private

+ (void)swapMethods
{
    Method origMethod = class_getClassMethod(NSDate.class, @selector(date));
    Method mockMethod = class_getClassMethod(NSDate.class, @selector(mockDate));
    method_exchangeImplementations(origMethod, mockMethod);
}

@end
