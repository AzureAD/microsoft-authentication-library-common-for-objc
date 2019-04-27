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

#import "MSIDBasicContext.h"
#import "MSIDAccountCacheItem.h"
#import "MSIDAccountCredentialCache.h"
#import "MSIDCacheItemJsonSerializer.h"
#import "MSIDCacheKey.h"
#import "MSIDClientInfo.h"
#import "MSIDDefaultAccountCacheKey.h"
#import "MSIDDefaultAccountCacheQuery.h"
#import "MSIDMacKeychainTokenCache.h"
#import "MSIDTestIdentifiers.h"
#import "NSDictionary+MSIDTestUtil.h"
#import "NSString+MSIDExtensions.h"
#import <XCTest/XCTest.h>

@interface MSIDMacKeychainACLTests : XCTestCase
{
    MSIDMacKeychainTokenCache *_dataSource;
    MSIDAccountCredentialCache *_cache;
    MSIDCacheItemJsonSerializer *_serializer;
    
    MSIDAccountCacheItem* _account;
    MSIDDefaultAccountCacheKey *_key;
}
@end

@implementation MSIDMacKeychainACLTests

- (void)setUp
{
    _dataSource = [MSIDMacKeychainTokenCache new];
    _cache = [[MSIDAccountCredentialCache alloc] initWithDataSource:_dataSource];
    _serializer = [MSIDCacheItemJsonSerializer new];
    
    _account = [MSIDAccountCacheItem new];
    
    _account.environment = DEFAULT_TEST_ENVIRONMENT;
    _account.realm = @"realmA";
    _account.homeAccountId = @"uidA.utidA";
    _account.localAccountId = @"localAccountIdA";
    _account.accountType = MSIDAccountTypeMSSTS;
    _account.username = @"UsernameA";
    _account.givenName = @"GivenNameA";
    _account.familyName = @"FamilyNameA";
    _account.middleName = @"MiddleNameA";
    _account.name = @"NameA";
    _account.alternativeAccountId = @"AltIdA";
    
    _key = [[MSIDDefaultAccountCacheKey alloc] initWithHomeAccountId:_account.homeAccountId
                                                          environment:_account.environment
                                                                realm:_account.realm
                                                                 type:_account.accountType];
    _key.username = _account.username;
    
    // Ensure these test accounts don't already exist:
    NSError* error;
    BOOL result = [_dataSource removeItemsWithAccountKey:_key context:nil error:&error];
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)tearDown
{
    [_dataSource removeItemsWithAccountKey:_key context:nil error:nil];
    _dataSource = nil;
}

- (NSDictionary*) executeKeychainUtil:(NSDictionary*)input
{
    NSString* buildDirectory = [NSString stringWithCString:BUILD_DIR encoding:NSUTF8StringEncoding];
    NSString* executablePath = [buildDirectory stringByAppendingPathComponent:@"MSIDTestKeychainUtil"];
    NSTask *task = [NSTask new];
    [task setLaunchPath:executablePath];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:input options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSArray *arguments = [NSArray arrayWithObjects:
                          jsonString,
                          nil];
    [task setArguments:arguments];
    
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    
    NSFileHandle *file = [pipe fileHandleForReading];
    
    printf("===============================\n");
    printf("%s\n", [jsonString UTF8String]);
    printf("===============================\n");
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    printf("%s\n", [output UTF8String]);
    NSError* error;
    NSDictionary* result = [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding]
                                                           options:0
                                                             error:&error];
    if (error != nil) {
        return @{@"getError": [NSString stringWithFormat:@"Couldn't parse input: '%@'", error]};
    }
    return result;
}

- (void)assertNumericalValue:(NSInteger)expected actual:(id)actual {
    XCTAssertTrue([actual isKindOfClass:[NSNumber class]]);
    XCTAssertEqual(expected, [actual integerValue]);
}

- (void)testFoobar
{
    //NSLog(@"AppPath: %s\n", [[[NSBundle mainBundle] bundlePath] UTF8String]);
    
    MSIDAccountCacheItem* account = [MSIDAccountCacheItem new];
    
    account.environment = DEFAULT_TEST_ENVIRONMENT;
    account.realm = @"Contoso.COM";
    account.homeAccountId = @"uid.utid";
    account.localAccountId = @"homeAccountIdA";
    account.accountType = MSIDAccountTypeAADV1;
    account.username = @"UsernameA";
    account.givenName = @"GivenNameA";
    account.familyName = @"FamilyNameA";
    account.middleName = @"MiddleNameA";
    account.name = @"NameA";
    account.alternativeAccountId = @"AltIdA";
    account.additionalAccountFields = @{@"key1": @"value1", @"key2": @"value2"};
    
    NSString* accountStr = [NSString stringWithUTF8String:[[_serializer serializeAccountCacheItem:account] bytes]];
    
    NSDictionary* writeParams =@{
                                 @"method":@"WriteAccount",
                                 @"account":accountStr
                                 };
    NSDictionary* result = [self executeKeychainUtil:writeParams];
    XCTAssertNotNil(result[@"status"]);
    [self assertNumericalValue:0 actual:result[@"status"]];
    
    NSDictionary* readParams =@{
                                @"method":@"ReadAccount",
                                @"account":accountStr
                                };
    
    result = [self executeKeychainUtil:readParams];
    [self assertNumericalValue:0 actual:result[@"status"]];
    MSIDAccountCacheItem* accountRead = [_serializer deserializeAccountCacheItem:[result[@"result"] dataUsingEncoding:NSUTF8StringEncoding]];
    BOOL bar = [account isEqual:accountRead];
    XCTAssertTrue(bar);
    
    NSDictionary* deleteParams =@{
                                  @"method":@"DeleteAccount",
                                  @"account":accountStr
                                  };
    
    result = [self executeKeychainUtil:deleteParams];
    [self assertNumericalValue:0 actual:result[@"status"]];
}

@end
