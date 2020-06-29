//------------------------------------------------------------------------------
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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"
#import "MSIDTestCacheDataSource.h"
#import "MSIDMetadataCache.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDAccountMetadataCacheItem.h"

@interface MSIDAccountMetadataCacheAccessorTests : XCTestCase

@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;
@property (nonatomic) MSIDAccountMetadataCacheAccessor *secondAccountMetadataCache;

@end

@implementation MSIDAccountMetadataCacheAccessorTests

- (void)setUp {
#if TARGET_OS_IOS
    [MSIDKeychainTokenCache reset];
    __auto_type dataSource = [[MSIDKeychainTokenCache alloc] init];
#else
    __auto_type dataSource = [[MSIDTestCacheDataSource alloc] init];
#endif
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    self.secondAccountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
}

- (void)tearDown {
}

- (void)testSignInStateForHomeAccountId_whenHomeAccountIdNil_shouldReturnErrorAndUnknown {
    NSError *error;
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:nil clientId:@"client_id" context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateUnknown);
}

- (void)testSigneInStateForHomeAccountId_whenClientIdNil_shouldReturnErrorAndUnknown {
    NSError *error;
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"uid.utid" clientId:nil context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateUnknown);
}

- (void)testSignInStateForHomeAccountId_whenAllParametersPassed_shouldReturnState {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateSignedIn);
}

- (void)testUpdateSignInStateForHomeAccountId_whenHomeAccountIdNil_shouldReturnError {
    NSError *error;
    BOOL success = [self.accountMetadataCache updateSignInStateForHomeAccountId:nil clientId:@"client_id" state:MSIDAccountMetadataStateSignedOut context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(success);
}

- (void)testUpdateSignInStateForHomeAccountId_whenClientIdNil_shouldReturnError {
    NSError *error;
    BOOL success = [self.accountMetadataCache updateSignInStateForHomeAccountId:@"uid.utid" clientId:nil state:MSIDAccountMetadataStateSignedOut context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(success);
}

- (void)testUpdateSignInStateForHomeAccountId_whenSetSignedOut_shouldSetState {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
    
    BOOL success = [self.accountMetadataCache updateSignInStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" state:MSIDAccountMetadataStateSignedOut context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateSignedOut);
    
    XCTAssertNil([self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                              homeAccountId:@"uid.utid"
                                                   clientId:@"my-client-id" instanceAware:NO context:nil error:&error]);
    
    
}

- (void)testUpdateSignInStateForHomeAccountId_whenSetNonSignedOutState_shouldNotAffectAuthorityMapping {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
    
    BOOL success = [self.accountMetadataCache updateSignInStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" state:MSIDAccountMetadataStateUnknown context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    MSIDAccountMetadataState signInState = [self.accountMetadataCache signInStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertEqual(signInState, MSIDAccountMetadataStateUnknown);
    
    retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                     homeAccountId:@"uid.utid"
                                                          clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
}

- (void)testGetAuthorityURL_whenAuthorityMappingRecordExists_shouldReturnAuthorityMapping {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    // return if there is record matched
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
}

- (void)testGetAuthorityURL_whenAuthorityMappingRecordNotExists_shouldReturnNil {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    // return nil if no record matched
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:YES context:nil error:&error];
    XCTAssertNil(retrievedCacheURL);
    
    retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                     homeAccountId:@"uid.utid2"
                                                          clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertNil(retrievedCacheURL);
    
    retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                     homeAccountId:@"uid.utid"
                                                          clientId:@"my-client-id2" instanceAware:NO context:nil error:&error];
    XCTAssertNil(retrievedCacheURL);
    
    retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common2"]
                                                     homeAccountId:@"uid.utid"
                                                          clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertNil(retrievedCacheURL);
}

- (void)testGetAuthorityURL_whenNoAccountMetadataAtAll_shouldReturnNil {
    NSError *error;
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:YES context:nil error:&error];
    XCTAssertNil(retrievedCacheURL);
}

- (void)testUpdateAuthorityURL_whenRequiredParametersNil_shouldReturnError {
    NSError *error;
    XCTAssertFalse([self.accountMetadataCache updateAuthorityURL:nil
                                                   forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                   homeAccountId:@"uid.utid"
                                                        clientId:@"my-client-id"
                                                   instanceAware:NO
                                                         context:nil
                                                           error:&error]);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    
    error = nil;
    XCTAssertFalse([self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                                   forRequestURL:nil
                                                   homeAccountId:@"uid.utid"
                                                        clientId:@"my-client-id"
                                                   instanceAware:NO
                                                         context:nil
                                                           error:&error]);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    
    error = nil;
    XCTAssertFalse([self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                                   forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                   homeAccountId:nil
                                                        clientId:@"my-client-id"
                                                   instanceAware:NO
                                                         context:nil
                                                           error:&error]);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    
    error = nil;
    XCTAssertFalse([self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                                   forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                   homeAccountId:@"uid.utid"
                                                        clientId:nil
                                                   instanceAware:NO
                                                         context:nil
                                                           error:&error]);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
}

- (void)testUpdateAuthorityURL_whenUpdateExistingAuthorityMapping_shouldUpdate {
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
    XCTAssertNil(error);
    
    // update existing record
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso2"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso2", retrievedCacheURL.absoluteString);
    XCTAssertNil(error);
}

