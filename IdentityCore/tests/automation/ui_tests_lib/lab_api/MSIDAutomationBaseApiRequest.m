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

#import "MSIDAutomationBaseApiRequest.h"

@implementation MSIDAutomationBaseApiRequest

#pragma mark - NSCopying

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    MSIDAutomationBaseApiRequest *request = [[MSIDAutomationBaseApiRequest allocWithZone:zone] init];
    return request;
}

#pragma mark - MSIDTestAutomationRequest

- (NSURL *)requestURLWithAPIPath:(NSString *)apiPath labAccessPassword:(NSString *)labPassword
{
    NSString *requestOperationPath = [self requestOperationPath];
    
    if (!requestOperationPath)
    {
        return nil;
    }
    
    NSString *fullAPIPath = [apiPath stringByAppendingPathComponent:requestOperationPath];
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:fullAPIPath];
    
    NSMutableArray *queryItems = [NSMutableArray array];
    
    if (labPassword)
    {
        [queryItems addObject:[[NSURLQueryItem alloc] initWithName:@"code" value:labPassword]];
    }
    
    NSArray *extraQueryItems = [self queryItems];
    
    if (!extraQueryItems)
    {
        return nil;
    }
    
    [queryItems addObjectsFromArray:extraQueryItems];
    components.queryItems = queryItems;
    NSURL *resultURL = [components URL];
    return resultURL;
}

#pragma mark - Abstract

- (NSString *)requestOperationPath
{
    NSAssert(NO, @"Abstract method, implement in subclasses");
    return nil;
}

- (NSArray<NSURLQueryItem *> *)queryItems
{
    NSAssert(NO, @"Abstract method, implement in subclasses");
    return nil;
}

- (NSString *)keyvaultNameKey
{
    NSAssert(NO, @"Abstract method, implement in subclasses");
    return nil;
}

+ (MSIDAutomationBaseApiRequest *)requestWithDictionary:(__unused NSDictionary *)dictionary
{
    NSAssert(NO, @"Abstract method, implement in subclasses");
    return nil;
}

- (BOOL)shouldCacheResponse
{
    return NO;
}

#pragma mark - NSObject

- (BOOL)isEqualToRequest:(MSIDAutomationBaseApiRequest *)request
{
    if (!request)
    {
        return NO;
    }

    BOOL result = YES;
    result &= (!self.requestOperationPath && !request.requestOperationPath) || [self.requestOperationPath isEqualToString:request.requestOperationPath];
    result &= (!self.queryItems && !request.queryItems) || [self.queryItems isEqualToArray:request.queryItems];
    result &= (!self.keyvaultNameKey && !request.keyvaultNameKey) || [self.keyvaultNameKey isEqualToString:request.keyvaultNameKey];

    return result;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object
{
    if (self == object)
    {
        return YES;
    }

    if (![object isKindOfClass:MSIDAutomationBaseApiRequest.class])
    {
        return NO;
    }

    return [self isEqualToRequest:(MSIDAutomationBaseApiRequest *)object];
}

- (NSUInteger)hash
{
    NSUInteger hash = self.requestOperationPath.hash;
    hash ^= self.queryItems.hash;
    hash ^= self.keyvaultNameKey.hash;

    return hash;
}

@end
