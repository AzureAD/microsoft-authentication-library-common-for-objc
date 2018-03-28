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
#import "MSIDTokenCacheItem.h"
#import "MSIDLegacyTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache.h"
#import "MSIDSharedTokenCache.h"
#import "MSIDAccount.h"
#import "MSIDTestCacheIdentifiers.h"
#import "MSIDRefreshToken.h"
#import "MSIDTestTokenResponse.h"
#import "MSIDTestRequestParams.h"
#import "MSIDAADV1TokenResponse.h"
#import "MSIDTelemetry+Internal.h"
#import "MSIDTelemetryEventStrings.h"
#import "MSIDDefaultTokenCacheAccessor.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"

@interface MSIDTestRequestContext : NSObject <MSIDRequestContext>

@property (retain, nonatomic) NSUUID* correlationId;
@property (retain, nonatomic) NSString* telemetryRequestId;
@property (retain, nonatomic) NSString* logComponent;

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
    _legacyCacheAccessor = [[MSIDLegacyTokenCacheAccessor alloc] initWithDataSource:_dataSource];
    _defaultCacheAccessor = [[MSIDDefaultTokenCacheAccessor alloc] initWithDataSource:_dataSource];
    
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
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:nil];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_legacyCacheAccessor saveRefreshToken:token
                                                 account:account
                                                 context:reqContext
                                                   error:&error];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_legacyCacheAccessor removeToken:token
                                       account:account
                                       context:reqContext
                                         error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    MSIDBaseToken *returnedToken = [_legacyCacheAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                                  account:account
                                                            requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                  context:reqContext
                                                                    error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
    
    
    
    // test if wipe data is logged in telemetry
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[@"Microsoft.Test.event_name"] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[@"Microsoft.Test.wipe_app"] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[@"Microsoft.Test.wipe_time"])
        {
            XCTAssertTrue(YES);
            return;
        }
    }
    
    XCTAssertTrue(NO);
}

- (void)testWipeDataTelemetry_whenGetAllTokensOfTypeButNoneForLegacyCache_shouldLogWipeDataInTelemetry
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
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:nil];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_legacyCacheAccessor saveRefreshToken:token
                                                 account:account
                                                 context:reqContext
                                                   error:&error];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_legacyCacheAccessor removeToken:token
                                       account:account
                                       context:reqContext
                                         error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    NSArray *returnedTokens = [_legacyCacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                                          withClientId:DEFAULT_TEST_CLIENT_ID
                                                               context:reqContext
                                                                 error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertEqual(returnedTokens.count, 0);
    
    
    
    // test if wipe data is logged in telemetry
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[@"Microsoft.Test.event_name"] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[@"Microsoft.Test.wipe_app"] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[@"Microsoft.Test.wipe_time"])
        {
            XCTAssertTrue(YES);
            return;
        }
    }
    
    XCTAssertTrue(NO);
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
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"some_uid.some_utid"];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_defaultCacheAccessor saveRefreshToken:token
                                                  account:account
                                                  context:reqContext
                                                    error:&error];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_defaultCacheAccessor removeToken:token
                                        account:account
                                        context:reqContext
                                          error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    MSIDBaseToken *returnedToken = [_defaultCacheAccessor getTokenWithType:MSIDTokenTypeRefreshToken
                                                                   account:account
                                                             requestParams:[MSIDTestRequestParams v1DefaultParams]
                                                                   context:reqContext
                                                                     error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertNil(returnedToken);
    
    
    
    // test if wipe data is logged in telemetry
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[@"Microsoft.Test.event_name"] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[@"Microsoft.Test.wipe_app"] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[@"Microsoft.Test.wipe_time"])
        {
            XCTAssertTrue(YES);
            return;
        }
    }
    
    XCTAssertTrue(NO);
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
    MSIDRefreshToken *token = [[MSIDRefreshToken alloc] initWithTokenResponse:[MSIDTestTokenResponse v1DefaultTokenResponse]
                                                                      request:[MSIDTestRequestParams v1DefaultParams]];
    MSIDAccount *account = [[MSIDAccount alloc] initWithLegacyUserId:DEFAULT_TEST_ID_TOKEN_USERNAME
                                                        uniqueUserId:@"some_uid.some_utid"];
    MSIDTestRequestContext *reqContext = [MSIDTestRequestContext new];
    [reqContext setTelemetryRequestId:[[MSIDTelemetry sharedInstance] generateRequestId]];
    NSError *error = nil;
    
    BOOL result = [_defaultCacheAccessor saveRefreshToken:token
                                                  account:account
                                                  context:reqContext
                                                    error:&error];
    XCTAssertNil(error);
    
    // remove the refresh token to trigger wipe data being written
    result = [_defaultCacheAccessor removeToken:token
                                        account:account
                                        context:reqContext
                                          error:&error];
    XCTAssertNil(error);
    
    // read the refresh token in order to log wipe data in telemetry
    NSArray *returnedTokens = [_defaultCacheAccessor getAllTokensOfType:MSIDTokenTypeRefreshToken
                                                           withClientId:DEFAULT_TEST_CLIENT_ID
                                                                context:reqContext
                                                                  error:&error];
    
    // expect no token because it has been deleted
    XCTAssertNil(error);
    XCTAssertEqual(returnedTokens.count, 0);
    
    
    
    // test if wipe data is logged in telemetry
    for (id<MSIDTelemetryEventInterface> event in receivedEvents)
    {
        if ([event.propertyMap[@"Microsoft.Test.event_name"] isEqualToString:MSID_TELEMETRY_EVENT_TOKEN_CACHE_LOOKUP]
            && [event.propertyMap[@"Microsoft.Test.wipe_app"] isEqualToString:@"com.microsoft.MSIDTestsHostApp"]
            && event.propertyMap[@"Microsoft.Test.wipe_time"])
        {
            XCTAssertTrue(YES);
            return;
        }
    }
}

@end

