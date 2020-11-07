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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <XCTest/XCTest.h>
#import "MSIDKeychainUtil.h"
#import "MSIDWorkPlaceJoinUtil.h"
#import "MSIDWorkPlaceJoinConstants.h"

@interface MSIDWorkPlaceJoinUtilTests : XCTestCase
@end

NSString * const dummyKeyIdendetifier = @"com.microsoft.workplacejoin.dummyKeyIdentifier";

@implementation MSIDWorkPlaceJoinUtilTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testGetWPJStringDataForIdentifier_withKeychainItem_shouldReturnValidValue
{
    NSString *dummyKeyIdentifierValue = @"dummyupn@dummytenant.com";

    NSString *sharedAccessGroup = nil;
    #if TARGET_OS_IPHONE
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];

    if (teamId)
    {
        sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    }
    #endif

    // Insert dummy UPN value.
    [MSIDWorkPlaceJoinUtilTests insertDummyStringDataIntoKeychain:dummyKeyIdentifierValue dataIdentifier:dummyKeyIdendetifier accessGroup:sharedAccessGroup];

    NSString *keyData = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:dummyKeyIdendetifier context:nil error:nil];
    XCTAssertNotNil(keyData);
    XCTAssertEqual([dummyKeyIdentifierValue isEqualToString: keyData], TRUE, "Expected registrationInfo.userPrincipalName to be same as test dummyUPNValue");

    // Cleanup
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:kMSIDUPNKeyIdentifier accessGroup:sharedAccessGroup];
}

- (void)testGetWPJStringDataForIdentifier_withoutKeychainItem_shouldReturnNil
{
    NSString *sharedAccessGroup = nil;
    #if TARGET_OS_IPHONE
    NSString *teamId = [[MSIDKeychainUtil sharedInstance] teamId];

    if (teamId)
    {
        sharedAccessGroup = [NSString stringWithFormat:@"%@.com.microsoft.workplacejoin", teamId];
    }
    #endif

    // Delete dummy key-value, if any exists before
    [MSIDWorkPlaceJoinUtilTests deleteDummyStringDataIntoKeychain:dummyKeyIdendetifier accessGroup:sharedAccessGroup];

    NSString *keyData = [MSIDWorkPlaceJoinUtil getWPJStringDataForIdentifier:dummyKeyIdendetifier context:nil error:nil];
    XCTAssertNil(keyData);
}

#pragma mark - Helpers

+ (OSStatus) insertDummyStringDataIntoKeychain: (NSString *) stringData
                                dataIdentifier: (NSString *) dataIdentifier
                                   accessGroup: (__unused NSString *) accessGroup
{
    NSMutableDictionary *insertStringDataQuery = [[NSMutableDictionary alloc] init];
    [insertStringDataQuery setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [insertStringDataQuery setObject:dataIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [insertStringDataQuery setObject:stringData forKey:(__bridge id<NSCopying>)(kSecAttrService)];

#if TARGET_OS_IOS
    [insertStringDataQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif
    return SecItemAdd((__bridge CFDictionaryRef)insertStringDataQuery, NULL);
}

+ (OSStatus) deleteDummyStringDataIntoKeychain: (NSString *) dataIdentifier
                                   accessGroup: (__unused NSString *) accessGroup
{
    NSMutableDictionary *deleteStringDataQuery = [[NSMutableDictionary alloc] init];
    [deleteStringDataQuery setObject:(__bridge id)(kSecClassGenericPassword) forKey:(__bridge id<NSCopying>)(kSecClass)];
    [deleteStringDataQuery setObject:dataIdentifier forKey:(__bridge id<NSCopying>)(kSecAttrAccount)];
    [deleteStringDataQuery setObject:(id)kCFBooleanTrue forKey:(__bridge id<NSCopying>)(kSecReturnAttributes)];

#if TARGET_OS_IOS
    [deleteStringDataQuery setObject:accessGroup forKey:(__bridge id)kSecAttrAccessGroup];
#endif

    return SecItemDelete((__bridge CFDictionaryRef)(deleteStringDataQuery));
}

@end
