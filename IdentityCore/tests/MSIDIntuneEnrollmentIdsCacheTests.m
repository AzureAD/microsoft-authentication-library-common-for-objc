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

#import <XCTest/XCTest.h>
#import "MSIDIntuneEnrollmentIdsCache.h"
#import "MSIDCache.h"
#import "MSIDIntuneInMemmoryCacheDataSource.h"

@interface MSIDIntuneEnrollmentIdsCacheTests : XCTestCase

@property (nonatomic) MSIDIntuneEnrollmentIdsCache *cache;
@property (nonatomic) MSIDCache *inMemoryStorage;

@end

@implementation MSIDIntuneEnrollmentIdsCacheTests

- (void)setUp
{
    self.inMemoryStorage = [MSIDCache new];
    __auto_type dictionary = @{
                               @"login.microsoftonline.com": @"https://www.microsoft.com/intune",
                               @"login.microsoftonline.de": @"https://www.microsoft.com/intune-de",
                               @"login.windows.net": @"https://www.microsoft.com/windowsIntune"
                               };
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_mam_resource_V1"];
    
    __auto_type dataSource = [[MSIDIntuneInMemmoryCacheDataSource alloc] initWithCache:self.inMemoryStorage];
    self.cache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:dataSource];
}

- (void)tearDown
{
}

#pragma mark - Tests

//- (void)testEnrollmentIdForUserId
//{
//    NSError *error;
//    [self.cache enrollmentIdForUserId:@"" error:&error];
//}

@end
