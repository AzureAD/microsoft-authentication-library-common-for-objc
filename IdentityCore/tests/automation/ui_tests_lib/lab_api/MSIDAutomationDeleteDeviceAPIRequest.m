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

#import "MSIDAutomationDeleteDeviceAPIRequest.h"

@implementation MSIDAutomationDeleteDeviceAPIRequest

#pragma mark - Lab Request

- (NSString *)requestOperationPath
{
    return @"DeleteDevice";
}

- (NSString *)httpMethod
{
    return @"POST";
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSMutableArray *queryItems = [NSMutableArray array];
    
    if (self.userUPN)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"upn" value:self.userUPN]];
    }
    
    if (self.deviceGUID)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"deviceid" value:self.deviceGUID]];
    }
    
    return queryItems;
}

- (NSString *)requestOperationCodeKey
{
    return @"delete_device_api_code";
}

- (NSUInteger)hash
{
    NSUInteger hash = self.userUPN.hash;
    hash ^= self.deviceGUID.hash;

    return hash;
}

@end
