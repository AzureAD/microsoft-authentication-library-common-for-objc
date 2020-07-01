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

@interface MSIDDevicePopManagerTest : XCTestCase

@property MSIDCacheConfig *msidCacheConfig;

@end

@implementation MSIDDevicePopManagerTest

- (void)setUp
{
    _msidCacheConfig = [MSIDCacheConfig new];
}

- (void)tearDown
{
    _msidCacheConfig = nil;
}

- (MSIDDevicePopManager *)test_initWithValidCacheConfig
{
    MSIDDevicePopManager *manager = [[MSIDDevicePopManager alloc] initWithCacheConfig:_msidCacheConfig];
    XCTAssertNotNil(manager);    
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
    
    // Delete publickey
    [self deleteKeyWithTag:MSID_POP_TOKEN_PUBLIC_KEY];
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

- (void)test_createSignedAccess_InvalidHTTPMethod_ShouldReturnNilAndError
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
    XCTAssertNotNil(error);
    XCTAssertNil(signedAT);
}

- (void)test_createSignedAccess_InvalidRequestURL_ShouldReturnNilAndError
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
    XCTAssertNotNil(error);
    XCTAssertNil(signedAT);
}

- (void)test_createSignedAccess_InvalidNonce_ShouldReturnNilAndError
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
    XCTAssertNotNil(error);
    XCTAssertNil(signedAT);
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
