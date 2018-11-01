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
#import "MSIDIntuneInMemoryCacheDataSource.h"

@interface MSIDIntuneEnrollmentIdsCacheTests : XCTestCase

@property (nonatomic) MSIDIntuneEnrollmentIdsCache *cache;
@property (nonatomic) MSIDCache *inMemoryStorage;

@end

@implementation MSIDIntuneEnrollmentIdsCacheTests

- (void)setUp
{
    self.inMemoryStorage = [MSIDCache new];
    __auto_type dictionary = @{
                               @"enrollment_ids": @[
                                       @{
                                           @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                           @"oid": @"6eec576f-dave-416a-9c4a-536b178a194a",
                                           @"home_account_id": @"1e4dd613-dave-4527-b50a-97aca38b57ba",
                                           @"user_id": @"dave@contoso.com",
                                           @"enrollment_id": @"64d0557f-dave-4193-b630-8491ffd3b180"
                                           },
                                       @{
                                           @"tid": @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1",
                                           @"oid": @"d3444455-mike-4271-b6ea-e499cc0cab46",
                                           @"home_account_id": @"60406d5d-mike-41e1-aa70-e97501076a22",
                                           @"user_id": @"mike@contoso.com",
                                           @"enrollment_id": @"adf79e3f-mike-454d-9f0f-2299e76dbfd5"
                                        },
                                       ]
                               };
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];
    
    __auto_type dataSource = [[MSIDIntuneInMemoryCacheDataSource alloc] initWithCache:self.inMemoryStorage];
    self.cache = [[MSIDIntuneEnrollmentIdsCache alloc] initWithDataSource:dataSource];
}

- (void)tearDown
{
}

#pragma mark - enrollmentIdForUserId

