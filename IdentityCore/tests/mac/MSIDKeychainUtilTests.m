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
#import "MSIDKeychainUtil+MacInternal.h"

@interface MSIDKeychainUtilTests : XCTestCase

@end

@implementation MSIDKeychainUtilTests

#pragma mark - Tests

- (void)testTeamIdFromSigningDictionary_whenTeamIdPresent_shouldReturnIt
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:nil teamId:@"XXXXXX"];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *teamId = [keychainUtil teamIdFromSigningInformation:signingDictionary];
    
    XCTAssertEqualObjects(teamId, @"XXXXXX");
}

- (void)testTeamIdFromSigningDictionary_whenTeamIdMissing_shouldReturnNil
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:nil teamId:nil];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *teamId = [keychainUtil teamIdFromSigningInformation:signingDictionary];
    
    XCTAssertNil(teamId);
}

- (void)testAppIdentifierPrefix_whenKeychainGroupsPresent_shouldReturnPrefixForFirstGroup
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:@"YYYYYY.com.mykeychain.mygroup" teamId:@"XXXXXXX"];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *prefix = [keychainUtil appIdPrefixFromSigningInformation:signingDictionary];
    
    XCTAssertEqualObjects(prefix, @"YYYYYY");
}

- (void)testAppIdentifierPrefix_whenKeychainGroupsPresent_butKeychainGroupHasInvalidFormat_shouldReturnNil
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:@"YYYYYYcommykeychainmygroup" teamId:@"XXXXXXX"];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *prefix = [keychainUtil appIdPrefixFromSigningInformation:signingDictionary];
    
    XCTAssertNil(prefix);
}

- (void)testAppIdentifierPrefix_whenNoKeychainGroupsDict_shouldReturnNil
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:nil teamId:@"XXXXXXX"];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *prefix = [keychainUtil appIdPrefixFromSigningInformation:signingDictionary];
    
    XCTAssertNil(prefix);
}

- (void)testAppIdentifierPrefix_whenEmptyKeychainGroupsDict_shouldReturnNil
{
    NSMutableDictionary *signingDictionary = [[self testSignedDictionaryWithKeychainGroup:nil teamId:@"XXXXXXX"] mutableCopy];
    signingDictionary[@"keychain-access-groups"] = @[];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *prefix = [keychainUtil appIdPrefixFromSigningInformation:signingDictionary];
    
    XCTAssertNil(prefix);
}

- (void)testAppIdentifierPrefix_whenKeychainGroupsDictWithEmptyGroup_shouldReturnNil
{
    NSDictionary *signingDictionary = [self testSignedDictionaryWithKeychainGroup:@"" teamId:@"XXXXXXX"];
    
    MSIDKeychainUtil *keychainUtil = [MSIDKeychainUtil sharedInstance];
    NSString *prefix = [keychainUtil appIdPrefixFromSigningInformation:signingDictionary];
    
    XCTAssertNil(prefix);
}

#pragma mark - Input data

- (NSDictionary *)testSignedDictionaryWithKeychainGroup:(NSString *)keychainGroup teamId:(NSString *)teamId
{
    NSMutableDictionary *entitlementsDictionary = [@{
        @"com.apple.application-identifier" : @"XXXXXX.com.microsoft.MSALMacTestApp",
        @"com.apple.security.app-sandbox" : @1,
        @"com.apple.security.files.user-selected.read-only" : @1,
        @"com.apple.security.get-task-allow" : @1,
        @"com.apple.security.network.client" : @1
    } mutableCopy];
    
    if (teamId)
    {
        entitlementsDictionary[@"com.apple.developer.team-identifier"] = teamId;
    }
    
    if (keychainGroup)
    {
        entitlementsDictionary[@"keychain-access-groups"] = @[keychainGroup];
    }
    
    NSMutableDictionary *signingDictionary = [@{
        @"digest-algorithm" : @2,
        @"digest-algorithms" :     @[@2],
        @"entitlements-dict" :     entitlementsDictionary,
        @"identifier" : @"com.microsoft.MSALMacTestApp",
        @"signing-time" : @"@2020-03-22 18:48:01 +0000",
        @"source" : @"embedded"
    } mutableCopy];
    
    if (teamId)
    {
        signingDictionary[@"teamid"] = teamId;
    }
    
    return signingDictionary;
}

@end
