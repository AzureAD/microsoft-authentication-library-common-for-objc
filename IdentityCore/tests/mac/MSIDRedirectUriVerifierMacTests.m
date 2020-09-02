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
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.  


#import <XCTest/XCTest.h>
#import "MSIDRedirectUriVerifier.h"
#import "MSIDTestBundle.h"
#import "MSIDRedirectUri.h"

@interface MSIDRedirectUriVerifierMacTests : XCTestCase

@end

@implementation MSIDRedirectUriVerifierMacTests

- (void)setUp
{
    [super setUp];
    [MSIDTestBundle overrideBundleId:@"test.bundle.identifier"];
}

- (void)testMsidRedirectUriCreation_whenCustomRedirectUriProvided_andRedirectUriBrokerCapable_shouldReturnBrokeredURL
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:@"msauth.test.bundle.identifier://auth"
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:NO
                                                                                   error:&error];
    
    XCTAssertNotNil(redirectUri);
    XCTAssertNil(error);
    XCTAssertTrue(redirectUri.brokerCapable);
}

- (void)testMsidRedirectUriCreation_whenCustomRedirectUriProvided_andRedirectUriNotBrokerCapable_shouldReturnNonBrokerURL
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:@"msauth.test.bundle.identifier2://auth"
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:NO
                                                                                   error:&error];
    
    XCTAssertNotNil(redirectUri);
    XCTAssertNil(error);
    XCTAssertFalse(redirectUri.brokerCapable);
}

- (void)testMsidRedirectUriCreation_whenCustomRedirectUriInvalid_shouldReturnNil
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:@"invalid_redirect"
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:NO
                                                                                   error:&error];
    
    XCTAssertNil(redirectUri);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, MSIDErrorInvalidDeveloperParameter);
    XCTAssertFalse(redirectUri.brokerCapable);
}

- (void)testMsidRedirectUriCreation_whenCustomRedirectUriInvalid_andByPassFladEnabled_shouldReturnBrokeredURL
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:@"invalid_redirect"
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:YES
                                                                                   error:&error];
    
    XCTAssertNotNil(redirectUri);
    XCTAssertNil(error);
    XCTAssertTrue(redirectUri.brokerCapable);
}

- (void)testMsidRedirectUriCreation_whenNoCustomRedirectUriProvided_shouldReturnDefaultBrokeredURL
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:nil
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:NO
                                                                                   error:&error];
    
    XCTAssertNotNil(redirectUri);
    XCTAssertNil(error);
    XCTAssertTrue(redirectUri.brokerCapable);
    XCTAssertEqualObjects(redirectUri.url.absoluteString, @"msauth.test.bundle.identifier://auth");
}

- (void)testMsidRedirectUriCreation_whenCustomRedirectUriProvided_andRedirectUriNotBrokerCapable_butByPassFlagEnabled_shouldReturnBrokeredURL
{
    NSError *error = nil;
    MSIDRedirectUri *redirectUri = [MSIDRedirectUriVerifier msidRedirectUriWithCustomUri:@"msauth.test.bundle.identifier2://auth"
                                                                                clientId:@"myclient"
                                                                bypassRedirectValidation:YES
                                                                                   error:&error];
    
    XCTAssertNotNil(redirectUri);
    XCTAssertNil(error);
    XCTAssertTrue(redirectUri.brokerCapable);
}

@end
