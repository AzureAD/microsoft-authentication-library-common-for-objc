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

#import "MSIDHelpers.h"
#import "MSIDConstants.h"
#import "MSIDDeviceId.h"

@implementation MSIDHelpers

+ (NSInteger)msidIntegerValue:(id)value
{
    if (value && [value respondsToSelector:@selector(integerValue)])
    {
        return [value integerValue];
    }
    
    return 0;
}

+ (NSString *)normalizeUserId:(NSString *)userId
{
    if (!userId)
    {
        return nil;
    }
    NSString *normalized = [userId msidTrimmedString].lowercaseString;

    return normalized.length ? normalized : nil;
}

+ (NSString *)msidAddToURLString:(NSString *)urlString withParameters:(NSDictionary<NSString *, NSString *> *)params
{
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return nil;
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
    if (!components) return nil;
    
    NSMutableDictionary *newQuery = [[NSMutableDictionary alloc] init];
    
    NSDictionary *oldQuery = [url msidQueryParameters];
    if (oldQuery)
    {
        [newQuery addEntriesFromDictionary:oldQuery];
    }
    
    if (params)
    {
        [newQuery addEntriesFromDictionary:params];
    }
    
    NSArray<NSURLQueryItem *> *queryItems = [newQuery urlQueryItemsArray];
    if (queryItems && queryItems.count > 0)
    {
        components.queryItems = queryItems;
    }
    
    return [[components URL] absoluteString];
}

+ (NSString *)msidAddClientVersionToURLString:(NSString *)urlString;
{
    return [self msidAddToURLString:urlString withParameters:@{MSID_VERSION_KEY:MSIDDeviceId.deviceId[MSID_VERSION_KEY]}];
}

@end
