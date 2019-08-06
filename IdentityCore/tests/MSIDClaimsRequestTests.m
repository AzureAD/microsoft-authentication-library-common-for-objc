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
#import "MSIDClaimsRequest.h"
#import "MSIDClaimsRequest+ClientCapabilities.h"
#import "MSIDIndividualClaimRequest.h"
#import "MSIDIndividualClaimRequestAdditionalInfo.h"

@interface MSIDClaimsRequestTests : XCTestCase

@end

@implementation MSIDClaimsRequestTests

- (void)setUp
{
}

- (void)tearDown
{
}

#pragma mark - requestCapabilities

- (void)testRequestCapabilities_whenNilCapabilities_shouldIgnoreThem
{
    NSArray *inputCapabilities = nil;
    
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    XCTAssertFalse(claimsRequest.hasClaims);
}

- (void)testRequestCapabilities_whenNonNilCapabilities_shouldRequestCapabilities
{
    NSArray *inputCapabilities = @[@"llt"];
    
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testRequestCapabilities_whenNonNilCapabilitiesAndNonNilDeveloperClaims_shouldReturnBoth
{
    NSArray *inputCapabilities = @[@"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"id_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"xms_cc\":{\"values\":[\"llt\"]}},\"id_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

- (void)testRequestCapabilities_whenNonNilCapabilitiesAndNonNilDeveloperClaimsAndAccessTokenClaimsInBoth_shouldMergeClaims
{
    NSArray *inputCapabilities = @[@"cp1", @"llt"];
    MSIDClaimsRequest *claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:@{@"access_token":@{@"polids":@{@"essential":@YES,@"values":@[@"d77e91f0-fc60-45e4-97b8-14a1337faa28"]}}} error:nil];
    
    [claimsRequest requestCapabilities:inputCapabilities];
    
    NSString *expectedResult = @"{\"access_token\":{\"polids\":{\"values\":[\"d77e91f0-fc60-45e4-97b8-14a1337faa28\"],\"essential\":true},\"xms_cc\":{\"values\":[\"cp1\",\"llt\"]}}}";
    NSString *jsonString = [[claimsRequest jsonDictionary] msidJSONSerializeWithContext:nil];
    XCTAssertEqualObjects(jsonString, expectedResult);
}

#pragma mark - testRequestClaim

- (void)testRequestClaim_whenSameClaimRequestedTwice_shouldReplaceCurrentRequest
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @2;
    
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    __auto_type requests = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertEqual(1, requests.count);
    MSIDIndividualClaimRequest *request = requests.firstObject;
    XCTAssertEqualObjects(@"sub", request.name);
    XCTAssertNotNil(request.additionalInfo);
    XCTAssertEqualObjects(@2, request.additionalInfo.value);
}

- (void)testRequestClaim_whenTargetIsIdToken_shouldRequestClaim
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    NSError *error;
    
    BOOL result = [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:&error];
    
    __auto_type requests = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertEqual(1, requests.count);
    MSIDIndividualClaimRequest *request = requests.firstObject;
    XCTAssertEqualObjects(@"sub", request.name);
    XCTAssertNotNil(request.additionalInfo);
    XCTAssertEqualObjects(@1, request.additionalInfo.value);
    XCTAssertTrue(result);
    XCTAssertNil(error);
}

- (void)testRequestClaim_whenTargetIsAccessToken_shouldRequestClaim
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetAccessToken error:nil];
    
    __auto_type requests = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetAccessToken];
    XCTAssertEqual(1, requests.count);
    MSIDIndividualClaimRequest *request = requests.firstObject;
    XCTAssertEqualObjects(@"sub", request.name);
    XCTAssertNotNil(request.additionalInfo);
    XCTAssertEqualObjects(@1, request.additionalInfo.value);
}

- (void)testRequestClaim_whenTargetIsInvalid_shouldIThrowException
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    
    XCTAssertThrows([claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetInvalid error:nil]);
}

#pragma mark - removeClaimRequestWithName

- (void)testRemoveClaimRequestWithName_whenClaimExistsInTarget_shouldRemoveIt
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"claim1": [NSNull new], @"claim2": [NSNull new], @"claim3": [NSNull new] }};
    NSError *error;
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];

    BOOL result = [claimsRequest removeClaimRequestWithName:@"claim2" target:MSIDClaimsRequestTargetIdToken error:&error];

    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertTrue(result);
    XCTAssertEqual(claims.count, 2);
    MSIDIndividualClaimRequest *claim = claims[0];
    XCTAssertEqualObjects(@"claim1", claim.name);
    claim = claims[1];
    XCTAssertEqualObjects(@"claim3", claim.name);
}

- (void)testRemoveClaimRequestWithName_whenClaimDoesntExistInTarget_shouldIgnoreIt
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"claim1": [NSNull new], @"claim3": [NSNull new] }};
    NSError *error;
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:nil];

    BOOL result = [claimsRequest removeClaimRequestWithName:@"claim2" target:MSIDClaimsRequestTargetIdToken error:&error];

    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertFalse(result);
    XCTAssertEqual(claims.count, 2);
    MSIDIndividualClaimRequest *claim = claims[0];
    XCTAssertEqualObjects(@"claim1", claim.name);
    claim = claims[1];
    XCTAssertEqualObjects(@"claim3", claim.name);
}

#pragma mark - Init with json dictionary

