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

#import "MSIDUrlRequestSerializer.h"

@implementation MSIDUrlRequestSerializer

- (NSURLRequest *)serializeWithRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters
{
    NSParameterAssert(request);
    
    if (!parameters) return request;
    
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    if ([self shouldEncodeParametersInURL:request])
    {
        NSAssert(mutableRequest.URL, NULL);
        
        __auto_type urlComponents = [[NSURLComponents alloc] initWithURL:request.URL resolvingAgainstBaseURL:YES];
        NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray new];
        
        for (id key in parameters)
        {
            id value = parameters[key];
            
            NSAssert([value isKindOfClass:NSString.class], NULL);
            NSAssert([key isKindOfClass:NSString.class], NULL);
            
            if (![key isKindOfClass:NSString.class] || ![value isKindOfClass:NSString.class])
            {
                MSID_LOG_WARN(nil, @"Ignoring key/value.");
                MSID_LOG_WARN_PII(nil, @"Ignoring key: %@ value: %@", key, value);
                continue;
            }
            __auto_type item = [[NSURLQueryItem alloc] initWithName:key value:value];
            [queryItems addObject:item];
        }
        
        urlComponents.queryItems = queryItems;
        
        mutableRequest.URL = urlComponents.URL;
    }
    else
    {
        mutableRequest.HTTPBody = [[parameters msidURLFormEncode] dataUsingEncoding:NSUTF8StringEncoding];
        [mutableRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [mutableRequest setValue:[NSString stringWithFormat:@"%ld", (unsigned long)mutableRequest.HTTPBody.length] forHTTPHeaderField:@"Content-Length"];
    }
    
    return mutableRequest;
}

#pragma mark - Private

- (BOOL)shouldEncodeParametersInURL:(NSURLRequest *)request
{
    __auto_type urlMethods = @[@"GET", @"HEAD", @"DELETE"];
    
    return [urlMethods containsObject:request.HTTPMethod.uppercaseString];
}

@end
