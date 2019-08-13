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
#import "MSIDKeychainTokenCache.h"
#import "MSIDBrokerKeyProvider.h"
#import "MSIDTestBrokerKeyProviderHelper.h"
#import "MSIDConstants.h"

@interface MSIDBrokerKeyProvider()

@property (nonatomic) NSString *keychainAccessGroup;
@property (nonatomic) NSString *keyIdentifier;

@end

@interface MSIDBrokerKeyProviderTests : XCTestCase

@end

@implementation MSIDBrokerKeyProviderTests

- (void)setUp
{
    [super setUp];

    // Clear keychain
    NSDictionary *query = @{(id)kSecClass : (id)kSecClassKey,
                            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric};

    SecItemDelete((CFDictionaryRef)query);
}

- (void)testInitWithGroup_whenNoKey_shouldUseDefaultKey
{
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:@"com.test.mygroup"];
    XCTAssertEqualObjects(keyProvider.keyIdentifier, @"com.microsoft.adBrokerKey\0");
    XCTAssertTrue([keyProvider.keychainAccessGroup hasSuffix:@"com.test.mygroup"]);
}

- (void)testInitWithGroup_whenCustomKeyAndGroupPassed_shouldSetKey
{
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:@"com.test.mygroup" keyIdentifier:@"com.test.mykey"];
    XCTAssertEqualObjects(keyProvider.keyIdentifier, @"com.test.mykey");
    XCTAssertTrue([keyProvider.keychainAccessGroup hasSuffix:@"com.test.mygroup"]);
}

- (void)testInitWithGroup_whenNoGroupProvided_shouldUseDefaultGroup
{
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:nil keyIdentifier:@"com.test.mykey"];
    XCTAssertEqualObjects(keyProvider.keyIdentifier, @"com.test.mykey");
    XCTAssertTrue([keyProvider.keychainAccessGroup hasSuffix:[[NSBundle mainBundle] bundleIdentifier]]);
}

#pragma mark - Normal scenarios

- (void)testBrokerKeyWithError_whenNoKeyInKeychain_shouldCreateNewKey
{
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:nil];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];

    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqual([brokerKey length], 32);
}

- (void)testBrokerKeyWithError_whenKeyInKeychain_shouldReturnKey
{
    // Pre-add key to the keychain
    NSData *keyData = [@"my-random-key-data" dataUsingEncoding:NSUTF8StringEncoding];

    [MSIDTestBrokerKeyProviderHelper addKey:keyData
                                accessGroup:[[NSBundle mainBundle] bundleIdentifier]
                             applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Read key from broker key provider
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:nil];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];

    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, keyData);
}

- (void)testBrokerKeyWithError_whenKeyInKeychainWithCustomIdentifier_shouldReturnKey
{
    // Pre-add key to the keychain
    NSData *keyData = [@"my-random-key-data" dataUsingEncoding:NSUTF8StringEncoding];
    
    [MSIDTestBrokerKeyProviderHelper addKey:keyData
                                accessGroup:[[NSBundle mainBundle] bundleIdentifier]
                             applicationTag:@"custom-tag-test"];
    
    // Read key from broker key provider
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:nil keyIdentifier:@"custom-tag-test"];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];
    
    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, keyData);
}

#pragma mark - Migration scenarios

- (void)testBrokerKeyWithError_whenMultipleKeysPresent_shouldReturnOneFromSharedgroup
{
    // Add one key to the shared group
    NSData *firstKeyData = [@"my-random-key-data-1" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:firstKeyData accessGroup:@"com.microsoft.adalcache" applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Add second key to private groyp
    NSData *secondKeyData = [@"my-random-key-data-2" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:secondKeyData accessGroup:[[NSBundle mainBundle] bundleIdentifier] applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Try to read key
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:@"com.microsoft.adalcache"];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];

    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, firstKeyData);
}

- (void)testBrokerKeyWithError_whenCorrectKeyPresentInPrivateCache_shouldReturnOneFromPrivateCache
{
    // Add one key to the shared group
    NSData *firstKeyData = [@"my-random-key-data-1" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:firstKeyData accessGroup:@"com.microsoft.adalcache" applicationTag:@"com.microsoft.adBrokerKeyUnknown"];

    // Add second key to private groyp
    NSData *secondKeyData = [@"my-random-key-data-2" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:secondKeyData accessGroup:[[NSBundle mainBundle] bundleIdentifier] applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Try to read key
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:@"com.microsoft.adalcache"];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];

    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, secondKeyData);
}

- (void)testBrokerKeyWithError_whenMultipleEntriesPresentInOtherGroups_shouldReturnOneEntry
{
    // Add one key to the shared group
    NSData *firstKeyData = [@"my-random-key-data-1" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:firstKeyData accessGroup:@"com.microsoft.adalcache" applicationTag:@"com.microsoft.adBrokerKeyUnknown"];

    // Add second key to private group
    NSData *secondKeyData = [@"my-random-key-data-2" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:secondKeyData accessGroup:[[NSBundle mainBundle] bundleIdentifier] applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Add third key to intune mam group
    NSData *thirdKeyData = [@"my-random-key-data-3" dataUsingEncoding:NSUTF8StringEncoding];
    [MSIDTestBrokerKeyProviderHelper addKey:thirdKeyData accessGroup:@"com.microsoft.intune.mam" applicationTag:MSID_BROKER_SYMMETRIC_KEY_TAG];

    // Try to read key
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:@"com.microsoft.adalcache"];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];

    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, secondKeyData);
}

- (void)testBrokerKeyWithError_whenLegacyBrokerKeyInKeychain_shouldReturnKey
{
    // Pre-add key to the keychain in the legacy way
    uint8_t symmetricKeyIdentifier[] = "com.microsoft.adBrokerKey";
    NSData *symmetricTag = [[NSData alloc] initWithBytes:symmetricKeyIdentifier length:sizeof(symmetricKeyIdentifier)];
    NSData *keyData = [@"my-random-key-data" dataUsingEncoding:NSUTF8StringEncoding];
    
    [MSIDTestBrokerKeyProviderHelper addKey:keyData
                                accessGroup:[[NSBundle mainBundle] bundleIdentifier]
                         applicationTagData:symmetricTag];
    
    // Read key from broker key provider
    MSIDBrokerKeyProvider *keyProvider = [[MSIDBrokerKeyProvider alloc] initWithGroup:nil];
    NSError *error = nil;
    NSData *brokerKey = [keyProvider brokerKeyWithError:&error];
    
    XCTAssertNotNil(brokerKey);
    XCTAssertNil(error);
    XCTAssertEqualObjects(brokerKey, keyData);
}


@end
