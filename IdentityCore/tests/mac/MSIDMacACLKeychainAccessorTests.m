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
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDMacACLKeychainAccessor.h"
#import "MSIDKeychainUtil+Internal.h"

@interface MSIDMacACLKeychainAccessorTests : XCTestCase

@end

@implementation MSIDMacACLKeychainAccessorTests

- (void)setUp
{
    [super setUp];
    
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSDictionary *attributes = @{(id)kSecAttrLabel : @"my-xctest-msal-label"};
    [accessor clearWithAttributes:attributes context:nil error:nil];
}

- (void)testInitWithTrustedApplications_whenNilTrustedApplications_shouldInitWithSelfOnly
{
    NSError *error = nil;
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:&error];
    
    XCTAssertNotNil(accessor);
    XCTAssertNil(error);
    
    XCTAssertNotNil(accessor.accessControlForSharedItems);
    
    NSArray *sharedItems = [self trustedAppsForAccess:accessor.accessControlForSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([sharedItems count], 1);
    XCTAssertEqualObjects(sharedItems[0], [self executablePath]);
    
    XCTAssertNotNil(accessor.accessControlForNonSharedItems);
    NSArray *nonSharedItems = [self trustedAppsForAccess:accessor.accessControlForNonSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([nonSharedItems count], 1);
    XCTAssertEqualObjects(nonSharedItems[0], [self executablePath]);
}

- (void)testInitWithTrustedApplications_whenEmptyTrustedApplications_shouldInitWithSelfOnly
{
    NSError *error = nil;
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:@[] accessLabel:@"label" error:&error];
    
    XCTAssertNotNil(accessor);
    XCTAssertNil(error);
    
    XCTAssertNotNil(accessor.accessControlForSharedItems);
    
    NSArray *sharedItems = [self trustedAppsForAccess:accessor.accessControlForSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([sharedItems count], 1);
    XCTAssertEqualObjects(sharedItems[0], [self executablePath]);
    
    XCTAssertNotNil(accessor.accessControlForNonSharedItems);
    NSArray *nonSharedItems = [self trustedAppsForAccess:accessor.accessControlForNonSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([nonSharedItems count], 1);
    XCTAssertEqualObjects(nonSharedItems[0], [self executablePath]);
}

- (void)testInitWithTrustedApplications_whenProvidedTrustedApplications_shouldShareCacheWithTrustedApps
{
    NSString *path1 = @"/Applications/Safari.app\0";
    SecTrustedApplicationRef appRef1 = nil;
    SecTrustedApplicationCreateFromPath([path1 UTF8String], &appRef1);
    id appReference = (__bridge_transfer id)appRef1;
    XCTAssertNotNil(appReference);
    
    NSError *error = nil;
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:@[appReference] accessLabel:@"label" error:&error];
    
    XCTAssertNotNil(accessor);
    XCTAssertNil(error);
    
    XCTAssertNotNil(accessor.accessControlForSharedItems);
    
    NSArray *sharedItems = [self trustedAppsForAccess:accessor.accessControlForSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([sharedItems count], 2);
    XCTAssertEqualObjects(sharedItems[0], path1);
    XCTAssertEqualObjects(sharedItems[1], [self executablePath]);
    
    XCTAssertNotNil(accessor.accessControlForNonSharedItems);
    NSArray *nonSharedItems = [self trustedAppsForAccess:accessor.accessControlForNonSharedItems authorizationTag:kSecACLAuthorizationDecrypt];
    XCTAssertEqual([nonSharedItems count], 1);
    XCTAssertEqualObjects(nonSharedItems[0], [self executablePath]);
}

- (void)testSaveData_withNilData_shouldReturnNoAndFillError
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSData *data = nil;
    NSError *error = nil;
    BOOL result = [accessor saveData:data attributes:@{} context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testSaveData_whenItemDoesntExist_shouldCreateItem
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSError *error = nil;
    NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{(id)kSecAttrService : @"test-service",
                                 (id)kSecAttrAccount : @"test-account",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    BOOL result = [accessor saveData:data attributes:attributes context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSData *writtenData = [accessor getDataWithAttributes:attributes context:nil error:&error];
    XCTAssertNotNil(writtenData);
    XCTAssertNil(error);
    XCTAssertEqualObjects(writtenData, data);
}

- (void)testSaveData_whenItemExists_shouldUpdateItem
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSError *error = nil;
    NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{(id)kSecAttrService : @"test-service",
                                 (id)kSecAttrAccount : @"test-account",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    BOOL result = [accessor saveData:data attributes:attributes context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    NSData *updatedData = [@"test data 2" dataUsingEncoding:NSUTF8StringEncoding];
    BOOL updateResult = [accessor saveData:updatedData attributes:attributes context:nil error:&error];
    XCTAssertTrue(updateResult);
    XCTAssertNil(error);
    
    NSData *writtenData = [accessor getDataWithAttributes:attributes context:nil error:&error];
    XCTAssertNotNil(writtenData);
    XCTAssertNil(error);
    XCTAssertEqualObjects(writtenData, updatedData);
}

- (void)testRemoveItem_whenItemDoesntExist_shouldNotRemoveOtherItems
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSError *error = nil;
    NSDictionary *attributes = @{(id)kSecAttrService : @"test-service",
                                 (id)kSecAttrAccount : @"test-account",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};

    BOOL result = [accessor removeItemWithAttributes:attributes context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testRemoveItem_whenItemExists_shouldRemoveItem
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSError *error = nil;
    NSData *data = [@"test data" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data2 = [@"test data 2" dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{(id)kSecAttrService : @"test-service",
                                 (id)kSecAttrAccount : @"test-account",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};
    NSDictionary *attributes2 = @{(id)kSecAttrService : @"test-service2",
                                  (id)kSecAttrAccount : @"test-account2",
                                  (id)kSecAttrLabel : @"my-xctest-msal-label"};
    BOOL result = [accessor saveData:data attributes:attributes context:nil error:&error];
    XCTAssertTrue(result);
    result = [accessor saveData:data2 attributes:attributes2 context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    BOOL removalResult = [accessor removeItemWithAttributes:attributes context:nil error:&error];
    XCTAssertTrue(removalResult);
    XCTAssertNil(error);
    
    NSData *writtenData1 = [accessor getDataWithAttributes:attributes context:nil error:&error];
    XCTAssertNil(writtenData1);
    XCTAssertNil(error);
    
    NSData *writtenData2 = [accessor getDataWithAttributes:attributes2 context:nil error:&error];
    XCTAssertNotNil(writtenData2);
    XCTAssertNil(error);
    XCTAssertEqualObjects(writtenData2, data2);
}

- (void)testGetDataWithAttributes_whenNoDataFound_shouldReturnNil
{
    MSIDMacACLKeychainAccessor *accessor = [[MSIDMacACLKeychainAccessor alloc] initWithTrustedApplications:nil accessLabel:@"label" error:nil];
    
    NSError *error = nil;
    NSDictionary *attributes = @{(id)kSecAttrService : @"test-service",
                                 (id)kSecAttrAccount : @"test-account",
                                 (id)kSecAttrLabel : @"my-xctest-msal-label"};

    NSData *writtenData = [accessor getDataWithAttributes:attributes context:nil error:&error];
    XCTAssertNil(writtenData);
    XCTAssertNil(error);
}

#pragma mark - Helper

- (NSString *)executablePath
{
    return [NSString stringWithFormat:@"%@\0", [[NSBundle mainBundle] executablePath]];
}

- (NSArray *)trustedAppsForAccess:(id)access authorizationTag:(CFStringRef)authorizationTag
{
    SecAccessRef accessRef = (__bridge SecAccessRef)access;
    NSArray *sharedACLs = (__bridge_transfer NSArray*)SecAccessCopyMatchingACLList(accessRef, authorizationTag);
    NSMutableArray *resultArray = [NSMutableArray new];
    
    for (id acl in sharedACLs)
    {
        CFArrayRef trustedAppsList = nil;
        CFStringRef description = nil;
        SecKeychainPromptSelector selector;
        SecACLCopyContents((__bridge SecACLRef)acl, &trustedAppsList, &description, &selector);
        
        if (!trustedAppsList)
        {
            return nil;
        }
        
        NSArray *trustedApps = (__bridge NSArray*)trustedAppsList;
        
        for (id trustedApp in trustedApps)
        {
            SecTrustedApplicationRef trustedAppRef = (__bridge SecTrustedApplicationRef)trustedApp;
            CFDataRef trustedDataRef = NULL;
            SecTrustedApplicationCopyData(trustedAppRef, &trustedDataRef);
            
            if (trustedDataRef)
            {
                NSString *appPath = [[NSString alloc] initWithData:(__bridge NSData * _Nonnull)(trustedDataRef) encoding:NSUTF8StringEncoding];
                [resultArray addObject:appPath];
                CFRelease(trustedDataRef);
            }
        }
        
        CFRelease(trustedAppsList);
        
        if (description) CFRelease(description);
    }
    
    return resultArray;
}

@end
