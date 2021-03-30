//
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
#import "MSIDDevicePopManager.h"
#import "MSIDCacheConfig.h"
#import "MSIDAssymetricKeyKeychainGenerator.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDAssymetricKeyPair.h"
#if !TARGET_OS_IPHONE
#import "MSIDAssymetricKeyLoginKeychainGenerator.h"
#endif
#import "MSIDConstants.h"
#import "MSIDAssymetricKeyLookupAttributes.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDMacKeychainTokenCache.h"

@interface MSIDDevicePopManagerTest : XCTestCase

@end

@implementation MSIDDevicePopManagerTest

NSString *const mockDefaultKeychainGroup = @"com.apple.dt.xctest.tool";

- (MSIDDevicePopManager *)test_initWithValidCacheConfig
{
    MSIDDevicePopManager *manager;
    MSIDCacheConfig *msidCacheConfig;
    NSError *error;
    
    MSIDAssymetricKeyLookupAttributes *keyPairAttributes;
    
#if TARGET_OS_IPHONE
    
    msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:[MSIDKeychainTokenCache defaultKeychainGroup]];
    keyPairAttributes = [MSIDAssymetricKeyLookupAttributes new];
    
#else
    keyPairAttributes = [[MSIDAssymetricKeyLookupAttributes alloc] init];
    
    if (@available(macOS 10.15, *))
    {
        msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:mockDefaultKeychainGroup];
    }
    else
    {
        MSIDMacKeychainTokenCache *macDataSource = [[MSIDMacKeychainTokenCache alloc] initWithGroup:[MSIDKeychainTokenCache defaultKeychainGroup]
                                                                                trustedApplications:nil
                                                                                              error:&error];
        
        msidCacheConfig = [[MSIDCacheConfig alloc] initWithKeychainGroup:[MSIDKeychainTokenCache defaultKeychainGroup]
                                                               accessRef:(__bridge SecAccessRef _Nullable)(macDataSource.accessControlForNonSharedItems)];
    }
#endif
    keyPairAttributes.privateKeyIdentifier = MSID_POP_TOKEN_PRIVATE_KEY;
    
    manager = [[MSIDDevicePopManager alloc] initWithCacheConfig:msidCacheConfig keyPairAttributes:keyPairAttributes];
    XCTAssertNil(error);
    XCTAssertNotNil(manager);
    [manager setValue:[self keyGenerator] forKey:@"keyGeneratorFactory"];
    return manager;
}

- (void)test_createSignedAccess_ValidInput_ShouldReturnSignedAT
{
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"accesToken";
    NSString *httpMethod = @"Post";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net/api/validateSHR";
    NSString *nonce = @"48D1E0E2-2AB4-491A-87F9-BCBAAAD777CC";
    NSError *error = nil;
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(signedAT);
    XCTAssertNil(error);
}

- (void)test_createSignedAccess_DeletePublickey_ShouldRegeneratePublicKey_AndReturnSignedAT
{
    
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"accesToken";
    NSString *httpMethod = @"Post";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net/api/validateSHR";
    NSString *nonce = @"48D1E0E2-2AB4-491A-87F9-BCBAAAD777CC";
    NSError *error = nil;
    
    // Delete privateKey
    [self deleteKeyWithTag:MSID_POP_TOKEN_PRIVATE_KEY];
    
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(signedAT);
    XCTAssertNil(error);
}

- (void)test_createSignedAccess_InvalidAcessToken_ShouldReturnNilAndError
{
    
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"";
    NSString *httpMethod = @"Post";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net/api/validateSHR";
    NSString *nonce = @"48D1E0E2-2AB4-491A-87F9-BCBAAAD777CC";
    NSError *error = nil;
    
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(error);
    XCTAssertNil(signedAT);
}

- (void)test_createSignedAccess_InvalidHTTPMethod_ShouldReturnSignedAT
{
    
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"accessToken";
    NSString *httpMethod = @"";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net/api/validateSHR";
    NSString *nonce = @"48D1E0E2-2AB4-491A-87F9-BCBAAAD777CC";
    NSError *error = nil;
    
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(signedAT);
    XCTAssertNil(error);
}

- (void)test_createSignedAccess_InvalidRequestURL_ShouldReturnSignedAT
{
    
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"accessToken";
    NSString *httpMethod = @"POST";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net";
    NSString *nonce = @"48D1E0E2-2AB4-491A-87F9-BCBAAAD777CC";
    NSError *error = nil;
    
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(signedAT);
    XCTAssertNil(error);
}

- (void)test_createSignedAccess_InvalidNonce_ShouldReturnSignedAT
{
    
    MSIDDevicePopManager *manager = [self test_initWithValidCacheConfig];
    NSString *accesToken = @"accessToken";
    NSString *httpMethod = @"POST";
    NSString *requestUrl = @"https://signedhttprequest.azurewebsites.net/api/validateSHR";
    NSString *nonce = @"";
    NSError *error = nil;
    
    NSString *signedAT = [manager createSignedAccessToken:accesToken
                                               httpMethod:httpMethod
                                               requestUrl:requestUrl
                                                    nonce:nonce
                                                    error:&error];
    XCTAssertNotNil(signedAT);
    XCTAssertNil(error);
}

- (void)deleteKeyWithTag:(NSString *)tag
{
    NSDictionary *deleteKeyAttr = @{(id)kSecClass : (id)kSecClassKey,
                                    (id)kSecAttrApplicationTag : (id)[tag dataUsingEncoding:NSUTF8StringEncoding]};
    
    OSStatus status = SecItemDelete((CFDictionaryRef)deleteKeyAttr);
    BOOL deletionSucceeded = status == errSecSuccess || status == errSecItemNotFound;
    XCTAssertTrue(deletionSucceeded);
}

- (MSIDAssymetricKeyKeychainGenerator *)keyGenerator
{
#if TARGET_OS_IPHONE
    return [[MSIDAssymetricKeyKeychainGenerator alloc] initWithGroup:nil error:nil];
#else
    return [[MSIDAssymetricKeyLoginKeychainGenerator alloc] initWithGroup:nil error:nil];
#endif
}

@end