- (void)testinitWithJSONDictionary_whenClaimRequestedInDefaultMannerInIdTokenTarget_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"nickname": [NSNull new] }};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedInDefaultMannerInIdAccessTokenTarget_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"access_token": @{@"nickname": [NSNull new] }};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetAccessToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedInTwoTargets_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"nickname": [NSNull new] }, @"access_token": @{@"some_claim": [NSNull new] }};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"nickname", claim.name);
    XCTAssertNil(claim.additionalInfo);
    claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetAccessToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    claim = claims.firstObject;
    XCTAssertEqualObjects(@"some_claim", claim.name);
    XCTAssertNil(claim.additionalInfo);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedWithEssentialFlag_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"given_name": @{@"essential": @YES}}};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"given_name", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertTrue(claim.additionalInfo.essential);
    XCTAssertNil(claim.additionalInfo.value);
    XCTAssertNil(claim.additionalInfo.values);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedWithValue_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"sub": @{@"value": @248289761001}}};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"sub", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertEqualObjects(@248289761001, claim.additionalInfo.value);
    XCTAssertNil(claim.additionalInfo.values);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedWithValues_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"acr": @{@"values": @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"]}}};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"acr", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertNil(claim.additionalInfo.value);
    __auto_type expectedValues = @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"];
    XCTAssertEqualObjects(expectedValues, claim.additionalInfo.values);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedWithDuplicateValues_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"acr": @{@"values": @[@"v1", @"v1"]}}};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];

    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"acr", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertNil(claim.additionalInfo.essential);
    XCTAssertNil(claim.additionalInfo.value);
    __auto_type expectedValues = @[@"v1", @"v1"];
    XCTAssertEqualObjects(expectedValues, claim.additionalInfo.values);
}

- (void)testinitWithJSONDictionary_whenClaimRequestedWithAllPossibleValues_shouldInitClaimRequest
{
    NSDictionary *claimsJsonDictionary = @{@"id_token": @{@"acr": @{@"essential": @YES, @"value": @248289761001, @"values": @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"]}}};
    NSError *error;
    
    __auto_type claimsRequest = [[MSIDClaimsRequest alloc] initWithJSONDictionary:claimsJsonDictionary error:&error];
    
    __auto_type claims = [claimsRequest claimsRequestsForTarget:MSIDClaimsRequestTargetIdToken];
    XCTAssertNotNil(claimsRequest);
    XCTAssertNil(error);
    XCTAssertEqual(claims.count, 1);
    MSIDIndividualClaimRequest *claim = claims.firstObject;
    XCTAssertEqualObjects(@"acr", claim.name);
    XCTAssertNotNil(claim.additionalInfo);
    XCTAssertTrue(claim.additionalInfo.essential);
    XCTAssertEqualObjects(@248289761001, claim.additionalInfo.value);
    __auto_type expectedValues = @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"];
    XCTAssertEqualObjects(expectedValues, claim.additionalInfo.values);
}

#pragma mark - jsonDictionary

- (void)testJsonDictionary_whenClaimsRequestWithoutClaims_shouldReturnValidJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedInDefaultManner_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"nickname"];
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"nickname": [NSNull new]}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithEssentialFlag_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"given_name"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @YES;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"given_name":@{@"essential":@YES}}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithEssentialFlagAndItIs10_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"given_name"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @10;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"given_name":@{@"essential":@YES}}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithEssentialFlagAndItIs0_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"given_name"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @0;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"given_name":@{@"essential":@NO}}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithEssentialFlagAndItIsNegative1_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"given_name"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @-1;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"given_name":@{@"essential":@YES}}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithValue_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @248289761001;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    XCTAssertEqualObjects(@{@"id_token":@{@"sub":@{@"value":@248289761001}}}, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithValues_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"acr"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.values = @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"];
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    __auto_type expectedJsonDictionary = @{@"id_token":@{@"acr":@{@"values":@[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"]}}};
    XCTAssertEqualObjects(expectedJsonDictionary, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithAllPossibleValues_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"acr"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.essential = @YES;
    claimRequest.additionalInfo.value = @248289761001;
    claimRequest.additionalInfo.values = @[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"];
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    __auto_type expectedJsonDictionary = @{@"id_token":@{@"acr":@{@"value":@248289761001,@"values":@[@"urn:mace:incommon:iap:silver", @"urn:mace:incommon:iap:bronze"],@"essential":@YES}}};
    XCTAssertEqualObjects(expectedJsonDictionary, jsonDictionary);
}

- (void)testJsonDictionary_whenClaimRequestedWithValueAndRequestedTwice_shouldReturnProperJsonString
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @2;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    NSDictionary *jsonDictionary = [claimsRequest jsonDictionary];
    
    __auto_type expectedJsonString = @{@"id_token":@{@"sub":@{@"value":@2}}};
    XCTAssertEqualObjects(expectedJsonString, jsonDictionary);
}

#pragma mark - hasClaims

- (void)testHasClaims_whenNoClaims_shoudReturnNo
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    
    BOOL result = [claimsRequest hasClaims];
    
    XCTAssertFalse(result);
}

- (void)testHasClaims_whenThereIsClaim_shoudReturnYes
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    BOOL result = [claimsRequest hasClaims];
    
    XCTAssertTrue(result);
}

#pragma mark - Copy

- (void)testCopy_shouldCopyAllFields
{
    __auto_type claimsRequest = [MSIDClaimsRequest new];
    __auto_type claimRequest = [[MSIDIndividualClaimRequest alloc] initWithName:@"sub"];
    claimRequest.additionalInfo = [MSIDIndividualClaimRequestAdditionalInfo new];
    claimRequest.additionalInfo.value = @1;
    [claimsRequest requestClaim:claimRequest forTarget:MSIDClaimsRequestTargetIdToken error:nil];
    
    MSIDClaimsRequest *claimsRequestCopy = [claimsRequest copy];
    
    NSDictionary *jsonDictionary = [claimsRequestCopy jsonDictionary];
    __auto_type expectedJsonString = @{@"id_token":@{@"sub":@{@"value":@1}}};
    XCTAssertEqualObjects(expectedJsonString, jsonDictionary);
}

@end
