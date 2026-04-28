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

#import "MSIDHttpRequestHeaderValidator.h"

static NSArray<NSString *> *s_reservedPrefixes = nil;

@interface MSIDHttpRequestHeaderValidator ()

- (BOOL)isValidHeaderFieldName:(nonnull NSString *)fieldName;
- (BOOL)isMissingRequiredXPrefix:(nonnull NSString *)fieldName;
- (nullable NSString *)reservedPrefixForFieldName:(nonnull NSString *)fieldName;

@end

@implementation MSIDHttpRequestHeaderValidator

+ (void)initialize
{
    if (self == [MSIDHttpRequestHeaderValidator class])
    {
        s_reservedPrefixes = @[@"x-ms-", @"x-client-", @"x-broker-", @"x-app-"];
    }
}

- (NSDictionary<NSString *, NSString *> *)validHeadersFromHeaders:(NSDictionary<NSString *, NSString *> *)headers
{
    NSMutableDictionary<NSString *, NSString *> *validHeaders = [NSMutableDictionary new];
    for (NSString *field in headers)
    {
        if ([self isValidHeaderFieldName:field])
        {
            validHeaders[field] = headers[field];
        }
    }
    return [validHeaders copy];
}

- (BOOL)isMissingRequiredXPrefix:(NSString *)fieldName
{
    return ![fieldName.lowercaseString hasPrefix:@"x-"];
}

- (nullable NSString *)reservedPrefixForFieldName:(NSString *)fieldName
{
    NSString *lowercaseName = fieldName.lowercaseString;
    for (NSString *reserved in s_reservedPrefixes)
    {
        if ([lowercaseName hasPrefix:reserved])
        {
            return reserved;
        }
    }
    return nil;
}

- (BOOL)isValidHeaderFieldName:(NSString *)fieldName
{
    if ([self isMissingRequiredXPrefix:fieldName])
    {
        return NO;
    }
    if ([self reservedPrefixForFieldName:fieldName] != nil)
    {
        return NO;
    }
    return YES;
}

@end
