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
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    keychainUtil.teamId = @"FakeTeamId";
    
    [[MSIDMacKeychainTokenCache new] clearWithContext:nil error:nil];
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
    
}

- (void)testSaveData_whenItemDoesntExist_shouldCreateItem
{
    
}

- (void)testSaveData_whenItemExists_shouldUpdateItem
{
    
}

- (void)testRemoveItem_whenItemDoesntExist_shouldNotRemoveOtherItems
{
    
}

- (void)testRemoveItem_whenItemExists_shouldRemoveItem
{
    
}

- (void)testGetDataWithAttributes_whenNoDataFound_shouldReturnNil
{
    
}

- (void)testGetDataWithAttributes_whenDataFound_shouldReturnData
{
    
}

- (void)testClearWithAttributes_whenNoMatchingItemsExist_shouldNotClear
{
    
}

- (void)testClearWithAttributes_whenAttributesProvided_shouldClear
{
    
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
