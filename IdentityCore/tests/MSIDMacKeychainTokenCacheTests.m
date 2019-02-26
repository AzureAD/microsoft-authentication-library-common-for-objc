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

#import "MSIDAccountCacheItem.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <XCTest/XCTest.h>

@interface MSIDMacKeychainTokenCacheTests : XCTestCase {
    MSIDMacKeychainTokenCache *_cache;
    MSIDCacheItemJsonSerializer *_serializer;
    MSIDAccountCacheItem *_testAccount;
    MSIDCacheKey *_testAccountKey;
}
@end

@implementation MSIDMacKeychainTokenCacheTests

- (void)setUp {
    _cache = [MSIDMacKeychainTokenCache new];
    _serializer = [MSIDCacheItemJsonSerializer new];

    _testAccount = [MSIDAccountCacheItem new];
    _testAccount.environment = DEFAULT_TEST_ENVIRONMENT;
    _testAccount.realm = @"Contoso.COM";
    _testAccount.additionalAccountFields = @{@"test": @"test2", @"test3": @"test4"};
    _testAccount.localAccountId = @"0000004-0000004-000004";
    _testAccount.givenName = @"First name";
    _testAccount.familyName = @"Last name";
    _testAccount.accountType = MSIDAccountTypeMSSTS;
    _testAccount.homeAccountId = @"uid.utid";
    _testAccount.username = @"username";
    _testAccount.alternativeAccountId = @"alt";
    _testAccount.name = @"test user";

    _testAccountKey = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_testAccount.homeAccountId
                                                                    environment:_testAccount.environment
                                                                          realm:_testAccount.realm
                                                                           type:_testAccount.accountType];
}

- (void)tearDown {
    [_cache removeItemsWithAccountKey:_testAccountKey context:nil error:nil];
    _cache = nil;
}

- (void)testMacKeychainCache_whenAccountWritten_writesAccountToKeychain {
    NSError *error;
    BOOL result = [_cache saveAccount:_testAccount key:_testAccountKey serializer:_serializer context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);

    // Verify that the account was written to the keychain by reading it back and comparing:
    MSIDAccountCacheItem *account2 = [_cache accountWithKey:_testAccountKey
                                                 serializer:_serializer
                                                    context:nil
                                                      error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(_testAccount, account2);
}

- (MSIDCacheKey *)makeAccountKey:(MSIDAccountCacheItem *)account {
    NSString *accountId = [NSString stringWithFormat:@"%@-%@-%@",
                                                     [account.homeAccountId msidNormalizedString],
                                                     [account.environment msidNormalizedString],
                                                     [account.realm msidNormalizedString]];
    return [[MSIDCacheKey alloc] initWithAccount:accountId service:nil generic:nil type:nil];
}

@end
