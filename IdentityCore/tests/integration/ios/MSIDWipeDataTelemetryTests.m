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
#import "MSIDTelemetryTestDispatcher.h"
#import "MSIDTelemetry.h"
#import "MSIDCredentialCacheItem.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDAccount.h"
#import "MSIDTestIdentifiers.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestConfiguration.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDAADV1Oauth2Factory.h"
#import "MSIDLegacyRefreshToken.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAADV2Oauth2Factory.h"
#import "MSIDAADAuthority.h"
#import "MSIDAuthority+Internal.h"

@interface MSIDTestRequestContext : NSObject <MSIDRequestContext>

@property (retain, nonatomic) NSUUID* correlationId;
@property (retain, nonatomic) NSString* telemetryRequestId;
@property (retain, nonatomic) NSString* logComponent;
@property (retain, nonatomic) NSDictionary* appRequestMetadata;

@end

@implementation MSIDTestRequestContext
@end


@interface MSIDWipeDataTelemetryTests : XCTestCase
{
    MSIDKeychainTokenCache *_dataSource;
    MSIDLegacyTokenCacheAccessor *_legacyCacheAccessor;
    MSIDDefaultTokenCacheAccessor *_defaultCacheAccessor;
}

@end

@implementation MSIDWipeDataTelemetryTests

- (void)setUp
{
    [MSIDKeychainTokenCache reset];
    _dataSource = [[MSIDKeychainTokenCache alloc] init];
    _legacyCacheAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:nil];
    _defaultCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_dataSource otherCacheAccessors:nil];
    
    [super setUp];
}

