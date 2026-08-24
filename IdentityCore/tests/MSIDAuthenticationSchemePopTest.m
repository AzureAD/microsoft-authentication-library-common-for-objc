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
#import "MSIDAuthenticationSchemePop.h"
#import "MSIDAccessToken.h"
#import "MSIDAccessTokenWithAuthScheme.h"
#import "MSIDTelemetryAPIEvent.h"
#import "MSIDTelemetryEventStrings.h"

@interface MSIDAuthenticationSchemePopTest : XCTestCase

@end

@implementation MSIDAuthenticationSchemePopTest

- (void) test_InitWithCorrectParams_shouldReturnCompleteScheme
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter]];
    [self test_assertDefaultAttributesInScheme:scheme];
}

- (void) test_InitWithInCorrectTokenType_shouldReturnNil
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter_incorrectTokenType]];
    XCTAssertNil(scheme);
}

- (void) test_InitWithInCorrectReqConf_shouldReturnNil
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter_incorrectReqCnf]];
    XCTAssertNil(scheme);
}

- (void) test_MatchAccessTokenKeyThumbprint
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter]];
    
    MSIDAccessToken *emptyAccessToken = [MSIDAccessToken new];
    XCTAssertFalse([scheme matchAccessTokenKeyThumbprint:emptyAccessToken]);
    
    MSIDAccessToken *correctToken = [MSIDAccessToken new];
    correctToken.kid = @"XiMaaghIwBYt0-e6EArulnikKlLUuYkquGFM9ba9D1w";
    XCTAssertTrue([scheme matchAccessTokenKeyThumbprint:correctToken]);
    
    MSIDAccessToken *incorrectToken = [MSIDAccessToken new];
    incorrectToken.kid = @"123XiMaaghIwBYt0-e6EArulnikKlLUuYkquGFM9ba9D1w";
    XCTAssertFalse([scheme matchAccessTokenKeyThumbprint:incorrectToken]);
}

- (void)testMatchAccessTokenKeyThumbprint_whenKeysDiffer_shouldIsolateCachedTokens
{
    NSDictionary *firstParameters = @{
        MSID_OAUTH2_TOKEN_TYPE : MSID_OAUTH2_POP,
        MSID_OAUTH2_REQUEST_CONFIRMATION : @"eyJraWQiOiJmaXJzdC1rZXkifQ"
    };
    NSDictionary *secondParameters = @{
        MSID_OAUTH2_TOKEN_TYPE : MSID_OAUTH2_POP,
        MSID_OAUTH2_REQUEST_CONFIRMATION : @"eyJraWQiOiJzZWNvbmQta2V5In0"
    };
    MSIDAuthenticationSchemePop *firstScheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:firstParameters];
    MSIDAuthenticationSchemePop *secondScheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:secondParameters];
    MSIDAccessToken *firstToken = [MSIDAccessToken new];
    firstToken.kid = @"first-key";
    MSIDAccessToken *secondToken = [MSIDAccessToken new];
    secondToken.kid = @"second-key";

    XCTAssertTrue([firstScheme matchAccessTokenKeyThumbprint:firstToken]);
    XCTAssertFalse([firstScheme matchAccessTokenKeyThumbprint:secondToken]);
    XCTAssertTrue([secondScheme matchAccessTokenKeyThumbprint:secondToken]);
    XCTAssertFalse([secondScheme matchAccessTokenKeyThumbprint:firstToken]);
}

- (void) test_InitWithCorrectJson_shouldReturnCompleteScheme
{
    NSDictionary *json = [self preparePopSchemeParameter];
    NSError *error = nil;
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNotNil(scheme);
    XCTAssertNil(error);
    [self test_assertDefaultAttributesInScheme:scheme];
}

- (void)testInitWithExternalKeyMarker_shouldPreserveMarkerInJsonAndCopy
{
    NSMutableDictionary *parameters = [[self preparePopSchemeParameter] mutableCopy];
    parameters[MSID_OAUTH2_EXTERNAL_KEY_POP] = @"1";
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:parameters];

    XCTAssertTrue(scheme.isExternalKeyPop);
    XCTAssertEqualObjects(scheme.schemeParameters[MSID_OAUTH2_EXTERNAL_KEY_POP], @"1");
    XCTAssertEqualObjects([scheme jsonDictionary][MSID_OAUTH2_EXTERNAL_KEY_POP], @"1");

    MSIDAuthenticationSchemePop *schemeCopy = [scheme copy];
    XCTAssertTrue(schemeCopy.isExternalKeyPop);
    XCTAssertEqualObjects(schemeCopy.schemeParameters[MSID_OAUTH2_EXTERNAL_KEY_POP], @"1");
}

