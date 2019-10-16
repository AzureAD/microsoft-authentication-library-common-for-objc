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