- (void)testUpdateAuthorityURL_whenUpdateExistingAuthorityMappingWithSameValue_shouldReturnSameResult {
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    // update existing record with same value
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    NSURL *retrievedCacheURL = [self.accountMetadataCache getAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                                            homeAccountId:@"uid.utid"
                                                                 clientId:@"my-client-id" instanceAware:NO context:nil error:&error];
    XCTAssertEqualObjects(@"https://login.microsoftonline.com/contoso", retrievedCacheURL.absoluteString);
    XCTAssertNil(error);
}

- (void)testPrincipalAccountIdForClientId_whenClientIdNil_shouldReturnNilAndFillError
{
    NSString *clientId = nil;
    
    NSError *error;
    MSIDAccountIdentifier *accountIdentifier = [self.accountMetadataCache principalAccountIdForClientId:clientId context:nil error:&error];
    
    XCTAssertNil(accountIdentifier);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"ClientId is required to query account metadata cache!");
}

- (void)testPrincipalAccountIdForClientId_whenAllParametersPassed_andNoAccountIdSaved_shouldReturnNil_andNilError
{
    NSString *clientId = @"myclientId";
    
    NSError *error;
    MSIDAccountIdentifier *accountIdentifier = [self.accountMetadataCache principalAccountIdForClientId:clientId context:nil error:&error];
    
    XCTAssertNil(accountIdentifier);
    XCTAssertNil(error);
}