- (void)testEnrollmentIdForUserId_whenUserIdIsNil_shouldReturnNil
{
    NSString *userId;
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserId_whenUserIdIsNotInCache_shouldReturnNil
{
    NSString *userId = @"qwe@contoso.com";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserId_whenCacheIsInvalid_shouldReturnNilAndError
{
    NSString *userId = @"mike@contoso.com";
    [self corruptCache];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

- (void)testEnrollmentIdForUserId_whenUserIdInCache_shouldReturnId
{
    NSString *userId = @"mike@contoso.com";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertEqualObjects(@"adf79e3f-mike-454d-9f0f-2299e76dbfd5", enrollmentId);
    XCTAssertNil(error);
}

#pragma mark - enrollmentIdForUserObjectId:tenantId

- (void)testEnrollmentIdForUserObjectIdTenantId_whenObjectIdIsNil_shouldReturnNil
{
    NSString *objectId;
    NSString *tenantId = @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserObjectIdTenantId_whenTenantIdIsNil_shouldReturnNil
{
    NSString *objectId = @"d3444455-mike-4271-b6ea-e499cc0cab46";
    NSString *tenantId;
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserObjectIdTenantId_whenTidAndOidMatch_shouldReturnId
{
    NSString *objectId = @"d3444455-mike-4271-b6ea-e499cc0cab46";
    NSString *tenantId = @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertEqualObjects(@"adf79e3f-mike-454d-9f0f-2299e76dbfd5", enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserObjectIdTenantId_whenTidDoesntMatchOidMatch_shouldReturnNil
{
    NSString *objectId = @"d3444455-mike-4271-b6ea-e499cc0cab46";
    NSString *tenantId = @"qwe";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserObjectIdTenantId_whenTidMatchOidDoesntMatch_shouldReturnNil
{
    NSString *objectId = @"qwe";
    NSString *tenantId = @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForUserObjectIdTenantId_whenCacheIsInvalid_shouldReturnNilAndError
{
    NSString *objectId = @"d3444455-mike-4271-b6ea-e499cc0cab46";
    NSString *tenantId = @"fda5d5d9-17c3-4c29-9cf9-a27c3d3f03e1";
    [self corruptCache];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserObjectId:objectId tenantId:tenantId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

#pragma mark - enrollmentIdForHomeAccountId

- (void)testEnrollmentIdForHomeAccountId_whenHomeAccountIdIsNil_shouldReturnNil
{
    NSString *homeAccountId;
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenCacheIsInvalid_shouldReturnNilAndError
{
    NSString *homeAccountId;
    [self corruptCache];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenHomeAccountIdIsNotInCache_shouldReturnNil
{
    NSString *homeAccountId = @"qwe";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountId_whenHomeAccountIdInCache_shouldReturnId
{
    NSString *homeAccountId = @"60406d5d-mike-41e1-aa70-e97501076a22";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId context:nil error:&error];
    
    XCTAssertEqualObjects(@"adf79e3f-mike-454d-9f0f-2299e76dbfd5", enrollmentId);
    XCTAssertNil(error);
}

#pragma mark - enrollmentIdForHomeAccountId:userId

- (void)testEnrollmentIdForHomeAccountIdUserId_whenHomeAccountIdIsNil_shouldReturnId
{
    NSString *homeAccountId;
    NSString *userId = @"mike@contoso.com";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId legacyUserId:userId context:nil error:&error];
    
    XCTAssertEqualObjects(@"adf79e3f-mike-454d-9f0f-2299e76dbfd5", enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountIdUserId_whenHomeAccountIdIsNilUserIdNotInCache_shouldReturnFirstAvailableId
{
    NSString *homeAccountId;
    NSString *userId = @"qwe@contoso.com";
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId legacyUserId:userId context:nil error:&error];
    
    XCTAssertEqualObjects(@"64d0557f-dave-4193-b630-8491ffd3b180", enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdForHomeAccountIdUserId_whenCacheIsInvalid_shouldReturnNilAndError
{
    NSString *homeAccountId;
    NSString *userId;
    [self corruptCache];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForHomeAccountId:homeAccountId legacyUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

#pragma mark - enrollmentIdIfAvailable

- (void)testEnrollmentIdIfAvailable_whenCacheIsEmpty_shouldReturnNil
{
    [self.inMemoryStorage removeAllObjects];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdIfAvailableWithContext:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNil(error);
}

- (void)testEnrollmentIdIfAvailable_whenCacheIsInvalid_shouldReturnNilAndError
{
    [self corruptCache];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdIfAvailableWithContext:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

- (void)testEnrollmentIdIfAvailable_whenCacheIsNotEmpty_shouldReturnFirstId
{
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdIfAvailableWithContext:nil error:&error];
    
    XCTAssertEqualObjects(@"64d0557f-dave-4193-b630-8491ffd3b180", enrollmentId);
    XCTAssertNil(error);
}

#pragma mark - Invalid data source

- (void)testEnrollmentIdForUserId_whenCacheContainsNotJsonObject_shoudlReturnNilAndError
{
    NSString *userId;
    [self.inMemoryStorage setObject:@"not a json dictionary" forKey:@"intune_app_protection_enrollment_id_V1"];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

- (void)testEnrollmentIdForUserId_whenCacheContainsJsonButValueUnderEnrollmentIdsKeyIsNotArray_shoudlReturnNilAndError
{
    NSString *userId;
    __auto_type dictionary = @{@"enrollment_ids": @"some string"};
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

- (void)testEnrollmentIdForUserId_whenCacheContainsJsonButEnrollmentIdIsNotString_shoudlReturnNilAndError
{
    NSString *userId;
    __auto_type dictionary = @{
                               @"enrollment_ids": @[
                                       @{ @"enrollment_id": @1 },
                                       @{ @"enrollment_id": @2 },
                                       ]
                               };
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];
    
    NSError *error;
    __auto_type enrollmentId = [self.cache enrollmentIdForUserId:userId context:nil error:&error];
    
    XCTAssertNil(enrollmentId);
    XCTAssertNotNil(error);
}

#pragma mark - clear

- (void)testClear_whenCacheIsNotEmpty_shouldDeleteOnlyIntuneKeys
{
    [self.inMemoryStorage setObject:@{@"key2": @"value2"} forKey:@"intune_app_protection_enrollment_id_V1"];
    __auto_type jsonDicionary = @{@"key": @"value"};
    [self.inMemoryStorage setObject:jsonDicionary forKey:@"custom_key"];
    
    [self.cache clear];
    
    XCTAssertEqual(self.inMemoryStorage.count, 1);
    XCTAssertEqualObjects(jsonDicionary, [self.inMemoryStorage objectForKey:@"custom_key"]);
}

#pragma mark - Private

- (void)corruptCache
{
    __auto_type dictionary = @{ @"enrollment_ids": @1 };
    [self.inMemoryStorage setObject:dictionary forKey:@"intune_app_protection_enrollment_id_V1"];
}

@end