- (void)testInitWithInvalidExternalKeyMarker_shouldReturnNil
{
    NSMutableDictionary *parameters = [[self preparePopSchemeParameter] mutableCopy];
    parameters[MSID_OAUTH2_EXTERNAL_KEY_POP] = @"true";

    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:parameters];

    XCTAssertNil(scheme);
}

- (void)testInitWithNumericExternalKeyMarkerJson_shouldReturnNilAndError
{
    NSMutableDictionary *json = [[self preparePopSchemeParameter] mutableCopy];
    json[MSID_OAUTH2_EXTERNAL_KEY_POP] = @1;
    NSError *error = nil;

    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithJSONDictionary:json error:&error];

    XCTAssertNil(scheme);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testInitWithoutExternalKeyMarker_shouldNotBeExternal
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter]];

    XCTAssertFalse(scheme.isExternalKeyPop);
}

- (void)testConfigureTelemetryEvent_whenInternalKey_shouldSetInternalPopKeySource
{
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:[self preparePopSchemeParameter]];
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT context:nil];

    [scheme configureTelemetryEvent:event];

    XCTAssertEqualObjects([event propertyWithName:MSID_TELEMETRY_KEY_POP_KEY_SOURCE], MSID_TELEMETRY_VALUE_INTERNAL);
}

- (void)testConfigureTelemetryEvent_whenExternalKey_shouldSetExternalPopKeySource
{
    NSMutableDictionary *parameters = [[self preparePopSchemeParameter] mutableCopy];
    parameters[MSID_OAUTH2_EXTERNAL_KEY_POP] = @"1";
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithSchemeParameters:parameters];
    MSIDTelemetryAPIEvent *event = [[MSIDTelemetryAPIEvent alloc] initWithName:MSID_TELEMETRY_EVENT_API_EVENT context:nil];

    [scheme configureTelemetryEvent:event];

    XCTAssertEqualObjects([event propertyWithName:MSID_TELEMETRY_KEY_POP_KEY_SOURCE], MSID_TELEMETRY_VALUE_EXTERNAL);
}

- (void) test_InitWithIncorrectJson_shouldReturnNil{
    NSDictionary *json = [self preparePopSchemeParameter_missingTokenType];
    NSError *error = nil;
    MSIDAuthenticationSchemePop *scheme = [[MSIDAuthenticationSchemePop alloc] initWithJSONDictionary:json error:&error];
    XCTAssertNil(scheme);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (NSDictionary *) preparePopSchemeParameter
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"eyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *) preparePopSchemeParameter_incorrectTokenType
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop1" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"eyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *) preparePopSchemeParameter_incorrectReqCnf
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop" forKey:MSID_OAUTH2_TOKEN_TYPE];
    [params setObject:@"123abceyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (NSDictionary *) preparePopSchemeParameter_missingTokenType
{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:@"Pop" forKey:@"token_type1"];
    [params setObject:@"123abceyJraWQiOiJYaU1hYWdoSXdCWXQwLWU2RUFydWxuaWtLbExVdVlrcXVHRk05YmE5RDF3In0" forKey:MSID_OAUTH2_REQUEST_CONFIRMATION];
    return params;
}

- (void) test_assertDefaultAttributesInScheme:(MSIDAuthenticationSchemePop *)scheme
{
    XCTAssertNotNil([scheme valueForKey:@"kid"]);
    XCTAssertNotNil([scheme valueForKey:@"req_cnf"]);
    XCTAssertEqual(scheme.authScheme, MSIDAuthSchemePop);
    XCTAssertEqual(scheme.credentialType, MSIDAccessTokenWithAuthSchemeType);
    XCTAssertEqual(scheme.tokenType, MSID_OAUTH2_POP);
    XCTAssertNotNil(scheme.accessToken);
    
    MSIDAccessToken *accessToken = scheme.accessToken;
    XCTAssertTrue([accessToken isMemberOfClass:[MSIDAccessTokenWithAuthScheme class]]);
    XCTAssertNotNil((MSIDAccessTokenWithAuthScheme *)accessToken.tokenType);
    XCTAssertNotNil((MSIDAccessTokenWithAuthScheme *)accessToken.kid);
}

@end
