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
#import "MSIDBrokerResponseHandler.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDConstants.h"

@interface MSIDBrokerResponseHandlerTests : XCTestCase

@end

@implementation MSIDBrokerResponseHandlerTests

- (void)setUp
{
    [super setUp];

    // Clear keychain
    NSDictionary *query = @{(id)kSecClass : (id)kSecClassKey,
                            (id)kSecAttrKeyClass : (id)kSecAttrKeyClassSymmetric};

    SecItemDelete((CFDictionaryRef)query);
}

- (void)tearDown
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    [super tearDown];
}

- (void)testHandleBrokerResponse_whenNoResumeState_shouldReturnNilResultAndNonNilError
{
    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = [NSURL URLWithString:@"msauth://test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerNoResumeStateFound);
}

- (void)testHandleBrokerResponse_whenNoResponseProvided_shouldReturnNilResultAndNonNilError
{
    [[NSUserDefaults standardUserDefaults] setObject:@"non-nil" forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];

    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = nil;
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInternal);
}

- (void)testHandleBrokerResponse_whenNoKeychainGroupInResumeDictionary_shouldReturnNilResultAndNonNilError
{
    NSDictionary *resumeDictionary = @{@"redirect_uri": @"x-msauth-test://com.contoso.mytestapp",
                                       @"authority": @"https://login.microsoftonline.com/contoso.com",
                                       @"correlation_id": [[NSUUID new] UUIDString],
                                       @"broker_nonce": @"nonce"
                                       };

    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];


    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = [NSURL URLWithString:@"x-msauth-test://com.contoso.mytestapp?response=test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerBadResumeStateFound);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Resume state is missing the keychain group!");

}

- (void)testHandleBrokerResponse_whenNoRedirectUriInResumeDictionary_shouldReturnNilResultAndNonNilError
{
    NSDictionary *resumeDictionary = @{@"keychain_group":@"com.microsoft.adalcache",
                                       @"authority": @"https://login.microsoftonline.com/contoso.com",
                                       @"correlation_id": [[NSUUID new] UUIDString],
                                       @"broker_nonce": @"nonce"
                                       };

    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];


    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = [NSURL URLWithString:@"x-msauth-test://com.contoso.mytestapp?response=test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerBadResumeStateFound);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Resume state is missing the redirect uri!");
}

- (void)testHandleBrokerResponse_whenNoBrokerNonceInResumeDictionary_shouldReturnNilResultAndNonNilError
{
    NSDictionary *resumeDictionary = @{@"redirect_uri": @"x-msauth-test://com.contoso.mytestapp",
                                       @"keychain_group":@"com.microsoft.adalcache",
                                       @"authority": @"https://login.microsoftonline.com/contoso.com",
                                       @"correlation_id": [[NSUUID new] UUIDString]
                                       };
    
    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];
    
    
    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];
    
    NSURL *testURL = [NSURL URLWithString:@"x-msauth-test://com.contoso.mytestapp?response=test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];
    
    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerBadResumeStateFound);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"Resume state is missing the broker nonce!");
}

- (void)testHandleBrokerResponse_whenResponseUsingWrongRedirectUri_shouldReturnNilResultAndNonNilError
{
    NSDictionary *resumeDictionary = @{@"keychain_group":@"com.microsoft.adalcache",
                                       @"redirect_uri":@"x-msauth-test://com.contoso.mytestapp",
                                       @"authority": @"https://login.microsoftonline.com/contoso.com",
                                       @"correlation_id": [[NSUUID new] UUIDString],
                                       @"broker_nonce": @"nonce"
                                       };

    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];


    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = [NSURL URLWithString:@"x-msauth-test-wrong://com.contoso.mytestapp?response=test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerMismatchedResumeState);
}

- (void)testHandleBrokerResponse_whenBrokerKeyCannotBeRead_shouldReturnNilResultAndNonNilError
{
    NSDictionary *resumeDictionary = @{@"keychain_group":@"com.microsoft.adalcache-wrong",
                                       @"redirect_uri":@"x-msauth-test://com.contoso.mytestapp",
                                       @"authority": @"https://login.microsoftonline.com/contoso.com",
                                       @"correlation_id": [[NSUUID new] UUIDString],
                                       @"broker_nonce": @"nonce"
                                       };

    [[NSUserDefaults standardUserDefaults] setObject:resumeDictionary forKey:MSID_BROKER_RESUME_DICTIONARY_KEY];


    MSIDBrokerResponseHandler *responseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];

    NSURL *testURL = [NSURL URLWithString:@"x-msauth-test://com.contoso.mytestapp?response=test"];
    NSError *error = nil;
    MSIDTokenResult *result = [responseHandler handleBrokerResponseWithURL:testURL sourceApplication:MSID_BROKER_APP_BUNDLE_ID error:&error];

    XCTAssertNil(result);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorBrokerKeyNotFound);
}

- (void)testCanHandleBrokerResponse_shouldReturnYes
{
    MSIDBrokerResponseHandler *brokerResponseHandler = [[MSIDBrokerResponseHandler alloc] initWithOauthFactory:[MSIDAADV2Oauth2Factory new] tokenResponseValidator:[MSIDTokenResponseValidator new]];
    
    BOOL result = [brokerResponseHandler canHandleBrokerResponse:[NSURL new] hasCompletionBlock:YES];
    
    XCTAssertTrue(result);
}

@end