- (void)testWipeDataTelemetry_whenGetTokenWithTypeButNoneForLegacyCache_shouldLogWipeDataInTelemetry
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];
    
    NSMutableArray *receivedEvents = [NSMutableArray array];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    
    // save a refresh token to keychain token cache
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        homeAccountId:nil];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;

    BOOL result = [_legacyCacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                             response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                              factory:[MSIDAADV1Oauth2Factory new]
                                                              context:reqContext
                                                                error:nil];
    XCTAssertNil(error);

    // remove the refresh token to trigger wipe data being written
    result = [_legacyCacheAccessor validateAndRemoveRefreshToken:token
                                                         context:reqContext
                                                           error:&error];

    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    MSIDRefreshToken *returnedToken = [_legacyCacheAccessor getRefreshTokenWithAccount:account
                                                                              familyId:nil
                                                                         configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                               context:reqContext
                                                                                 error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
    
    // test if wipe data is logged in telemetry
    XCTestExpectation *expectation = [self expectationWithDescription:@"Find wipe data in telemetry."];
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[MSID_TELEMETRY_KEY_EVENT_NAME] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[MSID_TELEMETRY_KEY_WIPE_APP] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[MSID_TELEMETRY_KEY_WIPE_TIME])
        {
            [expectation fulfill];
        }
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWipeDataTelemetry_whenGetAllAccountsButNoneForLegacyCache_shouldLogWipeDataInTelemetry
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];
    
    NSMutableArray *receivedEvents = [NSMutableArray array];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    
    // save a refresh token to keychain token cache
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDLegacyRefreshToken *token = [factory legacyRefreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_legacyCacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                             response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                              factory:[MSIDAADV1Oauth2Factory new]
                                                              context:reqContext
                                                                error:nil];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_legacyCacheAccessor validateAndRemoveRefreshToken:token
                                                         context:reqContext
                                                           error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                          context:reqContext
                                                            error:&error];

    NSArray *returnedAccounts = [_legacyCacheAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:reqContext error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertEqual(returnedAccounts.count, 0);
    
    // test if wipe data is logged in telemetry
    XCTestExpectation *expectation = [self expectationWithDescription:@"Find wipe data in telemetry."];
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[MSID_TELEMETRY_KEY_EVENT_NAME] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[MSID_TELEMETRY_KEY_WIPE_APP] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[MSID_TELEMETRY_KEY_WIPE_TIME])
        {
            [expectation fulfill];
        }
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWipeDataTelemetry_whenGetTokenWithTypeButNoneForDefaultCache_shouldLogWipeDataInTelemetry
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];
    
    NSMutableArray *receivedEvents = [NSMutableArray array];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    
    // save a refresh token to keychain token cache
    MSIDAADV1Oauth2Factory *factory = [MSIDAADV1Oauth2Factory new];
    MSIDRefreshToken *token = [factory refreshTokenFromResponse:[MSIDTestTokenResponse v1DefaultTokenResponse] configuration:[MSIDTestConfiguration v1DefaultConfiguration]];
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:@"some_uid.some_utid"];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;

    BOOL result = [_defaultCacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                              response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                               factory:factory
                                                               context:reqContext
                                                                 error:nil];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_defaultCacheAccessor validateAndRemoveRefreshToken:token
                                                          context:reqContext
                                                            error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    MSIDRefreshToken *returnedToken = [_defaultCacheAccessor getRefreshTokenWithAccount:account
                                                                               familyId:nil
                                                                          configuration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                                                context:reqContext
                                                                                  error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
    
    
    
    // test if wipe data is logged in telemetry
    XCTestExpectation *expectation = [self expectationWithDescription:@"Find wipe data in telemetry."];
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[MSID_TELEMETRY_KEY_EVENT_NAME] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[MSID_TELEMETRY_KEY_WIPE_APP] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[MSID_TELEMETRY_KEY_WIPE_TIME])
        {
            [expectation fulfill];
            break;
        }
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testWipeDataTelemetry_whenGetAllTokensOfTypeButNoneForDefaultCache_shouldLogWipeDataInTelemetry
{
    // setup telemetry callback
    MSIDTelemetryTestDispatcher *dispatcher = [MSIDTelemetryTestDispatcher new];
    
    NSMutableArray *receivedEvents = [NSMutableArray array];
    
    // the dispatcher will store the telemetry events it receives
    [dispatcher setTestCallback:^(id<MSIDTelemetryEventInterface> event)
     {
         [receivedEvents addObject:event];
     }];
    
    // register the dispatcher
    [[MSIDTelemetry sharedInstance] addDispatcher:dispatcher];
    
    // save a refresh token to keychain token cache
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_defaultCacheAccessor saveSSOStateWithConfiguration:[MSIDTestConfiguration v1DefaultConfiguration]
                                                              response:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                               factory:[MSIDAADV1Oauth2Factory new]
                                                               context:reqContext
                                                                 error:nil];
    XCTAssertNil(error);
    
    // remove the account to trigger wipe data being written
    NSString *homeAccountId = [NSString stringWithFormat:@"%@.%@", DEFAULT_TEST_UID, DEFAULT_TEST_UTID];
    MSIDAccountIdentifier *account = [[MSIDAccountIdentifier alloc] initWithDisplayableId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                                              homeAccountId:homeAccountId];

    MSIDAuthority *authority = [[MSIDAADAuthority alloc] initWithURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"] context:nil error:nil];

    result = [_defaultCacheAccessor clearCacheForAccount:account authority:authority clientId:@"test_client_id" familyId:nil context:nil error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    NSArray *returnedTokens = [_defaultCacheAccessor accountsWithAuthority:authority clientId:@"test_client_id" familyId:nil accountIdentifier:nil context:reqContext error:&error];

    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertEqual(returnedTokens.count, 0);
    
    // test if wipe data is logged in telemetry
    XCTestExpectation *expectation = [self expectationWithDescription:@"Find wipe data in telemetry."];
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[MSID_TELEMETRY_KEY_EVENT_NAME] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[MSID_TELEMETRY_KEY_WIPE_APP] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[MSID_TELEMETRY_KEY_WIPE_TIME])
        {
            [expectation fulfill];
        }
    }
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end