- (void)testPrincipalAccountIdForClientId_whenAllParametersPassed_andAccountIdSaved_shouldReturnNonNil_andNilError
{
    NSString *clientId = @"myclientId";
    
    MSIDAccountIdentifier *testAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@upn.com" homeAccountId:@"uid.utid"];
    
    [self.accountMetadataCache updatePrincipalAccountIdForClientId:clientId
                                                principalAccountId:testAccountId
                                       principalAccountEnvironment:@"login.myenv.com"
                                                           context:nil
                                                             error:nil];
    
    NSError *error;
    MSIDAccountIdentifier *accountIdentifier = [self.accountMetadataCache principalAccountIdForClientId:clientId context:nil error:&error];
    
    XCTAssertNotNil(accountIdentifier);
    XCTAssertNil(error);
    XCTAssertEqualObjects(accountIdentifier.displayableId, @"test@upn.com");
    XCTAssertEqualObjects(accountIdentifier.homeAccountId, @"uid.utid");

    MSIDAccountMetadataCacheItem *accountMetadataCacheItem = [self.accountMetadataCache retrieveAccountMetadataCacheItemForClientId:clientId context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(accountMetadataCacheItem.principalAccountEnvironment, @"login.myenv.com");
}

- (void)testPrincipalAccountIfForClientId_whenAllParametersPassed_andSkipCacheYES_andValueChangedInParallel_shouldReturnCorrectValue
{
    NSString *clientId = @"myclientId";
    
    MSIDAccountIdentifier *testAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@upn.com" homeAccountId:@"uid.utid"];
    
    [self.accountMetadataCache updatePrincipalAccountIdForClientId:clientId
                                                principalAccountId:testAccountId
                                       principalAccountEnvironment:@"login.myenv.com"
                                                           context:nil
                                                             error:nil];
    
    MSIDAccountIdentifier *secondTestAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test2@upn.com" homeAccountId:@"uid2.utid2"];
    
    [self.secondAccountMetadataCache updatePrincipalAccountIdForClientId:clientId
                                                      principalAccountId:secondTestAccountId
                                             principalAccountEnvironment:@"login.myenv.com"
                                                                 context:nil
                                                                   error:nil];
    
    
    NSError *error;
    self.accountMetadataCache.skipMemoryCacheForAccountMetadata = YES;
    MSIDAccountIdentifier *accountIdentifier = [self.accountMetadataCache principalAccountIdForClientId:clientId context:nil error:&error];
    
    XCTAssertNotNil(accountIdentifier);
    XCTAssertNil(error);
    XCTAssertEqualObjects(accountIdentifier.displayableId, @"test2@upn.com");
    XCTAssertEqualObjects(accountIdentifier.homeAccountId, @"uid2.utid2");

    MSIDAccountMetadataCacheItem *accountMetadataCacheItem = [self.accountMetadataCache retrieveAccountMetadataCacheItemForClientId:clientId context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertEqualObjects(accountMetadataCacheItem.principalAccountEnvironment, @"login.myenv.com");
}

- (void)testUpdatePrincipalAccountId_whenNilClientId_shouldReturnError
{
    NSString *clientId = nil;

    NSError *error;
    BOOL result = [self.accountMetadataCache updatePrincipalAccountIdForClientId:clientId principalAccountId:nil principalAccountEnvironment:@"login.myenv.com" context:nil error:&error];
    
    XCTAssertFalse(result);
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertEqualObjects(error.userInfo[MSIDErrorDescriptionKey], @"ClientId is required to query account metadata cache!");
}

- (void)testUpdatePrincipalAccountId_whenNilPrincipalId_shouldRemovePreviousPrincipalId
{
    NSString *clientId = @"myclientId";
    
    MSIDAccountIdentifier *testAccountId = [[MSIDAccountIdentifier alloc] initWithDisplayableId:@"test@upn.com" homeAccountId:@"uid.utid"];
    
    // Save first time
    [self.accountMetadataCache updatePrincipalAccountIdForClientId:clientId
                                                principalAccountId:testAccountId
                                       principalAccountEnvironment:@"login.myenv.com"
                                                           context:nil
                                                             error:nil];
    
    // Save with nil
    NSError *error;
    BOOL result = [self.accountMetadataCache updatePrincipalAccountIdForClientId:clientId principalAccountId:nil principalAccountEnvironment:@"login.myenv.com" context:nil error:&error];
    
    XCTAssertTrue(result);
    XCTAssertNil(error);
    
    MSIDAccountIdentifier *accountIdentifier = [self.accountMetadataCache principalAccountIdForClientId:clientId context:nil error:&error];
    
    XCTAssertNil(accountIdentifier);
    XCTAssertNil(error);
}

- (void)testSignInStateForHomeAccountId_whenMultipleCaches_shouldReadStateFromDisc
{
    [self.accountMetadataCache updateSignInStateForHomeAccountId:@"id1"
                                                        clientId:@"clientId1"
                                                           state:MSIDAccountMetadataStateSignedIn
                                                         context:nil
                                                           error:nil];
    MSIDAccountMetadataState state = [self.secondAccountMetadataCache signInStateForHomeAccountId:@"id1"
                                                                                         clientId:@"clientId1"
                                                                                          context:nil
                                                                                            error:nil];
    [self.accountMetadataCache updateSignInStateForHomeAccountId:@"id1"
                                                        clientId:@"clientId1"
                                                           state:MSIDAccountMetadataStateSignedOut
                                                         context:nil
                                                           error:nil];
    
    state = [self.secondAccountMetadataCache signInStateForHomeAccountId:@"id1"
                                                                clientId:@"clientId1"
                                                                 context:nil
                                                                   error:nil];
    
    XCTAssertEqual(MSIDAccountMetadataStateSignedOut, state);
}

@end
