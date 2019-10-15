//
//  MSIDAccountMetadataCacheAccessorTests.m
//  IdentityCore
//
//  Created by JZ on 10/15/19.
//  Copyright © 2019 Microsoft. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MSIDAccountMetadataCacheAccessor.h"
#import "MSIDKeychainTokenCache+MSIDTestsUtil.h"

@interface MSIDAccountMetadataCacheAccessorTests : XCTestCase

@property (nonatomic) MSIDAccountMetadataCacheAccessor *accountMetadataCache;

@end

@implementation MSIDAccountMetadataCacheAccessorTests

- (void)setUp {
    [MSIDKeychainTokenCache reset];
    __auto_type dataSource = [[MSIDKeychainTokenCache alloc] init];
    self.accountMetadataCache = [[MSIDAccountMetadataCacheAccessor alloc] initWithDataSource:dataSource];
    
}

- (void)tearDown {
}

- (void)testSignedOutStateForHomeAccountId_whenHomeAccountIdNil_shouldReturnNil {
    NSError *error;
    BOOL isSignedOut = [self.accountMetadataCache signedOutStateForHomeAccountId:nil clientId:@"client_id" context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(isSignedOut);
}

- (void)testSignedOutStateForHomeAccountId_whenClientIdNil_shouldReturnNil {
    NSError *error;
    BOOL isSignedOut = [self.accountMetadataCache signedOutStateForHomeAccountId:@"uid.utid" clientId:nil context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(isSignedOut);
}

- (void)testSignedOutStateForHomeAccountId_whenAllParametersPassed_shouldReturnState {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    BOOL isSignedOut = [self.accountMetadataCache signedOutStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertFalse(isSignedOut);
}

- (void)testMarkSignedOutStateForHomeAccountId_whenHomeAccountIdNil_shouldReturnNil {
    NSError *error;
    BOOL success = [self.accountMetadataCache markSignedOutStateForHomeAccountId:nil clientId:@"client_id" context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(success);
}

- (void)testMarkSignedOutStateForHomeAccountId_whenClientIdNil_shouldReturnNil {
    NSError *error;
    BOOL success = [self.accountMetadataCache markSignedOutStateForHomeAccountId:@"uid.utid" clientId:nil context:nil error:&error];
    
    XCTAssertNotNil(error);
    XCTAssertEqual(error.domain, MSIDErrorDomain);
    XCTAssertEqual(error.code, MSIDErrorInvalidInternalParameter);
    XCTAssertFalse(success);
}

- (void)testMarkSignedOutStateForHomeAccountId_whenAllParametersPassed_shouldMarkSignedOut {
    //Save account metadata
    NSError *error;
    [self.accountMetadataCache updateAuthorityURL:[NSURL URLWithString:@"https://login.microsoftonline.com/common"]
                                    forRequestURL:[NSURL URLWithString:@"https://login.microsoftonline.com/contoso"]
                                    homeAccountId:@"uid.utid"
                                         clientId:@"my-client-id"
                                    instanceAware:NO
                                          context:nil
                                            error:&error];
    XCTAssertNil(error);
    
    BOOL success = [self.accountMetadataCache markSignedOutStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    XCTAssertNil(error);
    XCTAssertTrue(success);
    
    BOOL isSignedOut = [self.accountMetadataCache signedOutStateForHomeAccountId:@"uid.utid" clientId:@"my-client-id" context:nil error:&error];
    
    XCTAssertNil(error);
    XCTAssertTrue(isSignedOut);
}

@end
